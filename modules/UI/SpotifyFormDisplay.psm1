# Spotify Windows Form Display Module
# Shows current track, artist, time, and next track in a Windows Form

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-SpotifyForm {
    <#
    .SYNOPSIS
    Display current Spotify playback in a Windows Form

    .DESCRIPTION
    Shows a modern Windows Form with current track information that updates in real-time

    .PARAMETER Block
    Block terminal until window is closed (default: runs in background)

    .EXAMPLE
    Show-SpotifyForm

    .EXAMPLE
    Show-SpotifyForm -Block

    .EXAMPLE
    ss
    Quick alias to show Spotify form
    #>

    param(
        [switch]$Block
    )

    # If Block is NOT specified (default), launch in a new PowerShell window
    if (-not $Block) {
        $modulePath = $PSScriptRoot
        $mainModulePath = Split-Path (Split-Path $modulePath -Parent) -Parent
        $mainModulePath = Join-Path $mainModulePath "SpotifyModule.psm1"

        # Get current environment variables for Spotify credentials
        $clientId = $env:SPOTIFY_CLIENT_ID
        $clientSecret = $env:SPOTIFY_CLIENT_SECRET

        $scriptBlock = @"
`$ErrorActionPreference = 'Continue'
`$env:SPOTIFY_CLIENT_ID = '$clientId'
`$env:SPOTIFY_CLIENT_SECRET = '$clientSecret'
try {
    Import-Module '$mainModulePath' -Force
    Show-SpotifyForm -Block
} catch {
    Write-Host 'Error loading Spotify module' -ForegroundColor Red
    Read-Host 'Press Enter to close'
}
"@

        Start-Process pwsh -ArgumentList "-NoProfile", "-WindowStyle", "Hidden", "-Command", $scriptBlock
        Write-Host "✅ Spotify display opened in background! The window will appear shortly." -ForegroundColor Green
        return
    }

    # --- CREATE FORM ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Spotify - Now Playing"
    $form.Size = New-Object System.Drawing.Size(450, 260)
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true
    $form.FormBorderStyle = "FixedToolWindow"
    $form.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#191414") # Spotify Dark

    # Force absolute topmost using Win32 API
    Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class WindowHelper {
            [DllImport("user32.dll")]
            public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
            public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
            public const uint SWP_NOMOVE = 0x0002;
            public const uint SWP_NOSIZE = 0x0001;
            public const uint SWP_SHOWWINDOW = 0x0040;
        }
"@ -ErrorAction SilentlyContinue

    # --- LAYOUT (Labels) ---

    # Song Title (Spotify Green) - Using Segoe UI Emoji for emoji support
    $lblSong = New-Object System.Windows.Forms.Label
    $lblSong.Location = New-Object System.Drawing.Point(15, 10)
    $lblSong.Size = New-Object System.Drawing.Size(360, 40)
    try {
        $lblSong.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 14, [System.Drawing.FontStyle]::Bold)
    } catch {
        $lblSong.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    }
    $lblSong.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#1DB954") # Spotify Green
    $lblSong.Text = "Loading..."
    $form.Controls.Add($lblSong)

    # Artist (Yellow)
    $lblArtist = New-Object System.Windows.Forms.Label
    $lblArtist.Location = New-Object System.Drawing.Point(15, 50)
    $lblArtist.Size = New-Object System.Drawing.Size(360, 25)
    try {
        $lblArtist.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 11, [System.Drawing.FontStyle]::Regular)
    } catch {
        $lblArtist.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
    }
    $lblArtist.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFD700") # Gold/Yellow
    $lblArtist.Text = ""
    $form.Controls.Add($lblArtist)

    # Album (Blue)
    $lblAlbum = New-Object System.Windows.Forms.Label
    $lblAlbum.Location = New-Object System.Drawing.Point(15, 75)
    $lblAlbum.Size = New-Object System.Drawing.Size(360, 20)
    try {
        $lblAlbum.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 9, [System.Drawing.FontStyle]::Italic)
    } catch {
        $lblAlbum.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    }
    $lblAlbum.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#64B5F6") # Light Blue
    $lblAlbum.Text = ""
    $form.Controls.Add($lblAlbum)

    # Time (Light Gray - Monospace)
    $lblTime = New-Object System.Windows.Forms.Label
    $lblTime.Location = New-Object System.Drawing.Point(15, 100)
    $lblTime.Size = New-Object System.Drawing.Size(360, 20)
    $lblTime.Font = New-Object System.Drawing.Font("Consolas", 10)
    $lblTime.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#B3B3B3")
    $lblTime.Text = "00:00 / 00:00"
    $form.Controls.Add($lblTime)

    # Progress Bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(15, 125)
    $progressBar.Size = New-Object System.Drawing.Size(360, 8)
    $progressBar.Style = "Continuous"
    $progressBar.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#1DB954")
    $form.Controls.Add($progressBar)

    # Next Track (Pink)
    $lblNext = New-Object System.Windows.Forms.Label
    $lblNext.Location = New-Object System.Drawing.Point(15, 140)
    $lblNext.Size = New-Object System.Drawing.Size(360, 20)
    try {
        $lblNext.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 9, [System.Drawing.FontStyle]::Italic)
    } catch {
        $lblNext.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    }
    $lblNext.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FF69B4") # Hot Pink
    $lblNext.Text = "Up Next: ..."
    $form.Controls.Add($lblNext)

    # --- CONTROL BUTTONS ---
    $buttonY = 170
    $buttonWidth = 75
    $buttonHeight = 30
    $buttonSpacing = 8

    # Previous Button
    $btnPrevious = New-Object System.Windows.Forms.Button
    $btnPrevious.Location = New-Object System.Drawing.Point(15, $buttonY)
    $btnPrevious.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
    $btnPrevious.Text = "Prev"
    $btnPrevious.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#282828")
    $btnPrevious.ForeColor = "White"
    $btnPrevious.FlatStyle = "Flat"
    $btnPrevious.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml("#404040")
    $btnPrevious.Tag = "previous"
    $form.Controls.Add($btnPrevious)

    # Play/Pause Button
    $btnPlayPause = New-Object System.Windows.Forms.Button
    $btnPlayPause.Location = New-Object System.Drawing.Point((15 + $buttonWidth + $buttonSpacing), $buttonY)
    $btnPlayPause.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
    $btnPlayPause.Text = "Pause"
    $btnPlayPause.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1DB954")
    $btnPlayPause.ForeColor = "White"
    $btnPlayPause.FlatStyle = "Flat"
    $btnPlayPause.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml("#1DB954")
    $btnPlayPause.Tag = "playpause"
    $form.Controls.Add($btnPlayPause)

    # Next Button
    $btnNext = New-Object System.Windows.Forms.Button
    $btnNext.Location = New-Object System.Drawing.Point((15 + ($buttonWidth + $buttonSpacing) * 2), $buttonY)
    $btnNext.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
    $btnNext.Text = "Next"
    $btnNext.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#282828")
    $btnNext.ForeColor = "White"
    $btnNext.FlatStyle = "Flat"
    $btnNext.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml("#404040")
    $btnNext.Tag = "next"
    $form.Controls.Add($btnNext)

    # Shuffle Button
    $btnShuffle = New-Object System.Windows.Forms.Button
    $btnShuffle.Location = New-Object System.Drawing.Point((15 + ($buttonWidth + $buttonSpacing) * 3), $buttonY)
    $btnShuffle.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
    $btnShuffle.Text = "Shuffle"
    $btnShuffle.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#282828")
    $btnShuffle.ForeColor = "White"
    $btnShuffle.FlatStyle = "Flat"
    $btnShuffle.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml("#404040")
    $btnShuffle.Tag = "shuffle"
    $form.Controls.Add($btnShuffle)

    # Repeat Button
    $btnRepeat = New-Object System.Windows.Forms.Button
    $btnRepeat.Location = New-Object System.Drawing.Point((15 + ($buttonWidth + $buttonSpacing) * 4), $buttonY)
    $btnRepeat.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
    $btnRepeat.Text = "Repeat"
    $btnRepeat.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#282828")
    $btnRepeat.ForeColor = "White"
    $btnRepeat.FlatStyle = "Flat"
    $btnRepeat.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml("#404040")
    $btnRepeat.Tag = "repeat"
    $form.Controls.Add($btnRepeat)

    # Add click handlers
    $btnPrevious.Add_Click({
        try {
            Invoke-SpotifyApi -Method POST -Path "/me/player/previous" | Out-Null
        } catch { }
    })

    $btnPlayPause.Add_Click({
        try {
            $currentState = Invoke-SpotifyApi -Method GET -Path "/me/player"
            if ($currentState -and $currentState.is_playing) {
                Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
            } else {
                Invoke-SpotifyApi -Method PUT -Path "/me/player/play" | Out-Null
            }
        } catch { }
    })

    $btnNext.Add_Click({
        try {
            Invoke-SpotifyApi -Method POST -Path "/me/player/next" | Out-Null
        } catch { }
    })

    $btnShuffle.Add_Click({
        try {
            $currentState = Invoke-SpotifyApi -Method GET -Path "/me/player"
            $newState = -not $currentState.shuffle_state
            Invoke-SpotifyApi -Method PUT -Path "/me/player/shuffle?state=$newState" | Out-Null
            # Update button immediately
            if ($newState) {
                $btnShuffle.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1DB954")
            } else {
                $btnShuffle.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#282828")
            }
            # Update "Up Next" after short delay (queue changes when shuffle toggles)
            Start-Sleep -Milliseconds 300
            try {
                $queue = Invoke-SpotifyApi -Method GET -Path "/me/player/queue"
                if ($queue -and $queue.queue -and $queue.queue.Count -gt 0) {
                    $nextTrack = $queue.queue[0]
                    if ($nextTrack.type -eq "episode") {
                        $lblNext.Text = "Up Next: " + $nextTrack.name
                    } else {
                        $nextArtists = ($nextTrack.artists | ForEach-Object { $_.name }) -join ", "
                        $lblNext.Text = "Up Next: " + $nextTrack.name + " - " + $nextArtists
                    }
                }
            } catch {
                $lblNext.Text = "Up Next: ..."
            }
        } catch { }
    })

    $btnRepeat.Add_Click({
        try {
            $currentState = Invoke-SpotifyApi -Method GET -Path "/me/player"
            $newState = if ($currentState.repeat_state -eq "off") { "context" } else { "off" }
            Invoke-SpotifyApi -Method PUT -Path "/me/player/repeat?state=$newState" | Out-Null
            # Update button immediately
            if ($newState -ne "off") {
                $btnRepeat.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1DB954")
                $btnRepeat.Text = "Repeat"
            } else {
                $btnRepeat.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#282828")
                $btnRepeat.Text = "Repeat"
            }
        } catch { }
    })

    # Event to force absolute topmost when form is shown
    $form.Add_Shown({
        try {
            [WindowHelper]::SetWindowPos(
                $form.Handle,
                [WindowHelper]::HWND_TOPMOST,
                0, 0, 0, 0,
                [WindowHelper]::SWP_NOMOVE -bor [WindowHelper]::SWP_NOSIZE -bor [WindowHelper]::SWP_SHOWWINDOW
            ) | Out-Null
        } catch {
            Write-Verbose "Could not set absolute topmost: $($_.Exception.Message)"
        }
    })

    # --- UPDATE TIMER ---
    $script:lastTrackId = ""
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000 # Update every second

    # Create scriptblock with closure to capture module scope
    $updateScriptBlock = {
        try {
            # Get current playback
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"

            if ($currentTrack -and $currentTrack.item) {
                $item = $currentTrack.item
                $progress = if ($currentTrack.progress_ms) { $currentTrack.progress_ms } else { 0 }
                $duration = $item.duration_ms
                $isPlaying = $currentTrack.is_playing

                # Update song if changed
                if ($item.id -ne $script:lastTrackId) {
                    $script:lastTrackId = $item.id

                    if ($currentTrack.currently_playing_type -eq "episode") {
                        # Podcast
                        $songText = "🎙️ " + $item.name
                        $lblSong.Text = $songText
                        # Adjust song font size
                        $songSize = if ($songText.Length -gt 45) { 9 } elseif ($songText.Length -gt 30) { 12 } else { 14 }
                        try {
                            $lblSong.Font = New-Object System.Drawing.Font("Segoe UI Emoji", $songSize, [System.Drawing.FontStyle]::Bold)
                        } catch {
                            $lblSong.Font = New-Object System.Drawing.Font("Segoe UI", $songSize, [System.Drawing.FontStyle]::Bold)
                        }

                        $artistText = "👤 " + $item.show.name
                        $lblArtist.Text = $artistText
                        # Adjust artist font size
                        $artistSize = if ($artistText.Length -gt 50) { 8 } elseif ($artistText.Length -gt 35) { 9 } else { 11 }
                        try {
                            $lblArtist.Font = New-Object System.Drawing.Font("Segoe UI Emoji", $artistSize, [System.Drawing.FontStyle]::Regular)
                        } catch {
                            $lblArtist.Font = New-Object System.Drawing.Font("Segoe UI", $artistSize, [System.Drawing.FontStyle]::Regular)
                        }

                        $lblAlbum.Text = "📻 Podcast Episode"
                    } else {
                        # Music
                        $songText = "🎵 " + $item.name
                        $lblSong.Text = $songText
                        # Adjust song font size
                        $songSize = if ($songText.Length -gt 45) { 9 } elseif ($songText.Length -gt 30) { 12 } else { 14 }
                        try {
                            $lblSong.Font = New-Object System.Drawing.Font("Segoe UI Emoji", $songSize, [System.Drawing.FontStyle]::Bold)
                        } catch {
                            $lblSong.Font = New-Object System.Drawing.Font("Segoe UI", $songSize, [System.Drawing.FontStyle]::Bold)
                        }

                        $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                        $artistText = "👤 " + $artists
                        $lblArtist.Text = $artistText
                        # Adjust artist font size
                        $artistSize = if ($artistText.Length -gt 50) { 8 } elseif ($artistText.Length -gt 35) { 9 } else { 11 }
                        try {
                            $lblArtist.Font = New-Object System.Drawing.Font("Segoe UI Emoji", $artistSize, [System.Drawing.FontStyle]::Regular)
                        } catch {
                            $lblArtist.Font = New-Object System.Drawing.Font("Segoe UI", $artistSize, [System.Drawing.FontStyle]::Regular)
                        }

                        $albumText = "📀 " + $item.album.name
                        $lblAlbum.Text = $albumText
                        # Adjust album font size
                        if ($albumText.Length -gt 50) {
                            try {
                                $lblAlbum.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 7, [System.Drawing.FontStyle]::Italic)
                            } catch {
                                $lblAlbum.Font = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Italic)
                            }
                        } else {
                            try {
                                $lblAlbum.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 9, [System.Drawing.FontStyle]::Italic)
                            } catch {
                                $lblAlbum.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
                            }
                        }
                    }

                    # Get next track from queue
                    try {
                        $queue = Invoke-SpotifyApi -Method GET -Path "/me/player/queue"
                        if ($queue -and $queue.queue -and $queue.queue.Count -gt 0) {
                            $nextTrack = $queue.queue[0]
                            if ($nextTrack.type -eq "episode") {
                                $lblNext.Text = "Up Next: " + $nextTrack.name
                            } else {
                                $nextArtists = ($nextTrack.artists | ForEach-Object { $_.name }) -join ", "
                                $lblNext.Text = "Up Next: " + $nextTrack.name + " - " + $nextArtists
                            }
                        } else {
                            $lblNext.Text = "Up Next: End of queue"
                        }
                    } catch {
                        $lblNext.Text = "Up Next: ..."
                    }
                }

                # Update time and progress
                $currentMin = [int][Math]::Floor($progress / 60000)
                $currentSec = [int][Math]::Floor(($progress % 60000) / 1000)
                $totalMin = [int][Math]::Floor($duration / 60000)
                $totalSec = [int][Math]::Floor(($duration % 60000) / 1000)

                $currentTime = "{0}:{1:D2}" -f $currentMin, $currentSec
                $totalTime = "{0}:{1:D2}" -f $totalMin, $totalSec

                $statusIcon = if ($isPlaying) { "▶️" } else { "⏸️" }
                $lblTime.Text = "$statusIcon $currentTime / $totalTime"

                # Update progress bar
                if ($duration -gt 0) {
                    $percentage = [Math]::Min(100, [Math]::Floor(($progress / $duration) * 100))
                    $progressBar.Value = $percentage
                }

                # Update Play/Pause button text
                if ($isPlaying) {
                    $btnPlayPause.Text = "Pause"
                } else {
                    $btnPlayPause.Text = "Play"
                }

                # Update Shuffle/Repeat button states
                try {
                    $playerState = Invoke-SpotifyApi -Method GET -Path "/me/player"
                    if ($playerState) {
                        # Update shuffle button
                        if ($playerState.shuffle_state) {
                            $btnShuffle.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1DB954")
                        } else {
                            $btnShuffle.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#282828")
                        }

                        # Update repeat button
                        if ($playerState.repeat_state -ne "off") {
                            $btnRepeat.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1DB954")
                            $btnRepeat.Text = if ($playerState.repeat_state -eq "track") { "Repeat 1" } else { "Repeat" }
                        } else {
                            $btnRepeat.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#282828")
                            $btnRepeat.Text = "Repeat"
                        }
                    }
                } catch {
                    # Ignore state update errors
                }
            } else {
                # Nothing playing
                $lblSong.Text = "No track playing"
                $lblArtist.Text = "Open Spotify and start playing"
                $lblAlbum.Text = ""
                $lblTime.Text = "Paused"
                $lblNext.Text = ""
                $progressBar.Value = 0
                $btnPlayPause.Text = "Play"
                $script:lastTrackId = ""
            }
        } catch {
            # Error occurred
            $lblSong.Text = "Error loading track"
            $lblArtist.Text = $_.Exception.Message
            $lblAlbum.Text = ""
            $lblTime.Text = ""
            $lblNext.Text = ""
            Write-Verbose "Error updating form: $($_.Exception.Message)"
        }

        # Force window to stay absolutely on top
        try {
            [WindowHelper]::SetWindowPos(
                $form.Handle,
                [WindowHelper]::HWND_TOPMOST,
                0, 0, 0, 0,
                [WindowHelper]::SWP_NOMOVE -bor [WindowHelper]::SWP_NOSIZE
            ) | Out-Null
        } catch {
            # Silently ignore if it fails
        }
    }.GetNewClosure()

    $timer.Add_Tick($updateScriptBlock)

    # Initial update
    $timer.Start()

    # Cleanup on close
    $form.Add_FormClosing({
        $timer.Stop()
        $timer.Dispose()
    })

    # Show form - this will block until window is closed
    # Using ShowDialog for proper event handling
    Write-Host "🎵 Opening Spotify display..." -ForegroundColor Cyan
    Write-Host "ℹ️  The window will update every second. Close it to return to terminal." -ForegroundColor Yellow

    $form.ShowDialog() | Out-Null

    Write-Host "✅ Spotify display closed." -ForegroundColor Green
}

# Create alias
Set-Alias -Name ShowSpotify -Value Show-SpotifyForm -ErrorAction SilentlyContinue
Set-Alias -Name ss -Value Show-SpotifyForm -ErrorAction SilentlyContinue

Export-ModuleMember -Function Show-SpotifyForm -Alias ShowSpotify, ss
