# Arch Linux ARM64 Cloud Image for OpenStack
# Built with packer-builder-arm

variable "image_name" {
  type    = string
  default = "arch-linux-arm64-base"
}

variable "image_size" {
  type    = string
  default = "8G"
}

source "arm" "arch-arm64" {
  # Remote file configuration - Arch Linux ARM generic tarball
  file_urls             = ["http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"]
  file_checksum_url     = "http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz.md5"
  file_checksum_type    = "md5"
  file_target_extension = "tar.gz"
  file_unarchive_cmd    = ["bsdtar", "-xpf", "$ARCHIVE_PATH", "-C", "$MOUNTPOINT"]

  # Image configuration - GPT for UEFI boot
  image_build_method = "new"
  image_path         = "output/${var.image_name}.img"
  image_size         = var.image_size
  image_type         = "gpt"

  # Partition layout for UEFI cloud image
  image_partitions {
    name         = "ESP"
    type         = "EF00"
    start_sector = "2048"
    filesystem   = "vfat"
    size         = "512M"
    mountpoint   = "/boot/efi"
  }

  image_partitions {
    name         = "root"
    type         = "8300"
    start_sector = "0"
    filesystem   = "ext4"
    size         = "0"  # Use remaining space
    mountpoint   = "/"
  }

  # Native ARM64 execution - no QEMU emulation needed
  qemu_binary_source_path      = ""
  qemu_binary_destination_path = ""
}

build {
  sources = ["source.arm.arch-arm64"]

  # Initialize pacman keyring
  provisioner "shell" {
    script = "scripts/01-init-pacman.sh"
  }

  # Install base packages
  provisioner "shell" {
    script = "scripts/02-install-packages.sh"
  }

  # Build and install cloud-init from AUR
  provisioner "shell" {
    script = "scripts/03-build-cloud-init.sh"
  }

  # Copy cloud-init configuration
  provisioner "file" {
    source      = "configs/99-openstack.cfg"
    destination = "/etc/cloud/cloud.cfg.d/99-openstack.cfg"
  }

  # Configure system (GRUB, services, etc.)
  provisioner "shell" {
    script = "scripts/04-configure-system.sh"
  }

  # Final cleanup
  provisioner "shell" {
    script = "scripts/05-cleanup.sh"
  }

  # Convert to qcow2 for OpenStack
  post-processor "shell-local" {
    inline = [
      "qemu-img convert -f raw -O qcow2 -c output/${var.image_name}.img output/${var.image_name}.qcow2",
      "sha256sum output/${var.image_name}.qcow2 > output/${var.image_name}.qcow2.sha256",
      "echo 'Build complete! Image: output/${var.image_name}.qcow2'"
    ]
  }
}
