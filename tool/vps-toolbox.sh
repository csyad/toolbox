#!/bin/bash
# VPS Toolbox
# 功能：
# - 一级菜单加 ▶ 标识，字体绿色
# - 二级菜单简洁显示，输入 1~99 都可执行
# - 快捷指令 m / M 自动创建
# - 系统信息面板
# - 彩色菜单和动态彩虹标题
# - 完整安装/卸载

INSTALL_PATH="/etc/vps-toolbox.sh"
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



# ==========================================
# GITHUB 代理
# ==========================================
GITHUB_PROXY=(
    ''
    'https://v6.gh-proxy.org/'
    'https://ghfast.top/'
    'https://gh-proxy.com/'
    'https://hub.glowp.xyz/'
    'https://proxy.vvvv.ee/'
    'https://ghproxy.lvedong.eu.org/'
)

# 新增全局缓存变量，记录上一次成功的最快索引（默认从 0 开始，即直连）
# 只要这个索引成功过，后面所有下载直接秒开，不再卡顿死等
if [ -z "$SUCCESS_PROXY_IDX" ]; then
    SUCCESS_PROXY_IDX=0
fi

# 核心内部优化轮询器：带有记忆和快速跳过功能
_smart_download_core() {
    local clean_url="$1"
    local mode="$2"       # text (用于curl输出), file (用于wget存盘), pipe (用于管道)
    local file_name="$3"  # 仅file模式需要

    # 1. 优先尝试上一次成功的那个通道 (秒开逻辑)
    local best_proxy="${GITHUB_PROXY[$SUCCESS_PROXY_IDX]}"
    local target_url="${best_proxy}${clean_url}"
    
    # 降低首次尝试的超时时间到 4 秒，防止用户等太久
    if [[ "$mode" == "text" || "$mode" == "pipe" ]]; then
        if response=$(curl -fsSL --max-time 4 "$target_url" 2>/dev/null) && [[ -n "$response" ]]; then
            echo "$response"
            return 0
        fi
    elif [[ "$mode" == "file" ]]; then
        if wget -T 4 -t 1 -q -O "$file_name" "$target_url" 2>/dev/null; then
            return 0
        fi
    fi

    # 2. 如果上一次成功的通道失效了，或者第一次运行失败了，才触发全量轮询
    for idx in "${!GITHUB_PROXY[@]}"; do
        # 跳过刚才已经试过失败的那个索引
        [[ $idx -eq $SUCCESS_PROXY_IDX ]] && continue
        
        local proxy="${GITHUB_PROXY[$idx]}"
        local target_url="${proxy}${clean_url}"
        
        if [[ "$mode" == "file" ]]; then
            echo -e "${yellow}⚡ 正在切换通道，尝试通过 [${proxy:-直连}]打开...${reset}"
            if wget -T 5 -t 1 -q -O "$file_name" "$target_url" 2>/dev/null; then
                SUCCESS_PROXY_IDX=$idx # 记住这个成功的位置
                return 0
            fi
        else
            if response=$(curl -fsSL --max-time 5 "$target_url" 2>/dev/null) && [[ -n "$response" ]]; then
                SUCCESS_PROXY_IDX=$idx # 记住这个成功的位置
                echo "$response"
                return 0
            fi
        fi
    done

    return 1
}

# 1：普通下载器
smart_curl() {
    local raw_url="$1"
    if [[ ! "$raw_url" =~ "github" ]] && [[ ! "$raw_url" =~ "raw.githubusercontent.com" ]]; then
        curl -fsSL --max-time 10 "$raw_url"
        return $?
    fi
    local clean_url=$(echo "$raw_url" | sed -E 's|https://[^/]*/https://github.com/|https://github.com/|g' | sed -E 's|https://[^/]*/https://raw.githubusercontent.com/|https://raw.githubusercontent.com/|g')
    
    _smart_download_core "$clean_url" "text"
    if [[ $? -ne 0 ]]; then
        echo -e "${red}❌ 错误: 所有代理节点及直连均无法访问该资源！${reset}" >&2
        return 1
    fi
}

# 2：存盘执行器
smart_wget_run() {
    local file_name="$1"
    local raw_url="$2"
    local clean_url=$(echo "$raw_url" | sed -E 's|https://[^/]*/https://|https://|g')

    if _smart_download_core "$clean_url" "file" "$file_name"; then
        echo
        chmod +x "$file_name"
        ./"$file_name"
        return 0
    else
        echo -e "${red}❌ 错误: 所有代理节点及直连均无法访问该资源！${reset}"
        return 1
    fi
}

# 3：管道带参执行器
smart_pipe_run() {
    local raw_url="$1"
    local bash_args="$2"
    local clean_url=$(echo "$raw_url" | sed -E 's|https://[^/]*/https://|https://|g')

    local response
    response=$(_smart_download_core "$clean_url" "pipe")
    
    if [[ -n "$response" ]]; then
        echo
        if [[ -n "$bash_args" ]]; then
            sudo bash -s $bash_args <<< "$response"
        else
            sudo bash <<< "$response"
        fi
        return 0
    else
        echo -e "${red}❌ 错误: 所有代理节点及直连均无法访问该资源！${reset}"
        return 1
    fi
}
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
        system_status="${yellow}系统状态：警告 ⚡${reset}"
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



# ===============================
# 获取当前时区（跨系统兼容）
# ===============================
get_timezone() {
    # 1️⃣ systemd 环境，屏蔽错误
    if command -v timedatectl &>/dev/null; then
        tz=$(timedatectl show -p Timezone --value 2>/dev/null)
        [[ -n "$tz" ]] && echo "$tz" && return
    fi

    # 2️⃣ /etc/timezone 文件（Debian）
    if [[ -f /etc/timezone ]]; then
        tz=$(cat /etc/timezone)
        [[ -n "$tz" ]] && echo "$tz" && return
    fi

    # 3️⃣ /etc/localtime 符号链接（RedHat / CentOS）
    if [[ -L /etc/localtime ]]; then
        tz=$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')
        [[ -n "$tz" ]] && echo "$tz" && return
    fi

    # 4️⃣ /etc/localtime 文件内容匹配（minimal / docker / chroot）
    if [[ -f /etc/localtime ]]; then
        tz=$(strings /etc/localtime 2>/dev/null | grep -E '^[A-Z][a-z]+/[A-Z][a-zA-Z_]+$' | head -n1)
        [[ -n "$tz" ]] && echo "$tz" && return
    fi

    # 5️⃣ 兜底
    echo "未知"
}

timezone=$(get_timezone)

# 架构

cpu_arch=$(uname -m)

# 获取 CPU 型号
cpu_model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2)
[ -z "$cpu_model" ] && cpu_model=$(grep -m1 "Hardware" /proc/cpuinfo 2>/dev/null | cut -d: -f2)
[ -z "$cpu_model" ] && cpu_model=$(lscpu 2>/dev/null | grep "Model name" | cut -d: -f2)

# 清理不需要的部分
cpu_model=$(echo "$cpu_model" | sed -E \
    -e 's/@.*GHz//g' \
    -e 's/CPU//g' \
    -e 's/Processor//g' \
    -e 's/[0-9]+-Core//g' \
	-e 's/\bv[1-9]\b//g' \
    -e 's/\s+/ /g' \
    | xargs)

cpu="${cpu_model:-Unknown CPU} (${cpu_arch})"


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
    "证书管理"
    "系统管理"
    "备份恢复"
    "玩具熊ʕ•ᴥ•ʔ"
    "更新卸载"
)

# 二级菜单（编号去掉前导零，显示时格式化为两位数）
SUB_MENU[1]="1 更新系统|2 系统信息|3 修改root密码|4 root登录管理|5 修改SSH端口|6 修改时区|7 时间同步|8 切换v4V6|9 开放所有端口|10 更换系统源|11 DDdebian13|12 DDwindows|13 NAT鸡重装系统|14 DD飞牛|15 修改语言|16 修改主机名|17 DNS优化|18 一键优化✨|19 VPS重启"
SUB_MENU[2]="20 代理工具箱|21 FRP管理|22 EasyTier组网|23 ShellCrash|24 CFWARP|25 BBRv3|26 BBR+TCP智能调参|27 Socks5/HTTP|28 VlessReality|29 Snell|30 Shadowsocks|31 VlessEncryption|32 Hysteria2|33 Xray-Argo|34 3X-UI|35 nftables|36 Realm|37 哆啦A梦转发面板|38 DDNS动态域名|39 流媒体DNS解锁|40 流量狗|41 流量监控"
SUB_MENU[3]="42 NodeQuality|43 融合怪测试|44 YABS测试|45 网络质量体检|46 IP质量体检|47 硬盘质量体检|48 TcpQuality|49 简单回程测试|50 完整路由检测|51 流媒体解锁|52 三网测速|53 网络PING/DNS检测|54 检查25端口开放|55 网络工具箱"
SUB_MENU[4]="56 Docker管理|57 DockerCompose管理|58 DockerCompose备份恢复|59 DockerCompose自动更新"
SUB_MENU[5]="60 应用管理|61 宝塔面板|62 1Panel面板|63 MCSManager游戏开服|64 CLICD开小鸡|65 OpenClaw|66 HermesAgent"
SUB_MENU[6]="67 NGINXV4反代✨|68 NGINXV6反代|69 Caddy反代|70 Acme申请证书|71 Lucky反代"
SUB_MENU[7]="72 系统清理|73 重装系统|74 系统组件|75 开发环境|76 工作区管理|78 防火墙管理|79 Fail2ban|80 系统监控|81 添加SWAP|82 DNS管理|83 定时任务"
SUB_MENU[8]="84 系统快照|85 系统恢复|86 本地备份|87 Rsync同步|89 Rclone备份|90 Croc文件传输|91 TGBot备份|92 压缩文件|93 解压文件"
SUB_MENU[9]="100 GProxy加速|101 Cloudflare隧道|102 Aria2|103 yt-dlp|104 机场签到|105 关闭哪吒监控SSH|106 AI检测|107 代理检测|108 容器检测|109 清理镜像卷|110 卸载探针"
SUB_MENU[10]="77 自动更新|88 更新工具箱|99 卸载工具箱"

# 显示一级菜单
show_main_menu() {
    clear
    # 上边框保留彩虹效果
    rainbow_animate "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 标题文字改为纯黄色
    echo -e "${ORANGE}📦 VPS Toolbox工具箱${reset}${yellow}(快捷指令:M/m)${reset} ${ORANGE}📦${reset}"

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
    printf "${ORANGE}%s %-*s:${yellow} %s${re}\n" "🧩" $label_w "架构" "$cpu"
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
        1) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/update.sh) ;;
        2) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/vpsinfo.sh) ;;
        3) sudo passwd root ;;
        4) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/SSHDLGL.sh) ;;
        5) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/sshdk.sh) ;;
        6) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/time.sh) ;;
        7) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/systemdtimesyncd.sh) ;;
        8) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/qhwl.sh) ;;
        9) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/UFWFX.sh) ;;
        10) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/huanyuan.sh) ;;
        11) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/Debian13.sh) ;;
        12) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/windowos.sh) ;;
        13) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/DDnat.sh) ;;
        14) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/ddfnos.sh) ;;
        15) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/xgyu.sh) ;;
        16) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/home.sh) ;;
        17) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Mosdnsxos.sh) ;;
        18) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/vpsupos.sh) ;;
        19) sudo reboot ;;
        20) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/proxy.sh) ;;
        21) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/FRPos.sh) ;;
        22) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/EasyTierx.sh) ;;
        23) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/ShellCrash.sh) ;;
        24) wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh ;;
        25) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/BBRv3os.sh) ;;
        26) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/BBR.sh) ;;
        27) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/MicaProxyos.sh) ;;
        28) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/XrayVLESS-Realityos.sh) ;;
        29) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Snellv6SSos.sh) ;;
        30) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/SS-2022os.sh) ;;
        31) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/XrayVLESS-Encryptionos.sh) ;;
        32) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Hysteria2os.sh) ;;
        33) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/2go.sh) ;;
        34) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/3xuios.sh) ;;
        35) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/nftablesos.sh) ;;
        36) smart_pipe_run "https://raw.githubusercontent.com/zywe03/realm-xwPF/main/xwPF.sh" "install" ;;
        37) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/flux-panel.sh);;
        38) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/DDNS.sh) ;;
        39) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/SNIProxyDNSos.sh) ;;
        40) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/port-traffic-dog.sh) ;;
        41) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/vnstat.sh) ;;
        42) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/NodeQuality.sh) ;;
        43) curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh ;;
        44) curl -sL https://yabs.sh | bash ;;
        45) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/NetQuality.sh) ;;
        46) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/IPQuality.sh) ;;
        47) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/HardwareQuality.sh) ;;
        48) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/TcpQuality.sh) ;;
        49) curl https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh -sSf | sh ;;
        50) bash <(curl -Ls https://Net.Check.Place) -R ;;
        51) bash <(curl -Ls unlock.icmp.ing/scripts/test.sh) ;;
        52) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/ecsspeed.sh) ;;
        53) bash <(wget -qO- https://raw.githubusercontent.com/Cd1s/network-latency-tester/main/latency.sh) ;;
        54) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/Telnet.sh) ;;
        55) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/Networktoolx.sh) ;; 
        56) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Dockersos.sh) ;;
        57) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/dockercompose.sh) ;;
        58) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Dockcompbauck.sh) ;;
        59) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/dockerupdate.sh) ;;
        60) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Store.sh) ;;
        61) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/Baotax.sh) ;;
        62) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/1Panelx.sh) ;;
        63) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/Games/MCSManager.sh) ;;
        64) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/NAT/CLICD.sh) ;;
        65) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/AI/OpenClaw.sh) ;;
        66) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/AI/Hermes.sh) ;;
        67) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Nginxos.sh) ;;
        68) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Nginx6os.sh) ;;
        69) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Caddyos.sh) ;;
        70) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Acmeos.sh) ;;
        71) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Lucky.sh) ;;
        72) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/clear.sh) ;;
        73) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/reinstall.sh) ;;
        74) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/package.sh) ;;
        75) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/exploitation.sh) ;;
        76) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/tmux.sh) ;;
        78) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/firewallos.sh) ;;
        79) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Fail2banos.sh) ;;
        80) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/System.sh) ;;
        81) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/SWAP.sh) ;;
        82) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/DNSos.sh) ;;
        83) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/crontab.sh) ;;
        84) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/snapshotBos.sh) ;;
        85) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/snapshotRos.sh) ;;
        86) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/beifen.sh) ;;
        87) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/Rrsync.sh) ;;
        89) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Rcloneos.sh) ;;
        90) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/Croc.sh) ;;
        91) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/VPSTGbackup.sh) ;;
        92) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/yasuo.sh) ;;
        93) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/tarzip.sh) ;;
        100) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/CN/CNGProxy.sh) ;;
        101) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/PROXY/Cloudflarehp2.sh) ;;
        102) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Aria2.sh) ;;
        103) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/yt-dlp.sh) ;;
        104) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/toy/JCQD.sh) ;;
        105) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/nezhassh.sh) ;;
		106) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/AI/AIcheck.sh) ;;
        107) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/test.sh) ;;
        108) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Dockermo.sh) ;;
        109) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Dockerclear.sh) ;;
        110) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/VPS/unagent.sh) ;;

        #  自动更新脚本
        77) bash <(smart_curl https://raw.githubusercontent.com/sistarry/toolbox/main/tool/toolboxupdates.sh) ;; 
        88)
            echo -e "${yellow}正在更新工具箱...${reset}"
            
            # 使用 smart_curl 获取内容并覆盖写入到本地脚本路径
            # smart_curl 会自动处理：直连 -> 失败则依次轮询各代理节点
            if ! smart_curl "https://raw.githubusercontent.com/sistarry/toolbox/main/tool/vps-toolbox.sh" > "$INSTALL_PATH"; then
                echo -e "${red}更新失败，所有代理及直连均无法访问，请检查网络！${reset}"
                return 1
            fi
            
            # 检查下载的文件是否为空（防止意外下载到空内容把本地脚本整坏）
            if [[ ! -s "$INSTALL_PATH" ]]; then
                echo -e "${red}更新失败：下载的文件为空，已终止覆盖！${reset}"
                return 1
            fi

            chmod +x "$INSTALL_PATH"
            echo -e "${green}更新完成！${reset}"
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
            echo -e "${green}工具箱已删除${reset}"
            fi
            # 删除首次运行标记文件
            MARK_FILE="$HOME/.vpstoolbox"
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
