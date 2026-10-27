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

# 4. Cleanup (mandatory before bootc container lint)
RUN rm -rf /var /run/dnf && \
    mkdir -p /var/tmp

# 5. Validate bootc container image structure
RUN bootc container lint
