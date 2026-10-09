# FIPS Kernel Builder
#
# Builds a FIPS-capable Linux kernel inside a container.

# Use 6.12.8 to match the Alpine 3.22 LTS kernel.
KERNEL_VERSION ?= 6.12.8
KERNEL_PROFILE ?= virt
OUTPUT_DIR ?= $(PWD)/output
DOCKER_IMAGE ?= trusted-kernel-builder
BUILD_CONTAINER ?= trusted-kernel-build

# actionlint pin for the docker fallback in `lint`; matches the version the
# runner and worker images bake (devops.md §9).
ACTIONLINT_VERSION ?= 1.7.12
WORKFLOWS := $(wildcard .github/workflows/*.yml .github/workflows/*.yaml)

.PHONY: all image build test lint require-trivy fs-scan image-scan security clean

all: build

image:
	docker build -t $(DOCKER_IMAGE) .

# Artifacts are copied out of a stopped container rather than bind-mounted.
# A bind mount source is resolved by the docker DAEMON, not the client, so in
# CI — where the job itself runs inside a container sharing the host's docker
# socket — the workspace path does not exist for the daemon and `docker run`
# dies with exit 125. `docker cp` streams through the API and extracts on the
# client side, so it lands in the workspace on every host.
build: image
	@echo "Building FIPS-capable kernel $(KERNEL_VERSION) with profile $(KERNEL_PROFILE)..."
	@docker rm -f $(BUILD_CONTAINER) >/dev/null 2>&1 || true
	docker run --name $(BUILD_CONTAINER) \
		-e KERNEL_VERSION=$(KERNEL_VERSION) \
		-e KERNEL_PROFILE=$(KERNEL_PROFILE) \
		$(DOCKER_IMAGE)
	@rm -rf $(OUTPUT_DIR)
	@mkdir -p $(OUTPUT_DIR)
	docker cp $(BUILD_CONTAINER):/output/. $(OUTPUT_DIR)/
	@docker rm $(BUILD_CONTAINER) >/dev/null
	@echo ""
	@echo "Build complete. Artifacts in: $(OUTPUT_DIR)"
	@ls -lh $(OUTPUT_DIR)

test:
	@echo "Testing FIPS kernel artifacts..."
	@if [ ! -f $(OUTPUT_DIR)/vmlinuz-fips ]; then \
		echo "ERROR: Kernel image not found. Run 'make build' first."; \
		exit 1; \
	fi
	@if [ ! -f $(OUTPUT_DIR)/kernel-version.txt ]; then \
		echo "ERROR: Version file not found."; \
		exit 1; \
	fi
	@echo "✓ Kernel image exists: $(OUTPUT_DIR)/vmlinuz-fips"
	@stat -c "Size: %s bytes" $(OUTPUT_DIR)/vmlinuz-fips
	@echo "Kernel version: $$(cat $(OUTPUT_DIR)/kernel-version.txt)"
	@cd $(OUTPUT_DIR) && sha256sum -c vmlinuz-fips.sha256
	@echo "✓ Kernel image checksum verified"
	@echo "✓ Modules tarball: $(OUTPUT_DIR)/modules-fips-$$(cat $(OUTPUT_DIR)/kernel-version.txt).tar.gz"
	@stat -c "Size: %s bytes" "$(OUTPUT_DIR)/modules-fips-$$(cat $(OUTPUT_DIR)/kernel-version.txt).tar.gz"
	@cd $(OUTPUT_DIR) && sha256sum -c "modules-fips-$$(cat kernel-version.txt).tar.gz.sha256"
	@echo "✓ Modules tarball checksum verified"

# Linters are piped their input on stdin: a `-v $(PWD):/mnt` bind mount fails
# in CI for the same daemon-path reason documented on the build target.
#
# actionlint (devops.md §4) runs from PATH when installed, so it also finds
# .github/actionlint.yaml; otherwise from its pinned image on stdin, which sees
# no config file. None is needed while every job runs on ubuntu-latest; a
# self-hosted runner label must be declared there and actionlint installed.
lint:
	@echo "Linting workflows (actionlint)..."
	@if command -v actionlint >/dev/null 2>&1; then \
		actionlint $(WORKFLOWS); \
	else \
		for f in $(WORKFLOWS); do \
			echo "  $$f"; \
			docker run --rm -i rhysd/actionlint:$(ACTIONLINT_VERSION) \
				-stdin-filename "$$f" - < "$$f" || exit 1; \
		done; \
	fi
	@echo "Linting Dockerfile (hadolint)..."
	docker run --rm -i hadolint/hadolint:latest \
		hadolint --failure-threshold warning - < Dockerfile
	@echo "Linting shell scripts (shellcheck)..."
	@for f in build-fips-kernel.sh configs/*.config; do \
		echo "  $$f"; \
		docker run --rm -i koalaman/shellcheck:stable \
			--severity=warning --shell=bash - < "$$f" || exit 1; \
	done

# devops.md §8. The Go suite (gosec, govulncheck, go mod verify, golangci-lint)
# has no analogue here — this repo contains no Go code — so the gate is the
# Dockerfile/shell linters plus both trivy scans.
# A scan that cannot run must fail, never pass vacuously.
require-trivy:
	@command -v trivy >/dev/null 2>&1 || { \
		echo "ERROR: trivy not found on PATH; the security scans cannot run." >&2; \
		echo "Install it, e.g.:" >&2; \
		echo "  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin" >&2; \
		exit 1; \
	}

fs-scan: require-trivy
	@echo "Scanning source tree (trivy fs)..."
	trivy fs --scanners vuln,secret \
		--severity CRITICAL,HIGH --exit-code 1 .

# --ignore-unfixed is ratified for IMAGE scans only (devops.md §8): base images
# carry unfixable distro advisories at any moment, so a raw gate is permanently
# red. The fs scan above deliberately does NOT use it.
image-scan: require-trivy image
	@echo "Scanning image (trivy image)..."
	trivy image --scanners vuln,secret \
		--severity CRITICAL,HIGH --ignore-unfixed --exit-code 1 $(DOCKER_IMAGE)

security: lint fs-scan image-scan
	@echo "✓ Security suite passed"

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(OUTPUT_DIR)
	@docker rm -f $(BUILD_CONTAINER) >/dev/null 2>&1 || true
	@docker rmi $(DOCKER_IMAGE) 2>/dev/null || true
