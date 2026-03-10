# MediaCrawler 小红书爬虫 - 一键部署

基于 [NanmiCoder/MediaCrawler](https://github.com/NanmiCoder/MediaCrawler) 的自动化部署脚本，适用于 Linux 环境。

## 快速开始

```bash
git clone https://github.com/agentdannis/mediacrawler-setup.git
cd mediacrawler-setup

# 1. 一键部署（安装 uv、克隆项目、安装依赖、初始化数据库）
bash setup.sh

# 2. 配置 cookie
#    Chrome 登录 xiaohongshu.com -> F12 -> Application -> Cookies -> 复制 web_session
nano .env

# 3. 运行爬虫
bash run.sh                        # 使用 .env 配置
bash run.sh "美食,旅行"             # 指定关键词
XHS_WEB_SESSION=xxx bash run.sh    # 临时 cookie
```

## 文件说明

```
.
├── setup.sh     # 一键部署脚本
├── run.sh       # 运行脚本（读取 .env 配置，修改配置文件，执行爬虫）
├── .env         # 配置文件（setup.sh 自动生成模板）
└── MediaCrawler/ # 克隆的项目（setup.sh 自动生成）
```

## 配置项（.env）

| 变量 | 说明 | 示例 |
|------|------|------|
| `XHS_WEB_SESSION` | 小红书登录 cookie | `040069b...` |
| `XHS_KEYWORDS` | 搜索关键词，逗号分隔 | `Python学习,数据分析` |
| `XHS_MAX_NOTES` | 最大爬取笔记数 | `15` |

## 关于 web_session

- 通过 Chrome 开发者工具获取（F12 -> Application -> Cookies）
- **会过期**，有效期通常几天到两周
- 过期后重新登录提取，更新 `.env` 即可
- 不建议使用 QR 码登录方式（选择器已过期）

## 数据存储

数据保存在 SQLite：`MediaCrawler/database/sqlite_tables.db`

主要表：
- `xhs_note` - 笔记（标题、点赞数、收藏数、内容等）
- `xhs_note_comment` - 评论（评论内容、用户、点赞数等）

## Linux 注意事项

- Playwright 需要系统依赖，`setup.sh` 会自动安装（可能需要 sudo）
- Linux 下默认使用 headless 模式（无头浏览器），不需要桌面环境
- 不使用 CDP 模式（Linux 服务器通常没有桌面 Chrome）

## 部署验证记录

以下为 Windows 环境首次部署测试结果（2026-03-10）：

| 方式 | 结果 |
|------|------|
| Playwright + QR码 | 失败（选择器过期） |
| CDP + QR码 | 失败（同上） |
| CDP + Cookie | 成功 |

最终方案：**Cookie 登录 + SQLite 存储**，爬取 20 篇笔记 + 166 条评论，耗时约 2.5 分钟。
