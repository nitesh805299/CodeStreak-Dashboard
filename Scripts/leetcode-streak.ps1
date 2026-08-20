$username = "nitesh_805299"

$basePath = Split-Path -Parent $PSScriptRoot
$outputFile = Join-Path $basePath "leetcode-data.txt"

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
# GRAPHQL
# ============================================================

$url = "https://leetcode.com/graphql"

$query = @"
query userProfileCalendar(`$username: String!, `$year: Int) {
    matchedUser(username: `$username) {
        userCalendar(year: `$year) {
            submissionCalendar
        }
        recentAcSubmissionList(limit: 1) {
            timestamp
        }
    }
}
"@

$year = (Get-Date).Year

$body = @{
    query = $query

    variables = @{
        username = $username
        year = $year
    }
} | ConvertTo-Json -Depth 5


# ============================================================
# RETRIES
# ============================================================

$maxRetries = 3
$success = $false
$lastError = ""

for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {

    try {

        Write-Host "LeetCode attempt $attempt of $maxRetries..."

        $response = Invoke-RestMethod `
            -Uri $url `
            -Method POST `
            -TimeoutSec 30 `
            -ContentType "application/json" `
            -Headers @{
                "User-Agent" = "Mozilla/5.0"
                "Referer" = "https://leetcode.com/u/$username/"
            } `
            -Body $body


        if (-not $response.data.matchedUser) {
            throw "LeetCode user nahi mila."
        }


        $calendarJSON =
            $response.data.matchedUser.userCalendar.submissionCalendar

        if (-not $calendarJSON) {
            throw "Submission calendar nahi mila."
        }


        $calendar =
            $calendarJSON |
            ConvertFrom-Json


        # ====================================================
        # ACTIVE DATES
        # ====================================================

        $activeDates = @()

        foreach ($property in $calendar.PSObject.Properties) {

            $timestamp = [long]$property.Name
            $submissionCount = [int]$property.Value

            if ($submissionCount -gt 0) {

                $date =
                    [DateTimeOffset]::FromUnixTimeSeconds(
                        $timestamp
                    ).LocalDateTime.Date

                $activeDates += $date
            }
        }

        $activeDates =
            $activeDates |
            Sort-Object -Unique


        # The calendar can lag behind the Recent AC list by a few minutes.
        # Count a just-accepted problem immediately instead of leaving today's
        # task as Remaining until LeetCode refreshes its calendar cache.
        $recentAcceptedToday = $false

        $recentAccepted =
            $response.data.matchedUser.recentAcSubmissionList |
            Select-Object -First 1

        if ($recentAccepted -and $recentAccepted.timestamp) {
            $recentAcceptedDate =
                [DateTimeOffset]::FromUnixTimeSeconds(
                    [long]$recentAccepted.timestamp
                ).LocalDateTime.Date

            $recentAcceptedToday =
                $recentAcceptedDate -eq $today
        }

        if (
            $recentAcceptedToday -and
            -not ($activeDates -contains $today)
        ) {
            $activeDates += $today
            $activeDates = $activeDates | Sort-Object -Unique
        }


        # ====================================================
        # TODAY STATUS
        # ====================================================

        if ($activeDates -contains $today) {
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

        while ($activeDates -contains $checkDate) {

            $currentStreak++
            $checkDate = $checkDate.AddDays(-1)
        }


        # ====================================================
        # LONGEST STREAK
        # ====================================================

        $longestStreak = 0
        $tempStreak = 0
        $previousDate = $null

        foreach ($date in $activeDates) {

            if (
                $previousDate -ne $null -and
                $date -eq $previousDate.AddDays(1)
            ) {
                $tempStreak++
            }
            else {
                $tempStreak = 1
            }

            if ($tempStreak -gt $longestStreak) {
                $longestStreak = $tempStreak
            }

            $previousDate = $date
        }


        if ($oldLongest -gt $longestStreak) {
            $longestStreak = $oldLongest
        }


        # ====================================================
        # SAVE
        # ====================================================

@"
CurrentStreak=$currentStreak
LongestStreak=$longestStreak
TodayStatus=$todayStatus
TodayActivitySource=$(if ($recentAcceptedToday) { "Recent accepted submission" } elseif ($activeDates -contains $today) { "Submission calendar" } else { "None" })
DataDate=$todayString
LastUpdated=$(Get-Date -Format "dd-MM-yyyy HH:mm:ss")
FetchStatus=OK
"@ | Set-Content `
            -Path $outputFile `
            -Encoding UTF8


        Write-Host ""
        Write-Host "LeetCode Data Updated"
        Write-Host "---------------------"
        Write-Host "Username       : $username"
        Write-Host "Current Streak : $currentStreak days"
        Write-Host "Longest Streak : $longestStreak days"
        Write-Host "Today Status   : $todayStatus"
        Write-Host ""

        $success = $true
        break
    }
    catch {

        $lastError = $_.Exception.Message

        Write-Host "LeetCode attempt failed:"
        Write-Host $lastError

        if ($attempt -lt $maxRetries) {
            Write-Host "Retrying in 5 seconds..."
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
    Write-Host "LeetCode ERROR"
    Write-Host "--------------"
    Write-Host "Old streak data preserved."
    Write-Host "Today Status : $safeStatus"
    Write-Host "Reason       : $lastError"
    Write-Host ""

    exit 1
}

exit 0
