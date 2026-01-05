# Lyrics Guide - Terminal Control Spotify

Complete guide to using the synchronized lyrics feature in Terminal Control Spotify.

## Quick Start

```powershell
# Launch lyrics window for current track
slw

# View lyrics in console
Get-SpotifyLyrics

# Karaoke mode (opens window)
Get-SpotifyLyrics -Karaoke

# Specific song
Get-SpotifyLyrics -Artist "Queen" -Track "Bohemian Rhapsody"
```

## Windows Form Display

### Overview

The lyrics window provides a beautiful, non-blocking display with synchronized lyrics that highlight in real-time as the song plays.

### Commands

- `Show-SpotifyLyricsForm` - Full command name
- `slw` - Quick alias (Show Lyrics Window)
- `ShowLyrics` - Alternative alias
- `Get-SpotifyLyrics -Karaoke` - Opens window via karaoke mode

### Features

#### Real-Time Synchronization
- Updates every 100ms for smooth highlighting
- Syncs with Spotify API every 5 seconds to prevent drift
- Auto-scrolls to keep current line visible
- Works seamlessly with playback controls (play/pause/seek)

#### Three-Color State System

The lyrics window uses three distinct colors to show lyric states:

1. **Dark Gray** - Lines that have already been sung
   - Helps you see what's been covered
   - Fades into background for less distraction

2. **Bright Green (Bold, Larger Font)** - Currently singing
   - Highly visible and easy to follow
   - Bold and slightly larger for emphasis
   - Color: #67cd4e (bright green)

3. **White** - Upcoming lines
   - Clean and readable
   - Shows what's coming next

**Visual Example:**
```
[Dark Gray]     I cut the rope and you fell from the tower
[Dark Gray]     I let it go for my peace of mind
[Bright Green]  ► Bit the bullet, it didn't hurt         (currently singing)
[White]         But I still hate the image of you kissing her
[White]         I chalk it up to "it's all for the better"
```

#### Resizable Window

The lyrics window is fully resizable:
- **Drag edges** to resize window
- **Width** - Adjusts for long lyrics lines
- **Height** - Shows more or fewer lines at once
- All content uses **anchor points** - expands/contracts with window
- Header expands horizontally
- Lyrics panel expands both ways

#### Auto-Scroll

- Current line is always kept in view
- Scrolls automatically as song progresses
- Smooth scrolling with 200px margin
- Manual scrolling disabled (auto-scroll takes precedence)

### Window Details

**Title Bar:** `🎤 Lyrics - [Artist] - [Track]`

**Header Section:**
- Artist name
- Track name
- Source (LRCLIB, Genius, or Musixmatch)
- All in turquoise color (#4ECDC4)

**Lyrics Panel:**
- Dark background (#2D2D2D)
- Scrollable container
- Auto-scroll enabled
- Shows 15-20 lines at default size

**Window Properties:**
- Always on top
- Resizable
- Non-blocking (runs in background)
- Starts centered on screen
- Default size: 600x700 pixels

## Console Display

### Basic Usage

```powershell
# Display lyrics for current track
Get-SpotifyLyrics

# Display with specific parameters
Get-SpotifyLyrics -Artist "Artist Name" -Track "Track Name"
```

### Output

The console display shows:
- Track information (artist, title)
- Source provider
- Full lyrics text
- Link to web version (if available)

**Example:**
```
🎤 Fetching lyrics for: Gracie Abrams - Blowing Smoke

🔍 Searching for lyrics...
✅ Lyrics found!
📝 Source: LRCLIB

📄 Lyrics
============================================================

I cut the rope and you fell from the tower
I let it go for my peace of mind
...
```

## Lyrics Providers

### LRCLIB.net (Primary)

**Free, no API key required!**

- **Coverage:** Large database with popular and obscure tracks
- **Format:** Both plain text and LRC (synced) lyrics
- **Speed:** Fast response times
- **Features:**
  - Detects instrumental tracks
  - Multiple versions per song (different albums)
  - Community-sourced lyrics
- **Limitations:**
  - Some very new or very obscure songs may be missing
  - No guaranteed availability for all tracks

### Genius (Fallback #1)

**Requires API key**

Setup:
```powershell
$env:GENIUS_ACCESS_TOKEN = "your_token_here"
```

Get API token: https://genius.com/api-clients

- **Coverage:** Extensive database, especially for popular music
- **Format:** Plain text only (no synced lyrics)
- **Features:**
  - Rich metadata
  - Song annotations
  - Links to web version

### Musixmatch (Fallback #2)

**Requires API key**

Setup:
```powershell
$env:MUSIXMATCH_API_KEY = "your_key_here"
```

Get API key: https://developer.musixmatch.com/

- **Coverage:** Very large commercial database
- **Format:** Both plain and synced lyrics
- **Features:**
  - High-quality synchronized lyrics
  - Translation support
  - Official lyrics partnerships

### Provider Fallback Chain

When you request lyrics, the system tries providers in this order:

1. **LRCLIB** (always tries first, no key needed)
2. **Genius** (if `GENIUS_ACCESS_TOKEN` is set)
3. **Musixmatch** (if `MUSIXMATCH_API_KEY` is set)
4. **Cache** (checked before providers)

**Example flow:**
```
Request lyrics
    ↓
Check cache (found?) → Return cached
    ↓ (not found)
Try LRCLIB → Success? → Cache & return
    ↓ (failed)
Try Genius → Success? → Cache & return
    ↓ (failed)
Try Musixmatch → Success? → Cache & return
    ↓ (failed)
Return "not found"
```

## Smart Caching

### How It Works

- Lyrics are cached locally after first fetch
- Cache location: `%APPDATA%\SpotifyCLI\Lyrics`
- Cache duration: 30 days (configurable)
- JSON format for easy reading

### Cache Benefits

- **Faster loading** - Instant lyrics for cached tracks
- **Offline access** - View lyrics without internet
- **Reduced API calls** - Saves provider quotas
- **Privacy** - No repeated external requests

### Cache File Format

```json
{
  "TrackId": "Artist-Track",
  "FullText": "Lyrics text...",
  "SyncedLines": [
    {
      "Timestamp": 4780,
      "Text": "Lyric line..."
    }
  ],
  "Source": "LRCLIB",
  "HasSyncedLyrics": true,
  "CachedAt": "2025-01-05T12:00:00Z"
}
```

### Cache Management

```powershell
# Cache is managed automatically
# Files older than 30 days are cleaned up periodically
# Manual cleanup: Delete files in %APPDATA%\SpotifyCLI\Lyrics
```

## Technical Details

### LRC Format

LRCLIB provides lyrics in LRC format with timestamps:

```
[00:04.78] I cut the rope and you fell from the tower
[00:08.12] I let it go for my peace of mind
[00:09.15] Bit the bullet, it didn't hurt
```

Format: `[mm:ss.xx] Lyrics text`
- `mm` - Minutes
- `ss` - Seconds
- `xx` - Centiseconds (hundredths of a second)

### Synchronization Algorithm

1. **Initial Position** - Gets current playback position from Spotify API
2. **Time Tracking** - Increments position locally every 100ms
3. **API Sync** - Queries Spotify API every 5 seconds to correct drift
4. **Line Matching** - Finds current line by comparing timestamps
5. **Update Display** - Changes colors and scrolls as needed

### Performance

- **Update Frequency:** 100ms (10 times per second)
- **API Calls:** Every 5 seconds (very light load)
- **CPU Usage:** Minimal (only updates on line changes)
- **Memory:** ~5-10 MB for lyrics window
- **Startup Time:** 1-2 seconds for window to appear

## Troubleshooting

### Lyrics Not Found

**Possible causes:**
- Song is very new or obscure
- Instrumental track
- No providers have the lyrics

**Solutions:**
1. Wait a few days for new songs (crowd-sourced databases)
2. Try enabling Genius or Musixmatch with API keys
3. Check song name spelling

### Window Not Appearing

**Possible causes:**
- Background process taking time to start
- PowerShell execution policy

**Solutions:**
```powershell
# Check if PowerShell process started
Get-Process pwsh | Where-Object {$_.MainWindowTitle -like "*Lyrics*"}

# Check temp files
dir $env:TEMP\SpotifyLyrics\
```

### Lyrics Out of Sync

**Possible causes:**
- Internet connection lag
- Spotify API delays
- System clock drift

**Solutions:**
- Close and reopen lyrics window
- Check internet connection
- Restart Spotify application

### No Synchronized Lyrics

Some songs only have plain text lyrics (no timestamps). In this case:
- Window still opens
- Shows all lyrics at once
- No line highlighting
- No auto-scroll

**Note:** LRCLIB has the most synced lyrics. Genius never provides synced lyrics.

## Examples

### Example 1: Quick Lyrics

```powershell
# Play a song
spotify play

# Show lyrics window
slw

# Window appears with synced lyrics!
```

### Example 2: Search and Lyrics

```powershell
# Search for a song
search "bohemian rhapsody"

# Play it (interactive mode)
# Press Enter on desired result

# Show lyrics
slw
```

### Example 3: Specific Song

```powershell
# Get lyrics for any song (doesn't need to be playing)
Get-SpotifyLyrics -Artist "The Beatles" -Track "Hey Jude"

# Opens in console with plain text
```

### Example 4: Karaoke Night

```powershell
# Start playing your playlist
play-playlist "Party Mix"

# Open lyrics window
slw

# Sing along! Lyrics highlight as you sing
# Current line is always bright green and bold
```

## Tips & Tricks

### Tip 1: Use with Spotify Display

Combine lyrics window with Spotify display for the ultimate setup:

```powershell
ss    # Show playback controls
slw   # Show lyrics

# Now you have:
# - Playback info and controls (ss)
# - Synchronized lyrics (slw)
# Both updating in real-time!
```

### Tip 2: Resize for Your Screen

- Make window **wider** for long lines (avoid wrapping)
- Make window **taller** to see more upcoming lyrics
- Position windows side-by-side for dual display

### Tip 3: Keyboard-Free Singing

1. Create a playlist of your favorite karaoke songs
2. Start playlist: `play-playlist "Karaoke"`
3. Open lyrics: `slw`
4. Enable repeat: In `ss` window, click "Repeat"
5. Sit back and sing! No keyboard needed

### Tip 4: Learn Lyrics

Use the color system to learn new songs:
- **White lines** - Read ahead to prepare
- **Green line** - Currently singing (follow along)
- **Gray lines** - Already learned (review if needed)

### Tip 5: Custom Positioning

Windows Form remembers its position!
- Position window where you want it
- Next time it opens in the same spot
- Great for multi-monitor setups

## Related Documentation

- [Windows Form Display](WINDOWS-FORM-GUIDE.md) - Spotify playback display
- [Interactive Mode](INTERACTIVE-MODE.md) - Keyboard navigation
- [Features](FEATURES.md) - Complete feature list
- [Contributing](../CONTRIBUTING.md) - How to contribute

## Feedback

Found a bug or have a feature request? Open an issue on GitHub!

Enjoying the lyrics feature? Give the project a ⭐!
