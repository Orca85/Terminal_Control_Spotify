# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PowerShell Spotify CLI (v3.0.0) — a full-featured terminal client for Spotify with real-time playback display, synchronized lyrics, statistics analytics, and interactive navigation. Requires a Spotify Premium account and a Spotify Developer App (Client ID/Secret).

## Running the CLI

```powershell
# Normal launch (requires .env with SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET)
.\spotifyCLI.ps1

# Launch modes
.\spotifyCLI.ps1 -Sidecar                    # Split-pane in Windows Terminal
.\spotifyCLI.ps1 -Live                        # Direct to live display
.\spotifyCLI.ps1 -Live -LiveMode compact      # Compact live display
.\spotifyCLI.ps1 -NewWindow                   # Force new window
```

## Installation & Setup

```powershell
.\Install-SpotifyCLI-Complete.ps1    # Full setup
.\Clear-SpotifyCliInstallation.ps1   # Cleanup
```

Copy `.env.example` to `.env` and fill in Spotify credentials. Optional: add `GENIUS_ACCESS_TOKEN` for fallback lyrics.

## Testing

```powershell
.\tests\Test-ComprehensiveValidation.ps1    # 71 core tests
.\tests\Test-ActualPerformance.ps1          # Performance benchmarks
.\tests\Run-SpotifyDiagnostics.ps1          # Diagnostics
# Feature-specific tests are in tests/ (60+ files)
```

## Architecture

### Entry Point & Module Loading

`spotifyCLI.ps1` is the entry point. It loads `.env`, authenticates via OAuth 2.0 (Authorization Code Flow), imports `SpotifyCommands.psd1` (module manifest), and runs an interactive command loop.

`SpotifyCommands.psd1` declares the module structure: root module `SpotifyCommands.psm1` plus 12 nested modules loaded in order. The manifest exports ~60 functions and ~16 aliases.

### Module Organization

```
modules/
├── SpotifyLiveFeatures.psm1        # Master controller for live subsystems
├── Core/
│   ├── ApiClientManager.psm1       # Rate limiting, caching, exponential backoff
│   ├── LegacyApiClient.psm1        # Spotify REST client (GET/PUT/POST/DELETE)
│   ├── StateManager.psm1           # Session state (tracks, playlists, devices, queue)
│   ├── ErrorHandling.psm1          # Custom exceptions, graceful degradation
│   ├── ConfigurationManager.psm1   # JSON config schema, validation, persistence
│   ├── InteractiveMode.psm1        # Arrow-key navigation (↑↓ select, Enter play, Space queue)
│   ├── PlaybackCommands.psm1       # play, pause, next, prev, volume, seek, shuffle, repeat
│   ├── SearchCommands.psm1         # Track/album/podcast search
│   ├── PlaylistQueueCommands.psm1  # Playlist/album browsing, queue management
│   ├── AppCommands.psm1            # Config, help, notifications
│   └── UIHelpers.psm1              # Formatting, color coding, terminal detection
├── UI/
│   ├── SpotifyFormDisplay.psm1     # WinForms: now-playing window with controls
│   └── LyricsFormDisplay.psm1      # WinForms: synchronized lyrics window
├── Lyrics/
│   └── LyricsEngine.psm1          # Multi-provider lyrics (LRCLIB → Genius → Musixmatch)
├── Statistics/
│   └── StatisticsEngine.psm1      # Playback tracking, analytics, data export
└── LiveDisplay/
    ├── LiveDisplayEngine.psm1      # Real-time track display with progress bars
    └── PerformanceOptimizer.psm1   # Caching, update batching
```

### Key Architectural Patterns

**Separate Process for UI**: Lyrics and stats windows run as independent `pwsh` processes. `LyricsFormDisplay.psm1` generates a background script as a here-string template, saves lyrics data to a temp JSON file (`$env:TEMP\SpotifyLyrics\`), and launches it via `Start-Process`. This keeps the main CLI non-blocking.

**Session State via StateManager**: Search results, playlists, devices, and queue are stored in `$script:Session*` variables. Users reference results by number (e.g., `play 3` plays the 3rd search result) without re-querying the API.

**Multi-Level Caching**: In-memory API response cache (ApiClientManager) → file-based lyrics cache (`$env:APPDATA\SpotifyCLI\Lyrics\`) → session-scoped numbered lists (StateManager).

**Graceful Degradation**: `GracefulDegradationManager` in ErrorHandling.psm1 switches to offline mode after consecutive API failures. Rate limiter uses exponential backoff with jitter.

**Config Persistence**: Settings stored in `$env:APPDATA\SpotifyCLI\config.json`. Schema validation via `ConfigurationSchema` class in ConfigurationManager.psm1.

### External APIs

| API | Purpose | Auth |
|-----|---------|------|
| Spotify Web API | Playback control, track info | OAuth 2.0 (`.env`) |
| LRCLIB.net | Synced lyrics (LRC format) | Free, no key |
| Genius API | Lyrics fallback | Bearer token (optional) |
| Musixmatch API | Lyrics fallback | API key (optional) |

## Critical Gotchas

### Here-String Variable Scoping (Background Processes)
In `@"..."@` here-strings used to generate background scripts: `$var` expands from the parent scope, `` `$var `` (backtick-escaped) becomes a literal `$var` in the output. Escape sequences like `` `n `` stay literal in here-strings.

### .GetNewClosure() Module Scope
`.GetNewClosure()` creates a new module scope. `$script:` inside a closure refers to the closure's module scope, NOT the original script scope. Script-scope functions read from the actual script scope. Fix: pass data as parameters to functions instead of relying on shared `$script:` variables.

### WinForms ScrollPanel
`label.Top` in a scrolled Panel returns the displayed position (adjusted by scroll offset), not the virtual position. Use `ScrollControlIntoView()` instead of manually calculating `AutoScrollPosition`. The setter takes positive values but the getter returns negative values.

### Lyrics Sync
LRCLIB provides LRC format `[mm:ss.ms]Lyric text`. The lyrics timer runs every 100ms with a 5-second API position verification. Three-color highlighting: dark gray (sung), bright green (current), white (upcoming).

## Conventions

- PowerShell PascalCase for functions with approved verbs (Get-, Set-, Start-, Stop-)
- Aliases defined in `.psd1` manifest (e.g., `slw` → `Get-SpotifyLyrics`, `pn`/`plays-now` → `Show-SpotifyTrack`)
- Token storage: `$env:APPDATA\SpotifyCLI\tokens.json` (auto-refreshed)
- Credentials in `.env` (never committed — blocked by `.gitignore`)
