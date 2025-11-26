# Contributing to Arch ARM64 Cloud Image

Thank you for your interest in contributing.

## Ways to Contribute

- **Bug reports**: Open an issue describing the problem
- **Platform guides**: Help us add deployment instructions for more platforms
- **Build improvements**: Submit PRs to improve the build script
- **Documentation**: Fix typos, clarify instructions, add examples

## Testing Changes

If you modify the build script, test by running a complete build:

```bash
sudo ./build.sh
```

Then validate:
1. Upload to a cloud platform
2. Boot a VM
3. Verify SSH access with `alarm` user
4. Check `cloud-init status` shows "done"

## Pull Request Process

1. Fork the repository
2. Make your changes
3. Test thoroughly
4. Submit a PR with a clear description

## Questions?

Open an issue and we'll help.
