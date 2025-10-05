# Design Document

## Overview

This design extends the existing Spotify PowerShell CLI with comprehensive functionality while maintaining the current architecture. The enhancement builds upon the existing OAuth2 authentication system, token management, and API wrapper to provide advanced playback controls, device management, search capabilities, and visual improvements.

The design follows the existing modular approach with separate script and module files, ensuring backward compatibility while adding new features through command expansion and configuration management.

## Architecture

### Current Architecture (Maintained)

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   spotifyCLI.ps1│    │ SpotifyModule.psm1│    │  Spotify Web API│
│   (Interactive) │    │   (Global Cmds)   │    │                 │
│                 │    │                   │    │                 │
│ ┌─────────────┐ │    │ ┌───────────────┐ │    │ ┌─────────────┐ │
│ │ CLI Loop    │ │    │ │ Global Funcs  │ │    │ │ REST API    │ │
│ │ Command     │ │◄───┤ │ spotify()     │ │◄───┤ │ Endpoints   │ │
│ │ Parser      │ │    │ │ next()        │ │    │ │             │ │
│ └─────────────┘ │    │ │ pause()       │ │    │ └─────────────┘ │
└─────────────────┘    │ │ play()        │ │    └─────────────────┘
                       │ │ previous()    │ │
                       │ └───────────────┘ │
                       └──────────────────┘
                                │
                       ┌──────────────────┐
                       │ Shared Components│
                       │ ┌──────────────┐ │
                       │ │ Auth System  │ │
                       │ │ Token Store  │ │
                       │ │ API Wrapper  │ │
                       │ └──────────────┘ │
                       └──────────────────┘
```

### Enhanced Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   spotifyCLI.ps1│    │ SpotifyModule.psm1│    │  Spotify Web API│
│   (Enhanced)    │    │   (Enhanced)      │    │                 │
│                 │    │                   │    │                 │
│ ┌─────────────┐ │    │ ┌───────────────┐ │    │ ┌─────────────┐ │
│ │ Enhanced    │ │    │ │ Extended      │ │    │ │ Full API    │ │
│ │ CLI Loop    │ │◄───┤ │ Global Funcs  │ │◄───┤ │ Coverage    │ │
│ │ Help System │ │    │ │ + New Cmds    │ │    │ │             │ │
│ │ Config Mgmt │ │    │ │ + Visual Enh  │ │    │ └─────────────┘ │
│ └─────────────┘ │    │ └───────────────┘ │    └─────────────────┘
└─────────────────┘    └──────────────────┘
                                │
                       ┌──────────────────┐
                       │ Enhanced Core    │
                       │ ┌──────────────┐ │
                       │ │ Auth System  │ │
                       │ │ Token Store  │ │
                       │ │ API Wrapper  │ │
                       │ │ Config Store │ │
                       │ │ History Log  │ │
                       │ │ Visual Utils │ │
                       │ └──────────────┘ │
                       └──────────────────┘
```

## Components and Interfaces

### 1. Enhanced Command System

#### Command Categories

- **Playback Controls**: `/seek`, `/volume`, `/shuffle`, `/repeat`
- **Device Management**: `/devices`, `/transfer`
- **Search & Play**: `/search`, `/queue`, `/play`
- **Library Management**: `/playlists`, `/liked`, `/recent`, `/save`, `/unsave`
- **System Commands**: `/help`, `/config`, `/history`
- **Visual Commands**: `/spotify compact`, `/notifications`, `/auto-refresh`

#### Command Parser Enhancement

```powershell
function Invoke-SpotifyCommand {
    param([string]$Command)

    $parts = $Command.Trim() -split '\s+', 2
    $cmd = $parts[0].ToLower()
    $args = if ($parts.Length -gt 1) { $parts[1] } else { "" }

    switch ($cmd) {
        "/seek" { Invoke-SeekCommand $args }
        "/volume" { Invoke-VolumeCommand $args }
        "/shuffle" { Invoke-ShuffleCommand $args }
        "/repeat" { Invoke-RepeatCommand $args }
        "/devices" { Invoke-DevicesCommand }
        "/transfer" { Invoke-TransferCommand $args }
        "/search" { Invoke-SearchCommand $args }
        "/queue" { Invoke-QueueCommand $args }
        "/play" { Invoke-PlayCommand $args }
        "/playlists" { Invoke-PlaylistsCommand }
        "/liked" { Invoke-LikedCommand }
        "/recent" { Invoke-RecentCommand }
        "/save" { Invoke-SaveCommand }
        "/unsave" { Invoke-UnsaveCommand }
        "/help" { Invoke-HelpCommand $args }
        "/config" { Invoke-ConfigCommand $args }
        "/history" { Invoke-HistoryCommand }
        "/notifications" { Invoke-NotificationsCommand $args }
        "/auto-refresh" { Invoke-AutoRefreshCommand $args }
        # Existing commands remain unchanged
        default { Show-UnknownCommand $cmd }
    }
}
```

### 2. Configuration Management

#### Configuration Structure

```powershell
$DefaultConfig = @{
    PreferredDevice = $null
    CompactMode = $false
    NotificationsEnabled = $false
    AutoRefreshInterval = 0
    LoggingEnabled = $false
    HistoryEnabled = $true
    MaxHistoryEntries = 100
    Colors = @{
        Playing = "Green"
        Paused = "Yellow"
        Track = "Cyan"
        Artist = "Yellow"
        Album = "Green"
        Progress = "Magenta"
    }
}
```

#### Configuration File Location

- Path: `$env:APPDATA\SpotifyCLI\config.json`
- Format: JSON for easy serialization/deserialization
- Automatic creation with defaults if missing

### 3. Visual Enhancement System

#### Progress Bar Implementation

```powershell
function Show-ProgressBar {
    param(
        [int]$Current,
        [int]$Total,
        [int]$Width = 30
    )

    $percentage = [Math]::Round(($Current / $Total) * 100)
    $filled = [Math]::Round(($Current / $Total) * $Width)
    $empty = $Width - $filled

    $bar = "█" * $filled + "░" * $empty
    return "[$bar] $percentage%"
}
```

#### Color Coding System

```powershell
function Get-StatusColor {
    param([bool]$IsPlaying)

    $config = Get-SpotifyConfig
    return if ($IsPlaying) { $config.Colors.Playing } else { $config.Colors.Paused }
}
```

### 4. Enhanced API Wrapper

#### Extended Scopes Required

```powershell
$EnhancedScopes = @(
    "user-read-playback-state",
    "user-modify-playback-state",
    "user-read-currently-playing",
    "user-read-private",           # For playlists
    "playlist-read-private",       # For private playlists
    "user-library-read",           # For liked songs
    "user-library-modify",         # For save/unsave
    "user-read-recently-played",   # For recent tracks
    "user-top-read"               # For enhanced features
) -join " "
```

#### API Endpoint Mapping

```powershell
$ApiEndpoints = @{
    Seek = "/me/player/seek"
    Volume = "/me/player/volume"
    Shuffle = "/me/player/shuffle"
    Repeat = "/me/player/repeat"
    Devices = "/me/player/devices"
    Transfer = "/me/player"
    Search = "/search"
    Queue = "/me/player/queue"
    Play = "/me/player/play"
    Playlists = "/me/playlists"
    LikedTracks = "/me/tracks"
    RecentTracks = "/me/player/recently-played"
}
```

### 5. History and Logging System

#### History Structure

```powershell
$HistoryEntry = @{
    Timestamp = [DateTimeOffset]::UtcNow
    TrackName = $track.name
    Artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
    Album = $track.album.name
    Duration = $track.duration_ms
    PlayedAt = $playback.timestamp
}
```

#### Log File Management

- History: `$env:APPDATA\SpotifyCLI\history.json`
- Debug Log: `$env:APPDATA\SpotifyCLI\debug.log`
- Automatic rotation when files exceed size limits
- Configurable retention periods

## Data Models

### 1. Track Information Model

```powershell
class SpotifyTrack {
    [string]$Id
    [string]$Name
    [string[]]$Artists
    [string]$Album
    [int]$Duration
    [string]$Uri
    [string]$ExternalUrl
    [hashtable]$Images
}
```

### 2. Device Information Model

```powershell
class SpotifyDevice {
    [string]$Id
    [string]$Name
    [string]$Type
    [bool]$IsActive
    [bool]$IsPrivateSession
    [bool]$IsRestricted
    [int]$VolumePercent
}
```

### 3. Playback State Model

```powershell
class SpotifyPlaybackState {
    [SpotifyDevice]$Device
    [SpotifyTrack]$Track
    [bool]$IsPlaying
    [bool]$ShuffleState
    [string]$RepeatState
    [int]$ProgressMs
    [int]$VolumePercent
}
```

### 4. Search Results Model

```powershell
class SpotifySearchResults {
    [SpotifyTrack[]]$Tracks
    [hashtable[]]$Artists
    [hashtable[]]$Albums
    [hashtable[]]$Playlists
    [int]$Total
    [int]$Limit
    [int]$Offset
}
```

## Error Handling

### 1. Error Categories

- **Authentication Errors**: Token expired, invalid credentials
- **API Errors**: Rate limiting, service unavailable
- **Device Errors**: No active device, device unavailable
- **Content Errors**: Track not found, premium required
- **Network Errors**: Connection timeout, DNS resolution

### 2. Error Response Strategy

```powershell
function Handle-SpotifyError {
    param(
        [System.Management.Automation.ErrorRecord]$Error,
        [string]$Context
    )

    switch ($Error.Exception.Response.StatusCode) {
        401 {
            Write-Warning "Authentication expired. Re-authenticating..."
            Start-SpotifyAuthentication
        }
        403 {
            Write-Error "Spotify Premium required for this operation."
        }
        404 {
            Write-Error "Content not found. Please check your input."
        }
        429 {
            Write-Warning "Rate limit exceeded. Waiting before retry..."
            Start-Sleep -Seconds 5
        }
        default {
            Write-Error "Unexpected error in $Context`: $($Error.Exception.Message)"
        }
    }
}
```

### 3. Graceful Degradation

- Commands continue to work even if optional features fail
- Fallback to basic functionality when enhanced features are unavailable
- Clear messaging about feature limitations

## Testing Strategy

### 1. Unit Testing Approach

- Test individual command functions in isolation
- Mock Spotify API responses for consistent testing
- Validate error handling for various failure scenarios
- Test configuration management and persistence

### 2. Integration Testing

- Test complete command workflows end-to-end
- Validate OAuth2 flow with test credentials
- Test device switching and playback control
- Verify search and library management functionality

### 3. User Acceptance Testing

- Test with real Spotify accounts and devices
- Validate user experience across different scenarios
- Test performance with large playlists and search results
- Verify visual enhancements and color coding

### 4. Test Data Management

```powershell
$TestData = @{
    MockTrack = @{
        id = "test-track-id"
        name = "Test Track"
        artists = @(@{ name = "Test Artist" })
        album = @{ name = "Test Album" }
        duration_ms = 180000
    }
    MockDevice = @{
        id = "test-device-id"
        name = "Test Device"
        type = "Computer"
        is_active = $true
        volume_percent = 75
    }
}
```

### 5. Performance Considerations

- Implement caching for frequently accessed data (devices, playlists)
- Optimize API calls to minimize rate limiting
- Use pagination for large result sets
- Implement request batching where possible

### 6. Security Considerations

- Secure token storage with appropriate file permissions
- Validate all user inputs to prevent injection attacks
- Use HTTPS for all API communications
- Implement proper state validation in OAuth2 flow

This design maintains backward compatibility while significantly expanding functionality, following PowerShell best practices and the existing code patterns.
