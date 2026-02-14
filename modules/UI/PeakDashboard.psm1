# Peak Dashboard Module
# Shows real-time track insights in a Windows Form window
# Uses standard Spotify API data (no extended quota required)

function Show-PeakDashboard {
    <#
    .SYNOPSIS
    Display track insights dashboard for the currently playing track

    .DESCRIPTION
    Creates a non-blocking Windows Form that displays track and artist data
    (popularity, artist popularity, followers, genres, album info, duration)
    with progress bars. Automatically updates when the track changes.

    .EXAMPLE
    Show-PeakDashboard

    .EXAMPLE
    peak
    #>

    $scriptPath = $PSScriptRoot
    $modulePath = Split-Path -Parent $scriptPath
    $rootPath = Split-Path -Parent $modulePath

    # Get current environment variables for Spotify credentials
    $clientId = $env:SPOTIFY_CLIENT_ID
    $clientSecret = $env:SPOTIFY_CLIENT_SECRET

    # Create temp directory
    $tempDir = Join-Path $env:TEMP "SpotifyPeak"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }

    $backgroundScript = @"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Set credentials for token refresh
`$env:SPOTIFY_CLIENT_ID = '$clientId'
`$env:SPOTIFY_CLIENT_SECRET = '$clientSecret'

# Import API client
Import-Module '$rootPath\modules\Core\LegacyApiClient.psm1' -Force -ErrorAction SilentlyContinue

# --- State ---
`$script:currentTrackUri = `$null
`$script:popHistory = [System.Collections.Generic.List[int]]::new()

# --- Colors ---
`$bgColor = [System.Drawing.ColorTranslator]::FromHtml('#1A1A1A')
`$bgLight = [System.Drawing.ColorTranslator]::FromHtml('#2D2D2D')
`$accent = [System.Drawing.ColorTranslator]::FromHtml('#4ECDC4')
`$textWhite = [System.Drawing.Color]::White
`$textGray = [System.Drawing.ColorTranslator]::FromHtml('#B3B3B3')
`$goldColor = [System.Drawing.ColorTranslator]::FromHtml('#FFD700')
`$pinkColor = [System.Drawing.ColorTranslator]::FromHtml('#FF69B4')

# --- Form ---
`$form = New-Object System.Windows.Forms.Form
`$form.Text = "Peak Dashboard"
`$form.Size = New-Object System.Drawing.Size(420, 530)
`$form.StartPosition = 'CenterScreen'
`$form.BackColor = `$bgColor
`$form.ForeColor = `$textWhite
`$form.FormBorderStyle = 'FixedToolWindow'
`$form.TopMost = `$true

# --- Header: Song + Artist ---
`$lblSong = New-Object System.Windows.Forms.Label
`$lblSong.Location = New-Object System.Drawing.Point(15, 12)
`$lblSong.Size = New-Object System.Drawing.Size(375, 24)
`$lblSong.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
`$lblSong.ForeColor = `$accent
`$lblSong.Text = "Loading..."
`$form.Controls.Add(`$lblSong)

`$lblArtist = New-Object System.Windows.Forms.Label
`$lblArtist.Location = New-Object System.Drawing.Point(15, 38)
`$lblArtist.Size = New-Object System.Drawing.Size(375, 20)
`$lblArtist.Font = New-Object System.Drawing.Font('Segoe UI', 9)
`$lblArtist.ForeColor = `$textGray
`$lblArtist.Text = ""
`$form.Controls.Add(`$lblArtist)

# --- Metric rows with progress bars ---
`$metrics = @(
    @{ Name = "Track Pop.";    Tag = "trackpop" },
    @{ Name = "Artist Pop.";   Tag = "artistpop" }
)

`$script:bars = @{}
`$script:valueLabels = @{}
`$yStart = 72
`$rowHeight = 42

foreach (`$m in `$metrics) {
    `$y = `$yStart + (`$metrics.IndexOf(`$m) * `$rowHeight)

    `$nameLabel = New-Object System.Windows.Forms.Label
    `$nameLabel.Location = New-Object System.Drawing.Point(15, `$y)
    `$nameLabel.Size = New-Object System.Drawing.Size(90, 18)
    `$nameLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    `$nameLabel.ForeColor = `$textGray
    `$nameLabel.Text = `$m.Name
    `$form.Controls.Add(`$nameLabel)

    `$bar = New-Object System.Windows.Forms.ProgressBar
    `$bar.Location = New-Object System.Drawing.Point(110, `$y)
    `$bar.Size = New-Object System.Drawing.Size(210, 18)
    `$bar.Style = 'Continuous'
    `$bar.ForeColor = `$accent
    `$bar.BackColor = `$bgLight
    `$bar.Minimum = 0
    `$bar.Maximum = 100
    `$bar.Value = 0
    `$form.Controls.Add(`$bar)
    `$script:bars[`$m.Tag] = `$bar

    `$valLabel = New-Object System.Windows.Forms.Label
    `$valLabel.Location = New-Object System.Drawing.Point(328, `$y)
    `$valLabel.Size = New-Object System.Drawing.Size(70, 18)
    `$valLabel.Font = New-Object System.Drawing.Font('Consolas', 9)
    `$valLabel.ForeColor = `$textWhite
    `$valLabel.Text = "---"
    `$valLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    `$form.Controls.Add(`$valLabel)
    `$script:valueLabels[`$m.Tag] = `$valLabel
}

# --- Info section ---
`$yInfo = `$yStart + (`$metrics.Count * `$rowHeight) + 8

# Followers row
`$lblFollowersTitle = New-Object System.Windows.Forms.Label
`$lblFollowersTitle.Location = New-Object System.Drawing.Point(15, `$yInfo)
`$lblFollowersTitle.Size = New-Object System.Drawing.Size(90, 18)
`$lblFollowersTitle.Font = New-Object System.Drawing.Font('Segoe UI', 9)
`$lblFollowersTitle.ForeColor = `$textGray
`$lblFollowersTitle.Text = "Followers"
`$form.Controls.Add(`$lblFollowersTitle)

`$lblFollowers = New-Object System.Windows.Forms.Label
`$lblFollowers.Location = New-Object System.Drawing.Point(110, `$yInfo)
`$lblFollowers.Size = New-Object System.Drawing.Size(280, 18)
`$lblFollowers.Font = New-Object System.Drawing.Font('Consolas', 9)
`$lblFollowers.ForeColor = `$goldColor
`$lblFollowers.Text = "---"
`$form.Controls.Add(`$lblFollowers)

# Duration row
`$yDur = `$yInfo + 28
`$lblDurTitle = New-Object System.Windows.Forms.Label
`$lblDurTitle.Location = New-Object System.Drawing.Point(15, `$yDur)
`$lblDurTitle.Size = New-Object System.Drawing.Size(90, 18)
`$lblDurTitle.Font = New-Object System.Drawing.Font('Segoe UI', 9)
`$lblDurTitle.ForeColor = `$textGray
`$lblDurTitle.Text = "Duration"
`$form.Controls.Add(`$lblDurTitle)

`$lblDuration = New-Object System.Windows.Forms.Label
`$lblDuration.Location = New-Object System.Drawing.Point(110, `$yDur)
`$lblDuration.Size = New-Object System.Drawing.Size(280, 18)
`$lblDuration.Font = New-Object System.Drawing.Font('Consolas', 9)
`$lblDuration.ForeColor = `$textWhite
`$lblDuration.Text = "---"
`$form.Controls.Add(`$lblDuration)

# Album row
`$yAlbum = `$yDur + 28
`$lblAlbumTitle = New-Object System.Windows.Forms.Label
`$lblAlbumTitle.Location = New-Object System.Drawing.Point(15, `$yAlbum)
`$lblAlbumTitle.Size = New-Object System.Drawing.Size(90, 18)
`$lblAlbumTitle.Font = New-Object System.Drawing.Font('Segoe UI', 9)
`$lblAlbumTitle.ForeColor = `$textGray
`$lblAlbumTitle.Text = "Album"
`$form.Controls.Add(`$lblAlbumTitle)

`$lblAlbum = New-Object System.Windows.Forms.Label
`$lblAlbum.Location = New-Object System.Drawing.Point(110, `$yAlbum)
`$lblAlbum.Size = New-Object System.Drawing.Size(280, 18)
`$lblAlbum.Font = New-Object System.Drawing.Font('Segoe UI', 9)
`$lblAlbum.ForeColor = `$textWhite
`$lblAlbum.Text = "---"
`$form.Controls.Add(`$lblAlbum)

# Release + Track number row
`$yRelease = `$yAlbum + 22
`$lblRelease = New-Object System.Windows.Forms.Label
`$lblRelease.Location = New-Object System.Drawing.Point(110, `$yRelease)
`$lblRelease.Size = New-Object System.Drawing.Size(280, 18)
`$lblRelease.Font = New-Object System.Drawing.Font('Segoe UI', 8)
`$lblRelease.ForeColor = `$textGray
`$lblRelease.Text = ""
`$form.Controls.Add(`$lblRelease)

# Explicit badge
`$lblExplicit = New-Object System.Windows.Forms.Label
`$lblExplicit.Location = New-Object System.Drawing.Point(15, `$yRelease)
`$lblExplicit.Size = New-Object System.Drawing.Size(90, 18)
`$lblExplicit.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
`$lblExplicit.ForeColor = `$pinkColor
`$lblExplicit.Text = ""
`$form.Controls.Add(`$lblExplicit)

# --- Genres ---
`$yGenres = `$yRelease + 28
`$lblGenresTitle = New-Object System.Windows.Forms.Label
`$lblGenresTitle.Location = New-Object System.Drawing.Point(15, `$yGenres)
`$lblGenresTitle.Size = New-Object System.Drawing.Size(90, 18)
`$lblGenresTitle.Font = New-Object System.Drawing.Font('Segoe UI', 9)
`$lblGenresTitle.ForeColor = `$textGray
`$lblGenresTitle.Text = "Genres"
`$form.Controls.Add(`$lblGenresTitle)

`$lblGenres = New-Object System.Windows.Forms.Label
`$lblGenres.Location = New-Object System.Drawing.Point(110, `$yGenres)
`$lblGenres.Size = New-Object System.Drawing.Size(280, 36)
`$lblGenres.Font = New-Object System.Drawing.Font('Segoe UI', 8)
`$lblGenres.ForeColor = `$accent
`$lblGenres.Text = "---"
`$form.Controls.Add(`$lblGenres)

# --- Mini-graph panel (popularity history) ---
`$yGraph = `$yGenres + 44
`$graphPanel = New-Object System.Windows.Forms.Panel
`$graphPanel.Location = New-Object System.Drawing.Point(15, `$yGraph)
`$graphPanel.Size = New-Object System.Drawing.Size(375, 60)
`$graphPanel.BackColor = `$bgLight
`$form.Controls.Add(`$graphPanel)

`$lblGraphTitle = New-Object System.Windows.Forms.Label
`$lblGraphTitle.Location = New-Object System.Drawing.Point(5, 2)
`$lblGraphTitle.Size = New-Object System.Drawing.Size(365, 16)
`$lblGraphTitle.Font = New-Object System.Drawing.Font('Segoe UI', 8)
`$lblGraphTitle.ForeColor = `$textGray
`$lblGraphTitle.Text = "Popularity (last 10 tracks)"
`$graphPanel.Controls.Add(`$lblGraphTitle)

`$lblGraph = New-Object System.Windows.Forms.Label
`$lblGraph.Location = New-Object System.Drawing.Point(5, 22)
`$lblGraph.Size = New-Object System.Drawing.Size(365, 34)
`$lblGraph.Font = New-Object System.Drawing.Font('Consolas', 18)
`$lblGraph.ForeColor = `$accent
`$lblGraph.Text = ""
`$graphPanel.Controls.Add(`$lblGraph)

# --- Status label ---
`$yStatus = `$yGraph + 65
`$lblStatus = New-Object System.Windows.Forms.Label
`$lblStatus.Location = New-Object System.Drawing.Point(15, `$yStatus)
`$lblStatus.Size = New-Object System.Drawing.Size(375, 18)
`$lblStatus.Font = New-Object System.Drawing.Font('Segoe UI', 8)
`$lblStatus.ForeColor = `$textGray
`$lblStatus.Text = "Waiting for track..."
`$form.Controls.Add(`$lblStatus)

# --- Helper: value to block char ---
function Get-BlockChar {
    param([double]`$val)
    `$blocks = @([char]0x2581, [char]0x2582, [char]0x2583, [char]0x2584, [char]0x2585, [char]0x2586, [char]0x2587, [char]0x2588)
    `$idx = [Math]::Min(7, [Math]::Max(0, [int](`$val * 7.99)))
    return `$blocks[`$idx]
}

# --- Helper: format follower count ---
function Format-Number {
    param([long]`$n)
    if (`$n -ge 1000000) { return "{0:N1}M" -f (`$n / 1000000) }
    if (`$n -ge 1000) { return "{0:N1}K" -f (`$n / 1000) }
    return `$n.ToString("N0")
}

# --- Helper: update dashboard from playback + artist data ---
function Update-Dashboard {
    param(`$playback, `$artistData)

    `$item = `$playback.item

    # Track popularity (0-100)
    `$trackPop = [int]`$item.popularity
    `$script:bars['trackpop'].Value = [Math]::Min(100, [Math]::Max(0, `$trackPop))
    `$script:valueLabels['trackpop'].Text = "`$trackPop/100"

    # Artist popularity (0-100)
    if (`$artistData) {
        `$artistPop = [int]`$artistData.popularity
        `$script:bars['artistpop'].Value = [Math]::Min(100, [Math]::Max(0, `$artistPop))
        `$script:valueLabels['artistpop'].Text = "`$artistPop/100"

        # Followers
        `$followers = [long]`$artistData.followers.total
        `$lblFollowers.Text = Format-Number `$followers

        # Genres
        `$genres = `$artistData.genres
        if (`$genres -and `$genres.Count -gt 0) {
            `$lblGenres.Text = (`$genres | Select-Object -First 4) -join ", "
        } else {
            `$lblGenres.Text = "n/a"
        }
    }

    # Duration
    `$durMs = [long]`$item.duration_ms
    `$durMin = [int][Math]::Floor(`$durMs / 60000)
    `$durSec = [int][Math]::Floor((`$durMs % 60000) / 1000)
    `$lblDuration.Text = "{0}:{1:D2}" -f `$durMin, `$durSec

    # Album
    `$lblAlbum.Text = `$item.album.name
    `$releaseDate = `$item.album.release_date
    `$trackNum = `$item.track_number
    `$totalTracks = `$item.album.total_tracks
    `$lblRelease.Text = "Released: `$releaseDate  |  Track `$trackNum of `$totalTracks"

    # Explicit
    `$lblExplicit.Text = if (`$item.explicit) { "EXPLICIT" } else { "" }

    # Update popularity history graph
    `$script:popHistory.Add(`$trackPop)
    if (`$script:popHistory.Count -gt 10) {
        `$script:popHistory.RemoveAt(0)
    }
    `$graphChars = (`$script:popHistory | ForEach-Object { Get-BlockChar (`$_ / 100.0) }) -join " "
    `$lblGraph.Text = `$graphChars

    `$lblStatus.Text = "Updated: `$(Get-Date -Format 'HH:mm:ss')"
}

# --- Timer: poll every 2 seconds ---
`$timer = New-Object System.Windows.Forms.Timer
`$timer.Interval = 2000

`$timer.Add_Tick({
    try {
        `$playback = Invoke-SpotifyApi -Method GET -Path '/me/player' -ErrorAction SilentlyContinue
        if (-not `$playback -or -not `$playback.item) {
            `$lblStatus.Text = "No track playing"
            return
        }

        `$trackUri = `$playback.item.uri
        `$isPlaying = `$playback.is_playing

        if (-not `$isPlaying) {
            `$lblStatus.Text = "Paused"
        }

        # Only update on track change
        if (`$trackUri -ne `$script:currentTrackUri) {
            `$script:currentTrackUri = `$trackUri

            # Update header
            `$songName = `$playback.item.name
            `$artists = (`$playback.item.artists | ForEach-Object { `$_.name }) -join ", "
            `$lblSong.Text = `$songName
            `$lblArtist.Text = `$artists
            `$form.Text = "Peak - `$songName"

            # Fetch artist details (popularity, followers, genres)
            `$artistData = `$null
            try {
                `$artistId = `$playback.item.artists[0].id
                `$artistData = Invoke-SpotifyApi -Method GET -Path "/artists/`$artistId" -ErrorAction SilentlyContinue
            } catch { }

            Update-Dashboard `$playback `$artistData
        }
    } catch {
        # Silently ignore errors
    }
}.GetNewClosure())

`$timer.Start()

# --- Do initial fetch immediately ---
try {
    `$initPlayback = Invoke-SpotifyApi -Method GET -Path '/me/player' -ErrorAction SilentlyContinue
    if (`$initPlayback -and `$initPlayback.item) {
        `$script:currentTrackUri = `$initPlayback.item.uri
        `$lblSong.Text = `$initPlayback.item.name
        `$lblArtist.Text = (`$initPlayback.item.artists | ForEach-Object { `$_.name }) -join ", "
        `$form.Text = "Peak - `$(`$initPlayback.item.name)"

        `$artistData = `$null
        try {
            `$artistId = `$initPlayback.item.artists[0].id
            `$artistData = Invoke-SpotifyApi -Method GET -Path "/artists/`$artistId" -ErrorAction SilentlyContinue
        } catch { }

        Update-Dashboard `$initPlayback `$artistData
    }
} catch {
    `$lblStatus.Text = "Init error: `$(`$_.Exception.Message)"
}

# --- Cleanup ---
`$form.Add_FormClosing({
    `$timer.Stop()
    `$timer.Dispose()
})

`$form.Add_FormClosed({
    Remove-Item '$scriptFile' -Force -ErrorAction SilentlyContinue
})

[void]`$form.ShowDialog()
"@

    # Save script to temp file
    $scriptFile = Join-Path $tempDir "peak_dashboard_$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
    $backgroundScript | Out-File -FilePath $scriptFile -Encoding UTF8

    # Start background process
    Start-Process pwsh -ArgumentList @(
        '-NoProfile',
        '-WindowStyle', 'Hidden',
        '-ExecutionPolicy', 'Bypass',
        '-File', $scriptFile
    )

    Write-Host "Peak Dashboard launched!" -ForegroundColor Green
    Write-Host "Dashboard updates automatically when song changes" -ForegroundColor Cyan
}

Set-Alias -Name peak -Value Show-PeakDashboard -ErrorAction SilentlyContinue

Export-ModuleMember -Function @('Show-PeakDashboard') -Alias @('peak')
