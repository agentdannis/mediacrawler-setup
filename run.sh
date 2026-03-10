#!/usr/bin/env bash
# MediaCrawler 小红书爬虫 - 运行脚本（适配无头 Linux 服务器）
#
# 用法:
#   bash run.sh                          # 使用 .env 中的配置
#   bash run.sh "关键词1,关键词2"         # 指定关键词
#   XHS_WEB_SESSION=xxx bash run.sh      # 临时指定 cookie
#
# 工作流程:
#   1. 首次运行: 需要 .env 中的 XHS_WEB_SESSION（从有浏览器的机器获取一次）
#   2. 后续运行: Playwright 持久化上下文自动复用登录状态，不再需要 cookie
#   3. 保活: 配合 install_cron.sh 每 12 小时自动保活，session 永不过期

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/MediaCrawler"
CONFIG_FILE="$PROJECT_DIR/config/base_config.py"
ENV_FILE="$SCRIPT_DIR/.env"
BROWSER_DATA="$PROJECT_DIR/browser_data/xhs_user_data_dir"

export PATH="$HOME/.local/bin:$PATH"

# 加载 .env
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# 参数
KEYWORDS="${1:-${XHS_KEYWORDS:-Python学习}}"
MAX_NOTES="${XHS_MAX_NOTES:-15}"
WEB_SESSION="${XHS_WEB_SESSION:-}"

# 判断是否需要 cookie（首次运行 vs 后续运行）
if [ -d "$BROWSER_DATA" ]; then
    echo "=== 检测到已有登录状态，跳过 cookie 设置 ==="
    LOGIN_TYPE="cookie"
    COOKIE_VALUE=""
else
    # 首次运行，需要 cookie
    if [ -z "$WEB_SESSION" ] || [ "$WEB_SESSION" = "your_web_session_here" ]; then
        echo "错误: 首次运行需要 XHS_WEB_SESSION"
        echo ""
        echo "获取方式（只需一次）:"
        echo "  1. 在有浏览器的机器上打开 www.xiaohongshu.com 并登录"
        echo "  2. F12 -> Application -> Cookies -> 复制 web_session 的值"
        echo "  3. 填入 .env 文件: XHS_WEB_SESSION=xxx"
        echo ""
        echo "设置后运行 bash run.sh，之后不再需要手动更新 cookie"
        exit 1
    fi
    echo "=== 首次运行，使用 cookie 初始化登录状态 ==="
    LOGIN_TYPE="cookie"
    COOKIE_VALUE="web_session=$WEB_SESSION"
fi

echo "  关键词: $KEYWORDS"
echo "  最大笔记数: $MAX_NOTES"
echo ""

# 写入配置（headless + 标准模式，适配无头服务器）
cd "$PROJECT_DIR"
uv run python -c "
import re

config_path = 'config/base_config.py'
with open(config_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = {
    r'KEYWORDS\s*=\s*\"[^\"]*\"': 'KEYWORDS = \"$KEYWORDS\"',
    r'LOGIN_TYPE\s*=\s*\"[^\"]*\"': 'LOGIN_TYPE = \"$LOGIN_TYPE\"',
    r'COOKIES\s*=\s*\"[^\"]*\"': 'COOKIES = \"$COOKIE_VALUE\"',
    r'SAVE_DATA_OPTION\s*=\s*\"[^\"]*\"': 'SAVE_DATA_OPTION = \"sqlite\"',
    r'SAVE_LOGIN_STATE\s*=\s*(True|False)': 'SAVE_LOGIN_STATE = True',
    r'CRAWLER_MAX_NOTES_COUNT\s*=\s*\d+': 'CRAWLER_MAX_NOTES_COUNT = $MAX_NOTES',
    r'HEADLESS\s*=\s*(True|False)': 'HEADLESS = True',
    r'ENABLE_CDP_MODE\s*=\s*(True|False)': 'ENABLE_CDP_MODE = False',
}

for pattern, replacement in replacements.items():
    content = re.sub(pattern, replacement, content)

with open(config_path, 'w', encoding='utf-8') as f:
    f.write(content)
"

echo "=== 开始爬取 ==="
uv run main.py --platform xhs --lt cookie --type search --save_data_option sqlite

echo ""
echo "=== 爬取完成 ==="

# 输出统计
PYTHONIOENCODING=utf-8 uv run python -c "
import sqlite3, os, sys
db_path = 'database/sqlite_tables.db'
if not os.path.exists(db_path):
    print('数据库文件不存在')
    sys.exit(0)
conn = sqlite3.connect(db_path)
cur = conn.cursor()
cur.execute('SELECT COUNT(*) FROM xhs_note')
notes = cur.fetchone()[0]
cur.execute('SELECT COUNT(*) FROM xhs_note_comment')
comments = cur.fetchone()[0]
print(f'  笔记总数: {notes}')
print(f'  评论总数: {comments}')
print(f'  数据库路径: {os.path.abspath(db_path)}')
conn.close()
"
