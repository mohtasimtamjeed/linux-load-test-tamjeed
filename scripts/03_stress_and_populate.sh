#!/bin/bash
set -euo pipefail

if [ -z "${SVC_NAME:-}" ]; then
  echo "Error: SVC_NAME environment variable is not set." >&2
  exit 1
fi

MOUNT_POINT="/mnt/${SVC_NAME}_tmp"

stress_disk() {
  echo "=== [Stress: Disk] Filling tmpfs scratch space ==="
  for i in $(seq 30); do
    if ! sudo -u "$SVC_NAME" dd if=/dev/urandom of="$MOUNT_POINT/file_$i.dat" bs=10M count=1 status=none 2>/dev/null; then
      echo "Disk write stopped as expected: filesystem capacity reached."
      break
    fi
  done
  df -h "$MOUNT_POINT"
}

stress_cpu() {
  echo "=== [Stress: CPU] Running 2 CPU workers for 30s as $SVC_NAME ==="
  sudo -u "$SVC_NAME" stress-ng --cpu 2 --timeout 30s --metrics-brief
}

stress_mem() {
  echo "=== [Stress: Memory] Allocating 200M virtual memory for 30s as $SVC_NAME ==="
  sudo -u "$SVC_NAME" stress-ng --vm 1 --vm-bytes 200M --timeout 30s --metrics-brief
}

stress_all() {
  echo "=== [Stress: Combined] Executing Disk, CPU, and Memory load simultaneously ==="
  stress_disk
  echo "Spawning background CPU stress..."
  sudo -u "$SVC_NAME" stress-ng --cpu 2 --timeout 30s &
  echo "Spawning background Memory stress..."
  sudo -u "$SVC_NAME" stress-ng --vm 1 --vm-bytes 200M --timeout 30s &
  wait
  echo "Combined stress test completed."
}

case "${1:-}" in
  --disk)
    stress_disk
    ;;
  --cpu)
    stress_cpu
    ;;
  --mem)
    stress_mem
    ;;
  --all)
    stress_all
    ;;
  *)
    echo "Usage: $0 {--cpu|--mem|--disk|--all}"
    exit 1
    ;;
esac
