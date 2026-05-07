#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印信息函数
print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# 打印错误函数
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 打印警告函数
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 清理残留文件及进程
cleanup() {
    print_info "开始清理残留文件..."
    rm -rf "/home/$username/.npm"
    rm -rf "/home/$username/virtualenv"
    rm -rf "/home/$username/.local"
    rm -rf "/home/$username/.cache"
    print_info "残留文件清理完成！"
    
    print_info "强制终止用户 $username 的所有进程..."
    pkill -kill -u "$username" 2>/dev/null
    print_info "进程清理完成。"
}

# 获取用户名
username=$(whoami)
print_info "用户名: $username"

domains_dir="/home/$username/domains"

# 检查 domains 目录是否存在，若不存在则直接清理并退出
if [ ! -d "$domains_dir" ]; then
    print_error "域名目录不存在: $domains_dir"
    print_info "由于没有域名目录，直接执行残留文件清理..."
    cleanup
    exit 0
fi

# 使用传统方式遍历域名目录（只处理一级子目录，且为目录）
domains=()
for dir in "$domains_dir"/*/; do
    # 去掉末尾的斜杠，并提取目录名
    [ -d "$dir" ] || continue
    domain_name=$(basename "$dir")
    domains+=("$domain_name")
done

if [ ${#domains[@]} -eq 0 ]; then
    print_warning "未找到任何域名目录，直接执行残留文件清理..."
    cleanup
    exit 0
fi

print_info "找到 ${#domains[@]} 个域名: ${domains[*]}"

# 删除应用前先结束 lsnode 和 node 进程
print_info "正在终止用户 $username 的所有 lsnode 进程..."
pkill -x "lsnode" -u "$username" 2>/dev/null
print_info "正在终止用户 $username 的所有 node 进程..."
pkill -f "node" -u "$username" 2>/dev/null

# 遍历每个域名，尝试删除其 Node.js 应用
for domain in "${domains[@]}"; do
    app_root="/home/$username/domains/$domain/public_html"
    print_info "正在检查域名: $domain (应用根目录: $app_root)"
    
    # 执行 destroy 操作，忽略错误输出（应用不存在时也继续）
    if cloudlinux-selector destroy --json --interpreter=nodejs --user="$username" --app-root="$app_root" 2>/dev/null; then
        print_info "成功删除域名 $domain 的 Node.js 应用。"
    else
        print_warning "域名 $domain 未找到 Node.js 应用，或删除失败（可能应用不存在）。"
    fi
done

# 所有域名处理完毕后，执行统一清理
cleanup

exit 0
