FROM i.anatase.org/anatase:stable

# Do your thing...
# Install btop
# RUN dnf -y install btop

# Install coolercontrol
# # For COPRs specify fedora-* as dnf will try to look for an anatase COPR
# RUN . /etc/os-release && \
#     dnf -y copr enable codifryed/CoolerControl "fedora-${VERSION_ID}-$(arch)" && \
#     dnf -y install coolercontrol && \
#     systemctl enable coolercontrold

# Cleanup (leave this here)
RUN rm -rf /var && \
    mkdir -p /var/tmp
