# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The images are tagged by kubectl version; these versions describe the image
and the pipeline that builds it.

## [Unreleased]

### Fixed

- **The daily pin check no longer reports an index pushed again over the same builds as drift.** `freshness.yml` compared each pinned base digest with the digest its tag names now and failed on any difference, so a publisher pushing the index again over the very same images (a platform added, an attestation rewritten) turned it red for an image that had not changed. It now also compares the builds this image is made from under both digests: linux/amd64 for a stage built on the runner, linux/amd64 and linux/arm64 for a stage built for each published platform. The same builds pass with a notice naming both digests; a new build, or one that cannot be read, still fails.

## [1.0.2] - 2026-11-07

### Changed

- **yq v4.54.2 in every line**, verified by the sha256 values its release's checksums file gives. It quotes unsafe values in `-o=shell -r` output (GHSA-h2cv-65fq-jgrp) and fixes `map_values`, `ireduce` and comment handling; the rest is in its release notes. kubectl stays on 1.37.2, 1.36.6 and 1.35.10.

## [1.0.1] - 2026-11-05

### Changed

- **Debian's 2026-11-04 `debian:trixie-slim` repush is the base of every line.** The pin moves from `sha256:f6b08b09…` to `sha256:a72b4433…`. The build picked up kubectl 1.36.6 and 1.35.10, the current patch releases of their minors, as every weekly rebuild does; 1.37 stays on 1.37.2 and yq on v4.54.1.

## [1.0.0] - 2026-10-26

### Added

- **heyvaldemar/kubectl: the three newest Kubernetes minors, each rebuilt every week.** Tags `latest`, the minor (`1.37`) and the patch release (`1.37.1`), the ones `bitnami/kubectl` users already write; `linux/amd64` and `linux/arm64`. `bitnami/kubectl` has published only `latest` since August 2025, and its versioned tags stopped at 1.33.4.
- **A drop-in for bitnami/kubectl, checked on every build** against `bitnamilegacy/kubectl:1.33.4`: user `1001` in group `0`, entrypoint `kubectl`, command `--help`, `HOME=/` with a writable `/.kube`, the same tools, its paths as links, and every executable on its `PATH` or a reason in `tests/drop-in-absent.tsv`.
- **A contract with the published image**: nothing a pipeline used under a tag disappears from it without a line in `tests/contract-removed.tsv`.
- **kubectl and yq verified by sha256** before they are installed; every digest signed with cosign, keyless, with SBOM, SLSA provenance and a GitHub build attestation; Trivy on every published line.
- **Every test shown the breaks it exists for**: nine planted violations in `tests/plants.tsv`, run in CI.

[Unreleased]: https://github.com/heyvaldemar/kubectl-docker/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.2
[1.0.1]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.1
[1.0.0]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.0
