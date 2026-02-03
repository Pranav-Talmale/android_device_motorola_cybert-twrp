#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_ROOT_DIR="$(readlink -f "${SCRIPT_DIR}/../../..")"
GKI_ROOT_DIR="${KERNEL_ROOT_DIR}/kernel/motorola"

# Verify GKI Root has build tools
if [ ! -f "${GKI_ROOT_DIR}/build/kernel/kleaf/bazel.sh" ]; then
    echo "Error: Could not find Bazel build script at ${GKI_ROOT_DIR}/build/kernel/kleaf/bazel.sh"
    exit 1
fi

TARGET_PRODUCT=cybert
KERNEL_DEFCONFIG="mgk_64_k61_defconfig"
KERNEL_BUILD_VARIANT=user
KERNEL_TARGET_ARCH=arm64

# Switch to GKI Root for build
cd "${GKI_ROOT_DIR}"
echo "Switched to GKI Root: ${PWD}"

# Kernel source relative to GKI root
KERNEL_DIR="kernel_device_modules-6.1"
LINUX_KERNEL_VERSION="kernel-6.1"
KERNEL_DEFCONFIG_OVERLAYS="mgk_64_k61_defconfig"

# Symlinking common if not present in GKI root (it usually is, but just in case)
if [ ! -L "common" ] && [ ! -d "common" ]; then
    echo "Symlinking common -> ${LINUX_KERNEL_VERSION}..."
    ln -s "${LINUX_KERNEL_VERSION}" "common"
fi

# New output directory (Absolute path)
KERNEL_BAZEL_BUILD_OUT="${KERNEL_ROOT_DIR}/out/target/product/${TARGET_PRODUCT}/KERNEL_OBJ"
# Clean up specific artifacts to enable delta builds
KERNEL_BAZEL_DIST_OUT=${KERNEL_BAZEL_BUILD_OUT}/dist
echo "Cleaning old artifacts..."
rm -rf "${KERNEL_BAZEL_DIST_OUT}/dtbs"
rm -rf "${KERNEL_BAZEL_DIST_OUT}/system"
rm -rf "${KERNEL_BAZEL_DIST_OUT}/vendor"
rm -rf "${KERNEL_BAZEL_DIST_OUT}/vendor_ramdisk"
rm -f "${KERNEL_BAZEL_DIST_OUT}/Image.lz4"
mkdir -p "${KERNEL_BAZEL_DIST_OUT}"

echo "Reference Kernel Build Script"
echo "Root Dir: ${KERNEL_ROOT_DIR}"
echo "GKI Dir: ${GKI_ROOT_DIR}"
echo "Kernel Dir: ${KERNEL_DIR}"
echo "Output Dir: ${KERNEL_BAZEL_BUILD_OUT}"

# Generate MODULE.bazel with MGK extension
# Generate MODULE.bazel with MGK extension (Only if missing to preserve incremental builds)
if [ ! -f "MODULE.bazel" ]; then
    echo "Generating MODULE.bazel..."
    cat "${GKI_ROOT_DIR}/build/kernel/kleaf/bzlmod/bazel.MODULE.bazel" > MODULE.bazel
    cat >> MODULE.bazel << 'EOF'

# MGK extension for Motorola kernel builds
mgk_ext = use_extension("//build/bazel_mgk_rules:mgk_ext.bzl", "mgk_ext")
use_repo(mgk_ext, "mgk_info")
use_repo(mgk_ext, "mgk_internal")
use_repo(mgk_ext, "mgk_ko")
EOF
else
    echo "MODULE.bazel exists, skipping generation."
fi

if [ ! -f "WORKSPACE.bzlmod" ]; then
    touch WORKSPACE.bzlmod
fi
if [ ! -L "WORKSPACE" ] && [ ! -f "WORKSPACE" ]; then
    touch WORKSPACE
fi

export BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1 DEFCONFIG_OVERLAYS="../../arch/arm64/configs/ext_config/moto-mgk_64_k61-cybert.config" KERNEL_VERSION=kernel-6.1 JAVA_HOME="${GKI_ROOT_DIR}/prebuilts/jdk/jdk11/linux-x86" PATH="${GKI_ROOT_DIR}/prebuilts/jdk/jdk11/linux-x86/bin:${PATH}"

PRIVATE_BAZEL_BUILD_FLAG="--experimental_writable_outputs --noincompatible_disallow_empty_glob --repo_manifest=${GKI_ROOT_DIR}/${KERNEL_DIR}/fake_manifest.xml"

PRIVATE_BAZEL_DIST_GOAL="//${KERNEL_DIR}:mgk_64_k61_customer_dist.${KERNEL_BUILD_VARIANT}"

# Run Bazel build
build/kernel/kleaf/bazel.sh --output_root=${KERNEL_BAZEL_BUILD_OUT} --output_base=${KERNEL_BAZEL_BUILD_OUT}/bazel/output_user_root/output_base run ${PRIVATE_BAZEL_BUILD_FLAG} --nokmi_symbol_list_violations_check ${PRIVATE_BAZEL_DIST_GOAL} -- --dist_dir=${KERNEL_BAZEL_DIST_OUT}

# Build DTBs for cybert (mt6897) from device modules sources
echo "Building DTBs for ${TARGET_PRODUCT}..."
mkdir -p ${KERNEL_BAZEL_DIST_OUT}/dtbs

# Set up paths - relative to PWD (GKI_ROOT_DIR)
DTS_DIR="${PWD}/${KERNEL_DIR}/arch/${KERNEL_TARGET_ARCH}/boot/dts/mediatek"
CLANG="${GKI_ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r547379/bin/clang"
# DTC path is in the bazel-out which is in output_root
DTC="${KERNEL_BAZEL_BUILD_OUT}/bazel/output_user_root/output_base/execroot/_main/bazel-out/k8-fastbuild/bin/${KERNEL_DIR}/mgk_64_k61.${KERNEL_BUILD_VARIANT}/scripts/dtc/dtc"

# Include paths for DTS preprocessing
DTC_INCLUDES="-I${PWD}/${KERNEL_DIR}/include \
    -I${PWD}/common/include \
    -I${PWD}/${KERNEL_DIR}/arch/${KERNEL_TARGET_ARCH}/boot/dts \
    -I${DTS_DIR}"

# Check if DTC exists (use system dtc as fallback)
if [ ! -f "${DTC}" ]; then
    DTC=$(which dtc 2>/dev/null || echo "")
    if [ -z "${DTC}" ]; then
        echo "Warning: dtc not found, skipping DTB build"
    fi
fi

# Build base DTB: mt6897.dtb
if [ -f "${DTS_DIR}/mt6897.dts" ]; then
    echo "  Building mt6897.dtb..."
    ${CLANG} -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp ${DTC_INCLUDES} \
        -o /tmp/mt6897.dts.preprocessed "${DTS_DIR}/mt6897.dts" 2>/dev/null && \
    ${DTC} -@ -I dts -O dtb -o "${KERNEL_BAZEL_DIST_OUT}/dtbs/mt6897.dtb" \
        /tmp/mt6897.dts.preprocessed 2>/dev/null && echo "    -> mt6897.dtb OK" || echo "    -> Failed"
fi

# Clean up temp files
rm -f /tmp/*.dts.preprocessed 2>/dev/null

# List built DTBs
echo ""
echo "DTBs built:"
ls -la ${KERNEL_BAZEL_DIST_OUT}/dtbs/*.dtb* 2>/dev/null || echo "  (none)"


# --- Module Organization ---
echo ""
echo "Organizing modules..."
DIST_DIR="${KERNEL_BAZEL_DIST_OUT}"
MODULES_SEARCH_PATH="${DIST_DIR}"

if [ -d "${MODULES_SEARCH_PATH}" ]; then
    echo "  Searching for modules in: ${MODULES_SEARCH_PATH}"
    
    # Ensure dist dir is writable and executable (Bazel might leave it read-only/non-executable)
    if [ -d "${DIST_DIR}" ]; then
        chmod -R u+rwx "${DIST_DIR}"
    fi

    # Define destination directories - keeping strict structure for BoardConfig usage
    SYSTEM_MOD_DIR="${DIST_DIR}/system"
    VENDOR_MOD_DIR="${DIST_DIR}/vendor"
    VENDOR_RAMDISK_MOD_DIR="${DIST_DIR}/vendor_ramdisk"
    
    mkdir -p "${SYSTEM_MOD_DIR}" "${VENDOR_MOD_DIR}" "${VENDOR_RAMDISK_MOD_DIR}"
    
    # Track missing modules
    declare -a MISSING_MODULES=()

    # Helper function to copy modules from list
    copy_modules() {
        local list_file="$1"
        local dest_dir="$2"
        local label="$3"
        
        if [ -f "${list_file}" ]; then
            echo "  Processing ${label} from $(basename ${list_file})..."
            while IFS= read -r module || [ -n "$module" ]; do
                # Trim whitespace
                module=$(echo "$module" | xargs)
                [ -z "$module" ] && continue
                [ "${module:0:1}" = "#" ] && continue # Skip comments
                
                # Find module file (handle potential paths or just filename)
                local mod_name=$(basename "$module")
                # Find the module recursively in the search path
                # Use head -1 to pick the first match if duplicates exist (usually identical)
                local src_path=$(find "${MODULES_SEARCH_PATH}" -name "${mod_name}" 2>/dev/null | head -1)
                
                if [ -n "${src_path}" ]; then
                    # Check if we are trying to copy the file to itself
                    if [ "${src_path}" != "${dest_dir}/${mod_name}" ]; then
                        cp -f "${src_path}" "${dest_dir}/"
                    else
                        echo "    Info: Skipping copy, source and dest are same: ${mod_name}"
                    fi
                else
                    echo "    Warning: Module ${mod_name} not found in build output"
                    MISSING_MODULES+=("${mod_name} (${label})")
                fi
            done < "${list_file}"
            echo "    -> Copied to ${dest_dir}"
        else
            echo "  Warning: Module list not found: ${list_file}"
        fi
    }

    # Iterate over modules.load files and copy modules to respective directories
    # Format: local_file_suffix:destination_dir:description
    declare -a MODULE_GROUPS=(
        "system:${SYSTEM_MOD_DIR}:System Modules"
        "vendor:${VENDOR_MOD_DIR}:Vendor Modules"
        "vendor_ramdisk:${VENDOR_RAMDISK_MOD_DIR}:Vendor Ramdisk Modules"
        "recovery:${VENDOR_RAMDISK_MOD_DIR}:Recovery Modules"
    )

    for group in "${MODULE_GROUPS[@]}"; do
        IFS=':' read -r suffix dest_dir desc <<< "$group"
        load_file="${SCRIPT_DIR}/modules.load.${suffix}"
        
        if [ -f "${load_file}" ]; then
             copy_modules "${load_file}" "${dest_dir}" "${desc}"
        else
             echo "    Warning: ${desc} list (${suffix}) not found in ${SCRIPT_DIR}."
        fi
    done

else
    echo "Warning: Could not find modules installation directory in dist: ${MODULES_SEARCH_PATH}"
fi

# Ensure Image.lz4 exists (Moved to end to be part of final artifact check)
echo ""
echo "Checking for Kernel Image..."
# Ensure Image.lz4 exists in DIST_DIR root
echo ""
echo "Checking for Kernel Image..."

# Try to find Image.lz4 anywhere in dist (it might be in a subdir)
IMAGE_LZ4_FOUND=$(find "${KERNEL_BAZEL_DIST_OUT}" -name "Image.lz4" -type f | head -1)

if [ -f "${IMAGE_LZ4_FOUND}" ]; then
    echo "  Found Image.lz4 at: ${IMAGE_LZ4_FOUND}"
    # Copy to root of dist if not already there
    if [ "${IMAGE_LZ4_FOUND}" != "${KERNEL_BAZEL_DIST_OUT}/Image.lz4" ]; then
        cp "${IMAGE_LZ4_FOUND}" "${KERNEL_BAZEL_DIST_OUT}/Image.lz4"
        echo "  -> Copied to ${KERNEL_BAZEL_DIST_OUT}/Image.lz4"
    fi
else
    # Fallback to compressing Image if Image.lz4 not found anywhere
    IMAGE_FOUND=$(find "${KERNEL_BAZEL_DIST_OUT}" -name "Image" -type f | head -1)
    
    if [ -f "${IMAGE_FOUND}" ]; then
        echo "  Image.lz4 not found, compressing Image from: ${IMAGE_FOUND}..."
        LZ4_CMD="${GKI_ROOT_DIR}/prebuilts/kernel-build-tools/linux-x86/bin/lz4"
        [ ! -f "${LZ4_CMD}" ] && LZ4_CMD=$(which lz4 2>/dev/null || echo "")

        if [ -x "${LZ4_CMD}" ]; then
            "${LZ4_CMD}" -f "${IMAGE_FOUND}" "${KERNEL_BAZEL_DIST_OUT}/Image.lz4"
            echo "  -> Created Image.lz4"
        else
             echo "  Warning: lz4 tool not found. Image.lz4 output missing!"
        fi
    else
        echo "  Warning: neither Image.lz4 nor Image found in dist!"
    fi
fi

echo ""
if [ ${#MISSING_MODULES[@]} -ne 0 ]; then
    echo "========================================================"
    echo "WARNING: The following modules were NOT found in the build output:"
    for mod in "${MISSING_MODULES[@]}"; do
        echo "  - ${mod}"
    done
    echo "========================================================"
fi
echo ""

echo "Build complete! Outputs in: ${KERNEL_BAZEL_DIST_OUT}"
