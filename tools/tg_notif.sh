#!/usr/bin/env bash

# Check if file argument is provided
if [ -z "$1" ]; then
    echo "Usage: ./tg_notif.sh <message>"
    exit 1
fi

MESSAGE="$1"

# Check if file exists
if [ ! -f .env ]; then
    echo "Error: Telegram tokens not found."
    exit 1
fi

source .env

curl -sS \
    -X POST \
    "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TG_CHAT}" \
    --data-urlencode "parse_mode=Markdown" \
    --data-urlencode "disable_web_page_preview=true" \
    --data-urlencode "text=${MESSAGE}" \
    >/dev/null

echo ""
echo "download url shared over telegram"
echo ""