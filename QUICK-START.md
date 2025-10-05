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

### Discovery

```powershell
search "artist name"    # Search for music
devices                 # List Spotify devices
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

### Use Aliases

```powershell
music            # Short for 'spotify' (Show-SpotifyTrack)
spotify          # Show current track
vol 50           # Short for 'volume 50'
pl               # Short for 'playlists'
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

### Configuration

```powershell
# Enable notifications
notifications on

# Set compact mode
Set-SpotifyConfig @{CompactMode=$true}

# View all settings
Get-SpotifyConfig
```

## 🎯 Workflow Examples

### Morning Routine

```powershell
devices          # Check available devices
pl               # Browse playlists
# Copy playlist URI from output
# Play your morning playlist
```

### Music Discovery

```powershell
search "new indie rock"    # Find new music
# Copy track URI from results
q <track_uri>             # Add to queue
save-track                # Save if you like it
```

### Quick Controls

```powershell
sp               # Check what's playing
vol 60           # Adjust volume
sh toggle        # Toggle shuffle
rep context      # Repeat playlist
```

Remember: Run `help` anytime to see all available commands!
