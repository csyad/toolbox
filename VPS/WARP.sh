#!/bin/bash
# VPS SWAP 管理脚本 (默认添加 1G)

SWAP_FILE="/swapfile"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
RESET="\033[0m"
BOLD="\033[1m"

menu() {
    clear
    CUR_SWAP=$(free -h | awk '/Swap:/ {print $2}')
    if [ "$CUR_SWAP" = "0B" ] || [ "$CUR_SWAP" = "0" ]; then
        STATUS="未启用"
    else
        STATUS="已启用 (${CUR_SWAP})"
    fi

    echo -e "${GREEN}====== VPS SWAP 管理 =========${RESET}"
    echo -e "${GREEN}当前 SWAP 状态: ${YELLOW}${STATUS}${RESET}"
    echo -e "${GREEN}==============================${RESET}"
    echo -e "${GREEN}1. 添加SWAP(默认1G)${RESET}"
    echo -e "${GREEN}2. 删除SWAP${RESET}"
    echo -e "${GREEN}3. 查看SWAP${RESET}"
    echo -e "${GREEN}0. 退出${RESET}"
    read -p "$(echo -e ${GREEN}请输入选项: ${RESET})" choice
    case $choice in
        1) add_swap ;;
        2) del_swap ;;
        3) view_swap ;;
        0) exit 0 ;;
        *) echo -e "${RED}❌ 无效选项${RESET}"; read -p "按回车返回菜单..." ; menu ;;
    esac
}

add_swap() {
    read -p "请输入要添加的 SWAP 大小(单位G, 默认1): " SWAP_SIZE
    SWAP_SIZE=${SWAP_SIZE:-1}  # 默认 1G

    swapoff -a 2>/dev/null
    [ -f $SWAP_FILE ] && rm -f $SWAP_FILE

    fallocate -l ${SWAP_SIZE}G $SWAP_FILE || dd if=/dev/zero of=$SWAP_FILE bs=1M count=$((SWAP_SIZE*1024))
    chmod 600 $SWAP_FILE
    mkswap $SWAP_FILE
    swapon $SWAP_FILE

    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    fi

    echo "✅ 已成功添加 ${SWAP_SIZE}G SWAP"
    read -p "按回车返回菜单..." 
    menu
}

del_swap() {
    swapoff -a 2>/dev/null
    sed -i "\|$SWAP_FILE|d" /etc/fstab
    [ -f $SWAP_FILE ] && rm -f $SWAP_FILE
    echo "✅ 已删除 SWAP"
    read -p "按回车返回菜单..." 
    menu
}

view_swap() {
    echo "========== 系统 SWAP 状态 =========="
    free -h
    swapon --show
    echo "==================================="
    read -p "按回车返回菜单..." 
    menu
}

menu
