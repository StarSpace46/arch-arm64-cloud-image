#!/bin/bash
set -e
echo "=== Configuring system ==="

# Enable services
systemctl enable cloud-init-local.service
systemctl enable cloud-init.service
systemctl enable cloud-config.service
systemctl enable cloud-final.service
systemctl enable NetworkManager
systemctl enable sshd

# Configure default user (alarm - Arch ARM convention)
if id "alarm" &>/dev/null; then
    usermod -aG wheel alarm
else
    useradd -m -G wheel -s /bin/bash alarm
fi

# Lock root password
passwd -l root

# Configure sudo for wheel group
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

# Set locale and timezone
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Configure GRUB for UEFI
cat > /etc/default/grub << 'GRUB_EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch Linux ARM"
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX="console=tty1 console=ttyAMA0,115200"
GRUB_EOF

# Install GRUB for ARM64 UEFI
grub-install --target=arm64-efi --efi-directory=/boot/efi --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg

echo "=== System configuration complete ==="
