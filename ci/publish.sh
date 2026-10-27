#!/usr/bin/env bash
# Push a locally built image to the registry under one or more tags, signing
# it with a sigstore key when one is provided.
#
# The first tag is pushed (and signed). The other tags are pointed at the
# same manifest digest, so one signature covers all of them.
#
# Env:
#   SIGNING_KEY       contents of the private key from
#                     `skopeo generate-sigstore-key` (optional)
#   SIGNING_PASSWORD  its passphrase (required if SIGNING_KEY is set)
#   TLS_VERIFY        set to "false" only for local testing
#
# Prints the pushed manifest digest.
#
# Usage: publish.sh <local-image> <dest-repo> <tag> [tag...]
set -euo pipefail

fail() { echo "publish: FAIL: $*" >&2; exit 1; }

[[ $# -ge 3 ]] || fail "usage: $0 <local-image> <dest-repo> <tag> [tag...]"
src="$1"; dest="$2"; shift 2
first="$1"; shift

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Store and read signatures as sigstore attachments in the registry.
mkdir -p "$work/registries.d"
printf 'docker:\n  %s:\n    use-sigstore-attachments: true\n' "$dest" \
    > "$work/registries.d/dest.yaml"

common=(--registries.d "$work/registries.d" --retry-times 3)
if [[ "${TLS_VERIFY:-true}" == "false" ]]; then
    common+=(--src-tls-verify=false --dest-tls-verify=false)
fi

sign=()
if [[ -n "${SIGNING_KEY:-}" ]]; then
    [[ -n "${SIGNING_PASSWORD:-}" ]] || fail "SIGNING_KEY is set but SIGNING_PASSWORD is empty"
    umask 077
    printf '%s\n' "$SIGNING_KEY" > "$work/key.private"
    printf '%s' "$SIGNING_PASSWORD" > "$work/key.pass"
    sign=(--sign-by-sigstore-private-key "$work/key.private"
          --sign-passphrase-file "$work/key.pass")
    echo "publish: signing $dest:$first" >&2
else
    echo "publish: no SIGNING_KEY, pushing unsigned" >&2
fi

skopeo copy "${common[@]}" "${sign[@]}" --digestfile "$work/digest" \
    "containers-storage:$src" "docker://$dest:$first" >&2
digest="$(cat "$work/digest")"
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "no digest from push"

for tag in "$@"; do
    skopeo copy "${common[@]}" --preserve-digests --remove-signatures \
        "docker://$dest@$digest" "docker://$dest:$tag" >&2
done

echo "publish: $dest@$digest tagged $first $*" >&2
echo "$digest"
