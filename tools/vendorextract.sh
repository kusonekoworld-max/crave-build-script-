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
DUMP="$ANDROID_BUILD_TOP/device/xiaomi/creek-dump-3.0.302"

# Check whether device dump exists; clone if missing
if [ ! -d "$DUMP" ]; then
    echo "Dump directory not found. Cloning firmware dump..."
    git clone -b missi-user-16-BP2A.250605.031.A3-OS3.0.302.0.WBOMIXM-release-keys https://github.com/XiaomiCreek/redmi_creek_dump.git --depth=1 "$DUMP"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone dump repository!"
        exit 1
    fi
else
    echo "Dump directory found at $DUMP. Skipping clone."
fi

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
