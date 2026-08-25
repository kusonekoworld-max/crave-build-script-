#!/bin/bash

# Define some requirements
export BUILD_USERNAME="thas-k"
export BUILD_HOSTNAME="creek"
export SKIP_ABI_CHECKS=true
export WITH_DEXPREOPT=true
export OTA_URL="https://xiaomicreek.github.io/OTA/PixelOS/builds/creek.json"

# remove device tree
rm -rf .repo/local_manifests

# re-initialize the lineage source
repo init -u https://github.com/PixelOS-AOSP/android_manifest.git -b sixteen-qpr2 --git-lfs --depth=1

#clone local manifest
git clone https://github.com/XiaomiCreek/android.git -b PixelOS-16 --depth=1 .repo/local_manifests

# resync the repo source
/opt/crave/resync.sh

# dynamically inject ota.mk into device tree
cat << EOF > device/xiaomi/creek/features.mk
# OTA url for future updates
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    lineage.updater.uri=${OTA_URL} \
    persist.ota.url=${OTA_URL}

# Inherit FastCharge configurations
$(call inherit-product, packages/apps/FastCharge/fastcharge.mk)
EOF

# setup build env
source build/envsetup.sh

# prepare device menu
breakfast creek userdebug

# Clean intermediate cached system properties and staging dirs
make installclean

# start building
m pixelos

# Upload
echo "uploading file..."
ROM_DIR="out/target/product/creek/"
ZIP_FILE=$(ls "$ROM_DIR" | grep "PixelOS-creek-*.zip$" | tail -n 1)
if [ -n "${ZIP_FILE}" ]; then
    curl -sfLo upload.sh -z upload.sh https://raw.githubusercontent.com/nuruszama/crave/creek/tools/pd-upload.sh
    chmod +x upload.sh ; ./upload.sh "${ROM_DIR}${ZIP_FILE}"
    echo "upload done!"
else
    echo "no zip found at out/ dir..."
    exit 1
fi
