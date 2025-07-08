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

WORKDIR /home/build/aports/scripts
ENTRYPOINT ["sh", "./mkimage.sh"]
