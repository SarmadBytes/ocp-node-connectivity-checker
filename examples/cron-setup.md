# Cron Job Setup Guide

This guide explains how to schedule the OpenShift Communication Checker script to run automatically on a daily basis.

## Table of Contents
- [Basic Cron Setup](#basic-cron-setup)
- [Advanced Scheduling](#advanced-scheduling)
- [Email Notifications](#email-notifications)
- [Log Rotation](#log-rotation)
- [Troubleshooting](#troubleshooting)

---

## Basic Cron Setup

### Single Destination - Daily at 2:00 AM

1. **Edit your crontab:**
   ```bash
   crontab -e
   ```

2. **Add the following line:**
   ```bash
   # OpenShift Connectivity Check - Daily at 2:00 AM
   0 2 * * * /path/to/ocp-connectivity-checker.sh -d payments-gateway.example.internal -p 8281 -n >> /var/log/ocp-connectivity-cron.log 2>&1
   ```

3. **Replace `/path/to/` with actual script path:**
   ```bash
   # Example with full path
   0 2 * * * /opt/scripts/ocp-connectivity-checker.sh -d payments-gateway.example.internal -p 8281 -n >> /var/log/ocp-connectivity-cron.log 2>&1
   ```

4. **Save and verify:**
   ```bash
   # List current cron jobs
   crontab -l
   ```

### Understanding the Cron Expression

```
0 2 * * * /path/to/script.sh
│ │ │ │ │
│ │ │ │ └─── Day of week (0-7, Sunday = 0 or 7)
│ │ │ └───── Month (1-12)
│ │ └─────── Day of month (1-31)
│ └───────── Hour (0-23)
└─────────── Minute (0-59)
```

**Examples:**
```bash
# Every day at 2:00 AM
0 2 * * *

# Every day at midnight
0 0 * * *

# Every 6 hours
0 */6 * * *

# Every Monday at 9:00 AM
0 9 * * 1

# First day of every month at 3:00 AM
0 3 1 * *
```

---

## Advanced Scheduling

### Multiple Destinations

Create a wrapper script to test multiple destinations:

1. **Create wrapper script:**
   ```bash
   sudo nano /opt/scripts/daily-connectivity-checks.sh
   ```

2. **Add content:**
   ```bash
   #!/bin/bash

   # Array of destinations to check (format: hostname:port)
   DESTINATIONS=(
     "payments-gateway.example.internal:8281"
     "api.internal.example.com:443"
     "database.internal.example.com:5432"
     "kafka.internal.example.com:9092"
   )

   SCRIPT_PATH="/opt/scripts/ocp-connectivity-checker.sh"
   LOG_DIR="/var/log/ocp-connectivity"
   DATE=$(date +%Y-%m-%d_%H-%M-%S)

   # Create log directory if it doesn't exist
   mkdir -p "$LOG_DIR"

   echo "=========================================="
   echo "Starting connectivity checks: $DATE"
   echo "=========================================="

   # Loop through each destination
   for dest in "${DESTINATIONS[@]}"; do
     IFS=':' read -r hostname port <<< "$dest"

     echo ""
     echo "Testing: $hostname:$port"
     echo "----------------------------------------"

     "$SCRIPT_PATH" -d "$hostname" -p "$port" -n

     echo ""
   done

   echo "=========================================="
   echo "Completed connectivity checks: $(date +%Y-%m-%d_%H-%M-%S)"
   echo "=========================================="
   ```

3. **Make executable:**
   ```bash
   sudo chmod +x /opt/scripts/daily-connectivity-checks.sh
   ```

4. **Schedule wrapper script:**
   ```bash
   crontab -e
   ```

   Add:
   ```bash
   # Multiple destination checks - Daily at 2:00 AM
   0 2 * * * /opt/scripts/daily-connectivity-checks.sh >> /var/log/ocp-connectivity/daily-checks.log 2>&1
   ```

### Different Schedules for Different Destinations

```bash
# Critical service - Every 4 hours
0 */4 * * * /opt/scripts/ocp-connectivity-checker.sh -d critical-api.example.com -p 443 -n >> /var/log/ocp-connectivity/critical.log 2>&1

# Standard service - Daily at 2:00 AM
0 2 * * * /opt/scripts/ocp-connectivity-checker.sh -d standard-api.example.com -p 8080 -n >> /var/log/ocp-connectivity/standard.log 2>&1

# Development service - Weekly on Monday at 1:00 AM
0 1 * * 1 /opt/scripts/ocp-connectivity-checker.sh -d dev-api.example.com -p 8080 -n >> /var/log/ocp-connectivity/dev.log 2>&1
```

---

## Email Notifications

### Using mailx/mail Command

1. **Install mailx (if not already installed):**
   ```bash
   # RHEL/CentOS 8
   sudo dnf install mailx

   # Ubuntu/Debian
   sudo apt-get install mailutils
   ```

2. **Create notification wrapper:**
   ```bash
   sudo nano /opt/scripts/ocp-connectivity-with-email.sh
   ```

3. **Add content:**
   ```bash
   #!/bin/bash

   SCRIPT_PATH="/opt/scripts/ocp-connectivity-checker.sh"
   DESTINATION="payments-gateway.example.internal"
   PORT="8281"
   EMAIL_TO="admin@example.com"
   EMAIL_SUBJECT="OCP Connectivity Check - $(date +%Y-%m-%d)"
   LOG_FILE="/tmp/ocp-connectivity-check-$$.log"

   # Run the connectivity check and capture output
   "$SCRIPT_PATH" -d "$DESTINATION" -p "$PORT" -n > "$LOG_FILE" 2>&1
   EXIT_CODE=$?

   # Send email based on result
   if [ $EXIT_CODE -eq 0 ]; then
     # Success - send summary only
     echo "All nodes successfully connected to $DESTINATION:$PORT" | \
       mail -s "$EMAIL_SUBJECT - SUCCESS" "$EMAIL_TO"
   else
     # Failure - send full log
     mail -s "$EMAIL_SUBJECT - FAILED" "$EMAIL_TO" < "$LOG_FILE"
   fi

   # Cleanup
   rm -f "$LOG_FILE"

   exit $EXIT_CODE
   ```

4. **Make executable:**
   ```bash
   sudo chmod +x /opt/scripts/ocp-connectivity-with-email.sh
   ```

5. **Schedule:**
   ```bash
   0 2 * * * /opt/scripts/ocp-connectivity-with-email.sh
   ```

### Using Slack Notifications

1. **Create Slack webhook wrapper:**
   ```bash
   sudo nano /opt/scripts/ocp-connectivity-slack-notify.sh
   ```

2. **Add content:**
   ```bash
   #!/bin/bash

   SCRIPT_PATH="/opt/scripts/ocp-connectivity-checker.sh"
   DESTINATION="payments-gateway.example.internal"
   PORT="8281"
   SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

   # Run connectivity check
   OUTPUT=$("$SCRIPT_PATH" -d "$DESTINATION" -p "$PORT" -n 2>&1)
   EXIT_CODE=$?

   # Extract summary from output
   SUMMARY=$(echo "$OUTPUT" | grep -A 5 "SUMMARY STATISTICS")

   # Determine status and color
   if [ $EXIT_CODE -eq 0 ]; then
     STATUS="SUCCESS"
     COLOR="good"
   else
     STATUS="FAILED"
     COLOR="danger"
   fi

   # Send to Slack
   curl -X POST "$SLACK_WEBHOOK" \
     -H 'Content-Type: application/json' \
     -d "{
       \"attachments\": [{
         \"color\": \"$COLOR\",
         \"title\": \"OCP Connectivity Check - $STATUS\",
         \"text\": \"Destination: $DESTINATION:$PORT\",
         \"fields\": [{
           \"title\": \"Summary\",
           \"value\": \"\`\`\`$SUMMARY\`\`\`\",
           \"short\": false
         }],
         \"footer\": \"OpenShift Infrastructure\",
         \"ts\": $(date +%s)
       }]
     }"
   ```

3. **Schedule:**
   ```bash
   0 2 * * * /opt/scripts/ocp-connectivity-slack-notify.sh
   ```

---

## Log Rotation

Prevent log files from growing too large:

### Method 1: Using logrotate

1. **Create logrotate configuration:**
   ```bash
   sudo nano /etc/logrotate.d/ocp-connectivity
   ```

2. **Add content:**
   ```conf
   /var/log/ocp-connectivity/*.log {
       daily
       rotate 30
       compress
       delaycompress
       missingok
       notifempty
       create 0644 root root
   }
   ```

3. **Test configuration:**
   ```bash
   sudo logrotate -d /etc/logrotate.d/ocp-connectivity
   ```

### Method 2: Manual Cleanup in Cron

```bash
# Clean up logs older than 30 days - Daily at 3:00 AM
0 3 * * * find /path/to/logs/ocp-connectivity-check_* -type d -mtime +30 -exec rm -rf {} + 2>/dev/null
```

---

## Complete Example Setup

Here's a complete setup for production use:

### 1. Directory Structure
```bash
sudo mkdir -p /opt/ocp-scripts
sudo mkdir -p /var/log/ocp-connectivity
sudo mkdir -p /var/log/ocp-connectivity/archive
```

### 2. Install Script
```bash
sudo cp ocp-connectivity-checker.sh /opt/ocp-scripts/
sudo chmod +x /opt/ocp-scripts/ocp-connectivity-checker.sh
```

### 3. Create Main Wrapper Script
```bash
sudo nano /opt/ocp-scripts/daily-checks.sh
```

Content:
```bash
#!/bin/bash

SCRIPT_DIR="/opt/ocp-scripts"
LOG_DIR="/var/log/ocp-connectivity"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H-%M-%S)
EMAIL="admin@example.com"

# Test primary destination
echo "[$TIME] Starting connectivity checks..." >> "$LOG_DIR/cron.log"

"$SCRIPT_DIR/ocp-connectivity-checker.sh" \
  -d payments-gateway.example.internal \
  -p 8281 \
  -n \
  >> "$LOG_DIR/daily-$DATE.log" 2>&1

EXIT_CODE=$?

# Send notification if failed
if [ $EXIT_CODE -ne 0 ]; then
  echo "Connectivity check FAILED on $DATE" | \
    mail -s "OCP Connectivity Alert - FAILED" "$EMAIL"
fi

echo "[$TIME] Checks completed with exit code: $EXIT_CODE" >> "$LOG_DIR/cron.log"

exit $EXIT_CODE
```

```bash
sudo chmod +x /opt/ocp-scripts/daily-checks.sh
```

### 4. Setup Crontab
```bash
sudo crontab -e
```

Add:
```bash
# OpenShift connectivity checks - Daily at 2:00 AM
0 2 * * * /opt/ocp-scripts/daily-checks.sh

# Clean old logs - Daily at 4:00 AM
0 4 * * * find /var/log/ocp-connectivity/logs/ -type d -mtime +30 -exec rm -rf {} + 2>/dev/null

# Archive monthly reports - 1st of each month at 5:00 AM
0 5 1 * * tar -czf /var/log/ocp-connectivity/archive/logs-$(date +\%Y-\%m).tar.gz /var/log/ocp-connectivity/daily-*.log && rm -f /var/log/ocp-connectivity/daily-*.log
```

---

## Troubleshooting

### Cron Job Not Running

1. **Check cron service status:**
   ```bash
   sudo systemctl status crond  # RHEL/CentOS
   sudo systemctl status cron   # Ubuntu/Debian
   ```

2. **Check cron logs:**
   ```bash
   sudo tail -f /var/log/cron      # RHEL/CentOS
   sudo tail -f /var/log/syslog    # Ubuntu/Debian
   ```

3. **Verify crontab syntax:**
   ```bash
   crontab -l
   ```

### Script Runs Manually But Not via Cron

**Issue:** Environment variables might be missing in cron context.

**Solution:** Use full paths and set environment variables explicitly:

```bash
# Add to crontab
PATH=/usr/local/bin:/usr/bin:/bin
KUBECONFIG=/home/user/.kube/config

0 2 * * * /opt/scripts/ocp-connectivity-checker.sh -d example.com -p 8281 -n
```

### Permission Issues

```bash
# Ensure script is executable
chmod +x /opt/scripts/ocp-connectivity-checker.sh

# Ensure log directory is writable
sudo chown -R $USER:$USER /var/log/ocp-connectivity
```

### OC Login Session Expires

**Problem:** `oc` token expires between cron runs.

**Solution 1 - Service Account Token (Recommended):**
```bash
# Create service account
oc create sa connectivity-checker

# Grant permissions
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:default:connectivity-checker

# Get token
TOKEN=$(oc sa get-token connectivity-checker)

# Use in script
oc login --token=$TOKEN https://api.your-cluster.com:6443
```

**Solution 2 - Re-login in Cron Script:**
```bash
#!/bin/bash

# Login before running checks
oc login https://api.your-cluster.com:6443 --token=$OC_TOKEN

# Run connectivity checks
/opt/scripts/ocp-connectivity-checker.sh -d example.com -p 8281 -n
```

---

## Best Practices

1. **Use Non-Interactive Mode** for cron jobs (always use `-n` flag)
2. **Redirect Output** to log files for troubleshooting
3. **Set Email Notifications** for failures
4. **Implement Log Rotation** to prevent disk space issues
5. **Use Full Paths** in cron entries
6. **Test Manually First** before scheduling
7. **Monitor Cron Logs** regularly
8. **Set Proper Permissions** on scripts and log directories
9. **Use Service Accounts** for long-running automation
10. **Document Your Setup** for team members

---

## Monitoring Cron Execution

### Check Last Execution Time
```bash
# View cron log
sudo grep "ocp-connectivity-checker" /var/log/cron
```

### Create Status Check Script
```bash
#!/bin/bash
# check-cron-status.sh

LOG_FILE="/var/log/ocp-connectivity/daily-$(date +%Y-%m-%d).log"

if [ -f "$LOG_FILE" ]; then
  echo "Last run: $(date -r "$LOG_FILE")"
  grep -A 3 "SUMMARY STATISTICS" "$LOG_FILE"
else
  echo "No log file found for today"
fi
```

---

## Additional Resources

- [Crontab Guru](https://crontab.guru/) - Cron expression generator
- [RHEL Cron Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_basic_system_settings/scheduling-tasks_configuring-basic-system-settings)
- [OpenShift Service Accounts](https://docs.openshift.com/container-platform/latest/authentication/using-service-accounts-in-applications.html)

---

**Last Updated:** 2025-10-15
**Version:** 1.0
