#!/bin/bash
set -euo pipefail

if [ -z "${SVC_NAME:-}" ]; then
  echo "Error: SVC_NAME environment variable is not set." >&2
  exit 1
fi

# Check if user already exists (idempotency)
if id "$SVC_NAME" &>/dev/null; then
  echo "User $SVC_NAME already exists. Skipping creation."
else
  echo "Creating service user: $SVC_NAME"
  sudo useradd -r -m -s /usr/sbin/nologin "$SVC_NAME"
  echo "User $SVC_NAME created successfully."
fi

# Display user details
id "$SVC_NAME"
getent passwd "$SVC_NAME"
