profile_lima() {
	profile_standard
	profile_abbrev="lima"
	title="Linux Virtual Machines"
	desc="Similar to standard.
		Slimmed down kernel.
		Optimized for virtual systems.
		Configured for lima."
	arch="aarch64 x86 x86_64"
	initfs_cmdline="modules=loop,squashfs,sd-mod,usb-storage"
	kernel_addons=
	kernel_flavors="virt"
	kernel_cmdline="console=hvc0 console=tty0 console=ttyS0,115200"
	syslinux_serial="0 115200"
	apkovl="genapkovl-lima.sh"
	apks="$apks iproute2 openssh-server-pam tiny-cloud-nocloud"
        if [ "${LIMA_INSTALL_CA_CERTIFICATES}" == "true" ]; then
            apks="$apks ca-certificates"
        fi
        if [ "${LIMA_INSTALL_CLOUD_INIT}" == "true" ]; then
            apks="$apks cloud-init"
        fi
        if [ "${LIMA_INSTALL_CLOUD_UTILS_GROWPART}" == "true" ]; then
            apks="$apks cloud-utils-growpart partx"
        fi
        if [ "${LIMA_INSTALL_CNI_PLUGINS}" == "true" ] || [ "${LIMA_INSTALL_NERDCTL_FULL}" == "true" ]; then
            apks="$apks cni-plugins"
        fi
        if [ "${LIMA_INSTALL_CNI_PLUGIN_FLANNEL}" == "true" ]; then
            apks="$apks cni-plugin-flannel"
        fi
        if [ "${LIMA_INSTALL_CTR}" == "true" ]; then
            apks="$apks containerd-ctr"
        fi
        if [ "${LIMA_INSTALL_CURL}" == "true" ]; then
            apks="$apks curl"
        fi
        if [ "${LIMA_INSTALL_DOCKER}" == "true" ]; then
            apks="$apks libseccomp runc containerd tini-static device-mapper-libs"
            apks="$apks docker-engine docker-openrc docker-cli docker"
            apks="$apks socat xz"
        fi
        if [ "${LIMA_INSTALL_E2FSPROGS_EXTRA}" == "true" ]; then
            apks="$apks e2fsprogs-extra"
        fi
        if [ "${LIMA_INSTALL_GIT}" == "true" ]; then
            apks="$apks git"
        fi
        if [ "${LIMA_INSTALL_GNUTAR}" == "true" ]; then
            apks="$apks tar"
        fi
        if [ "${LIMA_INSTALL_IPTABLES}" == "true" ] || [ "${LIMA_INSTALL_NERDCTL_FULL}" == "true" ]; then
            apks="$apks iptables ip6tables"
        fi
        if [ "${LIMA_INSTALL_K3S}" == "true" ]; then
            apks="$apks k3s"
        fi
        if [ "${LIMA_INSTALL_LIMA_INIT}" == "true" ]; then
            apks="$apks e2fsprogs lsblk sfdisk shadow sudo udev"
        fi
        if [ "${LIMA_INSTALL_LOGROTATE}" == "true" ]; then
            apks="$apks logrotate"
        fi
        if [ "${LIMA_INSTALL_MKCERT}" == "true" ]; then
            apks="$apks mkcert"
        fi
        if [ "${LIMA_INSTALL_OPENRESTY}" == "true" ]; then
            apks="$apks rd-openresty"
        fi
        if [ "${LIMA_INSTALL_OPENSSH_SFTP_SERVER=true}" == "true" ]; then
            apks="$apks openssh-sftp-server"
        fi
        if [ "${LIMA_INSTALL_SSHFS}" == "true" ]; then
            apks="$apks sshfs"
        fi
        if [ "${LIMA_INSTALL_TINI}" == "true" ]; then
            apks="$apks tini-static"
        fi
        if [ "${LIMA_INSTALL_TZDATA}" == "true" ]; then
            apks="$apks tzdata"
        fi
        if [ "${LIMA_INSTALL_ZSTD}" == "true" ]; then
            apks="$apks zstd"
        fi
}

# Override build_kernel to use the Alpine 3.20 kernel (6.6) because 6.12 has
# issues with older Java, https://bugs.openjdk.org/browse/JDK-8348566
build_kernel() {
	local _flavor="$2" _modloopsign= _add
	shift 3
	local _pkgs="$*"
	_pkgs=${_pkgs//linux-virt/linux-virt<6.12}
	[ "$modloop_sign" = "yes" ] && _modloopsign="--modloopsign"
	echo http://dl-cdn.alpinelinux.org/alpine/v3.20/main > /tmp/repositories.320
	update-kernel \
		$_hostkeys \
		${_abuild_pubkey:+--apk-pubkey $_abuild_pubkey} \
		$_modloopsign \
		--verbose \
		--media \
		--keys-dir "$APKROOT/etc/apk/keys" \
		--flavor "$_flavor" \
		--arch "$ARCH" \
		--package "$_pkgs" \
		--feature "$initfs_features" \
		--modloopfw "$modloopfw" \
		--repositories-file /tmp/repositories.320 \
		"$DESTDIR" \
		|| return 1
	for _add in $boot_addons; do
		apk fetch --root "$APKROOT" --quiet --stdout $_add | tar -C "${DESTDIR}" -zx boot/
	done
}
