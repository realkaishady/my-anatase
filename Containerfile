FROM i.anatase.org/anatase:stable

# Where this image is published. The GitHub workflow passes the real value.
ARG IMAGE_REF=ghcr.io/realkaishady/my-anatase

# Do your thing...
# Install btop
RUN dnf -y install btop

# Install coolercontrol
# # For COPRs specify fedora-* as dnf will try to look for an anatase COPR
# RUN . /etc/os-release && \
#     dnf -y copr enable codifryed/CoolerControl "fedora-${VERSION_ID}-$(arch)" && \
#     dnf -y install coolercontrol && \
#     systemctl enable coolercontrold

# Require signed updates of this image (no-op until signing/my-anatase.pub exists)
COPY signing/ /tmp/signing/
RUN bash /tmp/signing/install-policy.sh "$IMAGE_REF" && \
    rm -rf /tmp/signing

# Cleanup (leave this here)
RUN rm -rf /var /run/dnf && \
    mkdir -p /var/tmp

# Check the result is a valid bootc image (leave this last)
RUN bootc container lint
