# FIPS Kernel Builder

This Docker container builds a FIPS-enabled Linux kernel with TPM 2.0 and VirtIO for [go-trusted-platform](https://github.com/jeremyhahn/go-trusted-platform).

## Kernel Version

Linux 6.12.8 is used to match Alpine 3.22 LTS.

## FIPS Configuration

The kernel is built with:

- `CONFIG_CRYPTO_FIPS=y` - Enable FIPS mode
- `CONFIG_CRYPTO_FIPS_NAME="Alpine Linux FIPS 140-3"`
- All required crypto algorithms (SHA256, SHA512, AES, etc.)
- `CONFIG_MODULE_SIG=y` - Module signing (required for FIPS)
- `CONFIG_CRYPTO_MANAGER_DISABLE_TESTS=n` - Enable crypto self-tests (required for FIPS)
- TPM support (built-in for early boot)
- LUKS/dm-crypt support

## Usage

### Build with Default Profile (virt)

```bash
make build
```

This will:
1. Build the Docker image
2. Download and cryptographically verify the kernel source from kernel.org
3. Configure the kernel with FIPS enabled using the `virt` profile
4. Compile the kernel and modules
5. Extract artifacts to `output/`

### Build with Different Kernel Profile

```bash
# Build with full profile (includes new.config additions)
KERNEL_PROFILE=full make build

# Build with custom profile
KERNEL_PROFILE=myprofile make build

# Build specific kernel version with profile
KERNEL_VERSION=6.12.8 KERNEL_PROFILE=virt make build
```

### Available Profiles

- **`virt`** (default) - Minimal configuration for VMs, containers, and cloud
- **`full`** - Extended configuration including `new.config` additions for bare metal

See [`configs/README.md`](configs/README.md) for details on creating custom profiles.

### Other Commands

Clean build artifacts:

```bash
make clean
```

Test the built kernel:

```bash
make test
```

## Output

After building, you'll find in `output/`:

- `vmlinuz-fips` - The FIPS-capable kernel image
- `modules-fips-${KVER}.tar.gz` - Kernel modules
- `System.map-fips` - System map for debugging
- `config-fips` - Kernel configuration
- `kernel-version.txt` - Kernel version string
- `*.sha256` - SHA256 checksums
