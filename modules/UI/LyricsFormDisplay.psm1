# Lyrics Form Display Module
# Shows synchronized lyrics in a Windows Form window

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-LyricsForm {
    <#
    .SYNOPSIS
    Display lyrics in a Windows Form window with real-time synchronization

    .DESCRIPTION
    Creates a non-blocking Windows Form that displays lyrics with highlighting
    synchronized to the currently playing track.

    .PARAMETER LyricsData
    Hashtable containing lyrics data (from LyricsManager)

    .PARAMETER InitialPositionMs
    Initial playback position in milliseconds

    .EXAMPLE
    Show-LyricsForm -LyricsData $lyricsResult
    #>

    param(
        [Parameter(Mandatory)]
        [hashtable]$LyricsData,

        [int]$InitialPositionMs = 0
    )

    if (-not $LyricsData.Success) {
        Write-Error "Cannot display lyrics: $($LyricsData.Error)"
        return
    }

    # Launch in separate process to avoid blocking
    $scriptPath = $PSScriptRoot
    $modulePath = Split-Path -Parent $scriptPath
    $rootPath = Split-Path -Parent $modulePath

    # Create temp directory for data
    $tempDir = Join-Path $env:TEMP "SpotifyLyrics"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }

    # Save lyrics data to temp file
    $dataFile = Join-Path $tempDir "lyrics_$(Get-Date -Format 'yyyyMMddHHmmss').json"
    $LyricsData | ConvertTo-Json -Depth 10 | Out-File -FilePath $dataFile -Encoding UTF8

    # Create background script
    $backgroundScript = @"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import necessary modules
Import-Module '$rootPath\modules\Core\ApiClientManager.psm1' -Force -ErrorAction SilentlyContinue
Import-Module '$rootPath\modules\Core\LegacyApiClient.psm1' -Force -ErrorAction SilentlyContinue

# Load lyrics data from temp file
`$lyricsData = Get-Content '$dataFile' -Raw | ConvertFrom-Json -AsHashtable

# Clean up temp file after loading
Remove-Item '$dataFile' -Force -ErrorAction SilentlyContinue

# Track info
`$artist = if (`$lyricsData.TrackId) { `$lyricsData.TrackId.Split('-')[0] } else { "Unknown" }
`$track = if (`$lyricsData.TrackId) { (`$lyricsData.TrackId.Split('-', 2)[1]) } else { "Unknown" }
`$source = `$lyricsData.Source

# Create form
`$form = New-Object System.Windows.Forms.Form
`$form.Text = "🎤 Lyrics - `$artist - `$track"
`$form.Size = New-Object System.Drawing.Size(600, 700)
`$form.StartPosition = 'CenterScreen'
`$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#1A1A1A')
`$form.ForeColor = [System.Drawing.Color]::White
`$form.FormBorderStyle = 'SizableToolWindow'
`$form.TopMost = `$true

# Header label
`$headerLabel = New-Object System.Windows.Forms.Label
`$headerLabel.Location = New-Object System.Drawing.Point(10, 10)
`$headerLabel.Size = New-Object System.Drawing.Size(560, 60)
`$headerLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
`$headerLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#4ECDC4')
`$headerLabel.Text = "`$artist`n`$track`n📝 Source: `$source"
`$headerLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
`$form.Controls.Add(`$headerLabel)

# Lyrics panel (scrollable)
`$lyricsPanel = New-Object System.Windows.Forms.Panel
`$lyricsPanel.Location = New-Object System.Drawing.Point(10, 80)
`$lyricsPanel.Size = New-Object System.Drawing.Size(560, 580)
`$lyricsPanel.AutoScroll = `$true
`$lyricsPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#2D2D2D')
`$lyricsPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
`$form.Controls.Add(`$lyricsPanel)

# Create labels for each line
`$lineLabels = @()
`$yPosition = 10

if (`$lyricsData.HasSyncedLyrics -and `$lyricsData.SyncedLines) {
    # Synced lyrics - create label for each line
    foreach (`$line in `$lyricsData.SyncedLines) {
        `$label = New-Object System.Windows.Forms.Label
        `$label.Location = New-Object System.Drawing.Point(10, `$yPosition)
        `$label.Size = New-Object System.Drawing.Size(520, 30)
        `$label.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        `$label.ForeColor = [System.Drawing.Color]::White  # Kommande text = vit
        `$label.Text = `$line.Text
        `$label.Tag = `$line.Timestamp
        `$label.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
        `$label.AutoSize = `$false
        `$lyricsPanel.Controls.Add(`$label)
        `$lineLabels += `$label
        `$yPosition += 35
    }
} else {
    # Plain text lyrics
    `$textLines = `$lyricsData.FullText -split "`n"
    foreach (`$textLine in `$textLines) {
        `$label = New-Object System.Windows.Forms.Label
        `$label.Location = New-Object System.Drawing.Point(10, `$yPosition)
        `$label.Size = New-Object System.Drawing.Size(520, 30)
        `$label.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        `$label.ForeColor = [System.Drawing.Color]::White
        `$label.Text = `$textLine
        `$label.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
        `$label.AutoSize = `$false
        `$lyricsPanel.Controls.Add(`$label)
        `$yPosition += 35
    }
}

# Current position tracking
`$script:currentPositionMs = $InitialPositionMs
`$script:lastUpdate = [DateTime]::UtcNow
`$script:lastApiSync = [DateTime]::UtcNow
`$script:currentHighlightedLabel = `$null

# Function to get playback position
function Get-PlaybackPosition {
    try {
        `$playback = Invoke-SpotifyApi -Method GET -Path '/me/player' -ErrorAction SilentlyContinue
        if (`$playback -and `$playback.progress_ms) {
            return `$playback.progress_ms
        }
    } catch {
        # Ignore errors
    }
    return `$null
}

# Function to update highlighted line
function Update-HighlightedLine {
    param([int]`$positionMs)

    if (-not `$lyricsData.HasSyncedLyrics -or `$lineLabels.Count -eq 0) {
        return
    }

    # Find current line index
    `$currentIndex = -1
    for (`$i = `$lineLabels.Count - 1; `$i -ge 0; `$i--) {
        if (`$lineLabels[`$i].Tag -le `$positionMs) {
            `$currentIndex = `$i
            break
        }
    }

    `$currentLabel = if (`$currentIndex -ge 0) { `$lineLabels[`$currentIndex] } else { `$null }

    # Update highlighting if changed
    if (`$currentLabel -ne `$script:currentHighlightedLabel) {
        # Update all lines with three-state coloring
        for (`$i = 0; `$i -lt `$lineLabels.Count; `$i++) {
            if (`$i -lt `$currentIndex) {
                # Already sung - dark gray
                `$lineLabels[`$i].ForeColor = [System.Drawing.Color]::DarkGray
                `$lineLabels[`$i].Font = New-Object System.Drawing.Font('Segoe UI', 11)
            } elseif (`$i -eq `$currentIndex) {
                # Current line - bright green + bold
                `$lineLabels[`$i].ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#67cd4e')
                `$lineLabels[`$i].Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
            } else {
                # Upcoming - white
                `$lineLabels[`$i].ForeColor = [System.Drawing.Color]::White
                `$lineLabels[`$i].Font = New-Object System.Drawing.Font('Segoe UI', 11)
            }
        }

        # Auto-scroll to keep current line visible
        if (`$currentLabel -ne `$null) {
            `$lyricsPanel.AutoScrollPosition = New-Object System.Drawing.Point(0, `$currentLabel.Top - 200)
        }

        `$script:currentHighlightedLabel = `$currentLabel
    }
}

# Timer for updates
`$timer = New-Object System.Windows.Forms.Timer
`$timer.Interval = 100  # Update every 100ms

`$timer.Add_Tick({
    try {
        # Update playback position
        `$now = [DateTime]::UtcNow
        `$elapsed = (`$now - `$script:lastUpdate).TotalMilliseconds
        `$script:currentPositionMs += [int]`$elapsed
        `$script:lastUpdate = `$now

        # Sync with API every 5 seconds
        `$timeSinceApiSync = (`$now - `$script:lastApiSync).TotalMilliseconds
        if (`$timeSinceApiSync -ge 5000) {
            `$apiPosition = Get-PlaybackPosition
            if (`$apiPosition -ne `$null) {
                `$script:currentPositionMs = `$apiPosition
                `$script:lastApiSync = `$now
            }
        }

        # Update highlighted line
        Update-HighlightedLine -positionMs `$script:currentPositionMs

    } catch {
        # Silently ignore errors
    }
}.GetNewClosure())

# Start timer
`$timer.Start()

# Form closing cleanup
`$form.Add_FormClosing({
    `$timer.Stop()
    `$timer.Dispose()
})

# Clean up script file on exit
`$form.Add_FormClosed({
    Remove-Item '$scriptFile' -Force -ErrorAction SilentlyContinue
})

# Show form
[void]`$form.ShowDialog()
"@

    # Save script to temp file
    $scriptFile = Join-Path $tempDir "lyrics_display_$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
    $backgroundScript | Out-File -FilePath $scriptFile -Encoding UTF8

    # Start background process
    Start-Process pwsh -ArgumentList @(
        '-NoProfile',
        '-WindowStyle', 'Hidden',
        '-ExecutionPolicy', 'Bypass',
        '-File', $scriptFile
    )

    Write-Host "🎤 Lyrics window launched!" -ForegroundColor Green
    Write-Host "💡 Close the lyrics window when done" -ForegroundColor Cyan
}

Export-ModuleMember -Function @('Show-LyricsForm')
