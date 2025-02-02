#!/bin/bash

# 设置环境变量，提供默认值
export UUID=${UUID:-'90722436-8f8d-45f8-b1f5-e0ab9880cc9a'}
export NEZHA_SERVER=${NEZHA_SERVER:-'agent.oklala.filegear-sg.me'}
export NEZHA_PORT=${NEZHA_PORT:-'443'}
export NEZHA_KEY=${NEZHA_KEY:-'P90pdI0Hbnrth66HOu'}
export ARGO_DOMAIN=${ARGO_DOMAIN:-'a12.oklala.top'}
export ARGO_AUTH=${ARGO_AUTH:-'eyJhIjoiYTUyYzFmMDk1MzAyNTU0YjA3NzJkNjU4ODI0MjRlMzUiLCJ0IjoiZDk5ODQ2N2QtZjg4NC00Yzc1LTg1ODctOGIyMTY4OGE2NzMwIiwicyI6Ik1qUTNOV1l5WW1ZdE9HWTVZaTAwTVdFM0xUbGpaamN0WTJNd056QTNNR1F5WkRkaSJ9'}
export CFIP=${CFIP:-'a12.oklala.top'}
export CFPORT=${CFPORT:-'443'}
export ARGO_PORT=${ARGO_PORT:-'8001'}
export NAME=${NAME:-'IT-tickhosting-GOOD'}

# 循环检测进程是否运行，假若没有运行先检查文件是否存在，如果文件不存在就下载文件再运行
# 根据架构选择合适的下载URL
set_download_url() {
  local default_url="$1"
  local x64_url="$2"

  case "$(uname -m)" in
    x86_64|amd64|x64) echo "$x64_url" ;;
    *) echo "$default_url" ;;
  esac
}

# 下载程序文件（如果不存在）
download_program() {
  local program_name="$1"
  local default_url="$2"
  local x64_url="$3"

  local download_url
  download_url=$(set_download_url "$default_url" "$x64_url")

  if [ ! -f "$program_name" ]; then
    echo "正在下载 $program_name..."
    curl -sSL "$download_url" -o "$program_name"
    chmod +x "$program_name"
    echo "$program_name 下载完成，并授予权限。"
  else
    echo "$program_name 已存在，跳过下载。"
  fi
}

# 下载相关文件
download_program "npm" "https://github.com/eooce/test/releases/download/ARM/swith" "https://github.com/jpus/test/releases/download/amd/nhttp"
sleep 6

download_program "web" "https://github.com/eooce/test/releases/download/ARM/web" "https://github.com/jpus/test/releases/download/amd/xhttp"
sleep 6

download_program "http" "https://github.com/eooce/test/releases/download/arm64/bot13" "https://github.com/jpus/test/releases/download/amd/thttp"
sleep 6

# 生成配置文件 config.json
generate_config() {
  cat > config.json <<EOF
{
  "log": {
    "access": "/dev/null",
    "error": "/dev/null",
    "loglevel": "none"
  },
  "inbounds": [
    {
      "port": $ARGO_PORT,
      "listen": "::",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless"
        }
      }
    }
  ],
   "outbounds": [
     {
       "tag": "direct",
       "protocol": "freedom"
     }
  ]
}
EOF
}

# 配置 Argo Tunnel
argo_type() {
  if [[ -z $ARGO_AUTH || -z $ARGO_DOMAIN ]]; then
    echo "ARGO_AUTH 或 ARGO_DOMAIN 为空，使用临时隧道。"
    return
  fi

  if [[ $ARGO_AUTH =~ TunnelSecret ]]; then
    echo "$ARGO_AUTH" > tunnel.json
    cat > tunnel.yml <<EOF
tunnel: $(cut -d\" -f12 <<< "$ARGO_AUTH")
credentials-file: ./tunnel.json
protocol: http2

ingress:
  - hostname: $ARGO_DOMAIN
    service: http://localhost:$ARGO_PORT
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
  else
    echo "ARGO_AUTH 或 ARGO_DOMAIN 不为空,使用固定隧道。"
  fi
}

# 启动服务
run() {
  # 启动 npm
  if [ -x npm ]; then
    nohup ./npm -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} --tls --report-delay 4 --skip-conn --skip-procs >/dev/null 2>&1 &
    keep1="nohup ./npm -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} --tls --report-delay 4 --skip-conn --skip-procs >/dev/null 2>&1 &"
  fi

  # 启动 web
  if [ -x web ]; then
    nohup ./web -c config.json >/dev/null 2>&1 &
    keep2="nohup ./web -c config.json >/dev/null 2>&1 &"
  fi

  # 启动 http
  if [ -x http ]; then
    local args
    if [[ $ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
      args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
    elif [[ $ARGO_AUTH =~ TunnelSecret ]]; then
      args="tunnel --edge-ip-version auto --config tunnel.yml run"
    else
      args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile boot.log --loglevel info --url http://localhost:$ARGO_PORT"
    fi
    nohup ./http $args >/dev/null 2>&1 &
    keep3="nohup ./http $args >/dev/null 2>&1 &"
  fi
}

# 启动特定程序的检查逻辑
start_program() {
  local program=$1
  local command=$2
  local default_url=$3
  local x64_url=$4

  pid=$(pidof "$program")
  if [ -z "$pid" ]; then
    echo "'$program' 未运行，正在启动..."

    # 如果程序文件不存在，先下载
    if [ ! -f "$program" ]; then
      download_program "$program" "$default_url" "$x64_url"
    fi

    # 如果文件不存在，先生成
    if [ ! -e "config.json" ]; then
      generate_config
    fi
    # 启动程序
    eval "$command"
  else
    echo "'$program' 正在运行，PID: $pid"
  fi
}

# 启动程序并传入下载URL
start_npm_program() {
  if [ -n "$keep1" ]; then
    start_program "npm" "$keep1" "https://github.com/eooce/test/releases/download/ARM/swith" "https://github.com/jpus/test/releases/download/amd/nhttp"
  else
    echo "npm 不需要启动或未配置。"
  fi
}

start_web_program() {
  if [ -n "$keep2" ]; then
    start_program "web" "$keep2" "https://github.com/eooce/test/releases/download/ARM/web" "https://github.com/jpus/test/releases/download/amd/xhttp"
  else
    echo "web 不需要启动或未配置。"
  fi
}

start_http_program() {
  if [ -n "$keep3" ]; then
    start_program "http" "$keep3" "https://github.com/eooce/test/releases/download/arm64/bot13" "https://github.com/jpus/test/releases/download/amd/thttp"
  else
    echo "http 不需要启动或未配置。"
  fi
}

# 获取 Argo 域名
function get_argodomain() {
  if [[ -n $ARGO_AUTH ]]; then
    echo "$ARGO_DOMAIN"
  else
    grep -oE 'https://[[:alnum:]+\.-]+\.trycloudflare\.com' "${FILE_PATH}/boot.log" | sed 's@https://@@'
  fi
}
# 生成连接链接
generate_links() {
  argodomain=$(get_argodomain)
  echo -e "\e[1;32mArgoDomain:\e[1;35m${argodomain}\e[0m"
  sleep 1
  cat > list.txt <<EOF
vless://${UUID}@${CFIP}:${CFPORT}?encryption=none&security=tls&sni=${argodomain}&type=ws&host=${argodomain}&path=%2Fvless%3Fed%3D2560#${NAME}
EOF
  cat list.txt
  sleep 30
  clear
}

# 清理旧文件
cleanup_files() {
  rm -rf core sb.log list.txt boot.log tunnel.json tunnel.yml
}

# 主流程
generate_config
argo_type
generate_links
run
cleanup_files

# 定时检查并启动程序
programs=("npm" "web" "http")
commands=("$keep1" "$keep2" "$keep3")

while true; do
  for ((i=0; i<${#programs[@]}; i++)); do
    program=${programs[i]}
    command=${commands[i]}

    case $program in
      "npm") start_npm_program ;;
      "web") start_web_program ;;
      "http") start_http_program ;;
    esac
  done
  sleep 120
done