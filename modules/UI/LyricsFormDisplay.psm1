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
    synchronized to the currently playing track. Automatically detects track
    changes and loads new lyrics. Pauses when Spotify is paused.

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
Import-Module '$rootPath\modules\Lyrics\LyricsEngine.psm1' -Force -ErrorAction SilentlyContinue

# Load lyrics data from temp file
`$script:lyricsData = Get-Content '$dataFile' -Raw | ConvertFrom-Json -AsHashtable

# Clean up temp file after loading
Remove-Item '$dataFile' -Force -ErrorAction SilentlyContinue

# Create lyrics manager for track changes
`$lyricsConfig = @{
    DataDirectory = Join-Path `$env:APPDATA "SpotifyCLI\Lyrics"
    CacheEnabled = `$true
    CacheTtlDays = 30
}
if (`$env:GENIUS_ACCESS_TOKEN) { `$lyricsConfig.GeniusApiKey = `$env:GENIUS_ACCESS_TOKEN }
if (`$env:MUSIXMATCH_API_KEY) { `$lyricsConfig.MusixmatchApiKey = `$env:MUSIXMATCH_API_KEY }
`$script:lyricsManager = New-LyricsManager -Configuration `$lyricsConfig

# Track info
`$artist = if (`$script:lyricsData.TrackId) { `$script:lyricsData.TrackId.Split('-')[0] } else { "Unknown" }
`$track = if (`$script:lyricsData.TrackId) { (`$script:lyricsData.TrackId.Split('-', 2)[1]) } else { "Unknown" }
`$source = `$script:lyricsData.Source

# Create form
`$form = New-Object System.Windows.Forms.Form
`$form.Text = "Lyrics - `$artist - `$track"
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
`$headerLabel.Text = "`$artist`n`$track`nSource: `$source"
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

# Invisible anchor label at the bottom for look-ahead scrolling
`$script:scrollAnchor = New-Object System.Windows.Forms.Label
`$script:scrollAnchor.Size = New-Object System.Drawing.Size(1, 1)
`$script:scrollAnchor.Text = ""
`$lyricsPanel.Controls.Add(`$script:scrollAnchor)

# Create labels for each line
`$script:lineLabels = @()
`$yPosition = 10

if (`$script:lyricsData.HasSyncedLyrics -and `$script:lyricsData.SyncedLines) {
    foreach (`$line in `$script:lyricsData.SyncedLines) {
        `$label = New-Object System.Windows.Forms.Label
        `$label.Location = New-Object System.Drawing.Point(10, `$yPosition)
        `$label.Size = New-Object System.Drawing.Size(520, 30)
        `$label.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        `$label.ForeColor = [System.Drawing.Color]::White
        `$label.Text = `$line.Text
        `$label.Tag = `$line.Timestamp
        `$label.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
        `$label.AutoSize = `$false
        `$lyricsPanel.Controls.Add(`$label)
        `$script:lineLabels += `$label
        `$yPosition += 35
    }
} else {
    `$textLines = `$script:lyricsData.FullText -split "`n"
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

# State tracking
`$script:currentPositionMs = $InitialPositionMs
`$script:lastUpdate = [DateTime]::UtcNow
`$script:lastApiSync = [DateTime]::UtcNow
`$script:currentHighlightedLabel = `$null
`$script:currentTrackUri = `$null
`$script:isUpdatingTrack = `$false
`$script:isPlaying = `$true

# Get initial track state
try {
    `$initPlayback = Invoke-SpotifyApi -Method GET -Path '/me/player' -ErrorAction SilentlyContinue
    if (`$initPlayback) {
        if (`$initPlayback.item) { `$script:currentTrackUri = `$initPlayback.item.uri }
        if (`$initPlayback.PSObject.Properties.Name -contains 'is_playing') {
            `$script:isPlaying = `$initPlayback.is_playing
        }
    }
} catch { }

# Function to rebuild lyrics labels when track changes
function Rebuild-LyricsLabels {
    param([hashtable]`$NewLyricsData, [int]`$ProgressMs)

    `$script:isUpdatingTrack = `$true
    `$script:lyricsData = `$NewLyricsData

    `$lyricsPanel.SuspendLayout()
    # Remove old line labels but keep the scroll anchor
    foreach (`$lbl in `$script:lineLabels) {
        `$lyricsPanel.Controls.Remove(`$lbl)
        `$lbl.Dispose()
    }
    `$script:lineLabels = @()
    `$yPos = 10

    if (`$NewLyricsData.HasSyncedLyrics -and `$NewLyricsData.SyncedLines) {
        foreach (`$sl in `$NewLyricsData.SyncedLines) {
            `$lbl = New-Object System.Windows.Forms.Label
            `$lbl.Location = New-Object System.Drawing.Point(10, `$yPos)
            `$lbl.Size = New-Object System.Drawing.Size(520, 30)
            `$lbl.Font = New-Object System.Drawing.Font('Segoe UI', 11)
            `$lbl.ForeColor = [System.Drawing.Color]::White
            `$lbl.Text = `$sl.Text
            `$lbl.Tag = `$sl.Timestamp
            `$lbl.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
            `$lbl.AutoSize = `$false
            `$lyricsPanel.Controls.Add(`$lbl)
            `$script:lineLabels += `$lbl
            `$yPos += 35
        }
    } else {
        `$textLines = if (`$NewLyricsData.FullText) { `$NewLyricsData.FullText -split "`n" } else { @("No lyrics found") }
        foreach (`$tl in `$textLines) {
            `$lbl = New-Object System.Windows.Forms.Label
            `$lbl.Location = New-Object System.Drawing.Point(10, `$yPos)
            `$lbl.Size = New-Object System.Drawing.Size(520, 30)
            `$lbl.Font = New-Object System.Drawing.Font('Segoe UI', 11)
            `$lbl.ForeColor = [System.Drawing.Color]::White
            `$lbl.Text = `$tl
            `$lbl.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
            `$lbl.AutoSize = `$false
            `$lyricsPanel.Controls.Add(`$lbl)
            `$yPos += 35
        }
    }

    # Move scroll anchor to end of content
    `$script:scrollAnchor.Location = New-Object System.Drawing.Point(0, `$yPos)
    `$lyricsPanel.ResumeLayout(`$true)

    # Scroll to top
    if (`$script:lineLabels.Count -gt 0) {
        `$lyricsPanel.ScrollControlIntoView(`$script:lineLabels[0])
    }

    `$script:currentHighlightedLabel = `$null
    `$script:currentPositionMs = `$ProgressMs
    `$script:isUpdatingTrack = `$false
}

# Function to update highlighted line
function Update-HighlightedLine {
    param([int]`$positionMs)

    if (`$script:isUpdatingTrack) { return }
    if (-not `$script:lyricsData.HasSyncedLyrics -or `$script:lineLabels.Count -eq 0) {
        return
    }

    # Find current line index
    `$currentIndex = -1
    for (`$i = `$script:lineLabels.Count - 1; `$i -ge 0; `$i--) {
        if (`$script:lineLabels[`$i].Tag -le `$positionMs) {
            `$currentIndex = `$i
            break
        }
    }

    `$currentLabel = if (`$currentIndex -ge 0) { `$script:lineLabels[`$currentIndex] } else { `$null }

    # Update highlighting if changed
    if (`$currentLabel -ne `$script:currentHighlightedLabel) {
        for (`$i = 0; `$i -lt `$script:lineLabels.Count; `$i++) {
            if (`$i -lt `$currentIndex) {
                `$script:lineLabels[`$i].ForeColor = [System.Drawing.Color]::DarkGray
                `$script:lineLabels[`$i].Font = New-Object System.Drawing.Font('Segoe UI', 11)
            } elseif (`$i -eq `$currentIndex) {
                `$script:lineLabels[`$i].ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#67cd4e')
                `$script:lineLabels[`$i].Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
            } else {
                `$script:lineLabels[`$i].ForeColor = [System.Drawing.Color]::White
                `$script:lineLabels[`$i].Font = New-Object System.Drawing.Font('Segoe UI', 11)
            }
        }

        # Scroll: make a label a few lines ahead visible so current line stays in upper area
        if (`$currentIndex -ge 0) {
            `$linesVisible = [Math]::Max(1, [int](`$lyricsPanel.ClientSize.Height / 35))
            `$lookAheadIndex = [Math]::Min(`$script:lineLabels.Count - 1, `$currentIndex + `$linesVisible - 3)
            `$lookAheadIndex = [Math]::Max(`$lookAheadIndex, `$currentIndex)
            `$lyricsPanel.ScrollControlIntoView(`$script:lineLabels[`$lookAheadIndex])
        }

        `$script:currentHighlightedLabel = `$currentLabel
    }
}

# Timer for updates
`$timer = New-Object System.Windows.Forms.Timer
`$timer.Interval = 100

`$timer.Add_Tick({
    try {
        `$now = [DateTime]::UtcNow

        # Only advance position if playing
        if (`$script:isPlaying) {
            `$elapsed = (`$now - `$script:lastUpdate).TotalMilliseconds
            `$script:currentPositionMs += [int]`$elapsed
        }
        `$script:lastUpdate = `$now

        # Sync with API every 5 seconds
        `$timeSinceApiSync = (`$now - `$script:lastApiSync).TotalMilliseconds
        if (`$timeSinceApiSync -ge 5000) {
            try {
                `$playback = Invoke-SpotifyApi -Method GET -Path '/me/player' -ErrorAction SilentlyContinue
                if (`$playback) {
                    # Update play/pause state
                    if (`$playback.PSObject.Properties.Name -contains 'is_playing') {
                        `$script:isPlaying = `$playback.is_playing
                    }

                    if (`$playback.progress_ms) {
                        `$script:currentPositionMs = `$playback.progress_ms
                    }
                    `$script:lastApiSync = `$now

                    # Detect track change
                    if (`$playback.item -and `$playback.item.uri -ne `$script:currentTrackUri) {
                        `$script:currentTrackUri = `$playback.item.uri
                        `$newArtist = (`$playback.item.artists | ForEach-Object { `$_.name }) -join ", "
                        `$newTrack = `$playback.item.name

                        # Update header
                        `$headerLabel.Text = "`$newArtist`n`$newTrack"
                        `$form.Text = "Lyrics - `$newArtist - `$newTrack"

                        # Fetch new lyrics
                        `$newResult = `$script:lyricsManager.GetLyrics(`$newArtist, `$newTrack)
                        if (`$newResult.Success) {
                            `$newLyricsData = `$newResult
                            `$headerLabel.Text = "`$newArtist`n`$newTrack`nSource: `$(`$newResult.Source)"
                        } else {
                            `$newLyricsData = @{
                                Success = `$true
                                HasSyncedLyrics = `$false
                                FullText = "No lyrics found for `$newArtist - `$newTrack"
                            }
                            `$headerLabel.Text = "`$newArtist`n`$newTrack`nNo lyrics found"
                        }
                        Rebuild-LyricsLabels -NewLyricsData `$newLyricsData -ProgressMs ([int]`$playback.progress_ms)
                    }
                }
            } catch {
                # Ignore API errors
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

    Write-Host "Lyrics window launched!" -ForegroundColor Green
    Write-Host "Lyrics update automatically when song changes" -ForegroundColor Cyan
}

Export-ModuleMember -Function @('Show-LyricsForm')
