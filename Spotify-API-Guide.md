# 🎵 Spotify API Konfigurationsguide

En komplett guide för att konfigurera Spotify API för SpotifyCLI-projektet.

## 📋 Innehållsförteckning

1. [Förutsättningar](#förutsättningar)
2. [Skapa Spotify Developer App](#skapa-spotify-developer-app)
3. [Konfigurera API-nycklar](#konfigurera-api-nycklar)
4. [Testa konfigurationen](#testa-konfigurationen)
5. [Felsökning](#felsökning)
6. [Säkerhet och bästa praxis](#säkerhet-och-bästa-praxis)

---

## 🎯 Förutsättningar

### Spotify-konto

- **Spotify Premium-konto** (rekommenderat för full funktionalitet)
- Spotify Free fungerar för vissa funktioner (visa nuvarande låt, bläddra i bibliotek)

### Tekniska krav

- PowerShell 5.1 eller senare
- Internetanslutning
- Webbläsare för autentisering

---

## 🚀 Skapa Spotify Developer App

### Steg 1: Gå till Spotify Developer Dashboard

1. Öppna [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Logga in med ditt Spotify-konto
3. Klicka på **"Create app"**

### Steg 2: Fyll i appinformation

```
App name: SpotifyCLI (eller valfritt namn)
App description: PowerShell CLI för Spotify-kontroll
Website: http://localhost (eller din webbsida)
Redirect URI: http://127.0.0.1:8888/callback
```

⚠️ **VIKTIGT**: Redirect URI måste vara exakt `http://127.0.0.1:8888/callback`

### Steg 3: Välj API-typ

- Markera **"Web API"**
- Acceptera Spotify's användarvillkor
- Klicka **"Save"**

### Steg 4: Hämta API-nycklar

1. Klicka på din nya app i dashboard
2. Klicka **"Settings"**
3. Kopiera **Client ID** och **Client Secret**

---

## 🔑 Konfigurera API-nycklar

### Metod 1: Använd .env-filen (Rekommenderat)

1. **Öppna `.env`-filen** i projektmappen:

```powershell
notepad .env
```

2. **Ersätt placeholder-värdena** med dina riktiga API-nycklar:

```env
SPOTIFY_CLIENT_ID=din_client_id_här
SPOTIFY_CLIENT_SECRET=din_client_secret_här
```

3. **Spara filen** och stäng editorn

### Metod 2: Miljövariabler (Alternativ)

```powershell
# Sätt miljövariabler för aktuell session
$env:SPOTIFY_CLIENT_ID = "din_client_id_här"
$env:SPOTIFY_CLIENT_SECRET = "din_client_secret_här"

# Eller sätt permanent för användaren
[System.Environment]::SetEnvironmentVariable("SPOTIFY_CLIENT_ID", "din_client_id_här", "User")
[System.Environment]::SetEnvironmentVariable("SPOTIFY_CLIENT_SECRET", "din_client_secret_här", "User")
```

---

## ✅ Testa konfigurationen

### Snabbtest

```powershell
# Kör CLI:t för första gången
.\spotifyCLI.ps1

# Om allt fungerar kommer du att:
# 1. Se en webbläsare öppnas för autentisering
# 2. Logga in på Spotify
# 3. Auktorisera appen
# 4. Återvända till PowerShell med framgångsmeddelande
```

### Detaljerat test

```powershell
# Kör testskriptet
.\tests\Test-SpotifyAuthentication.ps1 -Detailed

# Detta testar:
# - .env-fil laddning
# - API-nyckel format
# - Autentiseringsflöde
# - Token-hantering
```

### Manuell verifiering

```powershell
# Kontrollera att miljövariabler laddas korrekt
Get-Content .env | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}

# Visa laddade värden (första 8 tecknen för säkerhet)
Write-Host "Client ID: $($env:SPOTIFY_CLIENT_ID.Substring(0,8))..."
Write-Host "Client Secret: $($env:SPOTIFY_CLIENT_SECRET.Substring(0,8))..."
```

---

## 🔧 Felsökning

### Problem: "Client ID not configured"

**Orsak**: API-nycklar inte korrekt laddade

**Lösning**:

```powershell
# 1. Kontrollera att .env-filen finns
Test-Path .env

# 2. Kontrollera innehållet
Get-Content .env

# 3. Kontrollera format (inga extra mellanslag)
# Korrekt format:
# SPOTIFY_CLIENT_ID=abc123...
# SPOTIFY_CLIENT_SECRET=def456...
```

### Problem: "Authentication failed"

**Möjliga orsaker och lösningar**:

1. **Felaktig Redirect URI**

   ```
   Lösning: Kontrollera att Redirect URI i Spotify Dashboard är:
   http://127.0.0.1:8888/callback
   ```

2. **Felaktiga API-nycklar**

   ```powershell
   # Verifiera att nycklarna är 32 tecken långa hex-strängar
   $env:SPOTIFY_CLIENT_ID -match '^[a-f0-9]{32}$'
   $env:SPOTIFY_CLIENT_SECRET -match '^[a-f0-9]{32}$'
   ```

3. **Port 8888 blockerad**
   ```powershell
   # Kör PowerShell som administratör
   # Eller ändra port i konfigurationen
   ```

### Problem: "No active device"

**Orsak**: Ingen Spotify-enhet är aktiv

**Lösning**:

1. Öppna Spotify på någon enhet (telefon, dator, högtalare)
2. Spela upp en låt
3. Använd `/devices` för att se tillgängliga enheter
4. Använd `/transfer <device_id>` om nödvändigt

### Problem: "Premium required"

**Orsak**: Vissa funktioner kräver Spotify Premium

**Begränsningar med Spotify Free**:

- ❌ Kontroller (play/pause/next/previous)
- ❌ Volymkontroll
- ❌ Seek i låtar
- ❌ Enhetsöverföring
- ✅ Visa nuvarande låt
- ✅ Bläddra i bibliotek
- ✅ Sök musik

---

## 🔒 Säkerhet och bästa praxis

### Skydda dina API-nycklar

1. **Lägg ALDRIG till .env i version control**

   ```gitignore
   # .gitignore
   .env
   tokens.json
   ```

2. **Använd miljövariabler i produktion**

   ```powershell
   # För servermiljöer
   [System.Environment]::SetEnvironmentVariable("SPOTIFY_CLIENT_ID", "...", "Machine")
   ```

3. **Rotera nycklar regelbundet**
   - Gå till Spotify Developer Dashboard
   - Generera nya Client Secret
   - Uppdatera .env-filen

### Begränsa app-behörigheter

**Nuvarande scopes** (i `spotifyCLI.ps1`):

```powershell
$Scopes = @(
    "user-read-playback-state",      # Läs uppspelningsstatus
    "user-modify-playback-state",    # Kontrollera uppspelning
    "user-read-currently-playing",   # Läs nuvarande låt
    "user-read-private",             # Läs användarinfo
    "playlist-read-private",         # Läs privata spellistor
    "user-library-read",             # Läs bibliotek
    "user-library-modify",           # Modifiera bibliotek
    "user-read-recently-played",     # Läs senast spelade
    "user-top-read"                  # Läs topplistor
)
```

**Ta bort scopes du inte behöver** för att minimera behörigheter.

---

## 📊 Avancerad konfiguration

### Anpassa cache-inställningar

```powershell
# I modules/Core/ApiClientManager.psm1
$defaultConfig = @{
    MaxRequestsPerMinute = 60        # API rate limit
    CacheDurationMs = 60000          # 1 minut cache
    MaxCacheSize = 1000              # Max cache-poster
    PersistentCacheEnabled = $true   # Spara cache till disk
}
```

### Konfigurera error handling

```powershell
# Aktivera detaljerad loggning
Set-ErrorHandlerLogging -Enabled $true -Level "Debug"

# Registrera cache-källor för offline-läge
Register-CachedDataSource -SourceType "ApiClient" -DataSource $apiClient
```

### Anpassa display-inställningar

```powershell
# Kompakt läge för mindre terminaler
$config = Get-SpotifyConfig
$config.CompactMode = $true
Set-SpotifyConfig -Config $config

# Anpassa färger
$config.Colors.Playing = "Green"
$config.Colors.Track = "Cyan"
Set-SpotifyConfig -Config $config
```

---

## 🆘 Support och hjälp

### Användbara kommandon för felsökning

```powershell
# Visa detaljerad konfiguration
.\tests\Test-SpotifyAuthentication.ps1 -Detailed

# Testa grundläggande funktionalitet
.\tests\Test-ScriptModeBasic.ps1

# Komplett validering
.\tests\Test-ComprehensiveValidation.ps1

# Visa API-statistik
Get-SpotifyApiClientStats -Client $apiClient
```

### Loggar och diagnostik

```powershell
# Aktivera loggning
$config = Get-SpotifyConfig
$config.LoggingEnabled = $true
Set-SpotifyConfig -Config $config

# Visa loggfiler
Get-Content "$env:APPDATA\SpotifyCLI\spotify-cli.log" -Tail 50
```

### Vanliga frågor

**Q: Kan jag använda flera Spotify-konton?**
A: Ja, men du behöver autentisera om för varje konto. Tokens sparas per användare.

**Q: Fungerar det med Spotify Connect-enheter?**
A: Ja, alla Spotify Connect-kompatibla enheter stöds (högtalare, TV, etc.).

**Q: Kan jag automatisera utan användarinteraktion?**
A: Nej, Spotify kräver användarautentisering för säkerhet. Tokens kan dock återanvändas.

---

## 📝 Slutsats

Med denna guide bör du kunna:

- ✅ Skapa en Spotify Developer App
- ✅ Konfigurera API-nycklar säkert
- ✅ Testa och verifiera konfigurationen
- ✅ Felsöka vanliga problem
- ✅ Implementera säkerhetsrutiner

**Nästa steg**: Kör `.\spotifyCLI.ps1` och njut av din Spotify CLI! 🎵

---

_Skapad för SpotifyCLI-projektet | Uppdaterad: $(Get-Date -Format 'yyyy-MM-dd')_
