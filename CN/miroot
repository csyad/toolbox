#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

ENABLE_URL="https://v6.gh-proxy.org/https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/xgroot.sh"
DISABLE_URL="https://v6.gh-proxy.org/https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/SSHpassword.sh"

run_script() {
    url=$1
    name=$2

    echo -e "${GREEN}正在执行：${name}${RESET}"
    bash <(curl -fsSL "$url")
    pause
}

pause() {
    read -p $'\033[32m按回车返回菜单...\033[0m'
    menu
}

menu() {
    clear
    echo -e "${GREEN}================================${RESET}"
    echo -e "${GREEN}        root 密码登录管理           ${RESET}"
    echo -e "${GREEN}================================${RESET}"
    echo -e "${GREEN} 1) 设置root密码登录${RESET}"
    echo -e "${GREEN} 2) 管理root密码登录${RESET}"
    echo -e "${GREEN} 0) 退出${RESET}"
    read -p $'\033[32m 请选择: \033[0m' choice

    case $choice in
        1) run_script "$ENABLE_URL" "设置 Root 密码登录" ;;
        2) run_script "$DISABLE_URL" "管理 Root 密码登录" ;;
        0) exit 0 ;;
        *)
            echo -e "${RED}输入错误${RESET}"
            sleep 1
            menu
            ;;
    esac
}

menu
