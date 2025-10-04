# Spotify CLI for PowerShell

A simple command-line interface for controlling Spotify playback directly from PowerShell.  
This script uses the **Spotify Web API** to authenticate with your account and allows you to run commands like `spotify`, `next`, `pause`, and `play` to control playback and display track information.

---

## ✨ Features
- Authenticate with your Spotify account via OAuth2
- Show the currently playing track (title, artist, album, progress)
- Control playback: play, pause, skip to next/previous track
- **Global commands** - use commands anywhere in PowerShell
- Works on Windows PowerShell 5.1 and PowerShell 7+

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

| Command     | Action                                |
|-------------|---------------------------------------|
| `spotify`   | Show currently playing track          |
| `next`      | Skip to next track                    |
| `previous`  | Skip to previous track                |
| `pause`     | Pause playback                        |
| `play`      | Resume playback                       |

### Script Mode
If you run the script directly, you'll get a prompt (`>`):

| Command     | Action                                |
|-------------|---------------------------------------|
| `/spotify`  | Show currently playing track          |
| `/next`     | Skip to next track                    |
| `/pause`    | Pause playback                        |
| `/play`     | Resume playback                       |
| `/quit`     | Exit the script                       |

### Examples
```powershell
PS C:\> spotify
🎵 Song Title
👤 Artist Name
📀 Album Name
⏱ 1:23 / 3:45 (playing)

PS C:\> next
⏭️ Next track.

PS C:\> pause
⏸️ Paused.
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
The script requests the following Spotify API scopes:
- `user-read-playback-state`
- `user-modify-playback-state`
- `user-read-currently-playing`

These are required to read playback information and control playback.

---

## 📝 Notes
- Tokens are stored locally in `%APPDATA%\SpotifyCLI\tokens.json`
- You must have an active Spotify Connect device (desktop app, mobile app, or web player) for playback control to work
- The first time you run the script, a browser will open for authentication
- Tokens are automatically refreshed when they expire

---

## 🔧 Troubleshooting
- **"No playback found"**: Start Spotify on a device and play music
- **"Could not fetch current track"**: Make sure you have Spotify Premium
- **Authentication errors**: Check that Client ID/Secret are correct and Redirect URI matches

---

## 📜 License
This project is provided as-is for educational and personal use.