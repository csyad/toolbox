#!/bin/bash
# ========================================
# 代理协议一键菜单（一级+二级分类版）
# 二级菜单 0 返回 | x 退出 | 自动补零 | 循环菜单
# ========================================

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
RESET="\033[0m"
BOLD="\033[1m"
ORANGE='\033[38;5;208m'

SCRIPT_PATH="/etc/proxy.sh"
SCRIPT_URL="https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/proxy.sh"
BIN_LINK_DIR="/usr/local/bin"


# =============================
# GitHub 代理镜像组（轮询模式）
# =============================
GITHUB_PROXY=(
    ''
    'https://v6.gh-proxy.org/'
    'https://ghfast.top/'
    'https://gh-proxy.com/'
    'https://hub.glowp.xyz/'
    'https://proxy.vvvv.ee/'
    'https://ghproxy.lvedong.eu.org/'
)

# 初始化轮询索引计数器
PROXY_INDEX=0


# 轮询转换 GitHub 链接为镜像链接
proxy_url() {
    local raw_url="$1"
    local total_proxies=${#GITHUB_PROXY[@]}
    
    # 获取当前索引对应的代理
    local proxy="${GITHUB_PROXY[$PROXY_INDEX]}"
    
    # 轮询索引自增，超过最大值则归零
    PROXY_INDEX=$(( (PROXY_INDEX + 1) % total_proxies ))
    
    if [[ -z "$proxy" ]]; then
        # 干净利落地只返回原始 URL，绝不掺杂任何多余的 echo 换行
        echo "$raw_url"
    else
        # 提示信息必须严格重定向到标准错误 >&2，确保不污染变量捕获
        echo -e "${YELLOW}[轮询提示] 当前切换至代理: ${proxy}${RESET}" >&2
        if [[ "$raw_url" == *"raw.githubusercontent.com"* || "$raw_url" == *"github.com"* ]]; then
            echo "${proxy}${raw_url}"
        else
            echo "$raw_url"
        fi
    fi
}

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用 root 权限运行！${RESET}"
    exit 1
fi


# =============================
# 首次运行自动安装
# =============================
if [ ! -f "$SCRIPT_PATH" ]; then
    install_url=$(proxy_url "$SCRIPT_URL")

    if curl -fsSL -o "$SCRIPT_PATH" "$install_url"; then
        chmod +x "$SCRIPT_PATH"
        ln -sf "$SCRIPT_PATH" "$BIN_LINK_DIR/f"
        ln -sf "$SCRIPT_PATH" "$BIN_LINK_DIR/F"
        echo -e "${GREEN}✅ 安装完成${RESET}"
        echo -e "${GREEN}✅ 快捷键：F 或 f 可快速启动${RESET}"
    else
        echo -e "${RED}❌ 初始化失败，请检查网络或更换代理！${RESET}"
        exit 1
    fi
fi
# =============================
# 自动补零
# =============================
format_choice() {
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        printf "%02d" "$1"
    else
        echo "$1"
    fi
}
# =============================
# 通用菜单读取（一级用）
# =============================
read_mainmenu() {
    echo -ne "${RED}请输入分类编号 ${RESET}"
    read choice

    choice=$(echo "$choice" | xargs)

    [[ "$choice" =~ ^[xX]$ ]] && exit 0
    [[ "$choice" == "0" || "$choice" == "00" ]] && exit 0

    choice=$(format_choice "$choice")
}

# =============================
# 通用二级菜单读取逻辑
# =============================
read_submenu() {
    echo -ne "${RED}请输入代理编号: ${RESET}"
    read sub

    sub=$(echo "$sub" | xargs)

    [[ "$sub" =~ ^[xX]$ ]] && exit 0
    [[ "$sub" == "0" || "$sub" == "00" ]] && return 1

    sub=$(format_choice "$sub")
    return 0
}

pause_return() {
    read -p "$(echo -e ${GREEN}按回车返回菜单...${RESET})"
}



# 核心状态检测函数（按关键字模糊匹配）
get_status() {
    local name=$1 # 传入 "sing-box" 或 "xray"
    local keyword=""
    
    # 根据传入的目标，定义模糊匹配的关键字
    if [ "$name" = "xray" ]; then
        keyword="vless|xray"  # 只要包含 vless 或 xray 都算
    else
        keyword="singbox|sing-box" # 包含 singbox 或 sing-box 都算
    fi
    
    # 1. 检查 Docker 容器状态 (容器名包含关键字)
    if command -v docker >/dev/null 2>&1; then
        if docker ps --format '{{.Names}}' | grep -Ei "(${keyword})" >/dev/null 2>&1; then
            echo -e "${YELLOW}运行中(Docker)${RESET}"
            return 0
        fi
    fi

    # 2. 检查 Systemd 服务状态 (常规 Linux 服务名包含关键字)
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl list-units --type=service --state=running 2>/dev/null | grep -Ei "(${keyword})" >/dev/null 2>&1; then
            echo -e "${YELLOW}运行中(Service)${RESET}"
            return 0
        fi
    fi

    # 3. 检查 OpenRC 服务状态 (Alpine Linux 运行中的服务)
    if command -v rc-status >/dev/null 2>&1; then
        if rc-status -s 2>/dev/null | grep "started" | grep -Ei "(${keyword})" >/dev/null 2>&1; then
            echo -e "${YELLOW}运行中(OpenRC)${RESET}"
            return 0
        fi
    fi

    # 4. 🚀 核心改动：纯进程检测 (只要进程命令行里包含关键字就算)
    # 使用 ps -ef 抓取所有进程，-i 忽略大小写，-E 支持正则表达式
    if ps -ef 2>/dev/null | grep -v grep | grep -Ei "(${keyword})" >/dev/null 2>&1; then
        echo -e "${YELLOW}运行中(Process)${RESET}"
        return 0
    fi

    # 所有检查都未通过
    echo -e "${RED}未运行${RESET}"
}

# =============================
# 一级菜单
# =============================
main_menu() {
    clear
    # 动态获取核心状态
    local singbox_status=$(get_status "sing-box")
    local xray_status=$(get_status "xray")
    echo -e "${ORANGE}╔═════════════════════════╗${RESET}"
    echo -e "${ORANGE}  代理工具箱${RESET}${YELLOW}(快捷指令:F/f)  ${RESET}"
    echo -e "${ORANGE}╚═════════════════════════╝${RESET}"
    echo -e "${GREEN}📦 sing-box :${RESET} ${singbox_status}"
    echo -e "${GREEN}📦 Xray     :${RESET} ${xray_status}"
    echo -e "${ORANGE}---------------------------${RESET}"
    echo -e "${YELLOW}[01] 单协议安装${RESET}"
    echo -e "${YELLOW}[02] 多协议安装${RESET}"
    echo -e "${YELLOW}[03] 面板管理类${RESET}"
    echo -e "${YELLOW}[04] 转发管理类${RESET}"
    echo -e "${YELLOW}[05] 组网管理类${RESET}"
    echo -e "${YELLOW}[06] 网络优化类${RESET}"
    echo -e "${YELLOW}[07] 媒体解锁类${RESET}"
    echo -e "${YELLOW}[08] 监控通知类${RESET}"
    echo -e "${YELLOW}[09] 核心卸载${RESET}"
    echo -e "${YELLOW}[10] 核心检测${RESET}"
    echo -e "${GREEN}[88] 更新${RESET}"
    echo -e "${GREEN}[99] 卸载${RESET}"
    echo -e "${YELLOW}[00] 退出${RESET}"

    read_mainmenu

    case "$choice" in
        01) protocol_menu ;;
        02) protocols_menu ;;
        03) panel_menu ;;
        04) zfpanel_menu ;;
        05) zwpanel_menu ;;
        06) network_menu ;;
        07) dns_menu ;;
        08) monitor_menu ;;
        09) uninstall_core_menu ;;
        10) check_panel ; pause_return ;;
        88) update_script ; pause_return ;;
        99) uninstall_script ;;
        00) exit 0 ;;
        *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
    esac
}

# =============================
# 单协议类
# =============================
protocol_menu() {
while true; do
    clear
    echo -e "${ORANGE}╔══════════════════════╗${RESET}"
    echo -e "${ORANGE}      单协议安装类        ${RESET}"
    echo -e "${ORANGE}╚══════════════════════╝${RESET}"
    echo -e "${YELLOW}[01] Shadowsocks${RESET}"
    echo -e "${YELLOW}[02] SS+ShadowTLS${RESET}"
    echo -e "${YELLOW}[03] Snellv5${RESET}"
    echo -e "${YELLOW}[04] Snellv5+ShadowTLS${RESET}"
    echo -e "${YELLOW}[05] Reality${RESET}"
    echo -e "${YELLOW}[06] Hysteria2${RESET}"
    echo -e "${YELLOW}[07] Anytls${RESET}"
    echo -e "${YELLOW}[08] Anytls+Reality${RESET}"
    echo -e "${YELLOW}[09] Tuicv5${RESET}"
    echo -e "${YELLOW}[10] MTProto${RESET}"
    echo -e "${YELLOW}[11] MTProto(Docker)${RESET}"
    echo -e "${YELLOW}[12] Socks5${RESET}"
    echo -e "${YELLOW}[13] HTTP${RESET}"
    echo -e "${YELLOW}[14] NaïveProxy${RESET}"
    echo -e "${YELLOW}[15] Xray-Argo${RESET}"
    echo -e "${YELLOW}[15] Vmess-ws${RESET}"
    echo -e "${YELLOW}[17] Vless-httpupgrade${RESET}"
    echo -e "${YELLOW}[18] Vless-ws-tls${RESET}"
    echo -e "${YELLOW}[19] Vless-Reality-xhttp${RESET}"
    echo -e "${YELLOW}[20] Vless-Encryption${RESET}"
    echo -e "${YELLOW}[21] Vless-Encryption-Reality${RESET}"
    echo -e "${YELLOW}[22] Snellv6${RESET}"
    echo -e "${YELLOW}[23] Snellv6+ShadowTLS${RESET}"
    echo -e "${GREEN}[0]  返回${RESET}"
    echo -e "${GREEN}[x]  退出${RESET}"

    read_submenu || return

    case "$sub" in
        01) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/SSRustos.sh")) ;;
        02) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/SSShadowTLSos.sh")) ;;
        03) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Snellos.sh")) ;;
        04) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/SnellShadowTLSos.sh")) ;;
        05) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/VlessRealityos.sh")) ;;
        06) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Hy2os.sh")) ;;
        07) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/SB-AnyTLSos.sh")) ;;
        08) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/AnyRealityos.sh")) ;;
        09) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Tuicv5os.sh")) ;;
        10) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/MTProtoos.sh")) ;;
        11) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/MTProtoDS.sh")) ;;
        12) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/nextsocks5os.sh")) ;;
        13) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Xary-HTTPos.sh")) ;;
        14) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/NaiveProxyos.sh")) ;;
        15) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/2go.sh")) ;;
        16) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Vmesswsos.sh")) ;;
        17) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Vlesshttpupgradeos.sh")) ;;
        18) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Vlesswstlsos.sh")) ;;
        19) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/VlessRealityxhttpos.sh")) ;;
        20) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/VlessEncryptionos.sh")) ;;
        21) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/VlessEncryptionRealityos.sh")) ;;
        22) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Snellv6os.sh")) ;;
        23) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Snellv6ShadowTLSos.sh")) ;;
        *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
    esac
done
}

# =============================
# 多协议类
# =============================
protocols_menu() {
while true; do
    clear
    echo -e "${ORANGE}╔══════════════════════╗${RESET}"
    echo -e "${ORANGE}      多协议安装类        ${RESET}"
    echo -e "${ORANGE}╚══════════════════════╝${RESET}"
    echo -e "${YELLOW}[01] Sing-box         fscarmen${RESET}"
    echo -e "${YELLOW}[02] Sing-box         233boy${RESET}"
    echo -e "${YELLOW}[03] Xray-2go         SS${RESET}"
    echo -e "${YELLOW}[04] Sing-box         多用户管理${RESET}"
    echo -e "${YELLOW}[05] vless-all-in-one 多协议代理${RESET}"
    echo -e "${GREEN}[0]  返回${RESET}"
    echo -e "${GREEN}[x]  退出${RESET}"

    read_submenu || return

    case "$sub" in
        01) bash <(wget -qO- $(proxy_url "https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh")) ;;
        02) bash <(wget -qO- -o- $(proxy_url "https://github.com/233boy/sing-box/raw/main/install.sh")) ; pause_return ;;
        03) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/Luckylos/xray-2go/refs/heads/main/xray_2go.sh")) ;;
        04) wget -O sb.sh $(proxy_url "https://raw.githubusercontent.com/Tangfffyx/sing-box/main/sb.sh") && bash sb.sh ;;
        05) wget -O vless-server.sh $(proxy_url "https://raw.githubusercontent.com/mozisen/surge/main/vless-server.sh") && chmod +x vless-server.sh && ./vless-server.sh ;;
        *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
    esac
done
}

# =============================
# 二级菜单：面板类
# =============================
panel_menu() {
while true; do
    clear
    echo -e "${ORANGE}╔══════════════════════╗${RESET}"
    echo -e "${ORANGE}      面板管理类        ${RESET}"
    echo -e "${ORANGE}╚══════════════════════╝${RESET}"
    echo -e "${YELLOW}[01] 3X-UI      Xray面板${RESET}"
    echo -e "${YELLOW}[02] S-UI       Singbox面板${RESET}"
    echo -e "${YELLOW}[03] Xboard     机场面板${RESET}"
    echo -e "${YELLOW}[04] PPanel     机场面板${RESET}"
    echo -e "${YELLOW}[05] Remnawave  节点管理${RESET}"
    echo -e "${YELLOW}[06] 妙妙屋X    节点管理${RESET}"
    echo -e "${YELLOW}[07] XrayR      机场后端 ${RESET}"
    echo -e "${YELLOW}[08] Conflux    Mihomo代理${RESET}"
    echo -e "${YELLOW}[09] OneBoard   Mihomo代理${RESET}"
    echo -e "${YELLOW}[10] AimiliVPN  干净IP出口${RESET}"
    echo -e "${YELLOW}[11] MiGate     代理面板${RESET}"
    echo -e "${YELLOW}[12] 1S-UI      代理面板${RESET}"
    echo -e "${YELLOW}[13] 2S-UI      代理面板${RESET}"
    echo -e "${GREEN}[0]  返回${RESET}"
    echo -e "${GREEN}[x]  退出${RESET}"
    
    read_submenu || return

    case "$sub" in
        01) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/3xuios.sh")) ; pause_return ;;
        02) bash <(curl -Ls https://s-ui.alireza0.dev/install.sh) ; pause_return ;;
        03) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/Xboard.sh")) ;;
        04) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/PPanel.sh")) ;;
        05) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/Remnawave.sh")) ;;
        06) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/MiaoMiaoWuX.sh")) ;;
        07) bash <(curl -Ls https://raw.githubusercontent.com/JackHONGhy/xrayr-automated-install-script/master/install.sh) ; pause_return ;;
        08) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/Conflux.sh")) ;;
        09) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/OneBoard.sh")) ;;
        10) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/baoweise-bot/aimili-vpngate/main/install.sh")) ; pause_return ;;
        11) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/MiGate.sh")) ;;
        12) bash <(curl -Ls https://raw.githubusercontent.com/Hhz0823/1s-ui/main/install.sh) ; pause_return ;;
        13) bash <(curl -Ls https://raw.githubusercontent.com/shenaba/2s-ui/main/install.sh) ; pause_return ;;
        0) return ;;
        *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
    esac
done
}

# =============================
# 二级菜单：转发类
# =============================
zfpanel_menu() {
while true; do
    clear
    echo -e "${ORANGE}╔══════════════════════╗${RESET}"
    echo -e "${ORANGE}      转发管理类        ${RESET}"
    echo -e "${ORANGE}╚══════════════════════╝${RESET}"
    echo -e "${YELLOW}[01] EZGost      Gost转发${RESET}"
    echo -e "${YELLOW}[02] Realm-xwPF  Realm转发${RESET}"
    echo -e "${YELLOW}[03] hia-realm   Realm转发${RESET}"
    echo -e "${YELLOW}[04] Zelay       Realm转发面板${RESET}"
    echo -e "${YELLOW}[05] RelayPanel  端口转发面板${RESET}"
    echo -e "${YELLOW}[06] ForwardX    端口转发面板${RESET}"
    echo -e "${YELLOW}[07] nft-forward 端口转发面板${RESET}"
    echo -e "${YELLOW}[08] 哆啦A梦     Gost转发面板${RESET}"
    echo -e "${YELLOW}[09] FLVX        Gost转发面板${RESET}"
    echo -e "${YELLOW}[10] NodePass    隧道转发面板${RESET}"
    echo -e "${GREEN}[0]  返回${RESET}"
    echo -e "${GREEN}[x]  退出${RESET}"
    
    read_submenu || return

    case "$sub" in
        01) wget --no-check-certificate -O gost.sh $(proxy_url "https://raw.githubusercontent.com/qqrrooty/EZgost/main/gost.sh") && chmod +x gost.sh && ./gost.sh ; pause_return ;;
        02) wget -qO- $(proxy_url "https://raw.githubusercontent.com/zywe03/realm-xwPF/main/xwPF.sh") | sudo bash -s install ; pause_return ;;
        03) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/hiapb/hia-realm/main/install.sh")) ;;
        04) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/Zelay.sh")) ;;
        05) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/RelayPanel.sh")) ;;
        06) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/ForwardX.sh")) ;;
        07) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/xjetry/nft-forward/main/install.sh")) ; pause_return ;;
        08) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/flux-panel.sh")) ;;
        09) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/flvx-panel.sh")) ;;
        10) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/NodePassDash.sh")) ;;
        0) return ;;
        *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
    esac
done
}

# =============================
# 二级菜单：组网类
# =============================
zwpanel_menu() {
while true; do
    clear
    echo -e "${ORANGE}╔══════════════════════╗${RESET}"
    echo -e "${ORANGE}      组网管理类        ${RESET}"
    echo -e "${ORANGE}╚══════════════════════╝${RESET}"
    echo -e "${YELLOW}[01] WireGuard  WireGuard组网${RESET}"
    echo -e "${YELLOW}[02] WG-Easy    WireGuard面板${RESET}"
    echo -e "${YELLOW}[03] Link42     WireGuard多节点面板${RESET}"
    echo -e "${YELLOW}[04] Easytier   Easytier组网${RESET}"
    echo -e "${YELLOW}[05] FRP-Panel  FRP面板${RESET}"
    echo -e "${GREEN}[0]  返回${RESET}"
    echo -e "${GREEN}[x]  退出${RESET}"
    
    read_submenu || return
  

    case "$sub" in
        01) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/WireGuard.sh")) ;;
        02) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/wg-easy.sh")) ;;
        03) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/Link42.sh")) ;;
        04) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/EasyTierD.sh")) ;;
        05) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/frp-Panel.sh")) ;;
        0) return ;;
        *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
    esac
done
}
# =============================
# 网络优化
# =============================
network_menu() {
while true; do
    clear
    echo -e "${ORANGE}╔══════════════════════╗${RESET}"
    echo -e "${ORANGE}      网络优化类        ${RESET}"
    echo -e "${ORANGE}╚══════════════════════╝${RESET}"
    echo -e "${YELLOW}[01] tcpx         BBR管理${RESET}"
    echo -e "${YELLOW}[02] BBRv3        Eric86777${RESET}"
    echo -e "${YELLOW}[03] nekoneko     TCP窗口调优${RESET}"
    echo -e "${YELLOW}[04] CFWARP       fscarmen${RESET}"
    echo -e "${YELLOW}[05] MicroWARP    DockerCFWARP${RESET}"
    echo -e "${YELLOW}[06] warp-rust    CFWARP${RESET}"
    echo -e "${YELLOW}[07] he-tunnel    HE隧道${RESET}"
    echo -e "${YELLOW}[08] Tun2Socksos  全局出口${RESET}"
    echo -e "${YELLOW}[09] Redsocks     透明代理${RESET}"
    echo -e "${YELLOW}[10] IP屏蔽       屏蔽国内IP${RESET}"
    echo -e "${YELLOW}[11] Realmtimeout Realm优化${RESET}"
    echo -e "${YELLOW}[12] WARP-monitor 状态监控与自动修复${RESET}"
    echo -e "${GREEN}[0]  返回${RESET}"
    echo -e "${GREEN}[x]  退出${RESET}"
    
    read_submenu || return

    case "$sub" in
        01) wget --no-check-certificate -O tcpx.sh $(proxy_url "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcpx.sh") && chmod +x tcpx.sh && ./tcpx.sh ; pause_return ;;
        02) bash <(curl -fsSL "$(proxy_url "https://raw.githubusercontent.com/Eric86777/vps-tcp-tune/main/install-alias.sh?")$(date +%s)") ; pause_return ;;
        03) wget http://sh.nekoneko.cloud/tools.sh -O tools.sh && bash tools.sh ; pause_return ;;
        04) wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh ;;
        05) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/MicroWARP.sh")) ;;
        06) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/WARP-Rustos.sh")) ;;
        07) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/HES.sh")) ;;
        08) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Tun2Socksos.sh")) ;;
        09) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Redsocksos.sh")) ;;
        10) curl -fsSL $(proxy_url "https://raw.githubusercontent.com/Henry00123/china_blocker/main/china_blocker.sh") -o china_blocker.sh && chmod +x china_blocker.sh && sudo ./china_blocker.sh ;;
        11) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/Realmtimeout.sh")) ;;
        12) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/WARPmonitor.sh")) ;;
        0) return ;;
        *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
    esac
done
}

# =============================
# DNS 类
# =============================
dns_menu() {
while true; do
    clear
    echo -e "${ORANGE}╔══════════════════════╗${RESET}"
    echo -e "${ORANGE}      流媒体解锁类      ${RESET}"
    echo -e "${ORANGE}╚══════════════════════╝${RESET}"
    echo -e "${YELLOW}[01] WARP  谷歌定位解锁${RESET}"
    echo -e "${YELLOW}[02] DNS   分流管理面板${RESET}"
    echo -e "${YELLOW}[03] AKDNS 流媒体解锁${RESET}"
    echo -e "${GREEN}[0]  返回${RESET}"
    echo -e "${GREEN}[x]  退出${RESET}"
    
    read_submenu || return
   

    case "$sub" in
        01) bash <(curl -fsSL https://vpszdm.com/warp-google.sh) ;;
        02) wget -O install.sh $(proxy_url "https://raw.githubusercontent.com/mslxi/Liquid-Glass-Prism-dns/main/install.sh") && sudo bash install.sh ; pause_return ;;
        03) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/akile-network/aktools/main/akdns.sh")) ;;
        0) return ;;
        *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
    esac
done
}

# =============================
# 二级菜单：Docker单协议类
# ===========================
docker_menu() {
while true; do
    clear
    echo -e "${ORANGE}╔══════════════════════╗${RESET}"
    echo -e "${ORANGE}      Docker单协议类     ${RESET}"
    echo -e "${ORANGE}╚══════════════════════╝${RESET}"
    echo -e "${YELLOW}[01] SS2022${RESET}"
    echo -e "${YELLOW}[02] SS2022+TLS${RESET}"
    echo -e "${YELLOW}[03] Reality${RESET}"
    echo -e "${YELLOW}[04] Snell${RESET}"
    echo -e "${YELLOW}[05] Snell+TLS${RESET}"
    echo -e "${YELLOW}[06] Vmess+WS+TLS${RESET}"
    echo -e "${YELLOW}[07] Anytls${RESET}"
    echo -e "${YELLOW}[08] Hysteria2${RESET}"
    echo -e "${YELLOW}[09] Tuicv5${RESET}"
    echo -e "${YELLOW}[10] MTProto${RESET}"
    echo -e "${YELLOW}[11] Socks5${RESET}"
    echo -e "${YELLOW}[12] Vmess+WS${RESET}"
    echo -e "${YELLOW}[13] Realityxhttp${RESET}"
    echo -e "${YELLOW}[14] AnyReality${RESET}"
    echo -e "${YELLOW}[15] Vless+httpupgrade${RESET}"
    echo -e "${GREEN}[0]  返回${RESET}"
    echo -e "${GREEN}[x]  退出${RESET}"
    
    read_submenu || return

    case "$sub" in
        01) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/SSRust2022D.sh")) ; pause_return ;;
        02) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/SSRust-tlsD.sh")) ; pause_return ;;
        03) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Xray-RealityD.sh")) ; pause_return ;;
        04) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/snell-serverD.sh")) ; pause_return ;;
        05) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/snelltls-serverD.sh")) ; pause_return ;;
        06) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Xray-VmesswstlsD.sh")) ; pause_return ;;
        07) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/AnyTLSD.sh")) ; pause_return ;;
        08) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/hysteria2D.sh")) ; pause_return ;;
        09) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Singbox-TUICv5D.sh")) ; pause_return ;;
        10) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/MTProtoD.sh")) ; pause_return ;;
        11) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Xray-Socks5D.sh")) ; pause_return ;;
        12) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Xray-VmesswsD.sh")) ; pause_return ;;
        13) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Xray-RealityxhttpD.sh")) ; pause_return ;;
        14) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Singbox-AnyRealityD.sh")) ; pause_return ;;
        15) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Xray-VlesshttpD.sh")) ; pause_return ;;
        0) return ;;
        *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
    esac
done
}

# =============================
# 二级菜单：Docker多协议类
# =============================
dockers_menu() {
while true; do
    clear
    echo -e "${ORANGE}╔══════════════════════╗${RESET}"
    echo -e "${ORANGE}      Docker多协议类     ${RESET}"
    echo -e "${ORANGE}╚══════════════════════╝${RESET}"
    echo -e "${YELLOW}[01] SS2022${RESET}"
    echo -e "${YELLOW}[02] SS2022+TLS${RESET}"
    echo -e "${YELLOW}[03] Reality${RESET}"
    echo -e "${YELLOW}[04] Snell${RESET}"
    echo -e "${YELLOW}[05] Snell+TLS${RESET}"
    echo -e "${YELLOW}[06] Vmess+WS+TLS${RESET}"
    echo -e "${YELLOW}[07] Anytls${RESET}"
    echo -e "${YELLOW}[08] Hysteria2${RESET}"
    echo -e "${YELLOW}[09] Tuicv5${RESET}"
    echo -e "${YELLOW}[10] MTProto${RESET}"
    echo -e "${YELLOW}[11] Socks5${RESET}"
    echo -e "${YELLOW}[12] Vmess+WS${RESET}"
    echo -e "${YELLOW}[13] Realityxhttp${RESET}"
    echo -e "${YELLOW}[14] AnyReality${RESET}"
    echo -e "${YELLOW}[15] Vless+httpupgrade${RESET}"
    echo -e "${GREEN}[0]  返回${RESET}"
    echo -e "${GREEN}[x]  退出${RESET}"
    
    read_submenu || return

    case "$sub" in
        01) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/SSRust2022GLD.sh")) ; pause_return ;;
        02) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/SSRust-tlsGLD.sh")) ; pause_return ;;
        03) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Xray-RealityGLD.sh")) ; pause_return ;;
        04) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/snell-serverGLD.sh")) ; pause_return ;;
        05) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/snelltls-serverGLD.sh")) ; pause_return ;;
        06) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Xray-VmesswstlsGLD.sh")) ; pause_return ;;
        07) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/AnyTLSGLD.sh")) ; pause_return ;;
        08) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/hysteria2GLD.sh")) ; pause_return ;;
        09) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Singbox-TUICv5GLD.sh")) ; pause_return ;;
        10) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/MTProtoGLD.sh")) ; pause_return ;;
        11) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Xray-Socks5GLD.sh")) ; pause_return ;;
        12) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Xray-VmesswsGLD.sh")) ; pause_return ;;
        13) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Xray-RealityxhttpGLD.sh")) ; pause_return ;;
        14) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Singbox-AnyRealityGLD.sh")) ; pause_return ;;
        15) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/Dockerproxy/Xray-VlesshttpGLD.sh")) ; pause_return ;;
        0) return ;;
        *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
    esac
done
}


# =============================
# 监控通知 类
# =============================
monitor_menu() {
while true; do
    clear
    echo -e "${ORANGE}╔══════════════════════╗${RESET}"
    echo -e "${ORANGE}      监控通知类        ${RESET}"
    echo -e "${ORANGE}╚══════════════════════╝${RESET}"
    echo -e "${YELLOW}[01] IP-Sentinel       送中拉回${RESET}"
    echo -e "${YELLOW}[02] TrafficCop        流量监控${RESET}"
    echo -e "${YELLOW}[03] Traffic-dog       端口流量狗${RESET}"
    echo -e "${YELLOW}[04] S-UITraffic       S-UI流量管理${RESET}"
    echo -e "${YELLOW}[05] VnstatTG          流量日报${RESET}"
    echo -e "${YELLOW}[06] DDDNS             动态DNS管理工具${RESET}"
    echo -e "${YELLOW}[07] trafficcop-lite   流量监控${RESET}"
    echo -e "${GREEN}[0]  返回${RESET}"
    echo -e "${GREEN}[x]  退出${RESET}"
    
    read_submenu || return
   

    case "$sub" in
        01) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/IP-Sentinel.sh")) ;;
        02) bash <(curl -fsSL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/TrafficCop.sh")) ;;
        03) wget -O port-traffic-dog.sh $(proxy_url "https://raw.githubusercontent.com/zywe03/realm-xwPF/main/port-traffic-dog.sh") && chmod +x port-traffic-dog.sh && ./port-traffic-dog.sh ;;
        04) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/S-UITrafficReset.sh")) ;;
        05) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/OS/vnstattgos.sh")) ;;
        06) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/CFDDNSManager.sh")) ;;
        07) wget -O trafficcop-lite.sh $(proxy_url "https://raw.githubusercontent.com/duya07/trafficcop-lite/main/trafficcop-lite.sh") && chmod +x trafficcop-lite.sh && ./trafficcop-lite.sh --install && sudo ntc ;;
        0) return ;;
        *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
    esac
done
}

# =============================
# 核心状态检测
# =============================
check_panel() {
    clear
    echo -e "${ORANGE}╔══════════════════════════╗${RESET}"
    echo -e "${ORANGE}       核心状态检测          ${RESET}"
    echo -e "${ORANGE}╚══════════════════════════╝${RESET}"
    echo ""

    format_status() {
        case "$1" in
            active) echo -e "${GREEN}运行中${RESET}" ;;
            inactive|failed) echo -e "${YELLOW}未运行${RESET}" ;;
            *) echo -e "${RED}未安装${RESET}" ;;
        esac
    }

    get_ports() {
        ss -tulnp 2>/dev/null | grep -E "$1" | awk '{print $5}' | awk -F: '{print $NF}' | sort -u
    }

    # =============================
    # Xray
    # =============================
    echo -e "${YELLOW}▶ Xray${RESET}"
    if command -v xray &>/dev/null || pgrep -f xray &>/dev/null; then

        status=$(systemctl is-active xray 2>/dev/null)
        [[ "$status" != "active" && $(pgrep -f xray) ]] && status="active"

        echo -e "状态: $(format_status "$status")"

        if command -v xray &>/dev/null; then
            ver=$(xray version 2>/dev/null | head -n1 | awk '{print $2}')
        else
            ver=$(ps -ef | grep xray | grep -v grep | grep -oE 'v[0-9.]+' | head -n1)
        fi
        echo -e "版本: ${ver:-运行中(内置)}"

        ports=$(get_ports xray)
        [[ -n "$ports" ]] && echo -e "端口: $(echo $ports | tr ' ' ', ')" || echo -e "${YELLOW}端口: 无${RESET}"

    else
        echo -e "状态: ${RED}未安装${RESET}"
    fi
    echo ""

    # =============================
    # Sing-box 
    # =============================
    echo -e "${YELLOW}▶ Sing-box${RESET}"
    
    # 同时检查 sing-box 和 s-ui 的命令或进程
    if command -v sing-box &>/dev/null || command -v s-ui &>/dev/null || pgrep -f sing-box &>/dev/null || pgrep -f s-ui &>/dev/null; then

        # 状态判定：支持两个服务名
        status=$(systemctl is-active sing-box 2>/dev/null)
        [[ "$status" != "active" ]] && status=$(systemctl is-active s-ui 2>/dev/null)
        [[ "$status" != "active" && ($(pgrep -f sing-box) || $(pgrep -f s-ui)) ]] && status="active"

        echo -e "状态: $(format_status "$status")"

        # 版本获取
        ver=""
        if command -v sing-box &>/dev/null; then
            ver=$(sing-box version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
        elif [[ -f "/usr/local/s-ui/bin/sing-box" ]]; then
            # 针对手动安装的 S-UI 常规路径进行探测
            ver=$(/usr/local/s-ui/bin/sing-box version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
        fi
        echo -e "版本: ${ver:-运行中(内置)}"

        # 端口获取：尝试获取 sing-box 端口，若无则尝试 s-ui
        ports=$(get_ports sing-box)
        [[ -z "$ports" ]] && ports=$(get_ports s-ui)
        
        [[ -n "$ports" ]] && echo -e "端口: $(echo $ports | tr ' ' ', ')" || echo -e "${YELLOW}端口: 无${RESET}"

    else
        echo -e "状态: ${RED}未安装${RESET}"
    fi
    echo ""
    # =============================
    # Mihomo 
    # =============================
    echo -e "${YELLOW}▶ Mihomo${RESET}"
    
    mihomo_found=0
    mi_ports=""

    # 1. 检测：系统命令、进程或 Docker (保持之前的逻辑)
    if command -v docker &>/dev/null; then
        mi_containers=$(docker ps -a --format "{{.Names}}" | grep -iE "mihomo|clash")
    fi

    if command -v mihomo &>/dev/null || pgrep -iE "mihomo|clash" &>/dev/null || [[ -n "$mi_containers" ]]; then
        mihomo_found=1
        
        # 状态判定
        status=$(systemctl is-active mihomo 2>/dev/null || systemctl is-active clash 2>/dev/null)
        if [[ "$status" != "active" ]]; then
            if pgrep -iE "mihomo|clash" &>/dev/null; then status="active"
            elif [[ -n "$mi_containers" ]]; then
                for name in $mi_containers; do
                    [[ $(docker inspect -f '{{.State.Status}}' "$name") == "running" ]] && status="active" && break
                done
            fi
        fi
        echo -e "状态: $(format_status "$status")"

        # 2. 版本获取优化 (核心修正点)
        # 获取第一行版本号，并检查是否含有 gvisor 关键字
        local raw_ver=""
        if command -v mihomo &>/dev/null; then
            raw_ver=$(mihomo -v 2>/dev/null)
        elif [[ -n "$mi_containers" ]]; then
            first_c=$(echo "$mi_containers" | head -n1)
            raw_ver=$(docker exec "$first_c" mihomo -v 2>/dev/null)
        fi

        if [[ -n "$raw_ver" ]]; then
            # 提取版本号 (v1.x.x)
            ver_num=$(echo "$raw_ver" | grep -iE "Mihomo|Clash" | awk '{print $3}' | head -n1)
            # 检查是否包含 gvisor 并做个简洁标记
            [[ "$raw_ver" == *"gvisor"* ]] && ver_num="${ver_num} (gVisor)"
            echo -e "版本: ${ver_num:-未知}"
        else
            echo -e "版本: 运行中(内置)"
        fi

        # 3. 端口获取
        mi_ports=$(get_ports mihomo; get_ports clash)
        if [[ -n "$mi_containers" ]]; then
            d_ports=$(docker container inspect $(echo "$mi_containers") --format '{{range $p, $conf := .NetworkSettings.Ports}}{{range $conf}}{{.HostPort}} {{end}}{{end}}' | tr -s ' ' '\n' | grep -v '^$')
            mi_ports="$mi_ports $d_ports"
        fi
        final_mi_ports=$(echo $mi_ports | tr ' ' '\n' | sort -un | tr '\n' ',' | sed 's/,$//')
        [[ -n "$final_mi_ports" ]] && echo -e "端口: ${GREEN}${final_mi_ports}${RESET}" || echo -e "端口: ${YELLOW}无${RESET}"

        # 4. 列出 Docker 容器
        if [[ -n "$mi_containers" ]]; then
            for name in $mi_containers; do
                raw_s=$(docker inspect -f '{{.State.Status}}' "$name")
                [[ "$raw_s" == "running" ]] && c_s="active" || c_s="$raw_s"
                echo -e "容器: ${CYAN}${name}${RESET} | 状态: $(format_status "$c_s")"
            done
        fi
    else
        echo -e "状态: ${RED}未安装${RESET}"
    fi
    echo ""



    # =============================
    # 防火墙底层规则架构检测 (兼容 Alpine / 常用系统)
    # =============================
    echo -e "${YELLOW}▶ 防火墙状态与规则${RESET}"

    fw_engine="${RED}未知 / 未启用${RESET}"
    nft_rules_count=0
    ipt_rules_count=0

    # 1. 检测 nftables 规则数量
    if command -v nft >/dev/null 2>&1; then
        # 兼容 BusyBox grep，排除空行和注释
        nft_rules_count=$(nft list ruleset 2>/dev/null | grep -v '^$' | grep -v '^[[:space:]]*#' | wc -l)
    fi

    # 2. 检测 iptables 规则数量 (同时计算 filter, nat, mangle 表)
    if command -v iptables >/dev/null 2>&1; then
        ipt_rules_count=$( (iptables -S 2>/dev/null; iptables -t nat -S 2>/dev/null; iptables -t mangle -S 2>/dev/null) | grep -v '^-P' | wc -l)
    fi

    # 3. 判定当前系统服务状态 (兼容 Systemd 和 OpenRC)
    is_nft_service_active=0
    if command -v systemctl >/dev/null 2>&1; then
        # Systemd 环境
        systemctl is-active nftables >/dev/null 2>&1 && is_nft_service_active=1
    elif command -v rc-service >/dev/null 2>&1; then
        # Alpine OpenRC 环境
        rc-service nftables status 2>/dev/null | grep -q "started" && is_nft_service_active=1
    fi

    # 4. 判定主要依靠哪种规则引擎
    if [[ $is_nft_service_active -eq 1 ]] || [[ $nft_rules_count -gt $ipt_rules_count && $nft_rules_count -gt 0 ]]; then
        fw_engine="${GREEN}nftables${RESET}"
    elif [[ $ipt_rules_count -gt 0 ]]; then
        # 检测是否是基于 nftables 后端的 iptables (iptables-nft)
        if iptables -V 2>/dev/null | grep -q "nf_tables"; then
            fw_engine="${GREEN}iptables${RESET} ${YELLOW}(兼容模式/iptables-nft)${RESET}"
        else
            fw_engine="${GREEN}iptables${RESET} ${YELLOW}(经典模式/legacy)${RESET}"
        fi
    fi

    # 5. 打印引擎及规则结果
    echo -e "当前活动防火墙: $fw_engine"
    echo -e "nftables 规则条数: ${YELLOW}${nft_rules_count}${RESET}"
    echo -e "iptables 规则条数: ${YELLOW}${ipt_rules_count}${RESET}"
    
    # 6. 常见高级防火墙前端管理工具检测 (兼容 Systemd / OpenRC / 基础命令)
    front_ends=""
    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active ufw >/dev/null 2>&1 && front_ends+="UFW "
        systemctl is-active firewalld >/dev/null 2>&1 && front_ends+="Firewalld "
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service ufw status 2>/dev/null | grep -q "started" && front_ends+="UFW "
        rc-service firewalld status 2>/dev/null | grep -q "started" && front_ends+="Firewalld "
    fi
    
    # Alpine 上经常直接用 awall (Alpine Wall) 作为前端
    if command -v awall >/dev/null 2>&1; then
        front_ends+="awall(AlpineWall) "
    fi
    
    if [[ -n "$front_ends" ]]; then
        echo -e "系统管理前端: ${YELLOW}${front_ends% }${RESET} (正在运行)"
    else
        echo -e "系统管理前端: ${YELLOW}无 (原生命令或底层规则管理)${RESET}"
    fi
    echo ""


    # =============================
    # Realm
    # =============================
    echo -e "${YELLOW}▶ Realm${RESET}"
    
    # 查找 Docker 容器名包含 realm 的容器 ID (不区分大小写)
    realm_containers=""
    if command -v docker &>/dev/null; then
        realm_containers=$(docker ps -a --format "{{.Names}}" | grep -i "realm")
    fi

    # 1. 检测原生安装、进程或 Docker 容器
    if command -v realm &>/dev/null || pgrep -f realm &>/dev/null || [[ -n "$realm_containers" ]]; then

        status=$(systemctl is-active realm 2>/dev/null)
        # 如果 systemctl 没过，但进程在，或者 Docker 在运行，也算 active
        if [[ "$status" != "active" ]]; then
            if pgrep -f realm &>/dev/null; then
                status="active"
            elif [[ -n "$realm_containers" ]]; then
                # 检查是否有任一 realm 容器在运行
                for name in $realm_containers; do
                    if [[ $(docker inspect -f '{{.State.Status}}' "$name") == "running" ]]; then
                        status="active"
                        break
                    fi
                done
            fi
        fi

        echo -e "状态: $(format_status "$status")"

        # 版本获取
        if command -v realm &>/dev/null; then
            ver=$(realm --version 2>/dev/null | awk '{print $2}')
        elif [[ -n "$realm_containers" ]]; then
            # 尝试从第一个容器内提取版本
            first_c=$(echo "$realm_containers" | head -n1)
            ver=$(docker exec "$first_c" realm --version 2>/dev/null | awk '{print $2}')
        fi
        echo -e "版本: ${ver:-运行中(内置)}"

        # 端口获取
        ports=$(get_ports realm)
        [[ -n "$ports" ]] && echo -e "端口: $(echo $ports | tr ' ' ', ')" || echo -e "${YELLOW}端口: 无${RESET}"

        # 如果有 Docker 容器，额外列出容器名 (保持简洁)
        if [[ -n "$realm_containers" ]]; then
            for name in $realm_containers; do
                raw_s=$(docker inspect -f '{{.State.Status}}' "$name")
                [[ "$raw_s" == "running" ]] && c_s="active" || c_s="$raw_s"
                echo -e "容器: ${CYAN}${name}${RESET} | 状态: $(format_status "$c_s")"
            done
        fi

    else
        echo -e "状态: ${RED}未安装${RESET}"
    fi
    echo ""


    # =============================
    # Gost 模块 (完整优化版)
    # =============================
    echo -e "${YELLOW}▶ Gost${RESET}"
    
    # 颜色变量定义 (确保脚本开头已定义，若无请取消下面注释)
    # YELLOW='\033[0;33m' && CYAN='\033[0;36m' && RED='\033[0;31m' && RESET='\033[0m'

    gost_containers=""
    if command -v docker &>/dev/null; then
        # 排除 grep 自身的干扰，精确获取容器名
        gost_containers=$(docker ps -a --format "{{.Names}}" | grep -i "gost")
    fi

    # 1. 综合检测：二进制文件、进程、或 Docker 容器
    if command -v gost &>/dev/null || pgrep -f gost &>/dev/null || [[ -n "$gost_containers" ]]; then

        status="inactive"
        # 优先级：Systemd > 进程 > Docker 运行状态
        if systemctl is-active gost &>/dev/null; then
            status="active"
        elif pgrep -f gost &>/dev/null; then
            status="active"
        elif [[ -n "$gost_containers" ]]; then
            for name in $gost_containers; do
                if [[ $(docker inspect -f '{{.State.Status}}' "$name") == "running" ]]; then
                    status="active"
                    break
                fi
            done
        fi

        echo -e "状态: $(format_status "$status")"

        # 2. 版本获取 (多重兼容逻辑)
        ver=""
        # 方式 A: 宿主机原生命令
        if command -v gost &>/dev/null; then
            ver=$(gost -V 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
        fi
        
        # 方式 B: 如果宿主机没装或没取到，从 Docker 容器取
        if [[ -z "$ver" && -n "$gost_containers" ]]; then
            first_c=$(echo "$gost_containers" | head -n1)
            # 尝试容器内 gost -V
            ver=$(docker exec "$first_c" gost -V 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
            # 兼容 gostpanel 等特殊镜像路径
            [[ -z "$ver" ]] && ver=$(docker exec "$first_c" /bin/gost -V 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
        fi
        echo -e "版本: ${ver:-运行中(内置)}"

        # 3. 端口获取 (原生 + Docker 穿透)
        ports=$(get_ports gost)
        if [[ -n "$gost_containers" ]]; then
            # 抓取 Docker 映射端口并格式化清洗
            d_ports=$(docker container inspect $gost_containers --format '{{range $p, $conf := .NetworkSettings.Ports}}{{range $conf}}{{.HostPort}} {{end}}{{end}}' | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ',' | sed 's/^,//;s/,$//')
            
            if [[ -n "$d_ports" ]]; then
                if [[ -n "$ports" ]]; then
                    ports="${ports},${d_ports}"
                else
                    ports="$d_ports"
                fi
            fi
        fi

        # 最终端口清洗输出
        final_ports=$(echo "$ports" | tr ' ' '\n' | tr ',' '\n' | sed '/^$/d' | sort -u | tr '\n' ',' | sed 's/,$//')
        [[ -n "$final_ports" ]] && echo -e "端口: ${CYAN}${final_ports}${RESET}" || echo -e "${YELLOW}端口: 无${RESET}"

        # 4. 细分容器详情显示
        if [[ -n "$gost_containers" ]]; then
            for name in $gost_containers; do
                raw_s=$(docker inspect -f '{{.State.Status}}' "$name")
                # 统一显示为 active 或实际状态
                [[ "$raw_s" == "running" ]] && c_s="active" || c_s="$raw_s"
                echo -e "容器: ${CYAN}${name}${RESET} | 状态: $(format_status "$c_s")"
            done
        fi

    else
        echo -e "状态: ${RED}未安装${RESET}"
    fi
    echo ""


    # =============================
    # EasyTier (兼容 Alpine / 常用系统)
    # =============================
    echo -e "${YELLOW}▶ EasyTier${RESET}"
    
    # 查找 Docker 容器名包含 easytier 的容器 (不区分大小写)
    easytier_containers=""
    if command -v docker >/dev/null 2>&1; then
        easytier_containers=$(docker ps -a --format "{{.Names}}" | grep -i "easytier")
    fi

    # 1. 检测是否存在（原生命令、进程、容器、或服务文件）
    has_easytier=0
    if command -v easytier-core >/dev/null 2>&1 || command -v easytier-cli >/dev/null 2>&1 || pgrep -x easytier-core >/dev/null 2>&1 || [[ -n "$easytier_containers" ]]; then
        has_easytier=1
    fi

    if [[ $has_easytier -eq 1 ]]; then
        # 判定状态：检测 Systemd 或 OpenRC
        status="stopped"
        
        if command -v systemctl >/dev/null 2>&1; then
            systemctl is-active easytier >/dev/null 2>&1 && status="active"
            systemctl is-active easytier-core >/dev/null 2>&1 && status="active"
        elif command -v rc-service >/dev/null 2>&1; then
            rc-service easytier status 2>/dev/null | grep -q "started" && status="active"
            rc-service easytier-core 2>/dev/null | grep -q "started" && status="active"
        fi

        # 如果服务没开，但进程在运行，依然算 active
        if [[ "$status" != "active" ]]; then
            if pgrep -x easytier-core >/dev/null 2>&1; then
                status="active"
            elif [[ -n "$easytier_containers" ]]; then
                for name in $easytier_containers; do
                    if [[ $(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null) == "running" ]]; then
                        status="active"
                        break
                    fi
                done
            fi
        fi

        echo -e "状态: $(format_status "$status")"

        # 版本获取逻辑 (统一使用标准重定向)
        ver=""
        if command -v easytier-core >/dev/null 2>&1; then
            ver=$(easytier-core --version 2>/dev/null | awk '{print $2}')
        elif command -v easytier-cli >/dev/null 2>&1; then
            ver=$(easytier-cli --version 2>/dev/null | awk '{print $2}')
        elif [[ -n "$easytier_containers" ]]; then
            first_c=$(echo "$easytier_containers" | head -n1)
            ver=$(docker exec "$first_c" easytier-core --version 2>/dev/null | awk '{print $2}')
        fi
        echo -e "版本: ${ver:-运行中(未知版本)}"

        # 端口获取
        ports=$(get_ports easytier-core 2>/dev/null)
        [[ -n "$ports" ]] && echo -e "端口: $(echo $ports | tr ' ' ', ')" || echo -e "${YELLOW}端口: 无${RESET}"

        # 如果有 Docker 容器，列出所有相关容器名
        if [[ -n "$easytier_containers" ]]; then
            for name in $easytier_containers; do
                raw_s=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null)
                [[ "$raw_s" == "running" ]] && c_s="active" || c_s="$raw_s"
                echo -e "容器: ${CYAN}${name}${RESET} | 状态: $(format_status "$c_s")"
            done
        fi

    else
        echo -e "状态: ${RED}未安装${RESET}"
    fi
    echo ""



    # =============================
    # FRP (frpc/frps)
    # =============================
    echo -e "${YELLOW}▶ FRP${RESET}"
    
    # 查找 Docker 容器名包含 frp 的容器 (不区分大小写)
    frp_containers=""
    if command -v docker &>/dev/null; then
        frp_containers=$(docker ps -a --format "{{.Names}}" | grep -i "frp")
    fi

    # 1. 检测原生安装、进程或 Docker 容器
    if command -v frpc &>/dev/null || command -v frps &>/dev/null || pgrep -x frpc &>/dev/null || pgrep -x frps &>/dev/null || [[ -n "$frp_containers" ]]; then

        # 判定状态：优先看系统服务，其次看进程，最后看容器
        status=$(systemctl is-active frpc 2>/dev/null || systemctl is-active frps 2>/dev/null)
        if [[ "$status" != "active" ]]; then
            if pgrep -x frpc &>/dev/null || pgrep -x frps &>/dev/null; then
                status="active"
            elif [[ -n "$frp_containers" ]]; then
                for name in $frp_containers; do
                    if [[ $(docker inspect -f '{{.State.Status}}' "$name") == "running" ]]; then
                        status="active"
                        break
                    fi
                done
            fi
        fi

        echo -e "状态: $(format_status "$status")"

        # 版本获取逻辑
        if command -v frpc &>/dev/null; then
            ver=$(frpc -v 2>/dev/null)
        elif command -v frps &>/dev/null; then
            ver=$(frps -v 2>/dev/null)
        elif [[ -n "$frp_containers" ]]; then
            first_c=$(echo "$frp_containers" | head -n1)
            # 尝试在容器内分别测试 frpc 或 frps
            ver=$(docker exec "$first_c" frpc -v 2>/dev/null || docker exec "$first_c" frps -v 2>/dev/null)
        fi
        echo -e "版本: ${ver:-运行中(内置)}"

        # 端口获取
        ports=$( (get_ports frpc; get_ports frps) | sort -u )
        [[ -n "$ports" ]] && echo -e "端口: $(echo $ports | tr ' ' ', ')" || echo -e "${YELLOW}端口: 无${RESET}"

        # 如果有 Docker 容器，列出所有相关容器名
        if [[ -n "$frp_containers" ]]; then
            for name in $frp_containers; do
                raw_s=$(docker inspect -f '{{.State.Status}}' "$name")
                [[ "$raw_s" == "running" ]] && c_s="active" || c_s="$raw_s"
                echo -e "容器: ${CYAN}${name}${RESET} | 状态: $(format_status "$c_s")"
            done
        fi

    else
        echo -e "状态: ${RED}未安装${RESET}"
    fi
    echo ""

    # =============================
    # Nginx（本机 + Docker）
    # =============================
    echo -e "${YELLOW}▶ Nginx${RESET}"

    nginx_found=0
    all_ports=""

    # 1. 检测本机 Nginx
    if command -v nginx &>/dev/null; then
        nginx_found=1
        status=$(systemctl is-active nginx 2>/dev/null)
        [[ "$status" != "active" ]] && pgrep -x nginx &>/dev/null && status="active"
        
        echo -e "状态: $(format_status "$status")"
        ver=$(nginx -v 2>&1 | awk -F/ '{print $2}')
        echo -e "版本: ${ver:-内置}"

        all_ports=$(get_ports nginx)
    fi

    # 2. 检测 Docker Nginx (针对 NPM 做了优化)
    if command -v docker &>/dev/null; then
        # 匹配 nginx 或 npm 相关容器
        nginx_containers=$(docker ps -a --format "{{.Names}}" | grep -iE "nginx|npm")
        
        if [[ -n "$nginx_containers" ]]; then
            [[ $nginx_found -eq 0 ]] && echo -e "状态: ${GREEN}Docker 运行中${RESET}"
            nginx_found=1

            for name in $nginx_containers; do
                raw_s=$(docker inspect -f '{{.State.Status}}' "$name")
                [[ "$raw_s" == "running" ]] && c_s="active" || c_s="$raw_s"
                echo -e "容器: ${CYAN}${name}${RESET} | 状态: $(format_status "$c_s")"

                # 修正：更精准地提取宿主机 HostPort，并确保每个端口后有空格以便后续分割
                d_ports=$(docker container inspect "$name" --format '{{range $p, $conf := .NetworkSettings.Ports}}{{range $conf}}{{.HostPort}} {{end}}{{end}}' | tr -s ' ' '\n' | grep -v '^$')
                all_ports="$all_ports $d_ports"
            done
        fi
    fi

    # 3. 最终端口汇总显示
    if [[ $nginx_found -eq 1 ]]; then
        # 核心修正点：确保用换行符分割，再排序去重，最后用逗号连接
        final_ports=$(echo $all_ports | tr ' ' '\n' | grep -v '^$' | sort -un | tr '\n' ',' | sed 's/,$//')
        
        if [[ -n "$final_ports" ]]; then
            echo -e "端口: ${GREEN}${final_ports}${RESET}"
        else
            echo -e "端口: ${YELLOW}未发现映射端口${RESET}"
        fi
    else
        echo -e "状态: ${RED}未安装${RESET}"
    fi
    echo ""
    # =============================
    # Caddy
    # =============================
    echo -e "${YELLOW}▶ Caddy${RESET}"
    
    # 查找 Docker 容器 (不区分大小写)
    caddy_containers=""
    if command -v docker &>/dev/null; then
        caddy_containers=$(docker ps -a --format "{{.Names}}" | grep -i "caddy")
    fi

    if command -v caddy &>/dev/null || pgrep -x caddy &>/dev/null || [[ -n "$caddy_containers" ]]; then

        status=$(systemctl is-active caddy 2>/dev/null)
        if [[ "$status" != "active" ]]; then
            if pgrep -x caddy &>/dev/null; then
                status="active"
            elif [[ -n "$caddy_containers" ]]; then
                for name in $caddy_containers; do
                    if [[ $(docker inspect -f '{{.State.Status}}' "$name") == "running" ]]; then
                        status="active"
                        break
                    fi
                done
            fi
        fi

        echo -e "状态: $(format_status "$status")"

        # 版本获取：增加 awk 处理，只保留 v2.x.x
        if command -v caddy &>/dev/null; then
            ver=$(caddy version 2>/dev/null | awk '{print $1}')
        elif [[ -n "$caddy_containers" ]]; then
            first_c=$(echo "$caddy_containers" | head -n1)
            ver=$(docker exec "$first_c" caddy version 2>/dev/null | awk '{print $1}')
        fi
        echo -e "版本: ${ver:-运行中(内置)}"

        # 端口获取
        ports=$(get_ports caddy)
        [[ -n "$ports" ]] && echo -e "端口: $(echo $ports | tr ' ' ', ')" || echo -e "${YELLOW}端口: 无${RESET}"

        # Docker 容器列表
        if [[ -n "$caddy_containers" ]]; then
            for name in $caddy_containers; do
                raw_s=$(docker inspect -f '{{.State.Status}}' "$name")
                [[ "$raw_s" == "running" ]] && c_s="active" || c_s="$raw_s"
                echo -e "容器: ${CYAN}${name}${RESET} | 状态: $(format_status "$c_s")"
            done
        fi
    else
        echo -e "状态: ${RED}未安装${RESET}"
    fi
    echo ""

    # =============================
    # ACME (acme.sh)
    # =============================
    echo -e "${YELLOW}▶ ACME${RESET}"
    # 检测原生二进制、家目录脚本或 Docker 容器
    if command -v acme.sh &>/dev/null || [[ -f ~/.acme.sh/acme.sh ]] || (command -v docker &>/dev/null && docker ps -a --format '{{.Names}}' | grep -qi "acme"); then
        
        # 确定状态
        if command -v acme.sh &>/dev/null || [[ -f ~/.acme.sh/acme.sh ]]; then
            echo -e "状态: ${GREEN}已安装${RESET}"
        else
            echo -e "状态: ${GREEN}已安装(Docker)${RESET}"
        fi

        # 版本获取逻辑：增加 grep 过滤掉 URL 干扰
        if command -v acme.sh &>/dev/null; then
            ver=$(acme.sh --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        elif [[ -f ~/.acme.sh/acme.sh ]]; then
            ver=$(~/.acme.sh/acme.sh --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        elif command -v docker &>/dev/null; then
            container_id=$(docker ps -a --format "{{.Names}}" | grep -i "acme" | head -n1)
            # 从容器内部提取版本，并过滤出纯数字版本号
            ver=$(docker exec "$container_id" acme.sh --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        fi
        echo -e "版本: ${ver:-内置}"
        
    else
        echo -e "状态: ${RED}未安装${RESET}"
    fi
    echo ""
    # =============================
    # CF WARP
    # =============================
    echo -e "${YELLOW}▶ Cloudflare WARP${RESET}"

    warp_found=0

    # 1. 官方 warp-cli
    if command -v warp-cli &>/dev/null; then
        warp_found=1
        if warp-cli status 2>/dev/null | grep -qi 'Connected'; then
            echo -e "状态: ${GREEN}已连接${RESET}"
        else
            echo -e "状态: ${YELLOW}已安装(未连接)${RESET}"
        fi
    fi
    
    # 2. WarpGo
    if command -v warp-go &>/dev/null || command -v warpgo &>/dev/null; then
        warp_found=1
        echo -e "状态: ${GREEN}WarpGo已安装${RESET}"
    fi

    if systemctl list-unit-files 2>/dev/null | grep -q warp-go; then
        warp_found=1
        if systemctl is-active warp-go &>/dev/null; then
            echo -e "状态: ${GREEN}WarpGo服务运行中${RESET}"
        else
            echo -e "状态: ${YELLOW}WarpGo已安装(未运行)${RESET}"
        fi
    fi

    # 3. WGCF
    if command -v wgcf &>/dev/null || ip a 2>/dev/null | grep -q 'wgcf'; then
        warp_found=1
        echo -e "状态: ${GREEN}WGCF已安装${RESET}"
    fi

    # 4. 官方服务进程
    if systemctl list-unit-files 2>/dev/null | grep -q warp-svc; then
        warp_found=1
        if systemctl is-active warp-svc &>/dev/null; then
            echo -e "状态: ${GREEN}服务运行中${RESET}"
        else
            echo -e "状态: ${YELLOW}服务已安装${RESET}"
        fi
    fi

    # 5. 其他快捷命令
    if command -v warp &>/dev/null; then
        warp_found=1
        if warp status 2>/dev/null | grep -q "WARP 网络接口已开启"; then
            echo -e "状态: ${GREEN}已开启${RESET}"
        else
            echo -e "状态: ${YELLOW}已安装${RESET}"
        fi
    fi

    # 6. Docker 模糊检测 (不区分大小写)
    if command -v docker &>/dev/null; then
        # 获取所有容器名，通过 grep -i 匹配包含 warp 的名称
        warp_containers=$(docker ps -a --format "{{.Names}}" | grep -i "warp")
        if [[ -n "$warp_containers" ]]; then
            warp_found=1
            for name in $warp_containers; do
                # 直接获取状态
                raw_status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null)
                # 对 Docker 状态进行简单转换，确保 format_status 能识别
                [[ "$raw_status" == "running" ]] && c_status="active" || c_status="$raw_status"
                
                echo -e "容器: ${CYAN}${name}${RESET} | 状态: $(format_status "$c_status")"
            done
        fi
    fi

    # 网络模式检测
    if [[ $warp_found -eq 0 ]]; then
        # 只有在没有任何发现时才显示未安装
        echo -e "状态: ${RED}未安装${RESET}"
    else
        trace=$(curl -s --max-time 2 https://www.cloudflare.com/cdn-cgi/trace)
        if echo "$trace" | grep -q "warp=on"; then
            echo -e "模式: ${GREEN}WARP中${RESET}"
        elif echo "$trace" | grep -q "warp=plus"; then
            echo -e "模式: ${GREEN}WARP+${RESET}"
        else
            echo -e "模式: ${YELLOW}普通网络${RESET}"
        fi
    fi
    echo ""

    # =============================
    # Cloudflare Tunnel (Argo)
    # =============================
    # 定义你脚本中的路径，假设 ${work_dir} 你已经全局定义了
    local argo_path="${work_dir}/argo"

    echo -e "${YELLOW}▶ Cloudflare Tunnel${RESET}"
    
    # 查找 Docker 容器 (保持模糊匹配)
    cf_containers=""
    if command -v docker &>/dev/null; then
        cf_containers=$(docker ps -a --format "{{.Names}}" | grep -iE "cloudflared|tunnel|argo")
    fi

    # 1. 检测：自定义路径文件、系统命令、进程或 Docker
    if [[ -f "$argo_path" ]] || command -v cloudflared &>/dev/null || pgrep -f "argo|cloudflared" &>/dev/null || [[ -n "$cf_containers" ]]; then

        status=$(systemctl is-active cloudflared 2>/dev/null || systemctl is-active argo 2>/dev/null)
        
        # 进程检测 (优先匹配你重命名后的 argo)
        if [[ "$status" != "active" ]]; then
            if pgrep -f "$argo_path" &>/dev/null || pgrep -f "cloudflared" &>/dev/null; then
                status="active"
            elif [[ -n "$cf_containers" ]]; then
                for name in $cf_containers; do
                    if [[ $(docker inspect -f '{{.State.Status}}' "$name") == "running" ]]; then
                        status="active"
                        break
                    fi
                done
            fi
        fi

        echo -e "状态: $(format_status "$status")"

        # 版本获取
        if [[ -f "$argo_path" ]]; then
            ver=$("$argo_path" --version 2>/dev/null | awk '{print $3}')
        elif command -v cloudflared &>/dev/null; then
            ver=$(cloudflared --version 2>/dev/null | awk '{print $3}')
        elif [[ -n "$cf_containers" ]]; then
            first_c=$(echo "$cf_containers" | head -n1)
            ver=$(docker exec "$first_c" cloudflared --version 2>/dev/null | awk '{print $3}')
        fi
        echo -e "版本: ${ver:-运行中(内置)}"

        # 如果有 Docker 容器，列出所有相关容器名
        if [[ -n "$cf_containers" ]]; then
            for name in $cf_containers; do
                raw_s=$(docker inspect -f '{{.State.Status}}' "$name")
                [[ "$raw_s" == "running" ]] && c_s="active" || c_s="$raw_s"
                echo -e "容器: ${CYAN}${name}${RESET} | 状态: $(format_status "$c_s")"
            done
        fi

    else
        echo -e "状态: ${RED}未安装${RESET}"
    fi
    echo ""

    # =============================
    # Docker
    # =============================
    echo -e "${YELLOW}▶ Docker${RESET}"

    if command -v docker &>/dev/null; then
        # Docker 已安装
        containers=$(docker ps --format "{{.Names}}" | grep -Ei 'xray|sing|hysteria|tuic|snell|3xui_app|AnyTLSD|MTProto|shadowsocks|sshadow-tls|shadow-tls|Singbox-AnyReality|Singbox-AnyTLS|Singbox-TUICv5|Xray-Reality|Xray-Realityxhttp|xray-socks5|xray-vlesshttpupgrade|xray-vmess|mtg-proxy|xray-vmesstls|clash|mihomo|warp|microwarp|easytier|ppanel-service|wg-easy|wireguard|xboard|xboard-node-1|miaomiaowux|Mihomo|remnawave|remnawave-subscription-page|sui-traffic-reset|forwardx-panel|frpp-master|frp-panel-server|frp-panel-client|relaypanel-panel|vite-frontend|onebord|nodepassdash')

        if [[ -n "$containers" ]]; then
            echo -e "状态: ${GREEN}运行中${RESET}"
            echo -e "${YELLOW}容器:${RESET} $(echo "$containers" | tr '\n' ' ')"
        else
            echo -e "状态: ${GREEN}已安装${RESET}"
        fi
    else
        echo -e "状态: ${RED}未安装${RESET}"
    fi

    echo ""

    # =============================
    # BBR
    # =============================
    echo -e "${YELLOW}▶ BBR${RESET}"

    actual_cc=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)

    if [[ "$actual_cc" == "bbr" ]]; then
        echo -e "状态: ${GREEN}已启用 BBR${RESET}"
    else
        echo -e "状态: ${RED}未启用 BBR${RESET}"
    fi

    echo ""

    # =============================
    # 网络出口
    # =============================
    echo -e "${YELLOW}▶ 网络出口${RESET}"

    # 获取 IP
    ipv4=$(curl -4 -s --max-time 3 ip.sb 2>/dev/null || curl -4 -s --max-time 3 ifconfig.me 2>/dev/null)
    ipv6=$(curl -6 -s --max-time 3 ip.sb 2>/dev/null)

    get_country_cn() {
        local ip="$1"
        # 优先从 ip-api 获取中文名称
        local res=$(curl -s --max-time 3 "http://ip-api.com/json/$ip?lang=zh-CN")
        local name=$(echo "$res" | grep -oP '"country":"\K[^"]+')
        echo "${name:-未知}"
    }

    if [[ -n "$ipv4" ]]; then
        country4=$(get_country_cn "$ipv4")
        echo -e "IPv4: ${GREEN}$ipv4${RESET}         国家: ${GREEN}$country4${RESET}"
    else
        echo -e "IPv4: ${RED}获取失败${RESET}"
    fi

    if [[ -n "$ipv6" ]]; then
        country6=$(get_country_cn "$ipv6")
        echo -e "IPv6: ${GREEN}$ipv6${RESET}  国家: ${GREEN}$country6${RESET}"
    fi

    echo ""

    # =============================
    # DNS 检测
    # =============================
    echo -e "${YELLOW}▶ DNS 信息${RESET}"

    # 提取 DNS 地址
    dns_all=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}')
    dns_v4=$(echo "$dns_all" | grep -v ":" | tr '\n' ' ')
    dns_v6=$(echo "$dns_all" | grep ":" | tr '\n' ' ')

    # --- IPv4 DNS ---
    if [[ -n "$dns_v4" ]]; then
        echo -e "DNSv4: ${CYAN}${dns_v4}${RESET}"
        # 使用第一个 v4 DNS 测试解析 google.com
        test_v4=$(first_dns=$(echo $dns_v4 | awk '{print $1}'); dig +short +time=1 +tries=1 google.com @$first_dns >/dev/null 2>&1 && echo "ok" || echo "fail")
        if [[ "$test_v4" == "ok" ]]; then
            echo -e "解析: ${GREEN}IPv4 正常${RESET}"
        else
            echo -e "解析: ${RED}IPv4 失败或超时${RESET}"
        fi
    else
        echo -e "DNSv4: ${RED}无${RESET}"
    fi

    # --- IPv6 DNS (仅在存在时显示) ---
    if [[ -n "$dns_v6" ]]; then
        echo -e "DNSv6: ${CYAN}${dns_v6}${RESET}"
        # 使用第一个 v6 DNS 测试解析 google.com (AAAA)
        test_v6=$(first_dns6=$(echo $dns_v6 | awk '{print $1}'); dig +short +time=1 +tries=1 google.com AAAA @$first_dns6 >/dev/null 2>&1 && echo "ok" || echo "fail")
        if [[ "$test_v6" == "ok" ]]; then
            echo -e "解析: ${GREEN}IPv6 正常${RESET}"
        else
            echo -e "解析: ${RED}IPv6 失败或超时${RESET}"
        fi
    fi
    echo ""
    
}



# =============================
# 核心卸载菜单
# =============================
uninstall_core_menu() {
while true; do
    clear
    echo -e "${RED}╔══════════════════════╗${RESET}"
    echo -e "${RED}      核心卸载管理        ${RESET}"
    echo -e "${RED}╚══════════════════════╝${RESET}"
    echo -e "${YELLOW}[01] 卸载 Xray${RESET}"
    echo -e "${YELLOW}[02] 卸载 Sing-box${RESET}"
    echo -e "${YELLOW}[03] 卸载 Mihomo${RESET}"
    echo -e "${YELLOW}[04] 卸载 Realm${RESET}"
    echo -e "${YELLOW}[05] 卸载 GOST${RESET}"
    echo -e "${YELLOW}[06] 卸载 EasyTier${RESET}"
    echo -e "${YELLOW}[07] 卸载 FRP${RESET}"
    echo -e "${YELLOW}[08] 卸载 Nginx${RESET}"
    echo -e "${YELLOW}[09] 卸载 Caddy${RESET}"
    echo -e "${YELLOW}[10] 卸载 ACME${RESET}"
    echo -e "${YELLOW}[11] 卸载 CFWARP${RESET}"
    echo -e "${YELLOW}[12] 卸载 CFTunnel${RESET}"
    echo -e "${GREEN}[0] 返回${RESET}"
    echo -e "${GREEN}[x] 退出${RESET}"

    read_submenu || return

    case "$sub" in
        01) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/uninstallXray.sh")) ; pause_return ;;
        02) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/uninstallSingbox.sh")) ; pause_return ;;
        03) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/uninstallMihomo.sh")) ; pause_return ;;
        04) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/uninstallRealm.sh")) ; pause_return ;;
        05) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/uninstallGost.sh")) ; pause_return ;;
        06) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/uninstallEasyTier.sh")) ; pause_return ;;
        07) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/uninstallFRP.sh")) ; pause_return ;;
        08) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/uninstallNginx.sh")) ; pause_return ;;
        09) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/uninstallCaddy.sh")) ; pause_return ;;
        10) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/uninstallAcme.sh")) ; pause_return ;;
        11) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/uninstallCFWARP.sh")) ; pause_return ;;
        12) bash <(curl -sL $(proxy_url "https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/uninstallCFArgo.sh")) ; pause_return ;;
        0) return ;;
        *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
    esac
done
}

# =============================
# 更新 & 卸载
# =============================
update_script() {
    local up_url=$(proxy_url "$SCRIPT_URL")
    echo -e "${YELLOW}正在更新代理工具箱...${RESET}"
    if curl -fsSL -o "$SCRIPT_PATH" "$up_url"; then
        chmod +x "$SCRIPT_PATH"
        echo -e "${GREEN}更新成功！${RESET}"
        exec bash "$SCRIPT_PATH"
    else
        echo -e "${RED}❌ 更新失败，请检查网络或代理是否可用！${RESET}"
    fi
}

uninstall_script() {
    rm -f "$SCRIPT_PATH"
    rm -f "$BIN_LINK_DIR/F" "$BIN_LINK_DIR/f"
    echo -e "${RED}卸载完成!${RESET}"
    exit 0
}

# =============================
# 主循环
# =============================
while true; do
    main_menu
done
