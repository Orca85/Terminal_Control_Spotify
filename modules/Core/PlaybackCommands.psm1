# PlaybackCommands Module
# Contains all core functions for controlling Spotify playback.

# --- Notification Helper ---
function Show-TrackNotification {
    <#
    .SYNOPSIS
    Shows a Windows toast notification for track changes
    #>
    param(
        [Parameter(ParameterSetName='TrackInfo')]
        $TrackInfo,

        [Parameter(ParameterSetName='Custom')]
        [string]$Title,

        [Parameter(ParameterSetName='Custom')]
        [string]$Message,

        [ValidateSet('play', 'pause', 'next', 'previous', '')]
        [string]$Action = ''
    )

    try {
        # Determine notification content
        if ($TrackInfo) {
            # Add action indicator
            $actionIcon = switch ($Action) {
                'play' { '▶️' }
                'pause' { '⏸️' }
                'next' { '⏭️' }
                'previous' { '⏮️' }
                default { '🎵' }
            }

            if ($TrackInfo.type -eq "episode") {
                $notifyTitle = "$actionIcon 🎙️ $($TrackInfo.name)"
                $notifyMessage = "📺 $($TrackInfo.show.name)"
                $appLogo = $TrackInfo.images[0].url
            } else {
                $artists = ($TrackInfo.artists | ForEach-Object { $_.name }) -join ", "
                $albumName = if ($TrackInfo.album) { $TrackInfo.album.name } else { "Unknown Album" }

                $notifyTitle = "$actionIcon 🎵 $($TrackInfo.name)"
                $notifyMessage = "💿 $albumName`n👤 $artists"
                $appLogo = if ($TrackInfo.album -and $TrackInfo.album.images) { $TrackInfo.album.images[0].url } else { $null }
            }
        } else {
            $notifyTitle = $Title
            $notifyMessage = $Message
            $appLogo = $null
        }

        # Try BurntToast first (best experience)
        if (Get-Module -ListAvailable -Name BurntToast) {
            Import-Module BurntToast -ErrorAction SilentlyContinue

            $toastParams = @{
                Text = $notifyTitle, $notifyMessage
                Silent = $true
            }

            # Add album art if available
            if ($appLogo) {
                $toastParams['AppLogo'] = $appLogo
            }

            New-BurntToastNotification @toastParams
        }
        else {
            # Fallback: Use Windows balloon tip via .NET
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

            if ([System.Windows.Forms.SystemInformation]::TerminalServerSession -eq $false) {
                $balloon = New-Object System.Windows.Forms.NotifyIcon
                $balloon.Icon = [System.Drawing.SystemIcons]::Information
                $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
                $balloon.BalloonTipTitle = $notifyTitle
                $balloon.BalloonTipText = $notifyMessage
                $balloon.Visible = $true
                $balloon.ShowBalloonTip(3000)

                # Clean up after a delay
                Start-Sleep -Milliseconds 3500
                $balloon.Dispose()
            }
        }
    }
    catch {
        # Silently fail - notifications are optional
        Write-Verbose "Notification failed: $($_.Exception.Message)"
    }
}

function play {
    param([string]$TrackReference)

    # Path 2: Play a specific track/episode
    if (-not [string]::IsNullOrWhiteSpace($TrackReference)) {
        $trackUri = $TrackReference
        # Check if it's a number (track/episode index from search)
        if ($TrackReference -match '^\d+$') {
            $itemIndex = [int]$TrackReference - 1
            $sessionTracks = Get-SessionTracks
            if ($sessionTracks -and $itemIndex -ge 0 -and $itemIndex -lt $sessionTracks.Count) {
                $item = $sessionTracks[$itemIndex]
                $trackUri = $item.uri
                $itemName = $item.name
                if ($item.search_type -eq "episode" -or $item.type -eq "episode") {
                    $showName = $item.show.name
                    Write-Host "🎯 Playing podcast episode #$TrackReference ($itemName from $showName)..." -ForegroundColor Magenta
                } else {
                    $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                    Write-Host "🎯 Playing track #$TrackReference ($itemName by $artists)..." -ForegroundColor Cyan
                }
            } else {
                Write-Host "❌ Invalid item number. Use 'search' to find tracks and episodes first." -ForegroundColor Red
                return
            }
        }

        # Ensure it's a valid Spotify URI
        if (-not ($trackUri.StartsWith("spotify:track:") -or $trackUri.StartsWith("spotify:episode:"))) {
            Write-Host "❌ Invalid URI. Must be a Spotify track or episode URI." -ForegroundColor Red
            return
        }

        try {
            # Try to play on active device first
            $body = @{ uris = @($trackUri) }
            Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
            if ($trackUri.StartsWith("spotify:episode:")) {
                Write-Host "▶️ Playing podcast episode" -ForegroundColor Magenta
            } else {
                Write-Host "▶️ Playing track" -ForegroundColor Green
            }
            # Show notification
            Start-Sleep -Milliseconds 300
            try {
                $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
                if ($currentTrack -and $currentTrack.item) {
                    Show-TrackNotification -TrackInfo $currentTrack.item -Action 'play'
                }
            } catch { }
        }
        catch {
            # If no active device, try to activate one
            Write-Host "🎵 No active device. Looking for available devices..." -ForegroundColor Yellow
            try {
                $devicesResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/devices"
                if (-not $devicesResponse -or -not $devicesResponse.devices -or $devicesResponse.devices.Count -eq 0) {
                    Write-Host "❌ No available devices found. Please start Spotify on a device." -ForegroundColor Red
                    return
                }

                $firstDevice = $devicesResponse.devices[0]
                Write-Host "🔄 Activating device: $($firstDevice.name)..." -ForegroundColor Cyan
                $transferBody = @{ device_ids = @($firstDevice.id); play = $false }
                Invoke-SpotifyApi -Method PUT -Path "/me/player" -Body $transferBody | Out-Null
                Start-Sleep -Milliseconds 500

                # Try again to play
                $body = @{ uris = @($trackUri) }
                Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
                if ($trackUri.StartsWith("spotify:episode:")) {
                    Write-Host "▶️ Playing podcast episode" -ForegroundColor Magenta
                } else {
                    Write-Host "▶️ Playing track" -ForegroundColor Green
                }
                # Show notification
                Start-Sleep -Milliseconds 300
                try {
                    $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
                    if ($currentTrack -and $currentTrack.item) {
                        Show-TrackNotification -TrackInfo $currentTrack.item -Action 'play'
                    }
                } catch { }
            }
            catch {
                Write-Host "❌ Could not play track: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        return
    }

    # Path 1: Resume playback or play recent
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" | Out-Null
        Write-Host "▶️ Resumed playback" -ForegroundColor Green
        # Show notification with current track
        Start-Sleep -Milliseconds 300
        try {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            if ($currentTrack -and $currentTrack.item) {
                Show-TrackNotification -TrackInfo $currentTrack.item -Action 'play'
            }
        } catch { }
    }
    catch {
        # This is the expected error when nothing is active.
        # Now we try to be smart and play a recent track.
        Write-Host "🎵 No active playback found. Trying to start from your recent tracks..." -ForegroundColor Yellow
        try {
            $devicesResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/devices"
            if (-not $devicesResponse -or -not $devicesResponse.devices -or $devicesResponse.devices.Count -eq 0) {
                Write-Host "❌ No available devices found. Please start Spotify on a device." -ForegroundColor Red
                return
            }

            $activeDevice = $devicesResponse.devices | Where-Object { $_.is_active -eq $true } | Select-Object -First 1
            if (-not $activeDevice) {
                $firstDevice = $devicesResponse.devices[0]
                Write-Host "🔄 Activating device: $($firstDevice.name)..." -ForegroundColor Cyan
                $transferBody = @{ device_ids = @($firstDevice.id); play = $false }
                Invoke-SpotifyApi -Method PUT -Path "/me/player" -Body $transferBody | Out-Null
                Start-Sleep -Milliseconds 500
            }

            $recentTracks = Invoke-SpotifyApi -Method GET -Path "/me/player/recently-played" -Query @{ limit = 1 }
            if ($recentTracks -and $recentTracks.items -and $recentTracks.items.Count -gt 0) {
                $lastTrack = $recentTracks.items[0].track
                $body = @{ uris = @($lastTrack.uri) }
                Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
                Write-Host "▶️ Started playing: $($lastTrack.name) by $(($lastTrack.artists | ForEach-Object { $_.name }) -join ', ')" -ForegroundColor Green
            } else {
                Write-Host "❌ No recent tracks found to play." -ForegroundColor Red
            }
        }
        catch {
            Write-Host "❌ Could not start playback: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function pause {
    try {
        # Get current track BEFORE pausing for notification
        $currentTrack = $null
        try {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        } catch { }

        Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
        Write-Host "⏸️ Paused playback" -ForegroundColor Yellow

        # Show notification with track info
        if ($currentTrack -and $currentTrack.item) {
            Show-TrackNotification -TrackInfo $currentTrack.item -Action 'pause'
        }
    }
    catch {
        $errorMessage = $_.Exception.Message

        # Check error type based on message content
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not pause playback. Make sure Spotify is open and playing." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred: $errorMessage" -ForegroundColor Red
        }
    }
}

function next {
    try {
        Invoke-SpotifyApi -Method POST -Path "/me/player/next" | Out-Null
        Write-Host "⏭️ Skipped to next track" -ForegroundColor Green
        # Wait a moment for Spotify to update, then show current track
        Start-Sleep -Milliseconds 500
        try {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            if ($currentTrack -and $currentTrack.item) {
                $item = $currentTrack.item
                if ($item.type -eq "episode") {
                    Write-Host "🎙️ Now playing: $($item.name)" -ForegroundColor Magenta
                } else {
                    $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                    Write-Host "🎵 Now playing: $($item.name) by $artists" -ForegroundColor Cyan
                }
                # Show toast notification
                Show-TrackNotification -TrackInfo $item -Action 'next'
            }
        } catch {
            # Silently ignore if we can't get track info
        }
    }
    catch {
        $errorMessage = $_.Exception.Message

        # Check error type based on message content
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not skip to next track. Make sure Spotify is playing music." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred: $errorMessage" -ForegroundColor Red
        }
    }
}

function previous {
    try {
        Invoke-SpotifyApi -Method POST -Path "/me/player/previous" | Out-Null
        Write-Host "⏮️ Skipped to previous track" -ForegroundColor Green
        # Wait a moment for Spotify to update, then show current track
        Start-Sleep -Milliseconds 500
        try {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            if ($currentTrack -and $currentTrack.item) {
                $item = $currentTrack.item
                if ($item.type -eq "episode") {
                    Write-Host "🎙️ Now playing: $($item.name)" -ForegroundColor Magenta
                } else {
                    $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                    Write-Host "🎵 Now playing: $($item.name) by $artists" -ForegroundColor Cyan
                }
                # Show toast notification
                Show-TrackNotification -TrackInfo $item -Action 'previous'
            }
        } catch {
            # Silently ignore if we can't get track info
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not skip to previous track. Make sure Spotify is playing music." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred: $errorMessage" -ForegroundColor Red
        }
    }
}

function volume {
    <#
    .SYNOPSIS
    Control Spotify volume
    .PARAMETER Level
    Volume level (0-100)
    .EXAMPLE
    volume 75
    Set volume to 75%
    #>
    param([int]$Level)
    if ($Level -lt 0 -or $Level -gt 100) {
        Write-Host "❌ Volume must be between 0 and 100" -ForegroundColor Red
        return
    }
    try {
        $query = @{ volume_percent = $Level }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/volume" -Query $query | Out-Null
        Write-Host "🔊 Volume set to $Level%" -ForegroundColor Green
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not set volume. Make sure a device is active and supports volume control." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred: $errorMessage" -ForegroundColor Red
        }
    }
}

function seek {
    <#
    .SYNOPSIS
    Seek in current track or podcast episode
    .PARAMETER Seconds
    Seconds to seek (positive = forward, negative = backward)
    .EXAMPLE
    seek 30
    Seek forward 30 seconds
    .EXAMPLE
    seek -10
    Seek backward 10 seconds
    .EXAMPLE
    seek -30
    Seek backward 30 seconds (useful for podcast replay)
    #>
    param([int]$Seconds)
    try {
        $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        if (-not $currentTrack -or -not $currentTrack.item) {
            Write-Host "❌ No track or episode currently playing." -ForegroundColor Red
            return
        }

        $item = $currentTrack.item
        $isPodcast = $item.type -eq "episode" -or ($currentTrack.currently_playing_type -eq "episode")
        $currentPosition = $currentTrack.progress_ms
        $newPosition = $currentPosition + ($Seconds * 1000)
        $maxPosition = $item.duration_ms
        
        if ($newPosition -lt 0) { $newPosition = 0 }
        if ($newPosition -gt $maxPosition) { $newPosition = $maxPosition }

        $query = @{ position_ms = $newPosition }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/seek" -Query $query | Out-Null

        $direction = if ($Seconds -gt 0) { "forward" } else { "backward" }
        $absSeconds = [Math]::Abs($Seconds)
        if ($isPodcast) {
            Write-Host "⏩ Seeked $direction $absSeconds seconds in podcast episode" -ForegroundColor Magenta
            # Show current position for podcast episodes (more useful for long content)
            $currentTimeStr = Format-Time $newPosition
            $totalTimeStr = Format-Time $maxPosition
            Write-Host "📍 Position: $currentTimeStr / $totalTimeStr" -ForegroundColor Gray
        } else {
            Write-Host "⏩ Seeked $direction $absSeconds seconds" -ForegroundColor Green
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not seek. Make sure a track is playing on an active device." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred during seek: $errorMessage" -ForegroundColor Red
        }
    }
}

function skip-forward {
    <#
    .SYNOPSIS
    Skip forward 30 seconds (common podcast control)
    .EXAMPLE
    skip-forward
    Skip forward 30 seconds in current episode or track
    #>
    seek 30
}

function skip-back {
    <#
    .SYNOPSIS
    Skip backward 15 seconds (common podcast control)
    .EXAMPLE
    skip-back
    Skip backward 15 seconds in current episode or track
    #>
    seek -15
}

function replay {
    <#
    .SYNOPSIS
    Skip backward 30 seconds (useful for podcast replay)
    .EXAMPLE
    replay
    Skip backward 30 seconds to replay content
    #>
    seek -30
}

function shuffle {
    <#
    .SYNOPSIS
    Control shuffle mode
    .PARAMETER State
    Shuffle state: 'on', 'off', or 'toggle'
    .EXAMPLE
    shuffle on
    Enable shuffle
    .EXAMPLE
    shuffle toggle
    Toggle shuffle state
    #>
    param([ValidateSet('on', 'off', 'toggle')][string]$State = 'toggle')
    try {
        if ($State -eq 'toggle') {
            # Get current state first
            $currentState = Invoke-SpotifyApi -Method GET -Path "/me/player"
            $currentShuffle = $currentState.shuffle_state
            $newState = -not $currentShuffle
        } else {
            $newState = ($State -eq 'on')
        }
        $query = @{ state = $newState.ToString().ToLower() }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/shuffle" -Query $query | Out-Null
        $stateText = if ($newState) { "enabled" } else { "disabled" }
        $icon = if ($newState) { "🔀" } else { "➡️" }
        Write-Host "$icon Shuffle $stateText" -ForegroundColor Green
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not change shuffle state. Make sure a track is playing on an active device." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred: $errorMessage" -ForegroundColor Red
        }
    }
}

function repeat {
    <#
    .SYNOPSIS
    Control repeat mode
    .PARAMETER Mode
    Repeat mode: 'track', 'context', 'off'
    .EXAMPLE
    repeat track
    Repeat current track
    .EXAMPLE
    repeat off
    Disable repeat
    #>
    param([ValidateSet('track', 'context', 'off')][string]$Mode = 'off')
    try {
        $query = @{ state = $Mode }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/repeat" -Query $query | Out-Null
        $icon = switch ($Mode) {
            "track" { "🔂" }
            "context" { "🔁" }
            "off" { "➡️" }
        }
        $modeText = switch ($Mode) {
            "track" { "current track" }
            "context" { "playlist/album" }
            "off" { "disabled" }
        }
        Write-Host "$icon Repeat $modeText" -ForegroundColor Green
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not change repeat state. Make sure a track is playing on an active device." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred: $errorMessage" -ForegroundColor Red
        }
    }
}

function transfer {
    <#
    .SYNOPSIS
    Transfer playback to another device
    .PARAMETER DeviceId
    Device ID or number (from devices list) to transfer to
    .EXAMPLE
    transfer 1
    Transfer playback to device #1 from devices list
    .EXAMPLE
    transfer abc123
    Transfer playback to device with ID abc123
    #>
    param([string]$DeviceId)
    try {
        if ([string]::IsNullOrWhiteSpace($DeviceId)) {
            Write-Host "Usage: transfer <device_number_or_id>" -ForegroundColor Yellow
            Write-Host "Use 'devices' command to see available devices" -ForegroundColor Gray
            return
        }

        $actualDeviceId = $DeviceId
        $deviceName = ""

        # Check if it's a number (device index from 'devices' command)
        if ($DeviceId -match '^\d+$') {
            $deviceIndex = [int]$DeviceId - 1
            $sessionDevices = Get-SessionDevices
            if ($sessionDevices -and $deviceIndex -ge 0 -and $deviceIndex -lt $sessionDevices.Count) {
                $actualDeviceId = $sessionDevices[$deviceIndex].id
                $deviceName = $sessionDevices[$deviceIndex].name
                Write-Host "🎯 Transferring to device #$DeviceId ($deviceName)..." -ForegroundColor Cyan
            } else {
                # If session is stale or number is invalid, give a helpful error.
                Write-Host "❌ Invalid device number. Run 'devices' first to see an up-to-date list." -ForegroundColor Red
                return
            }
        } else {
             # It's a raw ID, let's try to find its name for a better user message.
             $devicesResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/devices"
             $foundDevice = $devicesResponse.devices | Where-Object { $_.id -eq $actualDeviceId }
             if ($foundDevice) {
                 $deviceName = $foundDevice.name
             }
             Write-Host "🎯 Transferring to device '$($deviceName)' ($actualDeviceId)..." -ForegroundColor Cyan
        }

        $body = @{ device_ids = @($actualDeviceId) }
        Invoke-SpotifyApi -Method PUT -Path "/me/player" -Body $body | Out-Null

        Write-Host "📱 Playback successfully transferred to '$($deviceName)'" -ForegroundColor Green
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not transfer playback." -ForegroundColor Red
            Write-Host "💡 Make sure the device ID is correct and the device is online." -ForegroundColor Yellow
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred: $errorMessage" -ForegroundColor Red
        }
    }
}

function export-now-playing {
    <#
    .SYNOPSIS
    Export currently playing track info to files for OBS/streaming
    .PARAMETER OutputPath
    Directory to save files (default: current directory)
    .PARAMETER Watch
    Continuously update files (useful for OBS)
    .EXAMPLE
    export-now-playing
    Export current track to files in current directory
    .EXAMPLE
    export-now-playing -OutputPath "C:\OBS\nowplaying"
    Export to specific directory
    .EXAMPLE
    export-now-playing -Watch
    Continuously update files every 2 seconds
    #>
    param(
        [string]$OutputPath = ".",
        [switch]$Watch
    )

    # Ensure directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $trackFile = Join-Path $OutputPath "track.txt"
    $artistFile = Join-Path $OutputPath "artist.txt"
    $albumFile = Join-Path $OutputPath "album.txt"
    $nowPlayingFile = Join-Path $OutputPath "nowplaying.txt"

    if ($Watch) {
        Write-Host "📝 Starting continuous export to $OutputPath" -ForegroundColor Cyan
        Write-Host "💡 Files will update every 2 seconds" -ForegroundColor Yellow
        Write-Host "💡 Press Ctrl+C to stop" -ForegroundColor Yellow
        Write-Host ""

        try {
            while ($true) {
                try {
                    $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
                    if ($currentTrack -and $currentTrack.item) {
                        $item = $currentTrack.item

                        if ($currentTrack.currently_playing_type -eq "episode" -or $item.type -eq "episode") {
                            # Podcast episode
                            Set-Content -Path $trackFile -Value $item.name -Encoding UTF8
                            Set-Content -Path $artistFile -Value $item.show.name -Encoding UTF8
                            Set-Content -Path $albumFile -Value "Podcast" -Encoding UTF8
                            Set-Content -Path $nowPlayingFile -Value "🎙️ $($item.name) - $($item.show.name)" -Encoding UTF8
                        } else {
                            # Music track
                            $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                            Set-Content -Path $trackFile -Value $item.name -Encoding UTF8
                            Set-Content -Path $artistFile -Value $artists -Encoding UTF8
                            Set-Content -Path $albumFile -Value $item.album.name -Encoding UTF8
                            Set-Content -Path $nowPlayingFile -Value "🎵 $($item.name) - $artists" -Encoding UTF8
                        }

                        Write-Host "✅ Updated at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
                    } else {
                        # Clear files if nothing is playing
                        "" | Set-Content -Path $trackFile -Encoding UTF8
                        "" | Set-Content -Path $artistFile -Encoding UTF8
                        "" | Set-Content -Path $albumFile -Encoding UTF8
                        "Not playing" | Set-Content -Path $nowPlayingFile -Encoding UTF8
                    }
                } catch {
                    Write-Warning "Failed to update: $($_.Exception.Message)"
                }

                Start-Sleep -Seconds 2
            }
        } catch {
            Write-Host ""
            Write-Host "📝 Export stopped." -ForegroundColor Yellow
        }
    } else {
        try {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            if (-not $currentTrack -or -not $currentTrack.item) {
                Write-Host "❌ No track or episode currently playing." -ForegroundColor Red
                return
            }

            $item = $currentTrack.item

            if ($currentTrack.currently_playing_type -eq "episode" -or $item.type -eq "episode") {
                # Podcast episode
                Set-Content -Path $trackFile -Value $item.name -Encoding UTF8
                Set-Content -Path $artistFile -Value $item.show.name -Encoding UTF8
                Set-Content -Path $albumFile -Value "Podcast" -Encoding UTF8
                Set-Content -Path $nowPlayingFile -Value "🎙️ $($item.name) - $($item.show.name)" -Encoding UTF8

                Write-Host "📝 Exported podcast episode:" -ForegroundColor Magenta
                Write-Host "   $($item.name)" -ForegroundColor White
                Write-Host "   from $($item.show.name)" -ForegroundColor Gray
            } else {
                # Music track
                $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                Set-Content -Path $trackFile -Value $item.name -Encoding UTF8
                Set-Content -Path $artistFile -Value $artists -Encoding UTF8
                Set-Content -Path $albumFile -Value $item.album.name -Encoding UTF8
                Set-Content -Path $nowPlayingFile -Value "🎵 $($item.name) - $artists" -Encoding UTF8

                Write-Host "📝 Exported track:" -ForegroundColor Green
                Write-Host "   $($item.name)" -ForegroundColor White
                Write-Host "   by $artists" -ForegroundColor Gray
                Write-Host "   from $($item.album.name)" -ForegroundColor Gray
            }

            Write-Host ""
            Write-Host "Files saved to:" -ForegroundColor Cyan
            Write-Host "   $trackFile" -ForegroundColor Gray
            Write-Host "   $artistFile" -ForegroundColor Gray
            Write-Host "   $albumFile" -ForegroundColor Gray
            Write-Host "   $nowPlayingFile" -ForegroundColor Gray
        }
        catch {
            $errorMessage = $_.Exception.Message
            if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
                Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
                Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
            }
            elseif ($errorMessage -match "404|Not Found") {
                Write-Host "❌ Could not get current track." -ForegroundColor Red
                Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
            }
            else {
                Write-Host "❌ An unexpected error occurred: $errorMessage" -ForegroundColor Red
            }
        }
    }
}

function copy-track-link {
    <#
    .SYNOPSIS
    Copy current track or episode Spotify link to clipboard
    .EXAMPLE
    copy-track-link
    Copy Spotify link for currently playing track to clipboard
    #>
    try {
        $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        if (-not $currentTrack -or -not $currentTrack.item) {
            Write-Host "❌ No track or episode currently playing." -ForegroundColor Red
            return
        }

        $item = $currentTrack.item
        $link = ""
        $name = ""

        if ($currentTrack.currently_playing_type -eq "episode" -or $item.type -eq "episode") {
            # Podcast episode
            $episodeId = $item.id
            $link = "https://open.spotify.com/episode/$episodeId"
            $name = $item.name
            Write-Host "🎙️ $name" -ForegroundColor Magenta
        } else {
            # Music track
            $trackId = $item.id
            $link = "https://open.spotify.com/track/$trackId"
            $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
            $name = "$($item.name) by $artists"
            Write-Host "🎵 $name" -ForegroundColor Green
        }

        # Copy to clipboard
        Set-Clipboard -Value $link
        Write-Host "📋 Link copied to clipboard: $link" -ForegroundColor Cyan
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not get current track." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred: $errorMessage" -ForegroundColor Red
        }
    }
}

function volume-low {
    <#
    .SYNOPSIS
    Set volume to 25% (low preset)
    .EXAMPLE
    volume-low
    Set volume to 25%
    #>
    volume 25
}

function volume-medium {
    <#
    .SYNOPSIS
    Set volume to 50% (medium preset)
    .EXAMPLE
    volume-medium
    Set volume to 50%
    #>
    volume 50
}

function volume-high {
    <#
    .SYNOPSIS
    Set volume to 75% (high preset)
    .EXAMPLE
    volume-high
    Set volume to 75%
    #>
    volume 75
}

Export-ModuleMember -Function @(
    'play',
    'pause',
    'next',
    'previous',
    'volume',
    'volume-low',
    'volume-medium',
    'volume-high',
    'copy-track-link',
    'export-now-playing',
    'seek',
    'skip-forward',
    'skip-back',
    'replay',
    'shuffle',
    'repeat',
    'transfer'
)
