#
#	Vendorsetup for Xiaomi Mi 6 (sagit) - OrangeFox 12.1
#
FDEVICE="sagit"

fox_get_target_device() {
local chkdev=$(echo "$BASH_SOURCE" | grep \"$FDEVICE\")
   if [ -n "$chkdev" ]; then
      FOX_BUILD_DEVICE="$FDEVICE"
   else
      chkdev=$(set | grep BASH_ARGV | grep \"$FDEVICE\")
      [ -n "$chkdev" ] && FOX_BUILD_DEVICE="$FDEVICE"
   fi
}

if [ -z "$1" -a -z "$FOX_BUILD_DEVICE" ]; then
   fox_get_target_device
fi

if [ "$1" = "$FDEVICE" -o "$FOX_BUILD_DEVICE" = "$FDEVICE" ]; then
	# Base Android version of the recovery itself (12.1, not the ROM)
	export PLATFORM_VERSION="12.1.0"
	export PLATFORM_SECURITY_PATCH="2099-12-31"
	export TW_DEFAULT_LANGUAGE="zh_CN"

	# Encryption / OTA handling
	export OF_OTA_RES_DECRYPT=1
	export OF_DONT_PATCH_ENCRYPTED_DEVICE=1
	export OF_KEEP_DM_VERITY=1
	export OF_DISABLE_FORCED_ENCRYPTION=1

	# Magisk / image patching
	export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
	export OF_USE_MAGISKBOOT=1
	export OF_USE_MAGISKBOOT_FOR_ALL_PATCHES=1
	export OF_FORCE_MAGISKBOOT_BOOT_PATCH_MIUI=1

	# Extras
	export FOX_USE_BASH_SHELL=1
	export FOX_ASH_IS_BASH=1
	export FOX_USE_NANO_EDITOR=1
	export FOX_USE_ZIP_BINARY=1
	export FOX_USE_TAR_BINARY=1
	export FOX_USE_SED_BINARY=1
	export FOX_USE_XZ_UTILS=1
	export FOX_ENABLE_APP_MANAGER=1
	export FOX_REPLACE_BUSYBOX_PS=1
	export OF_SKIP_MULTIUSER_FOLDERS_BACKUP=1

	# Device specifics
	# Shown on Settings -> About as the maintainer name (and only name).
	export OF_MAINTAINER="晓宇xxxy"
	export OF_FLASHLIGHT_ENABLE=1
	export OF_NO_TREBLE_COMPATIBILITY_CHECK=1
	export OF_SCREEN_H=1920
	export OF_STATUS_H=80
	export OF_STATUS_INDENT_LEFT=48
	export OF_STATUS_INDENT_RIGHT=48
	export OF_ALLOW_DISABLE_NAVBAR=0
	export OF_CLOCK_POS=1

	# List container heights. The theme default is a 512px group list, which
	# only fits ~3.5 rows at 144px each, so the last entries of grouped menus
	# (e.g. the "More" page) were clipped with no scrollbar. cv=6 gives
	# 540px for plain lists and 1152px for grouped lists, enough for 8 rows.
	export OF_OPTIONS_LIST_NUM=6

	if [ -n "$FOX_BUILD_LOG_FILE" -a -f "$FOX_BUILD_LOG_FILE" ]; then
		export | grep "FOX" >> $FOX_BUILD_LOG_FILE
		export | grep "OF_" >> $FOX_BUILD_LOG_FILE
		export | grep "TW_" >> $FOX_BUILD_LOG_FILE
	fi

	command -v add_lunch_combo >/dev/null && add_lunch_combo twrp_"$FDEVICE"-eng
fi
