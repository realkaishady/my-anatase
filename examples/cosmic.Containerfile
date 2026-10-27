FROM i.anatase.org/base:stable

# Fedora 45 COSMIC desktop packages, slimmed down
# https://forge.fedoraproject.org/releng/fedora-comps/src/branch/main/comps-f45.xml.in
RUN dnf -y --setopt=install_weak_deps=False install \
    cosmic-session \
    cosmic-greeter \
    cosmic-initial-setup \
    cosmic-files \
    cosmic-store \
    cosmic-term \
    cosmic-player \
    oo7-daemon \
    oo7-portal \
    pam_oo7 \
    xdg-desktop-portal-gtk \
    && dnf clean all

# Provide a graphical login with COSMIC's greeter.
RUN systemctl enable cosmic-greeter.service && \
    systemctl set-default graphical.target

# Cleanup (leave this here)
RUN rm -rf /var && \
    mkdir -p /var/tmp
