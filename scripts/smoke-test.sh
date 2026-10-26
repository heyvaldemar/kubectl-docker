#!/usr/bin/env bash
# Smoke test for heyvaldemar/kubectl: every promised tool answers, kubectl is
# the version the image says, and it runs the way the README says it does.
#
#   scripts/smoke-test.sh <image>
set -euo pipefail
IMAGE="${1:?usage: smoke-test.sh <image>}"
fail=0
bad() { echo "FAIL: $*" >&2; fail=1; }
ok() { echo "OK: $*"; }
sh_in() { docker run --rm --entrypoint sh "$IMAGE" -c "$1"; }

# The entrypoint is kubectl: arguments go straight to it.
if docker run --rm "$IMAGE" version --client --output=yaml >/dev/null; then ok "the entrypoint is kubectl"; else bad "'docker run <image> version --client' does not run kubectl"; fi
help="$(docker run --rm "$IMAGE" 2>&1 || true)"
if grep -q "kubectl controls the Kubernetes cluster manager" <<<"$help"; then ok "the default command prints kubectl's help"; else bad "the default command is not kubectl --help"; fi

for t in bash jq yq git tar gzip envsubst openssl base64 ps pgrep kill; do
  if sh_in "command -v $t >/dev/null"; then ok "$t is on PATH"; else bad "$t is missing"; fi
done
for c in "jq --version" "yq --version" "git --version" "openssl version" "envsubst --version" "ps --version"; do
  if sh_in "$c >/dev/null 2>&1"; then ok "$c answers"; else bad "$c does not answer"; fi
done

file="$(sh_in 'cat /etc/kube-version' | tr -d '[:space:]')"
client="$(docker run --rm "$IMAGE" version --client --output=json | jq -r '.clientVersion.gitVersion')"
if [ -n "$file" ] && [ "$file" = "$client" ]; then ok "/etc/kube-version ($file) matches kubectl"; else bad "/etc/kube-version '$file', kubectl '$client'"; fi

# shellcheck disable=SC2016  # expanded inside the image
who="$(sh_in 'echo "$(id -u):$(id -g) $HOME"')"
if [ "$who" = "1001:0 /" ]; then ok "runs as 1001:0 with HOME=/"; else bad "runs as '$who', not '1001:0 /'"; fi
if sh_in 'touch /.kube/.probe && rm /.kube/.probe'; then ok "/.kube is writable by the runtime user"; else bad "/.kube is not writable by 1001"; fi
if docker run --rm --user 123456:0 --entrypoint sh "$IMAGE" -c 'touch /.kube/.probe && rm /.kube/.probe'; then ok "/.kube is writable by an arbitrary UID in group 0 (OpenShift)"; else bad "/.kube is not writable by an arbitrary UID in group 0"; fi

for p in /opt/bitnami/kubectl/bin/kubectl /opt/bitnami/common/bin/yq; do
  if sh_in "$p --help >/dev/null 2>&1 || $p --version >/dev/null 2>&1"; then ok "$p runs (Bitnami path)"; else bad "$p does not run"; fi
done

if sh_in 'curl -fsSI -o /dev/null https://kubernetes.io 2>/dev/null || openssl s_client -connect kubernetes.io:443 -servername kubernetes.io </dev/null 2>/dev/null | grep -q "Verify return code: 0"'; then ok "TLS to kubernetes.io verifies against the image's CA bundle"; else bad "TLS verification failed"; fi

[ "$fail" -eq 0 ] || { echo "The smoke test failed." >&2; exit 1; }
echo "All checks passed."
