#!/bin/bash

# Optional: ensure we are in correct directory
cd "$(dirname "$0")"
clear

# Check if .env file exists
if [ ! -f ".env" ]; then echo "⚠️ .env file not found! Exiting ..."
    exit 0
fi

# source .env file and print a welcome message.
source .env

print_text () {
echo "-------------------------------------------------"
echo "${1}"
}

print_text "          Building $ROM_NAME for $DEVICE"

# set the container log file
LOG_FILE="crave_build.log"
rm -f "$LOG_FILE"

# crave queue and retry logic
MAX_ATTEMPTS=2
ATTEMPT=0
DELAY_TIME="1m" # 1 minutes delay

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    print_text "          attempting build queue ~$((ATTEMPT))..."

    # Run the crave command
    crave run --projectID 93 --no-patch -- "curl -sf https://raw.githubusercontent.com/nuruszama/crave/creek/crave_run.sh | bash" 2>&1 | tee "$LOG_FILE"

    # Capture the pipeline status thanks to set -o pipefail
    CRAVE_STATUS=${PIPESTATUS[0]}

    if [ $CRAVE_STATUS -eq 0 ]; then
        break

    elif [ $CRAVE_STATUS -eq 130 ]; then
        exit 130 # ⚠️ Build Queue Cancelled

    else
        print_text "             Rejected with exit code $CRAVE_STATUS."

        if [ ! -f "$LOG_FILE" ]; then
            print_text " Build script failed to start! Check the setup"
            exit 1
        fi

        if grep -q "Setting up workspace" "$LOG_FILE"; then
            print_text "    build failed.. inspect the logs"
            exit 1
        else
            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                ((ATTEMPT++)) # Safely move to next attempt loop
                sleep $DELAY_TIME
            else
                print_text "  Build terminated with ${ATTEMPT} attempts."
                exit 1
            fi
        fi
    fi
done
