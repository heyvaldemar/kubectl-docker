# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The images are tagged by kubectl version; these versions describe the image
and the pipeline that builds it.

## [Unreleased]

_(no unreleased changes yet)_

## [1.0.0] - 2026-10-26

### Added

- **heyvaldemar/kubectl: the three newest Kubernetes minors, each rebuilt every week.** Tags `latest`, the minor (`1.37`) and the patch release (`1.37.1`), the ones `bitnami/kubectl` users already write; `linux/amd64` and `linux/arm64`. `bitnami/kubectl` has published only `latest` since August 2025, and its versioned tags stopped at 1.33.4.
- **A drop-in for bitnami/kubectl, checked on every build** against `bitnamilegacy/kubectl:1.33.4`: user `1001` in group `0`, entrypoint `kubectl`, command `--help`, `HOME=/` with a writable `/.kube`, the same tools, its paths as links, and every executable on its `PATH` or a reason in `tests/drop-in-absent.tsv`.
- **A contract with the published image**: nothing a pipeline used under a tag disappears from it without a line in `tests/contract-removed.tsv`.
- **kubectl and yq verified by sha256** before they are installed; every digest signed with cosign, keyless, with SBOM, SLSA provenance and a GitHub build attestation; Trivy on every published line.
- **Every test shown the breaks it exists for**: nine planted violations in `tests/plants.tsv`, run in CI.

[Unreleased]: https://github.com/heyvaldemar/kubectl-docker/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.0
