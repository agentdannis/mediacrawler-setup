# MediaCrawler 小红书爬虫 - 一键部署

基于 [NanmiCoder/MediaCrawler](https://github.com/NanmiCoder/MediaCrawler) 的自动化部署脚本，适用于 Linux 无头服务器。

## 核心特性

- 只需设置一次 cookie，之后自动保活，永不过期
- 适配无头 Linux 服务器（headless 模式）
- 一键部署，一键运行

## 快速开始

```bash
git clone https://github.com/agentdannis/mediacrawler-setup.git
cd mediacrawler-setup

# 1. 一键部署
bash setup.sh

# 2. 设置 cookie（只需一次）
#    在有浏览器的机器上登录 xiaohongshu.com
#    F12 -> Application -> Cookies -> 复制 web_session
nano .env    # 填入 XHS_WEB_SESSION=xxx

# 3. 运行爬虫
bash run.sh                        # 使用 .env 配置
bash run.sh "美食,旅行"             # 指定关键词

# 4. 安装自动保活（可选但推荐）
bash install_cron.sh               # 每 12 小时自动保活
```

## 文件说明

```
.
├── setup.sh          # 一键部署（安装 uv、克隆项目、装依赖、初始化 DB）
├── run.sh            # 运行爬虫（自动检测登录状态，首次需 cookie）
├── keep_alive.py     # Session 保活脚本（检查 + 刷新 session）
├── install_cron.sh   # 安装 cron 定时保活任务
├── .env              # 配置文件（setup.sh 自动生成模板）
└── MediaCrawler/     # 克隆的项目（setup.sh 自动生成）
```

## Session 保活机制

**问题**: web_session cookie 会过期（通常 1-2 周）

**方案**: Playwright 持久化上下文 + 定时保活

```
首次运行                     后续运行
   │                           │
   ▼                           ▼
cookie 注入 ──► 访问 XHS ──► Playwright 保存完整浏览器状态到 browser_data/
                                │
                                ▼
                  下次运行自动加载 ──► pong() 检测已登录 ──► 跳过登录
                                │
                                ▼
                     XHS 服务端续期 cookie ──► Playwright 自动保存新 cookie
```

**关键**: 每次爬取都会触发 cookie 续期。配合 cron 每 12 小时保活一次，session 永远不会过期。

```bash
# 手动检查 session 状态
cd MediaCrawler && uv run python ../keep_alive.py

# 检查并刷新
cd MediaCrawler && uv run python ../keep_alive.py --refresh

# 安装 cron 自动保活
bash install_cron.sh
```

## 配置项（.env）

| 变量 | 说明 | 示例 |
|------|------|------|
| `XHS_WEB_SESSION` | 小红书登录 cookie（只需设置一次） | `040069b...` |
| `XHS_KEYWORDS` | 搜索关键词，逗号分隔 | `Python学习,数据分析` |
| `XHS_MAX_NOTES` | 最大爬取笔记数 | `15` |

## 数据存储

SQLite: `MediaCrawler/database/sqlite_tables.db`

- `xhs_note` - 笔记（标题、点赞、收藏、内容）
- `xhs_note_comment` - 评论（内容、用户、点赞）

## FAQ

**Q: cookie 过期了怎么办？**
A: 如果安装了 cron 保活，正常情况下不会过期。万一过期，重新在浏览器获取 web_session，更新 .env，运行一次 `bash run.sh` 即可。

**Q: 为什么不用 QR 码登录？**
A: 小红书更新了前端页面，QR 码登录的 CSS 选择器已失效。Cookie + 自动保活是目前最稳定的方案。

**Q: 服务器没有图形界面怎么办？**
A: 脚本默认使用 headless 模式，不需要 GUI。初始 cookie 在有浏览器的机器上获取一次即可。
