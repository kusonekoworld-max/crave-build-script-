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
echo " Upload Complete!"
echo " Download Link: $RESPONSE"
echo ""

# send telegram notification
if [ ! -f ".env" ]; then
    echo "⚠️ .env file not found!"
    exit 1
fi

echo ""
echo "notifying on telegram"
source .env
curl -sS \
    -X POST \
    "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TG_CHAT}" \
    --data-urlencode "parse_mode=Markdown" \
    --data-urlencode "disable_web_page_preview=true" \
    --data-urlencode "text=Download Link: $RESPONSE" \
    >/dev/null
