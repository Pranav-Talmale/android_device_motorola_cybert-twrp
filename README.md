# Android Device Tree for Motorola Edge 60 Pro

Device tree for building TWRP for the **Motorola Edge 60 Pro (cybert)**.

![Motorola Edge 60 Pro](https://motorolain.vtexassets.com/arquivos/ids/161045-1600-auto?width=1600\&height=auto\&aspect=true "Motorola Edge 60 Pro")

## Device Information

| Property     | Value                   |
| ------------ | ----------------------- |
| Device       | Motorola Edge 60 Pro    |
| Codename     | `cybert`                |
| SoC          | MediaTek Dimensity 8350 |
| Android base | Android 16              |
| Recovery     | TWRP                    |
| Architecture | ARM64                   |

## Working

* [x] Booting TWRP
* [x] Touchscreen
* [x] Display
* [x] ADB
* [x] MTP
* [x] Internal storage access
* [x] Flashing ZIPs
* [x] Flashing images
* [x] FBE decryption
* [x] USB OTG
* [x] TEE / Trustonic initialization for decryption
* [ ] Vibration — **TODO / WIP**

## Decryption

Decryption required additional work beyond simply loading the Android 16 vendor blobs.

The device uses Trustonic/MobiCore components for its TEE and key-provisioning infrastructure. The required Trustonic artifacts are present in the `tzapp` partition and are mounted during recovery initialization.

The current implementation initializes the required vendor partitions and TEE environment before Android's encryption/key-provisioning components are started.

In particular, the recovery `tee.rc` handles:

* `protect_f`
* `protect_s`
* `nvcfg`
* `nvdata`
* `tzapp`
* `persist`
* MobiCore device nodes
* Trustonic storage directories
* `mcRegistry`
* `key_provisioning`
* MobiCore startup

The `tzapp` partition already contains the required `.drbin` and `.tlbin` trustlet files, eliminating the need for a separate trustlet backup/copy script.

> **Note:** `tzapp_a` is currently used by the recovery configuration. On devices where the active slot can differ, the mount should eventually be made slot-aware.

## Flashing

First check the currently active slot using:

```sh
fastboot getvar current-slot
```

Flash the recovery image using fastboot:

```sh
fastboot flash vendor_boot_a vendor_boot.img
```
OR
```sh
fastboot flash vendor_boot_b vendor_boot.img
```
Depending on the active slot.

Once TWRP has booted, images and ZIP packages can be flashed normally.

For flashing the recovery/vendor boot image itself, use the appropriate partition for the device and bootloader configuration. Verify the partition layout before flashing.

ADB can be used to access the recovery shell:

```sh
adb shell
```

Check that the device is detected:

```sh
adb devices
```

## USB OTG

USB OTG is working.

Connect a USB OTG device and verify that it is detected from recovery. Storage devices can then be accessed through TWRP where supported.

## Vibration

**TODO / WIP**

Vibration is currently not working correctly in recovery.

Further investigation is required into the vibrator HAL, kernel interface, device nodes, and required vendor components.

## Building

### 1. Initialize the TWRP Android 16 manifest

The recommended manifest is the TWRP-Test Android 16 manifest:

```sh
repo init --depth=1 \
    -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git \
    -b twrp-16.0
```

### 2. Sync the source tree

```sh
repo sync
```

### 3. Add this device tree

Place the device tree at:

```text
device/motorola/cybert
```

### 4. Set up the build environment

```sh
. build/envsetup.sh
```

### 5. Select the device

```sh
lunch twrp_cybert-bp2a-eng
```

### 6. Build

```sh
mka adbd vendorbootimage
```

The resulting build artifacts will be generated under:

```text
out/target/product/cybert/
```

## Credits

This device tree would not have been possible without the work and research from the following projects and developers.

### Original Device Tree

**Motorola-MT6897-Devs**

Original device tree and initial device bring-up:

[https://github.com/Motorola-MT6897-Devs/android_device_motorola_cybert](https://github.com/Motorola-MT6897-Devs/android_device_motorola_cybert)

### Final Password Decryption Fix

**forforksake**

Used as a reference for solving the final password-based decryption issue:

[https://github.com/forforksake/recovery_device_motorola_kyoto/](https://github.com/forforksake/recovery_device_motorola_kyoto/)

### Passwordless Decryption

**lazycodebuilder**

Reference for getting Android FBE decryption working without requiring a password:

[https://github.com/lazycodebuilder/android_recovery_device_nothing_mt6878](https://github.com/lazycodebuilder/android_recovery_device_nothing_mt6878)

### Initial Decryption Blob Layout

**hoshiyomiX**

Reference for the initial structure of the decryption blobs and the modules required for Trustonic/TEE initialization:

[https://github.com/hoshiyomiX/recovery-device_infinix_Infinix-X6873](https://github.com/hoshiyomiX/recovery-device_infinix_Infinix-X6873)

### OMAPI / Weaver / StrongBox

**YuKongA**

Reference for OMAPI, Weaver, and StrongBox integration. These references were investigated during development, although they ultimately did not contribute significantly to the final decryption solution.

[https://github.com/YuKongA/twrp_device_xiaomi_sm8850](https://github.com/YuKongA/twrp_device_xiaomi_sm8850)

### TWRP-Test Manifest

**TWRP-Test**

The TWRP Android 16 manifest used for the final build environment:

[https://github.com/TWRP-Test](https://github.com/TWRP-Test)

The TWRP-Test manifest was particularly important because the Android 16 decryption blobs did not work correctly with the official TWRP 14.1 and OrangeFox 14.1 manifests. Using the Android 16 TWRP-Test manifest provided the environment required to get decryption working.

Manifest:

[https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git](https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git)

## References

* [Motorola-MT6897-Devs — cybert device tree](https://github.com/Motorola-MT6897-Devs/android_device_motorola_cybert)
* [forforksake — kyoto recovery device](https://github.com/forforksake/recovery_device_motorola_kyoto/)
* [lazycodebuilder — Nothing MT6878 recovery device](https://github.com/lazycodebuilder/android_recovery_device_nothing_mt6878)
* [hoshiyomiX — Infinix X6873 recovery device](https://github.com/hoshiyomiX/recovery-device_infinix_Infinix-X6873)
* [YuKongA — Xiaomi SM8850 TWRP device](https://github.com/YuKongA/twrp_device_xiaomi_sm8850)
* [TWRP-Test](https://github.com/TWRP-Test)
* [TWRP-Test — Android 16 manifest](https://github.com/TWRP-Test/platform_manifest_twrp_aosp)

## License

```text
#
# SPDX-FileCopyrightText: The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
```
