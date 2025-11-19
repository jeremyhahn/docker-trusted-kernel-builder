# Kernel Configuration Profiles

This directory contains kernel configuration profiles for different deployment scenarios.

## Available Profiles

### `virt` (Default)
Minimal FIPS kernel configuration optimized for environments, containers, and cloud deployments.

**Features:**
- Essential filesystems (ext4, xfs, btrfs, overlay)
- FIPS 140-3 cryptographic module support
- TPM 2.0 support (built-in for early boot)
- VirtIO drivers for VM deployment
- Device mapper and dm-crypt for LUKS encryption
- EFI stub support
- Minimal hardware support for smaller kernel size

**Use case:** Virtual machines, containers, cloud instances

### `full`
Comprehensive FIPS kernel configuration with all features for bare metal, containers, and advanced networking.

**Features:**
- All `virt` features
- Container runtime (namespaces, cgroups, BPF/eBPF)
- Advanced networking (bridge, netfilter, Open vSwitch, VXLAN)
- Security hardening (IMA, SELinux, lockdown LSM)
- Extended cryptography
- Advanced storage (thin provisioning, multiple filesystems)

**Use case:** Bare metal deployments, container hosts, custom hardware support

## Usage

### Using a Built-in Profile

```bash
# Build with virt profile (default)
make build

# Build with full profile
KERNEL_PROFILE=full make build

# Or set it explicitly
KERNEL_PROFILE=virt make build
```

### Creating a Custom Profile

1. Create a new profile file in this directory:
   ```bash
   touch configs/myprofile.config
   chmod +x configs/myprofile.config
   ```

2. Add your kernel configuration commands (standalone - no sourcing):
   ```bash
   #!/bin/bash
   # myprofile.config - Custom kernel profile

   log "Configuring custom kernel profile..."

   # Add all configurations needed for your profile
   scripts/config --enable CONFIG_MY_FEATURE
   scripts/config --enable CONFIG_ANOTHER_FEATURE
   scripts/config --disable CONFIG_UNWANTED_FEATURE
   scripts/config --set-str CONFIG_VERSION_STRING "My Custom Kernel"

   # Include all necessary configs - profiles are standalone
   # (Copy configs from virt.config or full.config as needed)
   ```

3. Build with your custom profile:
   ```bash
   KERNEL_PROFILE=myprofile make build
   ```

**Note:** Each profile should be self-contained with all necessary configurations. Profiles do not source each other.

## Profile Configuration Syntax

Use the kernel's `scripts/config` tool to modify options:

```bash
# Enable an option (=y)
scripts/config --enable CONFIG_FEATURE_NAME

# Disable an option (=n)
scripts/config --disable CONFIG_FEATURE_NAME

# Build as module (=m)
scripts/config --module CONFIG_FEATURE_NAME

# Set string value
scripts/config --set-str CONFIG_STRING_OPTION "value"

# Set numeric value
scripts/config --set-val CONFIG_NUMERIC_OPTION 1234
```

## The `full` Profile

The `full` profile is a standalone configuration that includes:
- All base features from `virt`
- Additional container runtime support
- Advanced networking features
- Enhanced security hardening
- Extended cryptography

Each profile is self-contained - `full.config` doesn't source `virt.config`, it contains all configurations directly.

To modify the full profile:

1. Edit `configs/full.config` directly
2. Add or modify kernel config commands:
   ```bash
   # Enable a feature
   scripts/config --enable CONFIG_MY_DRIVER

   # Or use set-val
   scripts/config --set-val CONFIG_MY_DRIVER y
   ```

3. Build with the full profile:
   ```bash
   KERNEL_PROFILE=full make build
   ```

## Environment Variables

Available in profile scripts:

- `${PROFILE_DIR}` - Path to configs directory
- `${BUILD_ROOT}` - Path to build directory (/build)
- `${KERNEL_VERSION}` - Kernel version being built
- `${OUTPUT_DIR}` - Output directory for artifacts

## Tips

- Keep profiles focused on specific use cases
- Comment your configurations to explain why options are enabled
- Test your profile before committing
- Source existing profiles to build on proven configurations
