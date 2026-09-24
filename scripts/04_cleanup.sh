#!/bin/bash
set -u

if [ -z "${SVC_NAME:-}" ]; then
  echo "Error: SVC_NAME environment variable is not set." >&2
  exit 1
fi

MOUNT_POINT="/mnt/${SVC_NAME}_tmp"
LOG_DIR="/var/log/${SVC_NAME}"

echo "=== Starting Teardown for Service: $SVC_NAME ==="

# 1. Terminate all running processes owned by the user
echo "[1/5] Terminating active processes owned by $SVC_NAME..."
sudo pkill -u "$SVC_NAME" 2>/dev/null || true
sleep 1

# 2. Remove scheduled cron automation and monitoring scripts
echo "[2/5] Removing scheduled cron automation, scripts, and logrotate configs..."
sudo crontab -r -u "$SVC_NAME" 2>/dev/null || true
sudo rm -f "/etc/logrotate.d/${SVC_NAME}"
sudo rm -f "/usr/local/bin/${SVC_NAME}_monitor.sh"
sudo rm -f "/usr/local/bin/${SVC_NAME}_cleanup_old_files.sh"

# 3. Unmount scratch storage safely
echo "[3/5] Unmounting and purging scratch storage..."
if mountpoint -q "$MOUNT_POINT"; then
  sudo umount "$MOUNT_POINT"
fi
if [ -d "$MOUNT_POINT" ]; then
  sudo rmdir "$MOUNT_POINT"
fi

# 4. Remove log directories
echo "[4/5] Removing log files and directories..."
sudo rm -rf "$LOG_DIR"

# 5. Remove service user identity and home directory
echo "[5/5] Purging service identity and home path..."
if id "$SVC_NAME" &>/dev/null; then
  sudo userdel -r "$SVC_NAME" 2>/dev/null || true
fi

echo "=== Teardown Complete ==="
