#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Arch Linux ARM64 Cloud Image Builder"
echo "=========================================="

# Check for root (required for losetup, mount operations)
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (sudo)"
   exit 1
fi

# Check architecture
if [[ $(uname -m) != "aarch64" ]]; then
    echo "WARNING: Not running on ARM64. Build may require QEMU emulation."
fi

# Check dependencies
for cmd in packer qemu-img bsdtar; do
    if ! command -v $cmd &> /dev/null; then
        echo "ERROR: Required command '$cmd' not found"
        exit 1
    fi
done

# Create output directory
mkdir -p output

# Initialize Packer plugins
echo "=== Initializing Packer ==="
packer init arch-arm64-base.pkr.hcl

# Run Packer build
echo "=== Starting Packer build ==="
packer build arch-arm64-base.pkr.hcl

# Show results
echo "=========================================="
echo "Build complete!"
echo "=========================================="
ls -lh output/
echo ""
echo "Upload to OpenStack with:"
echo "openstack image create \\"
echo "  --disk-format qcow2 --container-format bare --public \\"
echo "  --property hw_firmware_type=uefi \\"
echo "  --property hw_machine_type=virt \\"
echo "  --property hw_disk_bus=virtio \\"
echo "  --property os_type=linux \\"
echo "  --property os_distro=arch \\"
echo "  --file output/arch-linux-arm64-base.qcow2 \\"
echo "  'arch-linux-arm64-base'"
