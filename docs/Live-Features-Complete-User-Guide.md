# Spotify CLI Live Features - Complete User Guide

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Live Display Features](#live-display-features)
4. [Lyrics Engine](#lyrics-engine)
5. [Statistics & Analytics](#statistics--analytics)
6. [Configuration Management](#configuration-management)
7. [Advanced Usage](#advanced-usage)
8. [Troubleshooting](#troubleshooting)
9. [Performance Optimization](#performance-optimization)
10. [API Reference](#api-reference)

## Overview

The Spotify CLI Live Features transform your terminal into a dynamic music control center with three powerful components:

- **Live Display Engine**: Real-time track information with animated progress bars
- **Lyrics Engine**: Synchronized lyrics display with multiple provider support
- **Statistics Engine**: Comprehensive listening analytics and visualizations

### System Requirements

- PowerShell 5.1+ (Windows) or PowerShell 7+ (cross-platform)
- Spotify Premium account
- Windows Terminal (recommended for sidecar mode)
- Internet connection for lyrics and API access

## Getting Started

### Initialization

Before using any live features, initialize the system:

```powershell
# Initialize all live features
Initialize-SpotifyLiveFeatures

# Check feature status
Get-SpotifyLiveFeaturesStatus
```

### Quick Start Examples

```powershell
# Start live display mode
Start-SpotifyLiveDisplay -Mode detailed

# Get lyrics for current track
Get-SpotifyCurrentTrackLyrics

# Generate monthly statistics
Get-SpotifyListeningStatistics -Period month
```

## Live Display Features

### Display Modes

#### Console Live Mode

Real-time display in your current terminal window:

```powershell
# Basic live mode (detailed view)
Start-SpotifyLiveDisplay

# Compact mode for smaller terminals
Start-SpotifyLiveDisplay -Mode compact

# Minimal mode for background monitoring
Start-SpotifyLiveDisplay -Mode minimal
```

**Display Mode Comparison:**

| Mode     | Features                                                  | Best For                 |
| -------- | --------------------------------------------------------- | ------------------------ |
| Detailed | Full track info, album art, progress bar, controls status | Primary music monitoring |
| Compact  | Essential info, smaller progress bar                      | Limited screen space     |
| Minimal  | Track name and progress only                              | Background monitoring    |

#### Sidecar Mode (Windows Terminal)

Split-pane display that runs alongside your work:

```powershell
# Start sidecar on right side (default)
spotify --sidecar

# Start sidecar on left side
spotify --sidecar --position left

# Custom width (30% of terminal)
spotify --sidecar --width 30

# Auto-hide when no music playing
spotify --sidecar --auto-hide
```

### Live Display Controls

While in live mode, use these keyboard shortcuts:

| Key      | Action                    |
| -------- | ------------------------- |
| `Ctrl+C` | Exit live mode gracefully |
| `Space`  | Pause/resume playback     |
| `→`      | Next track                |
| `←`      | Previous track            |
| `↑/↓`    | Volume up/down            |
| `R`      | Toggle repeat mode        |
| `S`      | Toggle shuffle mode       |

### Progress Bar Styles

Customize the visual appearance:

```powershell
# Set progress bar style
Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
    progressBarStyle = "blocks"  # blocks, bars, dots, arrows, circles
}
```

**Style Examples:**

- **Blocks**: `████████░░░░` (default)
- **Bars**: `========----`
- **Dots**: `●●●●●○○○○○○○`
- **Arrows**: `►►►►►►▷▷▷▷▷▷`
- **Circles**: `⬤⬤⬤⬤⬜⬜⬜⬜`

## Lyrics Engine

### Basic Lyrics Commands

```powershell
# Show lyrics for current track
Get-SpotifyCurrentTrackLyrics

# Show lyrics for specific track
Get-SpotifyLyrics -Artist "Queen" -Track "Bohemian Rhapsody"

# Display lyrics interactively
Show-Lyrics $lyricsData

# Format lyrics for display
Format-LyricsDisplay $lyricsData -CurrentPositionMs 30000
```

### Interactive Lyrics Viewer

The interactive viewer provides a rich lyrics experience:

```powershell
# Start interactive lyrics viewer
$lyrics = Get-SpotifyCurrentTrackLyrics
Show-Lyrics $lyrics
```

**Interactive Controls:**

| Key            | Action                      |
| -------------- | --------------------------- |
| `↑/↓`          | Scroll up/down line by line |
| `Page Up/Down` | Scroll by page              |
| `Home/End`     | Jump to beginning/end       |
| `/`            | Start search                |
| `n/N`          | Next/previous search result |
| `T`            | Toggle timestamps           |
| `H`            | Toggle highlighting         |
| `Esc/Q`        | Exit viewer                 |

### Synchronized Lyrics

For tracks with synchronized lyrics:

- Current line is highlighted in real-time
- Progress indicator shows position in song
- Auto-scroll follows playback position
- Timestamp display shows precise timing

### Lyrics Providers

The engine supports multiple providers with automatic fallback:

1. **Genius** (primary) - Rich metadata and lyrics
2. **Musixmatch** (fallback) - Synchronized lyrics support
3. **Mock Provider** (testing) - Sample lyrics for development

```powershell
# Check available providers
Test-LyricsProviders

# Configure preferred provider
Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
    preferredProvider = "genius"
}
```

### Lyrics Caching

Lyrics are automatically cached for offline access:

```powershell
# View cache statistics
$status = Get-SpotifyLiveFeaturesStatus
$status.LyricsCacheStats

# Clear lyrics cache
$manager = New-LyricsManager
$manager.ClearCache()

# Cleanup old cache entries (older than 30 days)
$manager.CleanupCache(720)  # 720 hours = 30 days
```

## Statistics & Analytics

### Basic Statistics Commands

```powershell
# Generate statistics for different periods
Get-SpotifyListeningStatistics -Period day
Get-SpotifyListeningStatistics -Period week
Get-SpotifyListeningStatistics -Period month
Get-SpotifyListeningStatistics -Period year
```

### Comprehensive Statistics Report

The statistics engine provides detailed analytics:

```powershell
# Generate full report
$report = Get-SpotifyListeningStatistics -Period month
Write-Host $report
```

**Report Sections:**

1. **Summary Statistics**

   - Total listening time
   - Track count
   - Unique artists/albums
   - Current listening streak

2. **Top Items**

   - Top 10 tracks with play counts
   - Top 10 artists with statistics
   - Top 10 albums

3. **Genre Analysis**

   - Genre distribution pie chart
   - Dominant genres
   - Listening diversity metrics

4. **Listening Patterns**

   - Hourly activity patterns
   - Weekly listening habits
   - Peak listening times

5. **Streak Analysis**
   - Current streak status
   - Longest streak record
   - Active listening days

### Data Export

Export your statistics in multiple formats:

```powershell
# Create statistics engine
$engine = New-StatisticsEngine @{
    DataDirectory = "$env:APPDATA\SpotifyCLI\Statistics"
    TrackingEnabled = $true
}

# Export as JSON
$jsonExport = $engine.ExportData("json", "month")
Set-Content -Path "my-stats.json" -Value $jsonExport.Data

# Export as CSV
$csvExport = $engine.ExportData("csv", "month")
Set-Content -Path "my-stats.csv" -Value $csvExport.Data

# Export raw listening data
$rawData = $engine.ExportRawData([DateTime]::Now.AddDays(-30), [DateTime]::Now, "json")
Set-Content -Path "raw-data.json" -Value $rawData.Data
```

### Data Backup and Restore

Protect your listening history:

```powershell
# Create backup
$backup = $engine.BackupData("C:\Backups\Spotify")
Write-Host "Backup created: $($backup.BackupFile)"

# Restore from backup
$restore = $engine.RestoreData("C:\Backups\Spotify\spotify_backup_20241106_143022.json")
Write-Host "Restored $($restore.RestoredEvents) events"
```

### ASCII Visualizations

The statistics engine generates beautiful ASCII charts:

```powershell
# Generate visualization components
$viz = New-VisualizationGenerator

# Create bar chart for top artists
$topArtists = @{ "Artist 1" = 45; "Artist 2" = 32; "Artist 3" = 28 }
$chart = $viz.GenerateBarChart($topArtists, "Top Artists", 50)
Write-Host $chart

# Create pie chart for genres
$genres = @{ "Rock" = 40; "Pop" = 30; "Jazz" = 20; "Classical" = 10 }
$pie = $viz.GeneratePieChart($genres, "Genre Distribution")
Write-Host $pie
```

## Configuration Management

### Configuration Structure

The live features use a hierarchical configuration system:

```json
{
  "liveDisplay": {
    "refreshInterval": 1000,
    "displayMode": "detailed",
    "sidecarPosition": "right",
    "sidecarWidth": 40,
    "showAlbumArt": true,
    "colorScheme": "auto",
    "progressBarStyle": "blocks",
    "performanceMode": true
  },
  "lyrics": {
    "preferredProvider": "genius",
    "cacheEnabled": true,
    "cacheRetentionHours": 720,
    "syncHighlighting": true,
    "scrollSpeed": 3,
    "showTimestamps": true,
    "geniusApiKey": "",
    "musixmatchApiKey": ""
  },
  "statistics": {
    "trackingEnabled": true,
    "retentionDays": 365,
    "exportFormat": "json",
    "defaultPeriod": "month",
    "dataDirectory": "%APPDATA%\\SpotifyCLI\\Statistics"
  },
  "apiClient": {
    "rateLimitPerSecond": 1,
    "timeoutMs": 10000,
    "retryAttempts": 3,
    "cacheEnabled": true,
    "cacheTtlMs": 60000
  }
}
```

### Configuration Commands

```powershell
# View current configuration
Get-SpotifyLiveFeaturesStatus

# Update live display settings
Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
    refreshInterval = 2000
    displayMode = "compact"
    progressBarStyle = "bars"
}

# Update lyrics settings
Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
    preferredProvider = "musixmatch"
    cacheRetentionHours = 168  # 1 week
    syncHighlighting = $true
}

# Update statistics settings
Set-SpotifyLiveFeaturesConfiguration -Section "statistics" -Settings @{
    trackingEnabled = $true
    retentionDays = 180  # 6 months
    defaultPeriod = "week"
}

# Reset to defaults
Reset-SpotifyLiveFeaturesConfiguration
```

### Configuration File Locations

- **Windows**: `%APPDATA%\SpotifyCLI\LiveFeatures\config.json`
- **macOS**: `~/Library/Application Support/SpotifyCLI/LiveFeatures/config.json`
- **Linux**: `~/.config/SpotifyCLI/LiveFeatures/config.json`

## Advanced Usage

### Custom Display Engines

Create custom display implementations:

```powershell
# Create console display engine with custom settings
$consoleEngine = New-LiveDisplayEngine -Type "Console" -Configuration @{
    RefreshInterval = 500
    DisplayMode = "detailed"
    PerformanceMode = $true
}

# Create sidecar display engine
$sidecarEngine = New-LiveDisplayEngine -Type "Sidecar" -Configuration @{
    Position = "right"
    Size = 35
}

# Test display capabilities
Test-DisplayCapabilities
```

### Background Processing

The system uses background processing for performance:

```powershell
# Check background processing status
$status = Get-SpotifyLiveFeaturesStatus
$status.BackgroundProcessingStats

# Configure background processing
Set-SpotifyLiveFeaturesConfiguration -Section "backgroundProcessing" -Settings @{
    batchSize = 10
    batchIntervalMs = 2000
    memoryThresholdMB = 150
}
```

### Performance Monitoring

Monitor system performance:

```powershell
# Get performance statistics
$status = Get-SpotifyLiveFeaturesStatus
Write-Host "API Client Stats:" -ForegroundColor Cyan
$status.ApiClientStats | Format-Table

Write-Host "Lyrics Cache Stats:" -ForegroundColor Cyan
$status.LyricsCacheStats | Format-Table

Write-Host "Statistics Storage Stats:" -ForegroundColor Cyan
$status.StatisticsStorageStats | Format-Table
```

### Integration with Main CLI

The live features integrate seamlessly with the main Spotify CLI:

```powershell
# Use with existing commands
plays-now  # Show current track
Start-SpotifyLiveDisplay  # Start live display

# Combine with search
search "bohemian rhapsody"
play 1
Get-SpotifyCurrentTrackLyrics
```

## Troubleshooting

### Common Issues and Solutions

#### Live Display Issues

**Problem**: Live display is flickering or updating too frequently

```powershell
# Solution: Increase refresh interval
Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
    refreshInterval = 2000  # 2 seconds
}
```

**Problem**: Display not updating or showing "No track information"

```powershell
# Check Spotify connection
plays-now

# Verify API client status
$status = Get-SpotifyLiveFeaturesStatus
$status.Features.ApiClient

# Restart live features
Stop-SpotifyLiveFeatures
Initialize-SpotifyLiveFeatures
```

**Problem**: Sidecar mode not working

```powershell
# Check Windows Terminal support
Test-DisplayCapabilities

# Verify Windows Terminal is running
$env:WT_SESSION  # Should return a value if in Windows Terminal
```

#### Lyrics Issues

**Problem**: No lyrics found for tracks

```powershell
# Check provider availability
Test-LyricsProviders

# Try different provider
Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
    preferredProvider = "musixmatch"
}

# Check internet connection and API keys
$status = Get-SpotifyLiveFeaturesStatus
$status.Features.Lyrics
```

**Problem**: Synchronized lyrics not highlighting correctly

```powershell
# Enable sync highlighting
Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
    syncHighlighting = $true
}

# Clear lyrics cache to refresh data
$manager = New-LyricsManager
$manager.ClearCache()
```

**Problem**: Lyrics cache taking too much space

```powershell
# Check cache size
$status = Get-SpotifyLiveFeaturesStatus
$status.LyricsCacheStats.TotalSizeMB

# Reduce cache retention
Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
    cacheRetentionHours = 168  # 1 week instead of 30 days
}

# Manual cleanup
$manager = New-LyricsManager
$manager.CleanupCache(168)
```

#### Statistics Issues

**Problem**: No statistics data available

```powershell
# Enable statistics tracking
Set-SpotifyLiveFeaturesConfiguration -Section "statistics" -Settings @{
    trackingEnabled = $true
}

# Check data directory permissions
$engine = New-StatisticsEngine
$stats = $engine.GetStorageInfo()
$stats

# Verify data is being collected
$engine.RecordPlayback(@{
    id = "test"
    name = "Test Track"
    artists = @(@{ name = "Test Artist" })
    album = @{ name = "Test Album" }
    duration_ms = 180000
})
```

**Problem**: Statistics export failing

```powershell
# Check available disk space
Get-PSDrive C

# Try different export location
$engine = New-StatisticsEngine
$export = $engine.ExportData("json", "month")
Set-Content -Path "C:\temp\stats.json" -Value $export.Data
```

### Performance Issues

**Problem**: High CPU usage during live mode

```powershell
# Enable performance mode
Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
    performanceMode = $true
    refreshInterval = 2000  # Reduce update frequency
}

# Check background processing
$status = Get-SpotifyLiveFeaturesStatus
$status.BackgroundProcessingStats
```

**Problem**: Memory usage growing over time

```powershell
# Configure memory limits
Set-SpotifyLiveFeaturesConfiguration -Section "backgroundProcessing" -Settings @{
    memoryThresholdMB = 100  # Lower threshold
}

# Restart live features periodically
Stop-SpotifyLiveFeatures
Initialize-SpotifyLiveFeatures
```

### Diagnostic Commands

```powershell
# Comprehensive system check
Get-SpotifyLiveFeaturesStatus | Format-List

# Test all display capabilities
Test-DisplayCapabilities | Format-List

# Check lyrics providers
Test-LyricsProviders | Format-Table

# Verify statistics engine
$engine = New-StatisticsEngine
$engine.GetStorageInfo() | Format-List
```

## Performance Optimization

### Recommended Settings

For optimal performance, use these configuration settings:

```powershell
# Performance-optimized configuration
Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
    refreshInterval = 1500      # Balance between responsiveness and CPU usage
    performanceMode = $true     # Enable optimizations
    displayMode = "compact"     # Reduce rendering complexity
}

Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
    cacheEnabled = $true        # Reduce API calls
    cacheRetentionHours = 168   # 1 week retention
}

Set-SpotifyLiveFeaturesConfiguration -Section "statistics" -Settings @{
    retentionDays = 180         # 6 months instead of 1 year
}

Set-SpotifyLiveFeaturesConfiguration -Section "apiClient" -Settings @{
    cacheEnabled = $true        # Enable API response caching
    cacheTtlMs = 30000         # 30 second cache
}
```

### Memory Management

```powershell
# Configure background processing for memory efficiency
Set-SpotifyLiveFeaturesConfiguration -Section "backgroundProcessing" -Settings @{
    batchSize = 5              # Smaller batches
    batchIntervalMs = 3000     # Longer intervals
    memoryThresholdMB = 75     # Lower memory threshold
}
```

### Monitoring Performance

```powershell
# Create performance monitoring script
$monitorScript = {
    while ($true) {
        $status = Get-SpotifyLiveFeaturesStatus
        $memory = [System.GC]::GetTotalMemory($false) / 1MB

        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Memory: $([Math]::Round($memory, 2))MB" -ForegroundColor Green

        if ($status.BackgroundProcessingStats) {
            Write-Host "Background Queue: $($status.BackgroundProcessingStats.QueueSize)" -ForegroundColor Cyan
        }

        Start-Sleep -Seconds 30
    }
}

# Run monitoring in background
Start-Job -ScriptBlock $monitorScript -Name "SpotifyLiveFeaturesMonitor"
```

## API Reference

### Core Functions

#### Initialize-SpotifyLiveFeatures

Initializes all live feature components.

```powershell
Initialize-SpotifyLiveFeatures
```

#### Start-SpotifyLiveDisplay

Starts the live display mode.

```powershell
Start-SpotifyLiveDisplay [-Mode <string>]
```

**Parameters:**

- `Mode`: Display mode (detailed, compact, minimal)

#### Get-SpotifyCurrentTrackLyrics

Gets lyrics for the currently playing track.

```powershell
Get-SpotifyCurrentTrackLyrics
```

**Returns:** Hashtable with lyrics data

#### Get-SpotifyLyrics

Gets lyrics for a specific track.

```powershell
Get-SpotifyLyrics -Artist <string> -Track <string>
```

**Parameters:**

- `Artist`: Artist name
- `Track`: Track name

#### Get-SpotifyListeningStatistics

Generates listening statistics report.

```powershell
Get-SpotifyListeningStatistics [-Period <string>]
```

**Parameters:**

- `Period`: Time period (day, week, month, year)

#### Get-SpotifyLiveFeaturesStatus

Gets status of all live features.

```powershell
Get-SpotifyLiveFeaturesStatus
```

**Returns:** Hashtable with detailed status information

#### Set-SpotifyLiveFeaturesConfiguration

Updates configuration settings.

```powershell
Set-SpotifyLiveFeaturesConfiguration -Section <string> -Settings <hashtable>
```

**Parameters:**

- `Section`: Configuration section (liveDisplay, lyrics, statistics, apiClient)
- `Settings`: Hashtable of settings to update

#### Stop-SpotifyLiveFeatures

Stops and cleans up live features.

```powershell
Stop-SpotifyLiveFeatures
```

### Factory Functions

#### New-LiveDisplayEngine

Creates a display engine instance.

```powershell
New-LiveDisplayEngine -Type <string> [-Configuration <hashtable>]
```

#### New-LyricsManager

Creates a lyrics manager instance.

```powershell
New-LyricsManager [-Configuration <hashtable>]
```

#### New-StatisticsEngine

Creates a statistics engine instance.

```powershell
New-StatisticsEngine [-Configuration <hashtable>]
```

### Utility Functions

#### Test-DisplayCapabilities

Tests display system capabilities.

```powershell
Test-DisplayCapabilities
```

#### Test-LyricsProviders

Tests lyrics provider availability.

```powershell
Test-LyricsProviders [-Configuration <hashtable>]
```

#### Show-Lyrics

Displays lyrics in interactive viewer.

```powershell
Show-Lyrics -LyricsData <hashtable> [-InitialPositionMs <int>]
```

#### Format-LyricsDisplay

Formats lyrics for display.

```powershell
Format-LyricsDisplay -LyricsData <hashtable> [-CurrentPositionMs <int>] [-DisplayHeight <int>] [-ShowTimestamps <bool>]
```

---

## Conclusion

The Spotify CLI Live Features provide a comprehensive, high-performance solution for real-time music monitoring, lyrics display, and listening analytics. With proper configuration and understanding of the available options, you can create a personalized music experience that enhances your productivity and enjoyment.

For additional support or feature requests, refer to the troubleshooting section or check the project documentation.
