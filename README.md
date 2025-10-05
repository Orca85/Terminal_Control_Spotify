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

| Command    | Action                 | Example              | Alias |
| ---------- | ---------------------- | -------------------- | ----- |
| `devices`  | List available devices | `devices`            | -     |
| `transfer` | Switch to device       | `transfer device_id` | `tr`  |

#### 🔍 Search & Queue

| Command  | Action           | Example                      | Alias |
| -------- | ---------------- | ---------------------------- | ----- |
| `search` | Search for music | `search "bohemian rhapsody"` | -     |
| `queue`  | Add to queue     | `queue spotify:track:...`    | `q`   |

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

PS C:\> Invoke-VolumeCommand 80
🔊 Volume set to 80%
```

#### Advanced Features

```powershell
PS C:\> search "pink floyd"
🔍 Search Results for "pink floyd":

TRACKS:
1. Comfortably Numb - Pink Floyd (The Wall)
2. Wish You Were Here - Pink Floyd (Wish You Were Here)
3. Another Brick in the Wall - Pink Floyd (The Wall)

PS C:\> devices
📱 Available Devices:
1. 💻 Desktop (Computer) - Active, Volume: 75%
2. 📱 iPhone (Smartphone) - Volume: 50%
3. 🔊 Living Room Speaker (Speaker) - Volume: 80%

PS C:\> notifications on
🔔 Notifications enabled
✅ Notification system ready: BurntToast module available
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
Set-SpotifyAlias -Alias 'vol' -Command 'volume'

# View all aliases
Get-SpotifyAliases

# Set auto-refresh for 5 seconds
Set-SpotifyConfig @{AutoRefreshInterval = 5}
```

---

## 📜 License

This project is provided as-is for educational and personal use.
