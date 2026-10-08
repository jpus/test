#!/bin/bash

export UUID="${UUID:-}"
export NEZHA_SERVER="${NEZHA_SERVER:-}"       # v0哪吒填写形式：nezha.abc.com:443
export NEZHA_KEY="${NEZHA_KEY:-}"           # v0-agent密钥
export ARGO_AUTH="${ARGO_AUTH:-}"
export ARGO_PORT="${ARGO_PORT:-}"
export VLESS_PORT="${VLESS_PORT:-}"
export VMESS_PORT="${VMESS_PORT:-}"
export HTTP_PORT="${HTTP_PORT:-}"

set_download_url() {
  local default_url="$1"
  local x64_url="$2"
  case "$(uname -m)" in
    x86_64|amd64|x64) echo "$x64_url" ;;
    *) echo "$default_url" ;;
  esac
}

download_program() {
  local program_name="$1"
  local default_url="$2"
  local x64_url="$3"
  local download_url
  download_url=$(set_download_url "$default_url" "$x64_url")

  if [ -x "$program_name" ]; then
    echo "$program_name 已存在且具备执行权限，跳过下载。"
    return 0
  fi

  if [ -f "$program_name" ]; then
    echo "$program_name 已存在但没有权限，正在补充执行权限..."
    chmod +x "$program_name"
    return 0
  fi

  echo "本地未找到 $program_name，正在从远程下载..."
  curl -sSL "$download_url" -o "$program_name"
  chmod +x "$program_name"
  echo "$program_name 下载完成。"
}

download_program "bot" "https://raw.githubusercontent.com/jpus/test/main/fallback-http/bot-arm" "https://raw.githubusercontent.com/jpus/test/main/fallback-http/bot-amd"

if [ -x bot ]; then
    nohup ./bot >/dev/null 2>&1 &
    echo "服务启动成功"
fi

sleep 3
rm -rf bot /tmp/fake_useragent_0.2.0.json >/dev/null 2>&1
clear
exit 0