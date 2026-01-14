#
# SPDX-FileCopyrightText: LineageOS
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from device makefile.
$(call inherit-product, device/motorola/cybert/device.mk)

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

TARGET_BOOT_ANIMATION_RES := 1080

PRODUCT_NAME := lineage_cybert
PRODUCT_DEVICE := cybert
PRODUCT_MANUFACTURER := motorola
PRODUCT_BRAND := motorola
PRODUCT_MODEL := motorola edge 60 pro

CUSTOM_PROCESSOR_INFO := MediaTek Dimensity 8350 Extreme

PRODUCT_GMS_CLIENTID_BASE := android-motorola

PRODUCT_BUILD_PROP_OVERRIDES += \
    DeviceName=cybert \
    BuildDesc="cybert_g_sys-user 16 W1VV36M.7-21-5 bb36b3 test-keys" \
    BuildFingerprint=motorola/cybert_g_sys/cybert:16/W1VV36M.7-21-5/bb36b3:user/release-keys
