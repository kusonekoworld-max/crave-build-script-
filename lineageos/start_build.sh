#!/bin/bash

clear

# Define some requirements
export BUILD_USERNAME="thas-k"
export BUILD_HOSTNAME="creek"
export TARGET_UNOFFICIAL_BUILD_ID="thas-k"
export SKIP_ABI_CHECKS=true
export WITH_DEXPREOPT=true
export OTA_URL="https://xiaomicreek.github.io/OTA/LOS/builds/creek.json"

# remove device tree
rm -rf .repo/local_manifests
rm -rf device/xiaomi/creek
rm -rf device/xiaomi/creek-kernel
rm -rf vendor/xiaomi/creek

# re-initialize the lineage source
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1

#clone local manifest
git clone https://github.com/XiaomiCreek/android.git -b lineage-23.2 --depth=1 .repo/local_manifests

# resync the repo source
repo sync -j16 --force-sync

# extract vendor tree
curl -sfLo vendorextract.sh -z vendorextract.sh https://raw.githubusercontent.com/nuruszama/crave/creek/tools/vendorextract.sh
chmod +x vendorextract.sh
./vendorextract.sh

# dynamically inject features.mk into device tree
cat << EOF > device/xiaomi/creek/features.mk
# OTA url for future updates
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += lineage.updater.uri=${OTA_URL}

# Inherit FastCharge configurations
\$(call inherit-product, packages/apps/FastCharge/fastcharge.mk)

# Inherit FastCharge configurations
\$(call inherit-product, vendor/gapps/arm64/arm64-vendor.mk)
EOF

# setup build env
source build/envsetup.sh

# remove intermediates files with seapp
find out/soong/.intermediates -type d -name "*seapp*" -exec rm -rf {} +

# change modified date to make soong start again
touch device/xiaomi/creek/BoardConfig.mk

# prepare device menu
breakfast creek userdebug

# Clean staging dirs
make installclean

# start building
mka bacon

# Upload
echo "upload to gofile..."
ROM_DIR="out/target/product/creek/"
ZIP_FILE=$(ls "$ROM_DIR" | grep "lineage-.*-creek.zip$" | tail -n 1)
if [ -n "${ZIP_FILE}" ]; then
    curl -sfLo upload.sh -z upload.sh https://raw.githubusercontent.com/nuruszama/crave/creek/tools/GoFile-upload.sh
    chmod +x upload.sh ; ./upload.sh "${ROM_DIR}${ZIP_FILE}"
    echo "upload done!"
else
    echo "no zip found at out/ dir..."
    exit 1
fi
