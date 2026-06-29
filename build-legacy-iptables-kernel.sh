#!/bin/sh
# Rebuild the linux-virt kernel with legacy iptables (xtables) restored.
#
# Alpine dropped CONFIG_NETFILTER_XTABLES_LEGACY (and the legacy iptables nat
# tables/targets) from the x86_64 linux-virt kernel in 3.23, while keeping it on
# aarch64. The option is built into the kernel image, not available as a loadable
# module, so the kernel must be rebuilt. Without it, a container that ships only
# the legacy iptables binary (notably rancher/rancher, whose embedded
# k3s/kube-proxy uses the legacy backend) cannot create its iptables `nat` table
# and crashes. See https://github.com/rancher/rancher/issues/54862
#
# Only x86_64 needs this; aarch64 keeps Alpine's prebuilt kernel. The rebuilt
# linux-virt is published into the local package repo that build.sh lists first,
# so mkimage installs it instead of Alpine's.
set -eu

ARCH="$(apk --print-arch)"
KDIR=/home/build/aports/main/linux-lts
REPO=/home/build/packages/lima
export REPODEST=/home/build/kernel-packages
# Build only the virt flavor (skips linux-lts). Exported so checksum and build
# see the same source list.
export FLAVOR=virt

cd "$KDIR"

# Append the legacy options to the virt config for this arch.
cat /home/build/kernel-legacy-iptables.config >> "virt.${ARCH}.config"

# FLAVOR=virt re-adds virt.${ARCH}.config to $source, which the APKBUILD already
# lists; abuild rejects the duplicate. Drop the original entry so the one FLAVOR
# adds is the only copy.
sed -i "/^[[:space:]]*virt\.${ARCH}\.config\$/d" APKBUILD

# Outrank Alpine's prebuilt linux-virt of the same version. The local repo is
# already listed first in build.sh, but bump pkgrel so the choice is unambiguous.
# pkgrel does not affect the kernel's vermagic, so out-of-tree modules still match.
pkgrel="$(awk -F= '/^pkgrel=/{print $2; exit}' APKBUILD)"
sed -i "s/^pkgrel=.*/pkgrel=$((pkgrel + 100))/" APKBUILD

# The Docker build runs as root, so abuild needs -F. abuild auto-installs the
# kernel makedepends.
abuild -F checksum
abuild -F -r

# Publish into the local repo and re-index it (alongside the openresty/mkcert
# packages already there).
mkdir -p "${REPO}/${ARCH}"
find "${REPODEST}" /root/packages -name 'linux-virt-*.apk' -exec cp {} "${REPO}/${ARCH}/" \;
cd "${REPO}/${ARCH}"
apk index -o APKINDEX.tar.gz ./*.apk
abuild-sign APKINDEX.tar.gz
