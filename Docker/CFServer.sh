#!/bin/bash
# ==========================================
# CFServer 管理脚本（绿色菜单版）
# ==========================================

set -e

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

green(){ echo -e "${GREEN}$1${RESET}"; }
yellow(){ echo -e "${YELLOW}$1${RESET}"; }
red(){ echo -e "${RED}$1${RESET}"; }

CF_DIR="/opt/cfserver"
SCRIPT_NAME="cfserver.sh"

# 获取服务器IP
SERVER_IP=$(hostname -I | awk '{print $1}')

install_cf() {

    green "正在下载并执行部署脚本..."
    curl -sS -O https://raw.githubusercontent.com/woniu336/open_shell/main/cfserver.sh
    chmod +x cfserver.sh
    ./cfserver.sh

    # 可选自定义重置 token
    yellow "是否现在自定义重置访问令牌？(y/n)"
    read -p "$(echo -e ${GREEN}请选择: ${RESET})" choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        cd /opt/cfserver || { red "目录不存在！"; return; }
        read -p "$(echo -e ${GREEN}请输入新的访问令牌（留空取消）: ${RESET})" CUSTOM_TOKEN
        if [ -n "$CUSTOM_TOKEN" ]; then
            ./dns-server -reset-token "$CUSTOM_TOKEN"
            green "✅ 访问令牌已重置为：$CUSTOM_TOKEN"
        else
            yellow "未输入 token，跳过重置"
        fi
    fi

    # 启动服务
    green "正在重启服务..."
    cd /opt/cfserver || { red "目录不存在！"; return; }
    pkill dns-server 2>/dev/null
    nohup ./dns-server > /dev/null 2>&1 &
    sleep 2
    green "服务已启动！"

    echo ""
    green "🌐 Web 管理地址："
    echo ""
    echo "   http://${SERVER_IP}:8081"
    echo ""
    green "========================================"
}

uninstall_cf() {
    yellow "停止 CFServer 服务..."
    pkill dns-server 2>/dev/null || echo "服务未运行"

    yellow "删除程序文件 ${CF_DIR} ..."
    if [ -d "${CF_DIR}" ]; then
        rm -rf "${CF_DIR}"
        green "程序文件已删除"
    else
        red "目录 ${CF_DIR} 不存在"
    fi

    yellow "删除安装脚本 ${SCRIPT_NAME} ..."
    if [ -f "./${SCRIPT_NAME}" ]; then
        rm -f "./${SCRIPT_NAME}"
        green "安装脚本已删除"
    else
        red "安装脚本不存在"
    fi

    green "✅ CFServer 已卸载完成"
    
    exit 0
}

reset_token() {
    if [ ! -d "${CF_DIR}" ]; then
        red "CFServer 未安装！"
        return
    fi

    cd "${CF_DIR}" || return
    read -p "$(echo -e ${GREEN}请输入新的访问令牌（token）: ${RESET})" CUSTOM_TOKEN
    [ -z "$CUSTOM_TOKEN" ] && { red "未输入 token，操作取消"; return; }

    if [ -x "./dns-server" ]; then
        ./dns-server -reset-token "$CUSTOM_TOKEN"
        green "✅ 令牌已重置为：$CUSTOM_TOKEN"
    else
        red "dns-server 文件不存在或不可执行"
    fi
}

start_service() {
    cd "${CF_DIR}" || { red "CFServer 未安装！"; return; }
    pkill dns-server 2>/dev/null
    nohup ./dns-server > /dev/null 2>&1 &
    green "✅ 服务已重启"
}


menu() {
    while true; do
        clear
        echo ""
        echo -e "${GREEN}==== CFServer 管理菜单 ====${RESET}"
        echo -e "${GREEN}1) 安装${RESET}"
        echo -e "${GREEN}2) 重置访问令牌${RESET}"
        echo -e "${GREEN}3) 重启${RESET}"
        echo -e "${GREEN}4) 卸载${RESET}"
        echo -e "${GREEN}0) 退出${RESET}"
        read -p "$(echo -e ${GREEN}请选择操作: ${RESET})" choice
        choice=$(echo "$choice" | xargs)  # 去掉空格

        case $choice in
            1) install_cf ;;
            2) reset_token ;;
            3) start_service ;;
            4) uninstall_cf ;;
            0) 
                exit 0 ;;
            *) red "无效选项，请重新输入" ;;
        esac

        echo -e "${YELLOW}按回车继续...${RESET}"
        read
    done
}

menu
