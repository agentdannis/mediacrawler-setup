"""MediaCrawler 小红书 session 保活脚本

原理：
- 通过 Playwright 持久化上下文（browser_data/）复用登录状态
- 每次运行时访问小红书并调用 API，触发 cookie 续期
- Playwright 自动将续期后的 cookie 写回磁盘
- 只要运行间隔不超过 cookie 有效期（通常 1-2 周），session 永远不会过期

用法：
    uv run python keep_alive.py              # 检查 session 状态
    uv run python keep_alive.py --refresh    # 检查并做一次轻量爬取来刷新
    配合 cron 每 12 小时运行一次即可
"""

import asyncio
import os
import sys

# 切到 MediaCrawler 目录，让 import 正常工作
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CRAWLER_DIR = os.path.join(SCRIPT_DIR, "MediaCrawler")
os.chdir(CRAWLER_DIR)
sys.path.insert(0, CRAWLER_DIR)

import config
# 强制 headless + cookie 模式 + 保存登录状态
config.HEADLESS = True
config.ENABLE_CDP_MODE = False
config.SAVE_LOGIN_STATE = True
config.LOGIN_TYPE = "cookie"
config.CRAWLER_MAX_NOTES_COUNT = 1
config.ENABLE_GET_COMMENTS = False
config.KEYWORDS = "Python"

from playwright.async_api import async_playwright
from media_platform.xhs.client import XiaoHongShuClient
from media_platform.xhs.core import XiaoHongShuCrawler
from tools import utils


async def check_session() -> bool:
    """检查当前 session 是否有效"""
    user_data_dir = os.path.join(CRAWLER_DIR, "browser_data", config.USER_DATA_DIR % config.PLATFORM)
    if not os.path.exists(user_data_dir):
        print(f"[FAIL] browser_data 目录不存在: {user_data_dir}")
        print("       需要先运行一次爬虫建立登录状态")
        return False

    async with async_playwright() as playwright:
        chromium = playwright.chromium
        browser_context = await chromium.launch_persistent_context(
            user_data_dir=user_data_dir,
            accept_downloads=True,
            headless=True,
            viewport={"width": 1920, "height": 1080},
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
        )
        await browser_context.add_init_script(path=os.path.join(CRAWLER_DIR, "libs", "stealth.min.js"))

        context_page = await browser_context.new_page()
        await context_page.goto("https://www.xiaohongshu.com")

        # 用 XiaoHongShuClient 检查登录状态
        cookie_list, cookie_dict = utils.convert_cookies(await browser_context.cookies())
        xhs_client = XiaoHongShuClient(
            headers={
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
                "Cookie": cookie_list,
                "Origin": "https://www.xiaohongshu.com",
                "Referer": "https://www.xiaohongshu.com",
                "Content-Type": "application/json;charset=UTF-8",
            },
            playwright_page=context_page,
            cookie_dict=cookie_dict,
        )

        is_valid = await xhs_client.pong()
        await browser_context.close()

    return is_valid


async def refresh_session():
    """通过执行一次轻量爬取来刷新 session"""
    print("[INFO] 执行轻量爬取以刷新 session...")
    crawler = XiaoHongShuCrawler()
    await crawler.start()
    print("[OK] 爬取完成，session 已刷新")


async def main():
    do_refresh = "--refresh" in sys.argv

    print("=== MediaCrawler Session 保活 ===")
    is_valid = await check_session()

    if is_valid:
        print("[OK] Session 有效")
        if do_refresh:
            await refresh_session()
    else:
        print("[WARN] Session 已过期")
        print("       需要重新设置 cookie:")
        print("       1. 在有浏览器的机器上登录 xiaohongshu.com")
        print("       2. F12 -> Application -> Cookies -> 复制 web_session")
        print("       3. 更新 .env 中的 XHS_WEB_SESSION")
        print("       4. 运行 bash run.sh 重新初始化")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
