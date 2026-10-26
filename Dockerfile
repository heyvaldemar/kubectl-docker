# syntax=docker/dockerfile:1.7

# ──────────────────────────────────────────────────────────────────────────────
# heyvaldemar/kubectl: kubectl for pipelines and Helm hooks, one Kubernetes
# minor per tag, rebuilt every week, signed, and laid out like bitnami/kubectl,
# so a chart written for that image runs on this one unchanged: the same user
# (1001, group 0), the same entrypoint and command, HOME=/ with a writable
# /.kube, the same tools, and its paths as links.
#
# Stage 1 downloads kubectl and yq and verifies both: kubectl against the
# sha256 dl.k8s.io publishes beside it, yq against the sha256 pinned below
# from the release's own checksums file. Nothing from this stage but the two
# binaries reaches the image.
# ──────────────────────────────────────────────────────────────────────────────
FROM debian:trixie-slim@sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad AS builder

ARG TARGETARCH
ARG KUBE_VERSION
ARG YQ_VERSION=v4.54.1
ARG YQ_SHA256_AMD64=8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f
ARG YQ_SHA256_ARM64=189088da0c6429ec5178dfaab1a114805f6cab0b61b165ab236efedf1d57a71b
ARG DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN [ -n "${KUBE_VERSION}" ] || { echo "KUBE_VERSION is required, for example v1.37.1" >&2; exit 1; } \
 && ARCH="${TARGETARCH:-$(dpkg --print-architecture)}" \
 && case "$ARCH" in \
      amd64) YQ_SHA256="$YQ_SHA256_AMD64" ;; \
      arm64) YQ_SHA256="$YQ_SHA256_ARM64" ;; \
      *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
    esac \
 && curl -fsSLo kubectl "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kubectl" \
 && curl -fsSLo kubectl.sha256 "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kubectl.sha256" \
 && echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c - \
 && curl -fsSLo yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" \
 && echo "${YQ_SHA256}  yq" | sha256sum -c - \
 && chmod 0755 kubectl yq \
 && printf '%s\n' "$KUBE_VERSION" > kube-version

# ──────────────────────────────────────────────────────────────────────────────
# Stage 2: the image.
# ──────────────────────────────────────────────────────────────────────────────
FROM debian:trixie-slim@sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad AS final

ARG KUBE_VERSION
ARG VCS_REF=unknown
ARG BUILD_DATE=unknown
ARG DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# THE TOOLS HOOKS CALL. bitnami/kubectl carried bash, jq, yq, git, tar, gzip,
# envsubst, openssl, base64 and the procps tools (ps, pgrep, kill, watch), and
# no curl or wget; charts written for it call them by name. tar, gzip and base64 come with the base; yq is upstream's,
# verified in stage 1. tests/drop-in-test.sh checks every executable the last
# versioned Bitnami image had on its PATH is on this one.
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      gettext-base \
      git \
      jq \
      openssl \
      procps \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/kubectl /usr/local/bin/kubectl
COPY --from=builder /build/yq /usr/local/bin/yq
COPY --from=builder /build/kube-version /etc/kube-version

# BITNAMI'S PATHS, AS LINKS. A hook that calls /opt/bitnami/kubectl/bin/kubectl
# by its full path runs unchanged. HOME is /, as there, so a kubeconfig mounted
# at /.kube/config is found, and /.kube is writable by group 0, as there, so
# kubectl's discovery cache works for the runtime user (1001, or an arbitrary
# UID in group 0 on OpenShift).
RUN mkdir -p /opt/bitnami/kubectl/bin /opt/bitnami/common/bin /.kube \
 && ln -s /usr/local/bin/kubectl /opt/bitnami/kubectl/bin/kubectl \
 && ln -s /usr/local/bin/yq /opt/bitnami/common/bin/yq \
 && chmod 0775 /.kube

ENV HOME=/ \
    PATH=/opt/bitnami/common/bin:/opt/bitnami/kubectl/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="kubectl" \
      org.opencontainers.image.description="kubectl on Debian 13, one Kubernetes minor per tag, rebuilt weekly, signed; a drop-in for bitnami/kubectl." \
      org.opencontainers.image.authors="Vladimir Mikhalev <v@valdemar.ai>" \
      org.opencontainers.image.vendor="heyvaldemar" \
      org.opencontainers.image.source="https://github.com/heyvaldemar/kubectl-docker" \
      org.opencontainers.image.documentation="https://github.com/heyvaldemar/kubectl-docker#readme" \
      org.opencontainers.image.url="https://hub.docker.com/r/heyvaldemar/kubectl" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      io.heyvaldemar.kubectl.version="${KUBE_VERSION}"

USER 1001
ENTRYPOINT ["kubectl"]
CMD ["--help"]
