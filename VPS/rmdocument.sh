#!/bin/bash
# safe_delete_sudo.sh - 安全一键删除文件脚本（sudo版）

# 颜色提示
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

echo -e "${YELLOW}请输入要删除的文件路径或目录（支持通配符，例如 *.log）:${RESET}"
read target

# 检查输入是否为空
if [[ -z "$target" ]]; then
    echo -e "${RED}未输入文件或目录，退出。${RESET}"
    exit 1
fi

# 显示待删除文件列表
echo -e "${YELLOW}以下文件将被删除:${RESET}"
sudo ls -1 $target 2>/dev/null

# 确认操作
echo -e "${RED}确定要删除以上文件吗？此操作不可恢复！(y/N):${RESET}"
read confirm

if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    sudo rm -rf $target
    echo -e "${GREEN}删除完成！${RESET}"
else
    echo -e "${YELLOW}已取消删除。${RESET}"
fi
