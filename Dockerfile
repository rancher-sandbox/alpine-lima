ARG ALPINE_VERSION=latest
ARG BINFMT_IMAGE=tonistiigi/binfmt:latest

FROM ${BINFMT_IMAGE} AS binfmt

FROM alpine:${ALPINE_VERSION}

ARG ARCH=x86_64
ARG OPENRESTY_VERSION=0.0.2

RUN apk add alpine-sdk build-base apk-tools alpine-conf busybox \
  fakeroot xorriso squashfs-tools sudo \
  mtools dosfstools grub-efi

# syslinux is missing for aarch64
ARG TARGETARCH
RUN if [ "${TARGETARCH}" = "amd64" ]; then apk add syslinux; fi

COPY --from=binfmt /usr/bin /binfmt

RUN addgroup root abuild
RUN abuild-keygen -i -a -n
RUN apk update

ADD src/aports /home/build/aports

# add custom OpenResty version with http-proxy-connect module compiled in
ADD openresty-v${OPENRESTY_VERSION}-${ARCH}.tar /home/build/packages/lima

# mkcert is only available in the "testing" repo from the "edge" branch
RUN \
  mkdir -p /home/build/packages/lima/${ARCH} && \
  cd /home/build/packages/lima && \
  mv *.pub /etc/apk/keys && \
  cd ${ARCH} && \
  apk fetch mkcert --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing && \
  apk index -o APKINDEX.tar.gz *.apk && \
  abuild-sign APKINDEX.tar.gz

# Remove --no-chown which is deprecated in apk 3.0 as alias for --usermode (disallowed as root)
RUN sed -i 's/--initdb --no-chown/--initdb/' /home/build/aports/scripts/mkimage.sh

# On x86_64, rebuild linux-virt with legacy iptables restored (Alpine dropped it
# there in 3.23 but keeps it on aarch64); needed by containers that ship only the
# legacy iptables binary, e.g. rancher/rancher.
# https://github.com/rancher/rancher/issues/54862
COPY kernel-legacy-iptables.config /home/build/kernel-legacy-iptables.config
COPY build-legacy-iptables-kernel.sh /home/build/build-legacy-iptables-kernel.sh
RUN if [ "${ARCH}" = "x86_64" ]; then sh /home/build/build-legacy-iptables-kernel.sh; fi

# Strip kernel modules that are unused in the VM but expose known CVEs
# (CVE-2026-43284 dirtyfrag esp4/esp6; CVE-2026-43500 dirtyfrag rxrpc;
# CVE-2026-31431 copy.fail algif_aead). update-kernel has no exclude
# flag, so we inject a hook before its `cp -a ... $MODLOOP` line; depmod
# re-runs to keep modules.dep consistent.
RUN cat > /usr/local/lib/strip-exploit-modules.sh <<'EOF'
for mod in esp4 esp6 rxrpc algif_aead; do
    find "$ROOTFS/lib/modules/$KVER/kernel" -name "$mod.ko*" -delete
done
$MOCK depmod -b "$ROOTFS" "$KVER"
EOF
RUN sed -i 's|^cp -a $ROOTFS/lib/modules $MODLOOP$|. /usr/local/lib/strip-exploit-modules.sh\n&|' /usr/sbin/update-kernel
WORKDIR /home/build/aports/scripts
ENTRYPOINT ["sh", "./mkimage.sh"]
