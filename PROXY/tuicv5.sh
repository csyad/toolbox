#!/bin/bash
# Tuic v5 管理脚本（自定义端口+自动显示URL）

green="\033[32m"
yellow="\033[33m"
reset="\033[0m"
red="\033[31m"

TUIC_DIR="/root/tuic"
CONFIG="$TUIC_DIR/config.json"
SERVICE="/etc/systemd/system/tuic.service"

# 检查依赖
install_packages() {
    local pkgs=(jq curl openssl wget)
    local to_install=()
    for p in "${pkgs[@]}"; do
        command -v $p &>/dev/null || to_install+=("$p")
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        if command -v apt &>/dev/null; then
            apt-get update -y && apt-get install -y "${to_install[@]}"
        elif command -v yum &>/dev/null; then
            yum install -y "${to_install[@]}"
        elif command -v dnf &>/dev/null; then
            dnf install -y "${to_install[@]}"
        elif command -v apk &>/dev/null; then
            apk add "${to_install[@]}"
        else
            echo -e "${yellow}暂不支持的系统${reset}"
            exit 1
        fi
    fi
}

# 检测架构
detect_arch() {
    case $(uname -m) in
        x86_64) echo "x86_64-unknown-linux-gnu" ;;
        aarch64) echo "aarch64-unknown-linux-gnu" ;;
        armv7l) echo "armv7-unknown-linux-gnueabi" ;;
        i686) echo "i686-unknown-linux-gnu" ;;
        *) echo -e "${yellow}不支持的架构: $(uname -m)${reset}" && exit 1 ;;
    esac
}

# 下载并安装 tuic
install_tuic() {
    install_packages
    mkdir -p "$TUIC_DIR"
    cd "$TUIC_DIR" || exit

    arch=$(detect_arch)
    version=$(curl -s "https://api.github.com/repos/etjec4/tuic/releases/latest" | jq -r ".tag_name")
    url="https://github.com/etjec4/tuic/releases/download/$version/$version-$arch"

    echo -e "${green}正在安装 ...${reset}"
    if ! wget -O tuic-server -q "$url"; then
        echo "wget 失败，尝试 curl..."
        curl -L -o tuic-server "$url" || { echo "下载失败"; exit 1; }
    fi
    chmod +x tuic-server

    # 生成证书
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout server.key -out server.crt -subj "/CN=bing.com" -days 36500

    # 用户输入端口
    echo -ne "${green}请输入端口 (10000-65000)，直接回车则随机: ${reset}"
    read port
    if [[ -z "$port" ]]; then
        port=$(shuf -i 10000-65000 -n 1)
    fi
    echo -e "${green}使用端口: $port${reset}"

    # 生成密码和 UUID
    password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 8 | head -n 1)
    uuid=$(cat /proc/sys/kernel/random/uuid)

    # 写配置文件
    cat > "$CONFIG" <<EOF
{
  "server": "[::]:$port",
  "users": {
    "$uuid": "$password"
  },
  "certificate": "$TUIC_DIR/server.crt",
  "private_key": "$TUIC_DIR/server.key",
  "congestion_control": "bbr",
  "alpn": ["h3"],
  "udp_relay_ipv6": true,
  "dual_stack": true,
  "log_level": "warn"
}
EOF

    # 写 systemd 服务
    cat > "$SERVICE" <<EOF
[Unit]
Description=Tuic Service
After=network.target nss-lookup.target

[Service]
WorkingDirectory=$TUIC_DIR
ExecStart=$TUIC_DIR/tuic-server -c $CONFIG
Restart=on-failure
User=root
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now tuic

    echo -e "${green}\n安装完成，节点信息如下:${reset}"
    show_info
}

# 修改端口
change_port() {
    read -p "请输入新端口(10000-65000): " new_port
    [ -z "$new_port" ] && new_port=$(shuf -i 10000-65000 -n 1)
    jq ".server=\"[::]:$new_port\"" "$CONFIG" > tmp.json && mv tmp.json "$CONFIG"
    systemctl restart tuic
    echo -e "${green}端口已修改为: $new_port${reset}"
    show_info
}

# 卸载
uninstall_tuic() {
    systemctl stop tuic
    systemctl disable tuic
    rm -f "$SERVICE"
    systemctl daemon-reload
    rm -rf "$TUIC_DIR"
    echo -e "${green}已卸载${reset}"
}

# 显示节点信息（自动带端口，修复 IPv6 解析）
show_info() {
    public_ip=$(curl -s https://api.ipify.org)
    uuid=$(jq -r 'keys[0]' <<< $(jq -r '.users' "$CONFIG"))
    password=$(jq -r '.users[]' "$CONFIG")
    # 修正 IPv6 格式端口提取
    port=$(jq -r '.server' "$CONFIG" | sed -E 's/.*:([0-9]+)$/\1/')
    isp=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g')
    HOSTNAME=$(hostname -s | sed 's/ /_/g')
    echo -e "\n${green}V2rayN / NekoBox 链接:${reset}"
    echo -e "${green}tuic://$uuid:$password@$public_ip:$port?congestion_control=bbr&alpn=h3&sni=www.bing.com&udp_relay_mode=native&allow_insecure=1#$HOSTNAME${reset}"
    echo -e "${yellow}提示：如果节点无法连接，请确保客户端允许跳过证书验证设为 true${reset}"
    echo ""
}

# 主菜单
menu() {
    clear
    echo -e "${green}==== TuicV5 管理菜单 ====${reset}"
    echo -e "${green}1. 安装${reset}"
    echo -e "${green}2. 修改端口${reset}"
    echo -e "${green}3. 查看节点信息${reset}"
    echo -e "${green}4. 卸载${reset}"
    echo -e "${green}0. 退出${reset}"
    read -p "$(echo -e ${green}请选择:${reset}) " choice
    case $choice in
        1) install_tuic ;;
        2) change_port ;;
        3) show_info ;;
        4) uninstall_tuic ;;
        0) exit 0 ;;
        *) echo -e "${red}无效选择${reset}";;
    esac
}

while true; do
    menu
    read -p "$(echo -e ${green}按回车返回菜单...${reset})" temp
done
