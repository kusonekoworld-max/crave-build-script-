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
git clone https://github.com/XiaomiCreek/android.git -b 16 --depth=1 .repo/local_manifests

# resync the repo source
repo sync -j16 --force-sync

# extract vendor tree
curl -sfLo vendorextract.sh -z vendorextract.sh https://raw.githubusercontent.com/nuruszama/crave/creek/tools/vendorextract.sh
chmod +x vendorextract.sh
./vendorextract.sh

# dynamically inject features.mk into device tree
cat << EOF > device/xiaomi/creek/features.mk
# OTA url for future updates
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    lineage.updater.uri=${OTA_URL}

# Inherit FastCharge configurations
$(call inherit-product, packages/apps/FastCharge/fastcharge.mk)

# Inherit FastCharge configurations
$(call inherit-product, vendor/gapps/arm64/arm64-vendor.mk)
EOF

# setup build env
source build/envsetup.sh

#
find out/soong/.intermediates -type d -name "*seapp*" -exec rm -rf {} +

# 
touch device/xiaomi/creek/BoardConfig.mk

# prepare device menu
breakfast creek userdebug

# Clean intermediate cached system properties and staging dirs
rm -rf out/target/product/creek/system/build.prop
rm -rf out/target/product/creek/vendor/build.prop
rm -rf out/target/product/creek/obj/KERNEL_OBJ
make installclean

# start building
mka bacon

# Upload
echo "upload to gofile..."
if [ -f out/target/product/creek/lineage*.zip ]; then
    curl -sfLo upload.sh -z upload.sh https://raw.githubusercontent.com/nuruszama/crave/creek/tools/GoFile-upload.sh
    chmod +x upload.sh ; ./upload.sh out/target/product/earth/*.zip
    echo "upload done!"
else
    echo "no zip found at out/ dir..."
    exit 1
fi
