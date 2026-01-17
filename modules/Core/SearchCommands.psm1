# Spotify PowerShell Module - Main Orchestrator

# --- Import Live Features ---
$script:LiveFeaturesModulePath = Join-Path $PSScriptRoot "LiveFeatures\SpotifyLiveFeatures.psm1"
if (Test-Path $script:LiveFeaturesModulePath) {
    try {
        Import-Module $script:LiveFeaturesModulePath -Force -Global
        $script:LiveFeaturesAvailable = $true
        Write-Verbose "Live Features module loaded successfully"
    } catch {
        Write-Warning "Failed to load Live Features module: $($_.Exception.Message)"
        $script:LiveFeaturesAvailable = $false
    }
} else {
    Write-Verbose "Live Features module not found at: $script:LiveFeaturesModulePath"
    $script:LiveFeaturesAvailable = $false
}

# Note: Core modules are imported by SpotifyModule.psm1
# No need to import them again here

# --- Search Functions ---

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
    Fetches lyrics from external providers (Genius, Musixmatch) and displays them
    with optional scrolling and synchronized highlighting.
    
    .PARAMETER Artist
    Artist name (optional - uses current track if not specified)
    
    .PARAMETER Track
    Track name (optional - uses current track if not specified)
    
    .PARAMETER Scroll
    Enable scrollable display with keyboard navigation
    
    .EXAMPLE
    Get-SpotifyLyrics
    Get lyrics for currently playing track
    
    .EXAMPLE
    Get-SpotifyLyrics -Artist "Queen" -Track "Bohemian Rhapsody"
    Get lyrics for specific track
    
    .EXAMPLE
    lyrics
    Quick alias to get current track lyrics
    #>
    
    param(
        [string]$Artist,
        [string]$Track,
        [switch]$Scroll
    )
    
    # Skip live features check for now - just show lyrics info
    
    try {
        # Initialize live features if not already done
        if (-not (Get-SpotifyLiveFeaturesStatus).IsInitialized) {
            Write-Host "🔄 Initializing live features..." -ForegroundColor Cyan
            Initialize-SpotifyLiveFeatures
        }
        
        $lyricsResult = $null
        
        if ($Artist -and $Track) {
            # Get lyrics for specific track
            Write-Host "🎵 Fetching lyrics for: $Artist - $Track" -ForegroundColor Cyan
            $lyricsResult = Get-SpotifyLyrics -Artist $Artist -Track $Track
        } else {
            # Get lyrics for current track
            Write-Host "🎵 Fetching lyrics for current track..." -ForegroundColor Cyan
            
            # Get current track info
            $currentTrack = Show-SpotifyTrack 2>&1 | Out-String
            if ($currentTrack -match "🎵 (.+)" -and $currentTrack -match "👤 (.+)") {
                $trackName = $matches[1].Trim()
                $artistName = $matches[1].Trim()
                
                # Extract from plays-now output
                plays-now
                Write-Host ""
                
                # Check if Genius API is configured
                if ($env:GENIUS_ACCESS_TOKEN) {
                    Write-Host "🎤 Genius API: ✅ Configured" -ForegroundColor Green
                    Write-Host "🔍 Searching for lyrics..." -ForegroundColor Cyan
                    
                    try {
                        # Simple Genius API search
                        $searchQuery = "$artistName $trackName"
                        $searchUrl = "https://api.genius.com/search?q=$([System.Web.HttpUtility]::UrlEncode($searchQuery))"
                        
                        $headers = @{
                            'Authorization' = "Bearer $env:GENIUS_ACCESS_TOKEN"
                        }
                        
                        $searchResponse = Invoke-RestMethod -Method Post -Uri $searchUrl -Headers $headers
                        
                        if ($searchResponse.response.hits.Count -gt 0) {
                            $song = $searchResponse.response.hits[0].result
                            Write-Host "✅ Found: $($song.full_title)" -ForegroundColor Green
                            Write-Host "🔗 Lyrics URL: $($song.url)" -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "💡 Note: Genius API doesn't provide direct lyrics text." -ForegroundColor Yellow
                            Write-Host "   Visit the URL above to read the full lyrics." -ForegroundColor Gray
                            
                            return @{
                                Success = $true
                                Title = $song.title
                                Artist = $song.primary_artist.name
                                Url = $song.url
                                Message = "Lyrics URL found"
                            }
                        } else {
                            Write-Host "❌ No lyrics found on Genius" -ForegroundColor Red
                        }
                    } catch {
                        Write-Host "❌ Error searching Genius: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else {
                    Write-Host "🎤 Lyrics Integration Status:" -ForegroundColor Yellow
                    Write-Host "   • Genius API: ❌ Not configured" -ForegroundColor Gray
                    Write-Host "   • Musixmatch API: ❌ Not configured" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "💡 To enable lyrics:" -ForegroundColor Cyan
                    Write-Host "   1. Get a free Genius API token at https://genius.com/api-clients" -ForegroundColor White
                    Write-Host "   2. Set: `$env:GENIUS_ACCESS_TOKEN = 'your_token'" -ForegroundColor White
                }
            } else {
                Write-Host "❌ Could not get current track information" -ForegroundColor Red
            }
            
            return @{
                Success = $false
                Message = "Lyrics not found or not configured"
            }
        }
        
        if ($lyricsResult.Success) {
            Write-Host "✅ Lyrics found!" -ForegroundColor Green
            Write-Host "📝 Source: $($lyricsResult.Source)" -ForegroundColor Gray
            Write-Host ""
            
            if ($Scroll) {
                # TODO: Implement scrollable display
                Write-Host "📜 Scrollable display (use arrow keys, 'q' to quit):" -ForegroundColor Yellow
            }
            
            # Display lyrics
            Write-Host $lyricsResult.Lyrics -ForegroundColor White
            
            if ($lyricsResult.HasSyncedLyrics) {
                Write-Host ""
                Write-Host "🎤 Synchronized lyrics available" -ForegroundColor Green
            }
            
        } else {
            Write-Host "❌ Lyrics not found: $($lyricsResult.Error)" -ForegroundColor Red
            Write-Host "💡 Try searching manually or check if the track name is correct" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "❌ Failed to get lyrics: $($_.Exception.Message)" -ForegroundColor Red
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
                    Write-Host "• Re-authenticate: .\spotifyCLI.ps1" -ForegroundColor White
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
    Write-Host "• Get-SpotifyHelp <command>          # Specific command help" -ForegroundColor White
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
# play, pause, next, previous moved to modules/Core/PlaybackCommands.psm1
function devices {
    try {
        $devicesResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/devices"
        if (-not $devicesResponse -or -not $devicesResponse.devices -or $devicesResponse.devices.Count -eq 0) {
            Write-Host "📱 No Spotify Connect devices found" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "💡 To use device management features:" -ForegroundColor Cyan
            Write-Host "1. Open Spotify on any device (phone, computer, speaker, etc.)" -ForegroundColor White
            Write-Host "2. Start playing any song to activate the device" -ForegroundColor White
            Write-Host "3. Run 'devices' again to see available devices" -ForegroundColor White
            Write-Host ""
            Write-Host "🎵 Supported device types: Computer, Phone, Speaker, TV, Tablet" -ForegroundColor Gray
            return
        }
        # Store devices in session for numbered reference
        Set-SessionDevices -Devices $devicesResponse.devices
        Write-Host "📱 Available Devices:" -ForegroundColor Cyan
        $i = 1
        foreach ($device in $devicesResponse.devices) {
            $deviceIcon = switch ($device.type.ToLower()) {
                "computer" { "[PC]" }
                "smartphone" { "[Phone]" }
                "speaker" { "[Speaker]" }
                "tv" { "[TV]" }
                default { "[Device]" }
            }
            $activeStatus = if ($device.is_active) { "Active" } else { "Inactive" }
            $volumeInfo = if ($device.volume_percent -ne $null) { ", Volume: $($device.volume_percent)%" } else { "" }
            Write-Host "$i. $deviceIcon $($device.name) ($($device.type)) - $activeStatus$volumeInfo" -ForegroundColor White
            $i++
        }
        Write-Host ""
        Write-Host "💡 Tip: Use 'transfer 1' to switch to device #1" -ForegroundColor Gray
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($_.Exception.StatusCode -eq 403) {
            Write-Host "🚫 Permission Error: Device management requires Spotify Premium." -ForegroundColor Red
        }
        else {
            Write-Host "❌ API Error: $errorMessage" -ForegroundColor Red
            Write-Host "💡 Check your internet connection and try again" -ForegroundColor Yellow
        }
    }
}
function search {
    <#
    .SYNOPSIS
    Search for music with advanced filters
    .PARAMETER Query
    Search query (supports Spotify search syntax)
    .PARAMETER Type
    Filter by type: track, artist, album, episode, or all (default)
    .PARAMETER Genre
    Filter by genre
    .PARAMETER Year
    Filter by release year (e.g., 2023 or 2020-2023)
    .PARAMETER Limit
    Number of results to return (default: 10, max: 50)
    .EXAMPLE
    search "bohemian rhapsody"
    Basic search for tracks, artists, albums, and episodes
    .EXAMPLE
    search -Query "love" -Type track -Limit 20
    Search for 20 tracks containing "love"
    .EXAMPLE
    search -Query "rock" -Genre "classic rock" -Year 1970-1979
    Advanced search with genre and year filters
    #>
    param(
        [Parameter(Position=0)]
        [string]$Query,

        [ValidateSet("track", "artist", "album", "episode", "all")]
        [string]$Type = "all",

        [string]$Genre,

        [string]$Year,

        [int]$Limit = 10
    )

    if ([string]::IsNullOrWhiteSpace($Query)) {
        Write-Host "Usage: search '<query>'" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Advanced options:" -ForegroundColor Cyan
        Write-Host "  search '<query>' -Type track     # Search only tracks" -ForegroundColor Gray
        Write-Host "  search '<query>' -Genre rock     # Filter by genre" -ForegroundColor Gray
        Write-Host "  search '<query>' -Year 2023      # Filter by year" -ForegroundColor Gray
        Write-Host "  search '<query>' -Limit 20       # Show more results" -ForegroundColor Gray
        return
    }

    # Build advanced query
    $advancedQuery = $Query

    if ($Genre) {
        $advancedQuery += " genre:$Genre"
    }

    if ($Year) {
        $advancedQuery += " year:$Year"
    }

    # Validate limit
    $Limit = [Math]::Min(50, [Math]::Max(1, $Limit))

    try {
        $searchType = if ($Type -eq "all") { "track,artist,album,episode" } else { $Type }

        $searchQuery = @{
            q = $advancedQuery
            type = $searchType
            limit = $Limit.ToString()
        }

        # Show search info
        Write-Host "🔍 Searching for: $Query" -ForegroundColor Cyan
        if ($Genre -or $Year) {
            Write-Host "   Filters: " -ForegroundColor Gray -NoNewline
            if ($Genre) { Write-Host "Genre=$Genre " -ForegroundColor Yellow -NoNewline }
            if ($Year) { Write-Host "Year=$Year" -ForegroundColor Yellow -NoNewline }
            Write-Host ""
        }
        Write-Host ""

        $results = Invoke-SpotifyApi -Method GET -Path "/search" -Query $searchQuery
        if (-not $results) {
            Write-Host "🔍 No results found for '$Query'." -ForegroundColor Yellow
            return
        }
        Write-Host "🔍 Search Results for '$Query':" -ForegroundColor Cyan
        Write-Host ""
        # Combine tracks and episodes for numbered reference
        $allItems = @()
        $trackCount = 0
        $episodeCount = 0
        if ($results.tracks -and $results.tracks.items) {
            $trackCount = $results.tracks.items.Count
            $allItems += $results.tracks.items[0..4] | ForEach-Object {
                $_ | Add-Member -NotePropertyName "search_type" -NotePropertyValue "track" -PassThru
            }
        }
        if ($results.episodes -and $results.episodes.items) {
            $episodeCount = $results.episodes.items.Count
            $allItems += $results.episodes.items[0..4] | ForEach-Object {
                $_ | Add-Member -NotePropertyName "search_type" -NotePropertyValue "episode" -PassThru
            }
        }
        # Store combined items in session for numbered reference
        Set-SessionTracks -Tracks $allItems[0..9]  # Store up to 10 items (tracks + episodes)
        if ($results.tracks -and $results.tracks.items) {
            Write-Host "TRACKS:" -ForegroundColor Yellow
            $i = 1
            foreach ($track in $results.tracks.items[0..4]) {
                $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
                Write-Host "$i. $($track.name) - $artists ($($track.album.name))" -ForegroundColor White
                $i++
            }
            Write-Host ""
        }
        if ($results.episodes -and $results.episodes.items) {
            Write-Host "PODCAST EPISODES:" -ForegroundColor Magenta
            $startIndex = ($results.tracks.items.Count -gt 0) ? ($results.tracks.items[0..4].Count + 1) : 1
            $i = $startIndex
            foreach ($episode in $results.episodes.items[0..4]) {
                $showName = $episode.show.name
                $description = if ($episode.description -and $episode.description.Length -gt 50) {
                    $episode.description.Substring(0, 47) + "..."
                } else {
                    $episode.description
                }
                Write-Host "$i. 🎙️ $($episode.name) - $showName" -ForegroundColor White
                if ($description) {
                    Write-Host "   📝 $description" -ForegroundColor Gray
                }
                $i++
            }
            Write-Host ""
        }
        if ($allItems.Count -gt 0) {
            Write-Host "💡 Tip: Use 'play 1' to play item #1, or 'queue 2' to add item #2 to queue" -ForegroundColor Gray
            if ($episodeCount -gt 0) {
                Write-Host "💡 Podcast episodes can be saved using 'save-track <number>'" -ForegroundColor Gray
            }
            Write-Host "🎮 Press Enter for interactive navigation mode..." -ForegroundColor Cyan
            # Check if user wants to enter interactive mode
            $capabilities = Get-TerminalCapabilities
            if ($capabilities.SupportsInteractiveInput) {
                try {
                    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    if ($key.VirtualKeyCode -eq 13) { # Enter key
                        Start-InteractiveMode -Items $allItems -Title "Search Results for '$Query'"
                    }
                } catch {
                    # If ReadKey fails, just continue without interactive mode
                    Write-Host "ℹ️ Interactive mode not available in this terminal" -ForegroundColor Yellow
                }
            } else {
                Write-Host "ℹ️ Interactive mode not supported in this terminal" -ForegroundColor Yellow
            }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Search failed: $errorMessage" -ForegroundColor Red
            Write-Host "💡 Check your internet connection and Spotify authentication." -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred during search: $errorMessage" -ForegroundColor Red
        }
    }
}
function search-albums {
    <#
    .SYNOPSIS
    Search for albums only on Spotify
    .DESCRIPTION
    Searches Spotify for albums matching the query and displays results with smart numbering.
    Results are stored in session for use with play-album and queue-album commands.
    .PARAMETER Query
    The search query for albums
    .EXAMPLE
    search-albums "pink floyd"
    Search for Pink Floyd albums
    .EXAMPLE
    search-albums "the beatles"
    Search for Beatles albums
    #>
    param([string]$Query)
    if ([string]::IsNullOrWhiteSpace($Query)) {
        Write-Host "Usage: search-albums '<query>'" -ForegroundColor Yellow
        Write-Host "Example: search-albums 'pink floyd'" -ForegroundColor Gray
        return
    }
    try {
        $searchQuery = @{
            q = $Query
            type = "album"
            limit = "10"
        }
        Write-Host "🔍 Searching albums for: $Query" -ForegroundColor Gray
        $results = Invoke-SpotifyApi -Method GET -Path "/search" -Query $searchQuery
        if (-not $results -or -not $results.albums -or -not $results.albums.items -or $results.albums.items.Count -eq 0) {
            Write-Host "💿 No albums found for '$Query'" -ForegroundColor Yellow
            Write-Host "💡 Try a different search term or check spelling" -ForegroundColor Gray
            return
        }
        Write-Host "💿 Album Search Results for '$Query':" -ForegroundColor Cyan
        Write-Host ""
        # Store albums in session for numbered reference
        Set-SessionAlbums -Albums $results.albums.items[0..9]  # Store up to 10 albums
        $i = 1
        foreach ($album in $results.albums.items[0..9]) {
            if (-not $album) { break }
            $artists = ($album.artists | ForEach-Object { $_.name }) -join ", "
            $releaseYear = if ($album.release_date) {
                try {
                    [DateTime]::Parse($album.release_date).Year
                } catch {
                    $album.release_date.Split('-')[0]
                }
            } else {
                "Unknown"
            }
            Write-Host "$i. " -NoNewline -ForegroundColor White
            Write-Host "$($album.name)" -NoNewline -ForegroundColor Cyan
            Write-Host " - " -NoNewline -ForegroundColor Gray
            Write-Host "$artists" -NoNewline -ForegroundColor Yellow
            Write-Host " ($releaseYear)" -ForegroundColor Green
            Write-Host "   💿 $($album.total_tracks) tracks" -ForegroundColor Gray
            $i++
        }
        Write-Host ""
        Write-Host "💡 Tip: Use 'play-album 1' to play album #1, or 'queue-album 2' to add album #2 to queue" -ForegroundColor Gray
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Album search failed: $errorMessage" -ForegroundColor Red
            Write-Host "💡 Check your internet connection and Spotify authentication." -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred during album search: $errorMessage" -ForegroundColor Red
        }
    }
}
function play-album {
    <#
    .SYNOPSIS
    Play an album by number from the album search results
    .DESCRIPTION
    Plays an album by its number from the most recent search-albums results.
    The album will be played from the beginning.
    .PARAMETER AlbumNumber
    The number of the album from the search-albums command (1-10)
    .EXAMPLE
    play-album 1
    Play the first album from the search results
    .EXAMPLE
    search-albums "pink floyd"; play-album 2
    Search for Pink Floyd albums and play the second result
    #>
    param([Parameter(Mandatory)][int]$AlbumNumber)
    try {
        $sessionAlbums = Get-SessionAlbums
        # Check if we have session albums
        if (-not $sessionAlbums -or $sessionAlbums.Count -eq 0) {
            Write-Host "❌ No albums in session. Run 'search-albums' first." -ForegroundColor Red
            Write-Host "💡 Example: search-albums 'pink floyd'" -ForegroundColor Yellow
            return
        }
        # Validate album number
        if ($AlbumNumber -lt 1 -or $AlbumNumber -gt $sessionAlbums.Count) {
            Write-Host "❌ Invalid album number. Use 1-$($sessionAlbums.Count)" -ForegroundColor Red
            Write-Host "💡 Use 'search-albums' to see available albums" -ForegroundColor Yellow
            return
        }
        $album = $sessionAlbums[$AlbumNumber - 1]
        $albumName = $album.name
        $albumUri = $album.uri
        $artists = ($album.artists | ForEach-Object { $_.name }) -join ", "
        Write-Host "🎵 Playing album #${AlbumNumber}: '$albumName' by $artists..." -ForegroundColor Cyan
        # Play the album using its context URI
        $body = @{ context_uri = $albumUri }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
        Write-Host "▶️ Now playing: '$albumName'" -ForegroundColor Green
        Write-Host "👤 Artist: $artists" -ForegroundColor Yellow
        Write-Host "💿 $($album.total_tracks) tracks" -ForegroundColor Gray
        # Show release info if available
        if ($album.release_date) {
            try {
                $releaseYear = [DateTime]::Parse($album.release_date).Year
                Write-Host "📅 Released: $releaseYear" -ForegroundColor Gray
            } catch {
                Write-Host "📅 Released: $($album.release_date)" -ForegroundColor Gray
            }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($_.Exception.StatusCode -eq 403 -or $_.Exception.StatusCode -eq 404) {
            Write-Host "❌ Could not play album." -ForegroundColor Red
            if ($_.Exception.StatusCode -eq 403) {
                Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
            } elseif ($_.Exception.StatusCode -eq 404) {
                Write-Host "💡 Make sure Spotify is running on an active device." -ForegroundColor Yellow
                Write-Host "💡 Try running 'devices' to see available devices." -ForegroundColor Yellow
            }
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while trying to play the album: $errorMessage" -ForegroundColor Red
        }
    }
}
function queue-album {
    <#
    .SYNOPSIS
    Add an entire album to the queue by number from album search results
    .DESCRIPTION
    Adds all tracks from an album to the current playback queue.
    The album is identified by its number from the most recent search-albums results.
    .PARAMETER AlbumNumber
    The number of the album from the search-albums command (1-10)
    .EXAMPLE
    queue-album 1
    Add all tracks from album #1 to the queue
    .EXAMPLE
    search-albums "radiohead"; queue-album 3
    Search for Radiohead albums and add the third result to queue
    #>
    param([Parameter(Mandatory)][int]$AlbumNumber)
    try {
        $sessionAlbums = Get-SessionAlbums
        # Check if we have session albums
        if (-not $sessionAlbums -or $sessionAlbums.Count -eq 0) {
            Write-Host "❌ No albums in session. Run 'search-albums' first." -ForegroundColor Red
            Write-Host "💡 Example: search-albums 'radiohead'" -ForegroundColor Yellow
            return
        }
        # Validate album number
        if ($AlbumNumber -lt 1 -or $AlbumNumber -gt $sessionAlbums.Count) {
            Write-Host "❌ Invalid album number. Use 1-$($sessionAlbums.Count)" -ForegroundColor Red
            Write-Host "💡 Use 'search-albums' to see available albums" -ForegroundColor Yellow
            return
        }
        $album = $sessionAlbums[$AlbumNumber - 1]
        $albumName = $album.name
        $albumId = $album.id
        $artists = ($album.artists | ForEach-Object { $_.name }) -join ", "
        Write-Host "🎵 Adding album '$albumName' by $artists to queue..." -ForegroundColor Cyan
        # Get album tracks
        $tracksResponse = Invoke-SpotifyApi -Method GET -Path "/albums/$albumId/tracks" -Query @{ limit = 50 }
        if (-not $tracksResponse -or -not $tracksResponse.items) {
            Write-Host "❌ Could not get album tracks" -ForegroundColor Red
            return
        }
        $addedCount = 0
        $skippedCount = 0
        Write-Host "📀 Adding $($tracksResponse.items.Count) tracks to queue..." -ForegroundColor Gray
        foreach ($track in $tracksResponse.items) {
            if ($track -and $track.uri -and $track.uri.StartsWith("spotify:track:")) {
                try {
                    # Add track to queue
                    $query = @{ uri = $track.uri }
                    Invoke-SpotifyApi -Method POST -Path "/me/player/queue" -Query $query | Out-Null
                    $addedCount++
                    # Small delay to avoid rate limiting
                    Start-Sleep -Milliseconds 100
                }
                catch {
                    $errorMessage = $_.Exception.Message
                    if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
                        Write-Host "🔐 Authentication Error during track queueing (track: $($track.name)): Your Spotify session has expired." -ForegroundColor Red
                        Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
                        $skippedCount++
                        break # Stop adding tracks if auth fails
                    }
                    elseif ($_.Exception.StatusCode -eq 403) {
                        Write-Host "❌ Could not add track '$($track.name)' to queue: $errorMessage" -ForegroundColor Red
                        Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
                        $skippedCount++
                    }
                    else {
                        Write-Host "❌ An unexpected error occurred while queuing track '$($track.name)': $errorMessage" -ForegroundColor Red
                        $skippedCount++
                    }
                }
            }
        }
        Write-Host "✅ Album '$albumName' added to queue. $addedCount tracks added, $skippedCount tracks skipped." -ForegroundColor Green
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($_.Exception.StatusCode -eq 403) {
            Write-Host "❌ Could not add album to queue." -ForegroundColor Red
            Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while processing the album: $errorMessage" -ForegroundColor Red
        }
    }
}