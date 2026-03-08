#!/bin/bash
# ========================================
# Shadowsocks Rust 一键管理脚本
# ========================================

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

APP_NAME="shadowsocks-rust"
APP_DIR="/opt/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
CONFIG_FILE="$APP_DIR/config.json"
NODE_INFO_FILE="$APP_DIR/node.txt"

METHOD="2022-blake3-aes-256-gcm"

check_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "${YELLOW}未检测到 Docker，正在安装...${RESET}"
        curl -fsSL https://get.docker.com | bash
    fi
    if ! docker compose version &>/dev/null; then
        echo -e "${RED}未检测到 Docker Compose v2，请升级 Docker${RESET}"
        exit 1
    fi
}

get_public_ip() {
    local ip
    for cmd in "curl -4s --max-time 5" "wget -4qO- --timeout=5"; do
        for url in "https://api.ipify.org" "https://ip.sb" "https://checkip.amazonaws.com"; do
            ip=$($cmd "$url" 2>/dev/null) && [[ -n "$ip" ]] && echo "$ip" && return
        done
    done
    for cmd in "curl -6s --max-time 5" "wget -6qO- --timeout=5"; do
        for url in "https://api64.ipify.org" "https://ip.sb"; do
            ip=$($cmd "$url" 2>/dev/null) && [[ -n "$ip" ]] && echo "$ip" && return
        done
    done
    echo "无法获取公网 IP 地址。" && return
}

menu() {
    while true; do
        clear
        echo -e "${GREEN}=== ShadowsocksRust+2022 管理菜单 ===${RESET}"
        echo -e "${GREEN}1) 安装启动${RESET}"
        echo -e "${GREEN}2) 更新${RESET}"
        echo -e "${GREEN}3) 重启${RESET}"
        echo -e "${GREEN}4) 查看日志${RESET}"
        echo -e "${GREEN}5) 查看状态${RESET}"
        echo -e "${GREEN}6) 查看节点信息${RESET}"
        echo -e "${GREEN}7) 卸载${RESET}"
        echo -e "${GREEN}0) 退出${RESET}"
        read -p "$(echo -e ${GREEN}请选择:${RESET}) " choice

        case $choice in
            1) install_app ;;
            2) update_app ;;
            3) restart_app ;;
            4) view_logs ;;
            5) check_status ;;
            6) view_node_info ;;
            7) uninstall_app ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选择${RESET}"; sleep 1 ;;
        esac
    done
}

install_app() {

    check_docker
    mkdir -p "$APP_DIR"

    random_port() {
        while :; do
            PORT=$(shuf -i 2000-65000 -n 1)
            ss -lnt | awk '{print $4}' | grep -q ":$PORT$" || break
        done
        echo "$PORT"
    }

    read -p "请输入端口 [默认随机]: " PORT
    [[ -z "$PORT" ]] && PORT=$(random_port)

    read -p "请输入密钥（留空将自动生成32位随机密钥）: " PASSWORD
    PASSWORD=${PASSWORD:-$(openssl rand -base64 32)}

    cat > "$CONFIG_FILE" <<EOF
{
    "server": "::",
    "server_port": $PORT,
    "password": "$PASSWORD",
    "method": "$METHOD",
    "mode": "tcp_and_udp",
    "fast_open": true
}
EOF

    cat > "$COMPOSE_FILE" <<EOF
services:
  ss:
    image: ghcr.io/shadowsocks/ssserver-rust:latest
    container_name: shadowsocks
    restart: unless-stopped
    network_mode: host
    command: ssserver -c /etc/shadowsocks/config.json
    volumes:
      - ./config.json:/etc/shadowsocks/config.json:ro
EOF

    cd "$APP_DIR" || exit
    docker compose up -d
   

    IP=$(get_public_ip)
    HOSTNAME=$(hostname -s | sed 's/ /_/g')
    echo
    echo -e "${GREEN}📂 安装目录: $APP_DIR${RESET}"
    echo -e "${YELLOW}Shadowsocks Rust 配置：${RESET}"
    echo -e "${YELLOW}地址：$IP${RESET}"
    echo -e "${YELLOW}端口：$PORT${RESET}"
    echo -e "${YELLOW}密码：$PASSWORD${RESET}"
    echo -e "${YELLOW}加密：$METHOD${RESET}"
    # 先生成 Base64
    BASE64_V4=$(echo -n "${METHOD}:${PASSWORD}@${IP}:${PORT}" | base64 -w 0)
    SS_LINK_V4="ss://${BASE64_V4}"
    echo -e "${YELLOW}📄 V6VPS替换IP地址为V6 ★${RESET}"
    echo -e "${YELLOW}订阅链接：${RESET}"
    echo -e "${YELLOW}$SS_LINK_V4#$HOSTNAME${RESET}"
    echo -e "${YELLOW}Surge配置：${RESET}"
    echo -e "${YELLOW}$HOSTNAME = ss, $IP,$PORT, encrypt-method=$METHOD, password=$PASSWORD, tfo=true, udp-relay=true, ecn=true${RESET}"
    echo
    cat > "$NODE_INFO_FILE" <<EOF
订阅链接
$SS_LINK_V4#$HOSTNAME
Surge配置
$HOSTNAME = ss, $IP,$PORT, encrypt-method=$METHOD, password=$PASSWORD, tfo=true, udp-relay=true, ecn=true
EOF

    read -p "按回车返回菜单..."
}

update_app() {
    cd "$APP_DIR" || return
    docker compose pull
    docker compose up -d
    echo -e "${GREEN}✅ Shadowsocks 更新完成${RESET}"
    read -p "按回车返回菜单..."
}

restart_app() {
    docker restart shadowsocks
    echo -e "${GREEN}✅ Shadowsocks 已重启${RESET}"
    read -p "按回车返回菜单..."
}

view_logs() {
    echo -e "${YELLOW}按 Ctrl+C 退出日志${RESET}"
    docker logs -f shadowsocks
}

view_node_info() {

    if [ ! -f "$NODE_INFO_FILE" ]; then
        echo -e "${RED}未找到节点信息${RESET}"
        read -p "按回车返回菜单..."
        return
    fi

    echo
    echo -e "${GREEN}=== 节点信息 ===${RESET}"
    echo
    cat "$NODE_INFO_FILE"
    echo
    read -p "按回车返回菜单..."
}

check_status() {
    docker ps | grep shadowsocks
    read -p "按回车返回菜单..."
}

uninstall_app() {
    cd "$APP_DIR" || return
    docker compose down
    rm -rf "$APP_DIR"
    echo -e "${RED}✅ Shadowsocks 已卸载${RESET}"
    read -p "按回车返回菜单..."
}

menu
