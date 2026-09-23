#!/bin/bash
set -euo pipefail

if [ -z "${SVC_NAME:-}" ]; then
  echo "Error: SVC_NAME environment variable is not set." >&2
  exit 1
fi

MOUNT_POINT="/mnt/${SVC_NAME}_tmp"

echo "=== Setting up tmpfs scratch storage for $SVC_NAME ==="

# 1. Create mount directory if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
  echo "Creating mount directory $MOUNT_POINT..."
  sudo mkdir -p "$MOUNT_POINT"
fi

# 2. Mount tmpfs with size cap if not already mounted (idempotency)
if mountpoint -q "$MOUNT_POINT"; then
  echo "$MOUNT_POINT is already mounted."
else
  echo "Mounting tmpfs (size=256M) on $MOUNT_POINT..."
  sudo mount -t tmpfs -o size=256M tmpfs "$MOUNT_POINT"
fi

# 3. Restrict ownership to the service identity
echo "Setting ownership to $SVC_NAME:$SVC_NAME..."
sudo chown "$SVC_NAME:$SVC_NAME" "$MOUNT_POINT"

# 4. Display filesystem details
echo "=== Storage Details ==="
df -h "$MOUNT_POINT"
