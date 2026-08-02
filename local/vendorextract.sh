#!/bin/bash
echo ""
echo "extracting vendor tree"

# define directories
DEVICE_TREE="/home/creek/android/lineage/device/xiaomi/creek"
TOOLS="/home/creek/android/lineage/tools/extract-utils"
DUMP="/home/creek/android/lineage/device/xiaomi/creek-dump"

# get into device tree directory
cd "$DEVICE_TREE" || { echo  "Error: Cannot access device tree folder"; exit 1; }

# extract the vendor tree
export PATCHELF=$(which patchelf)
PYTHONPATH="$TOOLS" python3 ./extract-files.py "$DUMP"
