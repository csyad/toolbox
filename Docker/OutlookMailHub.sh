#!/bin/bash
# =================================================================
# Outlook Mail Manager Docker Compose 管理面板
# =================================================================

# 颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

CONTAINER_NAME="outlook-mail-manager"
BASE_DIR="/opt/outlook-mail-manager"
COMPOSE_FILE="$BASE_DIR/docker-compose.yml"
ENV_FILE="$BASE_DIR/.env"

# 检测依赖
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: 未检测到 Docker，请先安装 Docker！${RESET}"
        exit 1
    fi
}

# 格式化 URL 中的 IP (如果是 IPv6 则加上方括号 [])
format_ip_for_url() {
    local ip="$1"
    if [[ "$ip" == *":"* ]]; then
        echo "[$ip]"
    else
        echo "$ip"
    fi
}

# 动态获取容器状态
get_status_info() {
    if ! command -v docker &> /dev/null; then
        status="${RED}未安装 Docker${RESET}"
        img_version="${RED}未安装${RESET}"
        webui_port="N/A"
        return 0
    fi
    
    # 1. 检查容器状态
    if [ "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
        local health_status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$CONTAINER_NAME" 2>/dev/null)
        if [[ "$health_status" == "healthy" ]]; then
            status="${GREEN}运行中 (健康)${RESET}"
        elif [[ "$health_status" == "unhealthy" ]]; then
            status="${RED}运行中 (不健康)${RESET}"
        elif [[ "$health_status" == "starting" ]]; then
            status="${YELLOW}运行中 (启动中)${RESET}"
        else
            status="${GREEN}运行中${RESET}"
        fi
    elif [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
        status="${RED}已停止${RESET}"
    else
        status="${RED}未部署${RESET}"
    fi

    # 2. 如果容器存在，提取镜像版本与主机端口
    if [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
        img_version=$(docker inspect -f '{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null)
        [[ -z "$img_version" ]] && img_version="已安装"

        webui_port=$(docker inspect -f '{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' "$CONTAINER_NAME" 2>/dev/null)
        [[ -z "$webui_port" ]] && webui_port=$(docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{(index $conf 0).HostPort}}{{break}}{{end}}{{end}}' "$CONTAINER_NAME" 2>/dev/null)
        [[ -z "$webui_port" ]] && webui_port="8080"
    else
        img_version="${RED}未安装${RESET}"
        webui_port="N/A"
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

# 部署服务
install_app() {
    check_dependencies
    
    mkdir -p "$BASE_DIR"

    RAW_IP=$(get_public_ip)
    DETECT_IP=$(format_ip_for_url "$RAW_IP")

    echo -e "${CYAN}====== 自定义参数配置 ======${RESET}"
    echo -ne "${YELLOW}请输入 WebUI 访问端口 (宿主机端口) [默认: 8080]: ${RESET}"
    read -r custom_port
    [[ -z "$custom_port" ]] && custom_port="8080"
    if ! [[ "$custom_port" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误: 端口必须是纯数字！${RESET}"
        return
    fi

    echo -ne "${YELLOW}请输入站点访问根 URL (APP_BASE_URL) [默认: https://${DETECT_IP}:${custom_port}]: ${RESET}"
    read -r custom_base_url
    [[ -z "$custom_base_url" ]] && custom_base_url="https://${DETECT_IP}:${custom_port}"

    # 赋予项目目录权限
    chmod -R 777 "$BASE_DIR"

    # 1. 生成 .env 配置文件
    echo -e "${YELLOW}正在生成 .env 环境变量配置文件...${RESET}"
    cat <<EOF > "$ENV_FILE"
APP_BASE_URL=${custom_base_url}
APP_LISTEN_ADDR=:8080
APP_DATA_DIR=/data
APP_TIMEZONE=Asia/Shanghai
APP_LOG_LEVEL=info
GOMEMLIMIT=512MiB
GOGC=75
EOF

    # 2. 生成 docker-compose.yml 配置文件
    echo -e "${YELLOW}正在生成 docker-compose.yml 配置文件...${RESET}"
    cat <<EOF > "$COMPOSE_FILE"
services:
  app:
    image: \${APP_IMAGE:-ghcr.io/wyk335858575/outlook-mail-manager:1.1.3}
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped
    env_file:
      - .env
    environment:
      APP_LISTEN_ADDR: :8080
      APP_DATA_DIR: /data
      APP_VERSION: \${APP_VERSION:-1.1.3}
      APP_UPDATE_REPOSITORY: \${APP_UPDATE_REPOSITORY:-}
      APP_IMAGE: \${APP_IMAGE:-}
      GOMEMLIMIT: \${GOMEMLIMIT:-512MiB}
      GOGC: \${GOGC:-75}
    ports:
      - "${custom_port}:8080"
    volumes:
      - outlook_data:/data
    mem_limit: 768m
    read_only: true
    tmpfs:
      - /tmp:size=32m,mode=1777
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    healthcheck:
      test: ["CMD", "wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/healthz"]
      interval: 30s
      timeout: 3s
      start_period: 10s
      retries: 3
    logging:
      driver: json-file
      options:
        max-size: 10m
        max-file: "3"

volumes:
  outlook_data:
EOF

    echo -e "${YELLOW}正在通过 Docker Compose 启动服务...${RESET}"
    cd "$BASE_DIR" && docker compose up -d --force-recreate

    echo -e "${GREEN}====================================================${RESET}"
    echo -e "${GREEN}      Outlook Mail Manager 部署及启动成功！         ${RESET}"
    echo -e "${GREEN}====================================================${RESET}"
    echo -e "${YELLOW}服务访问地址 : http://${DETECT_IP}:${custom_port}${RESET}"
    echo -e "${YELLOW}环境变量文件 : ${ENV_FILE}${RESET}"
    echo -e "${YELLOW}配置文件路径 : ${COMPOSE_FILE}${RESET}"
    echo -e "${GREEN}====================================================${RESET}"
}

# 编辑 .env 文件
edit_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}错误: 未找到 .env 环境变量文件，请先进行部署！${RESET}"
        return
    fi
    
    if command -v nano &> /dev/null; then
        nano "$ENV_FILE"
    elif command -v vim &> /dev/null; then
        vim "$ENV_FILE"
    else
        vi "$ENV_FILE"
    fi
    
    echo -e "${YELLOW}修改完成后，是否立即重启服务使配置生效？(y/n): ${RESET}"
    read -r apply_now
    if [[ "$apply_now" == "y" || "$apply_now" == "Y" ]]; then
        cd "$BASE_DIR" && docker compose up -d
        echo -e "${GREEN}服务配置更新成功！${RESET}"
    fi
}

# 更新镜像
update_app() {
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        echo -e "${RED}错误: 未检测到配置文件，请先执行选项 1 进行部署！${RESET}"
        return
    fi
    echo -e "${YELLOW}正在从远端拉取最新镜像...${RESET}"
    cd "$BASE_DIR" && docker compose pull
    docker compose up -d --remove-orphans
    echo -e "${GREEN}更新完成！容器已处于最新状态。${RESET}"
}

# 卸载服务
uninstall_app() {
    echo -ne "${YELLOW}确定要卸载并删除 Outlook Mail Manager 容器吗？(y/n): ${RESET}"
    read -r confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        if [ -f "$COMPOSE_FILE" ]; then
            cd "$BASE_DIR" && docker compose down -v
            echo -e "${GREEN}容器与 Docker Volume 数据已彻底清理。${RESET}"
            echo -ne "${YELLOW}是否同时删除项目所在本地目录？(y/n): ${RESET}"
            read -r clean_data
            if [[ "$clean_data" == "y" || "$clean_data" == "Y" ]]; then
                rm -rf "$BASE_DIR"
                echo -e "${GREEN}项目目录已彻底删除。${RESET}"
            fi
        else
            docker rm -f "$CONTAINER_NAME" 2>/dev/null
        fi
        echo -e "${GREEN}卸载完成！${RESET}"
    fi
}

start_app() { cd "$BASE_DIR" && docker compose start && echo -e "${GREEN}容器已启动${RESET}"; }
stop_app() { cd "$BASE_DIR" && docker compose stop && echo -e "${YELLOW}容器已停止${RESET}"; }
restart_app() { cd "$BASE_DIR" && docker compose restart && echo -e "${GREEN}容器已重启${RESET}"; }
logs_app() { 
    echo -e "${CYAN}--- 容器当前运行日志 (按 Ctrl+C 退出查看) ---${RESET}"
    docker logs -f "$CONTAINER_NAME"; 
}

show_info() {
    get_status_info
    RAW_IP=$(get_public_ip)
    DETECT_IP=$(format_ip_for_url "$RAW_IP")
    echo -e "${GREEN}========================================${RESET}"
    echo -e "${YELLOW}当前状态     : $status"
    echo -e "${YELLOW}镜像名称     : ${img_version}${RESET}"
    echo -e "${YELLOW}服务访问地址 : http://${DETECT_IP}:${webui_port}${RESET}"
    echo -e "${YELLOW}项目目录路径 : ${BASE_DIR}${RESET}"
    echo -e "${YELLOW}环境配置文件 : ${ENV_FILE}${RESET}"
    echo -e "${GREEN}========================================${RESET}"
}

menu() {
    clear
    get_status_info
    echo -e "${GREEN}====================================${RESET}"
    echo -e "${GREEN} ◈ Outlook Mail Manager 管理面板 ◈ ${RESET}"
    echo -e "${GREEN}====================================${RESET}"
    echo -e "${GREEN}状态 :${RESET} $status"
    echo -e "${GREEN}端口 :${RESET} ${YELLOW}${webui_port}${RESET}"
    echo -e "${GREEN}====================================${RESET}"
    echo -e "${GREEN}1. 部署启动${RESET}"
    echo -e "${GREEN}2. 更新容器${RESET}"
    echo -e "${GREEN}3. 卸载容器${RESET}"
    echo -e "${GREEN}4. 启动容器${RESET}"
    echo -e "${GREEN}5. 停止容器${RESET}"
    echo -e "${GREEN}6. 重启容器${RESET}"
    echo -e "${GREEN}7. 查看日志${RESET}"
    echo -e "${GREEN}8. 查看配置${RESET}"
    echo -e "${GREEN}0. 退出${RESET}"
    echo -e "${GREEN}====================================${RESET}"
    echo -ne "${GREEN}请输入选项: ${RESET}"
    read -r choice
    case "$choice" in
        1) install_app ;;
        2) update_app ;;
        3) uninstall_app ;;
        4) start_app ;;
        5) stop_app ;;
        6) restart_app ;;
        7) logs_app ;;
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