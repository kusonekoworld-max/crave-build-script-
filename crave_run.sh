#!/bin/bash

# ------ What this script can do?? ------
# Details coming soon.... be patient ;-)

# set pipelined command flow
set -o pipefail

BUILD_LOG="build.log"

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_step "⚠️ .env file not found!"
    # define 
    DEVICE="creek"
    BUILD_TYPE="user-debug"
fi

# Load your local secrets
set -o allexport
source .env
set +o allexport

# Defining the printing steps in terminal
print_step() {
    echo "----------------------------------------------------"
    echo "${1}"
    echo ""
}

# Send telegram message
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

    export ID
}

# Edit existing telegram message
telegram_edit() {

    [ -z "$ID" ] && {
        telegram_send "${1}"
        return
    }

    # Append new log entry
    export BUILD_HISTORY="${BUILD_HISTORY}

🌏 _$(date +"%d %b %Y %I:%M %p GST")_
${1}"

    curl -sS \
        -X POST \
        "https://api.telegram.org/bot${TG_TOKEN}/editMessageText" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "message_id=${ID}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${BUILD_HISTORY}" \
        >/dev/null
}

# reply to initial telegram message
telegram_reply() {
    local TEXT="🌏 _$(date +"%d %b %Y %I:%M %p GST")_
${1}"

    curl -sS \
        -X POST \
        "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "reply_parameters={\"message_id\":${ID}}" \
        --data-urlencode "text=${TEXT}" \
        >/dev/null
}

# Send a file document to telegram
telegram_send_document() {
    local file_path="${1}"
    local caption="${2}"

    curl -sS \
        -X POST \
        "https://api.telegram.org/bot${TG_TOKEN}/sendDocument" \
        -F "chat_id=${TG_CHAT}" \
        -F "document=@${file_path}" \
        -F "parse_mode=Markdown" \
        -F "reply_parameters={\"message_id\":${ID}}" \
        -F "caption=${caption}" \
        >/dev/null
}

# checking JQ and install if it is absent
if ! command -v jq &> /dev/null; then
    mkdir -p ~/bin
    curl -L -o ~/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux64
    chmod +x ~/bin/jq
    export PATH=$HOME/bin:$PATH
fi

# defining pixel drain uploads
pixeldrain_upload() {
    local FILE="${1}"

    if [ -f "$FILE" ]; then
        RESPONSE=$(curl -s -u ":$PIXELDRAIN" -T "$FILE" https://pixeldrain.com/api/file/)
        FILE_ID=$(echo "$RESPONSE" | jq -r '.id')

        if [[ "$FILE_ID" != "null" && -n "$FILE_ID" ]]; then
            # Mark file public
            curl -s -u ":$PIXELDRAIN" -X POST "https://pixeldrain.com/api/file/$FILE_ID/publicity" \
                 -H "Content-Type: application/json" \
                 -d '{"public": true}' > /dev/null
                 
            PD_URL="https://pixeldrain.com/u/$FILE_ID"
            echo "${PD_URL}"
            return 0  # Explicitly return success
        else
            # Print the raw error to standard error log so it shows up on your Crave console
            echo "PixelDrain API Error response: $RESPONSE" >&2
        fi
    else
        echo "Error: Target file $FILE not found." >&2
    fi

    return 1
}

# change local timezone to dev's
sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/${TZ} /etc/localtime

telegram_edit "${DEVICE} Build started"
START_TIME=$(date +%s)

export BUILD_USERNAME="${BUILD_USERNAME}"
export BUILD_HOSTNAME="${BUILD_HOSTNAME}"
export SKIP_ABI_CHECKS=true
export LINEAGE_UPDATER_URI="${OTA_URL}"

# Automatic cleanup to update tree changes
print_step "Performing safe compilation cleanup..."
remove=(
    .repo/local_manifests
    device/xiaomi/creek
    vendor/xiaomi/creek
)

# Efficiently remove all of them
for FILE in "${remove[@]}"; do
    [ -e "$FILE" ] && echo "    Removing: $FILE"
    rm -rf "$FILE"
done

# Initialize the ROM source repository
print_step "repo init"
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1
if [ $? -ne 0 ]; then
    text="Repo initialization failed. Exiting."
    telegram_reply "${text}"
    echo "${text}"
    exit 1
fi

# Clone or update local manifests
print_step "Cloning local manifests..."
git clone https://github.com/XiaomiCreek/LineageOS.git -b 16 .repo/local_manifests --depth=1 --quiet
if [ $? -ne 0 ]; then
    text="Failed to setup local manifests. Exiting."
    telegram_reply "${text}"
    echo "${text}"
    exit 1
fi

# Sync the repositories using the Crave sync script
print_step "resync the source and device tree"
/opt/crave/resync.sh
if [ $? -ne 0 ]; then
    text="Crave sync failed. Exiting."
    telegram_reply "${text}"
    echo "${text}"
    exit 1
fi

# Build environment setup
print_step "setting up build environment"
source build/envsetup.sh

# Build the ROM
print_step "setting up breakfast"
breakfast ${DEVICE} ${BUILD_TYPE}
if [ $? -ne 0 ]; then
    text="Breakfast failed. Exiting."
    telegram_reply "${text}"
    echo "${text}"
    exit 1
fi

print_step "baconing the rom hot"
make installclean
m bacon 2>&1 | tee "$BUILD_LOG"

END_TIME=$(date +%s)
BUILD_DIFF=$((END_TIME - START_TIME))
if [ $BUILD_DIFF -ge 3600 ]; then
    BUILD_TIME="$((BUILD_DIFF/3600))h $(((BUILD_DIFF%3600)/60))min"
else
    BUILD_TIME="$((BUILD_DIFF/60)) min"
fi

# what if build fails?
if grep -q -E "ninja failed|failed to build some targets" "$BUILD_LOG"; then
    telegram_reply "💥 *Build failed*
    
Took ${BUILD_TIME}"
    exit 0
else

# managing things if build succeed
    COMPLETE_TEXT="╒═══════════════════╕
            ◐ *Build Completed* ◑   
└───────────────────┘

Took ${BUILD_TIME}
"

    # Upload ROM zip file to PixelDrain
    # Define the target directory
    ROM_DIR="out/target/product/${DEVICE}/"
    ZIP_FILE=$(ls "$ROM_DIR" | grep "${ROM_NAME}-.*-${DEVICE}.zip$" | tail -n 1)
    REC_FILE="recovery.img"

    # Check if we actually found a matching zip file
    if [ -n "${ZIP_FILE}" ]; then
        ROM_PATH="${ROM_DIR}/${ZIP_FILE}"
        REC_PATH="${ROM_DIR}/${REC_FILE}"
        
        echo "Uploading ROM file to PixelDrain: ${ZIP_FILE}..."

        # Call custom pixeldrain upload function and capture the output URL directly
        PD_URL=$(pixeldrain_upload "$ROM_PATH")
        UPLOAD_STATUS=$?
        
        if [ $UPLOAD_STATUS -eq 0 ] && [[ "$PD_URL" == http* ]]; then
            echo "ROM uploaded successfully to PixelDrain!"
            echo "URL: ${PD_URL}"

            # Start building the files block with the ROM zip entry
            FILES_TEXT="╭─ Files
• [${ROM_NAME}-${ROM_VERSION}](${PD_URL})"

            # Path to the compiler's auto-generated JSON
            OTA_JSON="out/target/product/${DEVICE}/${DEVICE}.json"

            if [ -f "$OTA_JSON" ]; then
                # Send the clean document file to the group chat
                CAPTION="🚀 *OTA Update Configuration File for ${DEVICE}*"
                telegram_send_document "$OTA_JSON" "$CAPTION"
            else
                # Fallback warning if build output tree context path is missing
                telegram_reply "⚠️ ${DEVICE}.json not found."
            fi
            
            # Start recovery upload
            REC_URL=""
            if [ -f "$REC_PATH" ]; then
                echo "Uploading recovery.img to PixelDrain..."
                PD_REC_URL=$(pixeldrain_upload "$REC_PATH")
                
                if [ $? -eq 0 ] && [ -n "$PD_REC_URL" ]; then
                    echo "Recovery uploaded successfully to PixelDrain!"
                    REC_URL="$PD_REC_URL"
                    # Dynamically add the recovery line if upload succeeded
                    FILES_TEXT="${FILES_TEXT}
• [recovery.img](${PD_REC_URL})"
                else
                    echo "Recovery upload failed, falling back to Telegram group link."
                fi
                
            else
                echo "recovery.img not found in ${ROM_DIR}. Skipping recovery upload."
            fi

            # Append the screenshots or channel link at the end of the block
            FILES_TEXT="${FILES_TEXT}
• [screenshots](https://t.me/los_creek)"

            telegram_reply "${COMPLETE_TEXT}
${FILES_TEXT}"

        else
            text="

Failed to upload ROM to PixelDrain.
Check your network or credentials."
            telegram_reply "${COMPLETE_TEXT}${text}"
        fi
    else
        text="ROM file matching ${ROM_NAME} not found in ${ROM_DIR}. Upload skipped."
        telegram_reply "${COMPLETE_TEXT}${text}"
    fi
fi

# Script ends here.. Thanks for checking it...
