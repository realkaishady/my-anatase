FROM i.anatase.org/anatase:stable

# 1. Install host CLI utilities
RUN dnf -y install \
    btop \
    fastfetch \
    htop \
    wireguard-tools

# 2. Install audited CachyOS & Lenovo Legion Go (Z1 Extreme) system drop-ins
COPY cachyos/systemd/zram-generator.conf /etc/systemd/zram-generator.conf
COPY cachyos/sysctl.d/ /etc/sysctl.d/
COPY cachyos/sysctl.d/ /usr/lib/sysctl.d/
COPY cachyos/udev/ /etc/udev/rules.d/
COPY cachyos/tmpfiles.d/ /etc/tmpfiles.d/
COPY cachyos/tmpfiles.d/ /usr/lib/tmpfiles.d/
COPY cachyos/modprobe.d/ /etc/modprobe.d/
COPY cachyos/NetworkManager/conf.d/ /etc/NetworkManager/conf.d/
COPY cachyos/profile.d/ /etc/profile.d/
COPY cachyos/xdg/ /etc/xdg/

# 3. Install Day-2 verification & C5/C7 Space helper scripts
COPY bin/ /usr/local/bin/
RUN chmod 0755 /usr/local/bin/my-anatase-verify \
               /usr/local/bin/anatase-snap \
               /usr/local/bin/anatase-space-bootstrap

# 4. Cleanup (mandatory before bootc container lint)
RUN rm -rf /var /run/dnf && \
    mkdir -p /var/tmp

# 5. Validate bootc container image structure
RUN bootc container lint
