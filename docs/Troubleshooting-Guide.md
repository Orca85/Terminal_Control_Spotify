# Spotify CLI Live Features - Troubleshooting Guide

## Overview

This guide provides comprehensive troubleshooting information for the Spotify CLI Live Features system. It covers common issues, diagnostic procedures, and solutions for all major components.

## Quick Diagnostic Commands

Before diving into specific issues, run these commands to get an overview of system status:

```powershell
# Check overall system status
Get-SpotifyLiveFeaturesStatus

# Test display capabilities
Test-DisplayCapabilities

# Check lyrics providers
Test-LyricsProviders

# Verify basic Spotify connection
plays-now
```

## Live Display Issues

### Issue: Live Display Not Starting

**Symptoms:**

- Error when running `Start-SpotifyLiveDisplay`
- "Engine not initialized" messages
- Blank or frozen display

**Diagnostic Steps:**

```powershell
# Check if live features are initialized
$status = Get-SpotifyLiveFeaturesStatus
$status.IsInitialized

# Check feature availability
$status.Features.LiveDisplay

# Test display capabilities
Test-DisplayCapabilities
```

**Solutions:**

1. **Initialize the system first:**

   ```powershell
   Initialize-SpotifyLiveFeatures
   Start-SpotifyLiveDisplay
   ```

2. **Check terminal compatibility:**

   ```powershell
   # Verify ANSI support
   $caps = Test-DisplayCapabilities
   $caps.Console.Info.AnsiSupported
   ```

3. **Reset configuration:**
   ```powershell
   Reset-SpotifyLiveFeaturesConfiguration
   Initialize-SpotifyLiveFeatures
   ```

### Issue: Display Flickering or Performance Problems

**Symptoms:**

- Screen flickers constantly
- High CPU usage
- Slow response times

**Solutions:**

1. **Increase refresh interval:**

   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
       refreshInterval = 2000  # 2 seconds instead of 1
   }
   ```

2. **Enable performance mode:**

   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
       performanceMode = $true
       enableAnimations = $false
       displayMode = "compact"
   }
   ```

3. **Check background processing:**
   ```powershell
   $status = Get-SpotifyLiveFeaturesStatus
   $status.BackgroundProcessingStats
   ```

### Issue: Sidecar Mode Not Working

**Symptoms:**

- "Windows Terminal not detected" error
- Sidecar pane not created
- Commands not working in Windows Terminal

**Diagnostic Steps:**

```powershell
# Check Windows Terminal detection
$caps = Test-DisplayCapabilities
$caps.WindowsTerminal

# Check environment variables
$env:WT_SESSION
$env:WT_PROFILE_ID
```

**Solutions:**

1. **Ensure Windows Terminal is running:**

   - Launch Windows Terminal (not PowerShell directly)
   - Run commands from within Windows Terminal

2. **Check Windows Terminal version:**

   ```powershell
   wt --version
   ```

3. **Manual sidecar creation:**
   ```powershell
   # Try creating sidecar with different settings
   spotify --sidecar --position left --width 30
   ```

### Issue: Display Shows "No Track Information"

**Symptoms:**

- Live display shows no track data
- "No active playback" messages
- Display updates but shows empty information

**Diagnostic Steps:**

```powershell
# Check Spotify connection
plays-now

# Check API client status
$status = Get-SpotifyLiveFeaturesStatus
$status.Features.ApiClient
$status.ApiClientStats

# Test direct API call
$manager = [SpotifyLiveFeaturesManager]::new()
$track = $manager.GetCurrentTrack()
$track
```

**Solutions:**

1. **Verify Spotify is playing:**

   - Start music in Spotify app
   - Ensure Spotify Premium account
   - Check device is active

2. **Check API authentication:**

   ```powershell
   # Re-authenticate if needed
   .\spotifyCLI.ps1
   ```

3. **Restart live features:**
   ```powershell
   Stop-SpotifyLiveFeatures
   Initialize-SpotifyLiveFeatures
   ```

## Lyrics Engine Issues

### Issue: No Lyrics Found

**Symptoms:**

- "No lyrics found" messages
- Empty lyrics display
- Provider errors

**Diagnostic Steps:**

```powershell
# Check provider availability
Test-LyricsProviders

# Check current track
$track = plays-now
Write-Host "Track: $($track.name) by $($track.artists[0].name)"

# Test manual lyrics search
Get-SpotifyLyrics -Artist "Queen" -Track "Bohemian Rhapsody"
```

**Solutions:**

1. **Verify internet connection:**

   ```powershell
   Test-NetConnection -ComputerName "api.genius.com" -Port 443
   Test-NetConnection -ComputerName "api.musixmatch.com" -Port 443
   ```

2. **Check API keys (if using):**

   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
       providers = @{
           genius = @{
               enabled = $true
               apiKey = "your-genius-api-key"
           }
       }
   }
   ```

3. **Try different provider:**

   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
       preferredProvider = "musixmatch"
   }
   ```

4. **Enable mock provider for testing:**
   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
       enableMockProvider = $true
   }
   ```

### Issue: Synchronized Lyrics Not Working

**Symptoms:**

- Lyrics display but no highlighting
- Highlighting out of sync
- No current line indication

**Solutions:**

1. **Enable sync highlighting:**

   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
       syncHighlighting = $true
       autoScroll = $true
   }
   ```

2. **Check if track has synced lyrics:**

   ```powershell
   $lyrics = Get-SpotifyCurrentTrackLyrics
   $lyrics.HasSyncedLyrics
   $lyrics.SyncedLines.Count
   ```

3. **Clear lyrics cache:**
   ```powershell
   $manager = New-LyricsManager
   $manager.ClearCache()
   ```

### Issue: Lyrics Cache Problems

**Symptoms:**

- Slow lyrics loading
- Disk space issues
- Cache errors

**Diagnostic Steps:**

```powershell
# Check cache statistics
$status = Get-SpotifyLiveFeaturesStatus
$status.LyricsCacheStats

# Check cache directory
$cacheDir = "$env:APPDATA\SpotifyCLI\Lyrics"
Get-ChildItem $cacheDir | Measure-Object -Property Length -Sum
```

**Solutions:**

1. **Adjust cache settings:**

   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
       cacheRetentionHours = 168  # 1 week instead of 30 days
       maxCacheSizeMB = 25        # Reduce from 50MB
   }
   ```

2. **Manual cache cleanup:**

   ```powershell
   $manager = New-LyricsManager
   $manager.CleanupCache(168)  # Clean entries older than 1 week
   ```

3. **Clear entire cache:**
   ```powershell
   $manager = New-LyricsManager
   $manager.ClearCache()
   ```

## Statistics Engine Issues

### Issue: No Statistics Data

**Symptoms:**

- "No data available" in statistics
- Empty reports
- Zero play counts

**Diagnostic Steps:**

```powershell
# Check if tracking is enabled
$status = Get-SpotifyLiveFeaturesStatus
$status.Features.Statistics

# Check storage info
$engine = New-StatisticsEngine
$storage = $engine.GetStorageInfo()
$storage

# Check data directory
$dataDir = "$env:APPDATA\SpotifyCLI\Statistics"
Test-Path $dataDir
Get-ChildItem $dataDir
```

**Solutions:**

1. **Enable statistics tracking:**

   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "statistics" -Settings @{
       trackingEnabled = $true
   }
   ```

2. **Manually record some data:**

   ```powershell
   $engine = New-StatisticsEngine

   # Get current track and record it
   $track = plays-now
   if ($track) {
       $engine.RecordPlayback($track)
   }
   ```

3. **Check data directory permissions:**
   ```powershell
   $dataDir = "$env:APPDATA\SpotifyCLI\Statistics"
   $acl = Get-Acl $dataDir
   $acl.Access | Where-Object { $_.IdentityReference -eq [System.Security.Principal.WindowsIdentity]::GetCurrent().Name }
   ```

### Issue: Statistics Export Failing

**Symptoms:**

- Export commands return errors
- Files not created
- Permission denied errors

**Solutions:**

1. **Try different export location:**

   ```powershell
   $engine = New-StatisticsEngine
   $export = $engine.ExportData("json", "month")

   # Save to different location
   Set-Content -Path "C:\temp\stats.json" -Value $export.Data
   ```

2. **Check available disk space:**

   ```powershell
   Get-PSDrive C | Select-Object Used, Free
   ```

3. **Export raw data instead:**
   ```powershell
   $engine = New-StatisticsEngine
   $startDate = (Get-Date).AddDays(-30)
   $endDate = Get-Date
   $rawExport = $engine.ExportRawData($startDate, $endDate, "csv")
   Set-Content -Path "raw-data.csv" -Value $rawExport.Data
   ```

### Issue: Database Corruption

**Symptoms:**

- JSON parsing errors
- "Failed to load events" messages
- Inconsistent data

**Solutions:**

1. **Create backup first:**

   ```powershell
   $engine = New-StatisticsEngine
   $backup = $engine.BackupData("C:\Backups\Spotify")
   ```

2. **Validate JSON manually:**

   ```powershell
   $dbFile = "$env:APPDATA\SpotifyCLI\Statistics\playback_history.json"
   try {
       $json = Get-Content $dbFile -Raw
       $data = $json | ConvertFrom-Json
       Write-Host "Database is valid with $($data.Count) events"
   } catch {
       Write-Host "Database is corrupted: $($_.Exception.Message)"
   }
   ```

3. **Restore from backup:**

   ```powershell
   $engine = New-StatisticsEngine
   $restore = $engine.RestoreData("C:\Backups\Spotify\spotify_backup_20241106_143022.json")
   ```

4. **Clear and restart:**
   ```powershell
   $engine = New-StatisticsEngine
   $engine.ClearData()
   # Statistics will start collecting fresh data
   ```

## API Client Issues

### Issue: Rate Limiting Errors

**Symptoms:**

- "Rate limit exceeded" messages
- Slow API responses
- Temporary failures

**Solutions:**

1. **Adjust rate limiting:**

   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "apiClient" -Settings @{
       rateLimitPerSecond = 0.5  # Slower rate
       retryAttempts = 5
       exponentialBackoff = $true
   }
   ```

2. **Enable caching:**
   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "apiClient" -Settings @{
       cacheEnabled = $true
       cacheTtlMs = 60000  # 1 minute cache
   }
   ```

### Issue: Authentication Problems

**Symptoms:**

- "Unauthorized" errors
- Token expired messages
- Authentication required prompts

**Solutions:**

1. **Re-authenticate:**

   ```powershell
   # Run main CLI script to refresh tokens
   .\spotifyCLI.ps1
   ```

2. **Check environment variables:**

   ```powershell
   $env:SPOTIFY_CLIENT_ID
   $env:SPOTIFY_CLIENT_SECRET
   ```

3. **Verify .env file:**
   ```powershell
   Get-Content .env
   ```

### Issue: Network Connectivity

**Symptoms:**

- "Network unreachable" errors
- Timeout errors
- DNS resolution failures

**Solutions:**

1. **Test connectivity:**

   ```powershell
   Test-NetConnection -ComputerName "api.spotify.com" -Port 443
   ```

2. **Adjust timeout settings:**

   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "apiClient" -Settings @{
       timeoutMs = 15000  # Increase to 15 seconds
   }
   ```

3. **Check proxy settings:**
   ```powershell
   # If behind corporate proxy
   [System.Net.WebRequest]::DefaultWebProxy
   ```

## Background Processing Issues

### Issue: High Memory Usage

**Symptoms:**

- PowerShell process using excessive memory
- System slowdown
- Out of memory errors

**Diagnostic Steps:**

```powershell
# Check memory usage
$process = Get-Process -Name "pwsh" | Sort-Object WorkingSet -Descending | Select-Object -First 1
$memoryMB = [Math]::Round($process.WorkingSet / 1MB, 2)
Write-Host "PowerShell memory usage: $memoryMB MB"

# Check background processing stats
$status = Get-SpotifyLiveFeaturesStatus
$status.BackgroundProcessingStats
```

**Solutions:**

1. **Reduce memory threshold:**

   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "backgroundProcessing" -Settings @{
       memoryThresholdMB = 100  # Lower threshold
       batchSize = 5            # Smaller batches
   }
   ```

2. **Restart live features periodically:**
   ```powershell
   # Create scheduled restart
   Stop-SpotifyLiveFeatures
   Start-Sleep -Seconds 2
   Initialize-SpotifyLiveFeatures
   ```

### Issue: Background Processing Stopped

**Symptoms:**

- Statistics not updating
- Live display frozen
- Background queue not processing

**Solutions:**

1. **Check background processing status:**

   ```powershell
   $status = Get-SpotifyLiveFeaturesStatus
   $status.Features.BackgroundProcessing
   ```

2. **Restart background processing:**

   ```powershell
   Stop-SpotifyLiveFeatures
   Initialize-SpotifyLiveFeatures
   ```

3. **Disable background processing temporarily:**
   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "backgroundProcessing" -Settings @{
       enabled = $false
   }
   ```

## General System Issues

### Issue: Module Import Errors

**Symptoms:**

- "Module not found" errors
- Class definition errors
- Function not recognized

**Solutions:**

1. **Check module paths:**

   ```powershell
   $env:PSModulePath -split ';'
   ```

2. **Import modules manually:**

   ```powershell
   Import-Module .\modules\SpotifyLiveFeatures.psm1 -Force
   ```

3. **Check PowerShell version:**
   ```powershell
   $PSVersionTable.PSVersion
   # Requires PowerShell 5.1+ or PowerShell 7+
   ```

### Issue: Configuration File Corruption

**Symptoms:**

- JSON parsing errors
- Settings not persisting
- Default values always used

**Solutions:**

1. **Validate configuration file:**

   ```powershell
   $configFile = "$env:APPDATA\SpotifyCLI\LiveFeatures\config.json"
   try {
       $config = Get-Content $configFile | ConvertFrom-Json
       Write-Host "Configuration is valid"
   } catch {
       Write-Host "Configuration is corrupted: $($_.Exception.Message)"
   }
   ```

2. **Reset configuration:**

   ```powershell
   Reset-SpotifyLiveFeaturesConfiguration
   ```

3. **Manual configuration recreation:**

   ```powershell
   $configDir = "$env:APPDATA\SpotifyCLI\LiveFeatures"
   if (-not (Test-Path $configDir)) {
       New-Item -ItemType Directory -Path $configDir -Force
   }

   # Create minimal config
   $config = @{
       liveDisplay = @{
           refreshInterval = 1000
           displayMode = "detailed"
       }
       lyrics = @{
           cacheEnabled = $true
       }
       statistics = @{
           trackingEnabled = $true
       }
   }

   $config | ConvertTo-Json -Depth 10 | Set-Content "$configDir\config.json"
   ```

## Performance Optimization

### Memory Optimization

```powershell
# Optimize for low memory usage
Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
    refreshInterval = 2000
    performanceMode = $true
    enableAnimations = $false
}

Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
    maxCacheSizeMB = 25
    cacheRetentionHours = 168
}

Set-SpotifyLiveFeaturesConfiguration -Section "statistics" -Settings @{
    batchSize = 5
    compressionEnabled = $true
}

Set-SpotifyLiveFeaturesConfiguration -Section "backgroundProcessing" -Settings @{
    memoryThresholdMB = 75
    batchIntervalMs = 3000
}
```

### CPU Optimization

```powershell
# Optimize for low CPU usage
Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
    refreshInterval = 3000
    displayMode = "minimal"
    targetFPS = 15
}

Set-SpotifyLiveFeaturesConfiguration -Section "backgroundProcessing" -Settings @{
    cpuThresholdPercent = 60
    workerThreads = 1
}
```

## Diagnostic Scripts

### Complete System Check

```powershell
function Test-SpotifyLiveFeaturesHealth {
    Write-Host "=== Spotify Live Features Health Check ===" -ForegroundColor Cyan

    # Check initialization
    try {
        $status = Get-SpotifyLiveFeaturesStatus
        Write-Host "✓ Live Features Status: $($status.IsInitialized)" -ForegroundColor Green
    } catch {
        Write-Host "✗ Live Features Not Initialized" -ForegroundColor Red
        return
    }

    # Check features
    foreach ($feature in $status.Features.Keys) {
        $icon = if ($status.Features[$feature]) { "✓" } else { "✗" }
        $color = if ($status.Features[$feature]) { "Green" } else { "Red" }
        Write-Host "$icon $feature`: $($status.Features[$feature])" -ForegroundColor $color
    }

    # Check Spotify connection
    try {
        $track = plays-now
        if ($track) {
            Write-Host "✓ Spotify Connection: Active" -ForegroundColor Green
            Write-Host "  Current Track: $($track.name) by $($track.artists[0].name)" -ForegroundColor Gray
        } else {
            Write-Host "⚠ Spotify Connection: No active playback" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "✗ Spotify Connection: Failed" -ForegroundColor Red
    }

    # Check display capabilities
    try {
        $caps = Test-DisplayCapabilities
        Write-Host "✓ Console Display: $($caps.Console.Supported)" -ForegroundColor Green
        Write-Host "✓ Windows Terminal: $($caps.Sidecar.Supported)" -ForegroundColor Green
    } catch {
        Write-Host "✗ Display Capabilities: Failed to test" -ForegroundColor Red
    }

    # Check providers
    try {
        $providers = Test-LyricsProviders
        $availableCount = ($providers | Where-Object { $_.Available }).Count
        Write-Host "✓ Lyrics Providers: $availableCount available" -ForegroundColor Green
    } catch {
        Write-Host "✗ Lyrics Providers: Failed to test" -ForegroundColor Red
    }

    Write-Host "=== Health Check Complete ===" -ForegroundColor Cyan
}

# Run the health check
Test-SpotifyLiveFeaturesHealth
```

### Performance Monitor

```powershell
function Start-SpotifyLiveFeaturesMonitor {
    param([int]$DurationMinutes = 5)

    $endTime = (Get-Date).AddMinutes($DurationMinutes)

    Write-Host "Starting $DurationMinutes minute performance monitor..." -ForegroundColor Cyan

    while ((Get-Date) -lt $endTime) {
        $memory = [System.GC]::GetTotalMemory($false) / 1MB
        $process = Get-Process -Name "pwsh" | Sort-Object WorkingSet -Descending | Select-Object -First 1
        $processMemory = $process.WorkingSet / 1MB

        try {
            $status = Get-SpotifyLiveFeaturesStatus
            $timestamp = Get-Date -Format "HH:mm:ss"

            Write-Host "[$timestamp] Memory: $([Math]::Round($memory, 1))MB | Process: $([Math]::Round($processMemory, 1))MB" -ForegroundColor Green

            if ($status.BackgroundProcessingStats) {
                Write-Host "  Background Queue: $($status.BackgroundProcessingStats.QueueSize)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "[$timestamp] Error getting status: $($_.Exception.Message)" -ForegroundColor Red
        }

        Start-Sleep -Seconds 30
    }

    Write-Host "Performance monitoring complete." -ForegroundColor Cyan
}

# Start monitoring
# Start-SpotifyLiveFeaturesMonitor -DurationMinutes 10
```

## Getting Help

If you continue to experience issues after following this troubleshooting guide:

1. **Run the health check script** to get a complete system overview
2. **Check the logs** in `$env:APPDATA\SpotifyCLI\Logs` (if logging is enabled)
3. **Gather diagnostic information** using the provided scripts
4. **Reset to defaults** and test with minimal configuration
5. **Check for updates** to the Spotify CLI system

### Emergency Reset

If all else fails, perform a complete reset:

```powershell
# Stop all live features
Stop-SpotifyLiveFeatures

# Clear all configuration and data
$liveDir = "$env:APPDATA\SpotifyCLI\LiveFeatures"
if (Test-Path $liveDir) {
    Remove-Item -Path $liveDir -Recurse -Force
}

# Reinitialize with defaults
Initialize-SpotifyLiveFeatures

# Test basic functionality
Get-SpotifyLiveFeaturesStatus
```

This will restore the system to a clean state with default settings.
