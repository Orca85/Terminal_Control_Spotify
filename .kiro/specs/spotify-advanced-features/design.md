# Design Document

## Overview

This design document outlines the architecture and implementation approach for advanced Spotify CLI features. The design focuses on enhancing user experience through interactive navigation, smart number references, cross-platform compatibility, and intuitive command structure while maintaining backward compatibility with existing functionality.

## Architecture

### Core Components

```
SpotifyModule.psm1
├── Session Management
│   ├── SessionDevices (existing)
│   ├── SessionTracks (existing)
│   ├── SessionPlaylists (new)
│   └── SessionAlbums (new)
├── Interactive Navigation Engine
│   ├── InteractiveMode Handler
│   ├── Keyboard Input Manager
│   └── Display Renderer
├── Cross-Platform Compatibility Layer
│   ├── Terminal Detection
│   ├── Feature Capability Detection
│   └── Graceful Degradation Handler
├── Enhanced Notification System
│   ├── Global Toast Manager
│   ├── Environment Detection
│   └── Fallback Mechanisms
└── Application Integration
    ├── Spotify Launcher
    ├── Window Management
    └── Process Detection
```

### New Module Structure

```powershell
# Core Functions (Enhanced)
Show-CurrentTrack (renamed from Show-SpotifyTrack)
Start-SpotifyApp (new)
Enter-InteractiveMode (new)

# Playlist Functions (New)
Show-Playlists
Start-PlaylistPlayback
Add-PlaylistToQueue

# Album Functions (New)
Search-Albums
Start-AlbumPlayback
Add-AlbumToQueue

# Interactive Functions (New)
Start-InteractiveSearch
Start-InteractivePlaylistBrowser
Start-InteractiveAlbumBrowser

# Enhanced Notification Functions
Show-GlobalNotification (enhanced)
Test-NotificationCompatibility (enhanced)

# Queue Management Functions (Enhanced)
Show-PlaybackQueue (enhanced)
Add-TrackToQueue (enhanced)
Remove-TrackFromQueue (new)
Clear-PlaybackQueue (new)

# Installation Functions (New)
Install-SpotifyCliDependencies
Test-SpotifyCliInstallation
```

## Components and Interfaces

### 1. Interactive Navigation Engine

#### InteractiveMode Handler

```powershell
class InteractiveMode {
    [string] $Mode  # "search", "playlists", "albums"
    [array] $Items
    [int] $SelectedIndex
    [hashtable] $KeyBindings

    [void] EnterMode($items, $mode)
    [void] HandleKeyPress($key)
    [void] UpdateDisplay()
    [void] ExitMode()
}
```

#### Key Bindings

- **Arrow Keys**: Navigate up/down through items
- **Enter**: Select/play highlighted item
- **Space**: Add to queue
- **'q'**: Add to queue (alternative to Space)
- **'p'**: Play playlist (when applicable)
- **'a'**: Play album (when applicable)
- **'s'**: Save/unsave track
- **Numbers (1-9)**: Jump to numbered item
- **Escape**: Exit interactive mode

#### Display Renderer

```powershell
function Render-InteractiveList {
    param(
        [array] $Items,
        [int] $SelectedIndex,
        [string] $Mode,
        [hashtable] $KeyBindings
    )

    # Clear screen and render header
    # Render items with highlighting
    # Show keyboard shortcuts footer
}
```

### 2. Enhanced Session Management

#### Playlist Session Storage

```powershell
$script:SessionPlaylists = @()  # Stores playlist objects with metadata
$script:SessionAlbums = @()     # Stores album objects with metadata

class PlaylistSession {
    [string] $Id
    [string] $Name
    [string] $Description
    [int] $TrackCount
    [string] $Owner
    [array] $Tracks  # Populated on demand
}

class AlbumSession {
    [string] $Id
    [string] $Name
    [string] $Artist
    [string] $ReleaseDate
    [int] $TrackCount
    [array] $Tracks  # Populated on demand
}
```

### 3. Cross-Platform Compatibility Layer

#### Terminal Detection

```powershell
function Get-TerminalCapabilities {
    return @{
        SupportsColors = Test-ColorSupport
        SupportsInteractiveInput = Test-InteractiveSupport
        SupportsSplitWindow = Test-SplitWindowSupport
        SupportsToastNotifications = Test-ToastSupport
        TerminalType = Get-TerminalType  # "WindowsTerminal", "VSCode", "PowerShellISE", etc.
    }
}
```

#### Feature Capability Matrix

| Feature                | Windows Terminal | VS Code | PowerShell ISE | Standalone PS |
| ---------------------- | ---------------- | ------- | -------------- | ------------- |
| Interactive Navigation | ✅               | ✅      | ⚠️ Limited     | ✅            |
| Toast Notifications    | ✅               | ✅      | ✅             | ✅            |
| Split Window           | ✅               | ✅      | ❌             | ❌            |
| Color Support          | ✅               | ✅      | ✅             | ✅            |
| Arrow Key Input        | ✅               | ✅      | ⚠️ Limited     | ✅            |

### 4. Enhanced Notification System

#### Global Toast Manager

```powershell
function Show-GlobalNotification {
    param(
        [string] $Title,
        [string] $Message,
        [object] $TrackInfo = $null
    )

    $capabilities = Get-TerminalCapabilities

    # Try multiple notification methods in order of preference
    if ($capabilities.SupportsToastNotifications) {
        try {
            Show-WindowsToastNotification $Title $Message $TrackInfo
            return
        } catch {
            Write-Verbose "Toast notification failed: $($_.Exception.Message)"
        }
    }

    # Fallback to console notification
    Show-ConsoleNotification $Title $Message $TrackInfo
}
```

#### Environment-Specific Implementations

```powershell
function Show-WindowsToastNotification {
    # Enhanced implementation that works across all PowerShell environments
    # Uses multiple approaches: BurntToast, Windows.UI.Notifications, COM objects
}

function Show-ConsoleNotification {
    # Enhanced console display with better formatting
    # Adapts to terminal capabilities
}
```

### 5. Application Integration

#### Spotify Launcher

```powershell
function Start-SpotifyApp {
    param(
        [switch] $Web,
        [switch] $WaitForReady
    )

    if ($Web) {
        Start-Process "https://open.spotify.com"
        return
    }

    # Try multiple methods to launch Spotify
    $spotifyPaths = @(
        "$env:APPDATA\Spotify\Spotify.exe",
        "${env:ProgramFiles}\Spotify\Spotify.exe",
        "${env:ProgramFiles(x86)}\Spotify\Spotify.exe"
    )

    foreach ($path in $spotifyPaths) {
        if (Test-Path $path) {
            Start-Process $path
            if ($WaitForReady) {
                Wait-ForSpotifyReady
            }
            return
        }
    }

    # Try Windows Store version
    try {
        Start-Process "spotify:"
        if ($WaitForReady) {
            Wait-ForSpotifyReady
        }
    } catch {
        Write-Host "❌ Spotify not found. Please install Spotify from https://spotify.com" -ForegroundColor Red
    }
}
```

#### Window Management

```powershell
function Start-SpotifyCliInSidecar {
    $capabilities = Get-TerminalCapabilities

    if ($capabilities.SupportsSplitWindow) {
        switch ($capabilities.TerminalType) {
            "WindowsTerminal" {
                # Use Windows Terminal split pane API
                Start-Process "wt" -ArgumentList "split-pane", "-p", "PowerShell", "powershell", "-NoExit", "-Command", "& '$PSScriptRoot\spotifyCLI.ps1'"
            }
            "VSCode" {
                # Use VS Code terminal splitting
                # This would require VS Code extension integration
                Write-Host "💡 In VS Code, use Ctrl+Shift+5 to split terminal, then run ./spotifyCLI.ps1" -ForegroundColor Cyan
            }
            default {
                # Fallback to new window
                Start-Process "powershell" -ArgumentList "-NoExit", "-Command", "& '$PSScriptRoot\spotifyCLI.ps1'"
            }
        }
    } else {
        # Run in current terminal
        & "$PSScriptRoot\spotifyCLI.ps1"
    }
}
```

## Data Models

### Enhanced Track Model

```powershell
class SpotifyTrack {
    [string] $Id
    [string] $Name
    [array] $Artists
    [object] $Album
    [string] $Uri
    [int] $DurationMs
    [bool] $IsLocal
    [string] $Type  # "track", "episode" (for podcasts)
    [object] $Show  # For podcast episodes
}
```

### Playlist Model

```powershell
class SpotifyPlaylist {
    [string] $Id
    [string] $Name
    [string] $Description
    [object] $Owner
    [int] $TrackCount
    [string] $Uri
    [array] $Images
    [bool] $Public
    [bool] $Collaborative
}
```

### Album Model

```powershell
class SpotifyAlbum {
    [string] $Id
    [string] $Name
    [array] $Artists
    [string] $ReleaseDate
    [int] $TotalTracks
    [string] $Uri
    [array] $Images
    [string] $AlbumType  # "album", "single", "compilation"
}
```

### Podcast Episode Model

```powershell
class SpotifyEpisode {
    [string] $Id
    [string] $Name
    [string] $Description
    [object] $Show
    [int] $DurationMs
    [string] $ReleaseDate
    [string] $Uri
    [array] $Images
    [bool] $IsExternallyHosted
}
```

### Queue Management Model

```powershell
class SpotifyQueue {
    [array] $CurrentlyPlaying  # Current track info
    [array] $Queue             # Upcoming tracks
    [int] $TotalTracks

    [void] AddTrack($track)
    [void] RemoveTrack($index)
    [void] Clear()
    [string] DisplayQueue()
}

class QueueItem {
    [int] $Position
    [object] $Track  # SpotifyTrack or SpotifyEpisode
    [string] $AddedBy
    [datetime] $AddedAt
}
```

## Error Handling

### Graceful Degradation Strategy

1. **Feature Detection**: Always check capabilities before using advanced features
2. **Fallback Mechanisms**: Provide simpler alternatives when advanced features fail
3. **Clear User Communication**: Inform users about limitations and alternatives
4. **Progressive Enhancement**: Core functionality works everywhere, advanced features enhance experience

### Error Scenarios and Handling

```powershell
# Interactive Mode Failures
if (-not $capabilities.SupportsInteractiveInput) {
    Write-Host "💡 Interactive mode not supported in this terminal. Use numbered commands instead." -ForegroundColor Yellow
    Show-NumberedList $items
    return
}

# Notification Failures
if (-not (Test-NotificationSupport)) {
    Write-Verbose "Toast notifications not available, using console output"
    $script:NotificationMode = "Console"
}

# Spotify Launch Failures
if (-not (Test-SpotifyInstalled)) {
    Show-SpotifyInstallationGuide
    return
}
```

## Testing Strategy

### Unit Testing Approach

```powershell
# Test interactive navigation
Describe "Interactive Navigation" {
    It "Should handle arrow key navigation" {
        # Mock keyboard input
        # Test selection changes
    }

    It "Should handle number key jumps" {
        # Test direct number selection
    }
}

# Test cross-platform compatibility
Describe "Cross-Platform Support" {
    It "Should detect terminal capabilities correctly" {
        # Test capability detection
    }

    It "Should provide appropriate fallbacks" {
        # Test degradation scenarios
    }
}

# Test notification system
Describe "Global Notifications" {
    It "Should work in all PowerShell environments" {
        # Test different PS environments
    }
}
```

### Integration Testing

- Test in multiple terminal environments
- Test with different PowerShell versions
- Test Spotify app integration scenarios
- Test notification delivery across environments

### User Acceptance Testing

- Test interactive workflows with real users
- Validate command intuitiveness
- Test installation process simplicity
- Verify cross-platform experience consistency

## Implementation Phases

### Phase 1: Core Infrastructure

1. Enhanced session management for playlists/albums
2. Cross-platform compatibility detection
3. Updated command structure and aliases
4. Global notification system improvements

### Phase 2: Interactive Features

1. Interactive navigation engine
2. Keyboard input handling
3. Display rendering system
4. Search/playlist/album browsers

### Phase 3: Application Integration

1. Spotify launcher functionality
2. Window management features
3. Process detection and waiting
4. Sidecar/split window support

### Phase 4: Enhanced Content Support

1. Playlist playback with numbers
2. Album search and playback
3. Podcast detection and display
4. Smart pause/resume toggle

### Phase 5: Installation and Polish

1. Simplified installation process
2. Dependency management
3. Comprehensive testing
4. Documentation updates

Each phase builds upon the previous one, ensuring that core functionality remains stable while adding advanced features incrementally.
