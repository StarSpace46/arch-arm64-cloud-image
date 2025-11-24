#!/bin/bash
set -e
echo "=== Final cleanup ==="

# Clear package cache
pacman -Scc --noconfirm

# Clear logs
find /var/log -type f -delete
journalctl --vacuum-time=1s 2>/dev/null || true

# Clear temporary files
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clear machine-id (cloud-init will regenerate)
truncate -s 0 /etc/machine-id

# Clear SSH host keys (cloud-init will regenerate)
rm -f /etc/ssh/ssh_host_*

# Clear bash history
rm -f /root/.bash_history
rm -f /home/alarm/.bash_history 2>/dev/null || true
history -c 2>/dev/null || true

echo "=== Cleanup complete ==="
