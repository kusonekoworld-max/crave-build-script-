#!/bin/bash
set -e

clear

# Reset all local modifications and delete untracked/generated files
# (skip if this is a fresh workspace with no .repo yet)
if [ -d .repo ]; then
    repo forall -c "git reset --hard HEAD"
    repo forall -c "git clean -fd"
fi

# Maintainer and Host Info
export BUILD_USERNAME="kusonekoworld"
export BUILD_HOSTNAME="creek"

# Custom Build Tag
export TARGET_UNOFFICIAL_BUILD_ID="DerpFest-Edition"

# Build Optimizations & Checks
export SKIP_ABI_CHECKS=true
export WITH_DEXPREOPT=true

# remove local manifest
rm -rf .repo/local_manifests

# re-initialize the DerpFest source
repo init -u https://github.com/DerpFest-AOSP/android_manifest.git -b 16.2 --git-lfs

# fetch local manifest (single file, not a repo)
mkdir -p .repo/local_manifests
curl -sfLo .repo/local_manifests/local_manifest.xml \
    https://raw.githubusercontent.com/XiaomiCreek/android/lineage-23.2/local_manifest.xml

# resync the repo source
repo sync -j16 --force-sync

# setup build env
source build/envsetup.sh

# remove intermediates files with seapp (safe if out/ doesn't exist yet)
find out/soong/.intermediates -type d -name "*seapp*" -exec rm -rf {} + 2>/dev/null || true

# change modified date to make soong start again
touch device/xiaomi/creek/BoardConfig.mk

# prepare device menu
lunch lineage_creek-bp4a-user

# Clean staging dirs
make installclean

# start building
mka derp

# Upload
echo "upload to gofile..."
ROM_DIR="out/target/product/creek/"
ZIP_FILE=$(ls "$ROM_DIR" | grep "DerpFest-.*-creek.zip$" | tail -n 1)
if [ -n "${ZIP_FILE}" ]; then
    curl -sfLo upload.sh -z upload.sh https://raw.githubusercontent.com/kusonekoworld-max/crave-build-script-/creek/tools/GoFile-upload.sh
    chmod +x upload.sh ; ./upload.sh "${ROM_DIR}${ZIP_FILE}"
    echo "upload done!"
else
    echo "no zip found at out/ dir..."
    exit 1
fi
