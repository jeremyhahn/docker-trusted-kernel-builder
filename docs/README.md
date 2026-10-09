# Documentation index

- [README.md](../README.md) — what the FIPS kernel builder is, the FIPS configuration, and how to build with `make build`.
- [ROADMAP.md](../ROADMAP.md) — planned work.
- [configs/README.md](../configs/README.md) — kernel configuration profiles (`virt`, `full`).
- [CLAUDE.md](../CLAUDE.md) — project and agent instructions; points at the company standards.

## Build

Covered in [README.md](../README.md) (Usage). Inputs: [Dockerfile](../Dockerfile), [Makefile](../Makefile), [build-fips-kernel.sh](../build-fips-kernel.sh).

## Config

Kernel profiles live in [configs/](../configs/): `virt.config` and `full.config`.

## Release

Release automation is in [.github/workflows/release.yml](../.github/workflows/release.yml); CI is in [.github/workflows/ci.yml](../.github/workflows/ci.yml).
