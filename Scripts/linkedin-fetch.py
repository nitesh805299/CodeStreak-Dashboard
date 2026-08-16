from playwright.sync_api import sync_playwright
from pathlib import Path
from datetime import datetime
import json
import re
import sys


# =========================================================
# PATHS
# =========================================================

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent

PROFILE_DIR = ROOT_DIR / "linkedin-chrome-profile"
DEBUG_DIR = ROOT_DIR / "linkedin-debug"
DATA_FILE = ROOT_DIR / "linkedin-data.txt"

DEBUG_DIR.mkdir(exist_ok=True)

URL = "https://www.linkedin.com/games/zip/results/"

captured_responses = []


# =========================================================
# READ OLD DATA
# =========================================================

def read_old_data():

    data = {
        "CurrentStreak": 0,
        "LongestStreak": 0,
        "TodayStatus": "Remaining",
        "LastCompletedDate": "",
        "DataDate": ""
    }

    if not DATA_FILE.exists():
        return data

    try:

        for line in DATA_FILE.read_text(
            encoding="utf-8-sig"
        ).splitlines():

            if "=" not in line:
                continue

            key, value = line.split("=", 1)

            key = key.strip()
            value = value.strip()

            if key in data:
                data[key] = value

        try:
            data["CurrentStreak"] = int(
                data["CurrentStreak"]
            )
        except Exception:
            data["CurrentStreak"] = 0

        try:
            data["LongestStreak"] = int(
                data["LongestStreak"]
            )
        except Exception:
            data["LongestStreak"] = 0

    except Exception as e:
        print("Could not read old LinkedIn data:", e)

    return data


# =========================================================
# JSON HELPERS
# =========================================================

def find_values(obj, wanted_keys, results=None):

    if results is None:
        results = []

    wanted = {
        key.lower()
        for key in wanted_keys
    }

    if isinstance(obj, dict):

        for key, value in obj.items():

            if (
                key.lower() in wanted
                and value is not None
            ):
                results.append(value)

            find_values(
                value,
                wanted_keys,
                results
            )

    elif isinstance(obj, list):

        for value in obj:

            find_values(
                value,
                wanted_keys,
                results
            )

    return results


def has_solved_state(obj):

    if isinstance(obj, dict):

        for key, value in obj.items():

            if (
                key.lower() == "gameplaystate"
                and str(value).upper()
                in {
                    "END_SOLVED",
                    "SOLVED",
                    "COMPLETED"
                }
            ):
                return True

            if has_solved_state(value):
                return True

    elif isinstance(obj, list):

        for value in obj:

            if has_solved_state(value):
                return True

    return False


# =========================================================
# RESPONSE HANDLER
# =========================================================

def handle_response(response):

    url = response.url

    if (
        "linkedin.com/voyager/api/graphql" in url
        and "voyagerIdentityDashGames" in url
    ):

        captured_responses.append(response)


# =========================================================
# OLD DATA
# =========================================================

old_data = read_old_data()

current_streak = old_data["CurrentStreak"]
longest_streak = old_data["LongestStreak"]

today = datetime.now().strftime("%Y-%m-%d")

if old_data["LastCompletedDate"] == today:
    today_status = old_data["TodayStatus"]
else:
    today_status = "Remaining"

solved_detected = False
login_required = False
fetch_success = False


# =========================================================
# PLAYWRIGHT
# =========================================================

with sync_playwright() as p:

    context = None

    try:

        context = p.chromium.launch_persistent_context(
            user_data_dir=str(PROFILE_DIR),
            channel="chrome",
            headless=False,
            viewport=None,
            args=["--start-maximized"]
        )

        page = context.pages[0]

        page.on(
            "response",
            handle_response
        )

        print()
        print("======================================")
        print("LINKEDIN STREAK FETCHER")
        print("======================================")
        print()

        try:

            page.goto(
                URL,
                wait_until="domcontentloaded",
                timeout=60000
            )

        except Exception as e:
            print("Navigation warning:", e)

        page.wait_for_timeout(10000)

        current_url = page.url

        print("Current URL:")
        print(current_url)

        # =================================================
        # LOGIN / CHECKPOINT DETECTION
        # =================================================

        lower_url = current_url.lower()

        if (
            "/login" in lower_url
            or "/checkpoint" in lower_url
            or "/uas/login" in lower_url
        ):

            login_required = True
            raise RuntimeError(
                "LinkedIn login/session verification required."
            )


        # =================================================
        # RESULTS URL = STRONG COMPLETION EVIDENCE
        # =================================================

        if "/results" in lower_url:
            solved_detected = True


        # =================================================
        # TRY PAGE TEXT FOR REAL STREAK NUMBERS
        # =================================================

        page_text = ""

        try:
            page_text = page.locator("body").inner_text(
                timeout=10000
            )
        except Exception:
            pass


        if page_text:

            # Examples supported:
            # 27-day win streak
            # 27 day win streak

            streak_match = re.search(
                r"\b(\d+)[-\s]?day\s+win\s+streak\b",
                page_text,
                re.IGNORECASE
            )

            if streak_match:
                current_streak = int(
                    streak_match.group(1)
                )


            # Examples:
            # Max streak 58
            # Max streak: 58

            max_match = re.search(
                r"\bmax\s+streak\s*:?\s*(\d+)\b",
                page_text,
                re.IGNORECASE
            )

            if max_match:

                parsed_max = int(
                    max_match.group(1)
                )

                if parsed_max > longest_streak:
                    longest_streak = parsed_max


        # =================================================
        # PROCESS GRAPHQL RESPONSES
        # =================================================

        json_objects = []

        print(
            "Captured responses:",
            len(captured_responses)
        )

        for index, response in enumerate(
            captured_responses,
            start=1
        ):

            try:

                text = response.text()

                debug_file = (
                    DEBUG_DIR /
                    f"linkedin-auth-response-{index}.json"
                )

                debug_file.write_text(
                    text,
                    encoding="utf-8"
                )

                data = json.loads(text)
                json_objects.append(data)

            except Exception as e:
                print(
                    f"Response {index} parse error:",
                    e
                )


        # =================================================
        # SOLVED STATE FROM JSON
        # =================================================

        for data in json_objects:

            if has_solved_state(data):

                solved_detected = True
                break


        # =================================================
        # CURRENT STREAK FROM JSON
        # =================================================

        possible_current_keys = [
            "streakLength",
            "currentStreak",
            "winStreak",
            "currentWinStreak"
        ]

        for data in json_objects:

            values = find_values(
                data,
                possible_current_keys
            )

            numeric = [
                int(x)
                for x in values
                if isinstance(x, (int, float))
                and x >= 0
            ]

            if numeric:

                candidate = max(numeric)

                if candidate > 0:
                    current_streak = candidate
                    break


        # =================================================
        # LONGEST STREAK FROM JSON
        # =================================================

        possible_longest_keys = [
            "maxStreak",
            "longestStreak",
            "maxWinStreak",
            "maximumStreak",
            "bestStreak"
        ]

        for data in json_objects:

            values = find_values(
                data,
                possible_longest_keys
            )

            numeric = [
                int(x)
                for x in values
                if isinstance(x, (int, float))
                and x >= 0
            ]

            if numeric:

                candidate = max(numeric)

                if candidate > longest_streak:
                    longest_streak = candidate


        # =================================================
        # STATUS
        # =================================================

        if solved_detected:
            today_status = "Completed"

        fetch_success = True


    except Exception as e:

        print()
        print("======================================")
        print("LINKEDIN FETCH ERROR")
        print("======================================")
        print(e)

        current_streak = old_data["CurrentStreak"]
        longest_streak = old_data["LongestStreak"]

        if old_data["LastCompletedDate"] == today:
            today_status = old_data["TodayStatus"]
        else:
            today_status = "Remaining"


    finally:

        if context is not None:

            try:
                context.close()
            except Exception:
                pass


# =========================================================
# LONGEST STREAK SAFETY
# =========================================================

if old_data["LongestStreak"] > longest_streak:
    longest_streak = old_data["LongestStreak"]


# =========================================================
# LAST COMPLETED DATE
# =========================================================

if today_status == "Completed":
    last_completed_date = today
else:
    last_completed_date = old_data["LastCompletedDate"]


# =========================================================
# FETCH STATUS
# =========================================================

if login_required:
    fetch_status = "LOGIN_REQUIRED"
elif fetch_success:
    fetch_status = "OK"
else:
    fetch_status = "ERROR"


# =========================================================
# SAVE
# =========================================================

now = datetime.now()

output = (
    f"CurrentStreak={current_streak}\n"
    f"LongestStreak={longest_streak}\n"
    f"TodayStatus={today_status}\n"
    f"LastCompletedDate={last_completed_date}\n"
    f"DataDate={today}\n"
    f"LastUpdated={now.strftime('%d-%m-%Y %H:%M:%S')}\n"
    f"FetchStatus={fetch_status}\n"
)

DATA_FILE.write_text(
    output,
    encoding="utf-8"
)


print()
print("======================================")
print("LINKEDIN DATA UPDATED")
print("======================================")
print()

print(
    "Current Streak :",
    current_streak,
    "days"
)

print(
    "Longest Streak :",
    longest_streak,
    "days"
)

print(
    "Today Status   :",
    today_status
)

print(
    "Solved Detected:",
    solved_detected
)

print(
    "Fetch Status   :",
    fetch_status
)

print()


if login_required:
    sys.exit(2)

if not fetch_success:
    sys.exit(1)

sys.exit(0)