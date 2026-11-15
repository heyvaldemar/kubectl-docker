# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The images are tagged by kubectl version; these versions describe the image
and the pipeline that builds it.

## [Unreleased]

### Changed

- **Cosign is installed before anything is pushed.** The build job installs cosign v2.6.1 before `Build and push`, and the signing action finds it there. On 5 November 2026 in heyvaldemar/kubectl-docker, GitHub answered `cosign-installer` 504 after the push, so signing could not run and two tags named an unsigned image for 89 minutes; a failed install now fails the job before anything is public. Anything else that fails between the push and the signature still leaves the image unsigned until the read-back signs it or names it.

## [1.0.4] - 2026-11-15

### Added

- **Every tag a run pushes is read back from Docker Hub after signing.** For each one the run resolves the digest the tag names now, and requires that digest's cosign signature (`sha256-<digest>.sig`, HTTP 200) and a `cosign verify` that passes: for the digest this run pushed, as this run's exact workflow identity and commit; for a digest another run has moved the tag to since, as this repository's publish workflow on any ref. A missing signature fails the job. A digest this run built is then signed again; a digest it did not build never is. It also runs after a push refused half way: the build reports no digest then, so the tags it had already moved are reported and fail the job, but are not signed. What it found goes to the run summary (`scripts/verify-published.sh`).
- **The signing steps are shown each failure they exist for, before anything is published.** Signing, attesting and reading back are one action, `.github/actions/sign-attest-verify`, the same as in heyvaldemar/aws-kubectl-docker 2.3.1. The build job runs it after its push, and a new `signing` job runs it six times on throwaway images in a registry on the runner, signed with keys made there. The cases: nothing planted; the real attestation step failing (the job has no OIDC token, so the step fails before it contacts anything; the image is signed before the failure, and the job still fails); signing failing; signing skipped without an error, where the read-back alone fails the job and signs the digest; a tag another run moved to an image signed by a stranger's key (the job fails, and that image is left as it is); and a push that stopped half way (the job fails, nothing is signed). Nothing reaches Docker Hub, GitHub's attestation store or Sigstore's public log. The build waits for it, and so does the required check.

### Changed

- **`SECURITY.md` and the image's `org.opencontainers.image.authors` label give the public contact address**, and `SECURITY.md` links GitHub's form for a private vulnerability report directly. The label reaches the published images with the next weekly rebuild; nothing else in them changes.

### Fixed

- **Signing no longer depends on the build attestation.** The cosign steps came after `actions/attest-build-provenance` and ran only if it succeeded: the order in which heyvaldemar/aws-kubectl-docker shipped an unsigned image on 2 November 2026, when Rekor, Sigstore's transparency log, answered its attestation 502 and three of its tags named that image for 37 hours. One run here lost its signature another way. On 5 November 2026 GitHub answered `cosign-installer` 504 after the push ([42056140684](https://github.com/heyvaldemar/kubectl-docker/actions/runs/42056140684), first attempt), signing was skipped, and `1.36` and `1.36.6` named an unsigned image, `sha256:f6f9dc5ef80ff9d0cd590e17219f324792f1b316d26eb41baea6adc68a2b90f9`, from 15:38 to 17:07 UTC, when the rerun replaced it. No tag names it now; it can still be pulled by digest, and it stays unsigned, because a signature made now would name a later run than the one that built it. Signing still needs cosign installed, so that failure would still leave an image unsigned; the read-back below now names it in the run, digest and tags, as UNSIGNED. The pushed digest is now signed first, then attested; a failed attestation still fails the job, after the signature exists. It is signed once, not once per tag (the signature belongs to the digest either way), and a failed attempt is tried again twice.

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

[Unreleased]: https://github.com/heyvaldemar/kubectl-docker/compare/v1.0.4...HEAD
[1.0.4]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.4
[1.0.3]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.3
[1.0.2]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.2
[1.0.1]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.1
[1.0.0]: https://github.com/heyvaldemar/kubectl-docker/releases/tag/v1.0.0
