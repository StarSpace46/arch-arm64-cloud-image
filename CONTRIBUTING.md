# Contributing to Arch Linux ARM64 Cloud Image

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Code of Conduct

Be respectful, constructive, and collaborative. We welcome contributions from everyone.

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report:
- Check the [existing issues](https://github.com/starspace46/arch-arm64-cloud-image/issues)
- Verify you're using the latest release
- Test with a clean OpenStack/cloud environment if possible

When filing a bug report, include:
- **Image version** (commit SHA or release tag)
- **Cloud platform** (OpenStack version, AWS, Azure, etc.)
- **Instance type/flavor** (vCPUs, RAM, disk)
- **Steps to reproduce**
- **Expected behavior** vs **actual behavior**
- **Logs** from cloud-init (`/var/log/cloud-init*.log`)
- **System logs** if relevant (`journalctl`)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- Use a clear, descriptive title
- Provide detailed description of the proposed functionality
- Explain why this enhancement would be useful
- List any alternative solutions you've considered

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Follow the coding style** (see below)
3. **Test your changes** thoroughly
4. **Update documentation** if needed
5. **Write clear commit messages** (see below)
6. **Submit a pull request**

## Development Workflow

### Local Development

#### Prerequisites
- Docker (recommended), OR
- ARM64 Linux system with Packer + packer-builder-arm

#### Making Changes

```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/arch-arm64-cloud-image.git
cd arch-arm64-cloud-image

# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes
# Test locally (see Testing section)

# Commit your changes
git commit -m "Add feature: your feature description"

# Push to your fork
git push origin feature/your-feature-name
```

### Testing Changes

#### Build Locally (Docker)

```bash
docker run --rm --privileged \
  -v /dev:/dev \
  -v ${PWD}:/build \
  -w /build \
  mkaczanowski/packer-builder-arm:latest \
  build arch-arm64-base.pkr.hcl
```

#### Test in OpenStack

```bash
# Upload image
openstack image create \
  --disk-format qcow2 --container-format bare \
  --property hw_firmware_type=uefi \
  --property hw_machine_type=virt \
  --property hw_disk_bus=virtio \
  --file output/arch-linux-arm64-base.qcow2 \
  "arch-arm64-test"

# Launch instance
openstack server create \
  --flavor <flavor> \
  --image arch-arm64-test \
  --network <network> \
  --key-name <key> \
  test-vm

# Verify
ssh alarm@<instance-ip>
cloud-init status --wait
```

## Coding Style

### Packer HCL Templates
- Use 2-space indentation
- Follow HashiCorp HCL style guide
- Add comments for complex configurations
- Keep variable names descriptive

### Shell Scripts (Provisioners)
- Use `#!/bin/bash` shebang
- Add `set -e` for error handling
- Comment complex sections
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

Example:
```bash
#!/bin/bash
set -e
echo "=== Descriptive Section Header ==="

# Explain why this command is needed
pacman -Syu --noconfirm

echo "=== Section complete ==="
```

### Cloud-Init Configuration
- Use YAML format
- Validate with `cloud-init schema --config-file`
- Document datasource-specific settings

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Build process, dependencies

**Examples:**
```
feat: Add support for AWS EC2 metadata service

fix: Resolve cloud-init network configuration timeout

docs: Update OpenStack deployment instructions

refactor: Simplify package installation script
```

## What to Contribute

### High Priority
- **Bug fixes** for cloud-init issues
- **Cloud platform support** (AWS Graviton, Azure ARM)
- **Documentation improvements**
- **Test coverage** on different platforms
- **Performance optimizations**

### Ideas for Contributions
- Minimal variant (smaller base image)
- Additional package sets (development tools, monitoring)
- Alternative init systems
- Automated testing infrastructure
- Security hardening configurations

### Out of Scope
- GPU drivers (maintained in separate private repo)
- Desktop environments
- Non-ARM architectures
- Non-cloud use cases

## Review Process

1. **Automated checks** run on all PRs:
   - GitHub Actions build test
   - Packer template validation

2. **Manual review** by maintainers:
   - Code quality and style
   - Documentation completeness
   - Testing adequacy

3. **Approval and merge**:
   - At least one maintainer approval required
   - Squash and merge preferred for feature branches
   - Merge commits for release branches

## Release Process

Releases follow semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR**: Breaking changes (e.g., kernel upgrade, cloud-init major version)
- **MINOR**: New features, package updates
- **PATCH**: Bug fixes, documentation

Releases are created when:
- Significant bug fixes are merged
- New features are ready
- Quarterly package updates (minimum)

## Questions?

- **Issues**: [GitHub Issues](https://github.com/starspace46/arch-arm64-cloud-image/issues)
- **Discussions**: [GitHub Discussions](https://github.com/starspace46/arch-arm64-cloud-image/discussions)
- **Maintainer**: [@rhoegg](https://github.com/rhoegg)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
