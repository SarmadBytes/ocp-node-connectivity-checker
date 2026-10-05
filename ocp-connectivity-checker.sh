#!/bin/bash

################################################################################
# OpenShift Node Communication Checker
################################################################################
# Description: Automated script to verify network connectivity from all
#              OpenShift nodes to a specified destination (hostname/IP:port)
#
# Usage:
#   Interactive mode:
#     ./ocp-connectivity-checker.sh
#
#   Non-interactive mode (for cron):
#     ./ocp-connectivity-checker.sh -d <destination> -p <port> -n
#
# Requirements:
#   - OpenShift CLI (oc) installed and configured
#   - Valid login session to OpenShift cluster
#   - Permissions to run 'oc debug node' commands
#
# Author: OpenShift Infrastructure Team
# Version: 1.0
# Date: 2025-10-15
################################################################################

set -o pipefail  # Catch errors in pipes

################################################################################
# CONFIGURATION
################################################################################

# Script metadata
readonly SCRIPT_NAME="OpenShift Node Communication Checker"
readonly SCRIPT_VERSION="1.0"

# Timeout settings (in seconds)
readonly OC_DEBUG_TIMEOUT=60
readonly CURL_TIMEOUT=15

# Log directory base path
readonly LOG_BASE_DIR="logs"

# Color codes for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
# shellcheck disable=SC2034  # kept for future colour output
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'  # No Color

# Global variables
DESTINATION=""
PORT=""
NON_INTERACTIVE=false
LOG_DIR=""
LOG_FILE=""
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Arrays to store node information and results
declare -a NODE_NAMES=()
declare -a NODE_IPS=()
declare -a NODE_ROLES=()
declare -a RESULTS=()
declare -a ERROR_MESSAGES=()

# Statistics counters
TOTAL_NODES=0
SUCCESSFUL_NODES=0
FAILED_NODES=0

################################################################################
# HELPER FUNCTIONS
################################################################################

# Print colored messages
print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_header() {
    echo -e "${BOLD}$1${NC}"
}

# Log message to file (strip colors)
log_to_file() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | sed 's/\x1b\[[0-9;]*m//g' >> "${LOG_FILE}"
}

# Log and display message
log_message() {
    local level="$1"
    local message="$2"

    case "$level" in
        INFO)
            print_info "$message"
            log_to_file "INFO: $message"
            ;;
        SUCCESS)
            print_success "$message"
            log_to_file "SUCCESS: $message"
            ;;
        ERROR)
            print_error "$message"
            log_to_file "ERROR: $message"
            ;;
        WARN)
            print_warning "$message"
            log_to_file "WARN: $message"
            ;;
        DEBUG)
            log_to_file "DEBUG: $message"
            ;;
    esac
}

# Display banner
display_banner() {
    echo ""
    echo "================================================="
    print_header "  ${SCRIPT_NAME}"
    echo "  Version ${SCRIPT_VERSION}"
    echo "================================================="
    echo ""
}

# Validate port number
validate_port() {
    local port=$1

    # Check if port is numeric
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    # Check if port is in valid range
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi

    return 0
}

# Validate destination (hostname or IP)
validate_destination() {
    local dest=$1

    # Check if destination is not empty
    if [ -z "$dest" ]; then
        return 1
    fi

    # Basic validation - just ensure it's not empty and doesn't contain spaces
    if [[ "$dest" =~ [[:space:]] ]]; then
        return 1
    fi

    return 0
}

# Check prerequisites
check_prerequisites() {
    log_message "INFO" "Checking prerequisites..."

    # Check if oc command exists
    if ! command -v oc &> /dev/null; then
        log_message "ERROR" "OpenShift CLI (oc) is not installed or not in PATH"
        echo ""
        echo "Please install the OpenShift CLI from:"
        echo "https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html"
        return 1
    fi
    log_message "SUCCESS" "OpenShift CLI (oc) found"

    # Check if logged into OpenShift cluster
    if ! oc whoami &> /dev/null; then
        log_message "ERROR" "Not logged into OpenShift cluster"
        echo ""
        echo "Please login using: oc login <cluster-url>"
        return 1
    fi
    log_message "SUCCESS" "Logged into OpenShift cluster"

    # Get current cluster info
    local cluster_name
    cluster_name=$(oc whoami --show-server 2>/dev/null)
    if [ -n "$cluster_name" ]; then
        log_message "SUCCESS" "Connected to cluster: ${cluster_name}"
    fi

    # Check if user can list nodes
    if ! oc get nodes &> /dev/null; then
        log_message "ERROR" "Cannot list nodes - insufficient permissions"
        echo ""
        echo "Please ensure you have permissions to run 'oc get nodes'"
        return 1
    fi

    return 0
}

# Create log directory
create_log_directory() {
    LOG_DIR="${LOG_BASE_DIR}/ocp-connectivity-check_${TIMESTAMP}"
    LOG_FILE="${LOG_DIR}/connectivity-check.log"

    if ! mkdir -p "${LOG_DIR}" 2>/dev/null; then
        print_error "Failed to create log directory: ${LOG_DIR}"
        return 1
    fi

    # Create log file with header
    cat > "${LOG_FILE}" << EOF
=================================================
${SCRIPT_NAME}
=================================================
Start Time: $(date '+%Y-%m-%d %H:%M:%S')
Destination: ${DESTINATION}
Port: ${PORT}
Cluster: $(oc whoami --show-server 2>/dev/null || echo "Unknown")
User: $(oc whoami 2>/dev/null || echo "Unknown")
=================================================

EOF

    log_message "SUCCESS" "Log directory created: ${LOG_DIR}"
    return 0
}

# Get all OpenShift nodes
get_all_nodes() {
    log_message "INFO" "Discovering OpenShift nodes..."

    # Get nodes with their details
    local node_data
    node_data=$(oc get nodes -o wide --no-headers 2>&1)

    if [ $? -ne 0 ]; then
        log_message "ERROR" "Failed to get node list: ${node_data}"
        return 1
    fi

    # Parse node information
    while IFS= read -r line; do
        # Extract: NAME INTERNAL-IP ROLES
        local name
        name=$(echo "$line" | awk '{print $1}')
        local ip
        ip=$(echo "$line" | awk '{print $6}')
        local role
        role=$(echo "$line" | awk '{print $3}')
        if [ -n "$name" ] && [ -n "$ip" ]; then
            NODE_NAMES+=("$name")
            NODE_IPS+=("$ip")
            NODE_ROLES+=("$role")
            RESULTS+=("PENDING")
            ERROR_MESSAGES+=("")
        fi
    done <<< "$node_data"

    TOTAL_NODES=${#NODE_NAMES[@]}

    if [ $TOTAL_NODES -eq 0 ]; then
        log_message "ERROR" "No nodes found in the cluster"
        return 1
    fi

    # Count nodes by role
    local master_count
    master_count=$(printf '%s\n' "${NODE_ROLES[@]}" | grep -c "master" || true)
    local infra_count
    infra_count=$(printf '%s\n' "${NODE_ROLES[@]}" | grep -c "infra" || true)
    local worker_count
    worker_count=$(printf '%s\n' "${NODE_ROLES[@]}" | grep -c "worker" || true)
    log_message "SUCCESS" "Found ${TOTAL_NODES} nodes (${master_count} master, ${infra_count} infra, ${worker_count} worker)"

    return 0
}

# Parse curl output to determine success/failure
parse_curl_output() {
    local output="$1"

    # Check for successful connection
    if echo "$output" | grep -q "Connected to"; then
        echo "Success"
        return 0
    fi

    # Check for specific error patterns
    if echo "$output" | grep -qi "could not resolve host"; then
        echo "Failed: Could not resolve host"
        return 1
    elif echo "$output" | grep -qi "connection refused"; then
        echo "Failed: Connection refused"
        return 1
    elif echo "$output" | grep -qi "connection timed out"; then
        echo "Failed: Connection timed out"
        return 1
    elif echo "$output" | grep -qi "no route to host"; then
        echo "Failed: No route to host"
        return 1
    elif echo "$output" | grep -qi "failed to connect"; then
        echo "Failed: Failed to connect"
        return 1
    elif echo "$output" | grep -qi "network is unreachable"; then
        echo "Failed: Network unreachable"
        return 1
    else
        echo "Failed: Unknown error"
        return 1
    fi
}

# Test connectivity from a single node
test_node_connectivity() {
    local node_name="$1"
    local node_ip="$2"
    local index="$3"

    log_to_file "=========================================="
    log_to_file "Testing Node: ${node_name} (${node_ip})"
    log_to_file "=========================================="

    # Build the command to execute
    local test_command="chroot /host bash -c 'timeout ${CURL_TIMEOUT} curl -v telnet://${DESTINATION}:${PORT} 2>&1'"

    log_to_file "Command: oc debug node/${node_name} -- bash -c \"${test_command}\""

    # Execute oc debug with timeout
    local curl_output
    curl_output=$(timeout ${OC_DEBUG_TIMEOUT} oc debug node/"${node_name}" \
        --to-namespace=default \
        -- bash -c "${test_command}" 2>&1)

    local exit_code=$?

    # Log the full output
    log_to_file "Output:"
    log_to_file "${curl_output}"

    # Parse the output
    local result
    result=$(parse_curl_output "$curl_output")

    # Store result
    RESULTS[$index]="$result"

    if [ $exit_code -eq 124 ]; then
        # Timeout occurred
        RESULTS[$index]="Failed: Timeout"
        ERROR_MESSAGES[$index]="Operation timed out after ${OC_DEBUG_TIMEOUT} seconds"
        log_to_file "Result: FAILED (Timeout)"
        return 1
    elif [[ "$result" == "Success" ]]; then
        ERROR_MESSAGES[$index]=""
        log_to_file "Result: SUCCESS"
        return 0
    else
        ERROR_MESSAGES[$index]="$result"
        log_to_file "Result: ${result}"
        return 1
    fi
}

# Display progress indicator
show_progress() {
    local current=$1
    local total=$2
    local node_name=$3

    # Extract short hostname (first part before first dot)
    local short_name="${node_name%%.*}"

    echo -ne "\r${CYAN}[${current}/${total}]${NC} Testing ${BOLD}${short_name}${NC}... "
}

# Display summary table
display_summary_table() {
    echo ""
    echo "================================================="
    print_header "  CONNECTIVITY TEST RESULTS"
    echo "================================================="
    echo ""

    # Calculate column widths
    local max_hostname_len=20
    local max_dest_len=30

    # Table header
    printf "+%-22s+%-15s+%-32s+%-6s+%-10s+\n" \
        "----------------------" \
        "---------------" \
        "--------------------------------" \
        "------" \
        "----------"

    printf "| %-20s | %-13s | %-30s | %-4s | %-8s |\n" \
        "Node Hostname" \
        "Node IP" \
        "Destination" \
        "Port" \
        "Result"

    printf "+%-22s+%-15s+%-32s+%-6s+%-10s+\n" \
        "----------------------" \
        "---------------" \
        "--------------------------------" \
        "------" \
        "----------"

    # Table rows
    for i in "${!NODE_NAMES[@]}"; do
        local node_name="${NODE_NAMES[$i]}"
        local node_ip="${NODE_IPS[$i]}"
        local result="${RESULTS[$i]}"

        # Extract short hostname
        local short_name="${node_name%%.*}"

        # Truncate hostname if too long
        if [ ${#short_name} -gt $max_hostname_len ]; then
            short_name="${short_name:0:17}..."
        fi

        # Truncate destination if too long
        local dest_display="$DESTINATION"
        if [ ${#dest_display} -gt $max_dest_len ]; then
            dest_display="${dest_display:0:27}..."
        fi

        # Color code result
        local result_display
        if [[ "$result" == "Success" ]]; then
            result_display="${GREEN}Success${NC}"
        else
            result_display="${RED}Failed${NC}"
        fi

        printf "| %-20s | %-13s | %-30s | %-4s | " \
            "$short_name" \
            "$node_ip" \
            "$dest_display" \
            "$PORT"

        echo -e "$(printf '%-8s' "$result_display") |"
    done

    printf "+%-22s+%-15s+%-32s+%-6s+%-10s+\n" \
        "----------------------" \
        "---------------" \
        "--------------------------------" \
        "------" \
        "----------"

    echo ""
}

# Display summary statistics
display_statistics() {
    echo "========================================="
    print_header "  SUMMARY STATISTICS"
    echo "========================================="
    echo "Total Nodes:      ${TOTAL_NODES}"
    echo "Successful:       ${GREEN}${SUCCESSFUL_NODES}${NC}"
    echo "Failed:           ${RED}${FAILED_NODES}${NC}"

    # Calculate success rate
    if [ $TOTAL_NODES -gt 0 ]; then
        local success_rate
        success_rate=$(( SUCCESSFUL_NODES * 100 / TOTAL_NODES ))
        echo "Success Rate:     ${success_rate}%"
    fi
    echo "========================================="
    echo ""
}

# Write summary to log file
write_log_summary() {
    cat >> "${LOG_FILE}" << EOF

=================================================
Test Summary
=================================================
Total Nodes: ${TOTAL_NODES}
Successful: ${SUCCESSFUL_NODES}
Failed: ${FAILED_NODES}
Success Rate: $(( SUCCESSFUL_NODES * 100 / TOTAL_NODES ))%
End Time: $(date '+%Y-%m-%d %H:%M:%S')
=================================================
EOF
}

# Cleanup function (called on exit or interrupt)
cleanup() {
    echo ""
    log_message "INFO" "Cleaning up..."

    # Note: oc debug pods are automatically cleaned up when they exit
    # No manual cleanup needed

    log_message "INFO" "Cleanup completed"
}

# Handle interrupt signals
handle_interrupt() {
    echo ""
    print_warning "Script interrupted by user"
    cleanup
    exit 130
}

# Trap signals
trap handle_interrupt INT TERM

################################################################################
# MAIN FUNCTION
################################################################################

main() {
    # Display banner
    display_banner

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --destination|-d)
                DESTINATION="$2"
                shift 2
                ;;
            --port|-p)
                PORT="$2"
                shift 2
                ;;
            --non-interactive|-n)
                NON_INTERACTIVE=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -d, --destination <hostname|ip>  Destination hostname or IP address"
                echo "  -p, --port <port>                Destination port number"
                echo "  -n, --non-interactive            Run in non-interactive mode (no prompts)"
                echo "  -h, --help                       Show this help message"
                echo ""
                echo "Examples:"
                echo "  Interactive mode:"
                echo "    $0"
                echo ""
                echo "  Non-interactive mode:"
                echo "    $0 -d payments-gateway.example.internal -p 8281 -n"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    echo ""

    # Get user inputs (if not provided via command line)
    if [ "$NON_INTERACTIVE" = false ]; then
        if [ -z "$DESTINATION" ]; then
            echo -n "Enter destination hostname or IP: "
            read -r DESTINATION
        fi

        if [ -z "$PORT" ]; then
            echo -n "Enter destination port: "
            read -r PORT
        fi
    fi

    # Validate inputs
    log_message "INFO" "Validating inputs..."

    if ! validate_destination "$DESTINATION"; then
        log_message "ERROR" "Invalid destination: ${DESTINATION}"
        echo "Destination must not be empty and must not contain spaces"
        exit 1
    fi
    log_message "SUCCESS" "Destination: ${DESTINATION}"

    if ! validate_port "$PORT"; then
        log_message "ERROR" "Invalid port: ${PORT}"
        echo "Port must be a number between 1 and 65535"
        exit 1
    fi
    log_message "SUCCESS" "Port: ${PORT}"
    echo ""

    # Create log directory
    if ! create_log_directory; then
        exit 1
    fi
    echo ""

    # Discover nodes
    if ! get_all_nodes; then
        exit 1
    fi
    echo ""

    # Test connectivity for each node
    log_message "INFO" "Testing connectivity from all nodes..."
    echo ""

    for i in "${!NODE_NAMES[@]}"; do
        local current
        current=$((i + 1))
        local node_name="${NODE_NAMES[$i]}"
        local node_ip="${NODE_IPS[$i]}"
        local short_name="${node_name%%.*}"

        # Show progress
        show_progress "$current" "$TOTAL_NODES" "$node_name"

        # Test connectivity
        if test_node_connectivity "$node_name" "$node_ip" "$i"; then
            echo -e "${GREEN}Success ✓${NC}"
            ((SUCCESSFUL_NODES++))
        else
            echo -e "${RED}Failed ✗${NC} (${ERROR_MESSAGES[$i]})"
            ((FAILED_NODES++))
        fi
    done

    echo ""
    echo ""

    # Display results
    display_summary_table
    display_statistics

    # Write summary to log
    write_log_summary

    # Display log location
    log_message "SUCCESS" "Detailed logs saved to: ${LOG_FILE}"
    echo ""

    # Exit with appropriate code
    if [ $FAILED_NODES -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

################################################################################
# SCRIPT ENTRY POINT
################################################################################

main "$@"
