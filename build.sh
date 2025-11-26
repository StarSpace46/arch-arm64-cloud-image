#!/bin/bash
# Arch Linux ARM64 Cloud Image Builder
# Uses direct installation method (no ISO, no VM boot)
# Based on arch-boxes methodology
#
# Requirements:
# - Run as root on ARM64 system
# - pacstrap, arch-chroot, genfstab (arch-install-scripts package)
# - qemu-img (qemu package)
# - losetup, partprobe, blockdev (util-linux package)
# - sfdisk (util-linux package)
# - truncate (coreutils package)

set -euo pipefail

# Configuration
IMAGE_NAME="Arch-Linux-ARM64-cloudimg-$(date +%Y%m%d)"
IMAGE_SIZE="10G"
BUILD_DIR="$(mktemp -d)"
OUTPUT_DIR="./output"
MOUNT_DIR="/mnt/arch-build"

# Package lists
BASE_PACKAGES="base linux-aarch64 linux-firmware"
CLOUD_PACKAGES="cloud-init cloud-guest-utils"
BOOT_PACKAGES="grub efibootmgr"
NETWORK_PACKAGES="dhcpcd openssh"
UTILITY_PACKAGES="sudo vim"

# Functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[ERROR] $*" >&2
    cleanup
    exit 1
}

cleanup() {
    log "Cleaning up..."
    umount -R "${MOUNT_DIR}" 2>/dev/null || true

    # Detach loop device if set
    if [ -n "${LOOP_DEV:-}" ]; then
        losetup -d "${LOOP_DEV}" 2>/dev/null || true
    fi

    # Don't delete BUILD_DIR if it contains RAW_IMAGE that finalize_image() needs
    # Only clean up if finalize_image() hasn't run yet or has already cleaned up
    if [ ! -f "${RAW_IMAGE:-/nonexistent}" ]; then
        rm -rf "${BUILD_DIR}"
    fi
}

create_image() {
    log "Creating output directory..."
    mkdir -p "${OUTPUT_DIR}"
    # Image creation moved to setup_loop()
}

setup_loop() {
    log "Setting up loop device..."

    # Create raw image first (loop devices work with raw, not qcow2)
    RAW_IMAGE="${BUILD_DIR}/${IMAGE_NAME}.raw"
    truncate -s "${IMAGE_SIZE}" "${RAW_IMAGE}"

    # Attach to loop device with partition scanning
    LOOP_DEV=$(losetup --find --show --partscan "${RAW_IMAGE}")
    log "Attached to ${LOOP_DEV}"

    # Export for other functions
    export LOOP_DEV
    export RAW_IMAGE
}

create_partitions() {
    log "Creating GPT partitions with sfdisk..."
    # Use sfdisk with --no-reread to prevent automatic partition table reload
    # We'll manually trigger reload after to ensure proper udev processing
    # Note: sfdisk may exit with code 1 even on success with loop devices
    sfdisk --no-reread "${LOOP_DEV}" << EOF || true
label: gpt
unit: sectors
first-lba: 2048

start=2048, size=1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="EFI"
start=1050624, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="ROOT"
EOF

    # Force kernel to re-read partition table
    blockdev --rereadpt "${LOOP_DEV}" 2>/dev/null || true
    partprobe "${LOOP_DEV}" 2>/dev/null || true
    udevadm settle
    sleep 2

    # Verify partitions are visible - wait up to 10 seconds
    for i in {1..10}; do
        if [ -b "${LOOP_DEV}p1" ] && [ -b "${LOOP_DEV}p2" ]; then
            log "Partition devices are ready"
            return 0
        fi
        log "Waiting for partition devices... (attempt $i/10)"
        sleep 1
    done

    # If still not visible, try detach/reattach
    log "Partitions not visible after initial wait, detaching and reattaching loop device..."
    losetup -d "${LOOP_DEV}"
    udevadm settle
    sleep 2
    LOOP_DEV=$(losetup --find --show --partscan "${RAW_IMAGE}")
    export LOOP_DEV
    udevadm settle
    sleep 2

    # Final wait loop
    for i in {1..10}; do
        if [ -b "${LOOP_DEV}p1" ] && [ -b "${LOOP_DEV}p2" ]; then
            log "Partition devices are ready after reattach"
            return 0
        fi
        log "Waiting for partition devices after reattach... (attempt $i/10)"
        sleep 1
    done

    # Final check - fail if still not visible
    if [ ! -b "${LOOP_DEV}p1" ] || [ ! -b "${LOOP_DEV}p2" ]; then
        log "DEBUG: Contents of /dev:"
        ls -la /dev/loop* 2>&1 | head -20
        error "Failed to create partition devices for ${LOOP_DEV}"
    fi
}

format_filesystems() {
    log "Formatting filesystems..."
    mkfs.vfat -F32 -n EFI "${LOOP_DEV}p1"
    mkfs.ext4 -L ROOT "${LOOP_DEV}p2"
}

mount_filesystems() {
    log "Mounting filesystems..."
    mkdir -p "${MOUNT_DIR}"
    mount "${LOOP_DEV}p2" "${MOUNT_DIR}"
    mkdir -p "${MOUNT_DIR}/boot"
    mount "${LOOP_DEV}p1" "${MOUNT_DIR}/boot"
}

install_base_system() {
    log "Installing base system with pacstrap (this may take 5-10 minutes)..."
    pacstrap -K "${MOUNT_DIR}" \
        ${BASE_PACKAGES} \
        ${CLOUD_PACKAGES} \
        ${BOOT_PACKAGES} \
        ${NETWORK_PACKAGES} \
        ${UTILITY_PACKAGES}
}

configure_system() {
    log "Configuring system..."

    # Generate fstab
    genfstab -U "${MOUNT_DIR}" >> "${MOUNT_DIR}/etc/fstab"

    # Configure via chroot
    arch-chroot "${MOUNT_DIR}" /bin/bash << 'CHROOT_EOF'
# Set timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Set locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "archlinux" > /etc/hostname

# Configure hosts
cat > /etc/hosts << 'HOSTS_EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   archlinux.localdomain archlinux
HOSTS_EOF

# Enable services (create symlinks manually - systemctl doesn't work in chroot)
mkdir -p /etc/systemd/system/multi-user.target.wants
mkdir -p /etc/systemd/system/cloud-init.target.wants
ln -sf /usr/lib/systemd/system/sshd.service /etc/systemd/system/multi-user.target.wants/sshd.service
ln -sf /usr/lib/systemd/system/cloud-init-local.service /etc/systemd/system/cloud-init.target.wants/cloud-init-local.service
ln -sf /usr/lib/systemd/system/cloud-init-main.service /etc/systemd/system/cloud-init.target.wants/cloud-init-main.service
ln -sf /usr/lib/systemd/system/cloud-init-network.service /etc/systemd/system/cloud-init.target.wants/cloud-init-network.service
ln -sf /usr/lib/systemd/system/cloud-init.target /etc/systemd/system/multi-user.target.wants/cloud-init.target
ln -sf /usr/lib/systemd/system/dhcpcd.service /etc/systemd/system/multi-user.target.wants/dhcpcd.service

# Configure sudo for wheel group
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Security: Lock root account (cloud-init will manage user access)
passwd -l root

CHROOT_EOF
}

install_bootloader() {
    log "Installing GRUB bootloader for ARM64 UEFI..."

    arch-chroot "${MOUNT_DIR}" /bin/bash << 'CHROOT_EOF'
# Install GRUB for ARM64 UEFI
grub-install --target=arm64-efi \
    --efi-directory=/boot \
    --bootloader-id=GRUB \
    --removable

# Create explicit GRUB config for ARM64 (auto-detection doesn't work in OpenStack)
cat > /boot/grub/grub.cfg << 'GRUB_EOF'
set timeout=3
set default=0

menuentry 'Arch Linux' {
    set root=(hd0,gpt1)
    linux /Image root=LABEL=ROOT rw console=tty0 console=ttyAMA0,115200n8
    initrd /initramfs-linux.img
}
GRUB_EOF

echo "Created explicit GRUB configuration for ARM64"
CHROOT_EOF
}

configure_cloud_init() {
    log "Configuring cloud-init..."

    # Create cloud-init config supporting multiple cloud platforms
    cat > "${MOUNT_DIR}/etc/cloud/cloud.cfg.d/99-cloud-platforms.cfg" << 'CLOUD_EOF'
# Datasource configuration for multiple cloud platforms
datasource_list: [OpenStack, Ec2, Azure, GCE, NoCloud, ConfigDrive, None]

# OpenStack configuration
datasource:
  OpenStack:
    metadata_urls: ['http://169.254.169.254']
    max_wait: 120
    timeout: 50
    apply_network_config: true
  # EC2 (AWS) configuration
  Ec2:
    metadata_urls: ['http://169.254.169.254']
    max_wait: 120
    timeout: 50
  # Azure configuration
  Azure:
    apply_network_config: true
  # GCE (Google Cloud) configuration
  GCE:
    apply_network_config: true

# Disable root login, require SSH keys
disable_root: true
ssh_pwauth: false

# Let cloud platform handle network configuration
network:
  config: disabled

# Default user configuration
system_info:
  default_user:
    name: alarm
    lock_passwd: true
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    groups: [wheel, adm, systemd-journal]
    shell: /bin/bash
  distro: arch
  paths:
    cloud_dir: /var/lib/cloud
    templates_dir: /etc/cloud/templates
  ssh_svcname: sshd
CLOUD_EOF

    # Critical: Cloud-init generator needs this symlink (Arch Linux packaging quirk)
    # The actual location is /usr/libexec/cloud-init/ds-identify but cloud-init expects /usr/lib
    log "Creating ds-identify symlink..."
    arch-chroot "${MOUNT_DIR}" ln -sf /usr/libexec/cloud-init/ds-identify /usr/bin/ds-identify
}

optimize_image() {
    log "Optimizing image..."

    # Clean up to reduce image size
    arch-chroot "${MOUNT_DIR}" /bin/bash << 'CHROOT_EOF'
# Clean package cache
pacman -Scc --noconfirm

# Remove temporary files
rm -rf /tmp/* /var/tmp/*
rm -rf /var/cache/pacman/pkg/*
rm -f /var/log/*.log
rm -f /root/.bash_history

# Zero out free space for better compression (optional, commented out to save time)
# dd if=/dev/zero of=/EMPTY bs=1M || true
# rm -f /EMPTY
CHROOT_EOF
}

finalize_image() {
    log "Converting to QCOW2 format..."

    # Ensure all writes are flushed to disk
    sync

    # Unmount filesystems with retry logic
    log "Unmounting filesystems..."
    if ! umount -R "${MOUNT_DIR}" 2>/dev/null; then
        log "First unmount attempt failed, syncing and retrying..."
        sync
        sleep 2
        umount -R "${MOUNT_DIR}" || error "Failed to unmount ${MOUNT_DIR}"
    fi

    # Detach loop device
    log "Detaching loop device ${LOOP_DEV}..."
    losetup -d "${LOOP_DEV}" || error "Failed to detach loop device"

    # Convert raw to qcow2 with compression
    log "Converting raw image to QCOW2 format (this may take a few minutes)..."
    qemu-img convert -f raw -O qcow2 -c \
        "${RAW_IMAGE}" \
        "${OUTPUT_DIR}/${IMAGE_NAME}.qcow2" || error "Failed to convert image"

    # Clean up raw image
    log "Cleaning up raw image..."
    rm -f "${RAW_IMAGE}"

    # Clean up build directory
    rm -rf "${BUILD_DIR}"

    log "Conversion complete"
}

main() {
    # Check for root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
    fi

    # Check for required tools
    for cmd in qemu-img losetup partprobe blockdev sfdisk mkfs.vfat mkfs.ext4 pacstrap arch-chroot genfstab truncate; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command not found: $cmd"
        fi
    done

    # Setup cleanup trap
    trap cleanup EXIT INT TERM

    # Execute build steps
    log "Starting Arch Linux ARM64 cloud image build..."
    create_image
    setup_loop
    create_partitions
    format_filesystems
    mount_filesystems
    install_base_system
    configure_system
    install_bootloader
    configure_cloud_init
    optimize_image
    finalize_image

    log "Build complete: ${OUTPUT_DIR}/${IMAGE_NAME}.qcow2"

    # Display image info
    qemu-img info "${OUTPUT_DIR}/${IMAGE_NAME}.qcow2"

    log "Image ready for upload to cloud platforms"
    log "To create raw format: qemu-img convert -f qcow2 -O raw ${OUTPUT_DIR}/${IMAGE_NAME}.qcow2 ${OUTPUT_DIR}/${IMAGE_NAME}.raw"
}

main "$@"
