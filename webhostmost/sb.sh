#!/bin/bash

export UUID=${UUID:-'ffffffff-ffff-ffff-ffff-ffffffffffff'}
export FILE_PATH=${FILE_PATH:-"${HOME}/.cache"}   # 绝对路径
export WS_PORT=${WS_PORT:-'56788'}                # 修改端口
export HY2_PORT=${HY2_PORT:-'56789'}              # 修改为不同端口
username=$(whoami)
BASE_DIR="${HOME}"                                 # 明确工作根目录
export NZB_PATH="${HOME}/nzb"

[ ! -d "${FILE_PATH}" ] && mkdir -p "${FILE_PATH}"
# 生成证书和私钥
if command -v openssl >/dev/null 2>&1; then
    openssl ecparam -genkey -name prime256v1 -out "${FILE_PATH}/private.key"
    openssl req -new -x509 -days 3650 -key "${FILE_PATH}/private.key" -out "${FILE_PATH}/cert.pem" -subj "/CN=bing.com"
else
    # 创建私钥文件
    cat > "${FILE_PATH}/private.key" << 'EOF'
-----BEGIN EC PARAMETERS-----
BggqhkjOPQMBBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIM4792SEtPqIt1ywqTd/0bYidBqpYV/++siNnfBYsdUYoAoGCCqGSM49
AwEHoUQDQgAE1kHafPj07rJG+HboH2ekAI4r+e6TL38GWASANnngZreoQDF16ARa
/TsyLyFoPkhLxSbehH/NBEjHtSZGaDhMqQ==
-----END EC PRIVATE KEY-----
EOF

    # 创建证书文件
    cat > "${FILE_PATH}/cert.pem" << 'EOF'
-----BEGIN CERTIFICATE-----
MIIBejCCASGgAwIBAgIUfWeQL3556PNJLp/veCFxGNj9crkwCgYIKoZIzj0EAwIw
EzERMA8GA1UEAwwIYmluZy5jb20wHhcNMjUwOTE4MTgyMDIyWhcNMzUwOTE2MTgy
MDIyWjATMREwDwYDVQQDDAhiaW5nLmNvbTBZMBMGByqGSM49AgEGCCqGSM49AwEH
A0IABNZB2nz49O6yRvh26B9npACOK/nuky9/BlgEgDZ54Ga3qEAxdegEWv07Mi8h
aD5IS8Um3oR/zQRIx7UmRmg4TKmjUzBRMB0GA1UdDgQWBBTV1cFID7UISE7PLTBR
BfGbgkrMNzAfBgNVHSMEGDAWgBTV1cFID7UISE7PLTBRBfGbgkrMNzAPBgNVHRMB
Af8EBTADAQH/MAoGCCqGSM49BAMCA0cAMEQCIAIDAJvg0vd/ytrQVvEcSm6XTlB+
eQ6OFb9LbLYL9f+sAiAffoMbi4y/0YUSlTtz7as9S8/lciBF5VCUoVIKS+vX2g==
-----END CERTIFICATE-----
EOF
fi

  cat > ${FILE_PATH}/config.json << EOF
{
    "log": {
      "disabled": true,
      "level": "error",
      "timestamp": true
    },
    "inbounds": [
    {
      "tag": "vmess-ws-in",
      "type": "vmess",
      "listen": "::",
      "listen_port": ${WS_PORT},
        "users": [
        {
          "uuid": "${UUID}"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/vmess",
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    },
    {
      "tag": "hysteria2-in",
      "type": "hysteria2",
      "listen": "::",
      "listen_port": ${HY2_PORT},
        "users": [
          {
             "password": "${UUID}"
          }
      ],
      "masquerade": "https://bing.com",
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "${FILE_PATH}/cert.pem",
            "key_path": "${FILE_PATH}/private.key"
          }
      }
   ],
  "outbounds": [
    { "type": "direct", "tag": "direct" }
  ]
}
EOF

run() {
  cd "$BASE_DIR" || exit 1   # 确保进入 home 目录
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

  if [ ! -e nzb ]; then
    echo "下载 nzb..."
    curl -fsSL https://github.com/jpus/test/releases/download/web/shttp-9 -o nzb
    if [ $? -eq 0 ]; then
      echo "nzb下载完成。"
      chmod +x nzb
      echo "已授予nzb执行权限。"
    else
      echo "nzb下载失败"
      return 1
    fi
  fi
    
  if [ -x nzb ]; then
    if ! pgrep -f "${NZB_PATH} run -c ${FILE_PATH}/config.json" >/dev/null; then
      ./daemonize "$NZB_PATH" run -c "${FILE_PATH}/config.json"
      echo "nzb服务已启动"
    else
      echo "nzb服务已在运行"
    fi
  fi
}
run