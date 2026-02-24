#!/bin/bash
# ============================================
# 1Panel 本地应用更新脚本（安全备份 + 自动重启）
# ============================================

# 基本变量
LOCAL_PATH="/opt/1panel/resource/apps/local"
ZIP_URL="https://github.com/okxlin/appstore/archive/refs/heads/localApps.zip"
BACKUP_DIR="/opt/1panel/resource/apps/backup_$(date +%Y%m%d_%H%M%S)"

# 检查 1Panel 本地目录是否存在
if [ ! -d "$LOCAL_PATH" ]; then
    echo "❌ 未检测到 1Panel 本地应用目录：$LOCAL_PATH"
    echo "请确认 1Panel 是否已安装。"
    exit 1
fi

# 创建备份
echo "📦 正在备份本地应用到：$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -rf "$LOCAL_PATH"/* "$BACKUP_DIR"/

# 下载新版本应用包
echo "⬇️ 正在下载最新 localApps.zip ..."
wget -O "$LOCAL_PATH/localApps.zip" "$ZIP_URL"

# 解压覆盖
echo "📂 正在解压覆盖文件..."
unzip -o -d "$LOCAL_PATH" "$LOCAL_PATH/localApps.zip"

# 覆盖 apps 文件夹内容
cp -rf "$LOCAL_PATH/appstore-localApps/apps/"* "$LOCAL_PATH/"

# 清理临时文件
rm -rf "$LOCAL_PATH/appstore-localApps" "$LOCAL_PATH/localApps.zip"

# 自动重启 1Panel（改为 1pctl restart）
echo "🔄 正在重启 1Panel..."
if command -v 1pctl >/dev/null 2>&1; then
    1pctl restart
    echo "✅ 1Panel 已成功重启"
else
    echo "⚠️ 未检测到 1pctl 命令，请确认 1Panel 是否正确安装"
    echo "你可以手动执行：1pctl restart"
fi

echo "✅ 本地应用更新完成！"
echo "🗂 已备份旧版本到：$BACKUP_DIR"
