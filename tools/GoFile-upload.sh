#!/usr/bin/env bash

# Check if file argument is provided
if [ -z "$1" ]; then
    echo "Usage: ./upload.sh <file_path>"
    exit 1
fi

FILE="$1"

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found."
    exit 1
fi

FILENAME=$(basename "$FILE")

echo "Uploading $FILENAME..."

# Upload using curl to transfer.sh
RESPONSE=$(curl --progress-bar --upload-file "$FILE" "https://transfer.sh/$FILENAME")

echo ""
echo "=========================================="
echo " Upload Complete!"
echo " Download Link: $RESPONSE"
echo "=========================================="
