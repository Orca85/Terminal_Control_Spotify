# PlaybackCommands Module
# Contains all core functions for controlling Spotify playback.

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
            $body = @{ uris = @($trackUri) }
            Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body
            if ($trackUri.StartsWith("spotify:episode:")) {
                Write-Host "▶️ Playing podcast episode" -ForegroundColor Magenta
            } else {
                Write-Host "▶️ Playing track" -ForegroundColor Green
            }
        }
        catch [AuthenticationException] {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        catch [ApiClientException] {
            Write-Host "❌ Could not play track. Make sure a device is active." -ForegroundColor Red
            Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        catch {
            Write-Host "❌ An unexpected error occurred while trying to play the track: $($_.Exception.Message)" -ForegroundColor Red
        }
        return
    }

    # Path 1: Resume playback or play recent
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play"
        Write-Host "▶️ Resumed playback" -ForegroundColor Green
    }
    catch [ApiClientException] {
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
                Invoke-SpotifyApi -Method PUT -Path "/me/player" -Body $transferBody
                Start-Sleep -Milliseconds 500
            }

            $recentTracks = Invoke-SpotifyApi -Method GET -Path "/me/player/recently-played" -Query @{ limit = 1 }
            if ($recentTracks -and $recentTracks.items -and $recentTracks.items.Count -gt 0) {
                $lastTrack = $recentTracks.items[0].track
                $body = @{ uris = @($lastTrack.uri) }
                Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body
                Write-Host "▶️ Started playing: $($lastTrack.name) by $(($lastTrack.artists | ForEach-Object { $_.name }) -join ', ')" -ForegroundColor Green
            } else {
                Write-Host "❌ No recent tracks found to play." -ForegroundColor Red
            }
        }
        catch {
            Write-Host "❌ Could not start playback automatically." -ForegroundColor Red
            Write-Host "💡 Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred while trying to resume playback: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function pause {
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/pause"
        Write-Host "⏸️ Paused playback" -ForegroundColor Yellow
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not pause playback. Make sure Spotify is open and playing." -ForegroundColor Red
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        # Catch any other general errors
        Write-Host "❌ An unexpected error occurred: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function next {
    try {
        Invoke-SpotifyApi -Method POST -Path "/me/player/next"
        Write-Host "⏭️ Skipped to next track" -ForegroundColor Green
        # Wait a moment for Spotify to update, then show notification
        Start-Sleep -Milliseconds 500
        # Get current track info and show notification
        try {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            if ($currentTrack -and $currentTrack.item) {
                Show-TrackNotification -TrackInfo $currentTrack.item
            }
        } catch {
            # If we can't get track info, show generic notification
            Show-TrackNotification -Title "Spotify" -Message "Skipped to next track"
        }
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not skip to next track. Make sure Spotify is playing music." -ForegroundColor Red
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        # Catch any other general errors
        Write-Host "❌ An unexpected error occurred: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function previous {
    try {
        Invoke-SpotifyApi -Method POST -Path "/me/player/previous"
        Write-Host "⏮️ Skipped to previous track" -ForegroundColor Green
        # Wait a moment for Spotify to update, then show notification
        Start-Sleep -Milliseconds 500
        # Get current track info and show notification
        try {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            if ($currentTrack -and $currentTrack.item) {
                Show-TrackNotification -TrackInfo $currentTrack.item
            }
        } catch {
            # If we can't get track info, show generic notification
            Show-TrackNotification -Title "Spotify" -Message "Skipped to previous track"
        }
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not skip to previous track. Make sure Spotify is playing music." -ForegroundColor Red
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        # Catch any other general errors
        Write-Host "❌ An unexpected error occurred: $($_.Exception.Message)" -ForegroundColor Red
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
        Invoke-SpotifyApi -Method PUT -Path "/me/player/volume" -Query $query
        Write-Host "🔊 Volume set to $Level%" -ForegroundColor Green
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not set volume. Make sure a device is active and supports volume control." -ForegroundColor Red
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        # Catch any other general errors
        Write-Host "❌ An unexpected error occurred: $($_.Exception.Message)" -ForegroundColor Red
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
        Invoke-SpotifyApi -Method PUT -Path "/me/player/seek" -Query $query

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
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not seek. Make sure a track is playing on an active device." -ForegroundColor Red
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred during seek: $($_.Exception.Message)" -ForegroundColor Red
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
        Invoke-SpotifyApi -Method PUT -Path "/me/player/shuffle" -Query $query
        $stateText = if ($newState) { "enabled" } else { "disabled" }
        $icon = if ($newState) { "🔀" } else { "➡️" }
        Write-Host "$icon Shuffle $stateText" -ForegroundColor Green
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not change shuffle state. Make sure a track is playing on an active device." -ForegroundColor Red
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred: $($_.Exception.Message)" -ForegroundColor Red
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
        Invoke-SpotifyApi -Method PUT -Path "/me/player/repeat" -Query $query
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
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not change repeat state. Make sure a track is playing on an active device." -ForegroundColor Red
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred: $($_.Exception.Message)" -ForegroundColor Red
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
        Invoke-SpotifyApi -Method PUT -Path "/me/player" -Body $body

        Write-Host "📱 Playback successfully transferred to '$($deviceName)'" -ForegroundColor Green
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not transfer playback." -ForegroundColor Red
        Write-Host "💡 Make sure the device ID is correct and the device is online." -ForegroundColor Yellow
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Export-ModuleMember -Function @(
    'play',
    'pause',
    'next',
    'previous',
    'volume',
    'seek',
    'skip-forward',
    'skip-back',
    'replay',
    'shuffle',
    'repeat',
    'transfer'
)
