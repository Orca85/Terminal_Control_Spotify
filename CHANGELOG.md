# Changelog

All notable changes to Terminal Control Spotify will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Windows Form Display** (`ShowSpotify` / `ss` command)
  - Always-on-top floating window showing current playback
  - Real-time updates every second
  - Color-coded information (song, artist, album, next track)
  - Progress bar with visual feedback
  - Full playback controls (Prev, Play/Pause, Next, Shuffle, Repeat)
  - Non-blocking operation (runs in background process)
  - Support for both music tracks and podcast episodes
  - Automatic button state updates (shuffle/repeat indicators)
  - Emoji support with Segoe UI Emoji font
  - Win32 API integration for absolute topmost positioning

- **Interactive Mode Enhancements**
  - Arrow key navigation for playlists, queue, and search results
  - Visual selection indicator with color highlighting
  - Quick number key selection (1-9)
  - Space key to queue/remove items
  - Enter key to play items instantly
  - Automatic device activation when playing
  - Support for all item types (tracks, playlists, podcasts, queue items)
  - Context-aware behavior (different actions for different views)

- **Auto Device Activation**
  - Automatically activates first available device when playing
  - Eliminates "no active device" errors
  - Seamless playback start even when Spotify is idle
  - Integrated into both interactive mode and play commands

- **Enhanced Queue Management**
  - Interactive queue with arrow key navigation
  - Space key to remove items from queue
  - Enter key to jump to track in queue
  - Real-time queue updates after shuffle toggle
  - Visual feedback for queue operations

- **Lyrics Windows Form Display** (`ShowLyrics` / `slw` command)
  - Beautiful floating window with synchronized lyrics
  - Real-time highlighting following playback position
  - Three-color state system:
    - Dark gray for already sung lines
    - Bright green (bold) for current line
    - White for upcoming lines
  - Auto-scroll to keep current line visible
  - Resizable window with dynamic anchoring
  - Syncs with Spotify API every 5 seconds
  - Smooth position updates every 100ms
  - Non-blocking operation in background process
  - Support for both synced (LRC) and plain text lyrics

- **LRCLIB.net Integration**
  - Free lyrics provider requiring no API key
  - Primary provider with automatic fallback to Genius/Musixmatch
  - Support for synchronized lyrics (LRC format with timestamps)
  - Large database with both popular and obscure tracks
  - Detects instrumental tracks automatically
  - Smart caching with 30-day TTL

- **Enhanced Lyrics Commands**
  - `Get-SpotifyLyrics -Karaoke` now opens Windows Form (no more console flicker)
  - `Show-SpotifyLyricsForm` or `slw` for direct window launch
  - `ShowLyrics` alternative alias
  - Support for specific tracks: `-Artist` and `-Track` parameters
  - Automatic current track detection

- **Dynamic Font Sizing**
  - Spotify window (`ss`) automatically adjusts font size based on text length
  - Song titles: 14pt (short), 12pt (medium), 9pt (long)
  - Artist names: 11pt (short), 9pt (medium), 8pt (long)
  - Album names: 9pt (normal), 7pt (long)
  - Prevents text overflow for long track/artist names
  - Maintains readability across all text lengths

- **Module Organization**
  - Created `modules/UI/` directory for UI components
  - Split SpotifyFormDisplay into separate module
  - Added LyricsFormDisplay.psm1 for lyrics window
  - Improved module loading and dependency management
  - Better error handling across all modules

### Changed
- **Error Handling**
  - Removed typed catch blocks for better compatibility
  - Changed from `catch [ApiClientException]` to generic `catch`
  - Improved error messages in Windows Form display
  - Silent error handling in UI components

- **PowerShell Compatibility**
  - Replaced ternary operators with if-else statements
  - Replaced null-coalescing operators with if-else
  - Changed System.Web.HttpUtility to regex for cache filenames
  - Ensured compatibility with PowerShell 7.0+

- **API Client**
  - Fixed circular dependencies between ErrorHandling and ApiClientManager
  - Removed [ErrorHandler] type annotations
  - Changed type checking to use Get-Member instead
  - Improved API call reliability in UI components

- **Terminal Capabilities Detection**
  - Force SupportsInteractiveInput = true for PowerShell 7+
  - Better detection of ReadKey availability
  - Improved fallback behavior when interactive mode unavailable

### Fixed
- **String Formatting Issues**
  - Fixed emoji display in Windows Forms by using Segoe UI Emoji font
  - Fixed format specifier errors (`:D2` requires int, not decimal)
  - Cast Math.Floor results to [int] for proper formatting

- **Timer and Event Handling**
  - Fixed scriptblock closure issues in Windows Form timer
  - Properly capture function references for timer events
  - GetNewClosure() to maintain variable scope in events

- **Button Click Handlers**
  - Fixed API call syntax in button event handlers
  - Changed from `.ScriptBlock.Invoke()` to direct `Invoke-SpotifyApi` calls
  - Ensured button state updates correctly

- **Shuffle Queue Update**
  - Shuffle button now updates "Up Next" display immediately
  - Added 300ms delay to account for API queue update
  - Button color changes instantly on click

- **Sidecar Mode**
  - Fixed Windows Terminal --size parameter (expects 0.01-0.99, not percentage)
  - Convert percentage to decimal: `$Width / 100.0`
  - Proper argument escaping for wt.exe

- **Module Loading in Background Process**
  - Added proper error handling when launching Windows Form in background
  - Environment variables properly passed to new process
  - Better error messages when module loading fails

### Removed
- Temporary debug files (check_*.ps1)
- WindowsForm.md example file (replaced with proper documentation)
- setup_auth.ps1 (replaced with better documentation)
- .tmp/ directory and contents
- summaries/ directory (development notes)
- Archived old test files to tests/archive/

## [3.0.0] - Previous Release

### Added
- Live Features module
- Configuration system
- Help system
- Alias management
- Advanced queue management
- Playlist and library management
- Device management
- Search functionality
- Current track display
- Notification system

### Changed
- Complete module restructuring
- Improved error handling
- Better API integration
- Enhanced user experience

## [2.0.0] - Earlier Release

### Added
- Basic playback controls
- Search functionality
- Queue management
- Device switching

## [1.0.0] - Initial Release

### Added
- Core Spotify API integration
- Authentication system
- Basic playback control

---

## Release Notes

### Windows Form Display (Latest)

The Windows Form Display is the most significant addition in this release. It provides a modern, always-on-top window that shows your current Spotify playback with live updates and full controls.

**Key Features:**
- Non-blocking operation - terminal remains usable
- Real-time updates every second
- Color-coded information for easy reading
- Five playback control buttons with visual state indicators
- Support for music and podcasts
- Absolute topmost positioning (even over other "always on top" windows)

**Usage:** Simply type `ss` and the window appears. Close it anytime with the X button.

### Interactive Mode (Latest)

Interactive Mode has been completely revamped to provide keyboard-driven navigation:

**Key Features:**
- Arrow key navigation (↑↓)
- Quick number selection (1-9)
- Context-aware actions (Enter to play, Space to queue/remove)
- Visual selection with color highlighting
- Automatic device activation
- Works with playlists, search results, and queue

**Usage:** After running `playlists`, `search`, or `queue`, press Enter to activate interactive mode.

### Auto Device Activation (Latest)

No more "no active device" errors! The system now automatically:
1. Detects when no device is active
2. Finds available devices
3. Activates the first one
4. Retries the playback command

This "just works" approach eliminates a major pain point.

---

## Migration Guide

### From v3.0.0 to Current

1. **Update module import:**
   ```powershell
   Import-Module .\SpotifyModule.psm1 -Force
   ```

2. **New commands available:**
   - `ss` or `ShowSpotify` - Windows Form display
   - Interactive mode works automatically with `playlists`, `search`, `queue`

3. **No breaking changes** - All existing commands work as before

### Known Issues

- Emoji display in Windows Forms requires Segoe UI Emoji font
- Interactive mode requires PowerShell 7+ and direct console access
- Windows Form background process may take 1-2 seconds to appear

---

## Roadmap

See [docs/Roadmap.md](docs/Roadmap.md) for planned features and improvements.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.
