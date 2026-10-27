#!/usr/bin/env bash
set -euo pipefail

if [[ -f /run/.containerenv ]] || grep -q '^ID=ubuntu' /etc/os-release 2>/dev/null; then
  echo "ERROR: Do not run ./update.sh inside a Space. Open a Layer 1 Host (❯) terminal instead." >&2
  exit 1
fi

if (( UID != 0 )); then
    exec sudo -- "$0" "$@"
fi

cd "$(dirname "$0")"

image="localhost/my-anatase:latest"

podman build --network=host --pull=always --file Containerfile --tag "$image" .
bootc switch --transport containers-storage "$image"
bootc update

echo ""
echo "NOTE: Host is now tracking local storage ($image)."
echo "When finished testing, return to your signed CI stream with:"
echo "  sudo bootc switch ghcr.io/realkaishady/my-anatase:stable"
