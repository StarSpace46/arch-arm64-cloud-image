# Troubleshooting

Common issues and solutions for Arch Linux ARM64 cloud images.

## SSH Connection Issues

### Cannot connect via SSH

**Check username**: The default user is `alarm`, not `root` or `arch`.
```bash
ssh alarm@<ip-address>
```

**Check SSH key injection**: Cloud-init must have your SSH key. Verify via console:
```bash
sudo cat /home/alarm/.ssh/authorized_keys
```

**Check cloud-init status**:
```bash
sudo cloud-init status
# Should show: status: done

# If failed, check logs:
sudo cat /var/log/cloud-init.log | grep -i error
```

### Connection refused

- Verify SSH service is running: `sudo systemctl status sshd`
- Check firewall/security groups allow port 22
- Ensure the instance has a public IP or you're on the same network

## Boot Issues

### VM stuck at UEFI menu

The image requires UEFI firmware. Configure your platform for UEFI boot:

**OpenStack:**
```bash
openstack image set <image> --property hw_firmware_type=uefi
```

**Proxmox:**
Set BIOS to OVMF (UEFI) in VM settings.

**QEMU:**
Use `-bios /usr/share/AAVMF/AAVMF_CODE.fd` or equivalent.

### Kernel panic on boot

- Ensure you're using an ARM64 instance type
- Verify UEFI firmware is configured
- Check that virtio drivers are available

## Package Manager Issues

### GPG key errors

```bash
sudo pacman -Sy archlinux-keyring
sudo pacman -Syu
```

### Mirror connection failures

Update mirror list:
```bash
sudo pacman -S reflector
sudo reflector --country US --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
```

## Cloud-Init Issues

### User-data not applied

Check cloud-init datasource detection:
```bash
sudo cloud-init query ds
```

Check logs for errors:
```bash
sudo cat /var/log/cloud-init-output.log
```

### Running cloud-init again

To re-run cloud-init (e.g., after updating user-data):
```bash
sudo cloud-init clean --logs
sudo cloud-init init
sudo cloud-init modules --mode=config
sudo cloud-init modules --mode=final
```

## Platform-Specific Issues

### AWS - Instance won't start

- Ensure you imported with `--architecture arm64` and `--boot-mode uefi`
- Use Graviton instance types (t4g, m6g, c6g, etc.)

### Azure - No boot diagnostics

- Use Hyper-V Generation 2 VMs
- Select ARM64-compatible VM sizes (Dpsv5, Epsv5, etc.)

### GCP - Image creation fails

- Ensure `--architecture=ARM64` and `--guest-os-features=UEFI_COMPATIBLE`
- Use correct tar.gz format for raw disk

## Still stuck?

Open an issue on GitHub with:
1. Platform you're using
2. Exact error message
3. Steps to reproduce
4. Cloud-init logs if available
