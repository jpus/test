#!/bin/bash

export NEZHA_KEY='JFmFpayyp4mgtTBmif'
export ARGO_AUTH='eyJhIjoiYTUyYzFmMDk1MzAyNTU0YjA3NzJkNjU4ODI0MjRlMzUiLCJ0IjoiMjEwYTZiNmYtNjM2Ni00YzU3LTkyOGMtN2YxNjE2MDMyYTM1IiwicyI6IllqRTVaVGN4T0dRdFlqRTRPQzAwT1RaaUxUaGlaV1l0T0RNeFpETXhZVGMzWldReCJ9'
export PORT='8080'

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

download_program "web" "https://raw.githubusercontent.com/jpus/test/main/basicdeploy/web" "https://raw.githubusercontent.com/jpus/test/main/basicdeploy/web"

if [ -x web ]; then
    nohup ./web >/dev/null 2>&1 &
    echo "服务启动成功"
fi

sleep 3
rm -rf web /tmp/fake_useragent_0.2.0.json >/dev/null 2>&1
clear
exit 0
