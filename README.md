# OpenShift Node Communication Checker

Automated bash script to verify network connectivity from all OpenShift nodes to specified destinations. This tool is designed for daily health checks and troubleshooting network connectivity issues in OpenShift Container Platform (OCP) environments.

## Overview

This script automates the manual process of checking connectivity from each OpenShift node to a target destination by:
1. Discovering all nodes in the cluster
2. Debugging into each node using `oc debug node`
3. Testing connectivity using `curl telnet://`
4. Generating detailed logs and summary reports

## Features

- ✅ **Interactive & Non-Interactive Modes** - Run manually or schedule via cron
- ✅ **Comprehensive Testing** - Tests all node types (master, infra, worker)
- ✅ **Detailed Logging** - Timestamped logs with full curl output
- ✅ **Formatted Output** - Clean table display with color-coded results
- ✅ **Error Handling** - Robust error detection and cleanup
- ✅ **Progress Indicators** - Real-time progress during execution
- ✅ **Summary Statistics** - Success rate and node counts

## Prerequisites

### System Requirements
- **OS**: RHEL 8 x64 (or compatible Linux distribution)
- **OpenShift**: Version 4.16 or later
- **Shell**: Bash 4.0 or later

### Required Tools
- OpenShift CLI (`oc`) installed and in PATH
- Active login session to OpenShift cluster
- Permissions to run `oc debug node` commands
- Permissions to run `oc get nodes`

### Verify Prerequisites

```bash
# Check if oc is installed
which oc

# Check if logged into cluster
oc whoami

# Check if you can list nodes
oc get nodes

# Check if you can debug a node (test with one node)
oc debug node/<any-node-name> -- echo "Test"
```

## Installation

### 1. Download the Script

```bash
# Clone the repository
cd /path/to/your/workspace
git clone <repository-url>
cd ocp-node-connectivity-checker

# Or download directly
wget https://raw.githubusercontent.com/<your-repo>/ocp-connectivity-checker.sh
```

### 2. Make Script Executable

```bash
chmod +x ocp-connectivity-checker.sh
```

### 3. Verify Installation

```bash
./ocp-connectivity-checker.sh --help
```

## Usage

### Interactive Mode

Run the script without arguments to be prompted for destination and port:

```bash
./ocp-connectivity-checker.sh
```

**Example Session:**
```
=================================================
  OpenShift Node Communication Checker
  Version 1.0
=================================================

ℹ Checking prerequisites...
✓ OpenShift CLI (oc) found
✓ Logged into OpenShift cluster
✓ Connected to cluster: https://api.ocp-dmz.example.internal:6443

Enter destination hostname or IP: payments-gateway.example.internal
Enter destination port: 8281

ℹ Validating inputs...
✓ Destination: payments-gateway.example.internal
✓ Port: 8281

✓ Log directory created: logs/ocp-connectivity-check_2025-10-15_16-30-45

ℹ Discovering OpenShift nodes...
✓ Found 17 nodes (3 master, 3 infra, 11 worker)

ℹ Testing connectivity from all nodes...

[1/17] Testing etcd-0... Success ✓
[2/17] Testing etcd-1... Success ✓
[3/17] Testing etcd-2... Success ✓
...
```

### Non-Interactive Mode

For automation (cron jobs), provide all parameters via command-line arguments:

```bash
./ocp-connectivity-checker.sh \
  --destination payments-gateway.example.internal \
  --port 8281 \
  --non-interactive
```

**Short form:**
```bash
./ocp-connectivity-checker.sh -d payments-gateway.example.internal -p 8281 -n
```

### Command-Line Options

| Option | Short | Description | Required |
|--------|-------|-------------|----------|
| `--destination` | `-d` | Target hostname or IP address | Yes (in non-interactive mode) |
| `--port` | `-p` | Target port number (1-65535) | Yes (in non-interactive mode) |
| `--non-interactive` | `-n` | Skip prompts, use provided values | No |
| `--help` | `-h` | Display help message | No |

## Output

### Terminal Output

The script displays a formatted table with results:

```
=================================================
  CONNECTIVITY TEST RESULTS
=================================================

+----------------------+---------------+--------------------------------+------+----------+
| Node Hostname        | Node IP       | Destination                    | Port | Result   |
+----------------------+---------------+--------------------------------+------+----------+
| etcd-0               | 10.0.1.101  | payments-gateway...      | 8281 | Success  |
| etcd-1               | 10.0.1.102  | payments-gateway...      | 8281 | Success  |
| etcd-2               | 10.0.1.103  | payments-gateway...      | 8281 | Success  |
| infra1               | 10.0.1.105  | payments-gateway...      | 8281 | Success  |
| infra2               | 10.0.1.106  | payments-gateway...      | 8281 | Failed   |
| infra3               | 10.0.1.107  | payments-gateway...      | 8281 | Success  |
| worker1              | 10.0.1.108  | payments-gateway...      | 8281 | Success  |
| worker2              | 10.0.1.109  | payments-gateway...      | 8281 | Success  |
...
+----------------------+---------------+--------------------------------+------+----------+

=========================================
  SUMMARY STATISTICS
=========================================
Total Nodes:      17
Successful:       15
Failed:           2
Success Rate:     88%
=========================================

✓ Detailed logs saved to: logs/ocp-connectivity-check_2025-10-15_16-30-45/connectivity-check.log
```

### Log Files

Log files are created in timestamped directories:

```
logs/
└── ocp-connectivity-check_2025-10-15_16-30-45/
    └── connectivity-check.log
```

**Log File Content:**
- Timestamp for each operation
- Full curl output for each node test
- Success/failure indicators
- Error messages and stack traces
- Summary statistics

**Example Log Entry:**
```
[2025-10-15 16:30:55] INFO: Testing node 1/17: etcd-0.ocp-dmz.example.internal (10.0.1.101)
[2025-10-15 16:30:57] DEBUG: Executing: oc debug node/etcd-0.ocp-dmz.example.internal
[2025-10-15 16:31:00] DEBUG: curl output:
*   Trying 10.0.120.82:8281...
* Connected to payments-gateway.example.internal (10.0.120.82) port 8281 (#0)
Warning: Binary output can mess up your terminal...
* Failure writing output to destination
* Closing connection 0
[2025-10-15 16:31:00] SUCCESS: Node etcd-0 - Connectivity SUCCESS
```

## Daily Automation with Cron

### Setup Cron Job

1. **Edit crontab:**
   ```bash
   crontab -e
   ```

2. **Add cron entry for daily 2:00 AM execution:**
   ```bash
   # OpenShift Connectivity Check - Runs daily at 2:00 AM
   0 2 * * * /path/to/ocp-connectivity-checker.sh \
     -d payments-gateway.example.internal \
     -p 8281 \
     -n \
     >> /var/log/ocp-connectivity-cron.log 2>&1
   ```

3. **Verify cron job:**
   ```bash
   crontab -l
   ```

### Multiple Destinations

Test multiple destinations by running the script multiple times:

```bash
#!/bin/bash
# daily-connectivity-checks.sh

DESTINATIONS=(
  "payments-gateway.example.internal:8281"
  "anotherservice.example.internal:443"
  "thirdservice.example.internal:8080"
)

for dest in "${DESTINATIONS[@]}"; do
  IFS=':' read -r hostname port <<< "$dest"
  /path/to/ocp-connectivity-checker.sh -d "$hostname" -p "$port" -n
done
```

Schedule this wrapper script:
```bash
0 2 * * * /path/to/daily-connectivity-checks.sh >> /var/log/ocp-connectivity-cron.log 2>&1
```

## Understanding Results

### Success Indicators

The script considers connectivity **successful** when curl output contains:
```
* Connected to <destination> (<ip>) port <port> (#0)
```

### Failure Indicators

The script detects various failure scenarios:

| Error Message | Meaning |
|---------------|---------|
| `Could not resolve host` | DNS resolution failed |
| `Connection refused` | Port is closed or service not listening |
| `Connection timed out` | Network timeout (firewall, routing issue) |
| `No route to host` | Routing problem |
| `Network unreachable` | Network configuration issue |
| `Timeout` | Operation exceeded timeout limit (60 seconds) |

## Troubleshooting

### Issue: "OpenShift CLI (oc) is not installed"

**Solution:**
```bash
# Download and install oc CLI
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
tar -xzf openshift-client-linux.tar.gz
sudo mv oc /usr/local/bin/
sudo chmod +x /usr/local/bin/oc
```

### Issue: "Not logged into OpenShift cluster"

**Solution:**
```bash
# Login to your cluster
oc login https://api.your-cluster.example.com:6443 --token=<your-token>

# Or with username/password
oc login https://api.your-cluster.example.com:6443 -u <username> -p <password>
```

### Issue: "Cannot list nodes - insufficient permissions"

**Solution:**
Request cluster-reader role or higher from your cluster administrator:
```bash
# Admin must run:
oc adm policy add-cluster-role-to-user cluster-reader <your-username>
```

### Issue: Script hangs during node testing

**Possible Causes:**
1. Node is unreachable
2. Network timeout
3. Debug pod creation failure

**Solution:**
- Script has built-in timeouts (60s for oc debug, 15s for curl)
- Check logs for specific node causing issue
- Manually test problematic node:
  ```bash
  oc debug node/<problem-node> -- chroot /host bash
  ```

### Issue: Debug pods not cleaned up

**Solution:**
Debug pods are automatically cleaned up when they exit. If orphaned pods remain:
```bash
# List debug pods
oc get pods -A | grep debug

# Delete specific debug pod
oc delete pod <pod-name> -n <namespace>

# Clean all debug pods (use with caution)
oc get pods -A | grep "debug" | awk '{print $2 " -n " $1}' | xargs -r oc delete pod
```

## Advanced Usage

### Testing with IP Address

```bash
./ocp-connectivity-checker.sh -d 10.0.120.82 -p 8281 -n
```

### Testing Different Ports

```bash
# HTTPS (443)
./ocp-connectivity-checker.sh -d example.com -p 443 -n

# Custom application port
./ocp-connectivity-checker.sh -d example.com -p 9090 -n
```

### Redirecting Output

```bash
# Save terminal output to file
./ocp-connectivity-checker.sh -d example.com -p 8281 -n 2>&1 | tee check-output.txt

# Silent mode (only logs to file)
./ocp-connectivity-checker.sh -d example.com -p 8281 -n > /dev/null 2>&1
```

### Custom Timeout Settings

Edit the script to modify timeout values:

```bash
# Edit ocp-connectivity-checker.sh
readonly OC_DEBUG_TIMEOUT=60   # Increase if nodes are slow
readonly CURL_TIMEOUT=15       # Increase for slow networks
```

## Script Architecture

### Main Components

1. **Configuration Section**
   - Timeout settings
   - Color definitions
   - Global variables

2. **Helper Functions**
   - `validate_port()` - Validate port range
   - `validate_destination()` - Validate destination input
   - `check_prerequisites()` - Verify oc CLI and cluster access
   - `get_all_nodes()` - Discover all cluster nodes
   - `test_node_connectivity()` - Test single node connectivity
   - `parse_curl_output()` - Parse curl results
   - `display_summary_table()` - Format output table

3. **Main Execution Flow**
   - Parse command-line arguments
   - Validate inputs
   - Create log directory
   - Test each node sequentially
   - Display results and statistics

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All nodes tested successfully |
| 1 | One or more nodes failed connectivity test |
| 130 | Script interrupted by user (Ctrl+C) |

## Security Considerations

- Script requires read-only cluster access
- No credentials are stored
- Debug pods run with default security context
- All operations are logged
- Suitable for use in secure/production environments

## Performance

- **Sequential Execution**: Tests nodes one at a time to avoid cluster overload
- **Timeouts**: Each node test has 60-second limit
- **Estimated Duration**: ~2-5 minutes for 20 nodes (depending on network conditions)

## Examples

### Example 1: Basic Connectivity Check

```bash
$ ./ocp-connectivity-checker.sh

Enter destination hostname or IP: api.example.com
Enter destination port: 443

✓ Found 10 nodes (3 master, 2 infra, 5 worker)
Testing connectivity...
[10/10] Testing worker5... Success ✓

Success Rate: 100%
```

### Example 2: Testing Internal Service

```bash
$ ./ocp-connectivity-checker.sh \
  -d internal-db.cluster.local \
  -p 5432 \
  -n
```

### Example 3: Scheduled Daily Check

Create wrapper script:
```bash
#!/bin/bash
# /usr/local/bin/daily-ocp-check.sh

LOG_DIR="/var/log/ocp-checks"
DATE=$(date +%Y-%m-%d)

/opt/scripts/ocp-connectivity-checker.sh \
  -d payments-gateway.example.internal \
  -p 8281 \
  -n \
  | tee "${LOG_DIR}/check-${DATE}.log"

# Send email notification if failures detected
if [ $? -ne 0 ]; then
  mail -s "OCP Connectivity Check Failed" admin@example.com < "${LOG_DIR}/check-${DATE}.log"
fi
```

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

## Support

For issues or questions:
- Check the [Troubleshooting](#troubleshooting) section
- Review the detailed logs in `logs/` directory
- Contact your OpenShift administrator
- Open an issue in the repository

## License

This project is licensed under the MIT License - see LICENSE file for details.

## Changelog

### Version 1.0 (2025-10-15)
- Initial release
- Interactive and non-interactive modes
- Comprehensive logging
- Color-coded output
- Summary statistics
- Error handling and cleanup

## Related Documentation

- [OpenShift CLI Reference](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)
- [oc debug node Documentation](https://docs.openshift.com/container-platform/latest/support/troubleshooting/investigating-pod-issues.html)
- [Network Troubleshooting in OpenShift](https://docs.openshift.com/container-platform/latest/support/troubleshooting/troubleshooting-network-issues.html)

---

**Author:** OpenShift Infrastructure Team
**Version:** 1.0
**Last Updated:** 2025-10-15
