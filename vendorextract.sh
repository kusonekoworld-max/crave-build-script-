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

# Verify device tree folder exists
if [ ! -d "$DEVICE_TREE" ]; then
    echo "Error: Cannot access device tree folder at $DEVICE_TREE"
    exit 1
fi

# extract the vendor tree directly using absolute paths
export PATCHELF=$(which patchelf)
PYTHONPATH="$TOOLS:$DEVICE_TREE" python3 "$DEVICE_TREE/extract-files.py" "$DUMP"

echo ""
echo "extraction completed"
echo ""
