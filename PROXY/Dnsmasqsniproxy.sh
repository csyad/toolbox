#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

SCRIPT_URL="https://raw.githubusercontent.com/myxuchangbin/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy.sh"

menu() {
    clear
    echo -e "${GREEN}=== DnsmasqSNIproxy-One-click ===${RESET}"
    echo -e "${GREEN}1) 安装${RESET}"
    echo -e "${GREEN}2) 卸载${RESET}"
    echo -e "${GREEN}0) 退出${RESET}"
    read -p $'\033[32m请选择操作: \033[0m' choice
    case $choice in
        1)
            echo -e "${GREEN}正在安装 DnsmasqSNIproxy-One-click...${RESET}"
            wget --no-check-certificate -O dnsmasq_sniproxy.sh $SCRIPT_URL
            bash dnsmasq_sniproxy.sh -f
            pause
            ;;
        2)
            echo -e "${GREEN}正在卸载 DnsmasqSNIproxy-One-click...${RESET}"
            wget --no-check-certificate -O dnsmasq_sniproxy.sh $SCRIPT_URL
            bash dnsmasq_sniproxy.sh -u
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
