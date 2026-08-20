#!/bin/bash

clear

# Define some requirements
export BUILD_USERNAME="thas-k"
export BUILD_HOSTNAME="creek"
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
curl -sfLo vendorextract.sh -z vendorextract.sh https://raw.githubusercontent.com/nuruszama/crave/creek/vendorextract.sh
chmod +x vendorextract.sh
./vendorextract.sh

# dynamically inject ota.mk into device tree
cat << EOF > device/xiaomi/creek/ota.mk
# Dynamically generated during build script execution
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += lineage.updater.uri=${OTA_URL}
EOF

# setup build env
source build/envsetup.sh

# prepare device menu
breakfast creek eng

# Clean intermediate cached system properties and staging dirs
rm -rf out/target/product/creek/system/build.prop
rm -rf out/target/product/creek/vendor/build.prop
rm -rf out/target/product/creek/obj/KERNEL_OBJ
make installclean

# start building
mka bacon
