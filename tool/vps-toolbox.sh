#!/bin/bash
# VPS Toolbox
# 功能：
# - 一级菜单加 ▶ 标识，字体绿色
# - 二级菜单简洁显示，输入 1~99 都可执行
# - 快捷指令 m / M 自动创建
# - 系统信息面板保留
# - 彩色菜单和动态彩虹标题
# - 完整安装/卸载逻辑

INSTALL_PATH="$HOME/vps-toolbox.sh"
SHORTCUT_PATH="/usr/local/bin/m"
SHORTCUT_PATH_UPPER="/usr/local/bin/M"

# 颜色
green="\033[32m"
reset="\033[0m"
yellow="\033[33m"
red="\033[31m"
cyan="\033[36m"
BLUE="\033[34m"
ORANGE='\033[38;5;208m'


# Ctrl+C 中断保护
trap 'echo -e "\n${red}操作已中断${reset}"; exit 1' INT

# 彩虹标题
rainbow_animate() {
    local text="$1"
    local colors=(31 33 32 36 34 35)
    local len=${#text}
    for ((i=0; i<len; i++)); do
        printf "\033[%sm%s" "${colors[$((i % ${#colors[@]}))]}" "${text:$i:1}"
        sleep 0.002
    done
    printf "${reset}\n"
}

# 系统资源显示
show_system_usage() {
    local width=36
    local content_indent="    "

    # ================== 格式化函数 ==================
    format_size() {
        local size_mb=${1:-0}  # 防止为空
        if [ "$size_mb" -lt 1024 ]; then
            echo "${size_mb}M"
        else
            awk "BEGIN{printf \"%.1fG\", $size_mb/1024}"
        fi
    }

    # ================== 获取数据 ==================
    # 内存
    read mem_total mem_used <<< $(LANG=C free -m | awk 'NR==2{print $2, $3}')
    mem_total=${mem_total:-0}
    mem_used=${mem_used:-0}
    mem_total_fmt=$(format_size "$mem_total")
    mem_used_fmt=$(format_size "$mem_used")
    mem_percent=$(awk "BEGIN{if($mem_total>0){printf \"%.0f\", $mem_used*100/$mem_total}else{print 0}}")
    mem_percent="${mem_percent}%"  # 加回百分号显示

    # 磁盘
    read disk_total_h disk_used_h disk_used_percent <<< $(df -m / | awk 'NR==2{print $2, $3, $5}')
    disk_total_h=${disk_total_h:-0}
    disk_used_h=${disk_used_h:-0}
    disk_used_percent=${disk_used_percent:-0%}
    disk_total_fmt=$(format_size "$disk_total_h")
    disk_used_fmt=$(format_size "$disk_used_h")

    # CPU
    # 读取 /proc/stat 第一行，计算 CPU 使用率（防止空值）
    cpu_usage=$(awk 'NR==1{usage=($2+$4)*100/($2+$4+$5); if(usage!=""){printf "%.1f", usage}else{print 0}}' /proc/stat)
    cpu_usage="${cpu_usage}%"  # 加回百分号显示

    # ================== 系统状态 ==================
    mem_num=${mem_percent%\%}        # 去掉百分号
    disk_num=${disk_used_percent%\%} # 去掉百分号
    cpu_num=${cpu_usage%\%}          # 去掉百分号

    max_level=0
    for n in $mem_num $disk_num $cpu_num; do
        if (( $(awk "BEGIN{print ($n>80)?1:0}") )); then max_level=2; fi
        if (( $(awk "BEGIN{print ($n>60 && $n<=80)?1:0}") )) && [ "$max_level" -lt 2 ]; then max_level=1; fi
    done

    if [ "$max_level" -eq 0 ]; then
        system_status="${green}系统状态：正常 ✔${reset}"
    elif [ "$max_level" -eq 1 ]; then
        system_status="${yellow}系统状态：警告 ⚠️${reset}"
    else
        system_status="${red}系统状态：危险 🔥${reset}"
    fi

    # ================== 输出 ==================
    pad_string() {
        local str="$1"
        printf "%-${width}s" "${content_indent}${str}"
    }

    echo -e "${green}┌$(printf '─%.0s' $(seq 1 $width))┐${reset}"
    echo -e "$(pad_string "${system_status}")"
    echo -e "$(pad_string "${yellow}📊 内存：${mem_used_fmt}/${mem_total_fmt} (${mem_percent})${reset}")"
    echo -e "$(pad_string "${yellow}💽 磁盘：${disk_used_fmt}/${disk_total_fmt} (${disk_used_percent})${reset}")"
    echo -e "$(pad_string "${yellow} ⚙ CPU ：${cpu_usage}${reset}")"
    echo -e "${green}└$(printf '─%.0s' $(seq 1 $width))┘${reset}"
}

# ================== 系统信息 ==================

# 判断是否容器
if [ -f /proc/1/cgroup ] && grep -qE '(docker|lxc|kubepods)' /proc/1/cgroup; then
    container_flag=" (Container)"
else
    container_flag=""
fi

# 系统名称
if [ -f /etc/os-release ]; then
    system_name=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
else
    system_name=$(uname -s)
fi
system_name="${system_name}${container_flag}"

# 时区
if [ -f /etc/timezone ]; then
    timezone=$(cat /etc/timezone)
elif command -v timedatectl >/dev/null 2>&1; then
    timezone=$(timedatectl | awk '/Time zone/ {print $3}')
else
    timezone=$(date +%Z)
fi
timezone="${timezone} (Non-systemd)"


# 架构
cpu_arch=$(uname -m)

# 当前时间
datetime=$(date "+%Y-%m-%d %H:%M:%S")

# VPS 运行时间
if [ -f /proc/uptime ]; then
    uptime_seconds=$(cut -d' ' -f1 /proc/uptime | cut -d. -f1)
    days=$((uptime_seconds/86400))
    hours=$(( (uptime_seconds%86400)/3600 ))
    minutes=$(( (uptime_seconds%3600)/60 ))
    if [ "$days" -gt 0 ]; then
        vps_uptime="${days}天${hours}小时${minutes}分钟"
    elif [ "$hours" -gt 0 ]; then
        vps_uptime="${hours}小时${minutes}分钟"
    else
        vps_uptime="${minutes}分钟"
    fi
else
    vps_uptime=$(uptime -p 2>/dev/null | tr -d ' ' || echo "未知")
fi



# 一级菜单
MAIN_MENU=(
    "系统设置"
    "网络代理"
    "网络检测"
    "Docker管理"
    "应用商店"
    "证书安全"
    "系统管理"
    "工具箱合集"
    "玩具熊ʕ•ᴥ•ʔ"
    "更新/卸载"
)

# 二级菜单（编号去掉前导零，显示时格式化为两位数）
SUB_MENU[1]="1 更新系统|2 系统信息|3 修改root密码|4 root密码登录管理|5 root公钥登录管理|6 修改SSH端口|7 修改时区|8 切换v4V6|9 开放所有端口|10 更换系统源|11 DDdebian12|12 DDwindows10|13 DDNAT|14 DD飞牛|15 修改语言|16 修改主机名|17 美化命令|18 VPS重启"
SUB_MENU[2]="19 代理工具|20 FRP管理|21 BBRv3优化|22 WARP|23 BBR+TCP智能调参|24 Reality|25 SurgeSnell|26 Shadowsocks|27 自定义DNS解锁|28 DDNS|29 Hysteria2|30 3X-UI|31 Realm|32 GOST|33 哆啦A梦转发面板|34 easytier组网"
SUB_MENU[3]="35 NodeQuality脚本|36 融合怪测试|37 YABS测试|38 网络质量体检脚本|39 简单回程测试|40 完整路由检测|41 流媒体解锁|42 三网延迟测速|43 硬件质量体检脚本|44 检查25端口开放|45 网络工具"
SUB_MENU[4]="46 Docker管理|47 DockerCompose管理|48 DockerCompose备份恢复|49 DockerCompose自动更新"
SUB_MENU[5]="50 应用管理|51 面板管理|52 监控管理|53 视频下载工具|54 镜像加速|55 异次元数卡|56 小雅全家桶|57 qbittorrent"
SUB_MENU[6]="58 NGINXV4反代|59 NGINXV6反代|60 Caddy反代|61 NginxProxyManager面板|62 证书备份与恢复"
SUB_MENU[7]="63 系统清理|64 系统快照恢复|65 本地备份|66 重装系统|67 系统组件|68 开发环境|69 添加SWAP|70 DNS管理|71 工作区管理|72 系统监控|73 防火墙管理|74 Fail2ban|75 Rsync同步|76 解压文件|78 定时任务"
SUB_MENU[8]="79 科技lion工具箱|80 老王工具箱|81 酷雪云工具箱|82 Alpine工具箱|83 甲骨文工具箱"
SUB_MENU[9]="84 文件目录备份|85 Rclone备份|86 NAT小鸡|87 VPS监控通知|89 脚本短链|90 网站部署|91 Emby反代|92 GProxy加速|93 Akile优先DNS|94 关闭V1SSH|95 卸载哪吒Agent |96 卸载komariAgent"
SUB_MENU[10]="77 自动更新|88 更新脚本|99 卸载脚本"

# 显示一级菜单
show_main_menu() {
    clear
    # 上边框保留彩虹效果
    rainbow_animate "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 标题文字改为纯黄色
    echo -e "${yellow}       📦 VPS Toolbox工具箱 📦  ${reset}"

    # 下边框保留彩虹效果
    rainbow_animate "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 系统信息
    show_system_usage


    # 当前日期时间显示在框下、菜单上

    # 终端宽度（可用不用）
    term_width=$(tput cols 2>/dev/null || echo 80)

    label_w=8  # 左侧标签宽度

    printf "${ORANGE}%s %-*s:${yellow} %s${re}\n" "💻" $label_w "系统" "$system_name"
    printf "${ORANGE}%s %-*s:${yellow} %s${re}\n" "🌍" $label_w "时区" "$timezone"
    printf "${ORANGE}%s %-*s:${yellow} %s${re}\n" "🧩" $label_w "架构" "$cpu_arch"
    printf "${ORANGE}%s %-*s:${yellow} %s${re}\n" "🕒" $label_w "时间" "$datetime"
    printf "${ORANGE}%s %-*s:${ORANGE} %s${re}\n" "🚀" $label_w "在线" "$vps_uptime"

    # 绿色下划线
    echo -e "${green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${re}"

    # 显示菜单
    for i in "${!MAIN_MENU[@]}"; do
        if [[ $i -eq 8 ]]; then  # 第9项（索引从0开始）
            # 符号红色，数字和点绿色，文字黄色
            printf "${red}▶${reset} ${green}%02d.${reset} ${yellow}%s${reset}\n" "$((i+1))" "${MAIN_MENU[i]}"
        else
            # 其他项保持原来的颜色（符号红色，数字绿色，文字绿色）
            printf "${red}▶${reset} ${green}%02d. %s${reset}\n" "$((i+1))" "${MAIN_MENU[i]}"
        fi
    done
}


# 显示二级菜单并选择
show_sub_menu() {
    local idx="$1"
    while true; do
        IFS='|' read -ra options <<< "${SUB_MENU[idx]}"
        local map=()
        echo
        for opt in "${options[@]}"; do
            local num="${opt%% *}"
            local name="${opt#* }"
            printf "${red}▶${reset} ${yellow}%02d %s${reset}\n" "$num" "$name"
            map+=("$num")
        done
        echo -ne "${red}请输入要执行的编号${ORANGE}(0返回/X退出)${ORANGE}:${reset}"
        read -r choice

        # X/x 直接退出脚本
        if [[ "$choice" =~ ^[xX]$ ]]; then
            exit 0
        fi

        # 按回车直接刷新菜单
        if [[ -z "$choice" ]]; then
            clear
            continue
        fi

        # 输入 0 或 00 返回一级菜单
        if [[ "$choice" == "0" || "$choice" == "00" ]]; then
            return
        fi

        # 只允许数字输入
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${red}无效选项，请输入数字！${reset}"
            sleep 1
            clear
            continue
        fi

        # 判断是否为有效选项
        if [[ ! " ${map[*]} " =~ (^|[[:space:]])$choice($|[[:space:]]) ]]; then
            echo -e "${red}无效选项${reset}"
            sleep 1
            clear
            continue
        fi

        # 执行选项
        execute_choice "$choice"

        # 只有 0/99 才退出二级菜单，否则按回车刷新二级菜单
        if [[ "$choice" != "0" && "$choice" != "99" ]]; then
            read -rp $'\e[31m按回车刷新二级菜单...\e[0m' tmp
            clear
        else
            break
        fi
    done
}




# 删除快捷指令
remove_shortcut() {
    if [[ $EUID -eq 0 ]]; then
        rm -f "$SHORTCUT_PATH" "$SHORTCUT_PATH_UPPER"
    else
        sudo rm -f "$SHORTCUT_PATH" "$SHORTCUT_PATH_UPPER"
    fi
}

# 执行菜单选项
execute_choice() {
    case "$1" in
        1) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/update.sh) ;;
        2) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/vpsinfo.sh) ;;
        3) sudo passwd root ;;
        4) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/rootmi.sh) ;;
        5) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/rootgon.sh) ;;
        6) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/sshdk.sh) ;;
        7) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/time.sh) ;;
        8) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/qhwl.sh) ;;
        9) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/open_all_ports.sh) ;;
        10) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/huanyuan.sh) ;;
        11) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/debian.sh) ;;
        12) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/window.sh) ;;
        13) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/DDnat.sh) ;;
        14) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/ddfnos.sh) ;;
        15) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/xgyu.sh) ;;
        16) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/home.sh) ;;
        17) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/mhgl.sh) ;;
        18) sudo reboot ;;
        19) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/proxy.sh) ;;
        20) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/FRP.sh) ;;
        21) bash <(curl -fsSL "https://raw.githubusercontent.com/Eric86777/vps-tcp-tune/main/install-alias.sh?$(date +%s)") ;;
        22) wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh ;;
        23) bash <(curl -sL https://raw.githubusercontent.com/yahuisme/network-optimization/main/script.sh) ;;
        24) bash <(curl -L https://raw.githubusercontent.com/yahuisme/xray-vless-reality/main/install.sh) ;;
        25) wget -O snell.sh --no-check-certificate https://git.io/Snell.sh && chmod +x snell.sh && ./snell.sh ;;
        26) wget -O ss-rust.sh --no-check-certificate https://raw.githubusercontent.com/xOS/Shadowsocks-Rust/master/ss-rust.sh && chmod +x ss-rust.sh && ./ss-rust.sh ;;
        27) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/unlockdns.sh) ;;
        28) bash <(wget -qO- https://raw.githubusercontent.com/mocchen/cssmeihua/mochen/shell/ddns.sh) ;;
        29) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/Hysteria2.sh) ;;
        30) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/3xui.sh) ;;
        31) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/realmdog.sh) ;;
        32) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/gost.sh) ;;
        33) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/dlam.sh);;
        34) bash <(curl -sL https://raw.githubusercontent.com/ceocok/c.cococ/refs/heads/main/easytier.sh) ;;
        35) bash <(curl -sL https://run.NodeQuality.com) ;;
        36) curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh ;;
        37) curl -sL https://yabs.sh | bash ;;
        38) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/examine.sh) ;;
        39) curl https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh -sSf | sh ;;
        40) bash <(curl -Ls https://Net.Check.Place) -R ;;
        41) bash <(curl -L -s https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) ;;
        42) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/speed.sh) ;;
        43) bash <(curl -Ls https://Hardware.Check.Place) ;;
        44) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/Telnet.sh) ;;
        45) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/Networktool.sh) ;; 
        46) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Docker.sh) ;;
        47) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/dockercompose.sh) ;;
        48) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Dockcompbauck.sh) ;;
        49) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/dockerupdate.sh) ;;
        50) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Store.sh) ;;
        51) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/panel.sh) ;;
        52) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/jkgl.sh) ;;
        53) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ytdlpweb.sh) ;;
        54) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/hubproxy.sh) ;;
        55) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ACGFaka.sh) ;;
        56) bash -c "$(curl --insecure -fsSL https://ddsrem.com/xiaoya_install.sh)" ;;
        57) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/qbittorrent.sh) ;;
        58) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/ngixv4.sh) ;;
        59) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/ngixv6.sh) ;;
        60) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/Caddy.sh) ;;
        61) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/NginxProxy.sh) ;;
        62) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/SSLbackup.sh) ;;
        63) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/clear.sh) ;;
        64) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/restore.sh) ;;
        65) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/beifen.sh) ;;
        66) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/reinstall.sh) ;;
        67) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/package.sh) ;;
        68) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/exploitation.sh) ;;
        69) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/WARP.sh) ;;
        70) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/dns.sh) ;;
        71) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/tmux.sh) ;;
        72) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/System.sh) ;;
        73) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/firewall.sh) ;;
        74) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/fail2ban.sh) ;;
        75) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/Rrsync.sh) ;;
        76) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/tarzip.sh) ;;
        78) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/crontab.sh) ;;
        79) bash <(curl -sL kejilion.sh) ;;
        80) bash <(curl -fsSL ssh_tool.eooce.com) ;;
        81) bash <(curl -sL https://cdn.kxy.ovh/kxy.sh) ;;
        82) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Alpine/Alpine.sh) ;;
        83) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Oracle/oracle.sh) ;;
        84) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/Filebackup.sh) ;;
        85) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/rclone.sh) ;;
        86) bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/nat.sh) ;;
        87) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/vpstg.sh) ;;
        89) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/dl.sh) ;;
        90) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/html.sh) ;;
        91) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/Embyfd.sh) ;;
        92) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/GProxy.sh) ;;
        93) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/AkileDNS.sh) ;;
        94) sed -i 's/disable_command_execute: false/disable_command_execute: true/' /opt/nezha/agent/config.yml && systemctl restart nezha-agent ;;
        95) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/nzagent.sh) ;;
        96) sudo systemctl stop komari-agent && sudo systemctl disable komari-agent && sudo rm -f /etc/systemd/system/komari-agent.service && sudo systemctl daemon-reload && sudo rm -rf /opt/komari /var/log/komari ;;


        #  自动更新脚本
        77) bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/tool/update.sh) ;; 
        88)
            echo -e "${yellow}正在更新脚本...${reset}"
            # 下载最新版本覆盖本地脚本
            curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/tool/vps-toolbox.sh -o "$INSTALL_PATH"
            if [[ $? -ne 0 ]]; then
                echo -e "${red}更新失败，请检查网络或GitHub地址${reset}"
                return 1
            fi
            chmod +x "$INSTALL_PATH"
            echo -e "${green}脚本已更新完成！${reset}"
            # 重新执行最新脚本
            exec bash "$INSTALL_PATH"
            ;;

        99) 
            echo -e "${yellow}正在卸载工具箱...${reset}"

            # 删除快捷指令
            remove_shortcut
 
            # 删除工具箱脚本
            if [[ -f "$INSTALL_PATH" ]]; then
            rm -f "$INSTALL_PATH"
            echo -e "${green}工具箱脚本已删除${reset}"
            fi
            # 删除首次运行标记文件
            MARK_FILE="$HOME/.iutoolbox"
            if [[ -f "$MARK_FILE" ]]; then
            rm -f "$MARK_FILE"
            fi
           echo -e "${red}卸载完成！${reset}"
           exit 0
           ;;
        0) exit 0 ;;
        *) echo -e "${red}无效选项${reset}"; return 1 ;;
    esac
}


# 主循环
while true; do
    show_main_menu
    echo -ne "${red}请输入要执行的编号${ORANGE}(0退出)${ORANGE}:${reset} "
    read -r main_choice

    # X/x 直接退出脚本
    if [[ "$main_choice" =~ ^[xX]$ ]]; then
        exit 0
    fi

    # 按回车刷新菜单
    if [[ -z "$main_choice" ]]; then
        continue
    fi

    # 输入 0 退出
    if [[ "$main_choice" == "0" ]]; then
        exit 0
    fi

    # 只允许数字输入
    if ! [[ "$main_choice" =~ ^[0-9]+$ ]]; then
        echo -e "${red}无效选项，请输入数字！${reset}"
        sleep 1
        continue
    fi

    # 判断范围
    if (( main_choice >= 1 && main_choice <= ${#MAIN_MENU[@]} )); then
        show_sub_menu "$main_choice"
    else
        echo -e "${red}无效选项${reset}"
        sleep 1
    fi
done
