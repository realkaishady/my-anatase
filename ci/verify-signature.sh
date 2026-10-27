#!/usr/bin/env bash
# Check the sigstore (cosign-format) signature attached to a container image,
# the same way containers/image does on an Anatase host, without downloading
# the image layers. Needs only curl, jq, openssl and base64.
#
# Two modes, matching the two kinds of rule in /etc/containers/policy.json:
#
#   --ca <root.pem> <hostname>   certificate-based ("pki"), used by Anatase
#                                for i.anatase.org images
#   --key <public.pub>           key-based ("keyPath"), used for my-anatase
#
# Checks: the tag resolves to <arch>'s manifest; a signature is attached to
# that digest; (ca mode) its certificate chains to the root, is for code
# signing and names <hostname>; the signature over the payload is valid; the
# payload names this exact digest and repository.
#
# Prints the verified digest on success, exits non-zero otherwise.
#
# Usage:
#   verify-signature.sh <repo> <tag-or-digest> <arch> --ca <root.pem> <hostname>
#   verify-signature.sh <repo> <tag-or-digest> <arch> --key <public.pub>
# Set REGISTRY_TOKEN to send a bearer token (needed for ghcr.io, even public).
set -euo pipefail

fail() { echo "verify-signature: FAIL: $*" >&2; exit 1; }

[[ $# -ge 5 ]] || fail "usage: $0 <repo> <tag-or-digest> <arch> --ca <root.pem> <hostname> | --key <public.pub>"
repo="$1"; ref="$2"; arch="$3"; mode="$4"
case "$mode" in
    --ca)  [[ $# -eq 6 ]] || fail "--ca needs <root.pem> <hostname>"; root_ca="$5"; hostname="$6" ;;
    --key) [[ $# -eq 5 ]] || fail "--key needs <public.pub>"; pubkey="$5" ;;
    *)     fail "unknown mode $mode" ;;
esac

registry="${repo%%/*}"
name="${repo#*/}"
api="${REGISTRY_SCHEME:-https}://${registry}/v2/${name}"
accept='application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json'
auth=()
[[ -n "${REGISTRY_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${REGISTRY_TOKEN}")

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

get() { curl -fsSL "${auth[@]}" -H "Accept: $accept" "$1" -o "$2"; }
sha() { echo "sha256:$(sha256sum "$1" | cut -d' ' -f1)"; }

# 1. Resolve tag -> per-arch manifest digest.
get "$api/manifests/$ref" "$work/top.json" || fail "cannot fetch $repo:$ref"
case "$(jq -r '.mediaType // ""' "$work/top.json")" in
    *index*|*manifest.list*)
        digest="$(jq -r --arg a "$arch" \
            '[.manifests[] | select(.platform.architecture == $a)][0].digest // ""' \
            "$work/top.json")" ;;
    *)
        digest="$(sha "$work/top.json")" ;;
esac
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "no $arch manifest for $repo:$ref"
get "$api/manifests/$digest" "$work/manifest.json" || fail "cannot fetch manifest $digest"
[[ "$(sha "$work/manifest.json")" == "$digest" ]] || fail "manifest hash does not match $digest"

# 2. Signature manifest attached to the digest.
get "$api/manifests/${digest/:/-}.sig" "$work/sig.json" || fail "no signature attached to $repo@$digest"
sel='[.layers[]? | select(.mediaType == "application/vnd.dev.cosign.simplesigning.v1+json")]'
count="$(jq "$sel | length" "$work/sig.json")"
(( count > 0 )) || fail "signature manifest has no cosign layers"

if [[ "$mode" == "--key" ]]; then
    cp "$pubkey" "$work/pub.pem"
fi

ok=0
for i in $(seq 0 $((count - 1))); do
    layer="$(jq -c --argjson i "$i" "${sel}[\$i]" "$work/sig.json")"
    jq -r '.annotations["dev.cosignproject.cosign/signature"] // ""' <<<"$layer" \
        | base64 -d > "$work/sig.bin" 2>/dev/null || continue
    [[ -s "$work/sig.bin" ]] || continue
    blob="$(jq -r '.digest' <<<"$layer")"
    get "$api/blobs/$blob" "$work/payload.json" || continue
    [[ "$(sha "$work/payload.json")" == "$blob" ]] || continue

    # 3. Certificate checks (ca mode only).
    if [[ "$mode" == "--ca" ]]; then
        jq -r '.annotations["dev.cosignproject.cosign/certificate"] // ""' <<<"$layer" > "$work/leaf.pem"
        [[ -s "$work/leaf.pem" ]] || continue
        openssl verify -CAfile "$root_ca" "$work/leaf.pem" >/dev/null 2>&1 || continue
        openssl x509 -in "$work/leaf.pem" -noout -ext extendedKeyUsage 2>/dev/null \
            | grep -q 'Code Signing' || continue
        openssl x509 -in "$work/leaf.pem" -noout -ext subjectAltName 2>/dev/null \
            | grep -Eq "(^|[ ,])DNS:${hostname//./\\.}(,|$)" || continue
        openssl x509 -in "$work/leaf.pem" -noout -pubkey > "$work/pub.pem"
    fi

    # 4. Signature over the payload.
    openssl dgst -sha256 -verify "$work/pub.pem" -signature "$work/sig.bin" \
        "$work/payload.json" >/dev/null 2>&1 || continue

    # 5. Payload names this digest and repository (matchRepository).
    jq -e --arg d "$digest" --arg r "$repo" '
        .critical.type == "cosign container image signature"
        and .critical.image["docker-manifest-digest"] == $d
        and ((.critical.identity["docker-reference"] | sub("[:@][^/]*$"; "")) == $r)
    ' "$work/payload.json" >/dev/null || continue

    ok=1
    break
done

(( ok == 1 )) || fail "no valid signature for $repo@$digest"
echo "verify-signature: OK $repo:$ref ($arch) = $digest" >&2
echo "$digest"
