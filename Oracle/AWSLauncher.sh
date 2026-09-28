#!/bin/bash
# =================================================================
# AWSLauncher Docker Compose 管理面板 
# =================================================================

# 颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

CONTAINER_NAME="oci-aws"
BASE_DIR="/opt/oci-aws"
COMPOSE_FILE="$BASE_DIR/docker-compose.yml"
ENV_FILE="$BASE_DIR/.env"

# 检测依赖
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: 未检测到 Docker，请先安装 Docker！${RESET}"
        exit 1
    fi
}

# 动态获取容器状态与映射端口
get_status_info() {
    if ! command -v docker &> /dev/null; then
        status="${RED}未安装 Docker${RESET}"
        img_version="${RED}未安装${RESET}"
        port_display="N/A"
        return 0
    fi
    if [ "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
        status="${GREEN}运行中${RESET}"
    elif [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
        status="${RED}已停止${RESET}"
    else
        status="${RED}未部署${RESET}"
    fi

    if [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
        img_version=$(docker inspect -f '{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null)
        [[ -z "$img_version" ]] && img_version="已安装"

        if [[ -f "$ENV_FILE" ]]; then
            source "$ENV_FILE"
        fi
        port_display="${PORT:-18168}"
    else
        img_version="${RED}未安装${RESET}"
        port_display="N/A"
    fi
}

# 获取公网 IP (兼容双栈环境)
get_public_ip() {
    local mode=${1:-"auto"}
    local ip=""
    
    if [[ "$mode" == "v4" ]]; then
        for url in "https://api.ipify.org" "https://4.ip.sb" "https://checkip.amazonaws.com"; do
            ip=$(wget -qO- --timeout=3 --tries=1 -4 --no-check-certificate "$url" 2>/dev/null) && [[ -n "$ip" && "$ip" != *":"* ]] && echo "$ip" && return 0
        done
    elif [[ "$mode" == "v6" ]]; then
        for url in "https://api64.ipify.org" "https://6.ip.sb"; do
            ip=$(wget -qO- --timeout=3 --tries=1 -6 --no-check-certificate "$url" 2>/dev/null) && [[ -n "$ip" && "$ip" == *":"* ]] && echo "$ip" && return 0
        done
    else
        for url in "https://api.ipify.org" "https://4.ip.sb"; do
            ip=$(wget -qO- --timeout=3 --tries=1 -4 --no-check-certificate "$url" 2>/dev/null) && [[ -n "$ip" ]] && echo "$ip" && return 0
        done
        for url in "https://api64.ipify.org" "https://6.ip.sb"; do
            ip=$(wget -qO- --timeout=3 --tries=1 --no-check-certificate "$url" 2>/dev/null) && [[ -n "$ip" ]] && echo "$ip" && return 0
        done
    fi
    echo "127.0.0.1" && return 0
}

# 部署 OCI-AWS
install_utils() {
    check_dependencies
    
    mkdir -p "$BASE_DIR"
    DETECT_IP=$(get_public_ip)

    echo -e "${CYAN}====== 1. 端口与配置初始化 ======${RESET}"
    echo -ne "${YELLOW}请输入服务访问端口 [默认: 18168]: ${RESET}"
    read -r custom_port
    [[ -z "$custom_port" ]] && custom_port="18168"
    if ! [[ "$custom_port" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误: 端口必须是纯数字！${RESET}"
        return
    fi

    # 创建本地持久化数据目录
    echo -e "${YELLOW}正在创建本地数据目录 (data)...${RESET}"
    mkdir -p "$BASE_DIR/data"

    # 生成 32 字节高强度密钥
    echo -e "${YELLOW}正在自动生成 32 字节高强度安全密钥 (OCI_AWS_SECRET_KEY)...${RESET}"
    local generated_secret=$(openssl rand -hex 32)

    # 写入 .env 文件
    cat > "$ENV_FILE" <<EOF
OCI_AWS_VERSION=latest
PORT=$custom_port
AUTH_COOKIE_SECURE=false
OCI_AWS_RUNTIME_UID=1001
OCI_AWS_RUNTIME_GID=1001
OCI_AWS_SECRET_KEY=$generated_secret
EOF

    # 写入 docker-compose.yml 文件（使用 'EOF' 防止变量被误解析）
    echo -e "${YELLOW}正在生成规范的 docker-compose.yml 配置文件...${RESET}"
    cat << 'EOF' > "$COMPOSE_FILE"
services:
  init-permissions:
    image: busybox:1.37
    container_name: oci-aws-init-permissions
    user: "0:0"
    restart: "no"
    command:
      - sh
      - -c
      - |
        mkdir -p /app/data
        chown -R "${OCI_AWS_RUNTIME_UID:-1001}:${OCI_AWS_RUNTIME_GID:-1001}" /app/data
        chmod 700 /app/data
    volumes:
      - ./data:/app/data

  app:
    image: ${OCI_AWS_IMAGE_REPO:-ghcr.io/nodewebzsz/oci-aws}:${OCI_AWS_VERSION:-latest}
    pull_policy: always
    container_name: oci-aws
    restart: unless-stopped
    depends_on:
      init-permissions:
        condition: service_completed_successfully
    user: "${OCI_AWS_RUNTIME_UID:-1001}:${OCI_AWS_RUNTIME_GID:-1001}"
    environment:
      NODE_ENV: production
      HOSTNAME: 0.0.0.0
      PORT: ${PORT:-18168}
      LOCAL_AWS_DB_PATH: /app/data/oci-aws.sqlite
      AUTH_COOKIE_SECURE: ${AUTH_COOKIE_SECURE:-false}
      OCI_AWS_SECRET_KEY: ${OCI_AWS_SECRET_KEY:?OCI_AWS_SECRET_KEY is required}
    ports:
      - "${PORT:-18168}:${PORT:-18168}"
    volumes:
      - ./data:/app/data
    healthcheck:
      test: ["CMD-SHELL", "node -e \"const port=process.env.PORT||18168; fetch('http://127.0.0.1:' + port + '/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 20s
EOF

    echo -e "${YELLOW}正在通过 Docker Compose 启动 OCI-AWS...${RESET}"
    cd "$BASE_DIR" && docker compose up -d --force-recreate

    echo -e "${YELLOW}等待服务与权限初始化 (约3秒)...${RESET}"
    sleep 3

    echo -e "${GREEN}================================${RESET}"
    echo -e "${GREEN}        OCI-AWS 部署成功！      ${RESET}"
    echo -e "${GREEN}================================${RESET}"
    echo -e "${YELLOW}访问地址      : http://${DETECT_IP}:${custom_port}${RESET}"
    echo -e "${YELLOW}数据直挂路径  : $BASE_DIR/data${RESET}"
    echo -e "${YELLOW}环境配置文件  : $ENV_FILE${RESET}"
    echo -e "${YELLOW}Docker配置路径: $COMPOSE_FILE${RESET}"
    echo -e "${GREEN}================================${RESET}"
}

# 更新 OCI-AWS 镜像
update_utils() {
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        echo -e "${RED}错误: 未检测到配置文件，请先执行选项 1 进行部署！${RESET}"
        return
    fi
    echo -e "${YELLOW}正在从远端拉取 OCI-AWS 最新镜像并升级...${RESET}"
    cd "$BASE_DIR" && docker compose pull
    docker compose up -d --remove-orphans
    echo -e "${GREEN}更新完成！容器已处于最新状态。${RESET}"
}

# 卸载 OCI-AWS
uninstall_utils() {
    echo -e "${RED}警告: 卸载如果清理本地数据，将永久丢失您的 oci-aws 数据库配置！${RESET}"
    echo -ne "${YELLOW}确定要卸载并删除 OCI-AWS 容器吗？(y/n): ${RESET}"
    read -r confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        if [ -f "$COMPOSE_FILE" ]; then
            cd "$BASE_DIR" && docker compose down
            echo -e "${GREEN}容器已停止并移除。${RESET}"
            echo -ne "${RED}是否同时彻底删除本地全量挂载的 data 目录及 .env 配置文件？(y/n): ${RESET}"
            read -r clean_data
            if [ "$clean_data" = "y" ] || [ "$clean_data" = "Y" ]; then
                rm -rf "$BASE_DIR"
                echo -e "${GREEN}本地所有配置及数据已被彻底销毁。${RESET}"
            fi
        else
            docker rm -f "$CONTAINER_NAME" 2>/dev/null
        fi
        echo -e "${GREEN}卸载完成！${RESET}"
    fi
}

start_utils() { cd "$BASE_DIR" && docker compose start && echo -e "${GREEN}容器已启动${RESET}"; }
stop_utils() { cd "$BASE_DIR" && docker compose stop && echo -e "${YELLOW}容器已停止${RESET}"; }
restart_utils() { cd "$BASE_DIR" && docker compose restart && echo -e "${GREEN}容器已重启${RESET}"; }
logs_utils() { docker logs -f "$CONTAINER_NAME"; }

show_info() {
    get_status_info
    DETECT_IP=$(get_public_ip)
    [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
    echo -e "${GREEN}================================${RESET}"
    echo -e "${YELLOW}当前状态      : $status"
    echo -e "${YELLOW}镜像名称      : ${img_version}${RESET}"
    echo -e "${YELLOW}访问地址      : http://${DETECT_IP}:${PORT:-18168}${RESET}"
    echo -e "${YELLOW}环境变量路径  : $ENV_FILE${RESET}"
    echo -e "${YELLOW}配置文件路径  : $COMPOSE_FILE${RESET}"
    echo -e "${GREEN}================================${RESET}"
}

menu() {
    clear
    get_status_info
    echo -e "${GREEN}================================${RESET}"
    echo -e "${GREEN}     ◈  OCI-AWS 管理面板  ◈     ${RESET}"
    echo -e "${GREEN}================================${RESET}"
    echo -e "${GREEN}状态 :${RESET} $status"
    echo -e "${GREEN}端口 :${RESET} ${YELLOW}${port_display}${RESET}"
    echo -e "${GREEN}================================${RESET}"
    echo -e "${GREEN}1. 部署启动${RESET}"
    echo -e "${GREEN}2. 更新容器${RESET}"
    echo -e "${GREEN}3. 卸载容器${RESET}"
    echo -e "${GREEN}4. 启动容器${RESET}"
    echo -e "${GREEN}5. 停止容器${RESET}"
    echo -e "${GREEN}6. 重启容器${RESET}"
    echo -e "${GREEN}7. 查看日志${RESET}"
    echo -e "${GREEN}8. 查看配置${RESET}"
    echo -e "${GREEN}0. 退出${RESET}"
    echo -e "${GREEN}================================${RESET}"
    echo -ne "${GREEN}请输入选项: ${RESET}"
    read -r choice
    case "$choice" in
        1) install_utils ;;
        2) update_utils ;;
        3) uninstall_utils ;;
        4) start_utils ;;
        5) stop_utils ;;
        6) restart_utils ;;
        7) logs_utils ;;
        8) show_info ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项${RESET}" ;;
    esac
}

while true; do
    menu
    echo -ne "${YELLOW}按回车键继续...${RESET}"
    read -r
done