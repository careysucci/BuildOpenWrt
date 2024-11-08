#!/bin/bash
#=================================================
shopt -s extglob

sed -i '$a src-git miaogongzi https://github.com/mgz0227/OP-Packages.git;master' feeds.conf.default
sed -i "/telephony/d" feeds.conf.default

sed -i "s?targets/%S/packages?targets/%S/\$(LINUX_VERSION)?" include/feeds.mk

sed -i '/	refresh_config();/d' scripts/feeds

./scripts/feeds update -a
./scripts/feeds install -a -p miaogongzi -f
./scripts/feeds install -a

rm -rf package/base-files
mv -f feeds/miaogongzi/base-files package/
rm -rf package/net/nginx
rm -rf package/net/nginx-util
mv -f feeds/miaogongzi/nginx package/net/
mv -f feeds/miaogongzi/nginx-util package/net/

echo "$(date +"%s")" >version.date
sed -i '/$(curdir)\/compile:/c\$(curdir)/compile: package/opkg/host/compile' package/Makefile
sed -i "s/DEFAULT_PACKAGES:=/DEFAULT_PACKAGES:=luci-app-advancedplus luci-app-firewall luci-app-opkg luci-app-upnp luci-app-syscontrol \
luci-app-wizard luci-base luci-compat luci-lib-ipkg luci-lib-fs \
luci-app-argon-config luci-app-ddns-go luci-app-openclash luci-app-adblock tcpdump-mini luci-app-nlbwmon \
coremark wget-ssl curl autocore htop nano zram-swap kmod-lib-zstd kmod-tcp-bbr bash openssh-sftp-server block-mount resolveip ds-lite swconfig luci-app-fan luci-app-fileassistant /" include/target.mk

sed -i "s/procd-ujail//" include/target.mk
sed -i "s/procd-seccomp//" include/target.mk

sed -i "s/^.*vermagic$/\techo '1' > \$(LINUX_DIR)\/.vermagic/" include/kernel-defaults.mk

status=$(curl -H "Authorization: token $REPO_TOKEN" -s "https://api.github.com/repos/mgz0227/OP-Packages/actions/runs" | jq -r '.workflow_runs[0].status')
echo "$status"
while [[ "$status" == "in_progress" || "$status" == "queued" ]];do
	echo "wait 5s"
	sleep 5
	status=$(curl -H "Authorization: token $REPO_TOKEN" -s "https://api.github.com/repos/mgz0227/OP-Packages/actions/runs" | jq -r '.workflow_runs[0].status')
done

rm -rf package/feeds/packages/v4l2loopback  package/feeds/miaogongzi/accel-ppp package/network/utils/xdp-tools

mv -f feeds/miaogongzi/r81* tmp/

wget -N https://raw.githubusercontent.com/openwrt/packages/master/lang/golang/golang/Makefile -P feeds/packages/lang/golang/golang/

sed -i "s/192.168.1/192.168.3/" package/base-files/files/bin/config_generate

#sed -i "/call Build\/check-size,\$\$(KERNEL_SIZE)/d" include/image.mk

wget -N https://raw.githubusercontent.com/coolsnowwolf/lede/master/package/kernel/linux/modules/video.mk -P package/kernel/linux/modules/

git_clone_path master https://github.com/coolsnowwolf/lede target/linux/generic/hack-6.6
wget -N https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/generic/pending-6.6/613-netfilter_optional_tcp_window_check.patch -P target/linux/generic/pending-6.6/

sed -i "s/CONFIG_WERROR=y/CONFIG_WERROR=n/" target/linux/generic/config-6.6

sed -i "s/no-lto,$/no-lto no-mold,$/" include/package.mk

[ -d package/kernel/mt76 ] && {
wget -N https://raw.githubusercontent.com/immortalwrt/immortalwrt/master/package/kernel/mt76/patches/0001-mt76-allow-VHT-rate-on-2.4GHz.patch -P package/kernel/mt76/patches/
}

grep -q 'PKG_RELEASE:=9' package/libs/openssl/Makefile && {
sh -c "curl -sfL https://github.com/openwrt/openwrt/commit/a48d0bdb77eb93f7fba6e055dace125c72755b6a.patch | patch -d './' -p1 --forward"
}

sed -i "/wireless.\${name}.disabled/d" package/kernel/mac80211/files/lib/wifi/mac80211.sh

sed -i 's/Os/O2/g' include/target.mk
sed -i "/mediaurlbase/d" package/feeds/*/luci-theme*/root/etc/uci-defaults/*
sed -i 's/=bbr/=cubic/' package/kernel/linux/files/sysctl-tcp-bbr.conf

# find target/linux/x86 -name "config*" -exec bash -c 'cat kernel.conf >> "{}"' \;
sed -i 's/max_requests 3/max_requests 20/g' package/network/services/uhttpd/files/uhttpd.config
#rm -rf ./feeds/packages/lang/{golang,node}
sed -i "s/tty\(0\|1\)::askfirst/tty\1::respawn/g" target/linux/*/base-files/etc/inittab

sed -i 's/$$(call concat_cmd,$$(KERNEL_INITRAMFS))/-$$(call concat_cmd,$$(KERNEL_INITRAMFS))/' include/image.mk

date=`date +%m.%d.%Y`
sed -i -e "/\(# \)\?REVISION:=/c\REVISION:=$date" -e '/VERSION_CODE:=/c\VERSION_CODE:=$(REVISION)' include/version.mk

sed -i \
	-e "s/+\(luci\|luci-ssl\|uhttpd\)\( \|$\)/\2/" \
	-e "s/+nginx\( \|$\)/+nginx-ssl\1/" \
	-e 's/+python\( \|$\)/+python3/' \
	-e 's?../../lang?$(TOPDIR)/feeds/packages/lang?' \
	package/feeds/miaogongzi/*/Makefile

sed -i "s/OpenWrt/MeowWrt/g" package/base-files/files/bin/config_generate package/base-files/image-config.in config/Config-images.in Config.in include/u-boot.mk include/version.mk package/network/config/wifi-scripts/files/lib/wifi/mac80211.sh package/kernel/mac80211/files/lib/netifd/wireless/mac80211.sh || true
