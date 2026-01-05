# Terminal Control Spotify - Features

Complete feature list for Terminal Control Spotify CLI.

## Core Features

### 🎵 Playback Control
- **Play/Pause** - `play`, `pause`, `toggle`
- **Next/Previous Track** - `next`, `previous`, `prev`
- **Volume Control** - `volume <0-100>`, `vol+`, `vol-`
- **Seek** - `seek <seconds>`, `seek +30`, `seek -10`
- **Shuffle** - `shuffle on/off/toggle`
- **Repeat** - `repeat off/context/track`

### 🔍 Search & Discovery
- **Search Tracks** - `search <query>` or `s <query>`
- **Search Results Navigation** - Interactive mode with arrow keys
- **Play from Search** - Direct playback from search results
- **Queue from Search** - Add search results to queue

### 📋 Queue Management
- **View Queue** - `queue` or `q`
- **Interactive Queue** - Navigate queue with arrow keys, Enter to play, Space to remove
- **Clear Queue** - `clear-queue`
- **Add to Queue** - `queue-add <track>` or `qa <track>`

### 📁 Playlist Management
- **List Playlists** - `playlists` or `pl`
- **Interactive Playlists** - Arrow key navigation, Enter to play
- **Play Playlist** - `play-playlist <name/number>`
- **Create Playlist** - `create-playlist <name>`
- **Add to Playlist** - `add-to-playlist <playlist> <track>`

### 📱 Device Management
- **List Devices** - `devices` or `dev`
- **Switch Device** - `device <name/number>` or `transfer <device>`
- **Auto-activation** - Automatically activates device when needed

### ℹ️ Track Information
- **Current Track** - `current` or `now`, `np`
- **Track Details** - Shows artist, album, duration, progress
- **Lyrics** (if available) - `lyrics`

## New Features (Latest)

### 🎨 Windows Form Display
Launch a floating window that shows current track information with live updates.

**Command:** `ShowSpotify` or `ss`

**Features:**
- Always-on-top floating window
- Real-time updates (every second)
- Color-coded information:
  - 🎵 **Song Title** - Green (Spotify brand color)
  - 👤 **Artist** - Yellow/Gold
  - 📀 **Album** - Blue
  - ⏭️ **Up Next** - Pink
- Progress bar with visual feedback
- Full playback controls:
  - **Prev** - Previous track
  - **Play/Pause** - Toggle playback (button changes based on state)
  - **Next** - Next track
  - **Shuffle** - Toggle shuffle (green when active)
  - **Repeat** - Toggle repeat modes (green when active)
- Non-blocking - runs in background, terminal remains usable
- Supports both music tracks and podcast episodes

**Usage:**
```powershell
# Open in background (recommended)
ss

# Open and block terminal (wait for close)
ShowSpotify -Block
```

### 🎮 Interactive Mode
Navigate and control Spotify using arrow keys and keyboard shortcuts.

**Available in:**
- Playlists (press Enter after `playlists` command)
- Queue (automatic when viewing queue)
- Search results (automatic after search)

**Controls:**
- **↑/↓** - Navigate up/down
- **Enter** - Play selected item
- **Space** - Add to queue (or remove from queue when in queue view)
- **Esc** - Exit interactive mode
- **1-9** - Quick select by number

**Features:**
- Visual selection indicator (►)
- Color-coded items (yellow highlight for selected)
- Supports playlists, tracks, queue items, and podcast episodes
- Automatic device activation when playing
- Real-time queue updates

### 🎤 Lyrics Windows Form Display
Beautiful floating window with synchronized lyrics that follow your music in real-time.

**Commands:** `Show-SpotifyLyricsForm`, `slw`, or `ShowLyrics`

**Features:**
- **Real-time synchronization** - Lyrics highlight automatically as the song plays
- **Three-color state system:**
  - **Dark gray** - Lines already sung
  - **Bright green (bold)** - Currently singing (highly visible!)
  - **White** - Upcoming lines
- **Auto-scroll** - Current line always visible, scrolls smoothly
- **Resizable window** - Drag to resize for more lyrics or wider text
- **Free provider** - Uses LRCLIB.net (no API key required!)
- **Synced lyrics support** - LRC format with timestamps for perfect timing
- **Smart caching** - Stores lyrics locally for 30 days
- **Multi-provider fallback** - LRCLIB → Genius → Musixmatch
- **Non-blocking** - Runs in background, terminal stays usable

**Color Scheme:**
```
[Dark Gray]     I cut the rope and you fell from the tower
[Dark Gray]     I let it go for my peace of mind
[Bright Green]  ► Bit the bullet, it didn't hurt         (currently singing)
[White]         But I still hate the image of you kissing her
[White]         I chalk it up to "it's all for the better"
```

**Usage:**
```powershell
# Quick launch (recommended)
slw

# While a song is playing
Get-SpotifyLyrics -Karaoke

# For specific song
Get-SpotifyLyrics -Artist "Queen" -Track "Bohemian Rhapsody"

# Alternative alias
ShowLyrics
```

**Console Lyrics:**
```powershell
# Display lyrics in console (static)
Get-SpotifyLyrics

# View current track lyrics
lyrics  # If alias is set up
```

**Providers:**
- **LRCLIB.net** (Primary) - Free, no API key, supports synced lyrics
- **Genius** (Fallback) - Requires API key (`$env:GENIUS_ACCESS_TOKEN`)
- **Musixmatch** (Fallback) - Requires API key (`$env:MUSIXMATCH_API_KEY`)

### 🚀 Sidecar Mode
Open Spotify CLI in a Windows Terminal split pane alongside your current work.

**Command:** `Start-SpotifySidecar` or `spotify --sidecar`

**Features:**
- Splits Windows Terminal into two panes
- Configurable split size (default: 40% width)
- Runs in split pane while keeping current terminal active
- Perfect for monitoring playback while working

**Usage:**
```powershell
# Default 40% split
Start-SpotifySidecar

# Custom width split
Start-SpotifySidecar -Width 30
```

## Configuration

### Authentication
Set up Spotify API credentials:
```powershell
# Set environment variables
$env:SPOTIFY_CLIENT_ID = "your_client_id"
$env:SPOTIFY_CLIENT_SECRET = "your_client_secret"

# Or use configuration command
spotify config set ClientId "your_client_id"
spotify config set ClientSecret "your_client_secret"
```

### View Configuration
```powershell
spotify config show
```

## Aliases

Quick shortcuts for common commands:

| Alias | Command | Description |
|-------|---------|-------------|
| `s` | `search` | Search for tracks |
| `p` | `play` | Play/resume |
| `n` | `next` | Next track |
| `prev` | `previous` | Previous track |
| `q` | `queue` | Show queue |
| `qa` | `queue-add` | Add to queue |
| `pl` | `playlists` | List playlists |
| `dev` | `devices` | List devices |
| `np` | `now` | Now playing |
| `ss` | `ShowSpotify` | Windows Form playback display |
| `slw` | `Show-SpotifyLyricsForm` | Lyrics window with live sync |
| `ShowLyrics` | `Show-SpotifyLyricsForm` | Alternative lyrics window alias |

## Requirements

- **PowerShell:** 7.0+ (PowerShell Core)
- **Platform:** Windows 10/11
- **Spotify Account:** Premium (required for playback control API)
- **Windows Terminal:** Optional, but recommended for best experience

## Tips & Tricks

### Quick Playback
```powershell
# Search and play in one go
s "bohemian rhapsody" | select -First 1 | play

# Play your first playlist
pl | select -First 1 | play-playlist
```

### Multi-tasking
```powershell
# Open form display for monitoring
ss

# Continue working in terminal
# The form updates automatically
```

### Device Management
```powershell
# List all devices
devices

# Switch to phone
device "iPhone"

# Let CLI auto-activate device
play  # Will activate first available device if none active
```

### Interactive Workflow
```powershell
# Browse playlists interactively
playlists
# Press Enter to enter interactive mode
# Use arrow keys to navigate, Enter to play

# Search and select interactively
search "chill music"
# Automatically enters interactive mode
# Press Space to add to queue, Enter to play
```

## Troubleshooting

### Windows Form doesn't appear
- Check that PowerShell 7+ is installed
- Verify Spotify API credentials are set
- Try running with `-Block` flag: `ShowSpotify -Block`

### Interactive mode not working
- Ensure you're using PowerShell 7+
- Check terminal supports keyboard input
- Try pressing Enter again after command

### No active device error
- Open Spotify app on any device
- CLI will auto-activate first available device
- Use `devices` to see available devices

### Queue not updating
- Some Spotify clients cache queue data
- Wait a few seconds for sync
- Shuffle toggle refreshes queue immediately

## API Reference

For detailed API information, see [Spotify-API-Guide.md](Spotify-API-Guide.md).

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines.

## License

See [LICENSE](../LICENSE) for license information.
