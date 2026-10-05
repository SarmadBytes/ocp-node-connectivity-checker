# Quick Start Guide

Get started with the OpenShift Node Communication Checker in 5 minutes!

## Prerequisites Check

Before running the script, ensure you have:

```bash
# 1. OpenShift CLI installed
oc version

# 2. Logged into your OpenShift cluster
oc whoami

# 3. Can list nodes
oc get nodes
```

If any command fails, refer to the [README.md](README.md#prerequisites) for setup instructions.

---

## Installation

### Step 1: Make Script Executable

```bash
chmod +x ocp-connectivity-checker.sh
```

### Step 2: Run Your First Check

```bash
./ocp-connectivity-checker.sh
```

When prompted:
- **Destination:** Enter hostname or IP (e.g., `payments-gateway.example.internal`)
- **Port:** Enter port number (e.g., `8281`)

### Step 3: View Results

The script will:
1. Test connectivity from all nodes
2. Display a formatted table with results
3. Save detailed logs to `logs/ocp-connectivity-check_<timestamp>/`

---

## Example Run

```bash
$ ./ocp-connectivity-checker.sh

=================================================
  OpenShift Node Communication Checker
  Version 1.0
=================================================

ℹ Checking prerequisites...
✓ OpenShift CLI (oc) found
✓ Logged into OpenShift cluster

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
...
[17/17] Testing worker11... Success ✓

=================================================
  CONNECTIVITY TEST RESULTS
=================================================

+----------------------+---------------+--------------------------------+------+----------+
| Node Hostname        | Node IP       | Destination                    | Port | Result   |
+----------------------+---------------+--------------------------------+------+----------+
| etcd-0               | 10.0.1.101  | payments-gateway...      | 8281 | Success  |
| etcd-1               | 10.0.1.102  | payments-gateway...      | 8281 | Success  |
...
+----------------------+---------------+--------------------------------+------+----------+

=========================================
  SUMMARY STATISTICS
=========================================
Total Nodes:      17
Successful:       17
Failed:           0
Success Rate:     100%
=========================================

✓ Detailed logs saved to: logs/ocp-connectivity-check_2025-10-15_16-30-45/connectivity-check.log
```

---

## Non-Interactive Mode (For Automation)

Run without prompts:

```bash
./ocp-connectivity-checker.sh \
  --destination payments-gateway.example.internal \
  --port 8281 \
  --non-interactive
```

Short form:
```bash
./ocp-connectivity-checker.sh -d payments-gateway.example.internal -p 8281 -n
```

---

## Daily Automation (Cron)

### Quick Cron Setup

1. **Edit crontab:**
   ```bash
   crontab -e
   ```

2. **Add this line (runs daily at 2:00 AM):**
   ```bash
   0 2 * * * /full/path/to/ocp-connectivity-checker.sh -d payments-gateway.example.internal -p 8281 -n >> /var/log/ocp-connectivity.log 2>&1
   ```

3. **Save and verify:**
   ```bash
   crontab -l
   ```

For advanced scheduling options, see [examples/cron-setup.md](examples/cron-setup.md).

---

## Common Use Cases

### Use Case 1: Test Specific Service

```bash
./ocp-connectivity-checker.sh -d api.internal.example.com -p 443 -n
```

### Use Case 2: Test Database Connection

```bash
./ocp-connectivity-checker.sh -d database.internal.example.com -p 5432 -n
```

### Use Case 3: Test by IP Address

```bash
./ocp-connectivity-checker.sh -d 10.0.120.82 -p 8281 -n
```

---

## Interpreting Results

### Success ✓
- Node can reach destination
- Port is open and accepting connections
- Network path is clear

### Failed ✗
Common failure reasons:
- **Connection refused** - Port is closed or service not running
- **Connection timed out** - Firewall blocking or network issue
- **Could not resolve host** - DNS problem
- **No route to host** - Routing issue

---

## Viewing Detailed Logs

```bash
# List all log directories
ls -ltr logs/

# View latest log file
cat logs/ocp-connectivity-check_*/connectivity-check.log | tail -100

# Search for failures in logs
grep "FAILED" logs/ocp-connectivity-check_*/connectivity-check.log
```

---

## Getting Help

### Command-Line Help
```bash
./ocp-connectivity-checker.sh --help
```

### Full Documentation
- [README.md](README.md) - Complete documentation
- [Plan.md](Plan.md) - Implementation details
- [examples/cron-setup.md](examples/cron-setup.md) - Automation guide
- [examples/example-output.txt](examples/example-output.txt) - Sample output

### Troubleshooting

**Problem: "OpenShift CLI (oc) is not installed"**
```bash
# Install oc CLI
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
tar -xzf openshift-client-linux.tar.gz
sudo mv oc /usr/local/bin/
```

**Problem: "Not logged into OpenShift cluster"**
```bash
# Login to cluster
oc login https://api.your-cluster.example.com:6443
```

**Problem: "Cannot list nodes - insufficient permissions"**
```bash
# Contact your cluster admin to grant cluster-reader role
# Admin runs: oc adm policy add-cluster-role-to-user cluster-reader <your-username>
```

---

## Next Steps

1. ✅ Run your first connectivity check
2. ✅ Review the logs to understand output format
3. ✅ Set up daily cron job for automated checks
4. ✅ Configure email notifications for failures
5. ✅ Document your specific destinations and schedules

---

## Quick Reference

| Task | Command |
|------|---------|
| Interactive run | `./ocp-connectivity-checker.sh` |
| Non-interactive | `./ocp-connectivity-checker.sh -d host -p port -n` |
| Show help | `./ocp-connectivity-checker.sh --help` |
| View logs | `cat logs/ocp-connectivity-check_*/connectivity-check.log` |
| Check cron | `crontab -l` |
| Edit cron | `crontab -e` |

---

**Need more details?** See [README.md](README.md) for comprehensive documentation.

**Last Updated:** 2025-10-15
