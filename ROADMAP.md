# docker-trusted-kernel-builder roadmap

> **Status: REFERENCE** · Owner: Software Department · Last verified: 2026-10-08
> Changes are proposed by docs-only PR.

## Mission

Trusted kernel builder image, in the build layer.
Builds a FIPS-enabled Linux kernel with TPM 2.0 and VirtIO from verified kernel.org source.
Ships the kernel image and modules as checksummed artifacts for go-trusted-platform.

## Current milestone

None. Target kind RC, no projected date.

## Now

- [#6](http://git.example.internal/jeremyhahn/docker-trusted-kernel-builder/issues/6) Trivy image verdict independent of the building runner — blocked: see issue
- [#11](http://git.example.internal/jeremyhahn/docker-trusted-kernel-builder/issues/11) signed release artifacts — open
- [#12](http://git.example.internal/jeremyhahn/docker-trusted-kernel-builder/issues/12) docs conformance for index and serena — open

## Next

- [#8](http://git.example.internal/jeremyhahn/docker-trusted-kernel-builder/issues/8) decommissioned task-worker.yml removed — open

## Later

Nothing accepted. New work arrives as issues.

## Dependencies

- Up: none; no go.mod, no in-house module pins.
- Down: go-trusted-platform consumes the built kernel and modules.

## Non-goals

- Kernel source and upstream patches; kernel.org owns them.
- Booting, attesting or running the kernel; go-trusted-platform owns that.
- Ownership boundaries: [docs/00](../handbook/software/docs/00-ownership-and-sdk-boundary.md).
