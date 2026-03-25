#!/bin/bash

username=$(whoami)
export NEZHA_KEY=${NEZHA_KEY:-''}

run() {
  if [ ! -e daemonize ]; then
    echo "下载 daemonize..."
    curl -fsSL https://raw.githubusercontent.com/jpus/test/main/webhostmost/daemonize -o daemonize
    if [ $? -eq 0 ]; then
      echo "daemonize下载完成。"
      chmod +x daemonize
      echo "已授予daemonize执行权限。"
    else
      echo "daemonize下载失败"
      return 1
    fi
  fi

  if [ ! -e nza ]; then
    echo "下载 nza..."
    curl -fsSL https://github.com/jpus/test/releases/download/web/nza-9 -o nza
    if [ $? -eq 0 ]; then
      echo "nza下载完成。"
      chmod +x nza
      echo "已授予nza执行权限。"
    else
      echo "nza下载失败"
      return 1
    fi
  fi
  
  if ! pidof nza >/dev/null; then
    ./daemonize /home/$username/nza -p "${NEZHA_KEY}"
    echo "nza服务已启动"
  else
    echo "nza服务已在运行"
  fi

  sleep 6
  if pidof nza >/dev/null; then
    echo "nza已在后台运行"
  fi
}
run