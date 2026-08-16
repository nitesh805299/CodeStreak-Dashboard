$username = "nitesh805299"

$basePath = Split-Path -Parent $PSScriptRoot
$outputFile = Join-Path $basePath "github-data.txt"

$today = (Get-Date).Date
$todayString = $today.ToString("yyyy-MM-dd")

# ============================================================
# READ OLD DATA
# ============================================================

$oldCurrent = 0
$oldLongest = 0
$oldStatus = "Remaining"
$oldDate = ""

if (Test-Path $outputFile) {

    $oldContent = Get-Content $outputFile

    foreach ($line in $oldContent) {

        if ($line -match "^CurrentStreak=(\d+)") {
            $oldCurrent = [int]$matches[1]
        }

        if ($line -match "^LongestStreak=(\d+)") {
            $oldLongest = [int]$matches[1]
        }

        if ($line -match "^TodayStatus=(.*)") {
            $oldStatus = $matches[1].Trim()
        }

        if ($line -match "^DataDate=(.*)") {
            $oldDate = $matches[1].Trim()
        }
    }
}


# ============================================================
# FETCH WITH RETRIES
# ============================================================

$maxRetries = 3
$success = $false
$lastError = ""

for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {

    try {

        Write-Host "GitHub attempt $attempt of $maxRetries..."

        $url = "https://github.com/users/$username/contributions"

        $response = Invoke-WebRequest `
            -Uri $url `
            -UseBasicParsing `
            -TimeoutSec 30 `
            -Headers @{
                "User-Agent" = "Mozilla/5.0"
            }

        $html = $response.Content

        $pattern = 'data-date="(?<date>\d{4}-\d{2}-\d{2})"[^>]*data-level="(?<level>\d+)"'

        $matches = [regex]::Matches(
            $html,
            $pattern
        )

        $contributions = @()

        foreach ($match in $matches) {

            $date = [datetime]::ParseExact(
                $match.Groups["date"].Value,
                "yyyy-MM-dd",
                $null
            )

            $level = [int]$match.Groups["level"].Value

            $contributions += [PSCustomObject]@{
                Date  = $date
                Level = $level
            }
        }

        if ($contributions.Count -eq 0) {
            throw "GitHub contribution data nahi mila."
        }

        $contributions =
            $contributions |
            Sort-Object Date -Unique


        # ====================================================
        # TODAY STATUS
        # ====================================================

        $todayContribution =
            $contributions |
            Where-Object {
                $_.Date.Date -eq $today
            }

        if (
            $todayContribution -and
            $todayContribution.Level -gt 0
        ) {
            $todayStatus = "Completed"
        }
        else {
            $todayStatus = "Remaining"
        }


        # ====================================================
        # CURRENT STREAK
        # ====================================================

        $currentStreak = 0

        if ($todayStatus -eq "Completed") {
            $checkDate = $today
        }
        else {
            $checkDate = $today.AddDays(-1)
        }

        while ($true) {

            $day =
                $contributions |
                Where-Object {
                    $_.Date.Date -eq $checkDate.Date
                }

            if (
                $day -and
                $day.Level -gt 0
            ) {

                $currentStreak++
                $checkDate = $checkDate.AddDays(-1)

            }
            else {
                break
            }
        }


        # ====================================================
        # LONGEST STREAK
        # ====================================================

        $longestStreak = 0
        $tempStreak = 0
        $previousDate = $null

        $activeDays =
            $contributions |
            Where-Object {
                $_.Level -gt 0
            } |
            Sort-Object Date

        foreach ($day in $activeDays) {

            if (
                $previousDate -ne $null -and
                $day.Date.Date -eq $previousDate.AddDays(1).Date
            ) {
                $tempStreak++
            }
            else {
                $tempStreak = 1
            }

            if ($tempStreak -gt $longestStreak) {
                $longestStreak = $tempStreak
            }

            $previousDate = $day.Date.Date
        }


        # Do not accidentally reduce known longest streak
        if ($oldLongest -gt $longestStreak) {
            $longestStreak = $oldLongest
        }


        # ====================================================
        # SAVE ONLY AFTER SUCCESS
        # ====================================================

@"
CurrentStreak=$currentStreak
LongestStreak=$longestStreak
TodayStatus=$todayStatus
DataDate=$todayString
LastUpdated=$(Get-Date -Format "dd-MM-yyyy HH:mm:ss")
FetchStatus=OK
"@ | Set-Content `
            -Path $outputFile `
            -Encoding UTF8


        Write-Host ""
        Write-Host "GitHub Data Updated"
        Write-Host "-------------------"
        Write-Host "Current Streak : $currentStreak days"
        Write-Host "Longest Streak : $longestStreak days"
        Write-Host "Today Status   : $todayStatus"
        Write-Host ""

        $success = $true
        break
    }
    catch {

        $lastError = $_.Exception.Message

        Write-Host "GitHub attempt failed:"
        Write-Host $lastError

        if ($attempt -lt $maxRetries) {
            Start-Sleep -Seconds 5
        }
    }
}


# ============================================================
# FAILURE FALLBACK
# ============================================================

if (-not $success) {

    if ($oldDate -eq $todayString) {
        $safeStatus = $oldStatus
    }
    else {
        $safeStatus = "Remaining"
    }

@"
CurrentStreak=$oldCurrent
LongestStreak=$oldLongest
TodayStatus=$safeStatus
DataDate=$todayString
LastUpdated=$(Get-Date -Format "dd-MM-yyyy HH:mm:ss")
FetchStatus=ERROR
"@ | Set-Content `
        -Path $outputFile `
        -Encoding UTF8

    Write-Host ""
    Write-Host "GitHub fetch failed."
    Write-Host "Old streak data preserved."
    Write-Host "Today Status: $safeStatus"
    Write-Host "Reason: $lastError"
    Write-Host ""

    exit 1
}

exit 0