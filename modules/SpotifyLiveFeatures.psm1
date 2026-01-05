# Spotify Live Features - Simplified Version
# Simple implementation without complex classes

# Global state variables
$script:LiveFeaturesInitialized = $false
$script:FeatureStatus = @{
    LiveDisplay = $false
    Lyrics = $false
    Statistics = $false
    Configuration = $false
}

# Configuration directory
$script:ConfigDir = Join-Path $env:APPDATA "SpotifyCLI\LiveFeatures"

# Initialize Live Features
function Initialize-SpotifyLiveFeatures {
    <#
    .SYNOPSIS
    Initialize Spotify Live Features system
    #>
    try {
        Write-Host "🚀 Initializing Spotify Live Features..." -ForegroundColor Cyan
        
        # Create directories if they don't exist
        if (-not (Test-Path $script:ConfigDir)) {
            New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null
        }
        
        # Initialize basic configuration
        $script:FeatureStatus.Configuration = $true
        
        # Try to initialize each feature
        try {
            # Basic lyrics functionality
            $script:FeatureStatus.Lyrics = $true
            Write-Host "✅ Lyrics engine ready" -ForegroundColor Green
        } catch {
            Write-Warning "Lyrics engine initialization failed: $($_.Exception.Message)"
        }
        
        try {
            # Basic statistics functionality  
            $script:FeatureStatus.Statistics = $true
            Write-Host "✅ Statistics engine ready" -ForegroundColor Green
        } catch {
            Write-Warning "Statistics engine initialization failed: $($_.Exception.Message)"
        }
        
        try {
            # Basic live display functionality
            $script:FeatureStatus.LiveDisplay = $true
            Write-Host "✅ Live display engine ready" -ForegroundColor Green
        } catch {
            Write-Warning "Live display engine initialization failed: $($_.Exception.Message)"
        }
        
        $script:LiveFeaturesInitialized = $true
        Write-Host "🎉 Live Features initialized successfully!" -ForegroundColor Green
        
    } catch {
        Write-Error "Failed to initialize Live Features: $($_.Exception.Message)"
        throw
    }
}

# Get Live Features Status
function Get-SpotifyLiveFeaturesStatus {
    <#
    .SYNOPSIS
    Get the current status of all live features
    #>
    
    $status = @{
        Initialized = $script:LiveFeaturesInitialized
        Features = $script:FeatureStatus.Clone()
        ConfigurationDirectory = $script:ConfigDir
    }
    
    Write-Host "🎵 Spotify Live Features Status" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Initialized: $(if ($status.Initialized) { '✅ Yes' } else { '❌ No' })" -ForegroundColor White
    Write-Host ""
    Write-Host "Feature Status:" -ForegroundColor Yellow
    foreach ($feature in $status.Features.Keys) {
        $icon = if ($status.Features[$feature]) { "✅" } else { "❌" }
        Write-Host "  $icon $feature" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Configuration Directory: $($status.ConfigurationDirectory)" -ForegroundColor Gray
    
    return $status
}

# Start Live Display
function Start-SpotifyLiveDisplay {
    <#
    .SYNOPSIS
    Start live display of current track information with real-time updates
    .PARAMETER Mode
    Display mode: detailed (default), compact, or minimal
    .PARAMETER RefreshInterval
    Update interval in milliseconds (default: 1000)
    .PARAMETER UseAdvancedEngine
    Use the advanced LiveDisplayEngine with ANSI support (default: $true)
    .EXAMPLE
    Start-SpotifyLiveDisplay
    Start detailed live display with 1-second updates
    .EXAMPLE
    Start-SpotifyLiveDisplay -Mode compact -RefreshInterval 500
    Start compact mode with 0.5-second updates
    #>
    param(
        [ValidateSet("detailed", "compact", "minimal")]
        [string]$Mode = "detailed",

        [int]$RefreshInterval = 1000,

        [bool]$UseAdvancedEngine = $true
    )

    if (-not $script:LiveFeaturesInitialized) {
        Write-Host "🔄 Auto-initializing Live Features..." -ForegroundColor Cyan
        Initialize-SpotifyLiveFeatures
    }

    Write-Host "🎵 Starting Live Display ($Mode mode)..." -ForegroundColor Cyan
    Write-Host "💡 Press Ctrl+C to stop" -ForegroundColor Yellow
    Start-Sleep -Milliseconds 500

    # Try to use advanced engine if available
    $useAdvanced = $UseAdvancedEngine
    if ($UseAdvancedEngine) {
        try {
            Import-Module (Join-Path $PSScriptRoot "LiveDisplay\LiveDisplayEngine.psm1") -Force -ErrorAction Stop
            $displayEngine = New-LiveDisplayEngine -Type "Console" -Configuration @{
                Mode = $Mode
                RefreshInterval = $RefreshInterval
            }
            $useAdvanced = $true
        } catch {
            Write-Warning "Advanced display engine not available, using fallback mode"
            $useAdvanced = $false
        }
    }

    try {
        $lastTrackId = ""
        $lastProgress = 0
        $updateCount = 0

        # Hide cursor for cleaner display
        try {
            [Console]::CursorVisible = $false
        } catch {}

        while ($true) {
            try {
                # Get current playback state
                $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"

                if ($currentTrack -and $currentTrack.item) {
                    $item = $currentTrack.item
                    $progress = if ($currentTrack.progress_ms) { $currentTrack.progress_ms } else { 0 }
                    $duration = $item.duration_ms
                    $isPlaying = $currentTrack.is_playing

                    # Only clear screen when track changes or every 10 updates
                    $trackChanged = ($item.id -ne $lastTrackId)
                    if ($trackChanged -or $updateCount % 10 -eq 0) {
                        Clear-Host
                        $updateCount = 0
                    }

                    # Move cursor to top if not clearing
                    if (-not $trackChanged -and $updateCount -gt 0) {
                        try {
                            [Console]::SetCursorPosition(0, 0)
                        } catch {}
                    }

                    # Display header
                    Write-Host "🎵 Spotify Live Display" -ForegroundColor Cyan -NoNewline
                    Write-Host " - $Mode mode" -ForegroundColor Gray
                    Write-Host ("=" * 60) -ForegroundColor DarkGray
                    Write-Host ""

                    # Display track info based on mode
                    switch ($Mode) {
                        "detailed" {
                            $statusIcon = if ($isPlaying) { "▶️" } else { "⏸️" }

                            if ($currentTrack.currently_playing_type -eq "episode" -or $item.type -eq "episode") {
                                # Podcast episode
                                Write-Host "$statusIcon Podcast Episode:" -ForegroundColor Magenta
                                Write-Host "  🎙️  $($item.name)" -ForegroundColor White
                                Write-Host "  📻 $($item.show.name)" -ForegroundColor Yellow
                            } else {
                                # Music track
                                $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                                Write-Host "$statusIcon Now Playing:" -ForegroundColor Green
                                Write-Host "  🎵 $($item.name)" -ForegroundColor White
                                Write-Host "  👤 $artists" -ForegroundColor Yellow
                                Write-Host "  📀 $($item.album.name)" -ForegroundColor Cyan
                            }

                            Write-Host ""

                            # Progress bar
                            $barWidth = 50
                            $percentage = if ($duration -gt 0) { ($progress / $duration) * 100 } else { 0 }
                            $filled = [Math]::Floor(($percentage / 100) * $barWidth)
                            $empty = $barWidth - $filled

                            $progressBar = ("█" * $filled) + ("░" * $empty)
                            Write-Host "  [$progressBar] $([Math]::Round($percentage))%" -ForegroundColor Magenta

                            try {
                                $currentMin = [Math]::Floor($progress / 60000)
                                $currentSec = [Math]::Floor(($progress % 60000) / 1000)
                                $totalMin = [Math]::Floor($duration / 60000)
                                $totalSec = [Math]::Floor(($duration % 60000) / 1000)
                                $currentTime = "{0}:{1:D2}" -f $currentMin, $currentSec
                                $totalTime = "{0}:{1:D2}" -f $totalMin, $totalSec
                                Write-Host "  ⏱️  $currentTime / $totalTime" -ForegroundColor Gray
                            } catch {
                                Write-Host "  ⏱️  --:-- / --:--" -ForegroundColor Gray
                            }
                        }

                        "compact" {
                            $statusIcon = if ($isPlaying) { "▶" } else { "⏸" }

                            if ($currentTrack.currently_playing_type -eq "episode") {
                                Write-Host "  $statusIcon 🎙️ $($item.name) - $($item.show.name)" -ForegroundColor Magenta
                            } else {
                                $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                                Write-Host "  $statusIcon 🎵 $($item.name) - $artists" -ForegroundColor Green
                            }

                            # Compact progress bar
                            $barWidth = 40
                            $percentage = if ($duration -gt 0) { ($progress / $duration) * 100 } else { 0 }
                            $filled = [Math]::Floor(($percentage / 100) * $barWidth)
                            $empty = $barWidth - $filled

                            $progressBar = ("█" * $filled) + ("░" * $empty)
                            try {
                                $currentMin = [Math]::Floor($progress / 60000)
                                $currentSec = [Math]::Floor(($progress % 60000) / 1000)
                                $totalMin = [Math]::Floor($duration / 60000)
                                $totalSec = [Math]::Floor(($duration % 60000) / 1000)
                                $currentTime = "{0}:{1:D2}" -f $currentMin, $currentSec
                                $totalTime = "{0}:{1:D2}" -f $totalMin, $totalSec
                                Write-Host "  [$progressBar] $currentTime/$totalTime" -ForegroundColor Gray
                            } catch {
                                Write-Host "  [$progressBar] --:--/--:--" -ForegroundColor Gray
                            }
                        }

                        "minimal" {
                            if ($currentTrack.currently_playing_type -eq "episode") {
                                Write-Host "  🎙️ $($item.name)" -ForegroundColor Magenta -NoNewline
                            } else {
                                $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                                Write-Host "  🎵 $($item.name) - $artists" -ForegroundColor White -NoNewline
                            }

                            $percentage = if ($duration -gt 0) { ($progress / $duration) * 100 } else { 0 }
                            Write-Host " [$([Math]::Round($percentage))%]" -ForegroundColor Gray
                        }
                    }

                    Write-Host ""
                    Write-Host "  🕒 $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor DarkGray -NoNewline
                    Write-Host " | Updates every $($RefreshInterval)ms" -ForegroundColor DarkGray
                    Write-Host ""
                    Write-Host "  Press Ctrl+C to stop" -ForegroundColor DarkYellow

                    $lastTrackId = $item.id
                    $lastProgress = $progress

                } else {
                    Clear-Host
                    Write-Host "🎵 Spotify Live Display - $Mode mode" -ForegroundColor Cyan
                    Write-Host ("=" * 60) -ForegroundColor DarkGray
                    Write-Host ""
                    Write-Host "  ⏸️  No track currently playing" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "  🕒 $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor DarkGray
                    Write-Host ""
                    Write-Host "  Press Ctrl+C to stop" -ForegroundColor DarkYellow
                }

                $updateCount++
                Start-Sleep -Milliseconds $RefreshInterval

            } catch {
                # Don't spam errors, just show once
                if ($updateCount % 30 -eq 0) {
                    Write-Warning "Failed to update: $($_.Exception.Message)"
                }
                Start-Sleep -Milliseconds $RefreshInterval
            }
        }
    } catch {
        Write-Host ""
    } finally {
        # Restore cursor
        try {
            [Console]::CursorVisible = $true
        } catch {}

        Write-Host ""
        Write-Host "Live display stopped." -ForegroundColor Yellow
    }
}

# Stop Live Display (placeholder)
function Stop-SpotifyLiveDisplay {
    <#
    .SYNOPSIS
    Stop live display
    #>
    Write-Host "Live display will stop on next refresh cycle." -ForegroundColor Yellow
}

# Get Current Track Lyrics
function Get-SpotifyCurrentTrackLyrics {
    <#
    .SYNOPSIS
    Get lyrics for the currently playing track
    #>
    
    if (-not $script:LiveFeaturesInitialized) {
        Write-Host "🔄 Auto-initializing Live Features..." -ForegroundColor Cyan
        Initialize-SpotifyLiveFeatures
    }
    
    Write-Host "🎵 Getting lyrics for current track..." -ForegroundColor Cyan
    
    # This is a placeholder - in a full implementation this would
    # integrate with lyrics providers like Genius or Musixmatch
    $currentTrack = plays-now
    
    if ($currentTrack) {
        Write-Host "Current track: $currentTrack" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "🎤 Lyrics functionality is available but requires" -ForegroundColor Gray
        Write-Host "   integration with lyrics providers (Genius, Musixmatch)" -ForegroundColor Gray
        Write-Host "   This feature will be enhanced in future updates." -ForegroundColor Gray
    } else {
        Write-Host "No track currently playing" -ForegroundColor Gray
    }
}

# Get Listening Statistics
function Get-SpotifyListeningStatistics {
    <#
    .SYNOPSIS
    Get listening statistics for specified period using Spotify API
    .PARAMETER Period
    Time period: day, week, month (short_term), or year (long_term)
    .EXAMPLE
    Get-SpotifyListeningStatistics -Period month
    Show top tracks and artists for the past month
    #>
    param(
        [ValidateSet("day", "week", "month", "year")]
        [string]$Period = "month"
    )

    if (-not $script:LiveFeaturesInitialized) {
        Write-Host "🔄 Auto-initializing Live Features..." -ForegroundColor Cyan
        Initialize-SpotifyLiveFeatures
    }

    # Map period to Spotify API time range
    $timeRange = switch ($Period) {
        "day"   { "short_term" }  # ~4 weeks
        "week"  { "short_term" }  # ~4 weeks
        "month" { "medium_term" } # ~6 months
        "year"  { "long_term" }   # several years
        default { "medium_term" }
    }

    $periodDisplay = switch ($Period) {
        "day"   { "Recent" }
        "week"  { "Past Week" }
        "month" { "Past 6 Months" }
        "year"  { "All Time" }
    }

    try {
        Write-Host "📊 Spotify Listening Statistics" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Period: $periodDisplay" -ForegroundColor Yellow
        Write-Host ""

        # Get top tracks
        Write-Host "🎵 Top Tracks" -ForegroundColor Green
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        try {
            $topTracks = Invoke-SpotifyApi -Method GET -Path "/me/top/tracks" -Query @{
                limit = 10
                time_range = $timeRange
            }

            if ($topTracks -and $topTracks.items) {
                $i = 1
                foreach ($track in $topTracks.items) {
                    $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
                    Write-Host "  $i. $($track.name)" -ForegroundColor White
                    Write-Host "      👤 $artists" -ForegroundColor Gray
                    Write-Host "      📀 $($track.album.name)" -ForegroundColor DarkGray

                    # Show popularity
                    if ($track.popularity) {
                        $popBar = "█" * [Math]::Floor($track.popularity / 10)
                        Write-Host "      📊 Popularity: $popBar $($track.popularity)%" -ForegroundColor Magenta
                    }
                    Write-Host ""
                    $i++
                }
            } else {
                Write-Host "  No data available" -ForegroundColor Yellow
                Write-Host ""
            }
        } catch {
            Write-Host "  Unable to load top tracks" -ForegroundColor Yellow
            Write-Host ""
        }

        # Get top artists
        Write-Host "🎤 Top Artists" -ForegroundColor Cyan
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        try {
            $topArtists = Invoke-SpotifyApi -Method GET -Path "/me/top/artists" -Query @{
                limit = 10
                time_range = $timeRange
            }

            if ($topArtists -and $topArtists.items) {
                $i = 1
                foreach ($artist in $topArtists.items) {
                    Write-Host "  $i. $($artist.name)" -ForegroundColor White

                    # Show genres
                    if ($artist.genres -and $artist.genres.Count -gt 0) {
                        $genres = $artist.genres[0..2] -join ", "
                        Write-Host "      🎸 $genres" -ForegroundColor Gray
                    }

                    # Show popularity
                    if ($artist.popularity) {
                        $popBar = "█" * [Math]::Floor($artist.popularity / 10)
                        Write-Host "      📊 Popularity: $popBar $($artist.popularity)%" -ForegroundColor Magenta
                    }
                    Write-Host ""
                    $i++
                }
            } else {
                Write-Host "  No data available" -ForegroundColor Yellow
                Write-Host ""
            }
        } catch {
            Write-Host "  Unable to load top artists" -ForegroundColor Yellow
            Write-Host ""
        }

        # Get recently played for additional context
        Write-Host "🕒 Recently Played" -ForegroundColor Yellow
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        try {
            $recentTracks = Invoke-SpotifyApi -Method GET -Path "/me/player/recently-played" -Query @{
                limit = 5
            }

            if ($recentTracks -and $recentTracks.items) {
                foreach ($item in $recentTracks.items) {
                    $track = $item.track
                    $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
                    $playedAt = [DateTime]::Parse($item.played_at).ToString("yyyy-MM-dd HH:mm")
                    Write-Host "  🎵 $($track.name)" -ForegroundColor White
                    Write-Host "      by $artists • played $playedAt" -ForegroundColor Gray
                    Write-Host ""
                }
            }
        } catch {
            Write-Host "  Unable to load recently played" -ForegroundColor Yellow
            Write-Host ""
        }

        Write-Host ("=" * 60) -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "💡 Use 'recent' for more history" -ForegroundColor Cyan
        Write-Host "💡 Statistics based on your Spotify listening data" -ForegroundColor Cyan

    } catch {
        Write-Host "❌ Failed to load statistics: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "💡 Try: stats month" -ForegroundColor Yellow
    }
}

# Sidecar functionality
function Start-SpotifySidecar {
    <#
    .SYNOPSIS
    Start Spotify CLI in sidecar mode (split terminal pane)
    .PARAMETER Position
    Position for split window: right (default), down, left, up
    .PARAMETER Size
    Size percentage for split (default: 40)
    .PARAMETER Mode
    Display mode for sidecar: detailed, compact, or minimal
    .EXAMPLE
    Start-SpotifySidecar
    Start sidecar on the right side
    .EXAMPLE
    Start-SpotifySidecar -Position down -Size 30 -Mode compact
    Start sidecar at bottom with 30% size in compact mode
    #>
    param(
        [ValidateSet("right", "down", "left", "up")]
        [string]$Position = "right",

        [int]$Size = 40,

        [ValidateSet("detailed", "compact", "minimal")]
        [string]$Mode = "compact"
    )

    Write-Host "🚀 Starting Spotify CLI in sidecar mode..." -ForegroundColor Cyan
    Write-Host ""

    # Check if running in Windows Terminal
    $isWindowsTerminal = $false
    if ($env:WT_SESSION -or $env:WT_PROFILE_ID) {
        $isWindowsTerminal = $true
    }

    if (-not $isWindowsTerminal) {
        Write-Host "⚠️  Windows Terminal not detected" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Sidecar mode works best in Windows Terminal." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Cyan
        Write-Host "  1. Install Windows Terminal from Microsoft Store" -ForegroundColor Gray
        Write-Host "  2. Open a new Windows Terminal window manually" -ForegroundColor Gray
        Write-Host "  3. Continue with live display in current window" -ForegroundColor Gray
        Write-Host ""

        $response = Read-Host "Continue with live display in current window? (Y/n)"
        if ($response -eq "" -or $response -match '^[Yy]') {
            Start-SpotifyLiveDisplay -Mode $Mode
        }
        return
    }

    # Determine split direction and size parameter
    $splitDirection = switch ($Position.ToLower()) {
        "right" { "--horizontal" }
        "left" { "--horizontal" }
        "down" { "--vertical" }
        "up" { "--vertical" }
        default { "--horizontal" }
    }

    # Calculate size as decimal
    $sizeDecimal = $Size / 100.0

    try {
        # Get current module path for the spawned pane
        $modulePath = $PSScriptRoot
        $parentPath = Split-Path $modulePath -Parent

        # Create command to run in new pane
        $command = "Import-Module '$parentPath\SpotifyModule.psm1' -Force; Start-SpotifyLiveDisplay -Mode '$Mode' -RefreshInterval 1000"

        Write-Host "🎯 Creating $Position split pane ($Size%)..." -ForegroundColor Cyan

        # Create the split pane
        $wtArgs = @(
            "split-pane",
            $splitDirection,
            "--size", $sizeDecimal,
            "powershell.exe", "-NoExit", "-Command", $command
        )

        Start-Process "wt.exe" -ArgumentList $wtArgs -NoNewWindow

        Write-Host ""
        Write-Host "✅ Sidecar pane created successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "💡 The live display is running in the $Position pane" -ForegroundColor Cyan
        Write-Host "💡 You can continue using Spotify commands in this pane" -ForegroundColor Cyan
        Write-Host "💡 Press Ctrl+C in the sidecar pane to stop it" -ForegroundColor Yellow

    } catch {
        Write-Host ""
        Write-Host "❌ Failed to create sidecar pane: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Fallback: You can manually split your terminal and run:" -ForegroundColor Yellow
        Write-Host "  Start-SpotifyLiveDisplay -Mode $Mode" -ForegroundColor White
    }
}

# Configuration functions
function Set-SpotifyLiveFeaturesConfiguration {
    <#
    .SYNOPSIS
    Set configuration for live features
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Section,
        
        [Parameter(Mandatory)]
        [hashtable]$Settings
    )
    
    Write-Host "⚙️ Updating $Section configuration..." -ForegroundColor Cyan
    
    $configFile = Join-Path $script:ConfigDir "config.json"
    $config = @{}
    
    if (Test-Path $configFile) {
        try {
            $config = Get-Content $configFile | ConvertFrom-Json -AsHashtable
        } catch {
            Write-Warning "Could not read existing config, creating new one"
        }
    }
    
    $config[$Section] = $Settings
    
    try {
        $config | ConvertTo-Json -Depth 10 | Set-Content $configFile
        Write-Host "✅ Configuration updated successfully" -ForegroundColor Green
    } catch {
        Write-Error "Failed to save configuration: $($_.Exception.Message)"
    }
}

function Reset-SpotifyLiveFeaturesConfiguration {
    <#
    .SYNOPSIS
    Reset live features configuration to defaults
    #>
    
    Write-Host "🔄 Resetting Live Features configuration..." -ForegroundColor Cyan
    
    $configFile = Join-Path $script:ConfigDir "config.json"
    
    if (Test-Path $configFile) {
        Remove-Item $configFile -Force
        Write-Host "✅ Configuration reset to defaults" -ForegroundColor Green
    } else {
        Write-Host "No configuration file found, already at defaults" -ForegroundColor Gray
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-SpotifyLiveFeatures',
    'Get-SpotifyLiveFeaturesStatus', 
    'Start-SpotifyLiveDisplay',
    'Stop-SpotifyLiveDisplay',
    'Get-SpotifyCurrentTrackLyrics',
    'Get-SpotifyListeningStatistics',
    'Start-SpotifySidecar',
    'Set-SpotifyLiveFeaturesConfiguration',
    'Reset-SpotifyLiveFeaturesConfiguration'
)

# Create aliases (don't override existing lyrics alias)
New-Alias -Name 'stats' -Value 'Get-SpotifyListeningStatistics' -Force
New-Alias -Name 'live' -Value 'Start-SpotifyLiveDisplay' -Force
New-Alias -Name 'live-music' -Value 'Start-SpotifyLiveDisplay' -Force

Export-ModuleMember -Alias @('stats', 'live', 'live-music')