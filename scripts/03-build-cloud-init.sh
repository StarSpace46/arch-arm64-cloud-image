#!/bin/bash
set -e
echo "=== Building cloud-init from AUR ==="

# Create temporary build user (AUR requires non-root)
useradd -m -G wheel builder
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Build cloud-init as builder user
su - builder << 'BUILDER_EOF'
cd ~
git clone https://aur.archlinux.org/cloud-init.git
cd cloud-init

# Remove netplan dependency (not available on ARM)
sed -i "s/'netplan'//g" PKGBUILD

# Build package
makepkg -s --noconfirm
BUILDER_EOF

# Install the built package
pacman -U --noconfirm /home/builder/cloud-init/cloud-init-*.pkg.tar.zst

# Cleanup builder user
userdel -r builder
sed -i '/builder/d' /etc/sudoers

# Create critical ds-identify symlink (required for Arch)
ln -sf /usr/lib/cloud-init/ds-identify /usr/bin/ds-identify

echo "=== Cloud-init installed successfully ==="
cloud-init --version
