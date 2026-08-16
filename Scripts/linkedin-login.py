from playwright.sync_api import sync_playwright
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent

PROFILE_DIR = ROOT_DIR / "linkedin-chrome-profile"

with sync_playwright() as p:

    context = p.chromium.launch_persistent_context(
        user_data_dir=str(PROFILE_DIR),
        channel="chrome",
        headless=False,
        viewport=None,
        args=["--start-maximized"]
    )

    page = context.pages[0]

    print()
    print("======================================")
    print("LINKEDIN LOGIN")
    print("======================================")
    print()

    page.goto(
        "https://www.linkedin.com/login",
        wait_until="domcontentloaded",
        timeout=60000
    )

    print("Browser me LinkedIn login karo.")
    print()
    print("Agar OTP / CAPTCHA / verification aaye")
    print("to browser me manually complete karo.")
    print()
    print("Browser close mat karna.")
    print()

    input("Login complete hone ke baad ENTER press karo...")

    current_url = page.url

    print()
    print("Current URL:")
    print(current_url)

    if "checkpoint" in current_url.lower():

        print()
        print("LinkedIn security verification detected.")
        print("Browser me verification complete karo.")
        print()

        input("Verification complete hone ke baad ENTER press karo...")

    try:
        page.goto(
            "https://www.linkedin.com/feed/",
            wait_until="domcontentloaded",
            timeout=60000
        )
    except Exception:
        pass

    page.wait_for_timeout(5000)

    print()
    print("Final login URL:")
    print(page.url)

    if "/feed" in page.url:
        print("SUCCESS: LinkedIn login detected.")
    else:
        print("Login verify nahi hua.")

    print()
    print("Opening LinkedIn Zip...")
    print()

    try:
        page.goto(
            "https://www.linkedin.com/games/zip/",
            wait_until="domcontentloaded",
            timeout=60000
        )
    except Exception:
        pass

    page.wait_for_timeout(7000)

    print("Zip URL:")
    print(page.url)

    input("\nCheck karne ke baad ENTER press karo...")

    try:
        context.close()
    except Exception:
        pass

    print()
    print("LinkedIn session saved.")