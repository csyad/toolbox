#!/usr/bin/env bash
#
# Xray (HTTP) Alpine 多实例控制面板
# =========================================================
# 1. 核心控制与全局环境初始化
# =========================================================
set -Eeuo pipefail
export LANG=en_US.UTF-8

# ================== 颜色 ==================
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"

# ================== 基础变量 ==================
readonly TEMPLATE_NAME="xrayhttp"
readonly BASE_DIR="/etc/${TEMPLATE_NAME}"
readonly XRAY_BINARY="/usr/bin/${TEMPLATE_NAME}"
readonly REGISTRY_FILE="${BASE_DIR}/.instances.env"

CURRENT_INSTANCE="default"

# 降级备用版本
readonly BACKUP_VERSION="26.3.27"

TMP_DIR=$(mktemp -d -t xray_http.XXXXXX)

# ================== cleanup ==================
cleanup() {
    [[ -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

# ================== 日志与交互 ==================
info() { echo -e "${GREEN}[信息] $*${RESET}" >&2; }
warn() { echo -e "${YELLOW}[警告] $*${RESET}" >&2; }
error() { echo -e "${RED}[错误] $*${RESET}" >&2; }
pause() { read -n 1 -s -r -p "按任意键返回菜单..." || true; echo; }

# ================== 实例注册管理 ==================
register_instance() {
    local name="$1"
    [ -d "$BASE_DIR" ] || install -m 0755 -d "$BASE_DIR"
    touch "$REGISTRY_FILE"
    if ! grep -q "^${name}$" "$REGISTRY_FILE" 2>/dev/null; then
        echo "$name" >> "$REGISTRY_FILE"
    fi
}

sync_registry() {
    [ -d "$BASE_DIR" ] || install -m 0755 -d "$BASE_DIR"
    touch "$REGISTRY_FILE"
    local temp_reg=$(mktemp)
    for f in "${BASE_DIR}"/config_*.json; do
        [ -e "$f" ] || continue
        local name=$(basename "$f" | sed 's/^config_//;s/\.json$//')
        if [ -n "$name" ]; then echo "$name" >> "$temp_reg"; fi
    done
    mv -f "$temp_reg" "$REGISTRY_FILE"
    
    # 如果当前实例为空或不存在，尝试从注册表读取第一个
    if [ "$CURRENT_INSTANCE" = "default" ] && [ -s "$REGISTRY_FILE" ]; then
        local first_inst
        first_inst=$(head -n 1 "$REGISTRY_FILE")
        [ -n "$first_inst" ] && CURRENT_INSTANCE="$first_inst"
    fi
}

# ================== 获取公网IP ==================
get_public_ip() {
    local ip

    for cmd in "curl -4fsSL --max-time 5" "wget -4qO- --timeout=5"; do
        for url in "https://api.ipify.org" "https://ip.sb" "https://checkip.amazonaws.com"; do
            ip=$($cmd "$url" 2>/dev/null || true)
            if [[ -n "${ip:-}" ]]; then
                echo "$ip"
                return 0
            fi
        done
    done

    for cmd in "curl -6fsSL --max-time 5" "wget -6qO- --timeout=5"; do
        for url in "https://api.ipify.org" "https://ipv6.ip.sb"; do
            ip=$($cmd "$url" 2>/dev/null || true)
            if [[ -n "${ip:-}" ]]; then
                echo "$ip"
                return 0
            fi
        done
    done

    return 1
}

# ================== 检查端口占用 ==================
check_port() {
    local port="$1"
    if netstat -tuln 2>/dev/null | awk '{print $4}' | grep -qE "[:.]$port$"; then
        return 1
    fi
    return 0
}

# ================== 验证端口格式 ==================
is_valid_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -ge 1 ]] && [[ "$1" -le 65535 ]]
}

# ================== 获取可用随机端口 ==================
get_random_port() {
    local rand_port
    while true; do
        rand_port=$((RANDOM % 55536 + 10000))
        if check_port "$rand_port"; then
            echo "$rand_port"
            return 0
        fi
    done
}

# ================== 生成随机字符串 ==================
generate_random_string() {
    local length="$1"
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex "$((length / 2))"
    else
        tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c "$length" || echo "admin$(RANDOM)"
    fi
}

# ================== Alpine 架构检测 ==================
get_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) echo "64" ;;
        aarch64|arm64) echo "arm64-v8a" ;;
        armv7l) echo "arm32-v7a" ;;
        *) error "暂不支持的系统架构: $arch"; return 1 ;;
    esac
}

# ================== 自动获取最新版本号 ==================
get_latest_version() {
    local latest_version
    info "正在获取 GitHub 最新 Xray 版本号..."
    
    latest_version=$(curl -fsSL --max-time 10 "https://api.github.com/repos/XTLS/Xray-core/releases/latest" 2>/dev/null \
        | jq -r '.tag_name' 2>/dev/null || echo "")
        
    latest_version="${latest_version#v}"

    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        warn "通过 GitHub API 获取最新版本失败，将使用内置备用版本: v${BACKUP_VERSION}"
        echo "$BACKUP_VERSION"
    else
        info "成功获取最新版本: v${latest_version}"
        echo "$latest_version"
    fi
}

# ================== 从GitHub下载并解压Xray ==================
download_and_extract_xray() {
    local arch version
    arch=$(get_arch) || return 1
    version=$(get_latest_version)
    
    local download_url="https://github.com/XTLS/Xray-core/releases/download/v${version}/Xray-linux-${arch}.zip"
    local zip_file="$TMP_DIR/xray.zip"
    
    info "正在从 GitHub 下载 Xray v${version} (${arch})..."
    if ! curl -L -fsSL "$download_url" -o "$zip_file"; then
        error "从 GitHub 下载 Xray 失败，请检查网络连接。"
        return 1
    fi
    
    info "正在解压..."
    mkdir -p "$TMP_DIR/extracted"
    if ! unzip -qo "$zip_file" -d "$TMP_DIR/extracted"; then
        error "解压 Xray 压缩包失败，请确保系统已安装 unzip。"
        return 1
    fi
    
    mkdir -p "$(dirname "$XRAY_BINARY")"
    rm -f "$XRAY_BINARY"
    cp -f "$TMP_DIR/extracted/xray" "$XRAY_BINARY"
    chmod +x "$XRAY_BINARY"
    
    mkdir -p "/usr/share/${TEMPLATE_NAME}"
    cp -f "$TMP_DIR/extracted/geoip.dat" "/usr/share/${TEMPLATE_NAME}/" 2>/dev/null || true
    cp -f "$TMP_DIR/extracted/geosite.dat" "/usr/share/${TEMPLATE_NAME}/" 2>/dev/null || true
}

# ================== 配置 OpenRC 服务脚本 ==================
setup_openrc_service() {
    local rc_script="/etc/init.d/${TEMPLATE_NAME}"
    info "配置 OpenRC 服务脚本 [${rc_script}]..."
    
    cat > "$rc_script" <<EOF
#!/sbin/openrc-run

name="Xray HTTP Server"
description="Xray HTTP Server Service"
supervisor=supervise-daemon
command="${XRAY_BINARY}"
command_args="run -config ${BASE_DIR}/config_\${RC_SVCNAME#*@}.json"
rc_ulimit="-n 1000000"

depend() {
    use net
    after firewall
}

start_pre() {
    if [ "\${RC_SVCNAME}" = "${TEMPLATE_NAME}" ]; then
        eerror "请通过多实例子服务启动，例如: rc-service ${TEMPLATE_NAME}@<实例名> start"
        return 1
    fi
}
EOF

    chmod +x "$rc_script"
}

# ================== 获取服务状态与基础参数 ==================
get_xray_status() {
    if rc-service "${TEMPLATE_NAME}@${CURRENT_INSTANCE}" status 2>/dev/null | grep -q "started"; then
        echo -e "${GREEN}● 运行中${RESET}"
    else
        echo -e "${RED}● 未运行${RESET}"
    fi
}

get_xray_version() {
    if [[ -x "$XRAY_BINARY" ]]; then
        "$XRAY_BINARY" version 2>/dev/null \
            | grep -i "Xray" \
            | head -n 1 \
            | awk '{print $2}' || echo "未知"
    else
        echo "未安装"
    fi
}

get_listen_ip() {
    if sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null | grep -q '= 1'; then
        echo "0.0.0.0"
    else
        echo "::"
    fi
}

test_config() {
    local config_file="${BASE_DIR}/config_${CURRENT_INSTANCE}.json"
    if "$XRAY_BINARY" run -test -config "$config_file" >/dev/null 2>&1; then
        info "Configuration OK"
        return 0
    fi
    error "配置测试失败"
    return 1
}

restart_xray() {
    rc-service "${TEMPLATE_NAME}@${CURRENT_INSTANCE}" restart 2>/dev/null || true
    sleep 1

    if rc-service "${TEMPLATE_NAME}@${CURRENT_INSTANCE}" status 2>/dev/null | grep -q "started"; then
        info "${TEMPLATE_NAME}@${CURRENT_INSTANCE} 启动成功"
        return 0
    fi

    error "${TEMPLATE_NAME}@${CURRENT_INSTANCE} 启动失败"
    return 1
}

# ================== 写底层配置 ==================
write_config() {
    local port="$1"
    local user="$2"
    local pass="$3"
    local config_file="${BASE_DIR}/config_${CURRENT_INSTANCE}.json"
    
    local listen_ip
    listen_ip=$(get_listen_ip)

    mkdir -p "$(dirname "$config_file")"

    local settings_json
    if [[ -n "$user" && -n "$pass" ]]; then
        settings_json=$(jq -n --arg u "$user" --arg p "$pass" '{"accounts": [{"user": $u, "pass": $p}]}')
    else
        settings_json=$(jq -n '{"accounts": []}')
    fi

    jq -n \
        --arg listen "${listen_ip}" \
        --argjson port "${port}" \
        --argjson settings "${settings_json}" \
    '{
      "log": {"loglevel": "warning"},
      "inbounds": [{
        "listen": $listen,
        "port": $port,
        "protocol": "http",
        "settings": $settings,
        "sniffing": {
          "enabled": true,
          "destOverride": ["http", "tls", "quic"]
        }
      }],
      "outbounds": [{
        "protocol": "freedom",
        "settings": {
          "domainStrategy": "UseIPv4v6"
        }
      }]
    }' > "$config_file"

    chmod 644 "$config_file"
    register_instance "$CURRENT_INSTANCE"
}

# ================== 生成分享链接 ==================
generate_link() {
    local link_file="/root/proxynode/http/xray_http_${CURRENT_INSTANCE}.txt"
    mkdir -p "$(dirname "$link_file")"
    local config_file="${BASE_DIR}/config_${CURRENT_INSTANCE}.json"
    local ip
    if ! ip=$(get_public_ip); then
        error "获取公网 IP 失败"
        return 1
    fi

    local port user pass
    port=$(jq -r '.inbounds[0].port' "$config_file" 2>/dev/null || echo "8080")
    user=$(jq -r '.inbounds[0].settings.accounts[0].user // empty' "$config_file" 2>/dev/null || echo "")
    pass=$(jq -r '.inbounds[0].settings.accounts[0].pass // empty' "$config_file" 2>/dev/null || echo "")

    local display_ip="$ip"
    [[ "$ip" =~ ":" ]] && display_ip="[$ip]"

    {
        if [[ -n "$user" && -n "$pass" ]]; then
            echo "http://${user}:${pass}@${display_ip}:${port}"
        else
            echo "http://${display_ip}:${port}"
        fi
    } > "$link_file"
}

# ================== 显示配置 ==================
show_current_config() {
    local config_file="${BASE_DIR}/config_${CURRENT_INSTANCE}.json"
    if [[ ! -f "$config_file" ]]; then
        error "实例 [${CURRENT_INSTANCE}] 配置文件不存在"
        return
    fi

    local ip port user pass
    ip=$(get_public_ip || echo "未知")
    port=$(jq -r '.inbounds[0].port' "$config_file" 2>/dev/null || echo "未知")
    user=$(jq -r '.inbounds[0].settings.accounts[0].user // empty' "$config_file" 2>/dev/null || echo "")
    pass=$(jq -r '.inbounds[0].settings.accounts[0].pass // empty' "$config_file" 2>/dev/null || echo "")

    echo -e "${GREEN}====== Xray HTTP 实例 [${CURRENT_INSTANCE}] 配置 ======${RESET}"
    echo -e "${YELLOW}服务器公网 IP   : ${ip}${RESET}"
    echo -e "${YELLOW}服务监听端口    : ${port}${RESET}"
    
    if [[ -n "$user" && -n "$pass" ]]; then
        echo -e "${YELLOW}认证方式        : 密码认证 (Password)${RESET}"
        echo -e "${YELLOW}用户名          : ${user}${RESET}"
        echo -e "${YELLOW}密码            : ${pass}${RESET}"
    else
        echo -e "${YELLOW}认证方式        : 免密认证 (NoAuth)${RESET}"
    fi

    local link_file="/root/proxynode/http/xray_http_${CURRENT_INSTANCE}.txt"
    if [[ -f "$link_file" ]]; then
        local display_ip="$ip"
        [[ "$ip" =~ ":" ]] && display_ip="[$ip]"
        echo -e "${GREEN}====== HTTP 配置 (已存至 $link_file) ======${RESET}"
        if [[ -n "$user" && -n "$pass" ]]; then
            echo -e "${YELLOW}● 客户端直连格式:${RESET} http://${user}:${pass}@${display_ip}:${port}"
        else
            echo -e "${YELLOW}● 客户端直连格式:${RESET} http://${display_ip}:${port}"
        fi
    fi
}

# ================== 核心交互配置处理 ==================
configure_xray() {
    info "开始配置 HTTP 服务端节点 [${CURRENT_INSTANCE}]..."
    local port user pass auth_choice

    while true; do
        read -rp "请输入监听端口 (直接回车随机分配端口): " input_port
        if [[ -z "$input_port" ]]; then
            port=$(get_random_port)
            info "已为您随机分配未被占用端口: $port"
            break
        elif is_valid_port "$input_port"; then
            if ! check_port "$input_port"; then
                error "端口 ${input_port} 已被占用，请重新输入。"
                continue
            fi
            port="$input_port"
            break
        else
            error "端口无效"
        fi
    done

    echo -e "${GREEN}请选择认证方式:${RESET}"
    echo -e " 1. 密码认证 (需要用户名和密码)"
    echo -e " 2. 免密认证 (允许任何人直接连接)"
    while true; do
        read -rp "请输入选项 [1-2, 默认 1]: " auth_choice
        auth_choice="${auth_choice:-1}"

        if [[ "$auth_choice" == "1" ]]; then
            read -rp "请输入 HTTP 用户名 (直接回车自动随机生成): " input_user
            if [[ -z "$input_user" ]]; then
                user=$(generate_random_string 8)
                info "已自动生成随机账号：${user}"
            else
                user="$input_user"
            fi

            read -rp "请输入 HTTP 密码 (直接回车自动随机生成): " input_pass
            if [[ -z "$input_pass" ]]; then
                pass=$(generate_random_string 12)
                info "已自动生成高强度密码：${pass}"
            else
                pass="$input_pass"
            fi
            break
        elif [[ "$auth_choice" == "2" ]]; then
            user=""
            pass=""
            info "已选择：免密认证 (NoAuth)"
            break
        else
            error "输入无效，请输入 1 或 2"
        fi
    done

    write_config "$port" "$user" "$pass"
    test_config || return 1
    generate_link
    
    ln -sf "/etc/init.d/${TEMPLATE_NAME}" "/etc/init.d/${TEMPLATE_NAME}@${CURRENT_INSTANCE}" 2>/dev/null || true
    rc-update add "${TEMPLATE_NAME}@${CURRENT_INSTANCE}" default 2>/dev/null || true
    
    restart_xray
    show_current_config
}

# ================== 安装 ==================
install_xray() {
    info "开始安装 Xray 核心依赖..."
    download_and_extract_xray || return 1
    setup_openrc_service
    configure_xray
    info "安装完成并已成功启动实例: ${CURRENT_INSTANCE}"
}

# ================== 更新 ==================
update_xray() {
    info "开始更新 Xray 程序..."
    
    if ! download_and_extract_xray; then
        error "下载或安装新版本失败。"
        return 1
    fi
    
    sync_registry
    if [ -f "$REGISTRY_FILE" ]; then
        while IFS= read -r name || [ -n "$name" ]; do
            [ -z "$name" ] && continue
            rc-service "${TEMPLATE_NAME}@${name}" restart 2>/dev/null || true
        done < "$REGISTRY_FILE"
    fi
    info "内核更新完毕，所有实例已重新加载！当前版本: $(get_xray_version)"
}

# ================== 修改配置 ==================
modify_config() {
    local config_file="${BASE_DIR}/config_${CURRENT_INSTANCE}.json"
    if [[ ! -f "$config_file" ]]; then
        error "实例 [${CURRENT_INSTANCE}] 配置文件不存在"
        return 1
    fi

    local old_port old_user old_pass
    old_port=$(jq -r '.inbounds[0].port' "$config_file" 2>/dev/null || echo "8080")
    old_user=$(jq -r '.inbounds[0].settings.accounts[0].user // empty' "$config_file" 2>/dev/null || echo "")
    old_pass=$(jq -r '.inbounds[0].settings.accounts[0].pass // empty' "$config_file" 2>/dev/null || echo "")

    local port user pass auth_choice

    while true; do
        read -rp "请输入新端口 [当前:${old_port}, 回车不修改]: " input_port
        if [[ -z "$input_port" ]]; then
            port="$old_port"
            break
        elif is_valid_port "$input_port"; then
            if [[ "$input_port" != "$old_port" ]] && ! check_port "$input_port"; then
                error "端口 ${input_port} 已被占用，请更换。"
                continue
            fi
            port="$input_port"
            break
        else
            error "端口无效"
        fi
    done

    local current_mode="密码认证"
    [[ -z "$old_user" ]] && current_mode="免密认证"

    echo -e "${GREEN}请选择新的认证方式 [当前: ${current_mode}]:${RESET}"
    echo -e " 1. 密码认证"
    echo -e " 2. 免密认证"
    while true; do
        read -rp "请输入选项 [1-2, 回车保持当前]: " auth_choice
        if [[ -z "$auth_choice" ]]; then
            user="$old_user"
            pass="$old_pass"
            if [[ -n "$user" ]]; then
                read -rp "是否修改用户名？[当前:${old_user}, 回车不修改]: " input_user
                [[ -n "$input_user" ]] && user="$input_user"
                read -rp "是否修改密码？[当前:${old_pass}, 回车不修改]: " input_pass
                [[ -n "$input_pass" ]] && pass="$input_pass"
            fi
            break
        fi

        if [[ "$auth_choice" == "1" ]]; then
            read -rp "请输入新用户名 [旧:${old_user:-无}, 回车自动生成]: " input_user
            if [[ -z "$input_user" ]]; then
                user=$(generate_random_string 8)
                info "已自动生成随机账号：${user}"
            else
                user="$input_user"
            fi

            read -rp "请输入新密码 [旧:${old_pass:-无}, 回车自动生成]: " input_pass
            if [[ -z "$input_pass" ]]; then
                pass=$(generate_random_string 12)
                info "已自动生成高强度密码：${pass}"
            else
                pass="$input_pass"
            fi
            break
        elif [[ "$auth_choice" == "2" ]]; then
            user=""
            pass=""
            info "已切换为：免密认证 (NoAuth)"
            break
        else
            error "输入无效，请输入 1 或 2"
        fi
    done

    cp "$config_file" "${config_file}.bak.$(date +%s)"
    write_config "$port" "$user" "$pass"
    test_config || return 1
    generate_link
    restart_xray
    info "配置修改成功"
}

# ================== 卸载当前实例 ==================
uninstall_xray() {
    warn "即将彻底卸载并清理当前聚焦的实例 [${CURRENT_INSTANCE}]..."

    rc-service "${TEMPLATE_NAME}@${CURRENT_INSTANCE}" stop 2>/dev/null || true
    rc-update del "${TEMPLATE_NAME}@${CURRENT_INSTANCE}" default 2>/dev/null || true
    rm -f "/etc/init.d/${TEMPLATE_NAME}@${CURRENT_INSTANCE}"
    
    rm -f "${BASE_DIR}/config_${CURRENT_INSTANCE}.json"
    rm -f "/root/proxynode/http/xray_http_${CURRENT_INSTANCE}.txt"

    sed -i "/^${CURRENT_INSTANCE}$/d" "$REGISTRY_FILE" 2>/dev/null || true
    info "实例 [${CURRENT_INSTANCE}] 已移除。"

    sync_registry
    if [ ! -s "$REGISTRY_FILE" ]; then
        info "检测到矩阵内已无活跃节点，自动清理全局共享服务..."
        rm -f "/etc/init.d/${TEMPLATE_NAME}"
        rm -f "$XRAY_BINARY"
        rm -rf "$BASE_DIR"
        rm -rf "/usr/share/${TEMPLATE_NAME}"
        CURRENT_INSTANCE="default"
    fi
}

# ================== 多实例切换与管理中心 ==================
menu_switch_matrix() {
    echo -e "\n${GREEN}==== [Xray HTTP 多开实例中心] ====${RESET}"
    echo -e "${GREEN}当前操作目标实例: ${YELLOW}${CURRENT_INSTANCE}${RESET}"
    echo -e "${GREEN}当前独立实例列表:${RESET}"

    sync_registry
    local count=0
    local -a instance_list=()

    if [ -f "$REGISTRY_FILE" ]; then
        while IFS= read -r name || [ -n "$name" ]; do
            [ -z "$name" ] && continue
            local c_file="${BASE_DIR}/config_${name}.json"
            [ -f "$c_file" ] || continue

            count=$((count + 1))
            instance_list[$count]="$name"
            
            local port_num=$(jq -r '.inbounds[0].port' "$c_file" 2>/dev/null || echo "")
            local status_str="${RED}已停止${RESET}"
            if rc-service "${TEMPLATE_NAME}@${name}" status 2>/dev/null | grep -q "started"; then status_str="${GREEN}运行中${RESET}"; fi
            echo -e " ${CYAN}[ ${count} ] ->${GREEN} 实例名: ${YELLOW}${name}${RESET} ${GREEN}[端口: ${port_num} | 状态: ${status_str}${GREEN}]${RESET}"
        done < "$REGISTRY_FILE"
    fi

    [ "$count" -eq 0 ] && echo -e " ${YELLOW}(当前无活跃实例，可在下方输入新名称直接创建)${RESET}"
    
    echo ""
    echo -e "${GREEN}👉 输入已有实例的【数字编号】切换管理目标${RESET}"
    echo -e "${GREEN}👉 或者输入【全新的英文名称】创建新的多开实例${RESET}"
    echo -ne "${YELLOW}请输入选择或名称: ${RESET}"
    read -r input_val || true
    [[ -z "$input_val" ]] && return

    if [[ "$input_val" =~ ^[0-9]+$ ]]; then
        if [ "$input_val" -gt 0 ] && [ "$input_val" -le "$count" ]; then
            CURRENT_INSTANCE="${instance_list[$input_val]}"
            echo -e "${GREEN}焦点成功切为: ${YELLOW}${CURRENT_INSTANCE}${RESET}"
        else error "编号超出可用范围！"; fi
    else
        if [[ "$input_val" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            CURRENT_INSTANCE="$input_val"
            echo -e "${GREEN}成功创建/锁定新实例: ${YELLOW}${CURRENT_INSTANCE}${RESET}${GREEN} (请在菜单选择 [1] 下发部署)${RESET}"
        else error "命名不规范，仅限使用英文字母, 数字, 中划线和下划线！"; fi
    fi
}

# ================== 菜单 ==================
show_menu() {
    clear
    local status version port_show
    status=$(get_xray_status)
    version=$(get_xray_version)
    port_show="-"

    local config_file="${BASE_DIR}/config_${CURRENT_INSTANCE}.json"
    if [[ -f "$config_file" ]]; then
        port_show=$(jq -r '.inbounds[0].port' "$config_file" 2>/dev/null || echo "-")
    fi

    echo -e "${GREEN}================================${RESET}"
    echo -e "${GREEN}       Xray HTTP 多实例面板     ${RESET}"
    echo -e "${GREEN}================================${RESET}"
    echo -e "${GREEN}当前实例 :${RESET} ${YELLOW}${CURRENT_INSTANCE}${RESET}"
    echo -e "${GREEN}运行状态 :${RESET} $status"
    echo -e "${GREEN}内核版本 :${RESET} ${YELLOW}${version}${RESET}"
    echo -e "${GREEN}监听端口 :${RESET} ${YELLOW}${port_show}${RESET}"
    echo -e "${GREEN}================================${RESET}"
    echo -e "${GREEN} 1. 安装当前实例${RESET}"
    echo -e "${GREEN} 2. 更新内核程序${RESET}"
    echo -e "${GREEN} 3. 卸载当前实例${RESET}"
    echo -e "${GREEN} 4. 修改当前配置${RESET}"
    echo -e "${GREEN} 5. 启动当前实例${RESET}"
    echo -e "${GREEN} 6. 停止当前实例${RESET}"
    echo -e "${GREEN} 7. 重启当前实例${RESET}"
    echo -e "${GREEN} 8. 查看实时日志${RESET}"
    echo -e "${GREEN} 9. 查看节点配置${RESET}"
    echo -e "${GREEN}10. 管理实例${RESET}       ${YELLOW}← 添加/切换节点${RESET}"
    echo -e "${GREEN} 0. 退出${RESET}"
    echo -e "${GREEN}================================${RESET}"
}

# ================== Alpine 安装依赖 ==================
install_dependencies() {
    if command -v apk &>/dev/null; then
        apk update && apk add --no-cache bash jq curl wget sed coreutils unzip net-tools openssl
    else
        error "未检测到 Alpine apk 包管理器！"
        exit 1
    fi
}

# ================== 依赖检查 ==================
pre_check() {
    if [[ $(id -u) -ne 0 ]]; then
        error "请使用 root 用户运行"
        exit 1
    fi

    local deps=(jq curl wget unzip awk sed openssl)
    local missing=0

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing=1
            break
        fi
    done

    if [[ "$missing" -eq 1 ]]; then
        info "检测到缺失依赖，正在安装..."
        install_dependencies
    fi
}

# ================== 主循环 ==================
main() {
    pre_check
    sync_registry

    while true; do
        show_menu
        
        local choice=""
        read -r -p $'\033[32m请输入选项: \033[0m' choice || true
        
        [[ -z "$choice" ]] && continue

        case "$choice" in
            1) install_xray; pause ;;
            2) update_xray; pause ;;
            3) uninstall_xray; pause ;;
            4) modify_config; pause ;;
            5) rc-service "${TEMPLATE_NAME}@${CURRENT_INSTANCE}" start 2>/dev/null || true; restart_xray; pause ;;
            6) rc-service "${TEMPLATE_NAME}@${CURRENT_INSTANCE}" stop 2>/dev/null || true; info "服务已停止"; pause ;;
            7) restart_xray; pause ;;
            8) tail -n 50 /var/log/messages 2>/dev/null || rc-service "${TEMPLATE_NAME}@${CURRENT_INSTANCE}" status; pause ;;
            9) show_current_config; pause ;;
            10) menu_switch_matrix ;;
            0) exit 0 ;;
            *) error "无效输入"; pause ;;
        esac
    done
}

main "$@"