#!/bin/bash

echo ""
echo "extracting vendor tree"
echo ""

# define directories
DEVICE_TREE="device/xiaomi/creek"
TOOLS="tools/extract-utils"
DUMP="device/xiaomi/creek-dump"

# get into device tree directory
cd "$DEVICE_TREE" || { echo  "Error: Cannot access device tree folder"; exit 1; }

# extract the vendor tree
export PATCHELF=$(which patchelf)
PYTHONPATH="$TOOLS" python3 ./extract-files.py "$DUMP"

echo ""
echo "extraction completed"
echo ""
