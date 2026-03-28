# Quiz Commands Module - Multiple Choice Music Quiz using liked songs

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

function Get-ShuffledOptions {
    param(
        [Parameter(Mandatory)][string]$Correct,
        [Parameter(Mandatory)][string[]]$DecoyPool,
        [int]$Count = 3
    )

    # Filter out the correct answer and deduplicate
    $available = $DecoyPool | Where-Object { $_ -ne $Correct } | Select-Object -Unique

    # Pick random decoys
    if ($available.Count -le $Count) {
        $decoys = @($available)
    }
    else {
        $decoys = @($available | Get-Random -Count $Count)
    }

    # Combine with correct answer and shuffle
    $options = @($decoys) + @($Correct)
    $shuffled = $options | Get-Random -Count $options.Count

    # Find the index of the correct answer (1-based)
    $correctIndex = -1
    for ($i = 0; $i -lt $shuffled.Count; $i++) {
        if ($shuffled[$i] -eq $Correct) {
            $correctIndex = $i + 1
            break
        }
    }

    return @{
        Options      = $shuffled
        CorrectIndex = $correctIndex
    }
}

function Start-QuizRound {
    param(
        [Parameter(Mandatory)]$Track,
        [int]$RoundNumber,
        [int]$TotalRounds,
        [Parameter(Mandatory)][string[]]$DecoyArtists,
        [Parameter(Mandatory)][string[]]$DecoyTracks
    )

    $trackName = $Track.track.name
    $artistName = ($Track.track.artists | ForEach-Object { $_.name }) -join ", "
    $trackUri = $Track.track.uri
    $durationMs = $Track.track.duration_ms

    # Calculate random start position (avoid first/last 30s)
    if ($durationMs -gt 60000) {
        $minPos = 30000
        $maxPos = $durationMs - 30000 - 8000  # leave room for up to 8s of playback
        if ($maxPos -lt $minPos) { $maxPos = $minPos }
        $positionMs = Get-Random -Minimum $minPos -Maximum ($maxPos + 1)
    }
    else {
        $positionMs = 0
    }

    Write-Host ""
    Write-Host "  Round $RoundNumber/$TotalRounds" -ForegroundColor Cyan
    Write-Host "  Listening..." -ForegroundColor Yellow

    # Ensure playback is stopped before starting new track
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
        Start-Sleep -Milliseconds 300
    }
    catch { }

    # Play 3-second snippet for artist guess
    try {
        $body = @{
            uris        = @($trackUri)
            position_ms = $positionMs
        }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
    }
    catch {
        # Retry once after a brief wait
        Start-Sleep -Milliseconds 500
        try {
            Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
        }
        catch {
            Write-Host "  Could not play track. Make sure a Spotify device is active." -ForegroundColor Red
            return 0
        }
    }

    Start-Sleep -Seconds 3

    # Pause for artist guess
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
    }
    catch { }

    # Phase 1: Artist multiple choice
    $artistResult = Get-ShuffledOptions -Correct $artistName -DecoyPool $DecoyArtists
    Write-Host ""
    Write-Host "  Who is the artist?" -ForegroundColor White
    for ($i = 0; $i -lt $artistResult.Options.Count; $i++) {
        Write-Host "  $($i + 1). $($artistResult.Options[$i])" -ForegroundColor Gray
    }

    $artistChoice = Read-Host "  >"

    if ([string]::IsNullOrWhiteSpace($artistChoice)) {
        Write-Host "  No answer! It was: $artistName - $trackName" -ForegroundColor Red
        Write-Host ""
        return 0
    }

    $choiceNum = 0
    if (-not [int]::TryParse($artistChoice.Trim(), [ref]$choiceNum) -or $choiceNum -lt 1 -or $choiceNum -gt $artistResult.Options.Count) {
        Write-Host "  Invalid choice! It was: $artistName - $trackName" -ForegroundColor Red
        Write-Host ""
        return 0
    }

    if ($choiceNum -ne $artistResult.CorrectIndex) {
        Write-Host "  Wrong! It was: $artistName - $trackName" -ForegroundColor Red
        Write-Host "  0 points this round." -ForegroundColor Gray
        Write-Host ""
        return 0
    }

    # Correct artist!
    Write-Host "  Correct! +10 points" -ForegroundColor Green
    $totalPoints = 10

    # Phase 2: Resume from where we paused, play 5 more seconds, then ask for song title
    Write-Host ""
    Write-Host "  Listening to more..." -ForegroundColor Yellow

    try {
        $resumeBody = @{
            uris        = @($trackUri)
            position_ms = $positionMs + 3000
        }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $resumeBody | Out-Null
    }
    catch { }

    Start-Sleep -Seconds 5

    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
    }
    catch { }

    # Song title multiple choice
    $songResult = Get-ShuffledOptions -Correct $trackName -DecoyPool $DecoyTracks
    Write-Host ""
    Write-Host "  What song is it?" -ForegroundColor White
    for ($i = 0; $i -lt $songResult.Options.Count; $i++) {
        Write-Host "  $($i + 1). $($songResult.Options[$i])" -ForegroundColor Gray
    }

    $songChoice = Read-Host "  >"

    if ([string]::IsNullOrWhiteSpace($songChoice)) {
        Write-Host "  No answer! It was: $trackName" -ForegroundColor Red
        Write-Host "  $totalPoints points this round." -ForegroundColor Gray
        Write-Host ""
        return $totalPoints
    }

    $songNum = 0
    if (-not [int]::TryParse($songChoice.Trim(), [ref]$songNum) -or $songNum -lt 1 -or $songNum -gt $songResult.Options.Count) {
        Write-Host "  Invalid choice! It was: $trackName" -ForegroundColor Red
        Write-Host "  $totalPoints points this round." -ForegroundColor Gray
        Write-Host ""
        return $totalPoints
    }

    if ($songNum -eq $songResult.CorrectIndex) {
        $totalPoints += 10
        Write-Host "  Correct! +10 points" -ForegroundColor Green
    }
    else {
        Write-Host "  Wrong! It was: $trackName" -ForegroundColor Red
    }

    Write-Host "  Total: $totalPoints/20 for this round!" -ForegroundColor Cyan
    Write-Host ""
    return $totalPoints
}

function Start-MusicQuiz {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [int]$Rounds = 5
    )

    # Validate parameters
    if ($Rounds -lt 1) { $Rounds = 1 }
    if ($Rounds -gt 20) { $Rounds = 20 }

    Write-Host ""
    Write-Host "  MUSIC QUIZ" -ForegroundColor Cyan
    Write-Host "  ==========" -ForegroundColor Cyan
    Write-Host "  Multiple choice quiz from your liked tracks!" -ForegroundColor White
    Write-Host "  Rounds: $Rounds | Artist (3s) + Song (5s)" -ForegroundColor Gray
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

    # Need extra tracks for decoys
    $totalToFetch = $Rounds + 12
    if ($totalLiked -lt $totalToFetch) {
        $totalToFetch = [Math]::Min($totalLiked, $Rounds + $totalLiked)
    }

    if ($totalLiked -lt $Rounds) {
        Write-Host "  You only have $totalLiked liked songs. Need at least $Rounds for the quiz." -ForegroundColor Red
        return
    }

    if ($totalLiked -lt 4) {
        Write-Host "  You need at least 4 liked songs for multiple choice. You have $totalLiked." -ForegroundColor Red
        return
    }

    Write-Host "  Found $totalLiked liked songs. Picking tracks..." -ForegroundColor Gray

    # Pick random tracks (unique offsets) - fetch extra for decoys
    $usedOffsets = @()
    $allTracks = @()

    for ($i = 0; $i -lt $totalToFetch; $i++) {
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
                $allTracks += $result.items[0]
            }
        }
        catch {
            # Skip failed fetches
        }
    }

    if ($allTracks.Count -lt 4) {
        Write-Host "  Could not fetch enough tracks for the quiz." -ForegroundColor Red
        return
    }

    # Split into quiz tracks and build decoy pools from ALL tracks
    $quizTracks = @($allTracks | Select-Object -First $Rounds)
    $actualRounds = $quizTracks.Count

    # Build decoy pools from all fetched tracks (including quiz tracks)
    $decoyArtists = @($allTracks | ForEach-Object {
        ($_.track.artists | ForEach-Object { $_.name }) -join ", "
    } | Select-Object -Unique)

    $decoyTrackNames = @($allTracks | ForEach-Object {
        $_.track.name
    } | Select-Object -Unique)

    Write-Host ""
    Write-Host "  Ready! $actualRounds rounds. Listen carefully!" -ForegroundColor Green
    Write-Host "  Press Enter to start..." -ForegroundColor Gray
    Read-Host | Out-Null

    # Run quiz rounds
    $totalScore = 0
    $maxScore = $actualRounds * 20

    for ($i = 0; $i -lt $actualRounds; $i++) {
        # Brief pause between rounds to let Spotify API settle
        if ($i -gt 0) { Start-Sleep -Milliseconds 500 }
        $points = Start-QuizRound -Track $quizTracks[$i] -RoundNumber ($i + 1) -TotalRounds $actualRounds -DecoyArtists $decoyArtists -DecoyTracks $decoyTrackNames
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
Export-ModuleMember -Function 'Start-MusicQuiz', 'Get-ShuffledOptions' -Alias 'quiz'
