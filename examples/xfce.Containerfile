FROM i.anatase.org/base:stable

# Fedora 45 Xfce desktop packages, slimmed down
# https://forge.fedoraproject.org/releng/fedora-comps/src/branch/main/comps-f45.xml.in
RUN dnf -y --setopt=install_weak_deps=False install \
    xfce4-about \
    xfce4-appfinder \
    xfce4-panel \
    xfce4-power-manager \
    xfce4-session \
    xfce4-settings \
    xfconf \
    xfdesktop \
    xfwm4 \
    lightdm \
    lightdm-gtk \
    Thunar \
    thunar-media-tags-plugin \
    thunar-volman \
    tumbler \
    xfce4-terminal \
    xfce4-screensaver \
    xfce4-screenshooter-plugin \
    xfce4-taskmanager \
    xfce4-pulseaudio-plugin \
    xfce4-notifyd \
    xfce4-panel-profiles \
    blueman \
    oo7-daemon \
    oo7-portal \
    pam_oo7 \
    gvfs \
    gvfs-afc \
    gvfs-fuse \
    gvfs-gphoto2 \
    gvfs-mtp \
    gvfs-smb \
    network-manager-applet \
    nm-connection-editor \
    nm-connection-editor-desktop \
    NetworkManager-libreswan-gnome \
    NetworkManager-openconnect-gnome \
    NetworkManager-openvpn-gnome \
    NetworkManager-ppp \
    NetworkManager-ssh-gnome \
    xdg-desktop-portal-gtk \
    xdg-user-dirs-gtk \
    greybird-dark-theme \
    greybird-light-theme \
    greybird-xfce4-notifyd-theme \
    greybird-xfwm4-theme \
    && dnf clean all

# Recreate LightDM's state directories at boot after the /var cleanup.
RUN printf '%s\n' \
    'd /var/cache/lightdm 0755 lightdm lightdm -' \
    'd /var/lib/lightdm 0755 lightdm lightdm -' \
    'd /var/lib/lightdm-data 0755 lightdm lightdm -' \
    > /usr/lib/tmpfiles.d/anatase-lightdm.conf

# Provide a graphical login with LightDM's GTK greeter
RUN mkdir -p /etc/lightdm/lightdm.conf.d && \
    printf '[Seat:*]\ngreeter-session=lightdm-gtk-greeter\nuser-session=xfce\n' > /etc/lightdm/lightdm.conf.d/90-xfce.conf && \
    systemctl enable lightdm.service && \
    systemctl set-default graphical.target

# Cleanup (leave this here)
RUN rm -rf /var && \
    mkdir -p /var/tmp
