# Interactive Mode Module
# Provides keyboard navigation for lists (playlists, search results, etc.)

$script:InteractiveMode = $false
$script:CurrentItems = @()
$script:SelectedIndex = 0

function Start-InteractiveMode {
    <#
    .SYNOPSIS
    Start interactive navigation mode with arrow keys

    .PARAMETER Items
    Array of items to navigate (tracks, playlists, etc.)

    .PARAMETER Title
    Title to display at the top

    .EXAMPLE
    Start-InteractiveMode -Items $searchResults -Title "Search Results"
    #>

    param(
        [Parameter(Mandatory=$true)]
        $Items,

        [string]$Title = "Interactive Mode"
    )

    if (-not $Items -or $Items.Count -eq 0) {
        Write-Host "❌ No items to navigate" -ForegroundColor Red
        return
    }

    $script:InteractiveMode = $true
    $script:CurrentItems = $Items
    $script:SelectedIndex = 0

    Clear-Host
    Write-Host ""
    Write-Host "🎮 $Title" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor DarkGray
    Write-Host "⌨️  Controls: ↑↓ Navigate | Enter Play | Space Queue | Esc Exit" -ForegroundColor Yellow
    Write-Host ""

    Show-InteractiveItems

    try {
        while ($script:InteractiveMode) {
            if (-not $Host.UI.RawUI.KeyAvailable) {
                Start-Sleep -Milliseconds 100
                continue
            }

            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

            switch ($key.VirtualKeyCode) {
                38 { # Up arrow
                    if ($script:SelectedIndex -gt 0) {
                        $script:SelectedIndex--
                        Show-InteractiveItems
                    }
                }
                40 { # Down arrow
                    if ($script:SelectedIndex -lt ($script:CurrentItems.Count - 1)) {
                        $script:SelectedIndex++
                        Show-InteractiveItems
                    }
                }
                13 { # Enter - Play
                    $selectedItem = $script:CurrentItems[$script:SelectedIndex]
                    Play-SpotifyItem -Item $selectedItem
                    $script:InteractiveMode = $false
                }
                32 { # Space - Queue
                    $selectedItem = $script:CurrentItems[$script:SelectedIndex]
                    Queue-SpotifyItem -Item $selectedItem
                    Show-InteractiveItems
                }
                27 { # Escape - Exit
                    $script:InteractiveMode = $false
                    Write-Host ""
                    Write-Host "👋 Exited interactive mode" -ForegroundColor Yellow
                }
                { $_ -ge 49 -and $_ -le 57 } { # Number keys 1-9
                    $number = $_ - 48
                    if ($number -le $script:CurrentItems.Count) {
                        $script:SelectedIndex = $number - 1
                        Show-InteractiveItems
                    }
                }
            }
        }
    } catch {
        Write-Warning "Interactive mode error: $($_.Exception.Message)"
        $script:InteractiveMode = $false
    }
}

function Show-InteractiveItems {
    # Save cursor position
    $currentLine = [Console]::CursorTop

    # Clear and redraw items
    try {
        # Move cursor to start of list
        [Console]::SetCursorPosition(0, 5)

        for ($i = 0; $i -lt $script:CurrentItems.Count; $i++) {
            $item = $script:CurrentItems[$i]
            $isSelected = ($i -eq $script:SelectedIndex)
            $prefix = if ($isSelected) { "► " } else { "  " }
            $color = if ($isSelected) { "Yellow" } else { "White" }

            # Clear line
            Write-Host (" " * 120) -NoNewline
            [Console]::SetCursorPosition(0, [Console]::CursorTop)

            # Determine item type and display appropriately
            if ($item.type -eq "playlist" -or $item.search_type -eq "playlist") {
                # Playlist item
                $trackInfo = if ($item.description) { " • $($item.description)" } else { "" }
                Write-Host "$prefix$($i + 1). 📁 $($item.name)$trackInfo" -ForegroundColor $color
            }
            elseif ($item.PSObject.Properties.Name -contains 'track') {
                # Queue item
                $track = $item.track
                $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
                Write-Host "$prefix$($i + 1). 🎵 $($track.name) - $artists" -ForegroundColor $color
            }
            elseif ($item.type -eq "episode" -or $item.PSObject.Properties.Name -contains 'show') {
                # Podcast episode
                $showName = if ($item.show) { $item.show.name } else { "" }
                Write-Host "$prefix$($i + 1). 🎙️ $($item.name) - $showName" -ForegroundColor $color
            }
            elseif ($item.PSObject.Properties.Name -contains 'artists') {
                # Track
                $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                Write-Host "$prefix$($i + 1). 🎵 $($item.name) - $artists" -ForegroundColor $color
            }
            else {
                # Generic item - just show name
                Write-Host "$prefix$($i + 1). $($item.name)" -ForegroundColor $color
            }
        }

        Write-Host ""
    } catch {
        # Fallback if console manipulation fails
        for ($i = 0; $i -lt $script:CurrentItems.Count; $i++) {
            $item = $script:CurrentItems[$i]
            $isSelected = ($i -eq $script:SelectedIndex)
            $prefix = if ($isSelected) { "► " } else { "  " }

            Write-Host "$prefix$($i + 1). $($item.name)" -ForegroundColor $(if ($isSelected) { "Yellow" } else { "White" })
        }
    }
}

function Play-SpotifyItem {
    param($Item)

    if (-not $Item) { return }

    try {
        # Handle playlist vs track differently
        if ($Item.type -eq "playlist" -or $Item.search_type -eq "playlist") {
            # Play playlist
            $playlistUri = if ($Item.uri) { $Item.uri } else { "spotify:playlist:$($Item.id)" }
            $body = @{ context_uri = $playlistUri } | ConvertTo-Json

            try {
                Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
                Write-Host "▶️ Playing playlist: $($Item.name)" -ForegroundColor Green
            } catch {
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
                    $transferBody = @{ device_ids = @($firstDevice.id); play = $false } | ConvertTo-Json
                    Invoke-SpotifyApi -Method PUT -Path "/me/player" -Body $transferBody | Out-Null
                    Start-Sleep -Milliseconds 500

                    # Try again to play
                    Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
                    Write-Host "▶️ Playing playlist: $($Item.name)" -ForegroundColor Green
                } catch {
                    Write-Host "❌ Could not play playlist: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        else {
            # Play single track
            $uri = if ($Item.uri) {
                $Item.uri
            } elseif ($Item.track -and $Item.track.uri) {
                $Item.track.uri
            } elseif ($Item.Uri) {
                $Item.Uri
            } else {
                throw "No URI found for item"
            }

            $body = @{ uris = @($uri) } | ConvertTo-Json

            # Get display name
            $name = if ($Item.name) { $Item.name } elseif ($Item.track) { $Item.track.name } else { "Unknown" }

            try {
                Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null

                if ($Item.type -eq "episode" -or ($Item.track -and $Item.track.type -eq "episode")) {
                    Write-Host "▶️ Playing podcast episode: $name" -ForegroundColor Magenta
                } else {
                    $artists = if ($Item.artists) {
                        ($Item.artists | ForEach-Object { $_.name }) -join ", "
                    } elseif ($Item.track -and $Item.track.artists) {
                        ($Item.track.artists | ForEach-Object { $_.name }) -join ", "
                    } else {
                        "Unknown Artist"
                    }
                    Write-Host "▶️ Playing: $name by $artists" -ForegroundColor Green
                }
            } catch {
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
                    $transferBody = @{ device_ids = @($firstDevice.id); play = $false } | ConvertTo-Json
                    Invoke-SpotifyApi -Method PUT -Path "/me/player" -Body $transferBody | Out-Null
                    Start-Sleep -Milliseconds 500

                    # Try again to play
                    Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null

                    if ($Item.type -eq "episode" -or ($Item.track -and $Item.track.type -eq "episode")) {
                        Write-Host "▶️ Playing podcast episode: $name" -ForegroundColor Magenta
                    } else {
                        $artists = if ($Item.artists) {
                            ($Item.artists | ForEach-Object { $_.name }) -join ", "
                        } elseif ($Item.track -and $Item.track.artists) {
                            ($Item.track.artists | ForEach-Object { $_.name }) -join ", "
                        } else {
                            "Unknown Artist"
                        }
                        Write-Host "▶️ Playing: $name by $artists" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "❌ Could not play track: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    } catch {
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
    }
}

function Queue-SpotifyItem {
    param($Item)

    if (-not $Item) { return }

    try {
        # Determine URI based on item structure
        $uri = if ($Item.uri) {
            $Item.uri
        } elseif ($Item.track -and $Item.track.uri) {
            $Item.track.uri
        } elseif ($Item.Uri) {
            $Item.Uri
        } else {
            throw "No URI found for item"
        }

        Invoke-SpotifyApi -Method POST -Path "/me/player/queue?uri=$uri" | Out-Null

        $name = if ($Item.name) { $Item.name } elseif ($Item.track) { $Item.track.name } else { "Unknown" }
        Write-Host "✅ Added to queue: $name" -ForegroundColor Green
    } catch {
        Write-Host "❌ Could not add to queue: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Export-ModuleMember -Function @(
    'Start-InteractiveMode',
    'Show-InteractiveItems',
    'Play-SpotifyItem',
    'Queue-SpotifyItem'
)
