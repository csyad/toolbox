#!/bin/bash
# =================================================================
# VpsCT 系统 (GitHub 克隆 + Docker Compose) 自动化管理面板
# =================================================================

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

APP_NAME="ctlvpsd"
BASE_DIR="/opt/vpsct"
SRC_DIR="$BASE_DIR" 
REPO_URL="https://github.com/YongshengWin/VpsCT.git"

# 确保基础路径存在
mkdir -p "$BASE_DIR"

# 检测依赖
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: 未检测到 Docker，请先安装 Docker！${RESET}"
        exit 1
    fi
    if ! command -v git &> /dev/null; then
        echo -e "${RED}错误: 未检测到 Git，请先安装 Git！${RESET}"
        exit 1
    fi
}

# 动态获取服务端口与运行状态
get_status_info() {
    local container_id=$(docker ps -q -f "name=${APP_NAME}" -f "status=running" 2>/dev/null)

    if [[ -n "$container_id" ]]; then
        status="${GREEN}运行中${RESET}"
        webui_port=$(docker inspect -f '{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' "$container_id" 2>/dev/null)
        [[ -z "$webui_port" ]] && webui_port="8080"
    else
        if [ -d "$SRC_DIR/.git" ]; then
            status="${RED}已停止${RESET}"
        else
            status="${RED}未部署${RESET}"
        fi
        webui_port="N/A"
    fi
}

# 获取公网 IP
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

# 部署核心逻辑
install_vpsct() {
    check_dependencies

    echo -e "${CYAN}====== 1. 基础配置 ======${RESET}"
    
    echo -ne "${YELLOW}请输入 VpsCT 宿主机映射端口 [默认: 8080]: ${RESET}"
    read -r custom_port
    [[ -z "$custom_port" ]] && custom_port="8080"

    echo -ne "${YELLOW}请输入监听地址 [默认: 127.0.0.1:8080]: ${RESET}"
    read -r custom_listen
    [[ -z "$custom_listen" ]] && custom_listen="127.0.0.1:8080"

    echo -ne "${YELLOW}请输入面板站点 URL [默认: https://panel.example.com]: ${RESET}"
    read -r site_url
    [[ -z "$site_url" ]] && site_url="https://panel.example.com"

    # 克隆官方仓库到当前工作目录
    if [ ! -d "$SRC_DIR/.git" ]; then
        echo -e "\n${YELLOW}正在克隆官方 VpsCT GitHub 仓库...${RESET}"
        git clone "$REPO_URL" "$SRC_DIR/tmp_repo"
        if [ $? -eq 0 ]; then
            mv "$SRC_DIR/tmp_repo/"* "$SRC_DIR/" 2>/dev/null
            mv "$SRC_DIR/tmp_repo/."* "$SRC_DIR/" 2>/dev/null
            rm -rf "$SRC_DIR/tmp_repo"
        else
            echo -e "${RED}错误: 仓库克隆失败，请检查网络！${RESET}"
            exit 1
        fi
    else
        echo -e "\n${GREEN}检测到本地已存在官方仓库，正在同步最新代码...${RESET}"
        cd "$SRC_DIR" && git pull
    fi

    cd "$SRC_DIR"

    # 自动生成 .env 配置文件
    cat <<EOF > .env
CTLVPS_SITE_URL=${site_url}
CTLVPS_LISTEN=${custom_listen}
CTLVPS_DATA_DIR=/opt/ctlvps/data
CTLVPS_AGENT_BIN_DIR=/opt/ctlvps/agents
CTLVPS_TRUST_PROXY=true
CTLVPS_LOG_LEVEL=info
TZ=Asia/Shanghai
EOF

    # 动态写入 docker-compose.yml 确保端口与配置适配
    cat <<EOF > docker-compose.yml
services:
  ctlvpsd:
    image: ctlvps:latest
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ctlvpsd
    restart: unless-stopped
    ports:
      - "${custom_port}:8080"
    environment:
      CTLVPS_SITE_URL: \${CTLVPS_SITE_URL}
      CTLVPS_LISTEN: \${CTLVPS_LISTEN}
      CTLVPS_DATA_DIR: \${CTLVPS_DATA_DIR}
      CTLVPS_AGENT_BIN_DIR: \${CTLVPS_AGENT_BIN_DIR}
      CTLVPS_TRUST_PROXY: \${CTLVPS_TRUST_PROXY}
      CTLVPS_LOG_LEVEL: \${CTLVPS_LOG_LEVEL}
      TZ: \${TZ}
    volumes:
      - ctlvps-data:/data
    logging:
      driver: json-file
      options:
        max-size: "20m"
        max-file: "3"
    deploy:
      resources:
        limits:
          memory: 512M

volumes:
  ctlvps-data:
EOF

    # 编译并启动镜像
    echo -e "\n${YELLOW}正在编译并启动 VpsCT 容器...${RESET}"
    docker compose up -d --build

    echo -e "${YELLOW}正在等待容器拉起服务 (约 5 秒)...${RESET}"
    sleep 5

    get_status_info
    DETECT_IP=$(get_public_ip)
    echo -e "${GREEN}====================================================${RESET}"
    echo -e "${GREEN}        VpsCT 服务编译并启动成功！         ${RESET}"
    echo -e "${GREEN}====================================================${RESET}"
    echo -e "${YELLOW}访问地址 : http://${DETECT_IP}:${custom_port}${RESET}"
    echo -e "${YELLOW}站点 URL : ${site_url}${RESET}"
    echo -e "${YELLOW}监听配置 : ${custom_listen}${RESET}"
    echo -e "${YELLOW}项目所在路径 : ${SRC_DIR}${RESET}"
    echo -e "${GREEN}====================================================${RESET}"
}

# 重新 Build 更新
update_vpsct() {
    if [ ! -d "$SRC_DIR/.git" ]; then
        echo -e "${RED}错误: 未检测到克隆的仓库，请先执行选项 1！${RESET}"
        return
    fi

    echo -e "${YELLOW}正在同步最新的远程代码...${RESET}"
    cd "$SRC_DIR" && git pull
    
    echo -e "${YELLOW}正在重新编译镜像并平滑更新...${RESET}"
    docker compose up -d --build --remove-orphans
    echo -e "${GREEN}VpsCT 更新并重编完成！${RESET}"
}

# 彻底卸载
uninstall_vpsct() {
    echo -ne "${RED}确定要停止并卸载 VpsCT 容器服务吗？(y/n): ${RESET}"
    read -r confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        if [ -d "$SRC_DIR/.git" ]; then
            cd "$SRC_DIR" && docker compose down
            echo -e "${GREEN}容器与网络已被安全停止并移除。${RESET}"
            echo -ne "${YELLOW}是否同步连根拔除本地【源码及 Docker 持久化数据卷】？(y/n): ${RESET}"
            read -r clean_data
            if [ "$clean_data" = "y" ] || [ "$clean_data" = "Y" ]; then
                docker volume rm vpsct_ctlvps-data 2>/dev/null
                rm -rf "$BASE_DIR"
                echo -e "${GREEN}本地所有源码与持久化数据已被彻底清除！${RESET}"
            fi
        else
            echo -e "${YELLOW}未检测到运行中的 compose 环境，跳过删除。${RESET}"
        fi
    fi
}

# 容器集群控制
start_vpsct() { cd "$SRC_DIR" && docker compose start && echo -e "${GREEN}服务已全面启动${RESET}"; }
stop_vpsct() { cd "$SRC_DIR" && docker compose stop && echo -e "${YELLOW}服务已安全停止${RESET}"; }
restart_vpsct() { cd "$SRC_DIR" && docker compose restart && echo -e "${GREEN}服务已平滑重启${RESET}"; }
logs_vpsct() { cd "$SRC_DIR" && docker compose logs -f --tail=100; }

show_info() {
    get_status_info
    local DETECT_IP=$(get_public_ip)
    echo -e "${GREEN}====================================================${RESET}"
    echo -e "${YELLOW}服务运行状态     : $status"
    echo -e "${YELLOW}控制台访问地址   : http://${DETECT_IP}:${webui_port}${RESET}"
    echo -e "${GREEN}====================================================${RESET}"
}

# 菜单入口
menu() {
    clear
    get_status_info
    echo -e "${GREEN}===================================${RESET}"
    echo -e "${GREEN}       ◈  VpsCT 管理面板  ◈       ${RESET}"
    echo -e "${GREEN}===================================${RESET}"
    echo -e "${GREEN}服务状态 :${RESET} $status"
    echo -e "${GREEN}服务端口 :${RESET} ${YELLOW}${webui_port}${RESET}"
    echo -e "${GREEN}===================================${RESET}"
    echo -e "${GREEN}1. 部署启动${RESET}"
    echo -e "${GREEN}2. 更新容器${RESET}"
    echo -e "${GREEN}3. 卸载容器${RESET}"
    echo -e "${GREEN}4. 启动容器${RESET}"
    echo -e "${GREEN}5. 停止容器${RESET}"
    echo -e "${GREEN}6. 重启容器${RESET}"
    echo -e "${GREEN}7. 查看日志${RESET}"
    echo -e "${GREEN}8. 查看配置${RESET}"
    echo -e "${GREEN}0. 退出${RESET}"
    echo -e "${GREEN}===================================${RESET}"
    echo -ne "${GREEN}请输入选项: ${RESET}"
    read -r choice
    case "$choice" in
        1) install_vpsct ;;
        2) update_vpsct ;;
        3) uninstall_vpsct ;;
        4) start_vpsct ;;
        5) stop_vpsct ;;
        6) restart_vpsct ;;
        7) logs_vpsct ;;
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