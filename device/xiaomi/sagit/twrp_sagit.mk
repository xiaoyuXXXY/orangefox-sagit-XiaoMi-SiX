#
# Product configuration for Xiaomi Mi 6 (sagit) - OrangeFox 12.1
#

PRODUCT_RELEASE_NAME := sagit

# 64-bit userspace, recovery-only build
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

# Keymaster / gatekeeper hardware names used by the legacy HIDL services
# shipped in recovery/root/sbin
PRODUCT_PROPERTY_OVERRIDES += \
    ro.hardware.keystore=msm8998 \
    ro.hardware.gatekeeper=msm8998

# Device identifier. This must come after all inclusions
PRODUCT_DEVICE := sagit
PRODUCT_NAME := twrp_sagit
PRODUCT_BRAND := Xiaomi
PRODUCT_MODEL := MI 6
PRODUCT_MANUFACTURER := Xiaomi
