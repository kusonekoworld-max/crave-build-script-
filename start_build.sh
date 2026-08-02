#!/bin/bash

# remove leftover
clear
rm -rf "creek_build_*.log"
rm -rf "extract_*.log"

# Define some requirements
BUILD_DIR="/home/creek/android/lineage"
BUILD_LOG="creek_build_$(date +%s).log"
export BUILD_USERNAME="a.s.k"
export BUILD_HOSTNAME="thaz"
export SKIP_ABI_CHECKS=true
export WITH_DEXPREOPT=true

# remove device tree
rm -rf device/xiaomi/creek
rm -rf device/xiaomi/creek-kernel
rm -rf vendor/xiaomi/creek

# re-initialize the lineage source
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1 

# resync the repo source
repo sync

# clone device dump repo
git clone https://github.com/XiaomiCreek/redmi_creek_dump.git -b missi-user-16-BP2A.250605.031.A3-OS3.0.302.0.WBOMIXM-release-keys /home/creek/android/lineage/device/xiaomi/creek-dump

# setup build env
source vendor_extract.sh 2>&1 | tee "extract_$(date +%s).log"
source build/envsetup.sh

# prepare device menu
breakfast creek userdebug

# remove staging directories
make installclean

# start building
m bacon 2>&1 | tee "$BUILD_LOG"
