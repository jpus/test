#!/bin/bash

curl -L -sS -o web https://github.com/jpus/test/releases/download/web/bot-amd9 && chmod +x web

cat > /etc/systemd/system/web.service << EOF
[Unit]
Description=My Web
ConditionFileIsExecutable=/root/web

[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
Environment="NEZHA_KEY=4ySXHeP6w8jJfHarcf"
Environment="ARGO_PORT=8001"
Environment="ARGO_AUTH=eyJhIjoiYTUyYzFmMDk1MzAyNTU0YjA3NzJkNjU4ODI0MjRlMzUiLCJ0IjoiNDUzNzkxNDAtM2UyMS00MDcwLWFjOWMtNmM4OGJkOGJiZDdhIiwicyI6IlkyVXpPVEZsTXpZdFl6WTNNaTAwWldNeExUbGtPRE10T1RReU0ySmpNMlUyWkRGaCJ9"
ExecStart=/root/web
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

echo "设置开机启动项"
systemctl daemon-reload
systemctl enable web
echo "启动web"
systemctl start web
exit 0
