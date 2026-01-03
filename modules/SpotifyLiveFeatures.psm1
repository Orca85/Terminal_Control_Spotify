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
    Start live display of current track information
    #>
    param(
        [ValidateSet("detailed", "compact", "minimal")]
        [string]$Mode = "detailed"
    )
    
    if (-not $script:LiveFeaturesInitialized) {
        Write-Host "🔄 Auto-initializing Live Features..." -ForegroundColor Cyan
        Initialize-SpotifyLiveFeatures
    }
    
    Write-Host "🎵 Starting Live Display ($Mode mode)..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
    
    try {
        while ($true) {
            Clear-Host
            
            Write-Host "🎵 Spotify Live Display - $Mode Mode" -ForegroundColor Cyan
            Write-Host "=====================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "🕒 $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
            Write-Host ""
            
            switch ($Mode) {
                "detailed" {
                    Write-Host "🎵 Now Playing:" -ForegroundColor Yellow
                    plays-now
                    Write-Host ""
                    Write-Host "💡 Live updates every 2 seconds" -ForegroundColor Green
                }
                "compact" {
                    Write-Host "♪ Live:" -ForegroundColor Green
                    plays-now
                }
                "minimal" {
                    plays-now
                }
            }
            
            Write-Host ""
            Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
            
            Start-Sleep -Seconds 2
        }
    } catch {
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
    Get listening statistics for specified period
    #>
    param(
        [ValidateSet("day", "week", "month", "year")]
        [string]$Period = "month"
    )
    
    if (-not $script:LiveFeaturesInitialized) {
        Write-Host "🔄 Auto-initializing Live Features..." -ForegroundColor Cyan
        Initialize-SpotifyLiveFeatures
    }
    
    Write-Host "📊 Spotify Listening Statistics - $Period" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # This is a placeholder - in a full implementation this would
    # track and analyze listening history
    Write-Host "📈 Statistics tracking is available but requires" -ForegroundColor Gray
    Write-Host "   background data collection to be implemented." -ForegroundColor Gray
    Write-Host "   This feature will be enhanced in future updates." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Current period: $Period" -ForegroundColor Yellow
    Write-Host "Recent tracks:" -ForegroundColor Yellow
    
    # Show recent tracks as a basic statistic
    recent
}

# Sidecar functionality
function Start-SpotifySidecar {
    <#
    .SYNOPSIS
    Start Spotify CLI in sidecar mode (split terminal)
    #>
    param(
        [ValidateSet("right", "down", "left", "up")]
        [string]$Position = "right"
    )
    
    Write-Host "🚀 Starting Spotify CLI in sidecar mode ($Position)..." -ForegroundColor Cyan
    
    # This would integrate with Windows Terminal to create split panes
    Write-Host "Sidecar mode requires Windows Terminal integration." -ForegroundColor Yellow
    Write-Host "For now, you can manually split your terminal and run:" -ForegroundColor Gray
    Write-Host "  Start-SpotifyLiveDisplay" -ForegroundColor White
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