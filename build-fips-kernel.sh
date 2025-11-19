#!/bin/bash
# build-fips-kernel.sh - Build FIPS-capable Linux kernel
set -euo pipefail

# Configuration from environment or defaults
# Use 6.12.8 to match Alpine 3.22 LTS kernel
KERNEL_VERSION="${KERNEL_VERSION:-6.12.8}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
KERNEL_PROFILE="${KERNEL_PROFILE:-virt}"
BUILD_ROOT="/build"
PROFILE_DIR="${BUILD_ROOT}/configs"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" >&2
    exit 1
}

log "=========================================="
log "FIPS Kernel Build (Docker Container)"
log "=========================================="
log "Kernel version: ${KERNEL_VERSION}"
log "Kernel profile: ${KERNEL_PROFILE}"
log "Output directory: ${OUTPUT_DIR}"
log ""

# Download and verify kernel source
cd /build
KERNEL_TARBALL="linux-${KERNEL_VERSION}.tar.xz"

if [ ! -f "${KERNEL_TARBALL}" ] || [ ! -f "${KERNEL_TARBALL}.verified" ]; then
    log "Downloading kernel source..."
    log "Kernel version: ${KERNEL_VERSION}"

    KERNEL_BASE_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x"
    KERNEL_URL="${KERNEL_BASE_URL}/${KERNEL_TARBALL}"
    SHA256_URL="${KERNEL_BASE_URL}/sha256sums.asc"

    # Download kernel tarball
    if ! wget -q "${KERNEL_URL}"; then
        error "Failed to download kernel from ${KERNEL_URL}"
    fi
    log "✓ Kernel tarball downloaded"

    # Download SHA256 checksums file
    if ! wget -q "${SHA256_URL}"; then
        error "Failed to download checksums from ${SHA256_URL}"
    fi
    log "✓ Checksums file downloaded"

    # Extract the checksum for our specific kernel version
    EXPECTED_SHA256=$(grep "${KERNEL_TARBALL}" sha256sums.asc | awk '{print $1}')
    if [ -z "${EXPECTED_SHA256}" ]; then
        error "Could not find checksum for ${KERNEL_TARBALL} in sha256sums.asc"
    fi

    log "Expected SHA256: ${EXPECTED_SHA256}"

    # Calculate actual checksum
    ACTUAL_SHA256=$(sha256sum "${KERNEL_TARBALL}" | awk '{print $1}')
    log "Actual SHA256:   ${ACTUAL_SHA256}"

    # Verify checksums match
    if [ "${EXPECTED_SHA256}" != "${ACTUAL_SHA256}" ]; then
        error "SHA256 checksum verification FAILED!
Expected: ${EXPECTED_SHA256}
Actual:   ${ACTUAL_SHA256}

The downloaded kernel tarball is corrupted or has been tampered with.
Aborting build for security reasons."
    fi

    log "✓ SHA256 checksum verification PASSED"

    # Mark as verified
    touch "${KERNEL_TARBALL}.verified"

    # Clean up checksum file
    rm -f sha256sums.asc
else
    log "Using cached and verified kernel source: ${KERNEL_TARBALL}"
fi

# Extract kernel
log "Extracting kernel source..."
if ! tar -xf "${KERNEL_TARBALL}"; then
    error "Failed to extract kernel tarball: ${KERNEL_TARBALL}"
fi
log "✓ Kernel extracted"

log "Entering kernel source directory: linux-${KERNEL_VERSION}"
if ! cd "linux-${KERNEL_VERSION}"; then
    error "Failed to enter kernel directory: linux-${KERNEL_VERSION}"
fi

# Use kernel's default x86_64 config as base
log "Creating default x86_64 kernel configuration..."
make defconfig > /dev/null 2>&1 || error "Failed to create default config"

# Load kernel profile configuration
PROFILE_FILE="${PROFILE_DIR}/${KERNEL_PROFILE}.config"
if [ ! -f "${PROFILE_FILE}" ]; then
    error "Kernel profile '${KERNEL_PROFILE}' not found at ${PROFILE_FILE}"
fi

log "Loading kernel profile: ${KERNEL_PROFILE}"
# shellcheck source=configs/virt.config
source "${PROFILE_FILE}"

# Verify configs were set before olddefconfig
log "Verifying FIPS configs were set by scripts/config..."
echo "=== Pre-olddefconfig Status ==="
grep "^CONFIG_CRYPTO_FIPS=\|^# CONFIG_CRYPTO_FIPS " .config || echo "CONFIG_CRYPTO_FIPS not found in .config"
grep "^CONFIG_DEBUG_KERNEL=\|^# CONFIG_DEBUG_KERNEL " .config || echo "CONFIG_DEBUG_KERNEL not found"
grep "^CONFIG_CRYPTO_MANAGER_DISABLE_TESTS=\|^# CONFIG_CRYPTO_MANAGER_DISABLE_TESTS " .config || echo "CONFIG_CRYPTO_MANAGER_DISABLE_TESTS not found"
grep "^CONFIG_MODULE_SIG=\|^# CONFIG_MODULE_SIG " .config || echo "CONFIG_MODULE_SIG not found"
echo "================================="

# Apply config changes
log "Running make olddefconfig to resolve dependencies..."
make olddefconfig > /dev/null 2>&1 || error "Failed to apply config"

# Verify FIPS is enabled in final config
log "Verifying FIPS configuration..."
log "Checking FIPS and dependencies in .config:"
echo "=== FIPS Configuration Status ==="
grep "CONFIG_DEBUG_KERNEL\|CONFIG_CRYPTO_MANAGER_DISABLE_TESTS\|CONFIG_CRYPTO_DRBG\|CONFIG_MODULE_SIG\|CONFIG_CRYPTO_FIPS\|CONFIG_MODULES" .config | grep -E "=y|is not set" || echo "No matches found"
echo "================================="

if ! grep -q "^CONFIG_CRYPTO_FIPS=y" .config; then
    log "ERROR: CONFIG_CRYPTO_FIPS is not enabled in final kernel configuration!"
    log "This usually means dependencies are not met. Checking what might be wrong..."

    # Check if modules are enabled (FIPS needs either MODULE_SIG or !MODULES)
    if grep -q "^CONFIG_MODULES=y" .config; then
        log "Modules are enabled, checking MODULE_SIG..."
        if ! grep -q "^CONFIG_MODULE_SIG=y" .config; then
            log "ERROR: CONFIG_MODULE_SIG is not enabled but needed for FIPS with modules!"
        fi
    fi

    # Check CRYPTO_MANAGER_DISABLE_TESTS (should be NOT set for FIPS)
    if grep -q "^CONFIG_CRYPTO_MANAGER_DISABLE_TESTS=y" .config; then
        log "ERROR: CONFIG_CRYPTO_MANAGER_DISABLE_TESTS is enabled but must be disabled for FIPS!"
        log "Crypto self-tests are disabled which prevents FIPS from working"
    fi
    if ! grep -q "^# CONFIG_CRYPTO_MANAGER_DISABLE_TESTS is not set" .config; then
        log "WARNING: CONFIG_CRYPTO_MANAGER_DISABLE_TESTS status unclear"
    fi

    # Check DRBG
    if ! grep -q "^CONFIG_CRYPTO_DRBG=y" .config; then
        log "ERROR: CONFIG_CRYPTO_DRBG is not enabled!"
    fi

    error "Cannot continue without FIPS enabled. Please review above errors."
fi
log "✓ CONFIG_CRYPTO_FIPS=y verified in kernel configuration"

# Build kernel
log "Building FIPS kernel (this may take 15-30 minutes)..."
log "Using $(nproc) CPU cores"
# Write build log to /output so it persists after container exits
BUILD_LOG="${OUTPUT_DIR}/kernel-build.log"
if ! make -j"$(nproc)" bzImage modules 2>&1 | tee "${BUILD_LOG}"; then
    echo ""
    echo "=========================================="
    echo "KERNEL BUILD FAILED"
    echo "=========================================="
    echo "Last 100 lines of build output:"
    tail -100 "${BUILD_LOG}"
    echo "=========================================="
    error "Kernel compilation failed. See above for details and full log at ${BUILD_LOG}"
fi

# Get kernel version string
KVER=$(make -s kernelversion)
log "Built kernel version: ${KVER}"

# Prepare output
mkdir -p "${OUTPUT_DIR}"

# Copy kernel image
log "Copying kernel image..."
cp arch/x86/boot/bzImage "${OUTPUT_DIR}/vmlinuz-fips" || error "Failed to copy kernel"

# Install modules to temporary location
log "Installing kernel modules..."
MODULES_TEMP="/tmp/modules-fips"
mkdir -p "${MODULES_TEMP}"
make modules_install INSTALL_MOD_PATH="${MODULES_TEMP}" > /dev/null 2>&1 || error "Failed to install modules"

# Create modules tarball
log "Creating modules archive..."
cd "${MODULES_TEMP}"
tar -czf "${OUTPUT_DIR}/modules-fips-${KVER}.tar.gz" lib/modules/${KVER} || error "Failed to create modules archive"

# Copy System.map and config for reference
log "Copying System.map and kernel config..."
cp "/build/linux-${KERNEL_VERSION}/System.map" "${OUTPUT_DIR}/System.map-fips"
cp "/build/linux-${KERNEL_VERSION}/.config" "${OUTPUT_DIR}/config-fips"

# Create version file
echo "${KVER}" > "${OUTPUT_DIR}/kernel-version.txt"

# Create SHA256 checksums
cd "${OUTPUT_DIR}"
sha256sum vmlinuz-fips > vmlinuz-fips.sha256
sha256sum "modules-fips-${KVER}.tar.gz" > "modules-fips-${KVER}.tar.gz.sha256"

log ""
log "=========================================="
log "FIPS Kernel Build Complete!"
log "=========================================="
log "Kernel image: ${OUTPUT_DIR}/vmlinuz-fips"
log "Modules: ${OUTPUT_DIR}/modules-fips-${KVER}.tar.gz"
log "Version: ${KVER}"
log ""
