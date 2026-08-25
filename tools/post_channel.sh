#!/usr/bin/env bash

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found." >&2
    exit 1
fi

# Export variables from .env
set -a
source .env
set +a

# Clean TG_TOKEN
BOT_TOKEN="${TG_TOKEN#bot}"

# Determine message text (from file if it exists, otherwise from argument $1)
if [ -f "build_description.txt" ]; then
    MESSAGE=$(cat build_description.txt)
elif [ -n "$1" ]; then
    MESSAGE="$1"
else
    echo "Usage: $0 <message> [rom_url] [recovery_url]" >&2
    exit 1
fi

# Optional URLs passed as arguments $2 and $3, or set from environment
ROM_URL="${2:-$ROM_DOWNLOAD_URL}"
RECOVERY_URL="${3:-$RECOVERY_DOWNLOAD_URL}"

# Build the inline keyboard JSON dynamically based on available URLs
KEYBOARD_BUTTONS=()

if [ -n "$ROM_URL" ]; then
    KEYBOARD_BUTTONS+=("{\"text\": \" 📥 ROM\", \"url\": \"$ROM_URL\"}")
fi

if [ -n "$RECOVERY_URL" ]; then
    KEYBOARD_BUTTONS+=("{\"text\": \"⚡ Recovery\", \"url\": \"$RECOVERY_URL\"}")
fi

# Construct reply_markup payload if at least one link exists
REPLY_MARKUP=""
if [ ${#KEYBOARD_BUTTONS[@]} -gt 0 ]; then
    # Join buttons with commas inside a single inline keyboard row
    BUTTONS_JSON=$(IFS=,; echo "${KEYBOARD_BUTTONS[*]}")
    REPLY_MARKUP="{\"inline_keyboard\": [[ $BUTTONS_JSON ]]}"
fi

echo "Sending build update with buttons to ${TG_CHANNEL}..."

# Build base curl arguments
CURL_ARGS=(
    -sS -X POST
    --data-urlencode "chat_id=${TG_CHANNEL}"
    --data-urlencode "parse_mode=Markdown"
)

# Attach reply_markup if defined
if [ -n "$REPLY_MARKUP" ]; then
    CURL_ARGS+=(--data-urlencode "reply_markup=${REPLY_MARKUP}")
fi

# Send photo with caption or fall back to text message
if [ -n "${UPDATE_FILE_ID}" ]; then
    curl "${CURL_ARGS[@]}" \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendPhoto" \
        --data-urlencode "photo=${UPDATE_FILE_ID}" \
        --data-urlencode "caption=${MESSAGE}" >/dev/null
else
    curl "${CURL_ARGS[@]}" \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        --data-urlencode "text=${MESSAGE}" \
        --data-urlencode "disable_web_page_preview=true" >/dev/null
fi

echo ""
echo "Build update successfully posted to ${TG_CHANNEL}!"
echo ""