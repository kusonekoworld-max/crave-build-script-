#!/bin/bash

# Get the Android build top directory
if [ -z "$ANDROID_BUILD_TOP" ]; then
    ANDROID_BUILD_TOP="$(pwd)"
fi

echo ""
echo "extracting vendor tree"
echo ""

# define directories
DEVICE_TREE="$ANDROID_BUILD_TOP/device/xiaomi/creek"
TOOLS="$ANDROID_BUILD_TOP/tools/extract-utils"
DUMP="$ANDROID_BUILD_TOP/device/xiaomi/creek-dump"

# get into device tree directory
cd "$DEVICE_TREE" || { echo  "Error: Cannot access device tree folder"; exit 1; }

# extract the vendor tree
export PATCHELF=$(which patchelf)
PYTHONPATH="$TOOLS" python3 ./extract-files.py "$DUMP"

echo ""
echo "extraction completed"
echo ""
