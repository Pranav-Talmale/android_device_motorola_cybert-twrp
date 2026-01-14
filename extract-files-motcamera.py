#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
#
# SPDX-FileCopyrightText: The CyanogenMod Project
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

from pathlib import Path
from extract_utils.fixups_blob import (
    blob_fixup,
    blob_fixups_user_type,
)
from extract_utils.main import (
    ExtractUtils,
    ExtractUtilsModule,
)

namespace_imports = [
    'device/motorola/cybert',
    'hardware/mediatek',
    'hardware/mediatek/libmtkperf_client',
    'hardware/motorola',
]

blob_fixups: blob_fixups_user_type = {
}

module = ExtractUtilsModule(
    'cybert-motcamera',   # This ensures output goes to vendor/motorola/cybert-motcamera
    'motorola',
    blob_fixups=blob_fixups,
    namespace_imports=namespace_imports,
    skip_main_proprietary_file=True, # Important: Stop it from looking for the default file
)

# Get the absolute path to the file in the current directory (device/motorola/cybert)
# When passing an absolute path to add_proprietary_file, extract-utils ignores 
# the internal device path logic and uses exactly what we give it.
module_dir = Path(__file__).parent.resolve()
proprietary_list = module_dir / 'proprietary-files-motcamera.txt'

module.add_proprietary_file(str(proprietary_list))

if __name__ == '__main__':
    utils = ExtractUtils.device(module)
    utils.run()