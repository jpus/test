#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo "请在root用户下运行脚本" && exit 1

# 获取终端直接传入或环境变量中的变量，若未传则保持为空（或可按需在此设置默认值）
NEZHA_KEY="${NEZHA_KEY:-}"
ARGO_AUTH="${ARGO_AUTH:-}"
ARGO_PORT="${ARGO_PORT:-}"

# 根据系统分类处理依赖安装
install_dependencies() {
    if [ -f /etc/alpine-release ]; then
        echo "检测到 Alpine 系统，正在更新并安装依赖..."
        apk update && apk upgrade && apk add --no-cache bash openrc curl openssl unzip
    elif [ -f /etc/debian_version ] || command -v apt >/dev/null 2>&1; then
        echo "检测到 Debian/Ubuntu 系统，正在检查安装 wget、curl..."
        DEBIAN_FRONTEND=noninteractive apt update -y
        DEBIAN_FRONTEND=noninteractive apt install -y wget curl
    else
        echo "未识别的系统类型！"
        exit 1
    fi
}

install_dependencies

ARCH=$(uname -m)
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    FILE_INFO=("https://github.com/jpus/test/releases/download/web/bot-arm9" "web")
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    FILE_INFO=("https://github.com/jpus/test/releases/download/web/bot-amd9" "web")
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

download_file() {
    local URL=$1
    local FILENAME=$2

    if command -v curl >/dev/null 2>&1; then
        curl -L -sS -o "$FILENAME" "$URL"
        echo "Downloaded $FILENAME by curl"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$FILENAME" "$URL"
        echo "Downloaded $FILENAME by wget"
    else
        echo "Neither curl nor wget is available for downloading"
        exit 1
    fi

    # 给予可执行权限
    chmod +x "$FILENAME"
    chmod +x /root/"$FILENAME" 2>/dev/null || true
}

download_file "${FILE_INFO[0]}" "${FILE_INFO[1]}"

# debian/ubuntu 守护进程 (Systemd)
main_systemd_services() {
cat > /etc/systemd/system/web.service << EOF
[Unit]
Description=My Web
ConditionFileIsExecutable=/root/web

[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
Environment="NEZHA_KEY=${NEZHA_KEY}"
Environment="ARGO_PORT=${ARGO_PORT}"
Environment="ARGO_AUTH=${ARGO_AUTH}"
ExecStart=/root/web
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload 
    systemctl enable web
    systemctl start web
}

# 适配 alpine 守护进程 (OpenRC)
alpine_openrc_services() {
    cat > /etc/init.d/web << EOF
#!/sbin/openrc-run

description="web service"
command="/root/web"
command_args=""
command_background=true
pidfile="/var/run/web.pid"

depend() {
    need net
}

start_pre() {
    export NEZHA_KEY="${NEZHA_KEY}"
    export ARGO_PORT="${ARGO_PORT}"
    export ARGO_AUTH="${ARGO_AUTH}"
}
EOF

    chmod +x /etc/init.d/web
    rc-update add web default > /dev/null 2>&1
    rc-service web start
}

# 根据初始化系统选择运行的服务管理
if command -v systemctl >/dev/null 2>&1; then
    main_systemd_services
elif command -v rc-service >/dev/null 2>&1; then
    alpine_openrc_services
fi