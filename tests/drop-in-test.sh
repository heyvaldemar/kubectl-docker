#!/usr/bin/env bash
# Is this image a drop-in for bitnami/kubectl?
#
#   tests/drop-in-test.sh <image> [<bitnami-image>]
#
# A chart or pipeline written for bitnami/kubectl depends on how that image
# runs, not only on kubectl: the user (1001, group 0), the entrypoint and
# command, HOME=/ with a writable /.kube, the tools its hooks call, and
# sometimes the full path /opt/bitnami/kubectl/bin/kubectl. The last versioned
# Bitnami image (bitnamilegacy/kubectl:1.33.4, August 2025) is the reference.
# Every executable on its PATH must be on this image's PATH, unless
# tests/drop-in-absent.tsv names it with the reason.
set -euo pipefail
IMAGE="${1:?usage: drop-in-test.sh <image> [<bitnami-image>]}"
REF="${2:-bitnamilegacy/kubectl:1.33.4}"
ABSENT="$(dirname "$0")/drop-in-absent.tsv"
fail=0
bad() { echo "FAIL: $*" >&2; fail=1; }
ok() { echo "OK: $*"; }

# The reference is amd64 only; compare on the same architecture. Docker
# Desktop's containerd store needs --platform to read an amd64 image's config
# on an arm64 host; older engines (GitHub's runners) do not know the flag.
docker pull -q --platform linux/amd64 "$REF" >/dev/null
ref_inspect() { docker image inspect --platform linux/amd64 "$@" 2>/dev/null || docker image inspect "$@"; }
for field in User Entrypoint Cmd; do
  a="$(ref_inspect -f "{{json .Config.$field}}" "$REF")"
  b="$(docker image inspect -f "{{json .Config.$field}}" "$IMAGE")"
  if [ "$a" = "$b" ]; then ok "$field as bitnami/kubectl ($b)"; else bad "$field: bitnami/kubectl $a, this image $b"; fi
done
a="$(ref_inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$REF" | sed -n 's/^HOME=//p')"
b="$(docker image inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGE" | sed -n 's/^HOME=//p')"
if [ "$a" = "$b" ]; then ok "HOME as bitnami/kubectl ($b)"; else bad "HOME: bitnami/kubectl '$a', this image '$b'"; fi

executables() {
  docker run --rm --platform "$2" --entrypoint sh "$1" -c '
    IFS=:
    for d in $PATH; do
      [ -d "$d" ] || continue
      for f in "$d"/*; do [ -f "$f" ] && [ -x "$f" ] && echo "${f##*/}"; done
    done' | sort -u
}
unexplained=""
while IFS= read -r name; do
  [ -n "$name" ] || continue
  matched=false
  while IFS=$'\t' read -r pattern _; do
    case "$pattern" in ''|'#'*) continue ;; esac
    # shellcheck disable=SC2053  # the pattern is a glob on purpose
    if [[ "$name" == $pattern ]]; then matched=true; break; fi
  done <"$ABSENT"
  $matched || unexplained="$unexplained $name"
done < <(comm -23 <(executables "$REF" linux/amd64) <(executables "$IMAGE" "$(docker image inspect -f '{{.Os}}/{{.Architecture}}' "$IMAGE")"))
if [ -z "$unexplained" ]; then
  ok "every executable on bitnami/kubectl's PATH is here, or named in tests/drop-in-absent.tsv with its reason"
else
  bad "on bitnami/kubectl's PATH and not here, with no reason given:$unexplained"
fi

# The same calls a hook makes, on both images.
for c in "kubectl version --client" "/opt/bitnami/kubectl/bin/kubectl version --client" "yq --version" "jq --version" "envsubst --version" "bash -c true" "git --version"; do
  if docker run --rm --platform linux/amd64 --entrypoint sh "$REF" -c "$c" >/dev/null 2>&1; then
    if docker run --rm --entrypoint sh "$IMAGE" -c "$c" >/dev/null 2>&1; then ok "'$c' runs on both"; else bad "'$c' runs on bitnami/kubectl and not here"; fi
  fi
done
if docker run --rm --entrypoint sh "$IMAGE" -c 'mkdir -p /.kube/cache && rm -rf /.kube/cache'; then ok "kubectl's cache directory can be made under /.kube, as there"; else bad "/.kube/cache cannot be made"; fi

[ "$fail" -eq 0 ] || { echo "Not a drop-in for bitnami/kubectl." >&2; exit 1; }
echo "A drop-in for bitnami/kubectl."
