#
# SPDX-FileCopyrightText: LineageOS
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Installs gsi keys into ramdisk, to boot a developer GSI with verified boot.
$(call inherit-product, $(SRC_TARGET_DIR)/product/developer_gsi_keys.mk)

# Inherit from device makefile.
$(call inherit-product, device/motorola/cybert/device.mk)

# Inherit some common TWRP stuff.
$(call inherit-product, vendor/twrp/config/common.mk)

TARGET_BOOT_ANIMATION_RES := 1080

PRODUCT_NAME := twrp_cybert
PRODUCT_DEVICE := cybert
PRODUCT_MANUFACTURER := motorola
PRODUCT_BRAND := motorola
PRODUCT_MODEL := motorola edge 60 pro

CUSTOM_PROCESSOR_INFO := MediaTek Dimensity 8350 Extreme

PRODUCT_GMS_CLIENTID_BASE := android-motorola

# Set properties to hide Reflash TWRP
PRODUCT_PROPERTY_OVERRIDES += \
    ro.twrp.vendor_boot=true

TW_DEVICE_VERSION := cybert_v1.0.0

PRODUCT_BUILD_PROP_OVERRIDES += \
    DeviceName=cybert \
    BuildDesc="cybert_g_sys-user 16 W1VV36M.7-21-5 bb36b3 test-keys" \
    BuildFingerprint=motorola/cybert_g_sys/cybert:16/W1VV36M.7-21-5/bb36b3:user/release-keys
