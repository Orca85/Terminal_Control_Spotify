# Spotify PowerShell Module - Main Orchestrator

# NOTE: Module imports are handled by NestedModules in the manifest (SpotifyCommands.psd1)
# This ensures all functions from nested modules are properly exported

# Check if Live Features are available (loaded via NestedModules)
$script:LiveFeaturesAvailable = $true

# --- Main Module Functions ---

function Show-AllSpotifyCommands {
    Write-Host ""
    Write-Host "  ALL COMMANDS - Terminal Control Spotify" -ForegroundColor Cyan
    Write-Host "  =======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  PLAYBACK" -ForegroundColor Yellow
    Write-Host "    /spotify [compact]          Show current track info" -ForegroundColor Gray
    Write-Host "    /play                       Resume playback" -ForegroundColor Gray
    Write-Host "    /play track <uri>           Play specific track" -ForegroundColor Gray
    Write-Host "    /play album <uri>           Play specific album" -ForegroundColor Gray
    Write-Host "    /play playlist <uri>        Play specific playlist" -ForegroundColor Gray
    Write-Host "    /pause                      Pause playback" -ForegroundColor Gray
    Write-Host "    /next                       Skip to next track" -ForegroundColor Gray
    Write-Host "    /previous                   Go to previous track" -ForegroundColor Gray
    Write-Host "    /seek <seconds>             Seek forward/backward" -ForegroundColor Gray
    Write-Host "    /volume <0-100>             Set volume" -ForegroundColor Gray
    Write-Host "    /shuffle <on|off>           Toggle shuffle" -ForegroundColor Gray
    Write-Host "    /repeat <track|context|off> Set repeat mode" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  LIBRARY" -ForegroundColor Yellow
    Write-Host "    /search <query>             Search tracks, artists, albums" -ForegroundColor Gray
    Write-Host "    /queue <uri>                Add track to queue" -ForegroundColor Gray
    Write-Host "    /play-queue                 Show/manage play queue" -ForegroundColor Gray
    Write-Host "    /playlists                  Show your playlists" -ForegroundColor Gray
    Write-Host "    /liked                      Show liked songs" -ForegroundColor Gray
    Write-Host "    /recent                     Recently played tracks" -ForegroundColor Gray
    Write-Host "    /save                       Like current track" -ForegroundColor Gray
    Write-Host "    /unsave                     Unlike current track" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  DEVICES" -ForegroundColor Yellow
    Write-Host "    /devices                    List Spotify Connect devices" -ForegroundColor Gray
    Write-Host "    /transfer <id>              Transfer playback to device" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  LIVE & DISPLAY" -ForegroundColor Yellow
    Write-Host "    /live [mode]                Live display (detailed/compact/minimal)" -ForegroundColor Gray
    Write-Host "    /sidecar [options]          Split window mode" -ForegroundColor Gray
    Write-Host "    /lyrics [artist - title]    Show synced lyrics" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  FUN" -ForegroundColor Yellow
    Write-Host "    /quiz [rounds]              Multiple choice quiz (artist + song)" -ForegroundColor Gray
    Write-Host "    /peak                       Track insights dashboard" -ForegroundColor Gray
    Write-Host "    /setlist <artist>            Concert setlists + playlist" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  SYSTEM" -ForegroundColor Yellow
    Write-Host "    /config [key] [value]       View/modify configuration" -ForegroundColor Gray
    Write-Host "    /config-live [command]      Live features configuration" -ForegroundColor Gray
    Write-Host "    /history [N|clear]          Playback history" -ForegroundColor Gray
    Write-Host "    /notifications <on|off>     Toggle notifications" -ForegroundColor Gray
    Write-Host "    /auto-refresh <seconds|off> Auto-refresh display" -ForegroundColor Gray
    Write-Host "    /help [command]             Help (detailed per command)" -ForegroundColor Gray
    Write-Host "    /commands                   This list" -ForegroundColor Gray
    Write-Host "    /quit                       Exit the CLI" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ALIASES" -ForegroundColor Yellow
    Write-Host "    pn, plays-now = /spotify    pq = /play-queue    q = /quit" -ForegroundColor DarkGray
    Write-Host ""
}
New-Alias -Name 'commands' -Value 'Show-AllSpotifyCommands' -Force

# Live Features Integration Commands
function Start-SpotifyLive {
    <#
    .SYNOPSIS
    Start Spotify live display mode with real-time updates
    
    .DESCRIPTION
    Launches the live display mode showing current track information with continuous updates.
    Automatically initializes live features if not already done.
    
    .PARAMETER Mode
    Display mode: detailed (default), compact, or minimal
    
    .PARAMETER RefreshInterval
    Update interval in milliseconds (default: 1000)
    
    .EXAMPLE
    Start-SpotifyLive
    Start live display with detailed mode
    
    .EXAMPLE
    Start-SpotifyLive -Mode compact
    Start live display with compact single-line mode
    
    .EXAMPLE
    spotify --live
    Quick alias to start live display
    #>
    
    param(
        [ValidateSet("detailed", "compact", "minimal")]
        [string]$Mode = "detailed",
        
        [int]$RefreshInterval = 1000
    )
    
    if (-not $script:LiveFeaturesAvailable) {
        Write-Host "❌ Live Features not available" -ForegroundColor Red
        Write-Host "💡 Live features require additional modules that may not be installed" -ForegroundColor Yellow
        return
    }
    
    try {
        # Initialize live features if not already done
        if (-not (Get-SpotifyLiveFeaturesStatus).IsInitialized) {
            Write-Host "🔄 Initializing live features..." -ForegroundColor Cyan
            Initialize-SpotifyLiveFeatures
        }
        
        # Update refresh interval if specified
        if ($RefreshInterval -ne 1000) {
            Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
                refreshInterval = $RefreshInterval
            }
        }
        
        Write-Host "🎵 Starting live display mode ($Mode)..." -ForegroundColor Green
        Write-Host "💡 Press Ctrl+C to exit live mode" -ForegroundColor Cyan
        
        Start-SpotifyLiveDisplay -Mode $Mode
        
    } catch {
        Write-Host "❌ Failed to start live display: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Try: spotify --help for troubleshooting" -ForegroundColor Yellow
    }
}

function Get-WindowsTerminalPath {
    # Check if Windows Terminal is installed
    $wtPath = Get-Command wt.exe -ErrorAction SilentlyContinue
    if ($wtPath) {
        return $wtPath.Source
    }

    # Check common install locations
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe",
        "$env:ProgramFiles\WindowsApps\Microsoft.WindowsTerminal*\wt.exe"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

function Start-SpotifyCliInNewWindow {
    param(
        [switch]$Live,
        [string]$ScriptPath = $PSCommandPath
    )

    try {
        $arguments = if ($Live) { "-NoExit -Command `"Import-Module '$PSScriptRoot\SpotifyModule.psm1' -Force; Start-SpotifyLive`"" } else { "-NoExit -File `"$ScriptPath`"" }
        Start-Process pwsh -ArgumentList $arguments
        return $true
    } catch {
        Write-Warning "Failed to start new window: $($_.Exception.Message)"
        return $false
    }
}

function Start-SpotifyCliInWindowsTerminalSplit {
    param(
        [ValidateSet("right", "down", "left", "up")]
        [string]$SplitDirection = "right",
        [int]$Width = 40,
        [switch]$Live
    )

    $wtPath = Get-WindowsTerminalPath
    if (-not $wtPath) {
        throw "Windows Terminal not found"
    }

    # Map direction to wt.exe split parameter
    $splitParam = switch ($SplitDirection) {
        "right" { "--horizontal" }
        "left" { "--horizontal" }
        "down" { "--vertical" }
        "up" { "--vertical" }
    }

    # Convert percentage to decimal (40 -> 0.4)
    $sizeDecimal = [Math]::Max(0.01, [Math]::Min(0.99, $Width / 100.0))

    # Get absolute path to module
    $modulePath = Join-Path $PSScriptRoot "SpotifyModule.psm1"

    # Build command with properly escaped paths
    if ($Live) {
        $cmd = "Import-Module -Force '$modulePath'; Start-SpotifyLive"
    } else {
        $cmd = "Import-Module -Force '$modulePath'"
    }

    # Use wt.exe with proper argument structure
    $wtArgs = @(
        'split-pane'
        $splitParam
        '--size'
        $sizeDecimal.ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture)
        'pwsh.exe'
        '-NoExit'
        '-Command'
        $cmd
    )

    & $wtPath @wtArgs
}

function Start-SpotifySidecar {
    <#
    .SYNOPSIS
    Start Spotify in sidecar mode (split window)
    
    .DESCRIPTION
    Launches Spotify CLI in a split window/sidecar mode if supported by the terminal.
    Falls back to new window if split mode is not available.
    
    .PARAMETER Position
    Position for split window: right (default), down, left, up
    
    .PARAMETER Width
    Width percentage for split (default: 40)
    
    .EXAMPLE
    Start-SpotifySidecar
    Start sidecar mode on the right side
    
    .EXAMPLE
    Start-SpotifySidecar -Position down -Width 30
    Start sidecar mode below current pane with 30% width
    
    .EXAMPLE
    spotify --sidecar
    Quick alias to start sidecar mode
    #>
    
    param(
        [ValidateSet("right", "down", "left", "up")]
        [string]$Position = "right",
        
        [int]$Width = 40
    )
    
    # Check if Windows Terminal is available
    $wtPath = Get-WindowsTerminalPath
    if (-not $wtPath) {
        Write-Host "⚠️ Windows Terminal not detected" -ForegroundColor Yellow
        Write-Host "💡 Falling back to new window mode..." -ForegroundColor Cyan
        Start-SpotifyCliInNewWindow -Live
        return
    }
    
    try {
        Write-Host "🪟 Starting Spotify CLI in sidecar mode..." -ForegroundColor Cyan
        Start-SpotifyCliInWindowsTerminalSplit -SplitDirection $Position -Width $Width -Live
        
    } catch {
        Write-Host "❌ Failed to start sidecar mode: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Falling back to new window..." -ForegroundColor Yellow
        Start-SpotifyCliInNewWindow -Live
    }
}

function Get-SpotifyLyrics {
    <#
    .SYNOPSIS
    Get and display lyrics for current or specified track

    .DESCRIPTION
    Fetches lyrics from external providers (LRCLIB, Genius, Musixmatch) and displays them
    with optional scrolling, synchronized highlighting, and karaoke mode.

    .PARAMETER Artist
    Artist name (optional - uses current track if not specified)

    .PARAMETER Track
    Track name (optional - uses current track if not specified)

    .PARAMETER Scroll
    Enable scrollable display with keyboard navigation

    .PARAMETER Karaoke
    Enable karaoke mode with synchronized lyrics (if available)

    .PARAMETER Provider
    Lyrics provider to use: auto (default), genius, musixmatch, mock

    .EXAMPLE
    Get-SpotifyLyrics
    Get lyrics for currently playing track

    .EXAMPLE
    Get-SpotifyLyrics -Artist "Queen" -Track "Bohemian Rhapsody"
    Get lyrics for specific track

    .EXAMPLE
    Get-SpotifyLyrics -Karaoke
    Display lyrics in karaoke mode synced with playback

    .EXAMPLE
    lyrics
    Quick alias to get current track lyrics
    #>

    param(
        [string]$Artist,
        [string]$Track,
        [switch]$Scroll,
        [switch]$Karaoke,

        [ValidateSet("auto", "genius", "musixmatch", "mock")]
        [string]$Provider = "auto"
    )

    try {
        # Get current track info if not specified
        if (-not $Artist -or -not $Track) {
            Write-Host "🎵 Getting current track info..." -ForegroundColor Cyan
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"

            if (-not $currentTrack -or -not $currentTrack.item) {
                Write-Host "❌ No track currently playing" -ForegroundColor Red
                return
            }

            $item = $currentTrack.item
            $Artist = ($item.artists | ForEach-Object { $_.name }) -join ", "
            $Track = $item.name
        }

        Write-Host "🎤 Fetching lyrics for: $Artist - $Track" -ForegroundColor Green
        Write-Host ""

        # Import Lyrics Engine
        $lyricsModulePath = Join-Path $PSScriptRoot "modules\Lyrics\LyricsEngine.psm1"
        if (Test-Path $lyricsModulePath) {
            Import-Module $lyricsModulePath -Force -ErrorAction SilentlyContinue

            # Configure provider
            $config = @{
                DataDirectory = Join-Path $env:APPDATA "SpotifyCLI\Lyrics"
                CacheEnabled = $true
                CacheTtlDays = 30
            }

            # Add API keys if available
            if ($env:GENIUS_ACCESS_TOKEN) {
                $config.GeniusApiKey = $env:GENIUS_ACCESS_TOKEN
            }
            if ($env:MUSIXMATCH_API_KEY) {
                $config.MusixmatchApiKey = $env:MUSIXMATCH_API_KEY
            }

            # Create lyrics manager
            $lyricsManager = New-LyricsManager -Configuration $config

            # Fetch lyrics
            Write-Host "🔍 Searching for lyrics..." -ForegroundColor Cyan
            $result = $lyricsManager.GetLyrics($Artist, $Track)

            if ($result.Success) {
                Write-Host "✅ Lyrics found!" -ForegroundColor Green
                Write-Host "📝 Source: $($result.Source)" -ForegroundColor Gray
                Write-Host ""

                if ($Karaoke -and $result.HasSyncedLyrics) {
                    # Use Windows Form for karaoke mode (no flicker!)
                    $lyricsFormPath = Join-Path $PSScriptRoot "modules\UI\LyricsFormDisplay.psm1"
                    if (Test-Path $lyricsFormPath) {
                        Import-Module $lyricsFormPath -Force -ErrorAction SilentlyContinue

                        # Get current playback position
                        $currentPlayback = Invoke-SpotifyApi -Method GET -Path "/me/player"
                        $initialPositionMs = if ($currentPlayback -and $currentPlayback.progress_ms) {
                            $currentPlayback.progress_ms
                        } else {
                            0
                        }

                        Show-LyricsForm -LyricsData $result -InitialPositionMs $initialPositionMs
                    } else {
                        Write-Host "❌ Lyrics Form module not found" -ForegroundColor Red
                    }
                } elseif ($Scroll) {
                    Write-Host "📜 Scrollable Lyrics View" -ForegroundColor Cyan
                    Write-Host ("=" * 60) -ForegroundColor DarkGray
                    Write-Host ""
                    Write-Host "💡 Use arrow keys to scroll, 'q' to quit" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host $result.FullText -ForegroundColor White
                } else {
                    # Standard display
                    Write-Host "📄 Lyrics" -ForegroundColor Cyan
                    Write-Host ("=" * 60) -ForegroundColor DarkGray
                    Write-Host ""
                    Write-Host $result.FullText -ForegroundColor White
                }

                if ($result.HasSyncedLyrics) {
                    Write-Host ""
                    Write-Host "🎤 Synchronized lyrics available! Try: lyrics -Karaoke" -ForegroundColor Green
                }

                if ($result.Url) {
                    Write-Host ""
                    Write-Host "🔗 Full lyrics at: $($result.Url)" -ForegroundColor Cyan
                }

            } else {
                Write-Host "❌ Lyrics not found" -ForegroundColor Red
                Write-Host ""

                # Show configuration help
                Write-Host "💡 To enable real lyrics providers:" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Genius (recommended):" -ForegroundColor Cyan
                Write-Host "  1. Get API token: https://genius.com/api-clients" -ForegroundColor Gray
                Write-Host '  2. Set: $env:GENIUS_ACCESS_TOKEN = "your_token"' -ForegroundColor Gray
                Write-Host ""
                Write-Host "Musixmatch:" -ForegroundColor Cyan
                Write-Host "  1. Get API key: https://developer.musixmatch.com/" -ForegroundColor Gray
                Write-Host '  2. Set: $env:MUSIXMATCH_API_KEY = "your_key"' -ForegroundColor Gray
                Write-Host ""
                Write-Host "Current status:" -ForegroundColor Yellow
                $geniusStatus = if ($env:GENIUS_ACCESS_TOKEN) { "✅" } else { "❌" }
                $musixStatus = if ($env:MUSIXMATCH_API_KEY) { "✅" } else { "❌" }
                Write-Host "  Genius: $geniusStatus" -ForegroundColor White
                Write-Host "  Musixmatch: $musixStatus" -ForegroundColor White
            }
        } else {
            Write-Host "❌ Lyrics Engine not found" -ForegroundColor Red
            Write-Host "💡 Lyrics module may not be properly installed" -ForegroundColor Yellow
        }

    } catch {
        Write-Host "❌ Failed to get lyrics: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose $_.ScriptStackTrace
    }
}

function Show-SpotifyLyricsForm {
    <#
    .SYNOPSIS
    Show lyrics in a Windows Form window with real-time highlighting

    .DESCRIPTION
    Opens a non-blocking Windows Form that displays synchronized lyrics
    with highlighting that follows the currently playing track.

    .PARAMETER Artist
    Artist name (optional - uses current track if not specified)

    .PARAMETER Track
    Track name (optional - uses current track if not specified)

    .EXAMPLE
    Show-SpotifyLyricsForm
    Show lyrics for currently playing track

    .EXAMPLE
    slw
    Quick alias to show lyrics window (slw = Show Lyrics Window)

    .EXAMPLE
    ShowLyrics
    Alternative alias to show lyrics window
    #>

    param(
        [string]$Artist,
        [string]$Track
    )

    try {
        # Get current track info if not specified
        if (-not $Artist -or -not $Track) {
            Write-Host "🎵 Getting current track info..." -ForegroundColor Cyan
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"

            if (-not $currentTrack -or -not $currentTrack.item) {
                Write-Host "❌ No track currently playing" -ForegroundColor Red
                return
            }

            $item = $currentTrack.item
            $Artist = ($item.artists | ForEach-Object { $_.name }) -join ", "
            $Track = $item.name
        }

        Write-Host "🎤 Fetching lyrics for: $Artist - $Track" -ForegroundColor Green

        # Import Lyrics Engine
        $lyricsModulePath = Join-Path $PSScriptRoot "modules\Lyrics\LyricsEngine.psm1"
        if (Test-Path $lyricsModulePath) {
            Import-Module $lyricsModulePath -Force -ErrorAction SilentlyContinue

            # Configure
            $config = @{
                DataDirectory = Join-Path $env:APPDATA "SpotifyCLI\Lyrics"
                CacheEnabled = $true
                CacheTtlDays = 30
            }

            if ($env:GENIUS_ACCESS_TOKEN) {
                $config.GeniusApiKey = $env:GENIUS_ACCESS_TOKEN
            }
            if ($env:MUSIXMATCH_API_KEY) {
                $config.MusixmatchApiKey = $env:MUSIXMATCH_API_KEY
            }

            # Create lyrics manager
            $lyricsManager = New-LyricsManager -Configuration $config

            # Fetch lyrics
            $result = $lyricsManager.GetLyrics($Artist, $Track)

            if ($result.Success) {
                # Import and show form
                $lyricsFormPath = Join-Path $PSScriptRoot "modules\UI\LyricsFormDisplay.psm1"
                if (Test-Path $lyricsFormPath) {
                    Import-Module $lyricsFormPath -Force -ErrorAction SilentlyContinue

                    # Get current playback position
                    $currentPlayback = Invoke-SpotifyApi -Method GET -Path "/me/player"
                    $initialPositionMs = if ($currentPlayback -and $currentPlayback.progress_ms) {
                        $currentPlayback.progress_ms
                    } else {
                        0
                    }

                    Show-LyricsForm -LyricsData $result -InitialPositionMs $initialPositionMs
                } else {
                    Write-Host "❌ Lyrics Form module not found" -ForegroundColor Red
                }
            } else {
                Write-Host "❌ Lyrics not found: $($result.Error)" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ Lyrics Engine not found" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Failed to show lyrics: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose $_.ScriptStackTrace
    }
}

function Get-SpotifyStats {
    <#
    .SYNOPSIS
    Display comprehensive listening statistics and analytics
    
    .DESCRIPTION
    Shows detailed statistics about listening habits including top tracks, artists,
    genres, listening patterns, and visualizations.
    
    .PARAMETER Period
    Time period for statistics: day, week, month (default), or year
    
    .PARAMETER Type
    Type of statistics: summary (default), tracks, artists, genres, patterns, or export
    
    .PARAMETER Export
    Export statistics to file (CSV or JSON)
    .PARAMETER Interactive
    Launch interactive statistics menu
    
    .EXAMPLE
    Get-SpotifyStats
    Show monthly statistics summary
    
    .EXAMPLE
    Get-SpotifyStats -Period week -Type tracks
    Show top tracks for the past week
    
    .EXAMPLE
    Get-SpotifyStats -Interactive
    Launch interactive statistics menu
    
    .EXAMPLE
    stats
    Quick alias for statistics
    #>
    
    param(
        [ValidateSet("day", "week", "month", "year")]
        [string]$Period = "month",
        
        [ValidateSet("summary", "tracks", "artists", "genres", "patterns", "export")]
        [string]$Type = "summary",
        
        [ValidateSet("csv", "json")]
        [string]$Export,
        
        [switch]$Interactive
    )
    
    if (-not $script:LiveFeaturesAvailable) {
        Write-Host "❌ Statistics feature not available" -ForegroundColor Red
        Write-Host "💡 Statistics require additional modules that may not be installed" -ForegroundColor Yellow
        return
    }
    
    try {
        # Initialize live features if not already done
        if (-not (Get-SpotifyLiveFeaturesStatus).IsInitialized) {
            Write-Host "🔄 Initializing live features..." -ForegroundColor Cyan
            Initialize-SpotifyLiveFeatures
        }
        
        if ($Interactive) {
            # TODO: Launch interactive menu
            Write-Host "📊 Interactive Statistics Menu" -ForegroundColor Cyan
            Write-Host "💡 Interactive mode coming soon - showing summary for now" -ForegroundColor Yellow
        }
        
        Write-Host "📊 Generating $Period statistics..." -ForegroundColor Cyan
        
        $statsReport = Get-SpotifyListeningStatistics -Period $Period
        
        if ($statsReport) {
            Write-Host "✅ Statistics generated successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host $statsReport
            
            if ($Export) {
                $exportPath = Join-Path $env:USERPROFILE "Desktop" "spotify-stats-$Period-$(Get-Date -Format 'yyyyMMdd').$Export"
                # TODO: Implement export functionality
                Write-Host "💾 Export to $Export format coming soon" -ForegroundColor Yellow
                Write-Host "📁 Would save to: $exportPath" -ForegroundColor Gray
            }
        } else {
            Write-Host "❌ No statistics data available" -ForegroundColor Red
            Write-Host "💡 Statistics are collected when you use the live features" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "❌ Failed to generate statistics: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-SpotifyLiveFeatures {
    <#
    .SYNOPSIS
    Test and diagnose live features functionality
    
    .DESCRIPTION
    Runs comprehensive tests on all live feature components and provides
    diagnostic information for troubleshooting.
    
    .EXAMPLE
    Test-SpotifyLiveFeatures
    Run full diagnostic test
    #>
    
    Write-Host "🔍 Testing Spotify Live Features..." -ForegroundColor Cyan
    Write-Host ""
    
    # Test module availability
    Write-Host "📦 Module Availability:" -ForegroundColor Yellow
    if ($script:LiveFeaturesAvailable) {
        Write-Host "  ✅ Live Features module loaded" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Live Features module not available" -ForegroundColor Red
        Write-Host "  💡 Check if modules directory exists and contains required files" -ForegroundColor Gray
        Show-LiveFeaturesTroubleshootingGuide -Issue "ModuleNotFound"
        return
    }
    
    # Test initialization
    Write-Host ""
    Write-Host "🔄 Initialization Test:" -ForegroundColor Yellow
    try {
        if (-not (Get-SpotifyLiveFeaturesStatus).IsInitialized) {
            Write-Host "  🔄 Initializing live features..." -ForegroundColor Cyan
            Initialize-SpotifyLiveFeatures
        }
        Write-Host "  ✅ Live Features initialized successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        Show-LiveFeaturesTroubleshootingGuide -Issue "InitializationFailed" -ErrorMessage $_.Exception.Message
        return
    }
    
    # Test feature status
    Write-Host ""
    Write-Host "📊 Feature Status:" -ForegroundColor Yellow
    $status = Get-SpotifyLiveFeaturesStatus
    $failedFeatures = @()
    foreach ($feature in $status.Features.Keys) {
        $icon = if ($status.Features[$feature]) { "✅" } else { "❌" }
        Write-Host "  $icon $feature" -ForegroundColor White
        if (-not $status.Features[$feature]) {
            $failedFeatures += $feature
        }
    }
    
    if ($failedFeatures.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠️ Some features are not available:" -ForegroundColor Yellow
        foreach ($feature in $failedFeatures) {
            Show-LiveFeaturesTroubleshootingGuide -Issue "FeatureUnavailable" -Feature $feature
        }
    }
    
    # Test API connectivity
    Write-Host ""
    Write-Host "🌐 API Connectivity:" -ForegroundColor Yellow
    try {
        $currentTrack = Show-SpotifyTrack
        Write-Host "  ✅ Spotify API accessible" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Spotify API error: $($_.Exception.Message)" -ForegroundColor Red
        Show-LiveFeaturesTroubleshootingGuide -Issue "ApiConnectivity" -ErrorMessage $_.Exception.Message
    }
    
    # Test terminal capabilities
    Write-Host ""
    Write-Host "🖥️ Terminal Capabilities:" -ForegroundColor Yellow
    $terminalCaps = Get-TerminalCapabilities
    Write-Host "  Terminal: $($terminalCaps.TerminalType)" -ForegroundColor White
    Write-Host "  ANSI Support: $(if ($terminalCaps.SupportsAnsi) { '✅' } else { '❌' })" -ForegroundColor White
    Write-Host "  Split Window: $(if ($terminalCaps.SupportsSplitWindow) { '✅' } else { '❌' })" -ForegroundColor White
    
    # Test configuration
    Write-Host ""
    Write-Host "⚙️ Configuration:" -ForegroundColor Yellow
    try {
        $config = Get-LiveFeaturesConfig
        Write-Host "  ✅ Configuration loaded successfully" -ForegroundColor Green
        Write-Host "  📁 Config location: $($config.ConfigPath)" -ForegroundColor Gray
    } catch {
        Write-Host "  ❌ Configuration error: $($_.Exception.Message)" -ForegroundColor Red
        Show-LiveFeaturesTroubleshootingGuide -Issue "ConfigurationError" -ErrorMessage $_.Exception.Message
        return
    }
    
    Write-Host ""
    Write-Host "✅ Live Features diagnostic complete!" -ForegroundColor Green
    
    if ($failedFeatures.Count -eq 0) {
        Write-Host "🎉 All features are working correctly!" -ForegroundColor Green
        Write-Host "💡 Try: live, sidecar, lyrics, or stats commands" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️ Some features need attention. See troubleshooting suggestions above." -ForegroundColor Yellow
    }
}

function Show-LiveFeaturesTroubleshootingGuide {
    <#
    .SYNOPSIS
    Display targeted troubleshooting guidance for live features issues
    
    .PARAMETER Issue
    The specific issue type to provide guidance for
    
    .PARAMETER Feature
    The specific feature that's having issues
    
    .PARAMETER ErrorMessage
    The error message to help diagnose the issue
    #>
    
    param(
        [Parameter(Mandatory)]
        [ValidateSet("ModuleNotFound", "InitializationFailed", "FeatureUnavailable", "ApiConnectivity", "ConfigurationError")]
        [string]$Issue,
        
        [string]$Feature,
        [string]$ErrorMessage
    )
    
    Write-Host ""
    Write-Host "🔧 TROUBLESHOOTING GUIDE:" -ForegroundColor Yellow
    
    switch ($Issue) {
        "ModuleNotFound" {
            Write-Host "❌ Live Features module not found" -ForegroundColor Red
            Write-Host ""
            Write-Host "POSSIBLE CAUSES:" -ForegroundColor Yellow
            Write-Host "• Incomplete installation or missing files" -ForegroundColor White
            Write-Host "• Modules directory not in correct location" -ForegroundColor White
            Write-Host "• File permissions preventing module loading" -ForegroundColor White
            Write-Host ""
            Write-Host "SOLUTIONS:" -ForegroundColor Green
            Write-Host "1. Check if modules directory exists:" -ForegroundColor White
            Write-Host "   Test-Path '$PSScriptRoot\modules\SpotifyLiveFeatures.psm1'" -ForegroundColor Gray
            Write-Host "2. Verify file permissions allow reading" -ForegroundColor White
            Write-Host "3. Try running PowerShell as Administrator" -ForegroundColor White
            Write-Host "4. Reinstall the Spotify CLI if files are missing" -ForegroundColor White
        }
        
        "InitializationFailed" {
            Write-Host "❌ Live Features initialization failed" -ForegroundColor Red
            Write-Host "Error: $ErrorMessage" -ForegroundColor Gray
            Write-Host ""
            Write-Host "COMMON CAUSES:" -ForegroundColor Yellow
            Write-Host "• Missing dependencies or PowerShell modules" -ForegroundColor White
            Write-Host "• Insufficient permissions for configuration directory" -ForegroundColor White
            Write-Host "• Corrupted configuration files" -ForegroundColor White
            Write-Host ""
            Write-Host "SOLUTIONS:" -ForegroundColor Green
            Write-Host "1. Reset configuration:" -ForegroundColor White
            Write-Host "   Reset-LiveFeaturesConfig" -ForegroundColor Gray
            Write-Host "2. Check PowerShell execution policy:" -ForegroundColor White
            Write-Host "   Get-ExecutionPolicy" -ForegroundColor Gray
            Write-Host "3. Clear configuration directory:" -ForegroundColor White
            Write-Host "   Remove-Item '$env:APPDATA\SpotifyCLI\LiveFeatures' -Recurse -Force" -ForegroundColor Gray
            Write-Host "4. Restart PowerShell session" -ForegroundColor White
        }
        
        "FeatureUnavailable" {
            Write-Host "❌ Feature '$Feature' is not available" -ForegroundColor Red
            Write-Host ""
            switch ($Feature) {
                "LiveDisplay" {
                    Write-Host "LIVE DISPLAY ISSUES:" -ForegroundColor Yellow
                    Write-Host "• Terminal may not support ANSI escape codes" -ForegroundColor White
                    Write-Host "• Console output redirection may be interfering" -ForegroundColor White
                    Write-Host ""
                    Write-Host "SOLUTIONS:" -ForegroundColor Green
                    Write-Host "• Use Windows Terminal or PowerShell 7+" -ForegroundColor White
                    Write-Host "• Avoid running in ISE or basic console" -ForegroundColor White
                }
                "Lyrics" {
                    Write-Host "LYRICS ENGINE ISSUES:" -ForegroundColor Yellow
                    Write-Host "• Internet connection required for lyrics providers" -ForegroundColor White
                    Write-Host "• API rate limits may be exceeded" -ForegroundColor White
                    Write-Host ""
                    Write-Host "SOLUTIONS:" -ForegroundColor Green
                    Write-Host "• Check internet connectivity" -ForegroundColor White
                    Write-Host "• Wait a few minutes if rate limited" -ForegroundColor White
                }
                "Statistics" {
                    Write-Host "STATISTICS ENGINE ISSUES:" -ForegroundColor Yellow
                    Write-Host "• Database initialization may have failed" -ForegroundColor White
                    Write-Host "• Insufficient disk space for statistics storage" -ForegroundColor White
                    Write-Host ""
                    Write-Host "SOLUTIONS:" -ForegroundColor Green
                    Write-Host "• Check available disk space" -ForegroundColor White
                    Write-Host "• Reset statistics database" -ForegroundColor White
                }
                "ApiClient" {
                    Write-Host "API CLIENT ISSUES:" -ForegroundColor Yellow
                    Write-Host "• Spotify authentication may have expired" -ForegroundColor White
                    Write-Host "• Network connectivity issues" -ForegroundColor White
                    Write-Host ""
                    Write-Host "SOLUTIONS:" -ForegroundColor Green
                    Write-Host "• Re-authenticate: .\spotifyCLI.psm1" -ForegroundColor White
                    Write-Host "• Check network connection" -ForegroundColor White
                }
            }
        }
        
        "ApiConnectivity" {
            Write-Host "❌ Spotify API connectivity issues" -ForegroundColor Red
            Write-Host "Error: $ErrorMessage" -ForegroundColor Gray
            Write-Host ""
            Write-Host "COMMON CAUSES:" -ForegroundColor Yellow
            Write-Host "• Authentication token expired or invalid" -ForegroundColor White
            Write-Host "• Network connectivity issues" -ForegroundColor White
            Write-Host "• Spotify API service issues" -ForegroundColor White
            Write-Host "• Firewall blocking connections" -ForegroundColor White
            Write-Host ""
            Write-Host "SOLUTIONS:" -ForegroundColor Green
            Write-Host "1. Re-authenticate with Spotify:" -ForegroundColor White
            Write-Host "   .\spotifyCLI.psm1" -ForegroundColor Gray
            Write-Host "2. Test network connectivity:" -ForegroundColor White
            Write-Host "   Test-NetConnection api.spotify.com -Port 443" -ForegroundColor Gray
            Write-Host "3. Check Spotify service status online" -ForegroundColor White
            Write-Host "4. Temporarily disable firewall/antivirus" -ForegroundColor White
        }
        
        "ConfigurationError" {
            Write-Host "❌ Configuration system error" -ForegroundColor Red
            Write-Host "Error: $ErrorMessage" -ForegroundColor Gray
            Write-Host ""
            Write-Host "SOLUTIONS:" -ForegroundColor Green
            Write-Host "1. Reset to default configuration:" -ForegroundColor White
            Write-Host "   Reset-LiveFeaturesConfig" -ForegroundColor Gray
            Write-Host "2. Check configuration directory permissions:" -ForegroundColor White
            Write-Host "   Test-Path '$env:APPDATA\SpotifyCLI\LiveFeatures' -PathType Container" -ForegroundColor Gray
            Write-Host "3. Manually recreate configuration directory:" -ForegroundColor White
            Write-Host "   New-Item '$env:APPDATA\SpotifyCLI\LiveFeatures' -ItemType Directory -Force" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "💡 For more help, visit: https://github.com/your-repo/spotify-cli/wiki/Troubleshooting" -ForegroundColor Cyan
}

function Show-ProgressIndicator {
    <#
    .SYNOPSIS
    Display a progress indicator for long-running operations
    
    .PARAMETER Activity
    Description of the current activity
    
    .PARAMETER Status
    Current status message
    
    .PARAMETER PercentComplete
    Percentage complete (0-100)
    
    .PARAMETER Id
    Unique identifier for this progress indicator
    #>
    
    param(
        [Parameter(Mandatory)]
        [string]$Activity,
        
        [string]$Status = "Processing...",
        
        [ValidateRange(0, 100)]
        [int]$PercentComplete = -1,
        
        [int]$Id = 1
    )
    
    if ($PercentComplete -ge 0) {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -Id $Id
    } else {
        Write-Progress -Activity $Activity -Status $Status -Id $Id
    }
}

function Hide-ProgressIndicator {
    <#
    .SYNOPSIS
    Hide a progress indicator
    
    .PARAMETER Id
    Unique identifier of the progress indicator to hide
    #>
    
    param(
        [int]$Id = 1
    )
    
    Write-Progress -Activity "Complete" -Completed -Id $Id
}

function Show-UserFriendlyError {
    <#
    .SYNOPSIS
    Display user-friendly error messages with actionable suggestions
    
    .PARAMETER ErrorRecord
    The PowerShell error record
    
    .PARAMETER Context
    Context about what operation was being performed
    .PARAMETER Suggestions
    Array of suggested solutions
    #>
    
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [string]$Context = "operation",
        
        [string[]]$Suggestions = @()
    )
    
    Write-Host ""
    Write-Host "❌ Error during $Context" -ForegroundColor Red
    Write-Host ""
    
    # Extract meaningful error information
    $errorMessage = $ErrorRecord.Exception.Message
    $errorType = $ErrorRecord.Exception.GetType().Name
    
    # Categorize common errors and provide specific guidance
    switch -Regex ($errorMessage) {
        "401|Unauthorized" {
            Write-Host "🔐 AUTHENTICATION ERROR" -ForegroundColor Yellow
            Write-Host "Your Spotify session has expired or is invalid." -ForegroundColor White
            Write-Host ""
            Write-Host "SOLUTION:" -ForegroundColor Green
            Write-Host "• Run: .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor White
            Write-Host "• Make sure you're logged into Spotify" -ForegroundColor White
        }
        
        "403|Forbidden" {
            Write-Host "🚫 PERMISSION ERROR" -ForegroundColor Yellow
            Write-Host "This operation requires Spotify Premium or additional permissions." -ForegroundColor White
            Write-Host ""
            Write-Host "SOLUTIONS:" -ForegroundColor Green
            Write-Host "• Upgrade to Spotify Premium for full functionality" -ForegroundColor White
            Write-Host "• Some features work with free accounts (viewing, searching)" -ForegroundColor White
        }
        
        "404|Not Found" {
            Write-Host "❓ RESOURCE NOT FOUND" -ForegroundColor Yellow
            Write-Host "The requested item could not be found." -ForegroundColor White
            Write-Host ""
            Write-Host "POSSIBLE CAUSES:" -ForegroundColor Green
            Write-Host "• Track, album, or playlist no longer available" -ForegroundColor White
            Write-Host "• Content not available in your region" -ForegroundColor White
            Write-Host "• Invalid Spotify URI or ID" -ForegroundColor White
        }
        
        "429|Rate.*limit" {
            Write-Host "⏳ RATE LIMIT EXCEEDED" -ForegroundColor Yellow
            Write-Host "Too many requests sent to Spotify. Please wait before trying again." -ForegroundColor White
            Write-Host ""
            Write-Host "SOLUTION:" -ForegroundColor Green
            Write-Host "• Wait 1-2 minutes before retrying" -ForegroundColor White
            Write-Host "• The system will automatically retry with delays" -ForegroundColor White
        }
        
        "network|connection|timeout" {
            Write-Host "🌐 NETWORK ERROR" -ForegroundColor Yellow
            Write-Host "Unable to connect to Spotify services." -ForegroundColor White
            Write-Host ""
            Write-Host "SOLUTIONS:" -ForegroundColor Green
            Write-Host "• Check your internet connection" -ForegroundColor White
            Write-Host "• Try again in a few moments" -ForegroundColor White
            Write-Host "• Check if Spotify services are operational" -ForegroundColor White
        }
        
        default {
            Write-Host "⚠️ UNEXPECTED ERROR" -ForegroundColor Yellow
            Write-Host "Error Type: $errorType" -ForegroundColor Gray
            Write-Host "Message: $errorMessage" -ForegroundColor White
        }
    }
    
    # Show custom suggestions if provided
    if ($Suggestions.Count -gt 0) {
        Write-Host ""
        Write-Host "ADDITIONAL SUGGESTIONS:" -ForegroundColor Cyan
        foreach ($suggestion in $Suggestions) {
            Write-Host "• $suggestion" -ForegroundColor White
        }
    }
    
    # Always show general help
    Write-Host ""
    Write-Host "💡 For more help:" -ForegroundColor Cyan
    Write-Host "• Run: Get-SpotifyHelp" -ForegroundColor White
    Write-Host "• Run: Test-SpotifyLiveFeatures for diagnostics" -ForegroundColor White
    Write-Host "• Check: https://github.com/your-repo/spotify-cli/issues" -ForegroundColor White
}

function Show-SpotifyWelcome {
    <#
    .SYNOPSIS
    Display welcome message and feature discovery for new users
    
    .DESCRIPTION
    Shows an interactive welcome screen that introduces users to available features
    and helps them get started with the Spotify CLI.
    
    .PARAMETER FirstTime
    Whether this is a first-time user
    .PARAMETER ShowLiveFeatures
    Whether to highlight the new live features
    
    .EXAMPLE
    Show-SpotifyWelcome -FirstTime
    #>
    
    param(
        [switch]$FirstTime,
        [switch]$ShowLiveFeatures
    )
    
    Clear-Host
    
    Write-Host "🎵 Welcome to Spotify CLI - Enhanced Edition!" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($FirstTime) {
        Write-Host "🎉 Thank you for installing Spotify CLI!" -ForegroundColor Green
        Write-Host "This enhanced version includes powerful new features to transform your music experience." -ForegroundColor White
        Write-Host ""
    }
    
    if ($ShowLiveFeatures -or $FirstTime) {
        Write-Host "✨ NEW LIVE FEATURES:" -ForegroundColor Magenta
        Write-Host "• 🎵 Real-time Live Display - See current track with continuous updates" -ForegroundColor White
        Write-Host "• 🪟 Sidecar Mode - Split window display for multitasking" -ForegroundColor White
        Write-Host "• 📝 Lyrics Integration - View lyrics with synchronized highlighting" -ForegroundColor White
        Write-Host "• 📊 Advanced Statistics - Detailed listening analytics and patterns" -ForegroundColor White
        Write-Host ""
    }
    
    Write-Host "🚀 QUICK START GUIDE:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. BASIC PLAYBACK:" -ForegroundColor Cyan
    Write-Host "   spotify          # Launch Spotify app" -ForegroundColor Gray
    Write-Host "   plays-now        # Show current track" -ForegroundColor Gray
    Write-Host "   play / pause     # Control playback" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "2. NEW LIVE FEATURES:" -ForegroundColor Cyan
    Write-Host "   live             # Start real-time display" -ForegroundColor Gray
    Write-Host "   sidecar          # Open in split window" -ForegroundColor Gray
    Write-Host "   lyrics           # Show current track lyrics" -ForegroundColor Gray
    Write-Host "   stats            # View listening statistics" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "3. SEARCH & DISCOVERY:" -ForegroundColor Cyan
    Write-Host "   search 'artist'  # Find music" -ForegroundColor Gray
    Write-Host "   playlists        # Browse your playlists" -ForegroundColor Gray
    Write-Host "   liked            # Show liked songs" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "4. ADVANCED FEATURES:" -ForegroundColor Cyan
    Write-Host "   devices          # Manage playback devices" -ForegroundColor Gray
    Write-Host "   volume 75        # Set volume" -ForegroundColor Gray
    Write-Host "   shuffle on       # Enable shuffle" -ForegroundColor Gray
    Write-Host ""
    
    # Check system capabilities
    Write-Host "🖥️ SYSTEM CAPABILITIES:" -ForegroundColor Yellow
    $terminalCaps = Get-TerminalCapabilities
    Write-Host "Terminal: $($terminalCaps.TerminalType)" -ForegroundColor White
    Write-Host "Live Display: $(if ($terminalCaps.SupportsAnsi) { '✅ Supported' } else { '❌ Limited' })" -ForegroundColor White
    Write-Host "Split Windows: $(if ($terminalCaps.SupportsSplitWindow) { '✅ Available' } else { '❌ Not Available' })" -ForegroundColor White
    
    # Check live features availability
    if ($script:LiveFeaturesAvailable) {
        Write-Host "Live Features: ✅ Ready" -ForegroundColor Green
    } else {
        Write-Host "Live Features: ⚠️ Limited (some modules not available)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "💡 GETTING HELP:" -ForegroundColor Cyan
    Write-Host "• Get-SpotifyHelp                    # Complete command reference" -ForegroundColor White
    Write-Host "• Get-SpotifyHelp COMMAND          # Specific command help" -ForegroundColor White
    Write-Host "• Test-SpotifyLiveFeatures           # Diagnose any issues" -ForegroundColor White
    Write-Host ""
    
    # Interactive feature discovery
    if ($FirstTime) {
        Write-Host "🎯 FEATURE DISCOVERY:" -ForegroundColor Green
        Write-Host "Would you like to try the new features? (Choose a number or press Enter to skip)" -ForegroundColor White
        Write-Host ""
        Write-Host "1. 🎵 Try Live Display Mode" -ForegroundColor Cyan
        Write-Host "2. 📝 Get Lyrics for Current Track" -ForegroundColor Cyan
        Write-Host "3. 📊 View Listening Statistics" -ForegroundColor Cyan
        Write-Host "4. 🪟 Open Sidecar Mode" -ForegroundColor Cyan
        Write-Host "5. 🔍 Run System Diagnostics" -ForegroundColor Cyan
        Write-Host ""
        
        $choice = Read-Host "Enter your choice (1-5) or press Enter to continue"
        
        switch ($choice) {
            "1" {
                Write-Host "🎵 Starting Live Display Mode..." -ForegroundColor Cyan
                Write-Host "Press Ctrl+C to exit when ready." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                try { Start-SpotifyLive -Mode detailed } catch { Show-UserFriendlyError -ErrorRecord $_ -Context "live display demo" }
            }
            "2" {
                Write-Host "📝 Fetching lyrics for current track..." -ForegroundColor Cyan
                try { Get-SpotifyLyrics } catch { Show-UserFriendlyError -ErrorRecord $_ -Context "lyrics demo" }
            }
            "3" {
                Write-Host "📊 Generating listening statistics..." -ForegroundColor Cyan
                try { Get-SpotifyStats -Period month } catch { Show-UserFriendlyError -ErrorRecord $_ -Context "statistics demo" }
            }
            "4" {
                Write-Host "🪟 Opening Sidecar Mode..." -ForegroundColor Cyan
                try { Start-SpotifySidecar } catch { Show-UserFriendlyError -ErrorRecord $_ -Context "sidecar demo" }
            }
            "5" {
                Write-Host "🔍 Running diagnostics..." -ForegroundColor Cyan
                Test-SpotifyLiveFeatures
            }
            default {
                Write-Host "✅ Welcome complete! You're ready to use Spotify CLI." -ForegroundColor Green
            }
        }
    }
    
    Write-Host ""
    Write-Host "🎉 Enjoy your enhanced Spotify experience!" -ForegroundColor Green
    Write-Host "💡 Tip: Use 'Get-SpotifyHelp' anytime for assistance" -ForegroundColor Cyan
}

function Test-FirstTimeUser {
    <#
    .SYNOPSIS
    Check if this is a first-time user and show welcome if needed
    
    .DESCRIPTION
    Checks for the presence of a welcome flag file and shows the welcome screen
    for new users. This helps with feature discovery and onboarding.
    #>
    
    $welcomeFile = Join-Path $script:AppDataDir "welcome-shown.flag"
    
    if (-not (Test-Path $welcomeFile)) {
        # First time user - show welcome
        Show-SpotifyWelcome -FirstTime
        
        # Create flag file to prevent showing welcome again
        try {
            if (-not (Test-Path $script:AppDataDir)) {
                New-Item -ItemType Directory -Path $script:AppDataDir -Force | Out-Null
            }
            "Welcome shown on $(Get-Date)" | Set-Content -Path $welcomeFile -Encoding UTF8
        } catch {
            # Ignore errors creating flag file
        }
        
        return $true
    }
    
    return $false
}

function Show-FeatureDiscovery {
    <#
    .SYNOPSIS
    Show feature discovery hints based on user activity
    
    .DESCRIPTION
    Analyzes user behavior and suggests relevant features they haven't tried yet.
    This helps users discover the full capabilities of the CLI.
    
    .PARAMETER Context
    The context in which to show discovery hints (startup, after-command, etc.)
    #>
    
    param(
        [ValidateSet("startup", "after-command", "idle")]
        [string]$Context = "startup"
    )
    
    # Only show hints occasionally to avoid being annoying
    $random = Get-Random -Minimum 1 -Maximum 10
    if ($random -gt 3) { return } # 30% chance of showing hints
    
    $hints = @()
    
    # Check if user has tried live features
    if ($script:LiveFeaturesAvailable) {
        $status = Get-SpotifyLiveFeaturesStatus -ErrorAction SilentlyContinue
        if (-not $status.IsInitialized) {
            $hints += "💡 Try the new live display: live"
            $hints += "📝 Get lyrics for any track: lyrics"
            $hints += "📊 View your listening stats: stats"
        }
    }
    
    # Check terminal capabilities for sidecar suggestions
    $terminalCaps = Get-TerminalCapabilities
    if ($terminalCaps.SupportsSplitWindow) {
        $hints += "🪟 Try sidecar mode for multitasking: sidecar"
    }
    
    # General feature hints
    $generalHints = @(
        "🔍 Search with interactive navigation: search 'artist name'",
        "🎵 Quick track info: plays-now",
        "📱 Manage devices: devices",
        "❤️ View liked songs: liked"
    )
    
    $hints += $generalHints | Get-Random -Count 1
    
    if ($hints.Count -gt 0) {
        $selectedHint = $hints | Get-Random
        Write-Host ""
        Write-Host $selectedHint -ForegroundColor Cyan
    }
}
function Get-TerminalCapabilities {
    <#
    .SYNOPSIS
    Detect terminal capabilities like ANSI support and split window support
    .DESCRIPTION
    This function attempts to detect the current terminal type and its capabilities
    to provide a better user experience for features like live display and sidecar mode.
    #>
    # Default capabilities
    $capabilities = @{
        TerminalType = "Unknown"
        SupportsAnsi = $false
        SupportsSplitWindow = $false
        SupportsInteractiveInput = $false
    }

    # Detect Windows Terminal
    if ($env:WT_SESSION) {
        $capabilities.TerminalType = "Windows Terminal"
        $capabilities.SupportsAnsi = $true
        $capabilities.SupportsSplitWindow = $true
    }
    # Detect VS Code Integrated Terminal
    elseif ($env:TERM_PROGRAM -eq "vscode") {
        $capabilities.TerminalType = "VS Code Integrated Terminal"
        $capabilities.SupportsAnsi = $true
        $capabilities.SupportsSplitWindow = $false # VS Code usually doesn't do split panes by itself easily
    }
    # Detect PowerShell 7+ on modern console host
    elseif ($PSVersionTable.PSVersion.Major -ge 7 -and $host.UI.RawUI.SupportsVirtualTerminal) {
        $capabilities.TerminalType = "PowerShell 7+ Console"
        $capabilities.SupportsAnsi = $true
    }
    # Fallback for older PowerShell or basic consoles
    else {
        $capabilities.TerminalType = "Legacy PowerShell Console"
        $capabilities.SupportsAnsi = $false
    }
    
    # Basic check for interactive input support (ReadKey)
    try {
        # Check if ReadKey method is available
        $testKey = $null
        if ($Host.UI.RawUI.PSObject.Methods['ReadKey']) {
            # Try to actually use it (with timeout to avoid hanging)
            $capabilities.SupportsInteractiveInput = $true
        }
    } catch {
        $capabilities.SupportsInteractiveInput = $false
    }

    # If running in PowerShell 7+, always enable interactive input
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $capabilities.SupportsInteractiveInput = $true
    }

    return $capabilities
}

function Invoke-HelpCommand {
    param([string]$Arguments)
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        # Show general help overview
        Write-Host "Spotify CLI - Enhanced PowerShell Interface" -ForegroundColor Cyan
        Write-Host "===========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "PLAYBACK CONTROLS:" -ForegroundColor Yellow
        Write-Host "  /spotify [compact] - Show current track (add 'compact' for single-line)" -ForegroundColor White
        Write-Host "  /play              - Resume playback" -ForegroundColor White
        Write-Host "  /pause             - Pause playback" -ForegroundColor White
        Write-Host "  /next              - Skip to next track" -ForegroundColor White
        Write-Host "  /previous          - Go to previous track" -ForegroundColor White
        Write-Host "  /seek SECONDS      - Seek forward/backward (use negative for backward)" -ForegroundColor White
        Write-Host "  /volume 0-100      - Set playback volume" -ForegroundColor White
        Write-Host "  /shuffle on|off    - Toggle shuffle mode" -ForegroundColor White
        Write-Host "  /repeat MODE       - Set repeat mode (track/context/off)" -ForegroundColor White
        Write-Host ""
        Write-Host "DEVICE MANAGEMENT:" -ForegroundColor Yellow
        Write-Host "  /devices           - List available Spotify Connect devices" -ForegroundColor White
        Write-Host "  /transfer ID       - Transfer playback to device" -ForegroundColor White
        Write-Host ""
        Write-Host "SEARCH & PLAYBACK:" -ForegroundColor Yellow
        Write-Host "  /search QUERY      - Search for tracks, artists, albums" -ForegroundColor White
        Write-Host "  /queue URI         - Add track to playback queue" -ForegroundColor White
        Write-Host "  /play track URI    - Play specific track" -ForegroundColor White
        Write-Host "  /play album URI    - Play specific album" -ForegroundColor White
        Write-Host "  /play playlist URI - Play specific playlist" -ForegroundColor White
        Write-Host ""
        Write-Host "LIBRARY MANAGEMENT:" -ForegroundColor Yellow
        Write-Host "  /playlists         - Show your playlists" -ForegroundColor White
        Write-Host "  /liked             - Show your liked songs" -ForegroundColor White
        Write-Host "  /recent            - Show recently played tracks" -ForegroundColor White
        Write-Host "  /save              - Add current track to liked songs" -ForegroundColor White
        Write-Host "  /unsave            - Remove current track from liked songs" -ForegroundColor White
        Write-Host ""
        Write-Host "LIVE FEATURES:" -ForegroundColor Yellow
        Write-Host "  /live [mode]       - Start live display mode (detailed/compact/minimal)" -ForegroundColor White
        Write-Host "  /sidecar [options] - Launch CLI in split window/sidecar mode" -ForegroundColor White
        Write-Host ""
        Write-Host "SYSTEM COMMANDS:" -ForegroundColor Yellow
        Write-Host "  /config [key] [value] - View/modify configuration" -ForegroundColor White
        Write-Host "  /config-live [command] - Manage live features configuration" -ForegroundColor White
        Write-Host "  /history           - Show playback history" -ForegroundColor White
        Write-Host "  /notifications on|off - Toggle notifications" -ForegroundColor White
        Write-Host "  /auto-refresh SECONDS - Auto-refresh display every X seconds" -ForegroundColor White
        Write-Host "  /help [command]    - Show help (add command for detailed help)" -ForegroundColor White
        Write-Host "  /quit              - Exit the CLI" -ForegroundColor White
        Write-Host ""
        Write-Host "For detailed help on a specific command, use: /help COMMAND" -ForegroundColor Gray
        Write-Host "Example: /help seek" -ForegroundColor Gray
        return
    }
    
    # Show detailed help for specific command
    $command = $Arguments.Trim().ToLower().TrimStart('/')
    
    switch ($command) {
        "spotify" {
            Write-Host "COMMAND: /spotify [compact]" -ForegroundColor Cyan
            Write-Host "=========================" -ForegroundColor Cyan
            Write-Host "Shows information about the currently playing track." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /spotify          - Show full track information with progress bar" -ForegroundColor White
            Write-Host "  /spotify compact  - Show compact single-line format" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /spotify" -ForegroundColor Gray
            Write-Host "  /spotify compact" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTE: Compact mode can also be enabled globally via /config CompactMode true" -ForegroundColor Gray
        }
        "seek" {
            Write-Host "COMMAND: /seek SECONDS" -ForegroundColor Cyan
            Write-Host "=====================" -ForegroundColor Cyan
            Write-Host "Seeks forward or backward in the current track." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /seek SECONDS   - Positive numbers seek forward, negative backward" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /seek 30          - Skip forward 30 seconds" -ForegroundColor Gray
            Write-Host "  /seek -15         - Skip backward 15 seconds" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
            Write-Host "  - Active device with current track playing" -ForegroundColor Gray
        }
        "volume" {
            Write-Host "COMMAND: /volume 0-100" -ForegroundColor Cyan
            Write-Host "=====================" -ForegroundColor Cyan
            Write-Host "Sets the playback volume on the active device." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /volume LEVEL   - Volume level from 0 (mute) to 100 (maximum)" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /volume 50        - Set volume to 50%" -ForegroundColor Gray
            Write-Host "  /volume 0         - Mute playback" -ForegroundColor Gray
            Write-Host "  /volume 100       - Set to maximum volume" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
            Write-Host "  - Active device that supports volume control" -ForegroundColor Gray
        }
        "shuffle" {
            Write-Host "COMMAND: /shuffle on|off" -ForegroundColor Cyan
            Write-Host "=======================" -ForegroundColor Cyan
            Write-Host "Enables or disables shuffle mode for the current playback context." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /shuffle on       - Enable shuffle mode" -ForegroundColor White
            Write-Host "  /shuffle off      - Disable shuffle mode" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /shuffle on" -ForegroundColor Gray
            Write-Host "  /shuffle off" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
            Write-Host "  - Active playback context (playlist, album, etc.)" -ForegroundColor Gray
        }
        "repeat" {
            Write-Host "COMMAND: /repeat MODE" -ForegroundColor Cyan
            Write-Host "===================================" -ForegroundColor Cyan
            Write-Host "Sets the repeat mode for playback." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /repeat track     - Repeat current track" -ForegroundColor White
            Write-Host "  /repeat context   - Repeat current playlist/album" -ForegroundColor White
            Write-Host "  /repeat off       - Disable repeat" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /repeat track" -ForegroundColor Gray
            Write-Host "  /repeat context" -ForegroundColor Gray
            Write-Host "  /repeat off" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
            Write-Host "  - Active playback context" -ForegroundColor Gray
        }
        "devices" {
            Write-Host "COMMAND: /devices" -ForegroundColor Cyan
            Write-Host "=================" -ForegroundColor Cyan
            Write-Host "Lists all available Spotify Connect devices." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /devices           - Show all available devices with status" -ForegroundColor White
            Write-Host ""
            Write-Host "DISPLAYED INFO:" -ForegroundColor Yellow
            Write-Host "  - Device name and type" -ForegroundColor Gray
            Write-Host "  - Active status (which device is currently playing)" -ForegroundColor Gray
            Write-Host "  - Volume level (if available)" -ForegroundColor Gray
            Write-Host "  - Device ID (for use with /transfer command)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "TIP: Use device IDs with /transfer command to switch playback" -ForegroundColor Gray
        }
        "transfer" {
            Write-Host "COMMAND: /transfer DEVICE_ID" -ForegroundColor Cyan
            Write-Host "=============================" -ForegroundColor Cyan
            Write-Host "Transfers playback to a different Spotify Connect device." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /transfer ID    - Transfer to device with specified ID" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /transfer abc123  - Transfer to device with ID 'abc123')" -ForegroundColor Gray
            Write-Host ""
            Write-Host "HOW TO GET DEVICE ID:" -ForegroundColor Yellow
            Write-Host "  1. Run /devices to see available devices" -ForegroundColor Gray
            Write-Host "  2. Copy the device ID from the list" -ForegroundColor Gray
            Write-Host "  3. Use it with /transfer command" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Target device must be active and available" -ForegroundColor Gray
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
        }
        "search" {
            Write-Host "COMMAND: /search QUERY" -ForegroundColor Cyan
            Write-Host "=====================" -ForegroundColor Cyan
            Write-Host "Searches for tracks, artists, and albums on Spotify." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /search QUERY   - Search for music content" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /search bohemian rhapsody" -ForegroundColor Gray
            Write-Host "  /search artist:queen" -ForegroundColor Gray
            Write-Host "  /search album:\"a night at the opera\"" -ForegroundColor Gray
            Write-Host ""
            Write-Host "SEARCH TIPS:" -ForegroundColor Yellow
            Write-Host "  - Use quotes for exact phrases" -ForegroundColor Gray
            Write-Host "  - Use 'artist:', 'album:', 'track:' prefixes for specific searches" -ForegroundColor Gray
            Write-Host "  - Results show URIs that can be used with /play and /queue commands" -ForegroundColor Gray
        }
        "queue" {
            Write-Host "COMMAND: /queue TRACK_URI" -ForegroundColor Cyan
            Write-Host "=========================" -ForegroundColor Cyan
            Write-Host "Adds a track to the playback queue." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /queue URI      - Add track to queue using Spotify URI" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /queue spotify:track:4iV5W9uYEdYUVa79Axb7Rh" -ForegroundColor Gray
            Write-Host ""
            Write-Host "HOW TO GET TRACK URI:" -ForegroundColor Yellow
            Write-Host "  1. Use /search to find tracks" -ForegroundColor Gray
            Write-Host "  2. Copy the URI from search results" -ForegroundColor Gray
            Write-Host "  3. Use it with /queue command" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
            Write-Host "  - Active device with playback" -ForegroundColor Gray
        }
        "play" {
            Write-Host "COMMAND: /play TYPE URI" -ForegroundColor Cyan
            Write-Host "=========================" -ForegroundColor Cyan
            Write-Host "Plays specific content immediately." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /play track URI     - Play specific track" -ForegroundColor White
            Write-Host "  /play album URI     - Play specific album" -ForegroundColor White
            Write-Host "  /play playlist URI  - Play specific playlist" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /play track spotify:track:4iV5W9uYEdYUVa79Axb7Rh" -ForegroundColor Gray
            Write-Host "  /play album spotify:album:4aawyAB9vmqN3uQ7FjRGTy" -ForegroundColor Gray
            Write-Host "  /play playlist spotify:playlist:37i9dQZF1DXcBWIGoYBM5M" -ForegroundColor Gray
            Write-Host ""
            Write-Host "HOW TO GET URIs:" -ForegroundColor Yellow
            Write-Host "  - Use /search for tracks and albums" -ForegroundColor Gray
            Write-Host "  - Use /playlists to see your playlists with URIs" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
            Write-Host "  - Active device" -ForegroundColor Gray
        }
        "playlists" {
            Write-Host "COMMAND: /playlists" -ForegroundColor Cyan
            Write-Host "=================" -ForegroundColor Cyan
            Write-Host "Shows your Spotify playlists." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /playlists        - List all your playlists" -ForegroundColor White
            Write-Host ""
            Write-Host "DISPLAYED INFO:" -ForegroundColor Yellow
            Write-Host "  - Playlist name and description" -ForegroundColor Gray
            Write-Host "  - Number of tracks" -ForegroundColor Gray
            Write-Host "  - Playlist URI (for use with /play playlist command)" -ForegroundColor Gray
            Write-Host "  - Public/private status" -ForegroundColor Gray
            Write-Host ""
            Write-Host "TIP: Copy playlist URIs to use with /play playlist URI" -ForegroundColor Gray
        }
        "liked" {
            Write-Host "COMMAND: /liked" -ForegroundColor Cyan
            Write-Host "===============" -ForegroundColor Cyan
            Write-Host "Shows your Spotify liked/saved songs." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /liked            - Show your liked songs" -ForegroundColor White
            Write-Host ""
            Write-Host "DISPLAYED INFO:" -ForegroundColor Yellow
            Write-Host "  - Track name and artist" -ForegroundColor Gray
            Write-Host "  - Album name" -ForegroundColor Gray
            Write-Host "  - Date added to liked songs" -ForegroundColor Gray
            Write-Host "  - Track URI" -ForegroundColor Gray
            Write-Host ""
            Write-Host "RELATED COMMANDS:" -ForegroundColor Yellow
            Write-Host "  /save   - Add current track to liked songs" -ForegroundColor Gray
            Write-Host "  /unsave - Remove current track from liked songs" -ForegroundColor Gray
        }
        "recent" {
            Write-Host "COMMAND: /recent" -ForegroundColor Cyan
            Write-Host "===============" -ForegroundColor Cyan
            Write-Host "Shows recently played tracks from Spotify." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /recent           - Show recently played tracks" -ForegroundColor White
            Write-Host ""
            Write-Host "DISPLAYED INFO:" -ForegroundColor Yellow
            Write-Host "  - Track name and artist" -ForegroundColor Gray
            Write-Host "  - Album name" -ForegroundColor Gray
            Write-Host "  - When it was played" -ForegroundColor Gray
            Write-Host "  - Track URI" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTE: This shows Spotify's recent tracks, not local CLI history" -ForegroundColor Gray
            Write-Host "For local history, use /history command" -ForegroundColor Gray
        }
        "save" {
            Write-Host "COMMAND: /save" -ForegroundColor Cyan
            Write-Host "=============" -ForegroundColor Cyan
            Write-Host "Adds the currently playing track to your liked songs." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /save             - Save current track to liked songs" -ForegroundColor White
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - A track must be currently playing" -ForegroundColor Gray
            Write-Host "  - Track must not already be in liked songs" -ForegroundColor Gray
            Write-Host ""
            Write-Host "RELATED COMMANDS:" -ForegroundColor Yellow
            Write-Host "  /unsave - Remove current track from liked songs" -ForegroundColor Gray
            Write-Host "  /liked  - View all your liked songs" -ForegroundColor Gray
        }
        "unsave" {
            Write-Host "COMMAND: /unsave" -ForegroundColor Cyan
            Write-Host "===============" -ForegroundColor Cyan
            Write-Host "Removes the currently playing track from your liked songs." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /unsave           - Remove current track from liked songs" -ForegroundColor White
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - A track must be currently playing" -ForegroundColor Gray
            Write-Host "  - Track must be in your liked songs" -ForegroundColor Gray
            Write-Host ""
            Write-Host "RELATED COMMANDS:" -ForegroundColor Yellow
            Write-Host "  /save  - Add current track to liked songs" -ForegroundColor Gray
            Write-Host "  /liked - View all your liked songs" -ForegroundColor Gray
        }
        "config" {
            Write-Host "COMMAND: /config [key] [value]" -ForegroundColor Cyan
            Write-Host "=============================" -ForegroundColor Cyan
            Write-Host "View or modify CLI configuration settings." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /config           - Show current configuration" -ForegroundColor White
            Write-Host "  /config list      - Show available configuration keys" -ForegroundColor White
            Write-Host "  /config reset     - Reset to default configuration" -ForegroundColor White
            Write-Host "  /config KEY VALUE - Set configuration value" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /config CompactMode true" -ForegroundColor Gray
            Write-Host "  /config Colors.Playing Blue" -ForegroundColor Gray
            Write-Host "  /config AutoRefreshInterval 5" -ForegroundColor Gray
        }
        "config-live" {
            Write-Host "COMMAND: /config-live [command] [arguments]" -ForegroundColor Cyan
            Write-Host "=========================================" -ForegroundColor Cyan
            Write-Host "Manage live features configuration (display, lyrics, statistics)." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /config-live show                    - Show current live features config" -ForegroundColor White
            Write-Host "  /config-live set section.key=value - Set configuration value" -ForegroundColor White
            Write-Host "  /config-live reset [section]         - Reset to defaults" -ForegroundColor White
            Write-Host "  /config-live schema [section]        - Show valid settings" -ForegroundColor White
            Write-Host "  /config-live backup                  - Create configuration backup" -ForegroundColor White
            Write-Host "  /config-live info                    - Show system information" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /config-live set liveDisplay.refreshInterval=1500" -ForegroundColor Gray
            Write-Host "  /config-live set lyrics.preferredProvider=genius" -ForegroundColor Gray
            Write-Host "  /config-live reset liveDisplay" -ForegroundColor Gray
            Write-Host "  /config-live backup" -ForegroundColor Gray
            Write-Host ""
            Write-Host "SECTIONS:" -ForegroundColor Yellow
            Write-Host "  liveDisplay - Real-time display settings" -ForegroundColor White
            Write-Host "  lyrics      - Lyrics fetching and display" -ForegroundColor White
            Write-Host "  statistics  - Data collection and analytics" -ForegroundColor White
            Write-Host "  apiClient   - API client configuration" -ForegroundColor White
            Write-Host ""
            Write-Host "MAIN SETTINGS:" -ForegroundColor Yellow
            Write-Host "  CompactMode, NotificationsEnabled, LoggingEnabled" -ForegroundColor Gray
            Write-Host "  AutoRefreshInterval, HistoryEnabled, MaxHistoryEntries" -ForegroundColor Gray
            Write-Host "  Colors.* (Playing, Paused, Track, Artist, Album, Progress)" -ForegroundColor Gray
        }
        "history" {
            Write-Host "COMMAND: /history" -ForegroundColor Cyan
            Write-Host "=================" -ForegroundColor Cyan
            Write-Host "Shows local playback history tracked by the CLI." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /history          - Show recent playback history" -ForegroundColor White
            Write-Host ""
            Write-Host "DISPLAYED INFO:" -ForegroundColor Yellow
            Write-Host "  - Track name and artist" -ForegroundColor Gray
            Write-Host "  - Album name" -ForegroundColor Gray
            Write-Host "  - When it was played (local time)" -ForegroundColor Gray
            Write-Host "  - Duration" -ForegroundColor Gray
            Write-Host ""
            Write-Host "CONFIGURATION:" -ForegroundColor Yellow
            Write-Host "  - Enable/disable: /config HistoryEnabled true/false" -ForegroundColor Gray
            Write-Host "  - Max entries: /config MaxHistoryEntries NUMBER" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTE: This is different from /recent (Spotify's recent tracks)" -ForegroundColor Gray
        }
        "notifications" {
            Write-Host "COMMAND: /notifications on|off" -ForegroundColor Cyan
            Write-Host "===============================" -ForegroundColor Cyan
            Write-Host "Enable or disable Windows toast notifications for track changes." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /notifications on  - Enable notifications" -ForegroundColor White
            Write-Host "  /notifications off - Disable notifications" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /notifications on" -ForegroundColor Gray
            Write-Host "  /notifications off" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Windows 10/11 with toast notification support" -ForegroundColor Gray
            Write-Host "  - Notification permissions for PowerShell" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTE: Can also be configured via /config NotificationsEnabled true/false" -ForegroundColor Gray
        }
        "auto-refresh" {
            Write-Host "COMMAND: /auto-refresh SECONDS" -ForegroundColor Cyan
            Write-Host "===============================" -ForegroundColor Cyan
            Write-Host "Automatically refresh the display at specified intervals." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /auto-refresh SECONDS - Set refresh interval (0 to disable)" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /auto-refresh 5   - Refresh every 5 seconds" -ForegroundColor Gray
            Write-Host "  /auto-refresh 0   - Disable auto-refresh" -ForegroundColor Gray
            Write-Host ""
            Write-Host "BEHAVIOR:" -ForegroundColor Yellow
            Write-Host "  - Shows current track info at specified intervals" -ForegroundColor Gray
            Write-Host "  - Press any key to interrupt and return to command mode" -ForegroundColor Gray
            Write-Host "  - Useful for monitoring playback without manual commands" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTE: Can also be configured via /config AutoRefreshInterval SECONDS" -ForegroundColor Gray
        }
        "live" {
            Write-Host "COMMAND: /live [mode]" -ForegroundColor Cyan
            Write-Host "====================" -ForegroundColor Cyan
            Write-Host "Start real-time live display mode with continuous track updates." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /live              - Start live display in detailed mode" -ForegroundColor White
            Write-Host "  /live detailed     - Start with detailed track information" -ForegroundColor White
            Write-Host "  /live compact      - Start with compact single-line display" -ForegroundColor White
            Write-Host "  /live minimal      - Start with minimal display" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /live" -ForegroundColor Gray
            Write-Host "  /live compact" -ForegroundColor Gray
            Write-Host "  /live minimal" -ForegroundColor Gray
            Write-Host ""
            Write-Host "FEATURES:" -ForegroundColor Yellow
            Write-Host "  - Real-time track information updates" -ForegroundColor Gray
            Write-Host "  - Animated progress bar" -ForegroundColor Gray
            Write-Host "  - Automatic refresh every second" -ForegroundColor Gray
            Write-Host "  - Graceful exit with Ctrl+C" -ForegroundColor Gray
            Write-Host ""
            Write-Host "STARTUP OPTION:" -ForegroundColor Yellow
            Write-Host "  You can also start the CLI directly in live mode:" -ForegroundColor Gray
            Write-Host "  .\spotifyCLI.psm1 -Live -LiveMode compact" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Active Spotify device with current playback" -ForegroundColor Gray
            Write-Host "  - Terminal that supports ANSI escape codes (recommended)" -ForegroundColor Gray
        }
        "sidecar" {
            Write-Host "COMMAND: /sidecar [options]" -ForegroundColor Cyan
            Write-Host "=========================" -ForegroundColor Cyan
            Write-Host "Launch Spotify CLI in a split window or sidecar mode." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /sidecar           - Launch in sidecar with default settings" -ForegroundColor White
            Write-Host "  /sidecar live      - Launch sidecar in live display mode" -ForegroundColor White
            Write-Host "  /sidecar compact   - Launch sidecar with compact live display" -ForegroundColor White
            Write-Host "  /sidecar right     - Launch sidecar split to the right" -ForegroundColor White
            Write-Host "  /sidecar down live - Launch sidecar below with live mode" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /sidecar" -ForegroundColor Gray
            Write-Host "  /sidecar live" -ForegroundColor Gray
            Write-Host "  /sidecar compact right" -ForegroundColor Gray
            Write-Host "  /sidecar down minimal" -ForegroundColor Gray
            Write-Host ""
            Write-Host "OPTIONS:" -ForegroundColor Yellow
            Write-Host "  Live Modes: detailed, compact, minimal" -ForegroundColor Gray
            Write-Host "  Split Directions: right, down, left, up" -ForegroundColor Gray
            Write-Host "  Keywords: live (enables live display mode)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "SUPPORTED TERMINALS:" -ForegroundColor Yellow
            Write-Host "  - Windows Terminal (recommended)" -ForegroundColor Gray
            Write-Host "  - VS Code integrated terminal" -ForegroundColor Gray
            Write-Host "  - Falls back to new window if split not supported" -ForegroundColor Gray
        }
        "quit" {
            Write-Host "COMMAND: /quit" -ForegroundColor Cyan
            Write-Host "=============" -ForegroundColor Cyan
            Write-Host "Exits the Spotify CLI application." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /quit             - Exit the CLI" -ForegroundColor White
            Write-Host ""
            Write-Host "ALIASES:" -ForegroundColor Yellow
            Write-Host "  /exit, /q         - Same as /quit" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTE: All configuration and history are automatically saved" -ForegroundColor Gray
        }
        default {
            Write-Host "Unknown command: $command" -ForegroundColor Red
            Write-Host ""
            Write-Host "Available commands for detailed help:" -ForegroundColor Yellow
            $availableCommands = @(
                "spotify", "seek", "volume", "shuffle", "repeat",
                "devices", "transfer", "search", "queue", "play",
                "playlists", "liked", "recent", "save", "unsave",
                "config", "config-live", "history", "notifications", "auto-refresh", "live", "sidecar", "quit"
            )
            $availableCommands | ForEach-Object {
                Write-Host "  /help $_ " -ForegroundColor Gray
            }
            Write-Host ""
            Write-Host "Use /help without arguments to see the general command overview." -ForegroundColor Gray
        }
    }
}

function Invoke-ConfigCommand {
    param([string]$Arguments)
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        # Show current configuration
        $config = Get-SpotifyConfig
        Write-Host "Current Spotify CLI Configuration:" -ForegroundColor Cyan
        Write-Host "=================================" -ForegroundColor Cyan
        $deviceDisplay = if ($config.PreferredDevice) { $config.PreferredDevice } else { 'None' }
        Write-Host "PreferredDevice: $deviceDisplay" -ForegroundColor White
        Write-Host "CompactMode: $($config.CompactMode)" -ForegroundColor White
        Write-Host "NotificationsEnabled: $($config.NotificationsEnabled)" -ForegroundColor White
        Write-Host "AutoRefreshInterval: $($config.AutoRefreshInterval) seconds" -ForegroundColor White
        Write-Host "LoggingEnabled: $($config.LoggingEnabled)" -ForegroundColor White
        Write-Host "HistoryEnabled: $($config.HistoryEnabled)" -ForegroundColor White
        Write-Host "MaxHistoryEntries: $($config.MaxHistoryEntries)" -ForegroundColor White
        Write-Host "Colors:" -ForegroundColor White
        $config.Colors.GetEnumerator() | Sort-Object Key | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "Usage: /config KEY VALUE - Set a configuration value" -ForegroundColor Gray
        Write-Host "       /config reset - Reset to default configuration" -ForegroundColor Gray
        Write-Host "       /config list - Show available configuration keys" -ForegroundColor Gray
        return
    }
    
    $parts = $Arguments.Trim() -split '\s+', 2
    $key = $parts[0]
    $value = if ($parts.Length -gt 1) { $parts[1] } else { $null }
    
    if ($key -eq "reset") {
        if (Set-SpotifyConfig -Config $DefaultConfig.Clone()) {
            Write-Host "Configuration reset to defaults." -ForegroundColor Green
        }
        return
    }
    
    if ($key -eq "list") {
        Write-Host "Available configuration keys:" -ForegroundColor Cyan
        Write-Host "===========================" -ForegroundColor Cyan
        Write-Host "PreferredDevice - Set preferred Spotify device (string or null)" -ForegroundColor White
        Write-Host "CompactMode - Enable compact display mode (true/false)" -ForegroundColor White
        Write-Host "NotificationsEnabled - Enable Windows notifications (true/false)" -ForegroundColor White
        Write-Host "AutoRefreshInterval - Auto-refresh interval in seconds (number)" -ForegroundColor White
        Write-Host "LoggingEnabled - Enable debug logging (true/false)" -ForegroundColor White
        Write-Host "HistoryEnabled - Enable playback history tracking (true/false)" -ForegroundColor White
        Write-Host "MaxHistoryEntries - Maximum history entries to keep (number)" -ForegroundColor White
        Write-Host "Colors.* - Color settings for different elements:" -ForegroundColor White
        Write-Host "  Colors.Playing, Colors.Paused, Colors.Track, Colors.Artist, Colors.Album, Colors.Progress" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Valid colors: Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White" -ForegroundColor Gray
        return
    }
    
    if ($null -eq $value) {
        Write-Error "Please provide a value for '$key'. Usage: /config KEY VALUE"
        return
    }
    
    $config = Get-SpotifyConfig
    
    # Handle special cases for value parsing
    switch ($key) {
        "CompactMode" {
            $value = $value.ToLower() -in @("true", "1", "yes", "on")
        }
        "NotificationsEnabled" {
            $value = $value.ToLower() -in @("true", "1", "yes", "on")
        }
        "LoggingEnabled" {
            $value = $value.ToLower() -in @("true", "1", "yes", "on")
        }
        "HistoryEnabled" {
            $value = $value.ToLower() -in @("true", "1", "yes", "on")
        }
        "AutoRefreshInterval" {
            try { $value = [int]$value } catch { Write-Error "AutoRefreshInterval must be a number"; return }
        }
        "MaxHistoryEntries" {
            try { $value = [int]$value } catch { Write-Error "MaxHistoryEntries must be a number"; return }
        }
        "PreferredDevice" {
            if ($value.ToLower() -in @("null", "none", "")) { $value = $null }
        }
    }
    
    # Handle color configuration
    if ($key -like "Colors.*") {
        $colorKey = $key.Substring(7) # Remove "Colors." prefix
        if (-not $config.Colors.ContainsKey($colorKey)) {
            Write-Error "Unknown color setting '$colorKey'. Available: $($config.Colors.Keys -join ', ')"
            return
        }
        if (-not (Test-SpotifyConfigValue -Key "Colors" -Value @{$colorKey = $value})) {
            Write-Error "Invalid color value '$value'. Valid colors: Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White"
            return
        }
        $config.Colors[$colorKey] = $value
    } else {
        # Validate the configuration value
        if (-not (Test-SpotifyConfigValue -Key $key -Value $value)) {
            Write-Error "Invalid value '$value' for configuration key '$key'"
            return
        }
        
        if (-not $config.ContainsKey($key)) {
            Write-Error "Unknown configuration key '$key'. Available keys: $($config.Keys -join ', '), Colors.*"
            return
        }
        
        $config[$key] = $value
    }
    
    if (Set-SpotifyConfig -Config $config) {
        Write-Host "Configuration updated: $key = $value" -ForegroundColor Green
    }
}

function Invoke-LiveFeaturesConfigCommand {
    param([string]$Arguments)
    
    # Import the configuration modules if not already loaded
    $configModulePath = Join-Path $PSScriptRoot "modules\Core\ConfigurationCommands.psm1"
    if (Test-Path $configModulePath) {
        try {
            Import-Module $configModulePath -Force -Global -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Could not load live features configuration module: $($_.Exception.Message)"
            Write-Host "Live features configuration is not available." -ForegroundColor Yellow
            return
        }
    } else {
        Write-Host "Live features configuration module not found." -ForegroundColor Yellow
        Write-Host "Please ensure the live features modules are properly installed."
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        # Show current live features configuration
        try {
            Get-LiveFeaturesConfig
        } catch {
            Write-Warning "Failed to load live features configuration: $($_.Exception.Message)"
            Write-Host "💡 Try running: /config-live info" -ForegroundColor Yellow
        }
        return
    }
    
    # Parse arguments
    $argParts = $Arguments.Trim() -split '\s+', 2
    $command = $argParts[0].ToLower()
    $commandArgs = if ($argParts.Length -gt 1) { $argParts[1] } else { "" }
    
    try {
        switch ($command) {
            "show" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Get-LiveFeaturesConfig
                } else {
                    $parts = $commandArgs -split '\.'
                    if ($parts.Length -eq 1) {
                        Get-LiveFeaturesConfig -Section $parts[0]
                    } elseif ($parts.Length -eq 2) {
                        Get-LiveFeaturesConfig -Section $parts[0] -Key $parts[1]
                    } else {
                        Write-Error "Invalid format. Use 'section' or 'section.key'"
                    }
                }
            }
            
            "set" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Write-Error "Missing arguments. Use format: section.key=value"
                    Write-Host "Example: /config-live set liveDisplay.refreshInterval=1500" -ForegroundColor Gray
                    return
                }
                
                if ($commandArgs -match '^([^.]+)\.([^=]+)=(.+)$') {
                    $section = $matches[1]
                    $key = $matches[2]
                    $valueStr = $matches[3]
                    
                    # Parse value based on type
                    $value = ConvertTo-ConfigValue -ValueString $valueStr
                    
                    Set-LiveFeaturesConfig -Section $section -Key $key -Value $value
                } else {
                    Write-Error "Invalid format. Use: section.key=value"
                    Write-Host "Example: /config-live set liveDisplay.refreshInterval=1500" -ForegroundColor Gray
                }
            }
            
            "reset" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Reset-LiveFeaturesConfig
                } else {
                    Reset-LiveFeaturesConfig -Section $commandArgs
                }
            }
            
            "schema" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Get-LiveFeaturesConfigSchema
                } else {
                    Get-LiveFeaturesConfigSchema -Section $commandArgs
                }
            }
            
            "backup" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Backup-LiveFeaturesConfig
                } else {
                    Backup-LiveFeaturesConfig -Path $commandArgs
                }
            }
            
            "restore" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Write-Error "Missing backup file path"
                    Write-Host "Usage: /config-live restore BACKUP_FILE_PATH" -ForegroundColor Gray
                } else {
                    Restore-LiveFeaturesConfig -Path $commandArgs
                }
            }
            
            "export" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Export-LiveFeaturesConfig
                } else {
                    Export-LiveFeaturesConfig -Path $commandArgs
                }
            }
            
            "import" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Write-Error "Missing configuration file path"
                    Write-Host "Usage: /config-live import CONFIG_FILE_PATH" -ForegroundColor Gray
                } else {
                    Import-LiveFeaturesConfig -Path $commandArgs
                }
            }
            
            "test" {
                Test-LiveFeaturesConfig
            }
            
            "info" {
                Get-LiveFeaturesConfigInfo
            }
            
            "help" {
                Write-Host "Live Features Configuration Commands" -ForegroundColor Cyan
                Write-Host "===================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "COMMANDS:" -ForegroundColor Yellow
                Write-Host "  show [section[.key]]     - Display configuration" -ForegroundColor White
                Write-Host "  set section.key=value    - Set configuration value" -ForegroundColor White
                Write-Host "  reset [section]          - Reset to defaults" -ForegroundColor White
                Write-Host "  schema [section]         - Show valid settings" -ForegroundColor White
                Write-Host "  backup [path]            - Create backup" -ForegroundColor White
                Write-Host "  restore PATH             - Restore from backup" -ForegroundColor White
                Write-Host "  export [path]            - Export configuration" -ForegroundColor White
                Write-Host "  import PATH              - Import configuration" -ForegroundColor White
                Write-Host "  test                     - Validate configuration" -ForegroundColor White
                Write-Host "  info                     - Show system information" -ForegroundColor White
                Write-Host "  help                     - Show this help" -ForegroundColor White
                Write-Host ""
                Write-Host "EXAMPLES:" -ForegroundColor Yellow
                Write-Host "  /config-live show" -ForegroundColor Gray
                Write-Host "  /config-live set liveDisplay.refreshInterval=1500" -ForegroundColor Gray
                Write-Host "  /config-live reset liveDisplay" -ForegroundColor Gray
                Write-Host "  /config-live backup" -ForegroundColor Gray
            }
            
            default {
                Write-Error "Unknown command: $command"
                Write-Host "Use '/config-live help' to see available commands" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Error "Live features configuration command failed: $($_.Exception.Message)"
        Write-Host "💡 Use '/config-live info' to check system status" -ForegroundColor Yellow
    }
}

function ConvertTo-ConfigValue {
    <#
    .SYNOPSIS
    Convert string value to appropriate type for configuration
    #>
    param([string]$ValueString)
    
    # Try to parse as boolean
    if ($ValueString -eq "true" -or $ValueString -eq "True" -or $ValueString -eq "TRUE") {
        return $true
    }
    if ($ValueString -eq "false" -or $ValueString -eq "False" -or $ValueString -eq "FALSE") {
        return $false
    }
    
    # Try to parse as integer
    if ($ValueString -match '^\d+$') {
        return [int]$ValueString
    }
    
    # Return as string
    return $ValueString
}

# --- Create Aliases ---
# Core playback aliases
Set-Alias -Name pn -Value Show-SpotifyTrack -Force -ErrorAction SilentlyContinue
Set-Alias -Name plays-now -Value Show-SpotifyTrack -Force -ErrorAction SilentlyContinue
Set-Alias -Name music -Value Show-SpotifyTrack -Force -ErrorAction SilentlyContinue

# Override PowerShell built-in 'sp' (Set-ItemProperty)
try {
    Remove-Item -Path Alias:\sp -Force -ErrorAction SilentlyContinue
    Set-Alias -Name sp -Value Show-SpotifyTrack -Force -Scope Global -ErrorAction SilentlyContinue
} catch {
    Write-Verbose "Could not override 'sp' alias: $($_.Exception.Message)"
}

Set-Alias -Name vol -Value volume -Force -ErrorAction SilentlyContinue
Set-Alias -Name sh -Value shuffle -Force -ErrorAction SilentlyContinue
Set-Alias -Name rep -Value repeat -Force -ErrorAction SilentlyContinue
Set-Alias -Name tr -Value transfer -Force -ErrorAction SilentlyContinue
Set-Alias -Name q -Value queue -Force -ErrorAction SilentlyContinue
Set-Alias -Name pq -Value play-queue -Force -ErrorAction SilentlyContinue
Set-Alias -Name pl -Value playlists -Force -ErrorAction SilentlyContinue

# Help aliases
Set-Alias -Name spotify -Value Get-SpotifyHelp -Force -ErrorAction SilentlyContinue

# Override PowerShell built-in 'help' function
try {
    Remove-Item -Path Alias:\help -Force -ErrorAction SilentlyContinue
    Set-Alias -Name help -Value Get-SpotifyHelp -Force -Scope Global -ErrorAction SilentlyContinue
} catch {
    Write-Verbose "Could not override 'help' alias: $($_.Exception.Message)"
}

Set-Alias -Name spotify-help -Value Get-SpotifyHelp -Force -ErrorAction SilentlyContinue

# Live features aliases
Set-Alias -Name slw -Value Show-SpotifyLyricsForm -Force -ErrorAction SilentlyContinue
Set-Alias -Name ShowLyrics -Value Show-SpotifyLyricsForm -Force -ErrorAction SilentlyContinue

# --- Export Module Members ---
# Export ALL functions and aliases (from this module and imported submodules)
Export-ModuleMember -Function * -Alias *