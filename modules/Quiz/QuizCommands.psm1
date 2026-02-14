# Quiz Commands Module - Music Quiz using liked songs

function Get-QuizHighscore {
    param([int]$Rounds = 5)

    $highscorePath = Join-Path $env:APPDATA "SpotifyCLI\quiz_highscore.json"

    if (Test-Path $highscorePath) {
        try {
            $data = Get-Content $highscorePath -Raw -Encoding UTF8 | ConvertFrom-Json
            # Return highscore matching the round count
            if ($data.rounds -eq $Rounds) {
                return $data
            }
        }
        catch {
            # Corrupt file, ignore
        }
    }

    return $null
}

function Save-QuizHighscore {
    param(
        [int]$Score,
        [int]$Rounds
    )

    $dir = Join-Path $env:APPDATA "SpotifyCLI"
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $highscorePath = Join-Path $dir "quiz_highscore.json"

    $data = @{
        highScore = $Score
        date      = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        rounds    = $Rounds
    }

    $data | ConvertTo-Json | Set-Content $highscorePath -Encoding UTF8
}

function Start-QuizRound {
    param(
        [Parameter(Mandatory)]$Track,
        [int]$RoundNumber,
        [int]$TotalRounds,
        [int]$Duration = 5
    )

    $trackName = $Track.track.name
    $artistName = ($Track.track.artists | ForEach-Object { $_.name }) -join ", "
    $trackUri = $Track.track.uri
    $durationMs = $Track.track.duration_ms

    # Calculate random start position (avoid first/last 30s)
    if ($durationMs -gt 60000) {
        $minPos = 30000
        $maxPos = $durationMs - 30000 - ($Duration * 1000)
        if ($maxPos -lt $minPos) { $maxPos = $minPos }
        $positionMs = Get-Random -Minimum $minPos -Maximum ($maxPos + 1)
    }
    else {
        $positionMs = 0
    }

    Write-Host ""
    Write-Host "  Round $RoundNumber/$TotalRounds" -ForegroundColor Cyan
    Write-Host "  Listening..." -ForegroundColor Yellow

    # Play the snippet
    try {
        $body = @{
            uris        = @($trackUri)
            position_ms = $positionMs
        }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
    }
    catch {
        Write-Host "  Could not play track. Make sure a Spotify device is active." -ForegroundColor Red
        return 0
    }

    # Wait for the snippet duration
    Start-Sleep -Seconds $Duration

    # Pause playback
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
    }
    catch {
        # Ignore pause errors
    }

    # Ask for answer
    Write-Host ""
    $answer = Read-Host "  Guess the song (title or artist)"

    if ([string]::IsNullOrWhiteSpace($answer)) {
        Write-Host "  No answer! It was: $trackName - $artistName" -ForegroundColor Red
        Write-Host ""
        return 0
    }

    $answerLower = $answer.Trim().ToLower()
    $trackLower = $trackName.ToLower()
    $artistLower = $artistName.ToLower()

    $points = 0
    $matchDesc = @()

    # Exact track name match
    if ($answerLower -eq $trackLower) {
        $points += 20
        $matchDesc += "exact title match (20p)"
    }
    # Exact artist match
    elseif ($answerLower -eq $artistLower) {
        $points += 10
        $matchDesc += "exact artist match (10p)"
    }
    # Partial matches
    else {
        if ($trackLower -like "*$answerLower*" -or $answerLower -like "*$trackLower*") {
            $points += 5
            $matchDesc += "partial title match (5p)"
        }
        if ($artistLower -like "*$answerLower*" -or $answerLower -like "*$artistLower*") {
            $points += 5
            $matchDesc += "partial artist match (5p)"
        }
    }

    if ($points -gt 0) {
        Write-Host "  Correct! +$points points ($($matchDesc -join ', '))" -ForegroundColor Green
    }
    else {
        Write-Host "  Wrong!" -ForegroundColor Red
    }
    Write-Host "  Answer: $trackName - $artistName" -ForegroundColor Gray

    return $points
}

function Start-MusicQuiz {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [int]$Rounds = 5,

        [int]$Duration = 5
    )

    # Validate parameters
    if ($Rounds -lt 1) { $Rounds = 1 }
    if ($Rounds -gt 20) { $Rounds = 20 }
    if ($Duration -lt 2) { $Duration = 2 }
    if ($Duration -gt 15) { $Duration = 15 }

    Write-Host ""
    Write-Host "  MUSIC QUIZ" -ForegroundColor Cyan
    Write-Host "  ==========" -ForegroundColor Cyan
    Write-Host "  Guess songs from your liked tracks!" -ForegroundColor White
    Write-Host "  Rounds: $Rounds | Snippet: ${Duration}s" -ForegroundColor Gray
    Write-Host ""

    # Save current playback state to restore later
    $previousState = $null
    try {
        $previousState = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
    }
    catch {
        # No active playback, that's fine
    }

    # Get total liked songs count
    Write-Host "  Fetching your liked songs..." -ForegroundColor Gray
    try {
        $likedInfo = Invoke-SpotifyApi -Method GET -Path "/me/tracks" -Query @{ limit = 1; offset = 0 }
        $totalLiked = $likedInfo.total
    }
    catch {
        Write-Host "  Could not fetch liked songs. Check your connection." -ForegroundColor Red
        return
    }

    if ($totalLiked -lt $Rounds) {
        Write-Host "  You only have $totalLiked liked songs. Need at least $Rounds for the quiz." -ForegroundColor Red
        return
    }

    Write-Host "  Found $totalLiked liked songs. Picking $Rounds random tracks..." -ForegroundColor Gray

    # Pick random tracks (unique offsets)
    $usedOffsets = @()
    $quizTracks = @()

    for ($i = 0; $i -lt $Rounds; $i++) {
        $maxAttempts = 50
        $attempt = 0
        do {
            $offset = Get-Random -Minimum 0 -Maximum $totalLiked
            $attempt++
        } while ($usedOffsets -contains $offset -and $attempt -lt $maxAttempts)

        $usedOffsets += $offset

        try {
            $result = Invoke-SpotifyApi -Method GET -Path "/me/tracks" -Query @{ limit = 1; offset = $offset }
            if ($result.items -and $result.items.Count -gt 0) {
                $quizTracks += $result.items[0]
            }
        }
        catch {
            Write-Host "  Warning: Could not fetch track at offset $offset, skipping..." -ForegroundColor Yellow
        }
    }

    if ($quizTracks.Count -eq 0) {
        Write-Host "  Could not fetch any tracks for the quiz." -ForegroundColor Red
        return
    }

    $actualRounds = $quizTracks.Count
    Write-Host ""
    Write-Host "  Ready! $actualRounds rounds. Listen carefully!" -ForegroundColor Green
    Write-Host "  Press Enter to start..." -ForegroundColor Gray
    Read-Host | Out-Null

    # Run quiz rounds
    $totalScore = 0
    $maxScore = $actualRounds * 20

    for ($i = 0; $i -lt $actualRounds; $i++) {
        $points = Start-QuizRound -Track $quizTracks[$i] -RoundNumber ($i + 1) -TotalRounds $actualRounds -Duration $Duration
        $totalScore += $points
    }

    # Show results
    Write-Host ""
    Write-Host "  ========================" -ForegroundColor Cyan
    Write-Host "  QUIZ COMPLETE!" -ForegroundColor Cyan
    Write-Host "  Score: $totalScore / $maxScore points" -ForegroundColor White

    $percentage = if ($maxScore -gt 0) { [Math]::Round(($totalScore / $maxScore) * 100) } else { 0 }

    if ($percentage -ge 80) {
        Write-Host "  Amazing! You really know your music!" -ForegroundColor Green
    }
    elseif ($percentage -ge 50) {
        Write-Host "  Not bad! Keep listening!" -ForegroundColor Yellow
    }
    else {
        Write-Host "  Better luck next time!" -ForegroundColor Red
    }

    # Check highscore
    $existing = Get-QuizHighscore -Rounds $actualRounds
    if ($null -eq $existing -or $totalScore -gt $existing.highScore) {
        Write-Host "  NEW HIGHSCORE!" -ForegroundColor Magenta
        Save-QuizHighscore -Score $totalScore -Rounds $actualRounds
    }
    elseif ($null -ne $existing) {
        Write-Host "  Highscore: $($existing.highScore) pts ($($existing.date))" -ForegroundColor Gray
    }

    Write-Host "  ========================" -ForegroundColor Cyan
    Write-Host ""

    # Offer to restore previous playback
    if ($null -ne $previousState -and $null -ne $previousState.item) {
        $restoreChoice = Read-Host "  Resume previous track? ($($previousState.item.name)) [Y/n]"
        if ($restoreChoice -ne 'n' -and $restoreChoice -ne 'N') {
            try {
                $body = @{
                    uris        = @($previousState.item.uri)
                    position_ms = [int]$previousState.progress_ms
                }
                Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
                if (-not $previousState.is_playing) {
                    Start-Sleep -Milliseconds 300
                    Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
                }
                Write-Host "  Playback restored." -ForegroundColor Green
            }
            catch {
                Write-Host "  Could not restore playback." -ForegroundColor Yellow
            }
        }
    }
}

# Export and alias
New-Alias -Name 'quiz' -Value 'Start-MusicQuiz' -Force
Export-ModuleMember -Function 'Start-MusicQuiz' -Alias 'quiz'
