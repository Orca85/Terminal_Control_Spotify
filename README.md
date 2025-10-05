# Spotify CLI for PowerShell - Enhanced Edition

A streamlined command-line interface for controlling Spotify playback directly from PowerShell.  
This version provides essential Spotify control with core playback features, device management, search capabilities, and visual enhancements - optimized for reliability and ease of use.

---

## ✨ Features

### 🎵 Core Playback

- **Current Track Display**: Rich track information with progress bars and color coding
- **Basic Controls**: Play, pause, next, previous track
- **Advanced Controls**: Volume, seek, shuffle, repeat modes
- **Compact Mode**: Single-line track display for minimal output

### 📱 Device Management

- **Device Discovery**: List all available Spotify Connect devices
- **Device Transfer**: Switch playback between devices seamlessly
- **Device Status**: See which device is currently active

### 🔍 Search & Discovery

- **Music Search**: Search for tracks, artists, albums, and playlists
- **Queue Management**: Add tracks to your playback queue

### 📚 Library Management

- **Playlist Access**: Browse your playlists
- **Liked Songs**: View your saved tracks
- **Recently Played**: See your listening history
- **Save/Unsave**: Add or remove tracks from your library

### 🎨 Visual Enhancements

- **Progress Bars**: ASCII progress indicators for track position
- **Color Coding**: Different colors for playing/paused states and content types
- **Rich Display**: Detailed track information with emojis and formatting
- **Customizable Colors**: Configure display colors to your preference

### ⚙️ System Features

- **Configuration Management**: Persistent settings and preferences
- **Windows Notifications**: Toast notifications for track changes
- **Command Aliases**: Short aliases for frequently used commands
- **Comprehensive Help**: Built-in help system with detailed command documentation

### 🌐 Global Commands

- Use commands anywhere in PowerShell after installation
- Works on Windows PowerShell 5.1 and PowerShell 7+
- Backward compatible with existing workflows

### 🔢 Smart Number References

- **Numbered Devices**: Use `transfer 1` instead of long device IDs
- **Numbered Tracks**: Use `play 1` or `queue 2` from search results
- **Session Memory**: Commands remember your last search and device list
- **User-Friendly**: No more copying/pasting long Spotify URIs

### 🎯 Custom Aliases

- **Built-in Aliases**: Short commands like `sp`, `vol`, `sh`, `rep`
- **Custom Aliases**: Create your own shortcuts with `Set-SpotifyAlias`
- **Alias Management**: View, modify, and remove aliases easily
- **Conflict Detection**: Automatic detection of PowerShell command conflicts

---

## ⚙️ Requirements

- **Spotify Premium account** (required for playback control via API)
- **Spotify Developer App** (free to create)
- PowerShell 5.1+ (Windows) or PowerShell 7+ (cross-platform)

---

## 🚀 Setup

### 1. Create a Spotify Developer App

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Click **Create App**.
3. Fill in:
   - **App name**: e.g. `SpotifyCLI`
   - **Redirect URI**: must match the script:
     ```
     http://127.0.0.1:8888/callback
     ```
4. Save the app and copy your **Client ID** and **Client Secret**.

### 2. Configure Environment Variables

Create a `.env` file in the project folder:

```
SPOTIFY_CLIENT_ID=your_client_id_here
SPOTIFY_CLIENT_SECRET=your_client_secret_here
```

### 3. Install Global Commands (Recommended)

```powershell
./Install-SpotifyCommands.ps1
```

Then restart PowerShell or run:

```powershell
. $PROFILE
```

### 4. Alternative: Run as Regular Script

```powershell
./spotifyCLI.ps1
```

If you get an execution policy error, run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

---

## 🎮 Usage

### Global Commands (after installation)

Use commands anywhere in PowerShell:

#### 🎵 Core Playback Controls

| Command             | Action                        | Example             | Alias           |
| ------------------- | ----------------------------- | ------------------- | --------------- |
| `Show-SpotifyTrack` | Show current track (detailed) | `Show-SpotifyTrack` | `spotify`, `sp` |
| `spotify-now`       | Show current track (compact)  | `spotify-now`       | -               |
| `play`              | Resume playback               | `play`              | -               |
| `pause`             | Pause playback                | `pause`             | -               |
| `next`              | Skip to next track            | `next`              | -               |
| `previous`          | Skip to previous track        | `previous`          | -               |

#### 🎛️ Advanced Controls

| Command   | Action                | Example        | Alias |
| --------- | --------------------- | -------------- | ----- |
| `volume`  | Set volume (0-100)    | `volume 75`    | `vol` |
| `seek`    | Seek forward/backward | `seek 30`      | -     |
| `shuffle` | Control shuffle       | `shuffle on`   | `sh`  |
| `repeat`  | Control repeat mode   | `repeat track` | `rep` |

#### 📱 Device Management

| Command    | Action                 | Example                              | Alias |
| ---------- | ---------------------- | ------------------------------------ | ----- |
| `devices`  | List available devices | `devices`                            | -     |
| `transfer` | Switch to device       | `transfer 1` or `transfer device_id` | `tr`  |

#### 🔍 Search & Queue

| Command  | Action           | Example                                | Alias |
| -------- | ---------------- | -------------------------------------- | ----- |
| `search` | Search for music | `search "bohemian rhapsody"`           | -     |
| `play`   | Play track       | `play 1` or `play spotify:track:...`   | -     |
| `queue`  | Add to queue     | `queue 2` or `queue spotify:track:...` | `q`   |

#### 📚 Library Management

| Command        | Action               | Example        | Alias |
| -------------- | -------------------- | -------------- | ----- |
| `playlists`    | Show your playlists  | `playlists`    | `pl`  |
| `liked`        | Show liked songs     | `liked`        | -     |
| `recent`       | Show recently played | `recent`       | -     |
| `save-track`   | Save current track   | `save-track`   | -     |
| `unsave-track` | Remove current track | `unsave-track` | -     |

#### ⚙️ Configuration & Help

| Command             | Action                  | Example                                  | Alias  |
| ------------------- | ----------------------- | ---------------------------------------- | ------ |
| `Get-SpotifyConfig` | View configuration      | `Get-SpotifyConfig`                      | -      |
| `Set-SpotifyConfig` | Modify settings         | `Set-SpotifyConfig @{CompactMode=$true}` | -      |
| `notifications`     | Control notifications   | `notifications on`                       | -      |
| `Get-SpotifyHelp`   | Show comprehensive help | `Get-SpotifyHelp`                        | `help` |
| `spotify-help`      | Short alias for help    | `spotify-help`                           | -      |

#### 🎯 Alias Management

| Command               | Action              | Example                                                        |
| --------------------- | ------------------- | -------------------------------------------------------------- |
| `Set-SpotifyAlias`    | Create custom alias | `Set-SpotifyAlias -Alias 'music' -Command 'Show-SpotifyTrack'` |
| `Get-SpotifyAliases`  | View all aliases    | `Get-SpotifyAliases`                                           |
| `Remove-SpotifyAlias` | Remove alias        | `Remove-SpotifyAlias -Alias 'music'`                           |
| `Test-AliasConflicts` | Check for conflicts | `Test-AliasConflicts`                                          |

### Script Mode (Interactive CLI)

Run `./spotifyCLI.ps1` for an interactive experience with all commands available using `/` prefix:

| Command           | Action                | Example                 |
| ----------------- | --------------------- | ----------------------- |
| `/help`           | Show all commands     | `/help`                 |
| `/help <command>` | Detailed command help | `/help search`          |
| `/spotify`        | Show current track    | `/spotify`              |
| `/search <query>` | Search for music      | `/search "the beatles"` |
| `/devices`        | List devices          | `/devices`              |
| `/config`         | Manage settings       | `/config`               |
| `/quit`           | Exit CLI              | `/quit`                 |

### Examples

#### Basic Usage

```powershell
PS C:\> spotify
🎵 Bohemian Rhapsody
👤 Queen
📀 A Night at the Opera
[████████████░░░░░░░░░░░░░░░░░░] 67%
⏱ 4:02 / 5:55 ▶️ Playing on 💻 Desktop

PS C:\> next
⏭️ Skipped to next track
# Toast notification appears: "Now Playing: Another One Bites the Dust by Queen"

PS C:\> vol 80
🔊 Volume set to 80%
```

#### Advanced Features with Number References

```powershell
PS C:\> search "pink floyd"
🔍 Search Results for "pink floyd":

TRACKS:
1. Comfortably Numb - Pink Floyd (The Wall)
2. Wish You Were Here - Pink Floyd (Wish You Were Here)
3. Another Brick in the Wall - Pink Floyd (The Wall)

💡 Tip: Use 'play 1' to play track #1, or 'queue 2' to add track #2 to queue

PS C:\> play 1
🎯 Playing track #1 (Comfortably Numb by Pink Floyd)...
▶️ Playing track

PS C:\> devices
📱 Available Devices:
1. 💻 Desktop (Computer) - Active, Volume: 75%
2. 📱 iPhone (Smartphone) - Volume: 50%
3. 🔊 Living Room Speaker (Speaker) - Volume: 80%

💡 Tip: Use 'transfer 1' to switch to device #1

PS C:\> transfer 2
🎯 Transferring to device #2 (iPhone)...
📱 Playback transferred successfully

PS C:\> queue 3
🎯 Adding track #3 (Another Brick in the Wall by Pink Floyd) to queue...
➕ Track added to queue

PS C:\> notifications test
🧪 Testing notification system...
# Toast notification appears: "Test Notification - This is a test message"
```

#### Configuration

```powershell
PS C:\> Get-SpotifyConfig
PreferredDevice    :
CompactMode        : False
NotificationsEnabled : True
AutoRefreshInterval : 0
Colors             : @{Playing=Green; Paused=Yellow; Track=Cyan}

PS C:\> Set-SpotifyConfig @{CompactMode=$true; NotificationsEnabled=$true}
✅ Configuration updated successfully
```

---

## 🔢 Smart Number References

One of the most user-friendly features is the ability to use simple numbers instead of long Spotify IDs and URIs:

### Device Numbers

```powershell
PS C:\> devices
📱 Available Devices:
1. 💻 Desktop (Computer) - Active, Volume: 75%
2. 📱 iPhone (Smartphone) - Volume: 50%
3. 🔊 Living Room Speaker (Speaker) - Volume: 80%

PS C:\> transfer 2    # Switch to iPhone (device #2)
🎯 Transferring to device #2 (iPhone)...
📱 Playback transferred successfully
```

### Track Numbers

```powershell
PS C:\> search "the beatles"
🔍 Search Results for "the beatles":

TRACKS:
1. Hey Jude - The Beatles (Past Masters)
2. Let It Be - The Beatles (Let It Be)
3. Come Together - The Beatles (Abbey Road)

PS C:\> play 1       # Play Hey Jude (track #1)
🎯 Playing track #1 (Hey Jude by The Beatles)...
▶️ Playing track

PS C:\> queue 3      # Add Come Together to queue
🎯 Adding track #3 (Come Together by The Beatles) to queue...
➕ Track added to queue
```

### Session Memory

The CLI remembers your last search results and device list throughout your PowerShell session:

- **Search once, use numbers**: After searching, use `play 1`, `queue 2`, etc.
- **List devices once**: After running `devices`, use `transfer 1`, `transfer 2`, etc.
- **No copying URIs**: Never need to copy/paste long Spotify URIs or device IDs
- **Persistent until new search**: Numbers stay valid until you search again

### Backward Compatibility

All commands still accept the original long-form IDs and URIs:

```powershell
# Both work the same way:
play 1                                    # Use number from search
play spotify:track:4iV5W9uYEdYUVa79Axb7Rh # Use full URI

# Both work the same way:
transfer 1                                # Use number from devices
transfer b04f69eae60b6a491f1243307628c51436b13a23  # Use full device ID
```

---

## 🎯 Custom Aliases System

Create your own shortcuts for frequently used commands:

### Built-in Aliases

The module comes with useful built-in aliases:

| Alias     | Command             | Description                   |
| --------- | ------------------- | ----------------------------- |
| `spotify` | `Show-SpotifyTrack` | Show current track (detailed) |
| `music`   | `Show-SpotifyTrack` | Alternative to spotify        |
| `sp`      | `Show-SpotifyTrack` | Short form                    |
| `vol`     | `volume`            | Volume control                |
| `sh`      | `shuffle`           | Shuffle control               |
| `rep`     | `repeat`            | Repeat control                |
| `tr`      | `transfer`          | Device transfer               |
| `q`       | `queue`             | Add to queue                  |
| `pl`      | `playlists`         | Show playlists                |
| `help`    | `Get-SpotifyHelp`   | Show help                     |

### Creating Custom Aliases

```powershell
# Create a new alias
Set-SpotifyAlias -Alias 'np' -Command 'Show-SpotifyTrack'
Set-SpotifyAlias -Alias 'v' -Command 'volume'
Set-SpotifyAlias -Alias 'find' -Command 'search'

# Use your custom aliases
np           # Shows current track
v 75         # Sets volume to 75%
find "jazz"  # Searches for jazz music
```

### Managing Aliases

```powershell
# View all current aliases
Get-SpotifyAliases

# Remove an alias
Remove-SpotifyAlias -Alias 'np'

# Check for conflicts with existing PowerShell commands
Test-AliasConflicts
```

### Alias Conflict Detection

The system automatically detects conflicts with existing PowerShell commands:

```powershell
PS C:\> Set-SpotifyAlias -Alias 'ls' -Command 'liked'
⚠️ Warning: Alias 'ls' conflicts with existing PowerShell command
❌ Cannot create alias 'ls' - conflicts with existing command

PS C:\> Test-AliasConflicts
🔍 Checking for alias conflicts...
✅ No conflicts detected with current aliases
```

---

## 📁 Project Structure

```
├── spotifyCLI.ps1              # Main script (interactive mode)
├── SpotifyModule.psm1          # PowerShell module for global commands
├── Install-SpotifyCommands.ps1 # Installation script
├── .env                        # Environment variables (create yourself)
└── README.md                   # This file
```

---

## 🔐 API Scopes Used

The enhanced script requests the following Spotify API scopes:

### Core Playback

- `user-read-playback-state` - Read current playback state
- `user-modify-playback-state` - Control playback (play, pause, seek, volume, etc.)
- `user-read-currently-playing` - Get currently playing track

### Library & Playlists

- `user-read-private` - Access user profile information
- `playlist-read-private` - Read private playlists
- `user-library-read` - Read saved tracks
- `user-library-modify` - Save/unsave tracks
- `user-read-recently-played` - Access listening history
- `user-top-read` - Access top tracks and artists

These scopes enable full functionality including playlist management, library access, and enhanced features.

---

## 📝 Notes

### Data Storage

- **Tokens**: `%APPDATA%\SpotifyCLI\tokens.json` - OAuth2 access and refresh tokens
- **Configuration**: `%APPDATA%\SpotifyCLI\config.json` - User preferences and settings
- **History**: `%APPDATA%\SpotifyCLI\playback-history.json` - Local playback history
- **Logs**: `%APPDATA%\SpotifyCLI\spotify-cli.log` - Debug logs (when enabled)

### Requirements

- **Spotify Premium**: Required for playback control features (seek, volume, device transfer, etc.)
- **Active Device**: Must have an active Spotify Connect device for playback control
- **Internet Connection**: Required for all API operations
- **PowerShell 5.1+**: Windows PowerShell 5.1 or PowerShell 7+

### Authentication

- First run opens browser for OAuth2 authentication
- Tokens automatically refresh when expired
- Re-authentication required if scopes change or tokens are corrupted

---

## 🔧 Troubleshooting

### Common Issues

#### Authentication Problems

- **"Authentication Setup Error"**: Run PowerShell as Administrator
- **"Could not start local authentication server"**: Check if port 8888 is available
- **"Authentication state mismatch"**: Security issue, try authentication again
- **"Token requires additional permissions"**: Enhanced features need more scopes, re-authenticate

#### Playback Issues

- **"No Active Device"**:
  - Open Spotify on any device (phone, computer, speaker)
  - Start playing any song to activate the device
  - Use `/devices` to see available devices
- **"Spotify Premium required"**: Many control features require Premium subscription
- **"No playback found"**: Start music playback on any Spotify device first

#### API Errors

- **Rate Limit Exceeded**: Wait a few moments, the CLI handles this automatically
- **Service Unavailable**: Spotify API is temporarily down, try again later
- **Network Error**: Check internet connection and firewall settings

#### Feature-Specific Issues

- **Notifications not working**:
  - Windows 10+ required for toast notifications
  - Install BurntToast module: `Install-Module BurntToast`
  - Use `notifications test` to verify functionality
- **Search returns no results**: Check spelling and try different search terms
- **Device transfer fails**: Ensure target device is online and active in Spotify
- **Configuration not saving**: Check write permissions to `%APPDATA%\SpotifyCLI\`

### Debug Information

Enable logging for detailed troubleshooting:

```powershell
Set-SpotifyConfig @{LoggingEnabled=$true; LogLevel="Debug"}
```

View logs:

```powershell
logs
```

### Getting Help

- Use `/help` in interactive mode for command-specific help
- Use `/help <command>` for detailed command documentation
- Check configuration with `Get-SpotifyConfig`
- Test connectivity with built-in diagnostics

---

## ⚙️ Configuration Options

The CLI supports extensive configuration through the `Get-SpotifyConfig` and `Set-SpotifyConfig` commands:

### Available Settings

| Setting                | Type    | Default  | Description                                     |
| ---------------------- | ------- | -------- | ----------------------------------------------- |
| `PreferredDevice`      | String  | `null`   | Default device ID for playback                  |
| `CompactMode`          | Boolean | `false`  | Use single-line track display                   |
| `NotificationsEnabled` | Boolean | `false`  | Enable Windows toast notifications              |
| `AutoRefreshInterval`  | Integer | `0`      | Auto-refresh interval in seconds (0 = disabled) |
| `LoggingEnabled`       | Boolean | `false`  | Enable debug logging to file                    |
| `HistoryEnabled`       | Boolean | `true`   | Track playback history locally                  |
| `MaxHistoryEntries`    | Integer | `100`    | Maximum history entries to keep                 |
| `LogLevel`             | String  | `"Info"` | Logging level: Debug, Info, Warning, Error      |
| `MaxLogSizeMB`         | Integer | `10`     | Maximum log file size before rotation           |
| `LogRetentionDays`     | Integer | `30`     | Days to keep old log files                      |

### Color Configuration

Customize display colors for different elements:

| Color Setting     | Default     | Description                 |
| ----------------- | ----------- | --------------------------- |
| `Colors.Playing`  | `"Green"`   | Color when track is playing |
| `Colors.Paused`   | `"Yellow"`  | Color when track is paused  |
| `Colors.Track`    | `"Cyan"`    | Color for track names       |
| `Colors.Artist`   | `"Yellow"`  | Color for artist names      |
| `Colors.Album`    | `"Green"`   | Color for album names       |
| `Colors.Progress` | `"Magenta"` | Color for progress bars     |

### Configuration Examples

```powershell
# Enable notifications and compact mode
Set-SpotifyConfig @{
    NotificationsEnabled = $true
    CompactMode = $true
}

# Enable debug logging
Set-SpotifyConfig @{
    LoggingEnabled = $true
    LogLevel = "Debug"
}

# Customize colors
Set-SpotifyConfig @{
    Colors = @{
        Playing = "Blue"
        Paused = "Red"
        Track = "White"
        Artist = "Cyan"
    }
}

# Create custom aliases
Set-SpotifyAlias -Alias 'music' -Command 'Show-SpotifyTrack'
Set-SpotifyAlias -Alias 'v' -Command 'volume'

# View all aliases
Get-SpotifyAliases

# Remove an alias
Remove-SpotifyAlias -Alias 'music'

# Check for alias conflicts
Test-AliasConflicts

# Set auto-refresh for 5 seconds
Set-SpotifyConfig @{AutoRefreshInterval = 5}
```

---

## 📜 License

This project is provided as-is for educational and personal use.
