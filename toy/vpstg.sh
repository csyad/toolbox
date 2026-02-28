#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

menu() {
    clear
    echo -e "${GREEN}=== VPS信息通知 ===${RESET}"
    echo -e "${GREEN}1) 系统信息${RESET}"
    echo -e "${GREEN}2) 网卡信息${RESET}"
    echo -e "${GREEN}3) Docker信息${RESET}"
    echo -e "${GREEN}0) 退出${RESET}"
    read -p $'\033[32m请选择操作: \033[0m' choice
    case $choice in
        1)
            echo -e "${GREEN}正在运行系统信息脚本...${RESET}"
            bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/vpsxin.sh)
            pause
            ;;
        2)
            echo -e "${GREEN}正在运行网卡信息脚本...${RESET}"
            bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/network.sh)
            pause
            ;;
        3)
            echo -e "${GREEN}正在运行Docker信息脚本...${RESET}"
            bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/vpsd.sh)
            pause
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择，请重新输入${RESET}"
            sleep 1
            menu
            ;;
    esac
}

pause() {
    read -p $'\033[32m按回车键返回菜单...\033[0m'
    menu
}

menu
