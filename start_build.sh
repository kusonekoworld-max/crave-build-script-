#!/bin/bash

clear

# Define some requirements
export BUILD_USERNAME="a.s.k"
export BUILD_HOSTNAME="thazz"
export SKIP_ABI_CHECKS=true
export WITH_DEXPREOPT=true

# remove device tree
rm -rf .repo/local_manifests
rm -rf device/xiaomi/creek
rm -rf device/xiaomi/creek-kernel
rm -rf vendor/xiaomi/creek

# re-initialize the lineage source
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1

#clone local manifest
git clone https://github.com/XiaomiCreek/LineageOS.git -b 16 --depth=1 .repo/local_manifests

# resync the repo source
repo sync -j16 --force-sync

# extract vendor tree
curl -sfLo vendorextract.sh -z vendorextract.sh https://raw.githubusercontent.com/nuruszama/crave/creek/vendorextract.sh
chmod +x vendorextract.sh
./vendorextract.sh

# remove conflicting soong_namespace
rm -rf hardware/qcom-caf/sm6225/data-ipa-cfg-mgr/Android.bp

# setup build env
source build/envsetup.sh

# prepare device menu
breakfast creek eng

# remove staging directories
make installclean

# start building
m bacon -j24
