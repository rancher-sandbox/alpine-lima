#!/bin/sh
# Rebuild the linux-virt kernel with the patches in kernel-patches/.
#
# Stable 6.18.57 backported "ACPI: button: Convert the driver to a platform
# one" without its prerequisite, mainline ab06eb920401 "ACPI: scan: Register
# platform devices for fixed event buttons". On x86_64 the VM's power button
# is an ACPI fixed event button. Without ab06eb920401 it does not get a
# platform device, so the button driver never binds. Then acpid never sees
# the press that `limactl stop` sends, and Lima kills the VM once its stop
# timeout runs out.
#
# aarch64 describes its power button as an ACPI namespace device, which still
# gets a platform device, so it keeps Alpine's prebuilt kernel. Drop the
# patches and this rebuild once Alpine's linux-lts includes ab06eb920401.
set -eu

ARCH="$(apk --print-arch)"
KDIR=/home/build/aports/main/linux-lts
REPO=/home/build/packages/lima
export REPODEST=/home/build/kernel-packages
# Build only the virt flavor (skips linux-lts). Exported so checksum and build
# see the same source list.
export FLAVOR=virt

cd "$KDIR"

pkgver="$(awk -F= '/^pkgver=/{print $2; exit}' APKBUILD)"
pkgrel="$(awk -F= '/^pkgrel=/{print $2; exit}' APKBUILD)"

# apk installs the newest linux-virt from any repo, so once Alpine ships a
# newer version, the ISO gets that unpatched kernel instead of this rebuild.
# A release bump alone (e.g. -r1) would still lose to the pkgrel bump below,
# but it means this recipe is out of date. So fail unless Alpine ships exactly
# the version and release in this APKBUILD.
alpine="$(apk search --exact linux-virt)"
if [ "$alpine" != "linux-virt-${pkgver}-r${pkgrel}" ]; then
	echo "Alpine ships ${alpine:-no linux-virt}, not linux-virt-${pkgver}-r${pkgrel}; update LINUX_LTS_COMMIT in the Makefile" >&2
	exit 1
fi

# Append the patches to $source, after Alpine's own; default_prepare applies
# every *.patch in $source, in order.
patches=""
for patch in /home/build/kernel-patches/*.patch; do
	cp "$patch" .
	patches="$patches ${patch##*/}"
done
echo "source=\"\$source$patches\"" >> APKBUILD

# FLAVOR=virt adds virt.${ARCH}.config to $source a second time, and abuild
# rejects the duplicate, so delete the APKBUILD's own entry.
sed -i "/^[[:space:]]*virt\.${ARCH}\.config\$/d" APKBUILD

# Bump pkgrel so apk prefers this build over Alpine's linux-virt of the same
# version without relying on build.sh listing the local repo first. The
# kernel release includes pkgrel, so `uname -r` shows it (e.g. 6.18.58-100-virt).
sed -i "s/^pkgrel=.*/pkgrel=$((pkgrel + 100))/" APKBUILD

# The Docker build runs as root, so abuild needs -F. -r installs the kernel's
# makedepends.
abuild -F checksum
abuild -F -r

# Publish into the local repo and re-index it (alongside the openresty/mkcert
# packages already there).
mkdir -p "${REPO}/${ARCH}"
find "${REPODEST}" -name 'linux-virt-*.apk' -exec cp {} "${REPO}/${ARCH}/" \;
cd "${REPO}/${ARCH}"
apk index -o APKINDEX.tar.gz ./*.apk
abuild-sign APKINDEX.tar.gz
