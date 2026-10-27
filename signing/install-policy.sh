#!/usr/bin/env bash
# Runs inside the image build. Makes the OS refuse unsigned updates of this
# image, the same way stock Anatase refuses unsigned i.anatase.org images.
#
# It does nothing until signing/my-anatase.pub has been committed, so the
# image keeps building (unsigned) before signing is set up. See README.md,
# "Signing".
#
# Usage: install-policy.sh <image-ref without tag>, e.g. ghcr.io/user/my-anatase
set -euo pipefail

ref="$1"
here="$(cd "$(dirname -- "$0")" && pwd)"
pub="$here/my-anatase.pub"
policy=/etc/containers/policy.json

if [[ ! -s "$pub" ]]; then
    echo "install-policy: no signing/my-anatase.pub yet, leaving signature policy unchanged"
    exit 0
fi

install -Dm0644 "$pub" /etc/pki/containers/my-anatase.pub

# Require a sigstore signature from our key for this repository only.
# Every other rule (including Anatase's own for i.anatase.org) is kept.
tmp="$(mktemp)"
jq --arg ref "$ref" '
    .transports.docker[$ref] = [{
        "type": "sigstoreSigned",
        "keyPath": "/etc/pki/containers/my-anatase.pub",
        "signedIdentity": {"type": "matchRepository"}
    }]
' "$policy" > "$tmp"
install -m0644 "$tmp" "$policy"
rm -f "$tmp"

# Tell containers/image to look for sigstore signatures attached in the registry.
install -d /etc/containers/registries.d
printf 'docker:\n  %s:\n    use-sigstore-attachments: true\n' "$ref" \
    > /etc/containers/registries.d/my-anatase.yaml

echo "install-policy: signatures now required for $ref"
