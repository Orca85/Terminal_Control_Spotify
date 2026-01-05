# Windows Form Display Guide

The Windows Form Display is a floating window that shows your current Spotify playback with real-time updates and full playback controls.

## Quick Start

```powershell
# Import the module
Import-Module .\SpotifyModule.psm1

# Open the display (recommended)
ss

# Or use the full command
ShowSpotify
```

## Features

### Live Information Display

The form shows the following information, updated every second:

- **🎵 Song Title** (Green) - Current track name
- **👤 Artist** (Yellow/Gold) - Artist name(s)
- **📀 Album** (Blue) - Album name
- **⏱️ Time** (Gray) - Current position / Total duration with play/pause icon
- **📊 Progress Bar** (Green) - Visual playback progress
- **⏭️ Up Next** (Pink) - Next track in queue

### Color Coding

Information is color-coded for easy reading:
- **Green (#1DB954)** - Spotify brand color for song titles and active states
- **Yellow (#FFD700)** - Artist names
- **Blue (#64B5F6)** - Album names
- **Pink (#FF69B4)** - Next track information
- **Dark background (#191414)** - Spotify's dark theme

### Playback Controls

Five buttons provide full playback control:

1. **Prev** - Skip to previous track
2. **Play/Pause** - Toggle playback (button text changes automatically)
3. **Next** - Skip to next track
4. **Shuffle** - Toggle shuffle mode (green when active)
5. **Repeat** - Toggle repeat modes (green when active)

All buttons respond immediately and update their visual state.

### Always-On-Top

The window stays on top of all other windows using Win32 API calls, ensuring you can always see what's playing. This works even with other "always on top" windows.

### Non-Blocking Operation

By default, the form opens in a background PowerShell process, allowing you to continue using your terminal. The form runs independently and updates automatically.

## Usage

### Basic Usage

```powershell
# Open form (non-blocking)
ss
```

The form appears within 1-2 seconds and begins updating automatically.

### Blocking Mode

If you want the form to block your terminal (useful for dedicated monitoring):

```powershell
ShowSpotify -Block
```

Terminal will be blocked until you close the form window.

### Closing the Form

Simply click the X button in the top-right corner of the window.

## Technical Details

### Update Frequency

The form updates every **1000ms (1 second)** to show:
- Current track information
- Playback position and progress
- Play/pause state
- Shuffle state
- Repeat state
- Next track in queue

### API Calls

Each update cycle makes 2-3 API calls:
- `GET /me/player/currently-playing` - Current track data
- `GET /me/player/queue` - Next track (only when track changes)
- `GET /me/player` - Player state (for button states)

### Font Support

The form uses **Segoe UI Emoji** font to support emoji display. If this font is not available, it falls back to standard Segoe UI.

### Window Properties

- **Size:** 450x260 pixels
- **Position:** Centered on screen at startup
- **Border:** Fixed tool window (thin border, no maximize button)
- **Topmost:** Always stays on top
- **Background:** Spotify dark theme (#191414)

## Button Behavior

### Play/Pause Button
- Shows **"Pause"** when music is playing
- Shows **"Play"** when music is paused
- Background color: **Spotify Green (#1DB954)**
- Clicking toggles playback state

### Shuffle Button
- **Gray background (#282828)** when shuffle is off
- **Green background (#1DB954)** when shuffle is on
- Clicking toggles shuffle state
- Updates "Up Next" immediately after toggle (shuffle changes queue order)

### Repeat Button
- **Gray background (#282828)** when repeat is off
- **Green background (#1DB954)** when repeat is on
- Text changes to **"Repeat 1"** when repeating single track
- Clicking cycles: off → context (repeat playlist) → off

### Prev/Next Buttons
- Simple gray buttons (#282828)
- Skip to previous/next track immediately

## Supported Content Types

### Music Tracks
- Shows artist names
- Shows album name
- Shows track duration

### Podcast Episodes
- Shows podcast name instead of artist
- Shows "Podcast Episode" instead of album
- Shows episode duration

## Troubleshooting

### Form doesn't appear

**Cause:** Background process may have failed to start.

**Solutions:**
1. Try blocking mode: `ShowSpotify -Block`
2. Check PowerShell version: `$PSVersionTable.PSVersion`
3. Verify API credentials: `$env:SPOTIFY_CLIENT_ID`

### "Error loading track" message

**Cause:** API call failed or credentials missing.

**Solutions:**
1. Check Spotify API credentials are set
2. Verify you have an active Spotify Premium account
3. Check your internet connection
4. Restart Spotify app

### Form shows "Loading..." forever

**Cause:** No active Spotify playback.

**Solutions:**
1. Start playing something in Spotify
2. Check that Spotify is open on a device
3. Use `devices` command to see available devices

### Buttons don't respond

**Cause:** API calls are failing or form lost connection.

**Solutions:**
1. Close and reopen the form
2. Check Spotify app is running
3. Verify API credentials

### Form disappears behind other windows

**Cause:** Another application is forcing itself on top.

**Solutions:**
1. Close and reopen the form (Win32 topmost is reapplied)
2. The form automatically reasserts topmost every second
3. Check for other "always on top" applications

### "Up Next" shows wrong track after shuffle

**Cause:** This is normal Spotify behavior.

**Explanation:** When you toggle shuffle, Spotify re-orders the entire queue. The "Up Next" display updates after 300ms to show the new first track in the shuffled queue.

## Performance

### Resource Usage
- **Memory:** ~50-80MB (separate PowerShell process)
- **CPU:** Minimal (~1-2% during updates)
- **Network:** 2-3 small API calls per second

### Battery Impact
Negligible impact on battery life. The 1-second update interval is efficient.

## Advanced Usage

### Styling Customization

To customize colors, edit `modules\UI\SpotifyFormDisplay.psm1`:

```powershell
# Change song title color
$lblSong.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#YOUR_COLOR")

# Change background
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#YOUR_COLOR")

# Change button colors
$btnPlayPause.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#YOUR_COLOR")
```

### Multiple Instances

You can open multiple form instances:

```powershell
ss  # First instance
ss  # Second instance
# etc.
```

Each instance runs independently and updates separately.

### Integration with Scripts

The form can be integrated into automation scripts:

```powershell
# Start playback and open monitor
play "my-playlist"
ss

# Continue with other tasks
# Form monitors playback in background
```

## Source Code

Location: `modules\UI\SpotifyFormDisplay.psm1`

Key components:
- **Show-SpotifyForm** - Main function
- **Timer event handler** - Updates display every second
- **Button click handlers** - Playback control logic
- **WindowHelper** - Win32 API for topmost window

## Related Documentation

- [Features Overview](FEATURES.md)
- [Interactive Mode Guide](INTERACTIVE-MODE.md)
- [Spotify API Guide](Spotify-API-Guide.md)
- [Troubleshooting Guide](Troubleshooting-Guide.md)

## Feedback

If you encounter issues or have suggestions for the Windows Form Display, please open an issue on GitHub.
