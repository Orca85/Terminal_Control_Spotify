# Spotify CLI Live Features - User Guide

## Overview

The Spotify CLI Live Features bring your music experience to life with real-time displays, synchronized lyrics, and detailed listening analytics. This guide covers all the new interactive features that transform your terminal into a dynamic music control center.

## 🎵 Live Display Features

### Real-Time Live Mode

The live display mode provides continuous updates of your current playback status with animated progress bars and rich track information.

#### Basic Usage

```powershell
# Start live display mode
spotify --live

# Start with specific refresh interval (0.5-5 seconds)
spotify --live --interval 2

# Start in compact mode
spotify --live --compact

# Start in minimal mode
spotify --live --minimal
```

#### Display Modes

**Detailed Mode (Default)**

- Full track information with album art
- Animated progress bar with time indicators
- Artist, album, and genre information
- Playback controls status (shuffle, repeat)

**Compact Mode**

- Essential track info only
- Smaller progress bar
- Perfect for smaller terminal windows

**Minimal Mode**

- Track name and progress only
- Ultra-compact for background monitoring

#### Controls in Live Mode

- **Ctrl+C**: Exit live mode gracefully
- **Space**: Pause/resume playback
- **→**: Next track
- **←**: Previous track
- **↑/↓**: Volume up/down
- **R**: Toggle repeat mode
- **S**: Toggle shuffle mode

### Sidecar Mode (Windows Terminal)

Sidecar mode creates a split-pane display that runs alongside your regular terminal work.

#### Requirements

- Windows Terminal (recommended)
- PowerShell 7+ for best experience

#### Usage

```powershell
# Start sidecar mode (right pane)
spotify --sidecar

# Start sidecar on left side
spotify --sidecar --position left

# Custom width (percentage of terminal)
spotify --sidecar --width 30

# Auto-hide when no music playing
spotify --sidecar --auto-hide
```

#### Sidecar Features

- **Persistent Display**: Stays open while you work
- **Auto-positioning**: Automatically sizes based on terminal
- **Background Updates**: Non-intrusive updates
- **Smart Cleanup**: Automatically closes when terminal exits

## 🎤 Lyrics Display

### Basic Lyrics Commands

```powershell
# Show lyrics for current track
lyrics

# Show lyrics with synchronized highlighting
lyrics --sync

# Show lyrics in scrollable mode
lyrics --scroll

# Search for specific song lyrics
lyrics "Bohemian Rhapsody" "Queen"
```

### Interactive Lyrics Navigation

When viewing lyrics, you can navigate using:

- **↑/↓**: Scroll up/down line by line
- **Page Up/Down**: Scroll by page
- **Home/End**: Jump to beginning/end
- **Space**: Pause/resume playback
- **Enter**: Jump to current playback position
- **Esc**: Exit lyrics view

### Synchronized Lyrics

For tracks with synchronized lyrics:

- Current line is highlighted in real-time
- Progress indicator shows position in song
- Auto-scroll follows playback position
- Click any line to seek to that position (where supported)

### Lyrics Sources

The CLI automatically searches multiple sources:

1. **Genius** (primary source)
2. **Musixmatch** (fallback)
3. **Local cache** (for previously viewed lyrics)

## 📊 Statistics & Analytics

### Basic Statistics Commands

```powershell
# Show monthly statistics (default)
stats

# Show statistics for different periods
stats day      # Today's listening
stats week     # This week
stats month    # This month
stats year     # This year

# Show specific date range
stats --from "2024-01-01" --to "2024-01-31"
```

### Detailed Statistics Views

```powershell
# Show only top tracks
stats --view tracks

# Show only top artists
stats --view artists

# Show genre distribution
stats --view genres

# Show listening patterns
stats --view patterns

# Show listening streaks
stats --view streaks

# Show comprehensive summary
stats --view summary
```

### Interactive Statistics Mode

```powershell
# Launch interactive statistics explorer
stats --interactive
```

In interactive mode:

- **1-9**: Select different views
- **T**: Change time period
- **E**: Export current view
- **R**: Refresh data
- **Q**: Quit interactive mode

### Export Options

```powershell
# Export to JSON
stats --export json

# Export to CSV
stats --export csv

# Export specific view
stats --view tracks --export json

# Export with custom filename
stats --export json --file "my-music-stats.json"
```

## ⚙️ Configuration

### Live Display Configuration

```powershell
# Set default refresh interval
Set-SpotifyConfig -LiveDisplayInterval 1.5

# Set default display mode
Set-SpotifyConfig -LiveDisplayMode "compact"

# Enable/disable animations
Set-SpotifyConfig -LiveDisplayAnimations $true

# Configure color scheme
Set-SpotifyConfig -LiveDisplayColors @{
    Playing = "Green"
    Paused = "Yellow"
    Track = "Cyan"
    Artist = "White"
    Progress = "Blue"
}
```

### Lyrics Configuration

```powershell
# Set preferred lyrics provider
Set-SpotifyConfig -LyricsProvider "genius"

# Enable/disable lyrics caching
Set-SpotifyConfig -LyricsCaching $true

# Set cache retention (days)
Set-SpotifyConfig -LyricsCacheRetention 30

# Enable synchronized highlighting
Set-SpotifyConfig -LyricsSyncHighlighting $true
```

### Statistics Configuration

```powershell
# Enable/disable statistics tracking
Set-SpotifyConfig -StatisticsTracking $true

# Set data retention period (days)
Set-SpotifyConfig -StatisticsRetention 365

# Set default time period
Set-SpotifyConfig -StatisticsDefaultPeriod "month"

# Configure export format
Set-SpotifyConfig -StatisticsExportFormat "json"
```

## 🎯 Advanced Usage Examples

### Workflow Integration

**Background Music Monitoring**

```powershell
# Start sidecar for background monitoring
spotify --sidecar --auto-hide

# Continue with your regular work
# Music info stays visible in side pane
```

**Lyrics Study Session**

```powershell
# Start synchronized lyrics for language learning
lyrics --sync

# Follow along with the music
# Pause and replay sections as needed
```

**Music Discovery Analysis**

```powershell
# Analyze your listening patterns
stats --view patterns --interactive

# Export data for further analysis
stats --export csv --file "listening-analysis.csv"
```

### Keyboard Shortcuts Summary

| Mode              | Key          | Action          |
| ----------------- | ------------ | --------------- |
| Live Display      | Ctrl+C       | Exit            |
| Live Display      | Space        | Pause/Resume    |
| Live Display      | →/←          | Next/Previous   |
| Live Display      | ↑/↓          | Volume          |
| Lyrics            | ↑/↓          | Scroll          |
| Lyrics            | Page Up/Down | Page scroll     |
| Lyrics            | Enter        | Jump to current |
| Lyrics            | Esc          | Exit            |
| Stats Interactive | 1-9          | Select view     |
| Stats Interactive | T            | Change period   |
| Stats Interactive | E            | Export          |
| Stats Interactive | Q            | Quit            |

## 🔧 Troubleshooting

### Live Display Issues

**Problem**: Live display is flickering

```powershell
# Increase refresh interval
spotify --live --interval 2
```

**Problem**: Display not updating

```powershell
# Check if Spotify is playing
plays-now

# Restart live mode
spotify --live --force-refresh
```

### Lyrics Issues

**Problem**: No lyrics found

- Try alternative search: `lyrics "song title" "artist"`
- Check internet connection
- Verify song is correctly identified: `plays-now`

**Problem**: Synchronized lyrics not working

```powershell
# Enable sync highlighting
Set-SpotifyConfig -LyricsSyncHighlighting $true

# Clear lyrics cache
Clear-SpotifyLyricsCache
```

### Statistics Issues

**Problem**: No statistics data

- Statistics tracking must be enabled: `Set-SpotifyConfig -StatisticsTracking $true`
- Data accumulates over time - play some music first
- Check data directory: `$env:APPDATA\SpotifyCLI\Statistics`

**Problem**: Export fails

```powershell
# Check permissions
Test-Path "$env:APPDATA\SpotifyCLI" -PathType Container

# Try different export location
stats --export json --file "C:\temp\stats.json"
```

## 🎵 Tips & Best Practices

### Performance Optimization

1. **Adjust refresh intervals** based on your needs

   - Use 2-3 seconds for casual monitoring
   - Use 0.5-1 second for active music sessions

2. **Use appropriate display modes**

   - Compact mode for smaller terminals
   - Minimal mode for background monitoring

3. **Manage cache sizes**
   - Clear lyrics cache periodically
   - Set reasonable retention periods

### Workflow Integration

1. **Use sidecar mode** for multitasking
2. **Set up aliases** for frequently used commands
3. **Export statistics regularly** for backup
4. **Customize colors** to match your terminal theme

### Data Management

1. **Enable statistics tracking** from day one
2. **Regular exports** prevent data loss
3. **Monitor cache sizes** to avoid disk space issues
4. **Use date ranges** for specific analysis periods

## 🚀 What's Next

The live features are continuously evolving. Upcoming enhancements include:

- **Cross-platform support** for macOS and Linux
- **Additional lyrics providers** and sources
- **Advanced analytics** with machine learning insights
- **Custom visualizations** and themes
- **Integration with music services** beyond Spotify

---

_For technical support or feature requests, use the built-in help system or check the troubleshooting guides._
