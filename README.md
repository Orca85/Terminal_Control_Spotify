Here’s a polished **README.md** you can drop straight into your project folder. It explains what the script does, how to set it up, and how to use it:

```markdown
# Spotify CLI for PowerShell

A simple command-line interface for controlling Spotify playback directly from PowerShell.  
This script uses the **Spotify Web API** to authenticate with your account and allows you to run commands like `/spotify`, `/next`, `/pause`, and `/play` to control playback and display track information.

---

## ✨ Features
- Authenticate with your Spotify account via OAuth2
- Show the currently playing track (title, artist, album, progress)
- Control playback: play, pause, skip to next track
- Simple command loop with slash-style commands
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
   - **Redirect URI**: must match the script. Example:  
     ```
     http://127.0.0.1:8400/callback
     ```
4. Save the app and copy your **Client ID** and **Client Secret**.

### 2. Configure the Script
Open the script file (`SpotifyCLI.ps1`) and update these variables:
```powershell
$ClientId     = "<YOUR_CLIENT_ID>"
$ClientSecret = "<YOUR_CLIENT_SECRET>"
$RedirectUri  = "http://127.0.0.1:8400/callback"
```

### 3. Run the Script
```powershell
.\SpotifyCLI.ps1
```

If you see an error about execution policy, run:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

---

## 🎮 Usage

Once running, you’ll see a prompt (`>`). Type commands like:

| Command     | Action                                |
|-------------|---------------------------------------|
| `/spotify`  | Show currently playing track info      |
| `/next`     | Skip to the next track                 |
| `/pause`    | Pause playback                         |
| `/play`     | Resume playback                        |
| `/quit`     | Exit the script                        |

Example:
```
> /spotify
🎵 Song Title
👤 Artist Name
📀 Album Name
⏱ 1:23 / 3:45 (playing)
```

---

## 🔐 Scopes Used
The script requests the following Spotify API scopes:
- `user-read-playback-state`
- `user-modify-playback-state`
- `user-read-currently-playing`

These are required to read playback info and control playback.

---

## 📝 Notes
- Tokens are stored locally in `%APPDATA%\SpotifyCLI\tokens.json`.
- You must have an active Spotify Connect device (desktop app, mobile app, or web player) for playback control to work.
- You can extend the script by adding more scopes (e.g. playlist management, library access).

---

## 📜 License
This project is provided as-is for educational and personal use.
```

---

Would you like me to also add a **“Future Enhancements”** section in the README (e.g. playlist browsing, volume control, recently played), so it looks more like a real open-source project roadmap?
