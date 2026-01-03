# Spotify CLI for PowerShell - Advanced Edition

A comprehensive command-line interface for controlling Spotify playback directly from PowerShell with advanced features including interactive navigation, smart playlist management, cross-platform compatibility, and enhanced user experience.

This advanced edition includes playlist/album playback with smart numbers, interactive navigation with arrow keys, podcast support, cross-terminal compatibility, simplified installation, and much more - all while maintaining the reliability and ease of use of the core edition.

---

## ✨ Advanced Features

### 🎵 Enhanced Playback Control

- **Current Track Display**: Rich track information with progress bars and color coding
- **Smart Pause/Resume**: Intelligent toggle between pause and resume states
- **Podcast Support**: Full support for podcast episodes with specialized display
- **Basic Controls**: Play, pause, next, previous track with enhanced feedback
- **Advanced Controls**: Volume, seek, shuffle, repeat modes
- **Compact Mode**: Single-line track display for minimal output

### 🎼 Smart Playlist & Album Management

- **Numbered Playlists**: Browse playlists with `playlists` and play with `play-playlist 1`
- **Album Search & Play**: Search albums with `search-albums` and play with `play-album 1`
- **Track Selection**: Play specific tracks from playlists with `play-playlist 1 5`
- **Queue Management**: Add entire playlists/albums to queue with smart numbers
- **Session Memory**: Persistent numbered references throughout your session

### 🎮 Interactive Navigation Engine

- **Arrow Key Navigation**: Navigate search results, playlists, and albums with arrow keys
- **Keyboard Shortcuts**:
  - `Enter` to play, `Space` to queue
  - `p` for playlists, `a` for albums, `s` to save/unsave
  - Number keys for direct selection, `Escape` to exit
- **Visual Highlighting**: Clear indication of selected items
- **Multi-Mode Support**: Works with search results, playlists, and albums

### 📱 Cross-Platform Device Management

- **Device Discovery**: List all available Spotify Connect devices with enhanced info
- **Smart Transfer**: Switch playbook between devices with numbers or IDs
- **Device Status**: Detailed device information including volume and type
- **Cross-Terminal Support**: Works in Windows Terminal, VS Code, PowerShell ISE

### 🔍 Enhanced Search & Discovery

- **Unified Search**: Search tracks, artists, albums, and podcast episodes together
- **Podcast Integration**: Podcast episodes appear in search with specialized display
- **Interactive Results**: Enter interactive mode from any search
- **Smart Numbers**: Use numbers to play or queue any result type

### 📚 Advanced Library Management

- **Enhanced Playlists**: Browse with metadata, track counts, and descriptions
- **Album Browsing**: Search and browse albums with release info
- **Liked Songs**: View your saved tracks with enhanced display
- **Recently Played**: See listening history including podcasts
- **Save/Unsave**: Add or remove tracks and episodes from your library

### 🎨 Cross-Platform Visual Experience

- **Terminal Detection**: Automatic detection of Windows Terminal, VS Code, PowerShell ISE
- **Graceful Degradation**: Features adapt based on terminal capabilities
- **Enhanced Colors**: Rich color coding that works across all environments
- **Progress Bars**: ASCII progress indicators optimized for each terminal
- **Notification System**: Toast notifications with multiple fallback methods

### 🪟 Window Management & Sidecar Support

- **Split Window Support**: Open CLI in Windows Terminal split panes
- **VS Code Integration**: Works seamlessly in VS Code integrated terminal
- **Sidecar Mode**: Run CLI alongside your main work without taking over
- **Automatic Detection**: Detects terminal capabilities and offers appropriate options

### 🎙️ Comprehensive Podcast Support

- **Episode Detection**: Automatically detects and displays podcast episodes
- **Rich Metadata**: Shows episode title, show name, description, release date
- **Progress Tracking**: Appropriate progress display for episode duration
- **Search Integration**: Podcast episodes appear in search results with clear identification
- **Save Episodes**: Save podcast episodes to your library

### ⚙️ Enhanced System Features

- **Simplified Installation**: One-command installation with dependency management
- **Cross-Platform Compatibility**: Works on Windows PowerShell 5.1 and PowerShell 7+
- **Global Notifications**: Toast notifications work across all PowerShell environments
- **Configuration Management**: Persistent settings with enhanced options
- **Comprehensive Help**: Built-in help system with command-specific documentation
- **Error Handling**: Graceful error handling with helpful troubleshooting messages

### 🌐 Restructured Command System

- **Intuitive Commands**: `spotify` launches app, `plays-now`/`music`/`pn` show current track
- **Legacy Support**: `sp` alias maintained for backward compatibility
- **Smart Aliases**: Enhanced alias system with conflict detection
- **Global Access**: Use commands anywhere in PowerShell after installation
- **Command Restructure**: Clear separation between app launcher and track display commands

### 🔢 Advanced Smart References

- **Numbered Everything**: Devices, tracks, playlists, albums, and episodes all use numbers
- **Session Persistence**: Numbers stay valid throughout your PowerShell session
- **Cross-Command Memory**: Search once, use numbers across multiple commands
- **User-Friendly**: Never need to copy/paste long Spotify URIs or IDs

### 🎯 Enhanced Custom Aliases

- **Built-in Aliases**: Comprehensive set of short commands
- **Custom Creation**: Create your own shortcuts with enhanced management
- **Conflict Detection**: Automatic detection and prevention of PowerShell conflicts
- **Alias Categories**: Organized aliases for different command types

---

## ⚙️ Requirements & Compatibility

### System Requirements

- **Spotify Premium account** (required for playback control via API)
- **Spotify Developer App** (free to create)
- PowerShell 5.1+ (Windows) or PowerShell 7+ (cross-platform)

### Cross-Platform Compatibility

The advanced edition is designed to work seamlessly across different environments:

#### ✅ Fully Supported Environments

| Environment                     | Interactive Navigation | Split Window | Toast Notifications | All Features |
| ------------------------------- | ---------------------- | ------------ | ------------------- | ------------ |
| **Windows Terminal**            | ✅                     | ✅           | ✅                  | ✅           |
| **VS Code Integrated Terminal** | ✅                     | ✅           | ✅                  | ✅           |
| **PowerShell 7+ Console**       | ✅                     | ❌           | ✅                  | ✅           |
| **Windows PowerShell 5.1**      | ✅                     | ❌           | ✅                  | ✅           |

#### ⚠️ Limited Support Environments

| Environment               | Interactive Navigation | Split Window | Toast Notifications | Core Features |
| ------------------------- | ---------------------- | ------------ | ------------------- | ------------- |
| **PowerShell ISE**        | ⚠️ Limited             | ❌           | ✅                  | ✅            |
| **Third-party Terminals** | ✅ (varies)            | ❌           | ✅                  | ✅            |

#### Graceful Degradation

The CLI automatically detects your environment and adapts:

- **Interactive Navigation**: Falls back to numbered commands if arrow keys aren't supported
- **Split Window**: Opens in new window if split panes aren't available
- **Toast Notifications**: Falls back to console notifications if toast isn't supported
- **Colors**: Adapts color usage based on terminal capabilities

#### Environment Detection

```powershell
# Check your environment capabilities
PS C:\> Show-TerminalCapabilities
Terminal Type: WindowsTerminal
PowerShell Version: 7.5.3
Color Support: True
Interactive Input: True
Split Window Support: True
Toast Notifications: True
```

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

### 3. Simplified Installation (Recommended)

The advanced edition includes a comprehensive installation system:

```powershell
# Complete installation with dependency management
./Install-SpotifyCliDependencies.ps1
```

This will:

- Install required PowerShell modules (BurntToast for notifications)
- Set up global commands in your PowerShell profile
- Configure cross-platform compatibility
- Test the installation and provide verification

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

#### 🎵 Enhanced Playback Controls

| Command             | Action                        | Example             | Alias         |
| ------------------- | ----------------------------- | ------------------- | ------------- |
| `spotify`           | Launch Spotify application    | `spotify`           | -             |
| `plays-now`         | Show current track (detailed) | `plays-now`         | `music`, `pn` |
| `Show-SpotifyTrack` | Show current track (detailed) | `Show-SpotifyTrack` | `sp` (legacy) |
| `play`              | Resume/play track             | `play` or `play 1`  | -             |
| `pause`             | Smart pause/resume toggle     | `pause`             | -             |
| `next`              | Skip to next track            | `next`              | -             |
| `previous`          | Skip to previous track        | `previous`          | -             |

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

#### 🔍 Enhanced Search & Queue

| Command          | Action                     | Example                                   | Alias |
| ---------------- | -------------------------- | ----------------------------------------- | ----- |
| `search`         | Search music & podcasts    | `search "bohemian rhapsody"`              | -     |
| `search-albums`  | Search albums only         | `search-albums "pink floyd"`              | -     |
| `play`           | Play track/episode         | `play 1` or `play spotify:track:...`      | -     |
| `queue`          | Add to queue or show queue | `queue 2` or `queue` (show current queue) | `q`   |
| `queue clear`    | Clear entire queue         | `queue clear`                             | -     |
| `queue remove`   | Remove track from queue    | `queue remove 3`                          | -     |
| `play-playlist`  | Play playlist by number    | `play-playlist 1` or `play-playlist 1 5`  | -     |
| `play-album`     | Play album by number       | `play-album 1`                            | -     |
| `queue-playlist` | Queue entire playlist      | `queue-playlist 2`                        | -     |
| `queue-album`    | Queue entire album         | `queue-album 1`                           | -     |

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

### 🎮 Interactive Navigation

The CLI features a powerful interactive navigation system that lets you browse and select content using arrow keys and keyboard shortcuts:

#### Entering Interactive Mode

```powershell
# Search and enter interactive mode
PS C:\> search "pink floyd"
🔍 Search Results for "pink floyd":

TRACKS:
1. Comfortably Numb - Pink Floyd (The Wall)
2. Wish You Were Here - Pink Floyd (Wish You Were Here)
3. Another Brick in the Wall - Pink Floyd (The Wall)

PODCAST EPISODES:
4. 🎙️ Pink Floyd Documentary - Music History Podcast
   📝 Deep dive into the legendary band's history...

💡 Press Enter to start interactive mode, or use numbers directly

# Press Enter to enter interactive mode with arrow key navigation
```

#### Interactive Controls

| Key          | Action                | Description                            |
| ------------ | --------------------- | -------------------------------------- |
| `↑` `↓`      | Navigate up/down      | Move through search results            |
| `Enter`      | Play selected item    | Immediately play highlighted item      |
| `Space`      | Add to queue          | Add highlighted item to queue          |
| `p`          | Play as playlist      | Play highlighted playlist              |
| `a`          | Play as album         | Play highlighted album                 |
| `s`          | Save/unsave           | Toggle save status of highlighted item |
| `1-9`        | Jump to number        | Directly select numbered item          |
| `Escape` `q` | Exit interactive mode | Return to normal command line          |

#### Interactive Examples

```powershell
# Browse playlists interactively
PS C:\> playlists
📚 Your Playlists:
1. My Favorites (127 tracks)
2. Workout Mix (45 tracks)
3. Chill Vibes (89 tracks)

# Use arrow keys to navigate, Enter to play, Space to queue

# Browse albums interactively
PS C:\> search-albums "the beatles"
🔍 Album Results for "the beatles":
1. Abbey Road - The Beatles (1969, 17 tracks)
2. Sgt. Pepper's Lonely Hearts Club Band - The Beatles (1967, 13 tracks)

# Use 'a' key to play entire album, or Enter for track selection
```

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

#### Advanced Features with Smart Numbers

```powershell
# Enhanced search with tracks and podcasts
PS C:\> search "pink floyd"
🔍 Search Results for "pink floyd":

TRACKS:
1. Comfortably Numb - Pink Floyd (The Wall)
2. Wish You Were Here - Pink Floyd (Wish You Were Here)
3. Another Brick in the Wall - Pink Floyd (The Wall)

PODCAST EPISODES:
4. 🎙️ Pink Floyd: The Story Behind The Wall - Music History Podcast
   📝 Deep dive into the creation of Pink Floyd's masterpiece...
5. 🎙️ Dark Side of the Moon Analysis - Rock Chronicles
   📝 Track-by-track analysis of the legendary album...

💡 Tip: Use 'play 1' to play track #1, or 'queue 4' to add podcast #4 to queue
💡 Podcast episodes can be saved using 'save-track <number>'

PS C:\> play 1
🎯 Playing track #1 (Comfortably Numb by Pink Floyd)...
▶️ Playing track

# Smart pause/resume toggle
PS C:\> pause
⏸️ Paused playback

PS C:\> pause  # Same command now resumes
▶️ Resumed playback

# Playlist management with numbers
PS C:\> playlists
📚 Your Playlists:
1. My Favorites (127 tracks) - Your favorite songs
2. Workout Mix (45 tracks) - High energy tracks for exercise
3. Chill Vibes (89 tracks) - Relaxing music for focus

💡 Tip: Use 'play-playlist 1' to play playlist #1

PS C:\> play-playlist 2
🎯 Playing playlist #2 (Workout Mix)...
▶️ Playing playlist

# Play specific track from playlist
PS C:\> play-playlist 1 5
🎯 Playing track #5 from playlist #1 (My Favorites)...
▶️ Playing track

# Album search and playback
PS C:\> search-albums "the beatles"
🔍 Album Results for "the beatles":
1. Abbey Road - The Beatles (1969, 17 tracks)
2. Sgt. Pepper's Lonely Hearts Club Band - The Beatles (1967, 13 tracks)
3. Revolver - The Beatles (1966, 14 tracks)

PS C:\> play-album 1
🎯 Playing album #1 (Abbey Road by The Beatles)...
▶️ Playing album

# Enhanced device management
PS C:\> devices
📱 Available Devices:
1. 💻 Desktop (Computer) - Active, Volume: 75%
2. 📱 iPhone (Smartphone) - Volume: 50%
3. 🔊 Living Room Speaker (Speaker) - Volume: 80%
4. 📺 Smart TV (TV) - Volume: 60%

PS C:\> transfer 3
🎯 Transferring to device #3 (Living Room Speaker)...
📱 Playback transferred successfully

# Launch Spotify app
PS C:\> spotify
🚀 Launching Spotify application...
✅ Spotify is now active and ready

# Show current track with new aliases
PS C:\> plays-now
🎵 Come Together
👤 The Beatles
📀 Abbey Road
[████████████████████████████████] 100%
⏱ 4:19 / 4:19 ▶️ Playing on 🔊 Living Room Speaker

PS C:\> pn  # Short alias for plays-now
🎵 Come Together - The Beatles | [████████████████] 100% 4:19/4:19

# Test notifications across environments
PS C:\> notifications test
🧪 Testing notification system...
✅ BurntToast notifications working
✅ Windows.UI.Notifications available as fallback
✅ Console notifications always available
# Toast notification appears: "Spotify CLI Test - Notification system working"

# Enhanced queue management
PS C:\> queue
📋 Current Playback Queue:
1. ▶️ Come Together - The Beatles (Abbey Road) [Currently Playing]
2. Something - The Beatles (Abbey Road)
3. Maxwell's Silver Hammer - The Beatles (Abbey Road)
4. Oh! Darling - The Beatles (Abbey Road)

💡 Use 'queue remove 2' to remove track #2, or 'queue clear' to clear all

PS C:\> queue remove 3
🗑️ Removed track #3 (Maxwell's Silver Hammer) from queue

PS C:\> queue clear
🗑️ Cleared entire playback queue
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

| Alias       | Command             | Description                   |
| ----------- | ------------------- | ----------------------------- |
| `spotify`   | `Start-SpotifyApp`  | Launch Spotify application    |
| `plays-now` | `Show-CurrentTrack` | Show current track (detailed) |
| `music`     | `Show-CurrentTrack` | Alternative to plays-now      |
| `pn`        | `Show-CurrentTrack` | Short form for plays-now      |
| `sp`        | `Show-CurrentTrack` | Legacy compatibility          |
| `vol`       | `volume`            | Volume control                |
| `sh`        | `shuffle`           | Shuffle control               |
| `rep`       | `repeat`            | Repeat control                |
| `tr`        | `transfer`          | Device transfer               |
| `q`         | `queue`             | Add to queue                  |
| `pl`        | `playlists`         | Show playlists                |
| `help`      | `Get-SpotifyHelp`   | Show help                     |

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
├── .kiro/                              # Kiro IDE specifications and documentation
│   └── specs/spotify-advanced-features/
│       ├── requirements.md             # Feature requirements
│       ├── design.md                   # Technical design document
│       └── tasks.md                    # Implementation task list
├── spotifyCLI.ps1                      # Main script (interactive mode)
├── SpotifyModule.psm1                  # PowerShell module for global commands
├── Install-SpotifyCliDependencies.ps1  # Installation script with dependency management
├── Uninstall-SpotifyCli.ps1           # Clean uninstallation script
├── .env                                # Environment variables (create yourself)
├── .gitignore                          # Git ignore rules
└── README.md                           # This comprehensive documentation
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
