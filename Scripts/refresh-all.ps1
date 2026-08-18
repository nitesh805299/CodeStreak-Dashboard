$ErrorActionPreference = "Continue"

$root = Split-Path -Parent $PSScriptRoot

$logDir = Join-Path $root "logs"

if (-not (Test-Path $logDir)) {
    New-Item `
        -ItemType Directory `
        -Path $logDir `
        -Force |
        Out-Null
}

$logFile = Join-Path `
    $logDir `
    ("refresh-" + (Get-Date -Format "yyyy-MM-dd") + ".log")


function Log {

    param(
        [string]$Message
    )

    $line =
        "$(Get-Date -Format 'HH:mm:ss') | $Message"

    Write-Host $line

    Add-Content `
        -Path $logFile `
        -Value $line
}


Log "======================================"
Log "Developer Streak Auto Refresh START"
Log "======================================"


# ======================================================
# GITHUB
# ======================================================

Log "Updating GitHub..."

& powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File "$PSScriptRoot\github-streak.ps1"

$githubExit = $LASTEXITCODE

if ($githubExit -eq 0) {
    Log "GitHub update OK"
}
else {
    Log "GitHub update failed - old data preserved"
}


# ======================================================
# LEETCODE
# ======================================================

Log "Updating LeetCode..."

& powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File "$PSScriptRoot\leetcode-streak.ps1"

$leetcodeExit = $LASTEXITCODE

if ($leetcodeExit -eq 0) {
    Log "LeetCode update OK"
}
else {
    Log "LeetCode update failed - old data preserved"
}


# ======================================================
# LINKEDIN
# ======================================================

Log "Updating LinkedIn..."

& python "$PSScriptRoot\linkedin-fetch.py"

$linkedinExit = $LASTEXITCODE

if ($linkedinExit -eq 0) {

    Log "LinkedIn update OK"

}
elseif ($linkedinExit -eq 2) {

    Log "LinkedIn login required"

}
else {

    Log "LinkedIn update failed - old data preserved"
}


# ======================================================
# PROGRESS
# ======================================================

$githubFile =
    Join-Path $root "github-data.txt"

$leetcodeFile =
    Join-Path $root "leetcode-data.txt"

$linkedinFile =
    Join-Path $root "linkedin-data.txt"

$completed = 0


function Test-TaskCompleted {

    param(
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        return $false
    }

    try {

        $content =
            Get-Content `
            -Path $FilePath `
            -Raw

        return (
            $content -match
            '(?m)^TodayStatus=Completed\s*$'
        )

    }
    catch {

        return $false
    }
}


if (Test-TaskCompleted $githubFile) {
    $completed++
}

if (Test-TaskCompleted $leetcodeFile) {
    $completed++
}

if (Test-TaskCompleted $linkedinFile) {
    $completed++
}


$total = 3

$percent =
    [math]::Round(
        ($completed / $total) * 100
    )

$width =
    [math]::Round(
        ($completed / $total) * 300
    )


if ($completed -eq 0) {

    $message =
        "Start strong. Complete your first task."

}
elseif ($completed -eq 1) {

    $message =
        "Good start. Keep building."

}
elseif ($completed -eq 2) {

    $message =
        "Almost there. One task remaining."

}
else {

    $message =
        "All tasks completed. Great work!"
}


$progressFile =
    Join-Path `
    $root `
    "progress-data.txt"


@"
Completed=$completed
Total=$total
Percent=$percent
Width=$width
Message=$message
LastUpdated=$(Get-Date -Format "dd-MM-yyyy HH:mm:ss")
"@ | Set-Content `
    -Path $progressFile `
    -Encoding UTF8


Log "Progress = $completed / 3 ($percent%)"


# ======================================================
# OVERALL HEALTH
# ======================================================

$healthFile =
    Join-Path `
    $root `
    "health-data.txt"


if (
    $githubExit -eq 0 -and
    $leetcodeExit -eq 0 -and
    $linkedinExit -eq 0
) {

    $overallStatus = "OK"

}
elseif ($linkedinExit -eq 2) {

    $overallStatus =
        "LinkedIn Login Required"

}
else {

    $overallStatus =
        "Partial Update"
}


@"
Status=$overallStatus
GitHubExit=$githubExit
LeetCodeExit=$leetcodeExit
LinkedInExit=$linkedinExit
LastUpdated=$(Get-Date -Format "dd-MM-yyyy HH:mm:ss")
"@ | Set-Content `
    -Path $healthFile `
    -Encoding UTF8


Log "Overall status = $overallStatus"


# ======================================================
# RAINMETER REFRESH
# ======================================================

$rainmeterPaths = @(

    "C:\Program Files\Rainmeter\Rainmeter.exe",

    "C:\Program Files (x86)\Rainmeter\Rainmeter.exe"

)

$rainmeter = $null

foreach ($path in $rainmeterPaths) {

    if (Test-Path $path) {

        $rainmeter = $path
        break
    }
}


if ($rainmeter) {

    try {

        Start-Process `
            -FilePath $rainmeter `
            -ArgumentList '!RefreshApp'

        Log "Rainmeter refreshed"

    }
    catch {

        Log "Rainmeter refresh failed"
    }

}
else {

    Log "Rainmeter.exe not found"
}


Log "======================================"
Log "AUTO REFRESH COMPLETED"
Log "======================================"

exit 0

