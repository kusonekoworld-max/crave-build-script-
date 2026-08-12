#!/bin/bash

# remove leftover
clear
rm -rf extract_log.txt

# Define some requirements
BUILD_DIR="/home/creek/android/lineage"
BUILD_LOG="creek_build_$(date +%s).log"

export BUILD_USERNAME="a.s.k"
export BUILD_HOSTNAME="thazz"
export SKIP_ABI_CHECKS=true
export WITH_DEXPREOPT=true

# remove device tree
rm -rf vendor/lineage
rm -rf hardware/qcom-caf/common
rm -rf device/xiaomi/creek
rm -rf device/xiaomi/creek-kernel
rm -rf vendor/xiaomi/creek
rm -rf device/xiaomi/sepolicy
rm -rf .repo/local_manifests

# re-initialize the lineage source
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1

#clone local manifest
git clone https://github.com/XiaomiCreek/LineageOS.git -b 16 --depth=1 .repo/local_manifests

# resync the repo source
repo sync -j16 --force-sync

# extract vendor tree
source vendorextract.sh 2>&1 | tee "extract_log.txt"

# setup build env
source build/envsetup.sh

# prepare device menu
breakfast creek eng

# remove staging directories
make installclean

# start building
m bacon -j24 2>&1 | tee "$BUILD_LOG"
