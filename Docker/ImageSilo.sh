#!/bin/bash
# =================================================================
# ImageSilo Docker Compose 管理面板 
# =================================================================

# 颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

CONTAINER_NAME="imagesilo"
BASE_DIR="/opt/imagesilo"
COMPOSE_FILE="$BASE_DIR/docker-compose.yml"
ENV_FILE="$BASE_DIR/.env"

# 检测依赖
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: 未检测到 Docker，请先安装 Docker！${RESET}"
        exit 1
    fi
}

# 动态获取容器状态并联动健康检查
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

    # 2. 如果容器存在，从容器状态中提取信息
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

# 部署 imagesilo 并初始化默认配置
install_imagesilo() {
    check_dependencies
    
    echo -e "${CYAN}====== 自定义参数配置 ======${RESET}"
    echo -ne "${YELLOW}请输入数据存放路径 [默认: /opt/imagesilo/data]: ${RESET}"
    read -r custom_data_dir
    [[ -z "$custom_data_dir" ]] && custom_data_dir="$BASE_DIR/data"

    # 自动创建基础路径及数据目录
    mkdir -p "$BASE_DIR"
    mkdir -p "$custom_data_dir"

    echo -e "${YELLOW}正在为数据目录配置完全读写权限...${RESET}"
    chmod -R 777 "$custom_data_dir"

    echo -ne "${YELLOW}请输入服务访问端口 (宿主机端口) [默认: 8080]: ${RESET}"
    read -r custom_port
    [[ -z "$custom_port" ]] && custom_port="8080"
    if ! [[ "$custom_port" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误: 端口必须是纯数字！${RESET}"
        return
    fi

    echo -ne "${YELLOW}请输入处理并发数 IMAGESILO_PROCESSING_CONCURRENCY [默认: 1]: ${RESET}"
    read -r custom_proc_concurrency
    [[ -z "$custom_proc_concurrency" ]] && custom_proc_concurrency="1"

    echo -ne "${YELLOW}请输入分发并发数 IMAGESILO_DELIVERY_CONCURRENCY [默认: 0]: ${RESET}"
    read -r custom_del_concurrency
    [[ -z "$custom_del_concurrency" ]] && custom_del_concurrency="0"

    echo -ne "${YELLOW}是否启用代理信任 IMAGESILO_TRUST_PROXY_HEADERS (true/false) [默认: true]: ${RESET}"
    read -r custom_trust_proxy
    [[ -z "$custom_trust_proxy" ]] && custom_trust_proxy="true"

    echo -ne "${YELLOW}是否启用安全 Cookie IMAGESILO_COOKIE_SECURE (true/false) [默认: true]: ${RESET}"
    read -r custom_cookie_secure
    [[ -z "$custom_cookie_secure" ]] && custom_cookie_secure="true"

    # 生成 .env 配置文件
    echo -e "${YELLOW}正在生成 .env 配置文件...${RESET}"
    cat <<EOF > "$ENV_FILE"
IMAGESILO_PORT=$custom_port
IMAGESILO_DATA_DIR=$custom_data_dir
IMAGESILO_PROCESSING_CONCURRENCY=$custom_proc_concurrency
IMAGESILO_DELIVERY_CONCURRENCY=$custom_del_concurrency
IMAGESILO_MIGRATION_MUTATIONS=false
IMAGESILO_TRUST_PROXY_HEADERS=$custom_trust_proxy
IMAGESILO_COOKIE_SECURE=$custom_cookie_secure
EOF

    # 生成符合标准模板的 docker-compose.yml 配置文件
    echo -e "${YELLOW}正在生成符合标准模板的 docker-compose.yml 配置文件...${RESET}"
    cat <<EOF > "$COMPOSE_FILE"
services:
  imagesilo:
    image: ghcr.io/willxup/imagesilo:latest
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped
    ports:
      - "127.0.0.1:\${IMAGESILO_PORT:-8080}:8080"
    environment:
      IMAGESILO_DATA_DIR: /data
      IMAGESILO_LISTEN_ADDRESS: :8080
      IMAGESILO_PROCESSING_CONCURRENCY: \${IMAGESILO_PROCESSING_CONCURRENCY:-1}
      IMAGESILO_DELIVERY_CONCURRENCY: \${IMAGESILO_DELIVERY_CONCURRENCY:-0}
      IMAGESILO_MIGRATION_MUTATIONS: \${IMAGESILO_MIGRATION_MUTATIONS:-false}
      IMAGESILO_TRUST_PROXY_HEADERS: \${IMAGESILO_TRUST_PROXY_HEADERS:-true}
      IMAGESILO_SHUTDOWN_TIMEOUT: 10s
      IMAGESILO_COOKIE_SECURE: \${IMAGESILO_COOKIE_SECURE:-true}
    volumes:
      - ${custom_data_dir}:/data
    stop_grace_period: 20s

volumes:
  imagesilo-data:
EOF

    echo -e "${YELLOW}正在通过 Docker Compose 启动 imagesilo 服务...${RESET}"
    cd "$BASE_DIR" && docker compose --env-file "$ENV_FILE" up -d --force-recreate

    echo -e "${GREEN}====================================================${RESET}"
    echo -e "${GREEN}            ImageSilo 部署及启动成功！              ${RESET}"
    echo -e "${GREEN}====================================================${RESET}"
    echo -e "${YELLOW}本地监听端口 : ${custom_port}${RESET}"
    echo -e "${YELLOW}本地访问地址 : 127.0.0.1:${custom_port}${RESET}"
    echo -e "${YELLOW}数据存放目录 : $custom_data_dir${RESET}"
    echo -e "${YELLOW}配置文件路径 : $ENV_FILE${RESET}"
    echo -e "${GREEN}====================================================${RESET}"
}

# 更新镜像
update_imagesilo() {
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        echo -e "${RED}错误: 未检测到配置文件，请先执行选项 1 进行部署！${RESET}"
        return
    fi
    echo -e "${YELLOW}正在从远端拉取最新镜像...${RESET}"
    cd "$BASE_DIR" && docker compose --env-file "$ENV_FILE" pull
    docker compose --env-file "$ENV_FILE" up -d --remove-orphans
    echo -e "${GREEN}更新完成！容器已处于最新状态。${RESET}"
}

# 卸载服务
uninstall_imagesilo() {
    echo -ne "${YELLOW}确定要卸载并删除 imagesilo 容器吗？(y/n): ${RESET}"
    read -r confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        if [ -f "$COMPOSE_FILE" ]; then
            cd "$BASE_DIR" && docker compose --env-file "$ENV_FILE" down
            echo -e "${GREEN}容器已停止并移除。${RESET}"
            echo -ne "${YELLOW}是否同时删除所有本地配置文件及数据目录？(y/n): ${RESET}"
            read -r clean_data
            if [ "$clean_data" = "y" ] || [ "$clean_data" = "Y" ]; then
                rm -rf "$BASE_DIR"
                echo -e "${GREEN}配置及本地数据目录已彻底清理。${RESET}"
            fi
        else
            docker rm -f "$CONTAINER_NAME" 2>/dev/null
        fi
        echo -e "${GREEN}卸载完成！${RESET}"
    fi
}

start_imagesilo() { cd "$BASE_DIR" && docker compose --env-file "$ENV_FILE" start && echo -e "${GREEN}容器已启动${RESET}"; }
stop_imagesilo() { cd "$BASE_DIR" && docker compose --env-file "$ENV_FILE" stop && echo -e "${YELLOW}容器已停止${RESET}"; }
restart_imagesilo() { cd "$BASE_DIR" && docker compose --env-file "$ENV_FILE" restart && echo -e "${GREEN}容器已重启${RESET}"; }
logs_imagesilo() { 
    echo -e "${CYAN}--- imagesilo 容器当前运行日志 (按 Ctrl+C 退出查看) ---${RESET}"
    docker logs -f "$CONTAINER_NAME"; 
}

show_info() {
    get_status_info
    
    local env_port="8080"
    local env_data_dir="$BASE_DIR/data"
    if [[ -f "$ENV_FILE" ]]; then
        local p_val=$(grep "^IMAGESILO_PORT=" "$ENV_FILE" | cut -d'=' -f2-)
        [[ -n "$p_val" ]] && env_port="$p_val"
        local custom_dir_val=$(grep "^IMAGESILO_DATA_DIR=" "$ENV_FILE" | cut -d'=' -f2-)
        [[ -n "$custom_dir_val" ]] && env_data_dir="$custom_dir_val"
    fi

    echo -e "${GREEN}========================================${RESET}"
    echo -e "${YELLOW}当前状态     : $status"
    echo -e "${YELLOW}镜像名称     : ${img_version}${RESET}"
    echo -e "${YELLOW}访问地址     : 127.0.0.1:${env_port}${RESET}"
    echo -e "${YELLOW}数据本地路径 : ${env_data_dir}${RESET}"
    echo -e "${YELLOW}配置文件路径 : ${ENV_FILE}${RESET}"
    echo -e "${GREEN}========================================${RESET}"
}

menu() {
    clear
    get_status_info
    echo -e "${GREEN}==============================${RESET}"
    echo -e "${GREEN}  ◈  ImageSilo  管理面板  ◈   ${RESET}"
    echo -e "${GREEN}==============================${RESET}"
    echo -e "${GREEN}状态 :${RESET} $status"
    echo -e "${GREEN}端口 :${RESET} ${YELLOW}${webui_port}${RESET}"
    echo -e "${GREEN}==============================${RESET}"
    echo -e "${GREEN}1. 部署启动${RESET}"
    echo -e "${GREEN}2. 更新容器${RESET}"
    echo -e "${GREEN}3. 卸载容器${RESET}"
    echo -e "${GREEN}4. 启动容器${RESET}"
    echo -e "${GREEN}5. 停止容器${RESET}"
    echo -e "${GREEN}6. 重启容器${RESET}"
    echo -e "${GREEN}7. 查看日志${RESET}"
    echo -e "${GREEN}8. 查看配置${RESET}"
    echo -e "${GREEN}0. 退出${RESET}"
    echo -e "${GREEN}==============================${RESET}"
    echo -ne "${GREEN}请输入选项: ${RESET}"
    read -r choice
    case "$choice" in
        1) install_imagesilo ;;
        2) update_imagesilo ;;
        3) uninstall_imagesilo ;;
        4) start_imagesilo ;;
        5) stop_imagesilo ;;
        6) restart_imagesilo ;;
        7) logs_imagesilo ;;
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