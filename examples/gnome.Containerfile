FROM i.anatase.org/base:stable

# Fedora 45 GNOME desktop packages, slimmed down
# https://forge.fedoraproject.org/releng/fedora-comps/src/branch/main/comps-f45.xml.in
RUN dnf -y --setopt=install_weak_deps=False install \
    dconf \
    gdm \
    gnome-control-center \
    gnome-initial-setup \
    gnome-session-wayland-session \
    gnome-settings-daemon \
    gnome-shell \
    gnome-software \
    nautilus \
    ptyxis \
    fprintd-pam \
    gnome-bluetooth \
    oo7-daemon \
    oo7-portal \
    pam_oo7 \
    gnome-user-share \
    gvfs-afc \
    gvfs-fuse \
    gvfs-goa \
    gvfs-gphoto2 \
    gvfs-mtp \
    gvfs-smb \
    localsearch \
    NetworkManager-libreswan-gnome \
    NetworkManager-openconnect-gnome \
    NetworkManager-openvpn-gnome \
    NetworkManager-ppp \
    NetworkManager-ssh-gnome \
    sushi \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    xdg-user-dirs-gtk \
    glycin-thumbnailer \
    gnome-backgrounds \
    gnome-browser-connector \
    gnome-characters \
    gnome-clocks \
    gnome-color-manager \
    gnome-disk-utility \
    gnome-epub-thumbnailer \
    gnome-logs \
    gnome-system-monitor \
    gnome-user-docs \
    gst-thumbnailers \
    && dnf clean all

# Provide a graphical login, including GNOME's setup flow on fresh installs.
RUN systemctl enable gdm.service && \
    systemctl set-default graphical.target

# Cleanup (leave this here).
RUN rm -rf /var && \
    mkdir -p /var/tmp
