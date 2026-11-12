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
# The yq checks below are single-quoted on purpose: each runs inside a
# container, and its variables expand there, not here.
# shellcheck disable=SC2016
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
# A hook that edits a file it wrote itself in place with yq e -i, as
# Bitnami's milvus chart does with the same yq in os-shell.
c='d=$(mktemp -d) && printf "kafka:\n  ssl:\n    enabled: false\n" > "$d/c.yaml" && yq e -i ".kafka.ssl.enabled = true" "$d/c.yaml" && yq .kafka.ssl.enabled "$d/c.yaml" | grep -qx true'
if docker run --rm --platform linux/amd64 --entrypoint bash "$REF" -c "$c" >/dev/null 2>&1; then
  if docker run --rm --entrypoint bash "$IMAGE" -c "$c" >/dev/null 2>&1; then ok "yq e -i on a file it wrote runs on both"; else bad "yq e -i on a file it wrote runs on bitnami/kubectl and not here"; fi
else
  bad "yq e -i on a file it wrote does not run on bitnami/kubectl either; the test is wrong"
fi

# What yq v4.54.3 changed, as this image behaves now (CHANGELOG 1.0.3,
# Upgrading). bitnami/kubectl's older yq does otherwise, so these run here
# only: each was seen to fail on yq v4.54.2.
here() {
  local c="$1" what="$2"
  if docker run --rm --entrypoint bash "$IMAGE" -c "$c" >/dev/null 2>&1; then ok "$what"; else bad "$what: '$c' fails here"; fi
}
here 'd=$(mktemp -d) && printf "a: 1\n" > "$d/t.yaml" && ln -s "$d/t.yaml" "$d/l.yaml" && yq -i ".a = 2" "$d/l.yaml" && [ ! -L "$d/l.yaml" ] && yq .a "$d/t.yaml" | grep -qx 1 && yq .a "$d/l.yaml" | grep -qx 2' "yq -i replaces a symbolic link with the edited file and leaves its target as it was"
here 'd=$(mktemp -d) && printf "a: 1\n" > "$d/t.yaml" && chmod 444 "$d/t.yaml" && ! yq -i ".a = 2" "$d/t.yaml" && yq .a "$d/t.yaml" | grep -qx 1' "yq -i refuses a read-only file and leaves it as it was"
here 'd=$(mktemp -d) && mkdir "$d/w" && cd "$d/w" && ! printf "a: 1\n---\na: 2\n" | yq -s "\"../out_\" + \$index" && [ ! -e ../out_0.yml ]' "yq --split-exp writes nothing outside the current directory by default"
if docker run --rm --entrypoint sh "$IMAGE" -c 'mkdir -p /.kube/cache && rm -rf /.kube/cache'; then ok "kubectl's cache directory can be made under /.kube, as there"; else bad "/.kube/cache cannot be made"; fi

[ "$fail" -eq 0 ] || { echo "Not a drop-in for bitnami/kubectl." >&2; exit 1; }
echo "A drop-in for bitnami/kubectl."
