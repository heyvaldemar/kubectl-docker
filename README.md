# kubectl Docker Image

[![Publish Docker Image](https://github.com/heyvaldemar/kubectl-docker/actions/workflows/publish.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/kubectl-docker/actions/workflows/publish.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/heyvaldemar/kubectl.svg)](https://hub.docker.com/r/heyvaldemar/kubectl)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

kubectl for pipelines and Helm hooks: one Kubernetes minor per tag, rebuilt every week, signed, and laid out like `bitnami/kubectl`, so a chart written for that image runs on this one unchanged.

`bitnami/kubectl` has published one tag since August 2025: `latest`. Its versioned tags stopped at 1.33.4 on 2025-08-22 and live on, unmaintained, as `bitnamilegacy/kubectl`. A chart or pipeline that pinned `bitnami/kubectl:1.33` stopped receiving security fixes that day, and one that switched to `latest` now gets whatever kubectl minor ships next, which kubectl's one-minor version skew policy does not promise will talk to its cluster.

```bash
docker run --rm heyvaldemar/kubectl:1.37 version --client
docker run --rm -v ~/.kube/config:/.kube/config:ro heyvaldemar/kubectl:1.37 get nodes
```

In a chart that used `bitnami/kubectl:<version>`, change the repository and pick the minor of your cluster:

```yaml
image:
  repository: heyvaldemar/kubectl
  tag: "1.37"
```

## Tags

| Tag | What it is | Moves |
|---|---|---|
| `1.37`, `1.36`, `1.35` | the three newest Kubernetes minors, the window upstream supports | every week and on every change here, with the minor's current patch release and Debian's security updates; never to another minor |
| `1.37.1` | one patch release | every week, with Debian's security updates, while it is its minor's current patch |
| `latest` | the newest minor | as `1.37`, and to the next minor the week it ships |

Every tag moves, so a pinned tag keeps receiving security fixes. For an image that never changes, pin its digest:

```bash
docker buildx imagetools inspect heyvaldemar/kubectl:1.37 --format '{{.Manifest.Digest}}'
```

A minor that falls out of the newest three keeps its last image and stops moving. Images are `linux/amd64` and `linux/arm64`.

## A drop-in for bitnami/kubectl

Charts depend on how the image runs, not only on kubectl. This one keeps what `bitnami/kubectl` did:

- the user, `1001` with group `0`, so it also runs under an arbitrary UID in group 0 (OpenShift);
- the entrypoint `kubectl` and the command `--help`, so `args: ["get", "pods"]` works as it did;
- `HOME=/`, with `/.kube` writable by group 0, so a kubeconfig mounted at `/.kube/config` is found and kubectl's discovery cache works;
- the tools hooks call: bash, jq, yq, git, tar, gzip, envsubst, openssl, base64, ps, pgrep, kill; no curl or wget, as there;
- its paths, as links: `/opt/bitnami/kubectl/bin/kubectl` and `/opt/bitnami/common/bin/yq` run.

**It is checked, not claimed.** `tests/drop-in-test.sh` runs on every build against the last versioned Bitnami image, `bitnamilegacy/kubectl:1.33.4`: the same user, entrypoint, command and `HOME`, the same calls a hook makes, and every executable on its `PATH` on this one's. The ones that are not here are named in [`tests/drop-in-absent.tsv`](tests/drop-in-absent.tsv), each with its reason: Bitnami's own package scripts, and tools Debian 13 no longer ships in its slim base (`apt-key`, `adduser`, util-linux extras). The test fails on any absence without a reason.

A hook that calls only kubectl does not need this image. The Kubernetes project publishes `registry.k8s.io/kubectl:v1.37.1`: kubectl and nothing else, no shell. Use that one. This image is for the hooks that run `bash -c` with jq, yq or envsubst around kubectl, which is what most charts built on `bitnami/kubectl` do.

## Nothing you used yesterday disappears today

Before anything is published, each build is compared with the image already published under its tag (`scripts/contract-test.sh`): every executable on its `PATH`, its user, `HOME`, working directory, entrypoint and command, and kubectl on the tag's minor and no older. A removal has to be named in `tests/contract-removed.tsv` and in the changelog. Each test is shown the breaks it exists for (`tests/plants.tsv`, run in CI): the image running as root, jq or the procps tools left out, a Bitnami path gone, `/.kube` not writable, another entrypoint, `HOME` moved, a yq binary with another checksum, a kubectl that is not the version the image says.

## Supply chain

- Debian 13 slim, pinned by digest.
- kubectl verified against the sha256 dl.k8s.io publishes beside it; yq against the sha256 from its release's own checksums file, pinned in the `Dockerfile`. Neither is installed if it does not match.
- Every published digest is signed with cosign, keyless, by this repository's workflow; SBOM (SPDX) and SLSA provenance are attached, and build provenance is attested in [GitHub Attestations](https://github.com/heyvaldemar/kubectl-docker/attestations).
- Trivy scans every published line and reports CRITICAL and HIGH fixable findings to the Security tab.
- Every GitHub Action is pinned to a commit SHA, except the SLSA generator `release-assets.yml` calls by tag (`@v2.1.0`), because it verifies its own reference at run time and refuses a SHA.

```bash
cosign verify heyvaldemar/kubectl:1.37 \
  --certificate-identity-regexp "https://github.com/heyvaldemar/kubectl-docker/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

## Build it yourself

```bash
docker build --build-arg KUBE_VERSION=v1.37.1 -t kubectl:local .
./scripts/smoke-test.sh kubectl:local
./tests/drop-in-test.sh kubectl:local
./scripts/contract-test.sh kubectl:local heyvaldemar/kubectl:1.37 1.37
```

`KUBE_VERSION` is required; the build refuses to guess.

## Related

[heyvaldemar/aws-kubectl](https://hub.docker.com/r/heyvaldemar/aws-kubectl) is the same idea with the AWS CLI beside kubectl, for EKS pipelines, and the same weekly lines (`kube-1.37`).

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** · Docker Captain · CNCF Ambassador · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>
