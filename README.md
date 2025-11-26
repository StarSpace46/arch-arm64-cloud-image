# Arch Linux ARM64 Cloud Image

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ready-to-use Arch Linux ARM64 cloud images for OpenStack, AWS, Azure, GCP, and other cloud platforms.

## Download

[Latest Release](../../releases/latest)

| File | Description |
|------|-------------|
| `Arch-Linux-ARM64-cloudimg-YYYYMMDD.qcow2` | QCOW2 format (OpenStack, Proxmox, QEMU/KVM) |
| `Arch-Linux-ARM64-cloudimg-YYYYMMDD.qcow2.sha256` | SHA256 checksum |

**Verify downloads:**
```bash
sha256sum -c Arch-Linux-ARM64-cloudimg-YYYYMMDD.qcow2.sha256
```

### Planned Additions

Future releases will include:
- Raw format (`.raw.gz`) for AWS and GCP
- VHD format (`.vhd.gz`) for Azure
- GPG signatures for all artifacts

For now, use `qemu-img convert` to create other formats locally:
```bash
# Convert to raw
qemu-img convert -f qcow2 -O raw image.qcow2 image.raw

# Convert to VHD
qemu-img convert -f qcow2 -O vpc image.qcow2 image.vhd
```

## Image Details

| Property | Value |
|----------|-------|
| Architecture | ARM64 (aarch64) |
| Firmware | UEFI |
| Bootloader | GRUB |
| Cloud-init | Configured for OpenStack, NoCloud, ConfigDrive, EC2, Azure, GCE |
| Default user | `alarm` (passwordless sudo) |
| Root password | Locked |
| SSH | Key-based authentication only |

## Platform Deployment Guides

### OpenStack

```bash
# Upload image
openstack image create \
  --disk-format qcow2 \
  --container-format bare \
  --file Arch-Linux-ARM64-cloudimg-YYYYMMDD.qcow2 \
  --property hw_firmware_type=uefi \
  --property hw_machine_type=virt \
  --property architecture=aarch64 \
  --public \
  arch-linux-arm64

# Launch instance
openstack server create \
  --flavor <arm64-flavor> \
  --image arch-linux-arm64 \
  --network <network> \
  --key-name <your-key> \
  my-arch-vm

# Connect
ssh alarm@<instance-ip>
```

### AWS (Graviton Instances)

```bash
# Extract raw image
gunzip Arch-Linux-ARM64-cloudimg-YYYYMMDD.raw.gz

# Upload to S3
aws s3 cp Arch-Linux-ARM64-cloudimg-YYYYMMDD.raw s3://your-bucket/

# Import as AMI
aws ec2 import-image \
  --disk-containers "Format=raw,UserBucket={S3Bucket=your-bucket,S3Key=arch-arm64.raw}" \
  --architecture arm64 \
  --boot-mode uefi

# Launch on Graviton (t4g, m6g, c6g, etc.)
aws ec2 run-instances \
  --image-id <imported-ami-id> \
  --instance-type t4g.micro \
  --key-name <your-key>

# Connect
ssh alarm@<public-ip>
```

### Azure

```bash
# Extract VHD image
gunzip Arch-Linux-ARM64-cloudimg-YYYYMMDD.vhd.gz

# Upload to Azure Storage and create image
az storage blob upload --account-name <storage> --container images --file Arch-Linux-ARM64-cloudimg-YYYYMMDD.vhd --name arch-arm64.vhd
az image create --resource-group <rg> --name arch-linux-arm64 --source <blob-url> --os-type Linux --hyper-v-generation V2

# Launch (Dpsv5, Epsv5, or other ARM64 VM sizes)
az vm create \
  --resource-group <rg> \
  --name my-arch-vm \
  --image arch-linux-arm64 \
  --size Standard_D2ps_v5 \
  --admin-username alarm \
  --ssh-key-value @~/.ssh/id_rsa.pub

# Connect
ssh alarm@<public-ip>
```

### Google Cloud Platform (Tau T2A)

```bash
# Extract and repackage for GCP
gunzip Arch-Linux-ARM64-cloudimg-YYYYMMDD.raw.gz
tar -czvf arch-arm64.tar.gz Arch-Linux-ARM64-cloudimg-YYYYMMDD.raw

# Upload to GCS
gsutil cp arch-arm64.tar.gz gs://your-bucket/

# Create image
gcloud compute images create arch-linux-arm64 \
  --source-uri=gs://your-bucket/arch-arm64.tar.gz \
  --architecture=ARM64 \
  --guest-os-features=UEFI_COMPATIBLE

# Launch (t2a-standard-1, etc.)
gcloud compute instances create my-arch-vm \
  --image=arch-linux-arm64 \
  --machine-type=t2a-standard-1 \
  --zone=us-central1-a

# Connect
gcloud compute ssh alarm@my-arch-vm
```

### Hetzner Cloud

```bash
# Hetzner supports custom images via their API
# Upload via Hetzner Cloud Console or API
# Select CAX (ARM64) instance types

# Connect
ssh alarm@<server-ip>
```

### Vultr

```bash
# Upload via Vultr Custom ISO/Image feature
# Select "Cloud Compute - ARM" instances

# Connect
ssh alarm@<instance-ip>
```

### DigitalOcean

```bash
# Upload via DigitalOcean Custom Images
doctl compute image create arch-linux-arm64 \
  --image-url "https://your-host/arch-arm64.raw.gz" \
  --region nyc1

# Create droplet (if ARM64 available in your region)
doctl compute droplet create my-arch-vm \
  --image <image-id> \
  --size <arm64-size> \
  --ssh-keys <key-fingerprint>
```

### Proxmox VE

```bash
# Download image to Proxmox host
wget -O /var/lib/vz/template/iso/arch-arm64.qcow2 <release-url>

# Create VM (via UI or CLI)
qm create 100 --name arch-arm64 --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 100 /var/lib/vz/template/iso/arch-arm64.qcow2 local-lvm
qm set 100 --scsi0 local-lvm:vm-100-disk-0 --boot c --bootdisk scsi0
qm set 100 --bios ovmf --machine virt
qm start 100
```

### Generic QEMU/KVM

```bash
# Launch with UEFI
qemu-system-aarch64 \
  -M virt \
  -cpu cortex-a72 \
  -m 2048 \
  -bios /usr/share/AAVMF/AAVMF_CODE.fd \
  -drive file=Arch-Linux-ARM64-cloudimg-YYYYMMDD.qcow2,format=qcow2 \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -nographic

# Connect
ssh -p 2222 alarm@localhost
```

## Customization

This base image is designed for customization. Common use cases include GPU drivers (NVIDIA, AMD), container runtimes (Docker, Podman), ML/AI frameworks (PyTorch, TensorFlow, Ollama), and development tools.

Recommended workflow:
1. Deploy base image on your platform
2. SSH in and install your packages
3. Clean up: `sudo pacman -Scc && sudo cloud-init clean --logs`
4. Snapshot/create custom image from your platform's console

## Updating Packages

Arch Linux is a rolling release. Update your instance:

```bash
sudo pacman -Syu
```

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common issues.

### Quick fixes

**Cannot SSH in:**
- Use username `alarm` (not `root` or `arch`)
- Verify SSH key was provided via cloud-init/user-data
- Check security groups/firewall allows port 22

**Package manager errors:**
```bash
sudo pacman -Sy archlinux-keyring && sudo pacman -Syu
```

## Building Your Own

If you want to build images yourself or contribute improvements:

```bash
# Requires Arch Linux ARM64 host
git clone https://github.com/StarSpace46/arch-arm64-cloud-image.git
cd arch-arm64-cloud-image
sudo ./build.sh
# Output: ./output/Arch-Linux-ARM64-cloudimg-YYYYMMDD.qcow2
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## Release Schedule

New images are published monthly to incorporate security updates.

## License

MIT License - See [LICENSE](LICENSE)

## Maintainer

[StarSpace46 AI Lab](https://starspace46.com)

## Acknowledgments

- Build methodology based on [arch-boxes](https://gitlab.archlinux.org/archlinux/arch-boxes)
- Arch Linux ARM community
