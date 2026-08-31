#!/bin/bash

cd "$(dirname "$0")"
clear

LOG_FILE="crave_build.log"
rm -f "$LOG_FILE"

MAX_ATTEMPTS=4
ATTEMPT=1
DELAY_TIME="1m"

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo ">> attempting build queue ~$((ATTEMPT))..."

    crave run --projectID 86 --no-patch -- "curl -sf https://raw.githubusercontent.com/kusonekoworld-max/crave-build-script-/creek/derpfest/crave_run.sh | bash" 2>&1 | tee "$LOG_FILE"

    CRAVE_STATUS=${PIPESTATUS[0]}

    if [ $CRAVE_STATUS -eq 0 ]; then
        break
    elif [ $CRAVE_STATUS -eq 130 ]; then
        exit 130
    else
        echo ">> Rejected with exit code $CRAVE_STATUS."
        if [ ! -f "$LOG_FILE" ]; then
            echo ">> Build script failed to start! Check the setup"
            exit 1
        fi
        if grep -q "Setting up workspace" "$LOG_FILE"; then
            echo ">> build failed.. inspect the logs"
            exit 1
        else
            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                ((ATTEMPT++))
                sleep $DELAY_TIME
            else
                echo ">> Build terminated with ${ATTEMPT} attempts."
                exit 1
            fi
        fi
    fi
done
