#!/bin/bash

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