#!/usr/bin/env bash

# Check if file argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_file>" >&2
    exit 1
fi

FILE="$1"

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found." >&2
    exit 1
fi

# Load .env for credentials
if [ ! -f ".env" ]; then
    echo "⚠️ .env file not found!" >&2
    exit 1
fi

# Export all variables from .env automatically
set -a
source .env
set +a

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    mkdir -p ~/bin
    curl -L -o ~/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux64
    chmod +x ~/bin/jq
    export PATH=$HOME/bin:$PATH
fi

FILENAME=$(basename "$FILE")
echo "Uploading $FILENAME to Buzzheavier..."

# Upload file to Buzzheavier via PUT
RESPONSE=$(curl --progress-bar -T "$FILE" "https://buzzheavier.com/$FILENAME")

# Extract link from header/body response
DOWNLOAD_LINK=$(echo "$RESPONSE" | jq -r '.url // .link // empty')

# Fallback: parse direct URL if output is raw HTML/text
if [ -z "$DOWNLOAD_LINK" ]; then
    DOWNLOAD_LINK=$(echo "$RESPONSE" | grep -o 'https://buzzheavier.com/[a-zA-Z0-9]*' | head -n 1)
fi

if [ -z "$DOWNLOAD_LINK" ]; then
    echo "Error: Upload failed!" >&2
    echo "Buzzheavier Response: $RESPONSE" >&2
    exit 1
fi

TEXT="📦 *Build Uploaded Successfully!*%0A*File:* \`${FILENAME}\`%0A*Download Link:* ${DOWNLOAD_LINK}"

echo ""
echo "Download Link: $DOWNLOAD_LINK"
echo ""

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