#!/bin/bash

# ==========================================
# 系统快照 & 备份管理菜单（全绿字体）
# ==========================================

GREEN='\033[0;32m'
NC='\033[0m'

while true; do
    clear
    echo -e "${GREEN}===================================${NC}"
    echo -e "${GREEN}     系统快照 & 备份管理菜单        ${NC}"
    echo -e "${GREEN}===================================${NC}"
    echo -e "${GREEN}1) SSH密钥自动配置${NC}"
    echo -e "${GREEN}2) 安装快照备份${NC}"
    echo -e "${GREEN}3) 本地系统快照恢复${NC}"
    echo -e "${GREEN}4) 远程系统快照恢复${NC}"
    echo -e "${GREEN}5) 卸载快照备份${NC}"
    echo -e "${GREEN}0) 退出${NC}"
    read -p "$(echo -e ${GREEN}请选择操作: ${NC})" choice

    case $choice in
        1)
            echo -e "${GREEN}执行 SSH密钥自动配置...${NC}"
            bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/ssh.sh)
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
        2)
            echo -e "${GREEN}安装快照备份...${NC}"
            bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/system_snapshot.sh)
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
        3)
            echo -e "${GREEN}本地系统快照恢复...${NC}"
            bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/local_restore.sh)
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
        4)
            echo -e "${GREEN}远程系统快照恢复...${NC}"
            bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/remote.sh)
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
        5)
            echo -e "${GREEN}卸载快照备份...${NC}"
            bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/uninstall_snapshot.sh)
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${GREEN}无效选项，请重新输入${NC}"
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
    esac
done
