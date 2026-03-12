#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

menu() {
    clear
    echo -e "${GREEN}=== 系统监控管理菜单 ===${RESET}"
    echo -e "${GREEN} 1) 查看端口${RESET}"
    echo -e "${GREEN} 2) 释放端口${RESET}"
    echo -e "${GREEN} 3) 查看进程${RESET}"
    echo -e "${GREEN} 4) 删除进程${RESET}"
    echo -e "${GREEN} 5) 查看自启动服务${RESET}"
    echo -e "${GREEN} 6) 自启动服务管理${RESET}"
    echo -e "${GREEN} 7) 删除文件${RESET}"
    echo -e "${GREEN} 8) 国家IP屏蔽${RESET}"
    echo -e "${GREEN} 9) 查看磁盘占用${RESET}"
    echo -e "${GREEN}10) 安全扫描${RESET}"
    echo -e "${GREEN} 0) 退出${RESET}"
    read -p $'\033[32m 请选择操作: \033[0m' choice
    case $choice in
        1)
            echo -e "${GREEN}正在查看端口...${RESET}"
            bash <(curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/port.sh)
            pause
            ;;
        2)
            echo -e "${GREEN}正在释放端口...${RESET}"
            bash <(curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/killport.sh)
            pause
            ;;
        3)
            echo -e "${GREEN}正在查看进程...${RESET}"
            bash <(curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/psaux.sh)
            pause
            ;;
        4)
            echo -e "${GREEN}正在删除进程...${RESET}"
            bash <(curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/killprocess.sh)
            pause
            ;;
        5)
            echo -e "${GREEN}正在查看自启动服务...${RESET}"
            bash <(curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/service.sh)
            pause
            ;;
        6)
            echo -e "${GREEN}正在管理自启动服务...${RESET}"
            bash <(curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/killservice.sh)
            pause
            ;;
        7)
            echo -e "${GREEN}正在删除文件...${RESET}"
            bash <(curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/rmdocument.sh)
            pause
            ;;
        8)
            echo -e "${GREEN}正在国家IP屏蔽...${RESET}"
            bash <(curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/GeoFirewall.sh)
            pause
            ;;
        9)
            echo -e "${GREEN}正在查看磁盘占用...${RESET}"
            bash <(curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/DHGL.sh)
            pause
            ;;
        10)
            echo -e "${GREEN}正在安全扫描...${RESET}"
            bash <(curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/Security.sh)
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
