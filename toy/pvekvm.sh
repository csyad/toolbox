#!/bin/bash
# ========================================
# PVE 虚拟机一键管理脚本（国内/国外自动判断）
# Author: oneclickvirt 改
# ========================================

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

# 自动判断国内外源
check_source() {
    if ping -c 1 -W 1 google.com >/dev/null 2>&1; then
        echo "github"
    else
        echo "cdn"
    fi
}

# 下载脚本函数
download_scripts() {
    SOURCE=$(check_source)
    if [ "$SOURCE" = "github" ]; then
        BASE_URL="https://raw.githubusercontent.com/oneclickvirt/pve/main/scripts"
        echo -e "${GREEN}检测到国外环境，使用 GitHub 源下载${RESET}"
    else
        BASE_URL="https://cdn.spiritlhl.net/https://raw.githubusercontent.com/oneclickvirt/pve/main/scripts"
        echo -e "${GREEN}检测到国内环境，使用 CDN 源下载${RESET}"
    fi

    if [ ! -f buildvm.sh ]; then
        echo -e "${YELLOW}未找到 buildvm.sh，正在下载...${RESET}"
        curl -L ${BASE_URL}/buildvm.sh -o buildvm.sh && chmod +x buildvm.sh
    fi

    if [ ! -f pve_delete.sh ]; then
        echo -e "${YELLOW}未找到 pve_delete.sh，正在下载...${RESET}"
        curl -L ${BASE_URL}/pve_delete.sh -o pve_delete.sh && chmod +x pve_delete.sh
    fi
}

# 开设虚拟机
create_vm() {
    echo -e "${CYAN}请输入开设虚拟机所需参数:${RESET}"
    read -p "VMID(100~256): " VMID
    read -p "用户名(英文开头): " USERNAME
    read -p "密码(英文数字组合): " PASSWORD
    read -p "CPU核数: " CPU
    read -p "内存(MB): " MEM
    read -p "硬盘(GB): " DISK
    read -p "SSH端口: " SSHPORT
    read -p "80端口(默认留空): " PORT80
    read -p "443端口(默认留空): " PORT443
    read -p "外网端口起: " STARTPORT
    read -p "外网端口止: " ENDPORT
    read -p "系统(如 debian11 ubuntu20): " OS
    read -p "存储盘(如 local): " STORAGE
    read -p "独立IPV6地址(留空默认N): " IPV6

    ./buildvm.sh $VMID $USERNAME $PASSWORD $CPU $MEM $DISK $SSHPORT ${PORT80:-0} ${PORT443:-0} $STARTPORT $ENDPORT $OS $STORAGE ${IPV6:-N}
}

# 删除指定虚拟机
delete_vm() {
    read -p "请输入要删除的 VMID (可输入多个, 空格分隔): " VMIDS
    ./pve_delete.sh $VMIDS
}

# 查看虚拟机信息
check_vm() {
    read -p "请输入要查看的 VMID: " VMID
    if [ -f vm${VMID} ]; then
        cat vm${VMID}
    else
        echo -e "${RED}未找到 VMID ${VMID} 的信息文件${RESET}"
    fi
}

# 删除所有虚拟机
delete_all_vms() {
    echo -e "${RED}⚠️ 警告：此操作将删除所有虚拟机、清空 NAT 规则并重置网络！${RESET}"
    read -p "确认执行？(yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        echo -e "${YELLOW}正在删除所有虚拟机...${RESET}"
        for vmid in $(qm list | awk '{if(NR>1) print $1}'); do
            qm stop $vmid >/dev/null 2>&1
            qm destroy $vmid >/dev/null 2>&1
            rm -rf /var/lib/vz/images/$vmid*
        done

        echo -e "${YELLOW}清空防火墙规则...${RESET}"
        iptables -t nat -F
        iptables -t filter -F

        echo -e "${YELLOW}重启网络服务...${RESET}"
        service networking restart
        systemctl restart networking.service
        systemctl restart ndpresponder.service

        echo -e "${YELLOW}保存 iptables 配置...${RESET}"
        iptables-save | awk '{if($1=="COMMIT"){delete x}}$1=="-A"?!x[$0]++:1' | iptables-restore
        iptables-save > /etc/iptables/rules.v4

        echo -e "${YELLOW}清理日志和 VM 信息文件...${RESET}"
        rm -rf vmlog
        rm -rf vm*

        echo -e "${GREEN}✅ 所有虚拟机和端口映射已删除，网络已重置${RESET}"
    else
        echo -e "${GREEN}已取消操作${RESET}"
    fi
}

# 主菜单
menu() {
    clear
    echo -e "${GREEN}========================================${RESET}"
    echo -e "${GREEN}      PVE容器 KVM 管理菜单               ${RESET}"
    echo -e "${GREEN}========================================${RESET}"
    echo -e "${GREEN}1) 开设虚拟机${RESET}"
    echo -e "${GREEN}2) 删除指定虚拟机${RESET}"
    echo -e "${GREEN}3) 查看虚拟机信息${RESET}"
    echo -e "${GREEN}4) 删除所有虚拟机${RESET}"
    echo -e "${GREEN}0) 退出"
    read -r -p $'\033[32m请输入选项: \033[0m' choice
    case $choice in
        1) create_vm ;;
        2) delete_vm ;;
        3) check_vm ;;
        4) delete_all_vms ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项，请重新输入${RESET}" ;;
    esac
    echo -e "${YELLOW}按任意键返回菜单...${RESET}"
    read -n 1
    menu
}

# 运行
download_scripts
menu
