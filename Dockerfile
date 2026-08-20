# DS-0002 ACCEPTED RISK (owner ruling 2026-08-20): this is a BUILD-TIME tool
# image — it installs distro packages and produces artifacts, is never deployed
# as a service, and never faces traffic. Root is required for package installs
# and device/loop operations; a USER directive would break the build for no
# runtime benefit. Re-evaluate only if this image ever becomes a runtime image.
FROM alpine:3.22

# Install kernel build dependencies
# hadolint ignore=DL3018
RUN apk add --no-cache \
    build-base \
    bc \
    bison \
    flex \
    openssl \
    openssl-dev \
    elfutils-dev \
    linux-headers \
    perl \
    bash \
    wget \
    xz \
    findutils \
    gnupg \
    curl \
    ca-certificates \
    git

# Set working directory
WORKDIR /build

# Download kernel.org verification script
RUN wget -q -O /build/get-verified-tarball \
    https://git.kernel.org/pub/scm/linux/kernel/git/mricon/korg-helpers.git/plain/get-verified-tarball && \
    chmod +x /build/get-verified-tarball

# Copy kernel profile configurations
COPY configs/ /build/configs/

# Copy build script
COPY build-fips-kernel.sh /build/
RUN chmod +x /build/build-fips-kernel.sh

# Set entrypoint
ENTRYPOINT ["/build/build-fips-kernel.sh"]
