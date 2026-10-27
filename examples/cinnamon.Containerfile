FROM i.anatase.org/base:stable

# Fedora 45 Cinnamon desktop packages, slimmed down
# https://forge.fedoraproject.org/releng/fedora-comps/src/branch/main/comps-f45.xml.in
RUN dnf -y --setopt=install_weak_deps=False install \
    cinnamon \
    cinnamon-control-center \
    cinnamon-session \
    cinnamon-settings-daemon \
    cinnamon-screensaver \
    lightdm \
    slick-greeter \
    slick-greeter-cinnamon \
    nemo \
    nemo-image-converter \
    nemo-preview \
    gnome-terminal \
    blueman \
    oo7-daemon \
    oo7-portal \
    pam_oo7 \
    gvfs-afc \
    gvfs-fuse \
    gvfs-gphoto2 \
    gvfs-mtp \
    gvfs-smb \
    nm-connection-editor \
    nm-connection-editor-desktop \
    NetworkManager-libreswan-gnome \
    NetworkManager-openconnect-gnome \
    NetworkManager-openvpn-gnome \
    NetworkManager-ppp \
    NetworkManager-ssh-gnome \
    xdg-desktop-portal-gtk \
    xdg-user-dirs-gtk \
    ffmpegthumbnailer \
    glycin-thumbnailer \
    gnome-disk-utility \
    gnome-software \
    gnome-system-monitor \
    && dnf clean all

# Recreate LightDM's state directories at boot after the /var cleanup.
RUN printf '%s\n' \
    'd /var/cache/lightdm 0755 lightdm lightdm -' \
    'd /var/lib/lightdm 0755 lightdm lightdm -' \
    'd /var/lib/lightdm-data 0755 lightdm lightdm -' \
    > /usr/lib/tmpfiles.d/anatase-lightdm.conf

# Provide a graphical login with Cinnamon's Slick Greeter
RUN mkdir -p /etc/lightdm/lightdm.conf.d && \
    printf '[Seat:*]\ngreeter-session=slick-greeter\nuser-session=cinnamon\n' > /etc/lightdm/lightdm.conf.d/90-cinnamon.conf && \
    systemctl enable lightdm.service && \
    systemctl set-default graphical.target

# Cleanup (leave this here)
RUN rm -rf /var && \
    mkdir -p /var/tmp
