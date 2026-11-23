#
# Copyright 2017 The Android Open Source Project
#
# Copyright (C) 2018-2020 OrangeFox Recovery Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This contains the module build definitions for the hardware-specific
# components for this device.
#
# As much as possible, those components should be built unconditionally,
# with device-specific names to avoid collisions, to avoid device-specific
# bitrot and build breakages. Building a component unconditionally does
# *not* include it on all devices, so it is safe even with hardware-specific
# components.
#
#

LOCAL_PATH := device/xiaomi/sagit

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a73

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a73
TARGET_USES_64_BIT_BINDER := true

ENABLE_CPUSETS := true
ENABLE_SCHEDBOOST := true

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := msm8998
TARGET_NO_BOOTLOADER := true

# Kernel
BOARD_KERNEL_CMDLINE := console=ttyMSM0,115200,n8 androidboot.console=ttyMSM0 earlycon=msm_serial_dm,0xc1b0000
BOARD_KERNEL_CMDLINE += androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x37 ehci-hcd.park=3
BOARD_KERNEL_CMDLINE += lpm_levels.sleep_disabled=1 sched_enable_hmp=1 sched_enable_power_aware=1
BOARD_KERNEL_CMDLINE += service_locator.enable=1 swiotlb=2048 androidboot.usbcontroller=a800000.dwc3
BOARD_KERNEL_CMDLINE += androidboot.configfs=true firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_TAGS_OFFSET := 0x00000100
BOARD_RAMDISK_OFFSET := 0x01000000

ifeq ($(FOX_BUILD_FULL_KERNEL_SOURCES),1)
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb
TARGET_KERNEL_CONFIG := sagit-fox_defconfig
TARGET_KERNEL_SOURCE := kernel/xiaomi/sagit
else
TARGET_PREBUILT_KERNEL := $(LOCAL_PATH)/prebuilt/Image.gz-dtb
endif
# DJ9 end

# Platform
TARGET_BOARD_PLATFORM := msm8998
TARGET_BOARD_PLATFORM_GPU := qcom-adreno540


# Partitions
BOARD_FLASH_BLOCK_SIZE := 262144 # (BOARD_KERNEL_PAGESIZE * 64)
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_CACHEIMAGE_PARTITION_SIZE := 402653184
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 5368709120
BOARD_USERDATAIMAGE_PARTITION_SIZE := 120426835968
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_PARTITION_SIZE := 872415232
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_COPY_OUT_VENDOR := vendor

# Recovery
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_HAS_NO_SELECT_BUTTON := true
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
TARGET_RECOVERY_FSTAB := $(LOCAL_PATH)/recovery.fstab

# TWRP specific build flags
BOARD_HAS_NO_REAL_SDCARD := true
RECOVERY_SDCARD_ON_DATA := true
TARGET_RECOVERY_QCOM_RTC_FIX := true
TW_BRIGHTNESS_PATH := "/sys/class/leds/lcd-backlight/brightness"
TW_DEFAULT_BRIGHTNESS := 2047
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_EXCLUDE_SUPERSU := true
TW_EXTRA_LANGUAGES := true
TW_INPUT_BLACKLIST := "hbtp_vm"
TW_MAX_BRIGHTNESS := 4095
TW_SCREEN_BLANK_ON_BOOT := true
TW_THEME := portrait_hdpi

# Default UI language: Simplified Chinese (image ships zh_CN/zh_TW in twres/languages)
TW_DEFAULT_LANGUAGE := zh_CN
TW_INCLUDE_FUSE_EXFAT := true
#
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_FBE := true
#

# ---------- OrangeFox 12.1 adjustments ----------
# sagit is A-only with a dedicated recovery partition
BOARD_USES_RECOVERY_AS_BOOT := false

# 12.1 recovery: crypto/FBE are driven by TW_INCLUDE_CRYPTO; the legacy
# keymaster@3.0 / gatekeeper@1.0 blobs live in recovery/root/sbin
TW_INCLUDE_CRYPTO := true
# keep the built image inside the 64MB recovery partition
TW_INCLUDE_REPACKTOOLS := true
BOARD_USES_METADATA_PARTITION := false

# Legacy battery: sagit runs a 4.4 kernel with no android.hardware.health HAL,
# so the default health-service path returns 0. Read sysfs directly instead.
OF_USE_LEGACY_BATTERY_SERVICES := 1

# sagit uses a 4.4 kernel which cannot mount ext4 with the 64bit/metadata_csum
# features that e2fsprogs 1.45 enables by default. TARGET_USES_MKE2FS makes the
# build copy system/extras/ext4_utils/mke2fs.conf (conservative feature set, the
# same one shipped in the 24.03.16 build) into /system/etc of the recovery
# ramdisk. Without it mke2fs falls back to its built-in profile and produces a
# filesystem the kernel refuses to mount right after "Format Data".
TARGET_USES_MKE2FS := true

# Keep /data mounted after Setup_Data_Media instead of unmounting it again,
# otherwise internal storage drops offline on its own.
OF_FIX_DECRYPTION_ON_DATA_MEDIA := 1

# sagit runs a 4.4 kernel whose f2fs driver has no quota/verity support. The
# android default profile (-g android) enables both, which produces a
# filesystem the kernel then refuses to mount, so make_f2fs is limited to
# encrypt+extra_attr.
# NOTE: the data filesystem is deliberately NOT forced here. The user picks
# ext4 or f2fs from "Change File System", and "Format Data" rebuilds whichever
# one is actually on the partition (blkid decides).
OF_F2FS_LEGACY_FEATURES := 1

# Default to China Standard Time (UTC+8). No DST in China, so the timezone
# string carries no DST component and tw_time_zone_guidst is reset to 0.
OF_DEFAULT_TIMEZONE := CST-8
