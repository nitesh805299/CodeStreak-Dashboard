# 🔥 DevStreak Tracker

A Windows desktop productivity widget that automatically tracks my daily developer activity across **GitHub, LeetCode, and LinkedIn Games**.

Built using **Rainmeter, PowerShell, Python, and Playwright**.

The goal of this project is simple:  
**Stay consistent. Code every day. Build the streak. 🚀**

---

## ✨ Features

- 🟢 GitHub contribution streak tracking
- 🟠 LeetCode coding streak tracking
- 🔵 LinkedIn Games completion tracking
- 🔥 Current streak display
- 🏆 Longest streak display
- ✅ Automatic daily task status
- 📊 Daily progress calculation (`0/3` → `3/3`)
- 🔄 Automatic data refresh
- 🖥️ Windows desktop Rainmeter widget
- ⏰ Windows Task Scheduler automation
- 🌐 Network failure fallback
- 💾 Previous valid data preservation
- 🔐 Persistent LinkedIn login session

---

## 🖥️ Dashboard

The desktop widget tracks three daily activities:

| Platform | Tracking |
|---|---|
| GitHub | Contributions & streak |
| LeetCode | Submissions & streak |
| LinkedIn | Games completion & streak |
| Daily Progress | Overall completion percentage |

Example:

```text
GitHub
Current Streak: 2 days
Longest Streak: 3 days
Status: Remaining

LeetCode
Current Streak: 0 days
Longest Streak: 5 days
Status: Remaining

LinkedIn
Current Streak: 27 days
Longest Streak: 58 days
Status: Completed

Today's Progress
1 / 3 Tasks Completed
33%
```

---

## 🛠️ Tech Stack

- **Rainmeter** — Desktop widget/UI
- **PowerShell** — GitHub and LeetCode data fetching
- **Python** — LinkedIn automation
- **Playwright** — LinkedIn browser automation
- **Windows Task Scheduler** — Automatic background refresh

---

## 📁 Project Structure

```text
DevStreak-Tracker/
│
├── Assets/
│   ├── github.png
│   ├── leetcode.png
│   └── linkedin.png
│
├── Scripts/
│   ├── github-streak.ps1
│   ├── leetcode-streak.ps1
│   ├── linkedin-login.py
│   ├── linkedin-fetch.py
│   └── refresh-all.ps1
│
├── developerStreakTracker.ini
├── github-data.txt
├── leetcode-data.txt
├── linkedin-data.txt
├── progress-data.txt
└── README.md
```

---

## ⚙️ How It Works

### GitHub

PowerShell reads GitHub contribution activity and calculates:

- Current streak
- Longest streak
- Today's contribution status

### LeetCode

The tracker uses LeetCode's GraphQL endpoint to read the submission calendar and calculate coding streaks.

### LinkedIn Games

Python + Playwright opens the LinkedIn Games page using a persistent browser session.

The tracker detects whether today's game has been completed and updates the dashboard automatically.

### Daily Progress

Each platform counts as one daily task.

```text
0 completed = 0%
1 completed = 33%
2 completed = 67%
3 completed = 100%
```

---

## 🔄 Automatic Refresh

`refresh-all.ps1` runs all trackers:

```text
GitHub
   ↓
LeetCode
   ↓
LinkedIn
   ↓
Calculate Progress
   ↓
Update Data Files
   ↓
Refresh Rainmeter
```

Windows Task Scheduler can run this script automatically at a configured interval.

---

## 🚀 Installation

### 1. Install Rainmeter

Install Rainmeter on Windows.

### 2. Install Python

Python 3 is required.

Check:

```powershell
python --version
```

### 3. Install Playwright

```powershell
python -m pip install playwright
python -m playwright install chromium
```

### 4. Configure LinkedIn Session

Run:

```powershell
python ".\Scripts\linkedin-login.py"
```

Login manually when the browser opens.

### 5. Test the Tracker

```powershell
powershell -ExecutionPolicy Bypass -File ".\Scripts\refresh-all.ps1"
```

The script should update all platform data and refresh Rainmeter.

---

## 🔒 Security

This project does **not** require storing a LinkedIn password in the source code.

Login is completed manually and Playwright uses a persistent browser session.

Sensitive browser/session data should never be committed to GitHub.

---

## ⚠️ Important `.gitignore`

Browser profiles and login/session data should remain private.

Add these directories/files to `.gitignore`:

```gitignore
linkedin-browser-data/
linkedin-chrome-profile/
linkedin-debug/

__pycache__/
*.pyc

*.log
logs/
```

---

## 🎯 Future Improvements

- GitHub contribution heatmap
- LeetCode activity heatmap
- Better LinkedIn statistics extraction
- Weekly/monthly analytics
- Streak notifications
- Configurable usernames
- Settings panel
- Improved glassmorphism UI

---

## 👨‍💻 Author

**Nitesh Kumar Chaurasia**

Built as a personal developer productivity and consistency tracking project.

---

## ⭐ Support

If you like this project, consider giving the repository a ⭐.

**Stay consistent. Keep building. 🔥**
