#!/bin/bash

# set pipelined command flow
set -o pipefail

# Shared state
: "${TG_MSG_ID:=}"
BUILD_HISTORY=""
BUILD_LOG="build.log"

OUT_DIR="out/target/product/${DEVICE}"
START_TIME=$(date +%s)

# Send first message
telegram_send() {
    # Append new log entry
    BUILD_HISTORY="🌏 _$(date +"%d %b %Y %I:%M %p GST")_
${1}"
    
    local response
    response=$(curl -sS \
        -X POST \
        "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${BUILD_HISTORY}")

    TG_MSG_ID=$(echo "$response" | grep -o '"message_id":[0-9]*' | cut -d: -f2)

    export TG_MSG_ID
}

# Edit existing message
telegram_edit() {

    [ -z "$TG_MSG_ID" ] && {
        telegram_send "${1}"
        return
    }

    # Append new log entry
    BUILD_HISTORY="${BUILD_HISTORY}

🌏 _$(date +"%d %b %Y %I:%M %p GST")_
${1}"

    curl -sS \
        -X POST \
        "https://api.telegram.org/bot${TG_TOKEN}/editMessageText" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "message_id=${TG_MSG_ID}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${BUILD_HISTORY}" \
        >/dev/null
}

# ============================================================
# Send a reply linked directly to the main build card
# Does NOT overwrite active build message
# ============================================================
telegram_reply() {
    local TEXT="🌏 _$(date +"%d %b %Y %I:%M %p GST")_
${1}"

    curl -sS \
        -X POST \
        "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "reply_parameters={\"message_id\":${TG_MSG_ID}}" \
        --data-urlencode "text=${TEXT}" \
        >/dev/null
}

# Check if .env file exists
if [ ! -f ".env" ]; then
    text="⚠️ .env file not found!"
    echo "${text}"
    exit 1
fi

# Load your local secrets
set -o allexport
source .env
set +o allexport

# ================= TIMEZONE =================
sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/${TZ} /etc/localtime

telegram_edit "${DEVICE} Build started"

# ================= JQ =================
if ! command -v jq &> /dev/null; then
    mkdir -p ~/bin
    curl -L -o ~/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux64
    chmod +x ~/bin/jq
    export PATH=$HOME/bin:$PATH
fi

# ================= PIXELDRAIN =================
pixeldrain_upload() {
    local FILE="${1}"

    if [ -f "$FILE" ]; then
        RESPONSE=$(curl -s -u ":$PIXELDRAIN" -F "file=@$FILE" https://pixeldrain.com/api/file)
        FILE_ID=$(echo "$RESPONSE" | jq -r '.id')

        if [[ "$FILE_ID" != "null" && -n "$FILE_ID" ]]; then
            PD_URL="https://pixeldrain.com/u/$FILE_ID"
            echo "${PD_URL}"
            return
        fi
    fi

    return 1
}

# Automatic cleanup
echo "Performing cleanup..."
remove=(
    .repo/local_manifests
    hardware/qcom-caf/*
    vendor/lineage
    vendor/xiaomi/*
    vendor/gapps
    vendor/lineage-priv/keys
    device/xiaomi/*
    device/qcom/sepolicy_vndr/sm6225
)

# Efficiently remove all of them
for folder in "${remove[@]}"; do
    rm -rf "$folder"
    echo "    Cleaned: $folder"
done

# Initialize the ROM source repository
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs
if [ $? -ne 0 ]; then
    text="Repo initialization failed. Exiting."
    telegram_reply "${text}"
    echo "${text}"
    exit 1
fi
echo ""

# Clone local manifests
git clone https://github.com/nuruszama/local_manifest.git -b main .repo/local_manifests
if [ $? -ne 0 ]; then
    text="Failed to clone local manifests. Exiting."
    telegram_reply "${text}"
    echo "${text}"
    exit 1
fi
echo ""

# Sync the repositories using the Crave sync script
/opt/crave/resync.sh
if [ $? -ne 0 ]; then
    text="Crave sync failed. Exiting."
    telegram_reply "${text}"
    echo "${text}"
    exit 1
fi

# Build environment setup
source build/envsetup.sh
export BUILD_USERNAME="${BUILD_USERNAME}"
export BUILD_HOSTNAME="${BUILD_HOSTNAME}"
export SKIP_ABI_CHECKS=true
export LINEAGE_UPDATER_URI="${OTA_URL}"
mkdir -p out/target/product/${DEVICE}/obj/KERNEL_OBJ/usr

# Build the ROM
breakfast ${DEVICE} ${BUILD_TYPE}
if [ $? -ne 0 ]; then
    text="Breakfast failed. Exiting."
    telegram_reply "${text}"
    echo "${text}"
    exit 1
fi

make installclean
if [ $? -ne 0 ]; then
    text="Installclean failed. Exiting."
    telegram_reply "${text}"
    echo "${text}"
    exit 1
fi

mka bacon 2>&1 | tee "$BUILD_LOG"

END_TIME=$(date +%s)
BUILD_DIFF=$((END_TIME - START_TIME))
if [ $BUILD_DIFF -ge 3600 ]; then
    BUILD_TIME="$((BUILD_DIFF/3600))h $(((BUILD_DIFF%3600)/60))min"
else
    BUILD_TIME="$((BUILD_DIFF/60)) min"
fi

# ================= ON FAIL =================
if grep -q -E "ninja failed|failed to build some targets" "$BUILD_LOG"; then
    telegram_reply "💥 *Build failed*
    
Took ${BUILD_TIME}"
    echo "Build Failed!"
else
# ================= SUCCESS =================
    echo "Build completed!"
    COMPLETE_TEXT="╒═══════════════════╕
            ◐ *Build Completed* ◑   
└───────────────────┘

Took ${BUILD_TIME}
"

    # Upload ROM zip file to PixelDrain
    ROM_DIR="out/target/product/${DEVICE}/"
    ZIP_FILE=$(ls $ROM_DIR | grep "${$ROM_NAME}-${PROJECT_VERSION}-.*-UNOFFICIAL-${DEVICE}.zip$" | tail -n 1)

    if [ -n "$ROM_NAME" ]; then
        ROM_PATH="$ROM_DIR$ZIP_FILE"
        
        echo "Uploading ROM file to PixelDrain..."
        curl -T "$ROM_PATH" -u :${PIXELDRAIN} https://pixeldrain.com/api/file/
        if [ $? -eq 0 ]; then
            echo "ROM uploaded successfully to PixelDrain!"
            telegram_reply "${COMPLETE_TEXT}
╭─ Files
• [${$ROM_NAME}-${PROJECT_VERSION}](${PD_URL})
• [recovery.img](${https://t.me/los_creek})
• [screenshots](${https://t.me/los_creek})"
        else
            text="Failed to upload ROM to PixelDrain.
Check your network or credentials."
            telegram_reply "${COMPLETE_TEXT}${text}"
        fi
    else
        text="ROM file not found. Upload skipped."
        telegram_reply "${COMPLETE_TEXT}${text}"
    fi
fi

echo "
.....Script completed!....."
