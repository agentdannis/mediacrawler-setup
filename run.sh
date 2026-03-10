#!/usr/bin/env bash
# MediaCrawler 小红书爬虫 - 运行脚本
# 用法:
#   bash run.sh                          # 使用 .env 中的配置
#   bash run.sh "关键词1,关键词2"         # 指定关键词
#   XHS_WEB_SESSION=xxx bash run.sh      # 临时指定 cookie

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/MediaCrawler"
CONFIG_FILE="$PROJECT_DIR/config/base_config.py"
ENV_FILE="$SCRIPT_DIR/.env"

export PATH="$HOME/.local/bin:$PATH"

# 加载 .env
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# 参数校验
WEB_SESSION="${XHS_WEB_SESSION:-}"
KEYWORDS="${1:-${XHS_KEYWORDS:-Python学习}}"
MAX_NOTES="${XHS_MAX_NOTES:-15}"

if [ -z "$WEB_SESSION" ] || [ "$WEB_SESSION" = "your_web_session_here" ]; then
    echo "错误: 未设置 XHS_WEB_SESSION"
    echo ""
    echo "获取方式:"
    echo "  1. Chrome 打开 www.xiaohongshu.com 并登录"
    echo "  2. F12 -> Application -> Cookies -> 复制 web_session 的值"
    echo "  3. 填入 .env 文件或通过环境变量传入"
    exit 1
fi

echo "=== 配置 ==="
echo "  关键词: $KEYWORDS"
echo "  最大笔记数: $MAX_NOTES"
echo "  Cookie: ${WEB_SESSION:0:10}..."
echo ""

# 写入配置
cd "$PROJECT_DIR"

# 用 Python 修改配置，避免 sed 处理中文的问题
uv run python -c "
import re

config_path = 'config/base_config.py'
with open(config_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = {
    r'KEYWORDS\s*=\s*\"[^\"]*\"': 'KEYWORDS = \"$KEYWORDS\"',
    r'LOGIN_TYPE\s*=\s*\"[^\"]*\"': 'LOGIN_TYPE = \"cookie\"',
    r'COOKIES\s*=\s*\"[^\"]*\"': 'COOKIES = \"web_session=$WEB_SESSION\"',
    r'SAVE_DATA_OPTION\s*=\s*\"[^\"]*\"': 'SAVE_DATA_OPTION = \"sqlite\"',
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
uv run python -c "
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
