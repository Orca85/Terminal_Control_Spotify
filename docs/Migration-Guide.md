# Spotify CLI Live Features - Migration Guide

## Overview

This guide helps existing Spotify CLI users migrate to the new Live Features version (v3.0.0). The migration process preserves your existing configuration while adding powerful new capabilities.

## What's New in v3.0.0

### Major New Features

1. **Live Display Engine**

   - Real-time track information display
   - Animated progress bars
   - Windows Terminal sidecar mode
   - Multiple display modes (detailed, compact, minimal)

2. **Lyrics Engine**

   - Synchronized lyrics display
   - Multiple provider support (Genius, Musixmatch)
   - Interactive lyrics viewer
   - Local caching system

3. **Statistics Engine**

   - Comprehensive listening analytics
   - ASCII visualizations
   - Data export capabilities
   - Historical tracking

4. **Enhanced Configuration System**
   - Hierarchical JSON configuration
   - Runtime configuration updates
   - Performance optimization settings

### Compatibility

- **Backward Compatible**: All existing commands continue to work
- **New Commands**: 9 new live features commands added
- **Enhanced Performance**: Improved API handling and caching
- **Cross-Platform Ready**: Better support for PowerShell 7+

## Migration Process

### Step 1: Backup Your Current Setup

Before migrating, create a backup of your current configuration:

```powershell
# Create backup directory
$backupDir = "$env:USERPROFILE\SpotifyCLI-Backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $backupDir -Force

# Backup current module (if installed globally)
$currentModule = Get-Module -ListAvailable -Name SpotifyCommands
if ($currentModule) {
    Copy-Item $currentModule.ModuleBase -Destination "$backupDir\OldModule" -Recurse -Force
    Write-Host "✅ Current module backed up to: $backupDir\OldModule" -ForegroundColor Green
}

# Backup PowerShell profile
if (Test-Path $PROFILE.CurrentUserAllHosts) {
    Copy-Item $PROFILE.CurrentUserAllHosts -Destination "$backupDir\Profile.ps1" -Force
    Write-Host "✅ PowerShell profile backed up" -ForegroundColor Green
}

# Backup environment variables
$envVars = @{
    SPOTIFY_CLIENT_ID = $env:SPOTIFY_CLIENT_ID
    SPOTIFY_CLIENT_SECRET = $env:SPOTIFY_CLIENT_SECRET
}
$envVars | ConvertTo-Json | Set-Content "$backupDir\EnvironmentVariables.json"
Write-Host "✅ Environment variables backed up" -ForegroundColor Green

Write-Host "📁 Backup completed in: $backupDir" -ForegroundColor Cyan
```

### Step 2: Choose Migration Method

#### Option A: Automatic Migration (Recommended)

Use the new installation script with automatic migration:

```powershell
# Download and run the new installer
.\Install-SpotifyCLI-LiveFeatures.ps1 -Force
```

This will:

- Preserve your existing API credentials
- Update the module to v3.0.0
- Install live features components
- Update your PowerShell profile
- Maintain backward compatibility

#### Option B: Manual Migration

For users who prefer manual control:

1. **Remove old module (optional):**

   ```powershell
   # Find current module location
   $oldModule = Get-Module -ListAvailable -Name SpotifyCommands
   if ($oldModule) {
       Remove-Item $oldModule.ModuleBase -Recurse -Force
       Write-Host "Old module removed" -ForegroundColor Yellow
   }
   ```

2. **Install new version:**

   ```powershell
   # Run installation without forcing
   .\Install-SpotifyCLI-LiveFeatures.ps1
   ```

3. **Verify migration:**

   ```powershell
   # Restart PowerShell
   # Test existing functionality
   playlists

   # Test new features
   Initialize-SpotifyLiveFeatures
   Get-SpotifyLiveFeaturesStatus
   ```

### Step 3: Verify Migration

After migration, verify everything is working correctly:

```powershell
# Test existing commands
Write-Host "Testing existing functionality..." -ForegroundColor Yellow
try {
    $playlists = playlists
    Write-Host "✅ Playlists command working" -ForegroundColor Green
} catch {
    Write-Host "❌ Playlists command failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    $currentTrack = plays-now
    Write-Host "✅ Current track command working" -ForegroundColor Green
} catch {
    Write-Host "❌ Current track command failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test new live features
Write-Host "Testing live features..." -ForegroundColor Yellow
try {
    Initialize-SpotifyLiveFeatures
    $status = Get-SpotifyLiveFeaturesStatus
    Write-Host "✅ Live features initialized successfully" -ForegroundColor Green

    # Show feature status
    foreach ($feature in $status.Features.Keys) {
        $icon = if ($status.Features[$feature]) { "✅" } else { "❌" }
        Write-Host "$icon $feature" -ForegroundColor White
    }
} catch {
    Write-Host "❌ Live features initialization failed: $($_.Exception.Message)" -ForegroundColor Red
}
```

## Configuration Migration

### Existing Configuration Preservation

Your existing configuration is automatically preserved:

- **API Credentials**: Environment variables remain unchanged
- **PowerShell Profile**: Existing customizations are preserved
- **Aliases**: All existing aliases continue to work

### New Configuration Options

The live features add new configuration sections:

```powershell
# View new configuration structure
$status = Get-SpotifyLiveFeaturesStatus
$status.Configuration

# Configure live display
Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
    refreshInterval = 1500
    displayMode = "detailed"
    performanceMode = $true
}

# Configure lyrics
Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
    cacheEnabled = $true
    preferredProvider = "genius"
}

# Configure statistics
Set-SpotifyLiveFeaturesConfiguration -Section "statistics" -Settings @{
    trackingEnabled = $true
    retentionDays = 365
}
```

## Feature-by-Feature Migration

### Live Display

**No migration needed** - This is a completely new feature.

**Getting Started:**

```powershell
# Initialize live features
Initialize-SpotifyLiveFeatures

# Start live display
Start-SpotifyLiveDisplay -Mode detailed

# Try sidecar mode (Windows Terminal)
spotify --sidecar
```

### Lyrics Engine

**No migration needed** - This is a completely new feature.

**Getting Started:**

```powershell
# Get lyrics for current track
Get-SpotifyCurrentTrackLyrics

# Interactive lyrics viewer
$lyrics = Get-SpotifyCurrentTrackLyrics
if ($lyrics.Success) {
    Show-Lyrics $lyrics
}
```

### Statistics Engine

**No migration needed** - This is a completely new feature.

**Getting Started:**

```powershell
# Enable statistics tracking
Set-SpotifyLiveFeaturesConfiguration -Section "statistics" -Settings @{
    trackingEnabled = $true
}

# Generate statistics (after some listening)
Get-SpotifyListeningStatistics -Period week
```

## Troubleshooting Migration Issues

### Common Issues and Solutions

#### Issue: "Module not found" after migration

**Solution:**

```powershell
# Restart PowerShell completely
# Or reload profile
. $PROFILE

# If still not working, check module path
Get-Module -ListAvailable -Name SpotifyCommands
```

#### Issue: Live features not initializing

**Solution:**

```powershell
# Check PowerShell version (7+ recommended)
$PSVersionTable.PSVersion

# Reinstall with force
.\Install-SpotifyCLI-LiveFeatures.ps1 -Force

# Check for missing dependencies
Get-Module -ListAvailable | Where-Object Name -like "*Spotify*"
```

#### Issue: API credentials not working

**Solution:**

```powershell
# Check environment variables
$env:SPOTIFY_CLIENT_ID
$env:SPOTIFY_CLIENT_SECRET

# Re-authenticate if needed
.\spotifyCLI.ps1

# Or reconfigure during installation
.\Install-SpotifyCLI-LiveFeatures.ps1 -ConfigureApiKeys
```

#### Issue: Performance problems with live features

**Solution:**

```powershell
# Enable performance mode
Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
    performanceMode = $true
    refreshInterval = 2000
    enableAnimations = $false
}

# Check system resources
$memory = [System.GC]::GetTotalMemory($false) / 1MB
Write-Host "Memory usage: $([Math]::Round($memory, 2))MB"
```

### Getting Help

If you encounter issues during migration:

1. **Check the troubleshooting guide**: `docs/Troubleshooting-Guide.md`
2. **Run diagnostic commands**:
   ```powershell
   Get-SpotifyLiveFeaturesStatus
   Test-DisplayCapabilities
   Test-LyricsProviders
   ```
3. **Reset to defaults if needed**:
   ```powershell
   Reset-SpotifyLiveFeaturesConfiguration
   ```

## Rollback Procedure

If you need to rollback to the previous version:

### Step 1: Stop Live Features

```powershell
# Stop any running live features
Stop-SpotifyLiveFeatures
```

### Step 2: Restore from Backup

```powershell
# Restore old module (replace with your backup path)
$backupDir = "C:\Path\To\Your\Backup"
$moduleDir = Join-Path (Split-Path $PROFILE -Parent) "Modules\SpotifyCommands"

# Remove new module
Remove-Item $moduleDir -Recurse -Force

# Restore old module
Copy-Item "$backupDir\OldModule" -Destination $moduleDir -Recurse -Force

# Restore profile
Copy-Item "$backupDir\Profile.ps1" -Destination $PROFILE.CurrentUserAllHosts -Force
```

### Step 3: Restart PowerShell

```powershell
# Restart PowerShell and test
playlists
```

## Post-Migration Optimization

### Performance Tuning

After migration, optimize for your system:

```powershell
# For high-performance systems
Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
    refreshInterval = 1000
    displayMode = "detailed"
    enableAnimations = $true
    performanceMode = $false
}

# For resource-constrained systems
Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
    refreshInterval = 3000
    displayMode = "compact"
    enableAnimations = $false
    performanceMode = $true
}
```

### Feature Configuration

Configure features based on your usage:

```powershell
# For lyrics enthusiasts
Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
    syncHighlighting = $true
    autoScroll = $true
    showTimestamps = $true
    cacheRetentionHours = 720  # 30 days
}

# For data analysts
Set-SpotifyLiveFeaturesConfiguration -Section "statistics" -Settings @{
    trackingEnabled = $true
    enableAnalytics = $true
    enableVisualization = $true
    retentionDays = 365
    backgroundCollection = $true
}
```

## What to Expect

### Immediate Benefits

After migration, you'll have access to:

- **Real-time music monitoring** without manual commands
- **Synchronized lyrics** for your favorite songs
- **Listening analytics** to understand your music habits
- **Enhanced performance** with improved caching
- **Better error handling** and diagnostics

### Learning Curve

- **Existing users**: No learning curve for existing functionality
- **New features**: 5-10 minutes to explore live features
- **Advanced features**: 30 minutes to master configuration options

### Resource Usage

- **Memory**: Additional 10-20MB for live features
- **CPU**: Minimal impact with performance mode enabled
- **Disk**: 50-100MB for caches and statistics data
- **Network**: Reduced API calls due to improved caching

## Migration Checklist

Use this checklist to ensure a successful migration:

- [ ] **Backup created** - Current setup backed up
- [ ] **Installation completed** - New version installed successfully
- [ ] **Basic functionality tested** - Existing commands work
- [ ] **Live features initialized** - `Initialize-SpotifyLiveFeatures` successful
- [ ] **API credentials verified** - Authentication working
- [ ] **Performance acceptable** - No significant slowdown
- [ ] **Configuration customized** - Settings adjusted for preferences
- [ ] **Documentation reviewed** - Familiar with new features

## Next Steps

After successful migration:

1. **Explore the Complete User Guide**: `docs/Live-Features-Complete-User-Guide.md`
2. **Try example scenarios**: `docs/Example-Scenarios.md`
3. **Customize configuration**: `docs/Configuration-Reference.md`
4. **Set up your preferred workflow** using the new features

Welcome to the enhanced Spotify CLI experience with Live Features!
