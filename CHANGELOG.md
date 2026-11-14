# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The images are tagged by kubectl version; these versions describe the image
and the pipeline that builds it.

## [Unreleased]

### Changed

- **`SECURITY.md` and the image's `org.opencontainers.image.authors` label give the public contact address**, and `SECURITY.md` links GitHub's form for a private vulnerability report directly. The label reaches the published images with the next weekly rebuild; nothing else in them changes.

## [1.0.3] - 2026-11-12

### Changed

- **yq v4.54.3 in every line**, verified by the sha256 values its release's checksums file gives. kubectl stays on 1.37.2, 1.36.6 and 1.35.10, the current patch releases of their minors.

### Upgrading

yq v4.54.3 changes three things a script may rely on:

- **`yq -i` refuses a read-only file**, and on a symbolic link it writes the edited file in the link's place instead of changing the file the link points to (yq #2973). A ConfigMap or Secret volume is mounted read-only, so `yq -i` on its files failed before as well. A script that writes its own file into an emptyDir and edits that in place, as Bitnami's milvus chart does, works as before.
- **`--split-exp` writes only inside the current directory** unless `--security-allow-write-any-path` is given, which restores the old behaviour for trusted input (yq #2965).
- **YAML aliases are kept across the documents of one input stream**, without leaking anchors between files (yq #2956).

The drop-in test now runs `yq e -i` on a file the script wrote itself, on both images, and checks each of the three changes on this one; each of those checks fails on yq v4.54.2.

### Fixed

- **The daily pin check no longer reports an index pushed again over the same builds as drift.** `freshness.yml` compared each pinned base digest with the digest its tag names now and failed on any difference, so a publisher pushing the index again over the very same images (a platform added, an attestation rewritten) turned it red for an image that had not changed. It now also compares the builds this image is made from under both digests: linux/amd64 alone when every stage from that base is built on the runner (`--platform=$BUILDPLATFORM` or `${BUILDPLATFORM}`), linux/amd64 and linux/arm64 when any stage is built for each published platform, as the fleet's triage judges a re-pushed base. The same builds pass with a notice naming both digests; a new build, or one that cannot be read, still fails.

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

[Unreleased]: https://github.com/heyvaldemar/kubectl-docker/compare/v1.0.3...HEAD
[1.0.3]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.3
[1.0.2]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.2
[1.0.1]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.1
[1.0.0]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.0
