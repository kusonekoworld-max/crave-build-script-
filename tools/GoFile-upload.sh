#!/usr/bin/env bash

# Check if file argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_file>" >&2
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

# Fetch available server
SERVER=$(curl -s https://api.gofile.io/servers | jq -r '.data.servers[0].name')

if [ -z "$SERVER" ] || [ "$SERVER" == "null" ]; then
    echo "Error: Failed to fetch active Gofile server."
    exit 1
fi

# Upload file via multipart form-data
RESPONSE=$(curl --progress-bar -F "file=@$FILE" "https://${SERVER}.gofile.io/contents/uploadfile")

# Output response link using command substitution
DOWNLOAD_LINK=$(echo "$RESPONSE" | jq -r '.data.downloadPage')
TEXT="📦 *Build Uploaded Successfully!*%0A*File:* \`${FILENAME}\`%0A*Download Link:* ${DOWNLOAD_LINK}"

echo ""
echo "Download Link: $DOWNLOAD_LINK"
echo ""

# Send telegram notification
if [ ! -f ".env" ]; then
    echo "⚠️ .env file not found!"
    exit 1
fi

# Export all variables from .env automatically
set -a
source .env
set +a

# Send Telegram notification
if [[ -n "$TG_TOKEN" && -n "$TG_CHAT" ]]; then
    echo "Notifying on Telegram..."

    # Ensure TG_TOKEN doesn't duplicate the "bot" prefix
    BOT_TOKEN="${TG_TOKEN#bot}"

    curl -sS \
        -X POST \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${TEXT}" > /dev/null
fi