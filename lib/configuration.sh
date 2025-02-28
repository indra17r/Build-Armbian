# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# This file is a part of the Armbian build script
# https://github.com/armbian/build/

# common options
# daily beta build contains date in subrevision
if [[ $BETA == yes && -z $SUBREVISION ]]; then SUBREVISION="."$(date --date="tomorrow" +"%y%m%d"); fi
REVISION="5.44$SUBREVISION" # all boards have same revision
ROOTPWD="1234" # Must be changed @first login
MAINTAINER="Oleg Ivanov" # deb signature
MAINTAINERMAIL="balbes-150@yandex.ru" # deb signature
TZDATA=`cat /etc/timezone` # Timezone for target is taken from host or defined here.
USEALLCORES=yes # Use all CPU cores for compiling
EXIT_PATCHING_ERROR="" # exit patching if failed
HOST="$(echo "$BOARD" | cut -f1 -d-)" # set hostname to the board
ROOTFSCACHE_VERSION=3
CHROOT_CACHE_VERSION=6
[[ -z $DISPLAY_MANAGER ]] && DISPLAY_MANAGER=nodm
ROOTFS_CACHE_MAX=16 # max number of rootfs cache, older ones will be cleaned up

[[ -z $ROOTFS_TYPE ]] && ROOTFS_TYPE=ext4 # default rootfs type is ext4
[[ "ext4 f2fs btrfs nfs fel" != *$ROOTFS_TYPE* ]] && exit_with_error "Unknown rootfs type" "$ROOTFS_TYPE"

# Fixed image size is in 1M dd blocks (MiB)
# to get size of block device /dev/sdX execute as root:
# echo $(( $(blockdev --getsize64 /dev/sdX) / 1024 / 1024 ))
[[ "f2fs" == *$ROOTFS_TYPE* && -z $FIXED_IMAGE_SIZE ]] && exit_with_error "Please define FIXED_IMAGE_SIZE"

# small SD card with kernel, boot script and .dtb/.bin files
[[ $ROOTFS_TYPE == nfs ]] && FIXED_IMAGE_SIZE=64

# used by multiple sources - reduce code duplication
if [[ $USE_MAINLINE_GOOGLE_MIRROR == yes ]]; then
	MAINLINE_KERNEL_SOURCE='https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable'
else
	MAINLINE_KERNEL_SOURCE='git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git'
fi
MAINLINE_KERNEL_DIR='linux-mainline'

if [[ $USE_GITHUB_UBOOT_MIRROR == yes ]]; then
	MAINLINE_UBOOT_SOURCE='https://github.com/RobertCNelson/u-boot'
else
	MAINLINE_UBOOT_SOURCE='git://git.denx.de/u-boot.git'
fi
MAINLINE_UBOOT_DIR='u-boot'

# Let's set default data if not defined in board configuration above
[[ -z $OFFSET ]] && OFFSET=4 # offset to 1st partition (we use 4MiB boundaries by default)
ARCH=armhf
KERNEL_IMAGE_TYPE=zImage
SERIALCON=ttyS0
CAN_BUILD_STRETCH=yes
SRC_LOADADDR=""

# single ext4 partition is the default and preferred configuration
#BOOTFS_TYPE=''

# set unique mounting directory
SDCARD="$SRC/.tmp/rootfs-${BRANCH}-${BOARD}-${RELEASE}-${BUILD_DESKTOP}"
MOUNT="$SRC/.tmp/mount-${BRANCH}-${BOARD}-${RELEASE}-${BUILD_DESKTOP}"
DESTIMG="$SRC/.tmp/image-${BRANCH}-${BOARD}-${RELEASE}-${BUILD_DESKTOP}"

[[ ! -f $SRC/config/sources/$LINUXFAMILY.conf ]] && \
	exit_with_error "Sources configuration not found" "$LINUXFAMILY"

source $SRC/config/sources/$LINUXFAMILY.conf

if [[ -f $SRC/userpatches/sources/$LINUXFAMILY.conf ]]; then
	display_alert "Adding user provided $LINUXFAMILY overrides"
	source $SRC/userpatches/sources/$LINUXFAMILY.conf
fi

[[ $RELEASE == stretch && $CAN_BUILD_STRETCH != yes ]] && exit_with_error "Building Debian Stretch images with selected kernel is not supported"
[[ $RELEASE == bionic && $CAN_BUILD_STRETCH != yes ]] && exit_with_error "Building Ubuntu Bionic images with selected kernel is not supported"

[[ -n $ATFSOURCE && -z $ATF_USE_GCC ]] && exit_with_error "Error in configuration: ATF_USE_GCC is unset"
[[ -z $UBOOT_USE_GCC ]] && exit_with_error "Error in configuration: UBOOT_USE_GCC is unset"
[[ -z $KERNEL_USE_GCC ]] && exit_with_error "Error in configuration: KERNEL_USE_GCC is unset"

case $ARCH in
	arm64)
	[[ -z $KERNEL_COMPILER ]] && KERNEL_COMPILER="aarch64-linux-gnu-"
	[[ -z $UBOOT_COMPILER ]] && UBOOT_COMPILER="aarch64-linux-gnu-"
	ATF_COMPILER="aarch64-linux-gnu-"
	[[ -z $INITRD_ARCH ]] && INITRD_ARCH=arm64
	QEMU_BINARY="qemu-aarch64-static"
	ARCHITECTURE=arm64
	;;

	armhf)
	[[ -z $KERNEL_COMPILER ]] && KERNEL_COMPILER="arm-linux-gnueabihf-"
	[[ -z $UBOOT_COMPILER ]] && UBOOT_COMPILER="arm-linux-gnueabihf-"
	[[ -z $INITRD_ARCH ]] && INITRD_ARCH=arm
	QEMU_BINARY="qemu-arm-static"
	ARCHITECTURE=arm
	;;
esac

BOOTCONFIG_VAR_NAME=BOOTCONFIG_${BRANCH^^}
[[ -n ${!BOOTCONFIG_VAR_NAME} ]] && BOOTCONFIG=${!BOOTCONFIG_VAR_NAME}
[[ -z $LINUXCONFIG ]] && LINUXCONFIG="linux-${LINUXFAMILY}-${BRANCH}"
[[ -z $BOOTPATCHDIR ]] && BOOTPATCHDIR="u-boot-$LINUXFAMILY"
[[ -z $KERNELPATCHDIR ]] && KERNELPATCHDIR="$LINUXFAMILY-$BRANCH"

if [[ $RELEASE == xenial || $RELEASE == bionic ]]; then DISTRIBUTION="Ubuntu"; else DISTRIBUTION="Debian"; fi


# Essential packages
PACKAGE_LIST="bc bridge-utils build-essential cpufrequtils device-tree-compiler figlet fbset fping \
	iw fake-hwclock wpasupplicant psmisc ntp parted rsync sudo curl linux-base dialog crda \
	wireless-regdb ncurses-term python3-apt sysfsutils toilet u-boot-tools unattended-upgrades \
	usbutils wireless-tools console-setup unicode-data openssh-server initramfs-tools \
	ca-certificates resolvconf expect iptables automake \
	bison flex libwrap0-dev libssl-dev libnl-3-dev libnl-genl-3-dev \
	mc abootimg wget"


# Non-essential packages
PACKAGE_LIST_ADDITIONAL="alsa-utils btrfs-tools dosfstools iotop iozone3 stress sysbench screen ntfs-3g vim pciutils \
	evtest htop pv lsof apt-transport-https libfuse2 libdigest-sha-perl libproc-processtable-perl aptitude dnsutils f3 haveged \
	hdparm rfkill vlan sysstat bash-completion hostapd git ethtool network-manager unzip ifenslave command-not-found lirc \
	libpam-systemd iperf3 software-properties-common libnss-myhostname f2fs-tools avahi-autoipd iputils-arping qrencode"

# Dependent desktop packages
PACKAGE_LIST_DESKTOP="xserver-xorg xserver-xorg-video-fbdev gvfs-backends gvfs-fuse xfonts-base xinit x11-xserver-utils xterm thunar-volman \
	network-manager-gnome network-manager-openvpn-gnome gnome-keyring gcr libgck-1-0 p11-kit \
	libgl1-mesa-dri gparted synaptic policykit-1 profile-sync-daemon mesa-utils"

PACKAGE_LIST_OFFICE="lxtask mirage galculator hexchat mpv \
	gtk2-engines gtk2-engines-murrine gtk2-engines-pixbuf libgtk2.0-bin libgnome2-perl \
	network-manager-gnome network-manager-openvpn-gnome gnome-keyring gcr libgck-1-0 p11-kit \
	libpam-gnome-keyring thunderbird system-config-printer-common \
	bluetooth bluez bluez-tools blueman geany atril xarchiver leafpad \
	libreoffice-writer libreoffice-style-tango libreoffice-gtk fbi cups-pk-helper cups"

PACKAGE_LIST_PL="pasystray paman pavucontrol pulseaudio pavumeter pulseaudio-module-gconf pulseaudio-module-bluetooth gnome-orca paprefs"

#case $DISPLAY_MANAGER in
#	nodm)
#	PACKAGE_LIST_DESKTOP="$PACKAGE_LIST_DESKTOP nodm"
#	;;

#	lightdm)
	PACKAGE_LIST_DESKTOP="$PACKAGE_LIST_DESKTOP lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
#	;;

#	*)
#	exit_with_error "Unsupported display manager selected" "$DISPLAY_MANAGER"
#	;;
#esac

# add XFCE or MATE
case $BUILD_DESKTOP_DE in
	icewm)
	PACKAGE_LIST_DESKTOP="$PACKAGE_LIST_DESKTOP icewm"
	;;
	xfce)
	PACKAGE_LIST_DESKTOP="$PACKAGE_LIST_DESKTOP $PACKAGE_LIST_OFFICE"
	PACKAGE_LIST_DESKTOP="$PACKAGE_LIST_DESKTOP xfce4 xfce4-screenshooter xfce4-notifyd xfce4-terminal xfce4-notifyd"
	;;
	mate)
	PACKAGE_LIST_DESKTOP="$PACKAGE_LIST_DESKTOP $PACKAGE_LIST_OFFICE"
	PACKAGE_LIST_DESKTOP="$PACKAGE_LIST_DESKTOP mate-desktop-environment-extras mate-media mate-screensaver mate-utils mate-power-manager mate-applets mozo tango-icon-theme"
	;;
esac

# Release specific packages
case $RELEASE in
	jessie)
	PACKAGE_LIST_RELEASE="less kbd gnupg2 dirmngr"
	PACKAGE_LIST_DESKTOP+=" paman libgcr-3-common gcj-jre-headless policykit-1-gnome eject numix-icon-theme iceweasel pluma system-config-printer"
	;;
	stretch)
	PACKAGE_LIST_RELEASE="man-db less kbd net-tools netcat-openbsd gnupg2 dirmngr"
	PACKAGE_LIST_DESKTOP+=" thunderbird chromium dbus-x11 gksu"
	[[ $BUILD_DESKTOP_DE != icewm  ]] && PACKAGE_LIST_DESKTOP+=" libgcr-3-common gcj-jre-headless system-config-printer-common system-config-printer"
	[[ $BUILD_DESKTOP_DE != icewm  ]] && PACKAGE_LIST_DESKTOP="$PACKAGE_LIST_DESKTOP $PACKAGE_LIST_PL"
	;;
	xenial)
	PACKAGE_LIST_RELEASE="man-db nano zram-config"
	PACKAGE_LIST_DESKTOP+=" thunderbird chromium-browser gksu"
	[[ $BUILD_DESKTOP_DE != icewm  ]] && PACKAGE_LIST_DESKTOP+="  libgcr-3-common gcj-jre-headless numix-icon-theme language-selector-gnome system-config-printer-common system-config-printer-gnome ubuntu-mate-lightdm-theme"
	[[ $BUILD_DESKTOP_DE != icewm  ]] && PACKAGE_LIST_DESKTOP="$PACKAGE_LIST_DESKTOP $PACKAGE_LIST_PL"
	[[ $ARCH == armhf ]] && PACKAGE_LIST_DESKTOP+=" mate-utils mate-settings-daemon"
	;;
	bionic)
	PACKAGE_LIST_RELEASE="man-db nano zram-config"
	PACKAGE_LIST_DESKTOP+=" thunderbird firefox"
	[[ $BUILD_DESKTOP_DE != icewm  ]] && PACKAGE_LIST_DESKTOP+=" language-selector-gnome system-config-printer-common system-config-printer-gnome ubuntu-mate-desktop ubuntu-mate-themes mate-window-menu-applet"
	[[ $ARCH == armhf ]] && PACKAGE_LIST_DESKTOP+=" mate-utils mate-settings-daemon"
	;;
esac

DEBIAN_MIRROR='httpredir.debian.org/debian'
UBUNTU_MIRROR='ports.ubuntu.com/'

# For user override
if [[ -f $SRC/userpatches/lib.config ]]; then
	display_alert "Using user configuration override" "userpatches/lib.config" "info"
	source $SRC/userpatches/lib.config
fi

# apt-cacher-ng mirror configurarion
if [[ $DISTRIBUTION == Ubuntu ]]; then
	APT_MIRROR=$UBUNTU_MIRROR
else
	APT_MIRROR=$DEBIAN_MIRROR
fi

[[ -n $APT_PROXY_ADDR ]] && display_alert "Using custom apt-cacher-ng address" "$APT_PROXY_ADDR" "info"

# Build final package list after possible override
PACKAGE_LIST="$PACKAGE_LIST $PACKAGE_LIST_RELEASE $PACKAGE_LIST_ADDITIONAL"
#if [[ $ARCH == arm64 ]]; then
	#PACKAGE_LIST_DESKTOP="${PACKAGE_LIST_DESKTOP/iceweasel/iceweasel:armhf}"
	#PACKAGE_LIST_DESKTOP="${PACKAGE_LIST_DESKTOP/thunderbird/thunderbird:armhf}"
#fi
[[ $BUILD_DESKTOP == yes ]] && PACKAGE_LIST="$PACKAGE_LIST $PACKAGE_LIST_DESKTOP"

# remove any packages defined in PACKAGE_LIST_RM in lib.config
#if [[ -n $PACKAGE_LIST_RM ]]; then
#	PACKAGE_LIST=$(sed -r "s/\b($(tr ' ' '|' <<< $PACKAGE_LIST_RM))\b//g" <<< $PACKAGE_LIST)
#fi

# remove any packages defined in PACKAGE_LIST_RM in lib.config
if [[ -n $PACKAGE_LIST_RM ]]; then
        SED_TASK=""
        for PACKAGE_RM in $PACKAGE_LIST_RM; do
                SED_TASK+="|\s${PACKAGE_RM}\s"
        done
        PACKAGE_LIST=$(sed -r "s/${SED_TASK:1}/ /g" <<< " $PACKAGE_LIST ")
fi

# debug
cat <<-EOF >> $DEST/debug/output.log

## BUILD SCRIPT ENVIRONMENT

Repository: $(git remote get-url $(git remote 2>/dev/null) 2>/dev/null)
Version: $(git describe --match=d_e_a_d_b_e_e_f --always --dirty 2>/dev/null)

Host OS: $(lsb_release -sc)
Host arch: $(dpkg --print-architecture)
Host system: $(uname -a)
Virtualization type: $(systemd-detect-virt)

## Build script directories
Build directory is located on:
$(findmnt -o TARGET,SOURCE,FSTYPE,AVAIL -T $SRC)

Build directory permissions:
$(getfacl -p $SRC)

Temp directory permissions:
$(getfacl -p $SRC/.tmp)

## BUILD CONFIGURATION

Build target:
Board: $BOARD
Branch: $BRANCH
Desktop: $BUILD_DESKTOP

Kernel configuration:
Repository: $KERNELSOURCE
Branch: $KERNELBRANCH
Config file: $LINUXCONFIG

U-boot configuration:
Repository: $BOOTSOURCE
Branch: $BOOTBRANCH
Config file: $BOOTCONFIG

Partitioning configuration:
Root partition type: $ROOTFS_TYPE
Boot partition type: ${BOOTFS_TYPE:-(none)}
User provided boot partition size: ${BOOTSIZE:-0}
Offset: $OFFSET

CPU configuration:
$CPUMIN - $CPUMAX with $GOVERNOR
EOF
