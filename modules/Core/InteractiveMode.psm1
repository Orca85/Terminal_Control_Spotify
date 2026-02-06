# Interactive Mode Module
# Provides keyboard navigation for lists (playlists, search results, etc.)

$script:InteractiveMode = $false
$script:CurrentItems = @()
$script:SelectedIndex = 0
$script:ViewportStart = 0
$script:HeaderLines = 5

function Get-TerminalSize {
    try {
        $width = $Host.UI.RawUI.WindowSize.Width
        $height = $Host.UI.RawUI.WindowSize.Height
    } catch {
        $width = 80
        $height = 24
    }
    if ($width -lt 40) { $width = 40 }
    if ($height -lt 10) { $height = 10 }
    return @{ Width = $width; Height = $height }
}

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
    $script:ViewportStart = 0

    $termSize = Get-TerminalSize
    $separatorWidth = [Math]::Min($termSize.Width - 1, 80)

    Clear-Host
    Write-Host ""
    Write-Host "🎮 $Title" -ForegroundColor Cyan
    Write-Host ("=" * $separatorWidth) -ForegroundColor DarkGray
    Write-Host "⌨️  ↑↓ Navigate | Enter Play | Space Queue | Esc Exit" -ForegroundColor Yellow
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
    $termSize = Get-TerminalSize
    $termWidth = $termSize.Width
    $termHeight = $termSize.Height

    # Calculate visible item slots: total height minus header (5 lines) minus footer (2 lines for scroll indicators + blank)
    $maxVisible = $termHeight - $script:HeaderLines - 3
    if ($maxVisible -lt 3) { $maxVisible = 3 }

    $totalItems = $script:CurrentItems.Count

    # Adjust viewport to keep selected item visible
    if ($script:SelectedIndex -lt $script:ViewportStart) {
        $script:ViewportStart = $script:SelectedIndex
    }
    if ($script:SelectedIndex -ge ($script:ViewportStart + $maxVisible)) {
        $script:ViewportStart = $script:SelectedIndex - $maxVisible + 1
    }
    if ($script:ViewportStart -lt 0) { $script:ViewportStart = 0 }

    $viewEnd = [Math]::Min($script:ViewportStart + $maxVisible, $totalItems)

    try {
        # Move cursor to start of list area
        [Console]::SetCursorPosition(0, $script:HeaderLines)

        # Show "more above" indicator
        $clearStr = " " * ($termWidth - 1)
        if ($script:ViewportStart -gt 0) {
            $aboveText = "  ▲ $($script:ViewportStart) more above"
            if ($aboveText.Length -gt ($termWidth - 1)) { $aboveText = $aboveText.Substring(0, $termWidth - 1) }
            Write-Host $clearStr -NoNewline
            [Console]::SetCursorPosition(0, [Console]::CursorTop)
            Write-Host $aboveText -ForegroundColor DarkCyan
        } else {
            Write-Host $clearStr -NoNewline
            [Console]::SetCursorPosition(0, [Console]::CursorTop)
            Write-Host ""
        }

        # Draw visible items
        for ($i = $script:ViewportStart; $i -lt $viewEnd; $i++) {
            $item = $script:CurrentItems[$i]
            $isSelected = ($i -eq $script:SelectedIndex)
            $prefix = if ($isSelected) { "► " } else { "  " }
            $color = if ($isSelected) { "Yellow" } else { "White" }

            # Build display text
            $displayText = Get-ItemDisplayText -Item $item -Index $i

            # Truncate to fit terminal width
            $fullLine = "$prefix$displayText"
            if ($fullLine.Length -gt ($termWidth - 1)) {
                $fullLine = $fullLine.Substring(0, $termWidth - 4) + "..."
            }

            # Clear line and write
            Write-Host $clearStr -NoNewline
            [Console]::SetCursorPosition(0, [Console]::CursorTop)
            Write-Host $fullLine -ForegroundColor $color
        }

        # Clear remaining lines in viewport area
        $linesDrawn = ($viewEnd - $script:ViewportStart)
        $remainingSlots = $maxVisible - $linesDrawn
        for ($j = 0; $j -lt $remainingSlots; $j++) {
            Write-Host $clearStr -NoNewline
            [Console]::SetCursorPosition(0, [Console]::CursorTop)
            Write-Host ""
        }

        # Show "more below" indicator
        $belowCount = $totalItems - $viewEnd
        if ($belowCount -gt 0) {
            $belowText = "  ▼ $belowCount more below"
            if ($belowText.Length -gt ($termWidth - 1)) { $belowText = $belowText.Substring(0, $termWidth - 1) }
            Write-Host $clearStr -NoNewline
            [Console]::SetCursorPosition(0, [Console]::CursorTop)
            Write-Host $belowText -ForegroundColor DarkCyan
        } else {
            Write-Host $clearStr -NoNewline
            [Console]::SetCursorPosition(0, [Console]::CursorTop)
            Write-Host ""
        }

        # Status line
        $statusText = "  ($($script:SelectedIndex + 1)/$totalItems)"
        Write-Host $clearStr -NoNewline
        [Console]::SetCursorPosition(0, [Console]::CursorTop)
        Write-Host $statusText -ForegroundColor DarkGray

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

function Get-ItemDisplayText {
    param($Item, [int]$Index)

    if ($Item.type -eq "playlist" -or $Item.search_type -eq "playlist") {
        $trackInfo = if ($Item.description) { " • $($Item.description)" } else { "" }
        return "$($Index + 1). 📁 $($Item.name)$trackInfo"
    }
    elseif ($Item.PSObject.Properties.Name -contains 'track') {
        $track = $Item.track
        $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
        return "$($Index + 1). 🎵 $($track.name) - $artists"
    }
    elseif ($Item.type -eq "episode" -or $Item.PSObject.Properties.Name -contains 'show') {
        $showName = if ($Item.show) { $Item.show.name } else { "" }
        return "$($Index + 1). 🎙️ $($Item.name) - $showName"
    }
    elseif ($Item.PSObject.Properties.Name -contains 'artists') {
        $artists = ($Item.artists | ForEach-Object { $_.name }) -join ", "
        return "$($Index + 1). 🎵 $($Item.name) - $artists"
    }
    else {
        return "$($Index + 1). $($Item.name)"
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
            $body = @{ context_uri = $playlistUri }

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
                    $transferBody = @{ device_ids = @($firstDevice.id); play = $false }
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

            $body = @{ uris = @($uri) }

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
                    $transferBody = @{ device_ids = @($firstDevice.id); play = $false }
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
    'Get-ItemDisplayText',
    'Play-SpotifyItem',
    'Queue-SpotifyItem'
)
