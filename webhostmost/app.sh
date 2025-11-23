#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

username=$(whoami)
print_info "用户名: $username"

domains_dir="/home/$username/domains"

if [ ! -d "$domains_dir" ]; then
    print_error "域名目录不存在: $domains_dir"
    exit 1
fi

domains=("$domains_dir"/*)
if [ ${#domains[@]} -eq 0 ]; then
    print_error "未找到任何域名目录"
    exit 1
fi

domain=$(basename "${domains[0]}")
print_info "使用域名目录: $domain"

ls ~/nodevenv/domains/$domain/public_html

if [ $? -eq 0 ]; then
  echo "nodejs app Found"
  exit
else
  echo "nodejs app not Found"
fi

pkill -f lsnode

print_info "正在激活Node.js应用..."
cloudlinux-selector create --json --interpreter=nodejs --user=$username \
    --app-root="/home/$username/domains/$domain/public_html" --app-uri=/ \
    --version=22 --app-mode=Production --startup-file=app.js

domain_dir="/home/$username/domains/$domain/public_html"
node_env_path="/home/$username/nodevenv/domains/$domain/public_html"

node_versions=($(ls -d "$node_env_path"/* 2>/dev/null | grep -o '[0-9]*$' | sort -nr))
if [ ${#node_versions[@]} -eq 0 ]; then
    print_error "未找到Node.js虚拟环境"
    exit 1
fi

selected_version="${node_versions[0]}"
node_env_activate="$node_env_path/$selected_version/bin/activate"
print_info "使用Node.js版本: $selected_version"

print_info "正在安装依赖..."
cd "$domain_dir" || exit 1
source "$node_env_activate"
curl -fsSL https://raw.githubusercontent.com/jpus/test/main/webhostmost/app.js -o app.js
curl -fsSL https://raw.githubusercontent.com/jpus/test/main/webhostmost/package.json -o package.json
npm install

print_info "所有操作已完成!"

rm -f /home/$username/.npm/_logs/*.log
rm -rf /home/$username/.bash_history
print_info "清除文件已完成!"
curl -f "https://$domain/" > ~/nodejs.log