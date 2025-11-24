# Arch Linux ARM64 Cloud Image for OpenStack

[![Build Status](https://github.com/starspace46/arch-arm64-base-openstack/actions/workflows/build.yml/badge.svg)](https://github.com/starspace46/arch-arm64-base-openstack/actions)

**The first maintained Arch Linux ARM64 cloud image since 2022.**

## Features

- **ARM64 Native**: Built for aarch64/ARM64 processors
- **OpenStack Ready**: Full cloud-init 25.x integration with OpenStack metadata service
- **UEFI Boot**: Modern GPT partitioning with GRUB bootloader
- **Minimal Base**: Clean installation (~2-3GB compressed)
- **Rolling Release**: Latest Arch packages at build time
- **Reproducible**: Automated Packer builds with HCL templates
- **Open Source**: MIT licensed, contributions welcome

## Why This Exists

Arch Linux ARM stopped providing maintained cloud images around 2022. This project fills that gap with automated, reproducible builds using modern infrastructure-as-code tooling.

## Quick Start

### Pre-built Images

Download from [Releases](https://github.com/starspace46/arch-arm64-base-openstack/releases).

### Upload to OpenStack

```bash
openstack image create \
  --disk-format qcow2 \
  --container-format bare \
  --public \
  --property hw_firmware_type=uefi \
  --property hw_machine_type=virt \
  --property hw_disk_bus=virtio \
  --property os_type=linux \
  --property os_distro=arch \
  --file arch-linux-arm64-base.qcow2 \
  "arch-linux-arm64"
```

### Launch Instance

```bash
openstack server create \
  --flavor <your-flavor> \
  --image arch-linux-arm64 \
  --network <your-network> \
  --key-name <your-key> \
  my-arch-vm
```

### Connect

```bash
ssh alarm@<instance-ip>
```

## Default User

- **Username**: `alarm` (Arch Linux ARM convention)
- **Authentication**: SSH key only (password login disabled)
- **Sudo**: Passwordless sudo via `wheel` group
- **Shell**: `/bin/bash`

## What's Included

### Base System
- Arch Linux ARM rolling release
- Linux kernel (latest stable)
- systemd init system
- NetworkManager for network configuration
- OpenSSH server

### Cloud Integration
- cloud-init 25.x (built from AUR)
- OpenStack metadata service support
- Automatic hostname configuration
- SSH key injection
- Root filesystem resize on first boot
- User data script execution

### Development Tools
- base-devel package group
- git, curl, wget, vim
- Python 3 with pip

## Building Your Own

See [BUILDING.md](BUILDING.md) for detailed build instructions.

**Requirements**:
- Docker (for GitHub Actions or local builds)
- OR: ARM64 host with Packer + packer-builder-arm

**Quick build**:
```bash
# Using Docker
docker run --rm --privileged \
  -v /dev:/dev \
  -v ${PWD}:/build \
  mkaczanowski/packer-builder-arm:latest \
  build arch-arm64-base.pkr.hcl

# Using local Packer (on ARM64 host)
sudo ./build.sh
```

## Technical Details

### Partitioning
- **GPT** partition table for UEFI compatibility
- **EFI System Partition**: 512MB FAT32 (`/boot/efi`)
- **Root Partition**: Remaining space, ext4 (`/`)

### Boot Configuration
- **GRUB** bootloader for ARM64 UEFI
- Serial console enabled (`ttyAMA0,115200`)
- GRUB timeout: 5 seconds

### Cloud-Init
- **Datasources**: OpenStack, NoCloud, None (in order)
- **Metadata URL**: http://169.254.169.254
- **Network**: Managed by NetworkManager
- **Root filesystem**: Grows automatically on first boot

## Compatibility

Tested on:
- OpenStack Zed (2023.2)
- OpenStack 2024.1 (Caracal)

Should work on any OpenStack deployment with:
- ARM64 compute nodes
- UEFI firmware support
- Cloud-init metadata service

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built by [StarSpace46 AI Lab](https://starspace46.com) as part of our OpenStack infrastructure project
- Uses [packer-builder-arm](https://github.com/mkaczanowski/packer-builder-arm) by Mateusz Kaczanowski
- Inspired by the Arch Linux ARM community

## Related Projects

- [Arch Linux ARM](https://archlinuxarm.org/) - Official Arch Linux ARM port
- [cloud-init](https://cloud-init.io/) - Industry standard cloud instance initialization

## Support

- **Issues**: [GitHub Issues](https://github.com/starspace46/arch-arm64-base-openstack/issues)
- **Discussions**: [GitHub Discussions](https://github.com/starspace46/arch-arm64-base-openstack/discussions)

## Roadmap

- [ ] Automated quarterly rebuilds
- [ ] Additional cloud platform support (AWS ARM Graviton, Azure ARM)
- [ ] Minimal variant (even smaller base image)
- [ ] GPU-enabled variant (separate private repo)
