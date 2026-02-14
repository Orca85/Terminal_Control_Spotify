# Feature Plan: Quiz, Peak Dashboard & Setlist

## 1. Music Quiz (`quiz`)

### Koncept

Spela 5 sekunder av en random liked song — gissa låtnamn eller artist. Poängsystem med highscore.

### Spotify API-anrop

```
GET /me/tracks?limit=50&offset={random}    # Hämta liked songs
PUT /me/player/play                         # Spela specifik låt från random position
PUT /me/player/pause                        # Pausa efter 5 sek
GET /me/player                              # Kolla att uppspelning startade
```

### Flöde

```
> quiz
🎵 Music Quiz - 5 rounds!

Round 1/5 - Playing 5 seconds...
♫ ............

Who sings this? (or song name):
> tame impala
✅ Correct! +10 points (Artist: Tame Impala - "The Less I Know The Better")

Round 2/5 - Playing 5 seconds...
♫ ............

Who sings this? (or song name):
> wrong answer
❌ It was: Daft Punk - "Get Lucky"

...

🏆 Final Score: 30/50
🥇 New highscore! (Previous: 20)
```

### Implementationsplan

**Ny fil:** `modules/Core/QuizCommands.psm1`

**Funktioner:**

- `Start-MusicQuiz` — huvudfunktion
  - Parametrar: `-Rounds 5` (default 5), `-Duration 5` (sekunder, default 5)
- `Get-RandomLikedTracks` — hämta N random liked songs
  1. `GET /me/tracks?limit=1&offset=0` → hämta totalt antal
  2. Generera N random offsets inom range
  3. Hämta varje track med `GET /me/tracks?limit=1&offset={random}`
- `Start-QuizRound` — spela snippet, vänta på svar
  1. Beräkna random `position_ms` (mellan 30s och duration-30s, undvik intro/outro)
  2. `PUT /me/player/play` med `uris` + `position_ms`
  3. `Start-Sleep -Seconds $Duration`
  4. `PUT /me/player/pause`
  5. `Read-Host` för svaret
  6. Fuzzy-match mot artist och tracknamn (case-insensitive, `contains`-check)
- `Save-QuizHighscore` / `Get-QuizHighscore`
  - Spara i `$env:APPDATA\SpotifyCLI\quiz_highscore.json`

**Poängsystem:**

- Exakt låtnamn: 20 poäng
- Exakt artist: 10 poäng
- Partiell match (contains): 5 poäng
- Fel: 0 poäng

**Registrering:**

- `spotifyCLI.ps1` dispatch: `"quiz" { Start-MusicQuiz $args }`
- `SpotifyCommands.psd1`: lägg till i `FunctionsToExport` och `NestedModules`

**Beroenden:** Inga nya — använder befintliga `Invoke-SpotifyApi`, `Read-Host`

---

## 2. Peak Dashboard (`peak`)

### Koncept

WinForm-fönster som visar realtids-audiodata för nuvarande låt: BPM, tonart, energy, danceability. Uppdateras vid låtbyte.

### Spotify API-anrop

```
GET /me/player                              # Nuvarande låt + is_playing
GET /audio-features/{track_id}              # BPM, key, energy, danceability, etc.
GET /me/player/recently-played?limit=10     # Historik för mini-graf
```

### UI-layout

```
┌─────────────────────────────────────┐
│  Peak - Audio Dashboard             │
├─────────────────────────────────────┤
│  🎵 Song Name                       │
│  👤 Artist Name                     │
│                                     │
│  BPM     ████████████░░░  128       │
│  Energy  ██████████░░░░░  0.72      │
│  Dance   ████████░░░░░░░  0.58      │
│  Valence ██████░░░░░░░░░  0.41      │
│  Loud    ███████████░░░░  -5.2 dB   │
│                                     │
│  Key: C# minor                      │
│  Time: 4/4                          │
│                                     │
│  ── Recent tracks ──                │
│  Energy: ▁▃▅▇▅▃▆▇▅▃               │
│  BPM:    120 → 128 → 95 → 140     │
└─────────────────────────────────────┘
```

### Implementationsplan

**Ny fil:** `modules/UI/PeakDashboard.psm1`

**Funktioner:**

- `Show-PeakDashboard` — wrapper som startar bakgrundsprocess
  - Samma mönster som `Show-LyricsForm`: here-string → temp .ps1 → `Start-Process pwsh`

**Bakgrundsskript-innehåll:**

1. **Form-setup** (400×500, dark theme `#1A1A1A`, TopMost)
2. **Header-labels** — låtnamn + artist (turkos `#4ECDC4`)
3. **ProgressBar-kontroller** för varje metric:
   - 6 st `ProgressBar` + `Label` par
   - BPM (visa 60-200 range, normalisera till 0-100%)
   - Energy (0-1 → 0-100%)
   - Danceability (0-1 → 0-100%)
   - Valence (0-1 → 0-100%, glad/ledsen)
   - Loudness (-60 till 0 dB → 0-100%)
   - Acousticness (0-1 → 0-100%)
4. **Key/Time-label** — tonart + taktart
5. **Mini-graf panel** — senaste 10 låtars energy som `Label` med block-chars (`▁▃▅▇`)
6. **Timer** (interval 2000ms):
   - `GET /me/player` → kolla is_playing + track URI
   - Vid låtbyte: `GET /audio-features/{id}` → uppdatera alla bars
   - Spara energy/bpm i lista för mini-graf
   - Uppdatera mini-graf panel

**Tonart-mappning:**

```powershell
$keyNames = @('C','C#','D','D#','E','F','F#','G','G#','A','A#','B')
$modeNames = @('minor','major')
# audio_features.key = 0-11, audio_features.mode = 0-1
$keyText = "$($keyNames[$key]) $($modeNames[$mode])"
```

**ProgressBar-styling:**

```powershell
$bar = New-Object System.Windows.Forms.ProgressBar
$bar.Style = 'Continuous'
$bar.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#4ECDC4')
$bar.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#2D2D2D')
```

**Registrering:**

- `spotifyCLI.ps1` dispatch: `"peak" { Show-PeakDashboard }`
- `SpotifyCommands.psd1`: lägg till i exports

**Beroenden:** `Invoke-SpotifyApi`, WinForms assemblies

---

## 3. Concert Setlist (`setlist`)

### Koncept

Hämta en artists senaste konsert-setlist via setlist.fm API. Sök matchande låtar på Spotify och skapa en spellista.

### API-anrop

```
# Setlist.fm (extern)
GET https://api.setlist.fm/rest/1.0/search/setlists?artistName={name}&p=1
Headers: x-api-key: {SETLISTFM_API_KEY}, Accept: application/json

# Spotify
GET /search?q=track:{song}+artist:{artist}&type=track&limit=1   # Matcha varje låt
POST /users/{user_id}/playlists                                   # Skapa spellista
POST /playlists/{playlist_id}/tracks                              # Lägg till låtar
GET /me                                                           # Hämta user_id
```

### Flöde

```
> setlist Tame Impala

🎤 Searching setlist.fm for Tame Impala...

Found: Tame Impala @ Coachella, 2024-04-14
  1. One More Year
  2. Borderline
  3. Let It Happen
  ...
  14. The Less I Know The Better
  15. New Person, Same Old Mistakes

Create Spotify playlist from this setlist? (y/n): y
🔍 Matching songs on Spotify...
  ✅ One More Year (matched)
  ✅ Borderline (matched)
  ❌ Jam Session (no match - live only)
  ...

📝 Creating playlist "Tame Impala @ Coachella 2024-04-14"...
✅ Playlist created with 13/15 tracks!
▶️  Play now? (y/n): y
```

### Implementationsplan

**Ny fil:** `modules/Core/SetlistCommands.psm1`

**Funktioner:**

- `Invoke-SetlistCommand` — huvud-dispatcher
  - Parser: `setlist <artist>` eller `setlist <artist> -create`
- `Search-Setlist` — sök på setlist.fm
  1. Kräver `$env:SETLISTFM_API_KEY` (gratis på setlist.fm)
  2. `Invoke-RestMethod` till setlist.fm API
  3. Returnera senaste setlisten med venue, datum, låtlista
  4. Om ingen API-key: visa instruktioner för att skaffa en
- `Show-SetlistResults` — visa numrerad lista med setlists
  1. Visa senaste 5 konserterna
  2. Användaren väljer nummer (samma UX som `pl`)
  3. Visa låtlista för vald konsert
- `New-SetlistPlaylist` — skapa Spotify-spellista
  1. `GET /me` → hämta user_id
  2. Loop genom setlist-låtar:
     - `GET /search?q=track:{song}+artist:{artist}&type=track&limit=1`
     - Samla matchade URIs, logga missar
  3. `POST /users/{user_id}/playlists` med namn + beskrivning
  4. `POST /playlists/{id}/tracks` med alla URIs (max 100 per anrop)
  5. Erbjud att spela spellistan direkt

**Setlist.fm response-format:**

```json
{
  "setlist": [{
    "artist": { "name": "Tame Impala" },
    "venue": { "name": "Coachella", "city": { "name": "Indio" } },
    "eventDate": "14-04-2024",
    "sets": {
      "set": [{
        "song": [
          { "name": "One More Year" },
          { "name": "Borderline" }
        ]
      }]
    }
  }]
}
```

**Registrering:**

- `spotifyCLI.ps1` dispatch: `"setlist" { Invoke-SetlistCommand $args }`
- `SpotifyCommands.psd1`: lägg till i exports
- Env-variabel: `$env:SETLISTFM_API_KEY`

**Beroenden:** `Invoke-SpotifyApi`, `Invoke-RestMethod` (för setlist.fm), `Read-Host`

---

## Gemensamma ändringar

### spotifyCLI.ps1 — Nya dispatch-entries

```powershell
"quiz"    { Start-MusicQuiz $args }
"/quiz"   { Start-MusicQuiz $args }
"peak"    { Show-PeakDashboard }
"/peak"   { Show-PeakDashboard }
"setlist"  { Invoke-SetlistCommand $args }
"/setlist" { Invoke-SetlistCommand $args }
```

### SpotifyCommands.psd1 — Uppdateringar

```powershell
NestedModules = @(
    # ... befintliga ...
    'modules\Core\QuizCommands.psm1',
    'modules\UI\PeakDashboard.psm1',
    'modules\Core\SetlistCommands.psm1'
)

FunctionsToExport = @(
    # ... befintliga ...
    'Start-MusicQuiz',
    'Show-PeakDashboard',
    'Invoke-SetlistCommand'
)
```

## Prioriteringsordning

1. **Quiz** — enklast, inga externa API:er, kul att testa direkt
2. **Peak Dashboard** — medel, samma WinForm-mönster som lyrics
3. **Setlist** — mest komplex, kräver extern API-nyckel
