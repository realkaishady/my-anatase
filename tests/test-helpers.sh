#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables are read inside check's eval strings
# Tests for the host helpers in this image (fstab condition, boot-state record and notice,
# anatase-snap). Throwaway folders and fake commands only; never touches /etc, /run or a Space.
# Run anywhere except the Legion Go:  bash tests/test-helpers.sh
set -u
if [ -e /run/ostree-booted ] || [ -d /var/lib/spaces ]; then
  echo "Refusing to run on an Anatase host." >&2; exit 2
fi
R="$(cd "$(dirname -- "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; else FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; fi; }

echo "== fstab-root-needs-ro =="
C="${R}/libexec/fstab-root-needs-ro"
cat > "$T/f1" <<'EOF'
# Created by anaconda on Mon Oct 27 2026
UUID=abc /                       btrfs   subvol=root,compress=zstd:1,ro,x-systemd.device-timeout=0 0 0
UUID=def /boot                   ext4    defaults        1 2
EOF
cat > "$T/f2" <<'EOF'
# Created by anaconda
UUID=abc /                       btrfs   subvol=root,compress=zstd:1 0 0
EOF
cat > "$T/f3" <<'EOF'
# Created by anaconda
# UUID=old / btrfs ro 0 0
UUID=abc /                       btrfs   subvol=root,rootflags=ro2 0 0
EOF
printf '# only comments\n' > "$T/f4"
sh "$C" "$T/f1"; check "/ has ro mid-list: skip (exit 1)" '[ $? -eq 1 ]'
sh "$C" "$T/f2"; check "/ without ro: run (exit 0)" '[ $? -eq 0 ]'
sh "$C" "$T/f3"; check "ro only in a comment / as a substring: run (exit 0)" '[ $? -eq 0 ]'
sh "$C" "$T/f4"; check "no / entry: run (exit 0)" '[ $? -eq 0 ]'
sh "$C" "$T/missing"; check "unreadable fstab: run (exit 0)" '[ $? -eq 0 ]'

echo "== bootstate-write / bootstate-notify =="
W="${R}/libexec/bootstate-write"; N="${R}/libexec/bootstate-notify"
mk_status() {  # $1 booted ts, $2 rollback ts, $3 rollbackQueued, $4 staged ("" for none)
  local staged="null"
  [ -n "$4" ] && staged='{"image":{"image":{"image":"ghcr.io/x/my-anatase:stable"},"imageDigest":"sha256:2ccfc861732c6ec1","timestamp":"'"$4"'"}}'
  cat > "$T/status.json" <<EOF
{"status":{"staged":${staged},
 "booted":{"image":{"image":{"image":"ghcr.io/x/my-anatase:stable"},"imageDigest":"sha256:42f3a570af3e16b5d6ce","timestamp":"$1"}},
 "rollback":{"image":{"image":{"image":"ghcr.io/x/my-anatase:stable"},"imageDigest":"sha256:54e78bf26f80d49d462d","timestamp":"$2"}},
 "rollbackQueued":$3}}
EOF
}
export BOOTSTATE_DIR="$T/run" BOOTC_STATUS_CMD="cat $T/status.json" BOOTSTATE_FILE="$T/run/bootstate"
mk_status 2026-10-27T07:37:30Z 2026-10-27T07:53:35Z false 2026-10-27T22:59:50Z
bash "$W"
check "older booted than rollback -> reverted" 'grep -qx "state=reverted" "$T/run/bootstate"'
check "record names booted and rollback digests" 'grep -qx "booted=42f3a570af3e" "$T/run/bootstate" && grep -qx "rollback=54e78bf26f80" "$T/run/bootstate"'
check "record is world-readable" '[ "$(stat -c %a "$T/run/bootstate")" = 644 ]'
mk_status 2026-10-27T07:53:35Z 2026-10-27T07:37:30Z false ""
bash "$W"; check "newer booted -> ok" 'grep -qx "state=ok" "$T/run/bootstate"'
check "no staged image -> empty staged" 'grep -qx "staged=" "$T/run/bootstate"'
mk_status 2026-10-27T07:53:35Z 2026-10-27T07:37:30Z true ""
bash "$W"; check "rollbackQueued -> queued" 'grep -qx "state=queued" "$T/run/bootstate"'
BOOTC_STATUS_CMD="false" bash "$W"; check "bootc failure leaves the last record alone" 'grep -qx "state=queued" "$T/run/bootstate"'

mkdir -p "$T/fb"
cat > "$T/fb/busctl" <<EOF
#!/bin/sh
printf '%s\n' "\$@" > "$T/busctl.args"
EOF
chmod +x "$T/fb/busctl"
mk_status 2026-10-27T07:37:30Z 2026-10-27T07:53:35Z false ""; bash "$W"
PATH="$T/fb:$PATH" bash "$N"
check "reverted -> desktop notice sent" 'grep -qx "Running the previous OS version" "$T/busctl.args"'
check "notice is a valid Notify call" 'grep -qx "susssasa{sv}i" "$T/busctl.args"'
rm -f "$T/busctl.args"; mk_status 2026-10-27T07:53:35Z 2026-10-27T07:37:30Z false ""; bash "$W"
PATH="$T/fb:$PATH" bash "$N"; check "ok -> no notice" '[ ! -e "$T/busctl.args" ]'
unset BOOTSTATE_DIR BOOTC_STATUS_CMD BOOTSTATE_FILE

echo "== anatase-snap =="
S="${R}/bin/anatase-snap"
mkdir -p "$T/spaces/ubuntu/rootfs/etc" "$T/spaces/fedora/rootfs" "$T/snaps" "$T/home/Projects/_ANATASE_OPS/state" "$T/sb"
echo hi > "$T/spaces/ubuntu/rootfs/etc/x"
printf 'ID=anatase\n' > "$T/os-host"; printf 'ID=ubuntu\n' > "$T/os-space"
cat > "$T/sb/systemctl" <<EOF
#!/bin/sh
echo "\$*" >> "$T/systemctl.log"
case "\$*" in
  *is-active*) [ -e "$T/running" ] && exit 0; exit 3 ;;
  *stop*) [ -e "$T/stuck" ] || rm -f "$T/running" ;;
  *start*) touch "$T/running" ;;
esac
exit 0
EOF
printf '#!/bin/sh\nexit 1\n' > "$T/sb/btrfs"
chmod +x "$T/sb/"*
snap() { env PATH="$T/sb:$PATH" ANATASE_OS_RELEASE="$T/os-host" ANATASE_CONTAINER=0 ANATASE_SNAP_NO_SUDO=1 \
  SPACES_ROOT="$T/spaces" SNAP_ROOT="$T/snaps" ANATASE_USER=nobody ANATASE_OPS_DIR="$T/home/Projects/_ANATASE_OPS" \
  bash "$S" "$@"; }
st="$T/home/Projects/_ANATASE_OPS/state"

env ANATASE_OS_RELEASE="$T/os-space" ANATASE_CONTAINER=0 bash "$S" list >/dev/null 2>&1
check "refuses in a Space (ID=ubuntu)" '[ $? -ne 0 ]'
env ANATASE_OS_RELEASE="$T/os-host" ANATASE_CONTAINER=1 bash "$S" list >/dev/null 2>&1
check "refuses inside a container even with ID=anatase" '[ $? -ne 0 ]'
touch "$T/running"
snap create ubuntu >/dev/null 2>&1; check "running Space without --stop: refused" '[ $? -ne 0 ] && [ -z "$(ls -A "$T/snaps")" ]'
touch "$T/stuck"
snap create ubuntu --stop >/dev/null 2>&1; check "Space still active after stop: refused, nothing made" '[ $? -ne 0 ] && [ -z "$(ls -A "$T/snaps")" ]'
rm -f "$T/stuck"
out="$(snap create ubuntu --stop 2>&1)"; check "create --stop: PASS" 'echo "$out" | grep -q "^PASS: snapshot ubuntu-snap-"'
check "Space started again afterwards" '[ -e "$T/running" ]'
U1="$(sed -n 's/^name=//p' "$st/last-space-snapshot.ubuntu")"
check "per-Space record written" '[ "$(sed -n s/^result=//p "$st/last-space-snapshot.ubuntu")" = PASS ] && [ -d "$T/snaps/$U1" ]'
sleep 1
rm -f "$T/running"; snap create fedora >/dev/null 2>&1
check "a fedora snapshot doesn't overwrite the ubuntu record" '[ "$(sed -n s/^name=//p "$st/last-space-snapshot.ubuntu")" = "$U1" ] && grep -q "^space=fedora" "$st/last-space-snapshot.fedora"'
snap delete "$U1" --yes >/dev/null 2>&1
check "delete marks the record DELETED" '[ "$(sed -n s/^result=//p "$st/last-space-snapshot.ubuntu")" = DELETED ] && [ ! -e "$T/snaps/$U1" ]'
mkdir -p "$T/snaps/ubuntu-snap-20260101_000000-CHECK"
snap restore ubuntu-snap-20260101_000000-CHECK ubuntu --yes >/dev/null 2>&1
check "restore refuses a -CHECK copy" '[ $? -ne 0 ] && [ -e "$T/spaces/ubuntu/rootfs/etc/x" ]'
sleep 1; rm -f "$T/running"; snap create ubuntu >/dev/null 2>&1; U2="$(sed -n 's/^name=//p' "$st/last-space-snapshot.ubuntu")"
echo changed > "$T/spaces/ubuntu/rootfs/etc/x"
snap restore "$U2" ubuntu --yes >/dev/null 2>&1
check "restore brings the snapshot back" '[ "$(cat "$T/spaces/ubuntu/rootfs/etc/x")" = hi ]'
check "restore keeps the previous Space" 'ls "$T/snaps" | grep -q "^ubuntu-before-restore-"'

printf '\nRESULT: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
