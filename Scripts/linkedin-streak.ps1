# ============================================================
# LinkedIn Streak Tracker
# ============================================================

$rootPath = Split-Path -Parent $PSScriptRoot
$dataFile = Join-Path $rootPath "linkedin-data.txt"

$today = Get-Date -Format "yyyy-MM-dd"
$currentTime = Get-Date -Format "dd-MM-yyyy HH:mm:ss"

$currentStreak = 0
$longestStreak = 0
$todayStatus = "Remaining"
$lastCompletedDate = ""

# ============================================================
# READ EXISTING DATA
# ============================================================

if (Test-Path $dataFile) {

    $content = Get-Content $dataFile

    foreach ($line in $content) {

        if ($line -match "^CurrentStreak=(\d+)") {
            $currentStreak = [int]$matches[1]
        }

        if ($line -match "^LongestStreak=(\d+)") {
            $longestStreak = [int]$matches[1]
        }

        if ($line -match "^TodayStatus=(.*)") {
            $todayStatus = $matches[1].Trim()
        }

        if ($line -match "^LastCompletedDate=(.*)") {
            $lastCompletedDate = $matches[1].Trim()
        }
    }
}

# ============================================================
# RESET TODAY STATUS ON NEW DAY
# ============================================================

if ($lastCompletedDate -ne $today) {
    $todayStatus = "Remaining"
}

# ============================================================
# WRITE DATA
# ============================================================

@"
CurrentStreak=$currentStreak
LongestStreak=$longestStreak
TodayStatus=$todayStatus
LastCompletedDate=$lastCompletedDate
LastUpdated=$currentTime
"@ | Set-Content -Path $dataFile -Encoding UTF8


# ============================================================
# OUTPUT
# ============================================================

Write-Host ""
Write-Host "LinkedIn Tracker"
Write-Host "----------------------------"
Write-Host "Current Streak : $currentStreak days"
Write-Host "Longest Streak : $longestStreak days"
Write-Host "Today Status   : $todayStatus"
Write-Host "Last Completed : $lastCompletedDate"
Write-Host ""