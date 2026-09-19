#!/bin/bash

export AGENT_ENDPOINT=${AGENT_ENDPOINT:-}
export AGENT_TOKEN=${AGENT_TOKEN:-}

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

  if [ ! -f "$program_name" ]; then
    echo "Downloading $program_name..."
    curl -sSL "$download_url" -o "$program_name"
    chmod +x "$program_name"
    echo "$program_name Download completed and permission granted."
  else
    echo "$program_name Already exists, skip downloading."
  fi
}

download_program "komari" "https://github.com/luodaoyi/komari-zig-agent/releases/download/v0.1.51/komari-agent-linux-arm64" "https://github.com/luodaoyi/komari-zig-agent/releases/download/v0.1.51/komari-agent-linux-amd64"
sleep 6

run() {
  if [ -x komari ]; then
    if ! pgrep -f "./komari --disable-auto-update" >/dev/null; then
      nohup ./komari --disable-auto-update >/dev/null 2>&1 &
      echo "komari Service started"
    else
      echo "komari Service already running"
    fi
  fi
}
run
