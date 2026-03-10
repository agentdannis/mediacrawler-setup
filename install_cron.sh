#!/usr/bin/env bash
# 安装 cron 定时任务：每 12 小时自动保活 session
#
# 原理：
#   定期运行 keep_alive.py --refresh，执行一次轻量爬取
#   Playwright 持久化上下文会自动保存续期后的 cookie
#   只要间隔不超过 cookie 有效期，session 永远不过期

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UV_BIN="$HOME/.local/bin/uv"
KEEP_ALIVE="$SCRIPT_DIR/keep_alive.py"
LOG_FILE="$SCRIPT_DIR/keep_alive.log"

if ! command -v crontab &>/dev/null; then
    echo "错误: 系统未安装 cron"
    exit 1
fi

# 构建 cron 命令
CRON_CMD="cd $SCRIPT_DIR/MediaCrawler && $UV_BIN run python $KEEP_ALIVE --refresh >> $LOG_FILE 2>&1"

# 检查是否已安装
if crontab -l 2>/dev/null | grep -q "keep_alive.py"; then
    echo "cron 任务已存在，更新中..."
    crontab -l 2>/dev/null | grep -v "keep_alive.py" | crontab -
fi

# 每 12 小时运行一次（0:00 和 12:00）
(crontab -l 2>/dev/null; echo "0 */12 * * * $CRON_CMD") | crontab -

echo "=== Cron 任务已安装 ==="
echo "  频率: 每 12 小时"
echo "  日志: $LOG_FILE"
echo ""
echo "查看: crontab -l"
echo "删除: crontab -l | grep -v keep_alive | crontab -"
