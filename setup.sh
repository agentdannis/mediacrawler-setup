#!/usr/bin/env bash
# MediaCrawler 小红书爬虫 - Linux 一键部署脚本
# 用法: bash setup.sh
#
# 前置要求:
#   - Linux (Ubuntu/Debian/CentOS 等)
#   - git, curl 已安装
#   - Node.js >= 16 已安装（用于抖音/知乎平台，小红书可选）
#
# 本脚本完成:
#   1. 安装 uv（Python 包管理器）
#   2. 克隆 MediaCrawler 项目
#   3. 安装 Python 依赖
#   4. 安装 Playwright 浏览器驱动及系统依赖
#   5. 初始化 SQLite 数据库
#   6. 生成配置文件

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/MediaCrawler"

echo "=== [1/5] 安装 uv ==="
if command -v uv &>/dev/null; then
    echo "uv 已安装: $(uv --version)"
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    echo "uv 安装完成: $(uv --version)"
fi

echo ""
echo "=== [2/5] 克隆 MediaCrawler ==="
if [ -d "$PROJECT_DIR" ]; then
    echo "项目目录已存在，跳过克隆，拉取最新代码..."
    cd "$PROJECT_DIR" && git pull --ff-only || true
else
    git clone https://github.com/NanmiCoder/MediaCrawler.git "$PROJECT_DIR"
fi

echo ""
echo "=== [3/5] 安装 Python 依赖 ==="
cd "$PROJECT_DIR"
uv sync

echo ""
echo "=== [4/5] 安装 Playwright 浏览器驱动 ==="
# 先安装系统依赖（Playwright 在 Linux 上需要）
uv run playwright install-deps chromium 2>/dev/null || {
    echo "警告: install-deps 需要 root 权限，尝试 sudo..."
    sudo uv run playwright install-deps chromium
}
uv run playwright install chromium

echo ""
echo "=== [5/5] 初始化 SQLite 数据库 ==="
uv run main.py --platform xhs --lt cookie --type search --save_data_option sqlite --init_db sqlite

# 生成 .env 文件模板（如果不存在）
ENV_FILE="$SCRIPT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" <<'ENVEOF'
# 小红书 web_session cookie
# 获取方式: Chrome 登录 xiaohongshu.com -> F12 -> Application -> Cookies -> web_session
# 注意: 此 cookie 会过期（通常几天到两周），过期后需重新获取
XHS_WEB_SESSION=your_web_session_here

# 搜索关键词（英文逗号分隔）
XHS_KEYWORDS=Python学习

# 最大爬取笔记数
XHS_MAX_NOTES=15
ENVEOF
    echo ""
    echo "已生成 .env 文件，请编辑填入你的 web_session:"
    echo "  $ENV_FILE"
fi

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo ""
echo "下一步:"
echo "  1. 编辑 .env 文件，填入 XHS_WEB_SESSION"
echo "  2. 运行: bash run.sh"
echo ""
