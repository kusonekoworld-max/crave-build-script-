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
rm -rf .repo/local_manifests/

# re-initialize the lineage source
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1

#clone local manifest
git clone https://github.com/nuruszama/LineageOS.git -b 16 --depth=1 .repo/local_manifests

# resync the repo source
repo sync -j16 --force-sync

# ROM source patches

color="\033[0;32m"
end="\033[0m"

echo "----------------------------------------------------"
echo -e "${color}Starting hardware HAL sync...${end}"
echo ""

# Define directories and their matching repo details
rm -rf hardware/qcom-caf/common
git clone --depth 1 -b lineage-23.2 https://github.com/sapphire-sm6225/android_hardware_qcom-caf_common.git hardware/qcom-caf/common

rm -rf hardware/qcom-caf/sm6225

git clone --depth 1 -b lineage-22.2-caf-sm6225 https://github.com/sapphire-sm6225/vendor_qcom_opensource_agm.git hardware/qcom-caf/sm6225/audio/agm

git clone --depth 1 -b 16-qpr2 https://github.com/XiaomiCreek/hardware_qcom-caf_sm6225_audio_pal.git hardware/qcom-caf/sm6225/audio/pal

git clone --depth 1 -b lineage-23.2-caf-sm6225 https://github.com/sapphire-sm6225/vendor_qcom_opensource_data-ipa-cfg-mgr.git hardware/qcom-caf/sm6225/data-ipa-cfg-mgr

git clone --depth 1 -b lineage-23.2-caf-sm6225 https://github.com/sapphire-sm6225/vendor_qcom_opensource_dataipa.git hardware/qcom-caf/sm6225/dataipa

git clone --depth 1 -b lineage-22.0-caf-sm6225 https://github.com/sapphire-sm6225/hardware_qcom_display.git hardware/qcom-caf/sm6225/display

git clone --depth 1 -b lineage-23.2-caf-sm6225 https://github.com/sapphire-sm6225/hardware_qcom_media.git hardware/qcom-caf/sm6225/media

git clone --depth 1 -b 16-qpr2 https://github.com/XiaomiCreek/hardware_qcom-caf_sm6225_audio_primary-hal.git hardware/qcom-caf/sm6225/audio/primary-hal

rm -rf device/qcom/sepolicy_vndr/sm6225
git clone --depth 1 -b 16-qpr2 https://github.com/XiaomiCreek/android_device_qcom_sepolicy_vndr_sm6225.git device/qcom/sepolicy_vndr/sm6225

rm -rf vendor/lineage
git clone --depth 1 -b lineage-23.2 https://github.com/sapphire-sm6225/android_vendor_lineage.git vendor/lineage

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
