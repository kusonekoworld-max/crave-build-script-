#!/bin/bash

set -o pipefail
BUILD_LOG="build.log"

if [ ! -f ".env" ]; then
    echo "⚠️ .env file not found!"
    DEVICE="creek"
    BUILD_TYPE="userdebug"
fi

set -o allexport
source .env
set +o allexport

print_step() {
    echo "----------------------------------------------------"
    echo "${1}"
    echo ""
}

print_exit() {
    telegram_reply "$1"
    echo "$1"
    exit 1
}

telegram_send() {
    BUILD_HISTORY="🌏 _$(date +"%d %b %Y %I:%M %p GST")_
${1}"
    local response
    response=$(curl -sS -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${BUILD_HISTORY}")
    TG_MSG_ID=$(echo "$response" | grep -o '"message_id":[0-9]*' | cut -d: -f2)
    export ID
}

telegram_edit() {
    [ -z "$ID" ] && { telegram_send "${1}"; return; }
    export BUILD_HISTORY="${BUILD_HISTORY}

🌏 _$(date +"%d %b %Y %I:%M %p GST")_
${1}"
    curl -sS -X POST "https://api.telegram.org/bot${TG_TOKEN}/editMessageText" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "message_id=${ID}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${BUILD_HISTORY}" >/dev/null
}

telegram_reply() {
    local TEXT="🌏 _$(date +"%d %b %Y %I:%M %p GST")_
${1}"
    curl -sS -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "reply_parameters={\"message_id\":${ID}}" \
        --data-urlencode "text=${TEXT}" >/dev/null
}

telegram_send_document() {
    local file_path="${1}"
    local caption="${2}"
    curl -sS -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendDocument" \
        -F "chat_id=${TG_CHAT}" \
        -F "document=@${file_path}" \
        -F "parse_mode=Markdown" \
        -F "reply_parameters={\"message_id\":${ID}}" \
        -F "caption=${caption}" >/dev/null
}

if ! command -v jq &> /dev/null; then
    mkdir -p ~/bin
    curl -L -o ~/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux64
    chmod +x ~/bin/jq
    export PATH=$HOME/bin:$PATH
fi

pixeldrain_upload() {
    local FILE="${1}"
    if [ -f "$FILE" ]; then
        RESPONSE=$(curl -s -u ":$PIXELDRAIN" -T "$FILE" https://pixeldrain.com/api/file/)
        FILE_ID=$(echo "$RESPONSE" | jq -r '.id')
        if [[ "$FILE_ID" != "null" && -n "$FILE_ID" ]]; then
            curl -s -u ":$PIXELDRAIN" -X POST "https://pixeldrain.com/api/file/$FILE_ID/publicity" \
                 -H "Content-Type: application/json" -d '{"public": true}' > /dev/null
            PD_URL="https://pixeldrain.com/u/$FILE_ID"
            echo "${PD_URL}"
            return 0
        else
            echo "PixelDrain API Error response: $RESPONSE" >&2
        fi
    else
        echo "Error: Target file $FILE not found." >&2
    fi
    return 1
}

sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/${TZ} /etc/localtime

telegram_edit "${DEVICE} DerpFest Build started"
START_TIME=$(date +%s)

export BUILD_USERNAME="${BUILD_USERNAME}"
export BUILD_HOSTNAME="${BUILD_HOSTNAME}"
export SKIP_ABI_CHECKS=true

# ====== Cleanup (local_manifests TIDAK dihapus) ======
print_step "Performing safe compilation cleanup..."
remove=(
    device/xiaomi/creek
    vendor/xiaomi/creek
    device/xiaomi/creek-kernel
)
for FILE in "${remove[@]}"; do
    [ -e "$FILE" ] && echo "    Removing: $FILE"
    rm -rf "$FILE"
done

# ====== Sync source (pakai local_manifests yang udah ada) ======
print_step "resync the source and device tree"
/opt/crave/resync.sh
if [ $? -ne 0 ]; then
    print_exit "Crave sync failed. Exiting."
fi

# ====== Build ======
print_step "setting up build environment"
source build/envsetup.sh

print_step "lunch"
lunch lineage_${DEVICE}-bp4a-user
if [ $? -ne 0 ]; then
    print_exit "Lunch failed. Exiting."
fi

print_step "building derpfest"
make installclean
mka derp 2>&1 | tee "$BUILD_LOG"

END_TIME=$(date +%s)
BUILD_DIFF=$((END_TIME - START_TIME))
if [ $BUILD_DIFF -ge 3600 ]; then
    BUILD_TIME="$((BUILD_DIFF/3600))h $(((BUILD_DIFF%3600)/60))min"
else
    BUILD_TIME="$((BUILD_DIFF/60)) min"
fi

if grep -q -E "ninja failed|failed to build some targets" "$BUILD_LOG"; then
    telegram_reply "💥 *Build failed*

Took ${BUILD_TIME}"
    exit 0
else
    COMPLETE_TEXT="╒═══════════════════╕
            ◐ *Build Completed* ◑   
└───────────────────┘

Took ${BUILD_TIME}
"
    ROM_DIR="out/target/product/${DEVICE}/"
    ZIP_FILE=$(ls "$ROM_DIR" | grep "${ROM_NAME}-.*-${DEVICE}.zip$" | tail -n 1)

    if [ -n "${ZIP_FILE}" ]; then
        ROM_PATH="${ROM_DIR}/${ZIP_FILE}"
        echo "Uploading ROM file to PixelDrain: ${ZIP_FILE}..."
        PD_URL=$(pixeldrain_upload "$ROM_PATH")
        UPLOAD_STATUS=$?

        if [ $UPLOAD_STATUS -eq 0 ] && [[ "$PD_URL" == http* ]]; then
            FILES_TEXT="╭─ Files
• [${ROM_NAME}-${ROM_VERSION}](${PD_URL})"
            telegram_reply "${COMPLETE_TEXT}
${FILES_TEXT}"
        else
            telegram_reply "${COMPLETE_TEXT}

Failed to upload ROM to PixelDrain."
        fi
    else
        telegram_reply "${COMPLETE_TEXT}

ROM file matching ${ROM_NAME} not found in ${ROM_DIR}."
    fi
fi