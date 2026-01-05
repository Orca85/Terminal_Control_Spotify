# Interactive Mode Guide

Interactive Mode enables keyboard-driven navigation and control of Spotify using arrow keys and shortcuts. Navigate playlists, queue, and search results without typing commands.

## Quick Start

```powershell
# View playlists, then press Enter
playlists

# Search for music (automatically enters interactive mode)
search "your query"

# View queue (automatically enters interactive mode)
queue
```

## Controls

### Navigation
- **↑ Up Arrow** - Move selection up
- **↓ Down Arrow** - Move selection down
- **1-9 Number Keys** - Jump to item by number (quick select)

### Actions
- **Enter** - Play selected item
- **Space** - Add to queue (in playlists/search) or Remove from queue (in queue view)
- **Esc** - Exit interactive mode

## Features

### Visual Feedback

Selected items are highlighted with:
- **► Symbol** - Shows current selection
- **Yellow Color** - Selected item stands out
- **Item Numbers** - Each item has a number for quick selection

Example display:
```
🎮 Your Playlists - Interactive Mode
================================================================================
⌨️  Controls: ↑↓ Navigate | Enter Play | Space Queue | Esc Exit

  1. 📁 Chill Vibes • 50 tracks
► 2. 📁 Workout Mix • 30 tracks
  3. 📁 Focus Music • 75 tracks
```

### Item Type Display

Different item types have different icons:

- **📁 Playlists** - Shows track count and owner
- **🎵 Tracks** - Shows artist name
- **🎙️ Podcast Episodes** - Shows podcast name
- **Queue Items** - Shows track with artist

### Context-Aware Behavior

Interactive mode adapts based on what you're viewing:

**Playlists:**
- Enter → Play entire playlist
- Space → Add playlist to queue (if supported)
- Shows playlist description/owner

**Search Results:**
- Enter → Play track immediately
- Space → Add track to queue
- Shows artist and track info

**Queue:**
- Enter → Jump to and play that track
- Space → Remove track from queue
- Shows current queue position

## Usage Examples

### Browse and Play Playlists

```powershell
# List your playlists
playlists

# Press Enter when prompt appears
# Use ↑↓ to navigate
# Press Enter to play selected playlist
```

### Search and Queue Music

```powershell
# Search for tracks
search "indie rock"

# Automatically enters interactive mode
# Use Space to add multiple tracks to queue
# Press Esc when done
```

### Manage Queue

```powershell
# View current queue
queue

# Navigate to track you want to remove
# Press Space to remove it
# Press Enter to play a different track
```

### Quick Selection

```powershell
# List playlists
playlists

# Press Enter to activate interactive mode
# Press 3 to instantly select playlist #3
# Press Enter to play it
```

## Implementation Details

### Terminal Compatibility

Interactive mode requires:
- **PowerShell 7.0+** - For modern keyboard input handling
- **Console that supports ReadKey** - Most modern terminals work
- **No SSH session** - Direct console access required

Automatic detection checks `$Host.UI.RawUI.ReadKey` availability.

### Keyboard Input

Uses PowerShell's `ReadKey()` method with:
- **NoEcho** - Key presses aren't echoed to screen
- **IncludeKeyDown** - Captures key down events

Virtual key codes:
- `38` - Up arrow
- `40` - Down arrow
- `13` - Enter
- `32` - Space
- `27` - Escape
- `49-57` - Numbers 1-9

### Display Updates

The display refreshes on:
- Arrow key navigation (selection changes)
- Space key (after queue/remove action)
- Automatic (for queue updates)

Uses console cursor positioning to redraw items in place without clearing screen.

### Item Selection State

Maintains state variables:
- `$script:InteractiveMode` - Boolean, is interactive mode active
- `$script:CurrentItems` - Array of items being navigated
- `$script:SelectedIndex` - Currently selected index (0-based)

## Supported Item Types

### Playlists

Properties used:
- `type` or `search_type` = "playlist"
- `name` - Playlist name
- `description` - Playlist description (if available)
- `uri` - Spotify URI for playback

Display format: `📁 {name} • {description}`

### Tracks

Properties used:
- `name` - Track name
- `artists` - Array of artist objects
- `uri` - Spotify URI for playback

Display format: `🎵 {name} - {artists}`

### Podcast Episodes

Properties used:
- `type` = "episode"
- `name` - Episode name
- `show.name` - Podcast name
- `uri` - Spotify URI for playback

Display format: `🎙️ {name} - {show.name}`

### Queue Items

Properties used:
- `track.name` - Track name
- `track.artists` - Array of artist objects
- `track.uri` - Spotify URI for playback

Display format: `🎵 {name} - {artists}`

## Playback Integration

### Playing Items

When you press **Enter**, the selected item is played using:

```powershell
Play-SpotifyItem -Item $selectedItem
```

This function:
1. Detects item type (playlist vs track)
2. Constructs appropriate Spotify API call
3. Handles device activation if needed
4. Starts playback
5. Displays confirmation message

### Auto Device Activation

If no device is currently active, the system automatically:
1. Fetches available devices
2. Selects first available device
3. Activates it
4. Waits 500ms for activation
5. Retries playback command

This ensures playback "just works" even when Spotify isn't actively playing.

### Queueing Items

When you press **Space**, the selected item is queued using:

```powershell
Queue-SpotifyItem -Item $selectedItem
```

This function:
1. Extracts track URI
2. Calls Spotify queue API
3. Displays confirmation message
4. Refreshes display

## Error Handling

### No Items to Display

If the list is empty:
```
❌ No items to navigate
```

Interactive mode exits immediately.

### ReadKey Not Available

If terminal doesn't support keyboard input:
```
ℹ️ Interactive mode not supported in this terminal
```

Falls back to displaying items as simple list.

### Playback Errors

If playback fails:
- Error message is displayed
- Interactive mode remains active
- You can try another selection

### API Errors

All API calls are wrapped in try-catch:
- Errors are logged but don't crash interactive mode
- User sees friendly error messages
- Can retry or exit gracefully

## Performance

### Responsiveness

- Key presses are detected within **100ms**
- Display updates are instant (direct console manipulation)
- No noticeable lag even with large lists

### Resource Usage

- Minimal CPU usage (event-driven)
- No background polling
- Releases resources when exiting

## Tips & Best Practices

### Efficient Navigation

1. **Use number keys** for quick jumps (1-9)
2. **Hold arrow keys** to scroll quickly
3. **Press Esc** anytime to exit

### Multi-Queue Workflow

```powershell
# Search for music
search "chill"

# Press Space on multiple tracks to queue them
# Track 1 → Space
# Track 2 → Space
# Track 3 → Space
# Press Esc when done
```

### Playlist Exploration

```powershell
# Browse all playlists
playlists

# Enter interactive mode
# Navigate and preview different playlists
# Press Enter to play one
```

### Queue Management

```powershell
# View queue
queue

# Use Space to remove unwanted tracks
# Use Enter to jump to specific track
# Reorganize on the fly
```

## Troubleshooting

### Interactive mode says "not supported"

**Solutions:**
1. Verify PowerShell 7+: `$PSVersionTable.PSVersion`
2. Run in local terminal (not SSH)
3. Use Windows Terminal or PowerShell console

### Arrow keys don't work

**Solutions:**
1. Check keyboard input isn't captured by another app
2. Try exiting and re-entering interactive mode
3. Restart PowerShell session

### Selection jumps around

**Solutions:**
1. Console window may be too small
2. Resize terminal to see full list
3. Use number keys instead of arrows

### Items don't display correctly

**Solutions:**
1. Check terminal supports UTF-8 (for emojis)
2. Verify font supports symbols (📁 🎵 etc.)
3. Use Windows Terminal for best results

### Space key doesn't queue

**Solutions:**
1. Verify you're in search/playlist mode (not queue)
2. Check Spotify Premium account is active
3. Ensure active device exists

## Advanced Usage

### Scripting Integration

Interactive mode can be triggered programmatically:

```powershell
$searchResults = Search-Spotify "query"
Start-InteractiveMode -Items $searchResults -Title "Custom Search"
```

### Custom Item Lists

You can create custom lists for interactive navigation:

```powershell
$customItems = @(
    [PSCustomObject]@{
        name = "Item 1"
        uri = "spotify:track:..."
        type = "track"
    }
)

Start-InteractiveMode -Items $customItems -Title "My Custom List"
```

## Source Code

Location: `modules\Core\InteractiveMode.psm1`

Key functions:
- **Start-InteractiveMode** - Main entry point
- **Show-InteractiveItems** - Display/refresh list
- **Play-SpotifyItem** - Handle playback
- **Queue-SpotifyItem** - Handle queueing

## Related Documentation

- [Features Overview](FEATURES.md)
- [Windows Form Guide](WINDOWS-FORM-GUIDE.md)
- [Playlist Management](../docs/Example-Scenarios.md)
- [Queue Management](../docs/Example-Scenarios.md)

## Feedback

Interactive mode is constantly being improved. If you have suggestions or encounter bugs, please open an issue on GitHub!
