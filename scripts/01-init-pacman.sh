#!/bin/bash
set -e
echo "=== Initializing pacman keyring ==="
pacman-key --init
pacman-key --populate archlinuxarm
