#!/bin/bash

# Get the Android build top directory
if [ -z "$ANDROID_BUILD_TOP" ]; then
    ANDROID_BUILD_TOP="$(pwd)"
fi

git clone -b missi-user-16-BP2A.250605.031.A3-OS3.0.302.0.WBOMIXM-release-keys https://github.com/XiaomiCreek/redmi_creek_dump.git --depth=1 device/xiaomi/device-dump

echo ""
echo "extracting vendor tree"
echo ""

# define directories
DEVICE_TREE="$ANDROID_BUILD_TOP/device/xiaomi/creek"
TOOLS="$ANDROID_BUILD_TOP/tools/extract-utils"
DUMP="$ANDROID_BUILD_TOP/device/xiaomi/creek-dump"

# Run inside a subshell so cd doesn't affect the caller's environment
(
    cd "$DEVICE_TREE" || exit 1
    export PATCHELF=$(which patchelf)
    PYTHONPATH="$TOOLS" python3 ./extract-files.py "$DUMP"
)

# Capture exit status of the subshell
if [ $? -eq 0 ]; then
    echo ""
    echo "extraction completed successfully"
    echo ""
else
    echo ""
    echo "Error: Vendor extraction failed!"
    echo ""
    exit 1
fi
