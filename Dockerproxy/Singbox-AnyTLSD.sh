#!/bin/bash
# ========================================
# Sing-box AnyTLS 一键管理脚本（Host模式 + 自签Bing证书）
# ========================================

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

APP_NAME="Singbox-AnyTLS"
APP_DIR="/opt/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
CONFIG_FILE="$APP_DIR/config.json"
CONTAINER_NAME="Singbox-AnyTLS"
NODE_INFO_FILE="$APP_DIR/node.txt"

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

check_port() {
    if ss -tulnp | grep -q ":$1 "; then
        echo -e "${RED}端口 $1 已被占用，请更换端口！${RESET}"
        return 1
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
        echo -e "${GREEN}=== Singbox-AnyTLS 管理菜单 ===${RESET}"
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

    if [ -f "$COMPOSE_FILE" ]; then
        echo -e "${YELLOW}检测到已安装，是否覆盖安装？(y/n)${RESET}"
        read confirm
        [[ "$confirm" != "y" ]] && return
    fi

    # 端口
    read -p "请输入端口 [默认随机]: " input_port
    if [[ -z "$input_port" ]]; then
        PORT=$(shuf -i 20000-60000 -n1)
    else
        PORT=$input_port
    fi

    check_port "$PORT" || return

    # 生成随机密码（AnyTLS 用 password）
    read -p "请输入密码（留空将自动生成16位随机密码）: " PASSWORD
    PASSWORD=${PASSWORD:-$(tr -dc A-Za-z0-9 </dev/urandom | head -c16)}

    echo -e "${YELLOW}正在生成自签证书...${RESET}"

    openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "$APP_DIR/server.key" \
    -out "$APP_DIR/server.crt" \
    -days 36500 \
    -subj "/CN=www.bing.com" \
    -addext "subjectAltName=DNS:www.bing.com" >/dev/null 2>&1

    # 生成 sing-box 配置
    cat > "$CONFIG_FILE" <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "anytls",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        {
          "password": "${PASSWORD}"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "certificate_path": "/etc/sing-box/server.crt",
        "key_path": "/etc/sing-box/server.key"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF

    # 生成 compose
    cat > "$COMPOSE_FILE" <<EOF
services:
  singbox-anytls:
    image: ghcr.io/sagernet/sing-box:latest
    container_name: ${CONTAINER_NAME}
    restart: always
    network_mode: host
    volumes:
      - ./config.json:/etc/sing-box/config.json
      - ./server.crt:/etc/sing-box/server.crt
      - ./server.key:/etc/sing-box/server.key
    command: run -c /etc/sing-box/config.json
EOF

    cd "$APP_DIR" || exit
    docker compose up -d
    
    SERVER_IP=$(get_public_ip)
    HOSTNAME=$(hostname -s | sed 's/ /_/g')

    echo
    echo -e "${GREEN}📂 安装目录: $APP_DIR${RESET}"
    echo -e "${GREEN}✅ Singbox-AnyTLS 已启动${RESET}"
    echo -e "${YELLOW}🌐 IP: ${SERVER_IP}${RESET}"
    echo -e "${YELLOW}🔌 端口: ${PORT}${RESET}"
    echo -e "${YELLOW}🔑 密码: ${PASSWORD}${RESET}"
    echo
    echo -e "${YELLOW}📄 V6VPS替换IP地址为V6 ★${RESET}"
    echo -e "${YELLOW}V2rayN:${RESET}"
    echo -e "${YELLOW}anytls://${PASSWORD}@${SERVER_IP}:${PORT}/?sni=www.bing.com&insecure=1#$HOSTNAME${RESET}"
    echo -e "${YELLOW}Surge :${RESET}"
    echo -e "${YELLOW}$HOSTNAME = anytls, ${SERVER_IP}, ${PORT}, password=${PASSWORD}, tfo=true, skip-cert-verify=true, reuse=false${RESET}"
    echo
    cat > "$NODE_INFO_FILE" <<EOF
V2rayN
anytls://${PASSWORD}@${SERVER_IP}:${PORT}/?sni=www.bing.com&insecure=1#$HOSTNAME
Surge
$HOSTNAME = anytls, ${SERVER_IP}, ${PORT}, password=${PASSWORD}, tfo=true, skip-cert-verify=true, reuse=false
EOF
    read -p "按回车返回菜单..."
}

update_app() {
    cd "$APP_DIR" || return
    docker compose pull
    docker compose up -d
    echo -e "${GREEN}✅ Singbox-AnyTLS 更新完成${RESET}"
    read -p "按回车返回菜单..."
}

restart_app() {
    docker restart ${CONTAINER_NAME}
    echo -e "${GREEN}✅ Singbox-AnyTLS 已重启${RESET}"
    read -p "按回车返回菜单..."
}

view_logs() {
    echo -e "${YELLOW}按 Ctrl+C 退出日志${RESET}"
    docker logs -f ${CONTAINER_NAME}
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
    docker ps | grep ${CONTAINER_NAME}
    read -p "按回车返回菜单..."
}

uninstall_app() {
    docker stop ${CONTAINER_NAME}
    docker rm ${CONTAINER_NAME}
    rm -rf "$APP_DIR"
    echo -e "${RED}✅ Singbox-AnyTLS 已卸载${RESET}"
    read -p "按回车返回菜单..."
}

menu
