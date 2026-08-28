# SpotifyCLI v3.2.4

A full-featured Spotify terminal client for PowerShell. Control playback, search, browse playlists, manage your queue, view synchronized lyrics, track listening statistics, play a music quiz, and look up concert setlists — all from the terminal.

Requires **Spotify Premium** and a **Spotify Developer App** (free to create).

---

## Quick Start (PowerShell Gallery)

### Step 1 — Create a Spotify Developer App

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Click **Create App**, give it any name
3. Add **Redirect URI**: `http://127.0.0.1:8888/callback`
4. Save and copy your **Client ID** and **Client Secret**

### Step 2 — Install and run

```powershell
Install-Module SpotifyCLI -Scope CurrentUser
Start-SpotifyCLI
```

On first run you'll be prompted for your Client ID and Client Secret, then a browser window opens for Spotify login. Tokens are saved automatically — no login needed on future runs.

**Tip:** To skip the prompt, set env vars before calling `Start-SpotifyCLI`:

```powershell
$env:SPOTIFY_CLIENT_ID     = "your_client_id"
$env:SPOTIFY_CLIENT_SECRET = "your_client_secret"
Start-SpotifyCLI
```

Or place a `.env` file in your working directory:

```
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
```

---

## Setup (from source)

```powershell
# Clone the repo, then:
.\Install-SpotifyCLI-Complete.ps1
.\spotifyCLI.ps1
```

To clean up a previous installation:

```powershell
.\Clear-SpotifyCliInstallation.ps1
```

---

## Features

### Playback Control

| Command      | Aliases              | Description                        |
| ------------ | -------------------- | ---------------------------------- |
| `plays-now`  | `pn`, `music`, `sp`  | Show current track                 |
| `play`       |                      | Resume or play item by number      |
| `pause`      |                      | Toggle pause/resume                |
| `next`       |                      | Skip to next track                 |
| `previous`   |                      | Go to previous track               |
| `volume`     | `vol`                | Set volume 0–100                   |
| `volume-low` / `volume-medium` / `volume-high` | | Volume presets        |
| `seek`       |                      | Seek forward/backward (seconds)    |
| `skip-forward` / `skip-back` |        | Jump 15 seconds forward/back       |
| `shuffle`    | `sh`                 | Toggle or set shuffle mode         |
| `repeat`     | `rep`                | Set repeat (off/track/context)     |
| `replay`     |                      | Restart current track              |

### Search & Discovery

| Command        | Description                          | Example                        |
| -------------- | ------------------------------------ | ------------------------------ |
| `search`       | Search tracks, albums, podcasts      | `search "bohemian rhapsody"`   |
| `search-albums`| Search albums                        | `search-albums "pink floyd"`   |

After searching, results are numbered. Use `play 1`, `queue 2`, etc. to act on them. Navigation also supports arrow keys in interactive mode.

### Playlists & Library

| Command          | Aliases | Description                   |
| ---------------- | ------- | ----------------------------- |
| `playlists`      | `pl`    | List your playlists           |
| `play-playlist`  |         | Play playlist by number       |
| `queue-playlist` | `pq`    | Add playlist to queue         |
| `liked`          |         | Show liked songs              |
| `recent`         |         | Show recently played          |
| `save-track`     |         | Save current track to library |
| `unsave-track`   |         | Remove current track          |

### Queue & Albums

| Command       | Aliases | Description              |
| ------------- | ------- | ------------------------ |
| `queue`       | `q`     | Show queue or add by number |
| `play-queue`  |         | Play a numbered queue item |
| `play-album`  |         | Play album by number     |
| `queue-album` |         | Add album to queue       |

### Device Management

| Command    | Aliases | Description               |
| ---------- | ------- | ------------------------- |
| `devices`  |         | List available devices    |
| `transfer` | `tr`    | Switch playback to device |

### Interactive Navigation

Arrow key navigation is available after any list command (`search`, `playlists`, `queue`):

- **↑↓** — navigate items
- **Enter** — play selected
- **Space** — queue selected
- **1–9** — jump to numbered item
- **Esc** — exit

### Live Display

| Command                    | Aliases       | Description                          |
| -------------------------- | ------------- | ------------------------------------ |
| `Start-SpotifyLiveDisplay` | `live`        | Real-time now-playing (progress bar) |
| `Stop-SpotifyLiveDisplay`  |               | Stop live display                    |
| `Start-SpotifySidecar`     | `live-music`  | Split-pane display in Windows Terminal |

Modes: `detailed`, `compact`, `minimal`

```powershell
Start-SpotifyLiveDisplay -Mode compact
```

### Lyrics

| Command              | Aliases              | Description                            |
| -------------------- | -------------------- | -------------------------------------- |
| `Get-SpotifyLyrics`  | `slw`, `ShowLyrics`  | Synchronized lyrics in a floating window |

Lyrics are sourced from LRCLIB (free, no key) with automatic fallback to Genius and Musixmatch. The window color-codes lines: dark gray = sung, bright green = current, white = upcoming.

```powershell
slw   # Open lyrics window for current track
Get-SpotifyLyrics -Artist "Queen" -Track "Bohemian Rhapsody"
```

### Now Playing Window

```powershell
ss        # Open floating playback window (alias: ShowSpotify)
```

Always-on-top WinForms window with track info, progress bar, and playback controls (Prev / Play-Pause / Next / Shuffle / Repeat).

### Statistics & Peak Dashboard

| Command                          | Aliases | Description                        |
| -------------------------------- | ------- | ---------------------------------- |
| `Get-SpotifyListeningStatistics` | `stats` | Listening analytics in terminal    |
| `Show-PeakDashboard`             | `peak`  | WinForms analytics dashboard       |

```powershell
stats
Get-SpotifyListeningStatistics -Period week
peak
```

### Music Quiz

Test your music knowledge — multiple-choice questions drawn from your listening history.

```powershell
quiz       # 5 rounds (default)
quiz 10    # Custom round count (1–20)
```

Scoring: exact title = 20 pts, exact artist = 10 pts, partial match = 5 pts. Highscores saved automatically.

### Setlist Lookup

Fetch a concert setlist and build a Spotify playlist from it.

```powershell
setlist "Radiohead"
```

### Favorites

```powershell
fav        # Mark current track as favorite
```

### Utilities

| Command                   | Aliases                | Description                |
| ------------------------- | ---------------------- | -------------------------- |
| `Get-SpotifyHelp`         | `help`, `spotify-help` | Show all commands          |
| `Show-AllSpotifyCommands` | `commands`             | Compact command list       |
| `Start-SpotifyApp`        | `spotify`              | Launch Spotify desktop app |
| `copy-track-link`         |                        | Copy current track URL     |
| `export-now-playing`      |                        | Export track info to file  |
| `notifications`           |                        | Toggle terminal notifications |
| `Get-SpotifyConfig`       |                        | View current settings      |
| `Set-SpotifyConfig`       |                        | Update a setting           |

---

## Requirements

- PowerShell 5.1+ (Windows) or PowerShell 7+
- Spotify Premium account
- Spotify Developer App (Client ID + Secret)

---

## Troubleshooting

```powershell
Test-SpotifyAuth                     # Check token status
Get-SpotifyCliTroubleshootingGuide   # Guided troubleshooting
Repair-SpotifyCliInstallation        # Attempt auto-repair
```

**Module not loading after install:**
```powershell
. $PROFILE   # Reload profile
```

**Functions not recognized:**
```powershell
Import-Module SpotifyCLI -Force
```
