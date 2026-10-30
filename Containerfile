FROM i.anatase.org/anatase:stable

# 1. Install host CLI utilities
# (fastfetch, htop and wireguard-tools are already in the base image; listed
# so they stay if upstream ever drops them)
RUN dnf -y install \
    btop \
    fastfetch \
    htop \
    wireguard-tools

# 2. Install audited CachyOS & Lenovo Legion Go (Z1 Extreme) system drop-ins
# Discover's update settings are left at Anatase's defaults: its unattended
# updates are what keep Flatpak apps (Anatase Browser, Steam...) up to date.
COPY cachyos/systemd/zram-generator.conf /etc/systemd/zram-generator.conf
COPY cachyos/sysctl.d/ /etc/sysctl.d/
COPY cachyos/udev/ /etc/udev/rules.d/
COPY --chmod=0755 cachyos/udev-helpers/audio-pm-ctl /usr/lib/udev/audio-pm-ctl
COPY cachyos/tmpfiles.d/ /etc/tmpfiles.d/
COPY cachyos/modprobe.d/ /etc/modprobe.d/

# 3. Install the Day-2 verification script
# Goes in /usr/bin, not /usr/local/bin: on bootc images /usr/local points
# into /var, which the cleanup step below deletes, so anything copied there
# never reaches the published image.
# Space-only helpers live in space/ and are not part of this image (a Space
# has its own /usr and /etc and can't see the host's).
COPY --chmod=0755 bin/my-anatase-verify /usr/bin/my-anatase-verify

# 3b. Host-only, root-run helpers (read-only here, so nothing in a Space can change them)
# anatase-snap: Space snapshots (the workbench's copy in Projects is only a fallback).
COPY --chmod=0755 bin/anatase-snap /usr/bin/anatase-snap

# 3c. Boot state: skip bootc's fstab rewrite loop (bootc-dev/bootc#2592) in the image, so it
# no longer depends on a marker line in one deployment's /etc; record which deployment is
# booted and show a desktop notice when it's the older one (e.g. after hhd's Revert).
COPY --chmod=0755 libexec/ /usr/libexec/my-anatase/
COPY systemd/system/ /usr/lib/systemd/system/
COPY systemd/user/ /usr/lib/systemd/user/
RUN systemctl enable my-anatase-bootstate.service && \
    systemctl --global enable my-anatase-bootnotice.service my-anatase-bootnotice.path

# 4. Cleanup (mandatory before bootc container lint)
RUN rm -rf /var /run/dnf && \
    mkdir -p /var/tmp

# 5. Validate bootc container image structure
RUN bootc container lint
