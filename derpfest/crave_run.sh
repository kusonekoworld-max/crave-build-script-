#!/bin/bash

set -e

clear

echo "=========================================="
echo "   DerpFest 16.2 - Xiaomi Creek Builder"
echo "=========================================="

# ==========================================
# CONFIG
# ==========================================

export BUILD_USERNAME="kusonekoworld"
export BUILD_HOSTNAME="creek"

export TARGET_UNOFFICIAL_BUILD_ID="DerpFest-Edition"

export SKIP_ABI_CHECKS=true
export WITH_DEXPREOPT=true

DEVICE="creek"
LUNCH_TARGET="derp_creek-userdebug"

MANIFEST_URL="https://github.com/DerpFest-AOSP/android_manifest.git"
MANIFEST_BRANCH="16.2"

LOCAL_MANIFEST_URL="https://github.com/kusonekoworld-max/local_manifests1.git"
LOCAL_MANIFEST_BRANCH="main"

ROM_DIR="out/target/product/${DEVICE}"

# ==========================================
# CHECK REQUIRED COMMANDS
# ==========================================

echo "[*] Checking required commands..."

for cmd in repo git curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[!] Missing command: $cmd"
        exit 1
    fi
done

# ==========================================
# CLEAN OLD LOCAL MANIFEST
# ==========================================

echo "[*] Removing old local manifests..."

rm -rf .repo/local_manifests

# ==========================================
# INIT DERPFEST
# ==========================================

echo "[*] Initializing DerpFest 16.2..."

repo init \
    -u "$MANIFEST_URL" \
    -b "$MANIFEST_BRANCH" \
    --git-lfs \
    --depth=1

# ==========================================
# CLONE LOCAL MANIFEST
# ==========================================

echo "[*] Installing creek local manifest..."

git clone \
    "$LOCAL_MANIFEST_URL" \
    -b "$LOCAL_MANIFEST_BRANCH" \
    --depth=1 \
    .repo/local_manifests

# ==========================================
# SYNC SOURCE
# ==========================================

echo "[*] Syncing source..."

repo sync \
    -c \
    --force-sync \
    --no-clone-bundle \
    --no-tags \
    -j16

# ==========================================
# CHECK DEVICE TREE
# ==========================================

echo
echo "=========================================="
echo "Checking creek source"
echo "=========================================="

FOUND=0

for dir in \
    "device/xiaomi/creek" \
    "vendor/xiaomi/creek" \
    "kernel/xiaomi/creek" \
    "kernel/xiaomi/sm6225"; do

    if [ -d "$dir" ]; then
        echo "[OK] $dir"
        FOUND=1
    else
        echo "[--] $dir"
    fi

done

if [ "$FOUND" -eq 0 ]; then
    echo
    echo "[!] ERROR:"
    echo "    Creek device source was not found."
    echo "    Check .repo/local_manifests."
    exit 1
fi

# ==========================================
# BUILD ENVIRONMENT
# ==========================================

echo
echo "[*] Loading build environment..."

source build/envsetup.sh

# ==========================================
# LUNCH
# ==========================================

echo
echo "[*] Selecting target:"
echo "    $LUNCH_TARGET"
echo

lunch "$LUNCH_TARGET"

# ==========================================
# VERIFY TARGET
# ==========================================

if [ "$TARGET_PRODUCT" != "derp_creek" ]; then
    echo
    echo "[!] Wrong TARGET_PRODUCT:"
    echo "    $TARGET_PRODUCT"
    exit 1
fi

echo
echo "[OK] TARGET_PRODUCT=$TARGET_PRODUCT"
echo "[OK] TARGET_BUILD_VARIANT=$TARGET_BUILD_VARIANT"
echo

# ==========================================
# OPTIONAL CLEAN
# ==========================================

echo "[*] Cleaning previous installation output..."

if [ -d "out" ]; then
    make installclean
fi

# ==========================================
# BUILD
# ==========================================

echo
echo "=========================================="
echo "Starting DerpFest build"
echo "=========================================="
echo

mka derp

# ==========================================
# FIND ROM
# ==========================================

echo
echo "=========================================="
echo "Searching for ROM ZIP"
echo "=========================================="

if [ ! -d "$ROM_DIR" ]; then
    echo "[!] ROM directory does not exist:"
    echo "    $ROM_DIR"
    exit 1
fi

ZIP_FILE=""

while IFS= read -r file; do
    ZIP_FILE="$file"
    break
done < <(
    find "$ROM_DIR" \
        -maxdepth 1 \
        -type f \
        -iname "*.zip" \
        -printf "%T@ %p\n" 2>/dev/null |
    sort -nr |
    cut -d' ' -f2-
)

if [ -z "$ZIP_FILE" ]; then
    echo
    echo "[!] No ROM ZIP found."
    echo
    echo "Files in output directory:"
    ls -lah "$ROM_DIR"
    exit 1
fi

echo
echo "[OK] ROM found:"
echo "     $ZIP_FILE"
echo

# ==========================================
# UPLOAD TO GOFILE
# ==========================================

echo "=========================================="
echo "Uploading ROM to GoFile"
echo "=========================================="

curl -sfLo upload.sh \
    -z upload.sh \
    "https://raw.githubusercontent.com/kusonekoworld-max/crave-build-script-/creek/tools/GoFile-upload.sh"

chmod +x upload.sh

./upload.sh "$ZIP_FILE"

echo
echo "=========================================="
echo "          BUILD COMPLETED"
echo "=========================================="
echo
echo "ROM:"
echo "$ZIP_FILE"
echo
echo "Upload completed."
echo
