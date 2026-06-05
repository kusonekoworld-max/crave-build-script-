#!/bin/bash

# Optional: ensure we are in correct directory
cd "$(dirname "$0")"

# Check if .env file exists
if [ ! -f ".env" ]; then echo ".env file not found"
    exit 1
fi

# Load your local secrets
source .env

# ================= TIMEZONE =================
sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/${TZ} /etc/localtime

# Send first message
telegram_send() {
    # Append new log entry
    BUILD_HISTORY="🌏 _$(date +"%d %b %Y %I:%M %p GST")_
$1"
    
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
        telegram_send "$1"
        return
    }

    # Append new log entry
    BUILD_HISTORY="${BUILD_HISTORY}

🌏 _$(date +"%d %b %Y %I:%M %p GST")_
$1"

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
$1"

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

# set the container log file
LOG_FILE="crave_build.log"
rm -f "$LOG_FILE"

# ================= CRAVE QUEUE & RETRY LOGIC =================
MAX_ATTEMPTS=2
ATTEMPT=1
DELAY_TIME="1m" # 1 minutes delay
telegram_send "${DEVICE} Build Queued ~${ATTEMPT}..."
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do

    # Run the crave command
    crave run --projectID 93 --no-patch -- \
"export TG_MSG_ID='${TG_MSG_ID}'; \
curl -sf https://raw.githubusercontent.com/nuruszama/crave/main/crave_run.sh | bash" \
2>&1 | tee "$LOG_FILE"
    
    # Capture the pipeline status thanks to set -o pipefail
    CRAVE_STATUS=${PIPESTATUS[0]}

    if [ $CRAVE_STATUS -eq 0 ]; then
        break
        
    elif [ $CRAVE_STATUS -eq 130 ]; then
        # ⚠️ CANCELLED BY USER
        exit 1
        
    else
        echo "Rejected with exit code $CRAVE_STATUS."
        
        if [ ! -f "$LOG_FILE" ]; then
            ERROR_TEXT="Build script failed to start! Check the setup"
            telegram_edit "$ERROR_TEXT"
            exit 1
        fi

        if grep -q "Setting up workspace" "$LOG_FILE"; then
            # Case A: The container started fine, but compilation failed later. 
            # Do NOT retry automatically; you need to inspect actual build logs.
            break
        else
            # Case B: The container was rejected or dropped out before setting up.
            
            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                TERMINATION_TEXT="Retrying Build Queue ~$((ATTEMPT + 1))..."
                telegram_edit "$TERMINATION_TEXT"
                    
                sleep $DELAY_TIME
                ((ATTEMPT++)) # Safely move to next attempt loop
            else
                TERMINATION_TEXT="Build terminated with ${ATTEMPT} attempts."
                telegram_edit "$TERMINATION_TEXT"
                break
            fi
        fi
    fi
done
