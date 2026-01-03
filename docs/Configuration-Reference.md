# Spotify CLI Live Features - Configuration Reference

## Overview

This document provides a comprehensive reference for all configuration options available in the Spotify CLI Live Features system. The configuration system uses a hierarchical JSON structure with four main sections: Live Display, Lyrics, Statistics, and API Client.

## Configuration File Location

The configuration file is automatically created and managed by the system:

- **Windows**: `%APPDATA%\SpotifyCLI\LiveFeatures\config.json`
- **macOS**: `~/Library/Application Support/SpotifyCLI/LiveFeatures/config.json`
- **Linux**: `~/.config/SpotifyCLI/LiveFeatures/config.json`

## Configuration Structure

```json
{
  "liveDisplay": {
    /* Live Display Settings */
  },
  "lyrics": {
    /* Lyrics Engine Settings */
  },
  "statistics": {
    /* Statistics Engine Settings */
  },
  "apiClient": {
    /* API Client Settings */
  },
  "backgroundProcessing": {
    /* Background Processing Settings */
  }
}
```

## Live Display Configuration

### Section: `liveDisplay`

Controls the behavior and appearance of the live display engine.

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
    "performanceMode": true,
    "targetFPS": 30,
    "enableAnimations": true,
    "compactThreshold": 80,
    "autoHideSidecar": false,
    "showTimestamp": false,
    "showControls": true,
    "colors": {
      "playing": "Green",
      "paused": "Yellow",
      "track": "Cyan",
      "artist": "White",
      "album": "Gray",
      "progress": "Blue",
      "background": "Black"
    }
  }
}
```

#### Configuration Options

| Option             | Type    | Default    | Description                                                       |
| ------------------ | ------- | ---------- | ----------------------------------------------------------------- |
| `refreshInterval`  | integer | 1000       | Update interval in milliseconds (500-5000)                        |
| `displayMode`      | string  | "detailed" | Display mode: "detailed", "compact", "minimal"                    |
| `sidecarPosition`  | string  | "right"    | Sidecar position: "left", "right", "top", "bottom"                |
| `sidecarWidth`     | integer | 40         | Sidecar width as percentage of terminal (20-80)                   |
| `showAlbumArt`     | boolean | true       | Show album art information                                        |
| `colorScheme`      | string  | "auto"     | Color scheme: "auto", "light", "dark", "mono"                     |
| `progressBarStyle` | string  | "blocks"   | Progress bar style: "blocks", "bars", "dots", "arrows", "circles" |
| `performanceMode`  | boolean | true       | Enable performance optimizations                                  |
| `targetFPS`        | integer | 30         | Target frames per second for animations                           |
| `enableAnimations` | boolean | true       | Enable progress bar animations                                    |
| `compactThreshold` | integer | 80         | Terminal width threshold for auto-compact mode                    |
| `autoHideSidecar`  | boolean | false      | Hide sidecar when no music is playing                             |
| `showTimestamp`    | boolean | false      | Show last update timestamp                                        |
| `showControls`     | boolean | true       | Show playback controls status                                     |
| `colors`           | object  | see above  | Color configuration for different elements                        |

## Configuration Management Commands

### Viewing Configuration

```powershell
# View all configuration
Get-SpotifyLiveFeaturesStatus

# View specific section
$status = Get-SpotifyLiveFeaturesStatus
$status.Configuration.liveDisplay
```

### Updating Configuration

```powershell
# Update live display settings
Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
    refreshInterval = 2000
    displayMode = "compact"
    progressBarStyle = "bars"
}

# Update lyrics settings
Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
    preferredProvider = "musixmatch"
    cacheRetentionHours = 168
    syncHighlighting = $true
}

# Update statistics settings
Set-SpotifyLiveFeaturesConfiguration -Section "statistics" -Settings @{
    trackingEnabled = $true
    retentionDays = 180
    backgroundCollection = $true
}

# Update API client settings
Set-SpotifyLiveFeaturesConfiguration -Section "apiClient" -Settings @{
    rateLimitPerSecond = 2
    cacheEnabled = $true
    cacheTtlMs = 30000
}
```

### Resetting Configuration

```powershell
# Reset all configuration to defaults
Reset-SpotifyLiveFeaturesConfiguration
```

## Performance Tuning

### Recommended Settings by Use Case

#### High Performance (Minimal Resource Usage)

```json
{
  "liveDisplay": {
    "refreshInterval": 2000,
    "displayMode": "minimal",
    "performanceMode": true,
    "enableAnimations": false
  },
  "lyrics": {
    "cacheEnabled": true,
    "cacheRetentionHours": 168,
    "maxCacheSizeMB": 25
  },
  "statistics": {
    "backgroundCollection": true,
    "batchSize": 20,
    "compressionEnabled": true
  },
  "apiClient": {
    "cacheEnabled": true,
    "cacheTtlMs": 60000,
    "rateLimitPerSecond": 1
  }
}
```

#### Rich Experience (Full Features)

```json
{
  "liveDisplay": {
    "refreshInterval": 1000,
    "displayMode": "detailed",
    "enableAnimations": true,
    "showAlbumArt": true
  },
  "lyrics": {
    "syncHighlighting": true,
    "autoScroll": true,
    "showTimestamps": true
  },
  "statistics": {
    "enableAnalytics": true,
    "enableVisualization": true,
    "collectGenres": true,
    "collectDeviceInfo": true
  },
  "apiClient": {
    "rateLimitPerSecond": 2,
    "retryAttempts": 5
  }
}
```

## Troubleshooting Configuration Issues

### Common Problems

1. **Configuration Not Loading**

   - Check file permissions
   - Verify JSON syntax
   - Check file path

2. **Settings Not Taking Effect**

   - Restart live features
   - Check validation errors
   - Verify section names

3. **Performance Issues**
   - Review refresh intervals
   - Check cache settings
   - Monitor resource usage

### Diagnostic Commands

```powershell
# Check configuration status
Get-SpotifyLiveFeaturesStatus | Select-Object Configuration

# Validate configuration manually
$config = Get-Content "$env:APPDATA\SpotifyCLI\LiveFeatures\config.json" | ConvertFrom-Json
$config | ConvertTo-Json -Depth 10

# Reset to known good state
Reset-SpotifyLiveFeaturesConfiguration
```

---

This configuration reference provides complete documentation for the core settings in the Spotify CLI Live Features system. For detailed information about all available options, refer to the Complete User Guide.
