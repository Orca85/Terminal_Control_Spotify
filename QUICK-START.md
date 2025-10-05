# Spotify CLI - Quick Start Guide

## 🚀 Getting Started

### 1. First Time Setup

```powershell
# Run the main CLI script to authenticate
.\spotifyCLI.ps1

# Follow the browser authentication process
# This creates the necessary tokens for global commands
```

### 2. Install Global Commands

```powershell
# Install commands globally in PowerShell
.\Install-SpotifyCommands.ps1

# Restart PowerShell or reload profile
. $PROFILE
```

### 3. Test Authentication

```powershell
# Check if everything is working
Test-SpotifyAuth

# Should show: ✅ Authentication successful!
```

## 🎵 Essential Commands

### Basic Playback

```powershell
spotify          # Show current track
play             # Resume playback
pause            # Pause playback
next             # Next track
previous         # Previous track
```

### Quick Controls

```powershell
vol 75           # Set volume to 75%
seek 30          # Seek forward 30 seconds
sh on            # Enable shuffle
rep track        # Repeat current track
```

### Discovery & Smart Numbers

```powershell
search "artist name"    # Search for music
play 1                  # Play first track from search
queue 2                 # Add second track to queue
devices                 # List Spotify devices
transfer 1              # Switch to first device
pl                      # Show your playlists
liked                   # Show liked songs
```

### Help

```powershell
help             # Show all commands
help search      # Detailed help for specific command
```

## 🔧 Troubleshooting

### Authentication Issues

If you get "401 Unauthorized" errors:

1. **Re-authenticate**: Run `.\spotifyCLI.ps1` to refresh tokens
2. **Check credentials**: Ensure `.env` file has correct Spotify app credentials
3. **Test status**: Run `Test-SpotifyAuth` to check authentication

### Common Problems

**"No Active Device"**

- Open Spotify on any device (phone, computer, speaker)
- Start playing any song to activate the device

**"Spotify Premium Required"**

- Many control features require a Premium subscription
- Read-only features (search, playlists, liked songs) work with Free accounts

**Commands Not Found**

- Run `.\Install-SpotifyCommands.ps1` to install global commands
- Restart PowerShell or run `. $PROFILE`

**Alias Issues**

- If aliases don't work: `Get-SpotifyAliases` to check status
- If alias conflicts: Some PowerShell aliases are read-only and can't be overridden
- To fix broken aliases: `Remove-SpotifyAlias -Alias 'name'` then recreate

## 💡 Pro Tips

### Use Built-in Aliases

```powershell
music            # Short for 'spotify' (Show-SpotifyTrack)
spotify          # Show current track
sp               # Even shorter for current track
vol 50           # Short for 'volume 50'
pl               # Short for 'playlists'
q                # Short for 'queue'
sh on            # Short for 'shuffle on'
rep track        # Short for 'repeat track'
tr 1             # Short for 'transfer 1'
```

### Create Custom Aliases

```powershell
# Create your own shortcuts
Set-SpotifyAlias -Alias 'music' -Command 'Show-SpotifyTrack'
Set-SpotifyAlias -Alias 'v' -Command 'volume'

# View all aliases
Get-SpotifyAliases

# Remove alias if needed
Remove-SpotifyAlias -Alias 'music'
```

### Chain Commands

```powershell
# Set volume and enable shuffle
vol 80; sh on

# Search and show current track
search "beatles"; spotify
```

### Configuration & Notifications

```powershell
# Test notifications first
notifications test

# Enable notifications for track changes
notifications on

# Set compact mode
Set-SpotifyConfig @{CompactMode=$true}

# View all settings
Get-SpotifyConfig

# Create custom aliases
Set-SpotifyAlias -Alias 'np' -Command 'Show-SpotifyTrack'
Get-SpotifyAliases
```

## 🎯 Workflow Examples

### Morning Routine

```powershell
devices          # Check available devices
pl               # Browse playlists
# Copy playlist URI from output
# Play your morning playlist
```

### Music Discovery (with Smart Numbers)

```powershell
search "new indie rock"    # Find new music
play 1                     # Play first result immediately
queue 2                    # Add second result to queue
queue 3                    # Add third result to queue
save-track                 # Save current track if you like it
```

### Device Management

```powershell
devices          # List all devices with numbers
transfer 1       # Switch to device #1
transfer 2       # Switch to device #2
sp               # Check what's playing and where
```

### Final Controls

```powershell
sp               # Check what's playing
vol 60           # Adjust volume
sh toggle        # Toggle shuffle
rep context      # Repeat playlist
notifications test  # Test notification system
```

## 🔢 Smart Number System

The biggest time-saver is using numbers instead of long IDs:

### Instead of this (old way):

```powershell
search "beatles"
# Copy: spotify:track:4iV5W9uYEdYUVa79Axb7Rh
play spotify:track:4iV5W9uYEdYUVa79Axb7Rh

devices
# Copy: b04f69eae60b6a491f1243307628c51436b13a23
transfer b04f69eae60b6a491f1243307628c51436b13a23
```

### Do this (new way):

```powershell
search "beatles"
play 1           # Play first result

devices
transfer 1       # Switch to first device
```

Much easier! 🎉

Remember: Run `help` anytime to see all available commands!
