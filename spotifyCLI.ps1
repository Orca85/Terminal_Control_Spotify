<# 
Spotify CLI GUI-lite för PowerShell
- Autentiserar via Spotify Authorization Code Flow
- Lagrar och uppdaterar access/refresh tokens lokalt
- Kommandon: /spotify (nu spelas), /next, /pause, /play, /quit
- Kräver: Spotify Developer App (Client ID/Secret), Premium-konto, aktiv Spotify-enhet via Spotify Connect
#>

#region Konfiguration
# Fyll i dina uppgifter från Spotify Developer Dashboard
$ClientId     = "REMOVED"
$ClientSecret = "REMOVED"

# Redirect URI måste exakt matcha den du lagt till i appens inställningar
$RedirectUri  = "http://127.0.0.1:8888/callback"

# Nödvändiga scopes för uppspelning och status
$Scopes = @(
    "user-read-playback-state",
    "user-modify-playback-state",
    "user-read-currently-playing"
) -join " "

# Lagring av tokens
$AppDataDir   = Join-Path $env:APPDATA "SpotifyCLI"
$TokenFile    = Join-Path $AppDataDir "tokens.json"

# Spotify API-basar
$AuthEndpoint = "https://accounts.spotify.com/authorize"
$TokenEndpoint= "https://accounts.spotify.com/api/token"
$ApiBase      = "https://api.spotify.com/v1"
#endregion Konfiguration

#region Hjälpfunktioner
function Ensure-TokenStore {
    if (-not (Test-Path $AppDataDir)) { New-Item -ItemType Directory -Path $AppDataDir | Out-Null }
    if (-not (Test-Path $TokenFile)) { '{}' | Set-Content -Path $TokenFile -Encoding UTF8 }
}

function Read-Tokens {
    Ensure-TokenStore
    try {
        $json = Get-Content -Path $TokenFile -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($json)) { return @{} }
        return ($json | ConvertFrom-Json)
    } catch { return @{} }
}

function Save-Tokens($Tokens) {
    Ensure-TokenStore
    ($Tokens | ConvertTo-Json -Depth 5) | Set-Content -Path $TokenFile -Encoding UTF8
}

function New-CodeVerifierAndChallenge {
    # PKCE (valfritt men bra), här använder vi enkel Authorization Code med client secret,
    # så vi hoppar PKCE för enkelhet.
    return $null
}

function Start-SpotifyAuth {
    Write-Host "Startar autentisering mot Spotify..."
    # Starta en lokal HTTP-listener för att få 'code'
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add(($RedirectUri.TrimEnd('/') + "/"))
    try {
        $listener.Start()
    } catch {
        Write-Warning "Kunde inte starta lokal listener på $RedirectUri. Kör PowerShell med rättigheter och säkerställ att URI är korrekt."
        return $null
    }

    $state = [Guid]::NewGuid().ToString()
    $authUrl = "$AuthEndpoint?response_type=code&client_id=$ClientId&redirect_uri=$([System.Uri]::EscapeDataString($RedirectUri))&scope=$([System.Uri]::EscapeDataString($Scopes))&state=$state"

    Start-Process $authUrl | Out-Null
    Write-Host "Öppnade webbläsaren. Logga in och godkänn appen..."

    # Vänta på callback
    $context = $listener.GetContext()
    $request = $context.Request
    $response= $context.Response

    $query = $request.Url.Query
    $params = [System.Web.HttpUtility]::ParseQueryString($query)
    $code  = $params["code"]
    $retState = $params["state"]
    $error = $params["error"]

    $html = "<html><body style='font-family:sans-serif'><h2>Klart!</h2><p>Du kan stänga denna flik och gå tillbaka till PowerShell.</p></body></html>"
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer,0,$buffer.Length)
    $response.OutputStream.Close()
    $listener.Stop()

    if ($error) { 
        Write-Error "Spotify auth fel: $error"
        return $null
    }
    if ($retState -ne $state) {
        Write-Error "Ogiltig state-mismatch."
        return $null
    }
    if (-not $code) {
        Write-Error "Ingen auth code mottagen."
        return $null
    }

    # Byt code mot tokens
    $body = @{
        grant_type   = "authorization_code"
        code         = $code
        redirect_uri = $RedirectUri
        client_id    = $ClientId
        client_secret= $ClientSecret
    }

    $tokenResp = Invoke-RestMethod -Method Post -Uri $TokenEndpoint -Body $body
    $tokens = [ordered]@{
        access_token  = $tokenResp.access_token
        token_type    = $tokenResp.token_type
        expires_in    = $tokenResp.expires_in
        refresh_token = $tokenResp.refresh_token
        obtained_at   = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    }
    Save-Tokens $tokens
    Write-Host "Autentisering slutförd."
    return $tokens
}

function Get-SpotifyAccessToken {
    $tokens = Read-Tokens
    if (-not $tokens.access_token) {
        $tokens = Start-SpotifyAuth
        return $tokens.access_token
    }

    $obtained = [long]$tokens.obtained_at
    $expiresIn= [int]$tokens.expires_in
    $age = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $obtained
    if ($age -ge ($expiresIn - 60)) {
        # Förnya med refresh token
        if (-not $tokens.refresh_token) {
            $tokens = Start-SpotifyAuth
            return $tokens.access_token
        }
        $body = @{
            grant_type    = "refresh_token"
            refresh_token = $tokens.refresh_token
            client_id     = $ClientId
            client_secret = $ClientSecret
        }
        try {
            $tokenResp = Invoke-RestMethod -Method Post -Uri $TokenEndpoint -Body $body
            $tokens.access_token = $tokenResp.access_token
            if ($tokenResp.refresh_token) { $tokens.refresh_token = $tokenResp.refresh_token }
            $tokens.expires_in = $tokenResp.expires_in
            $tokens.obtained_at= [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            Save-Tokens $tokens
        } catch {
            Write-Warning "Kunde inte uppdatera token, försöker ny auth..."
            $tokens = Start-SpotifyAuth
        }
    }
    return $tokens.access_token
}

function Invoke-SpotifyApi {
    param(
        [Parameter(Mandatory)][ValidateSet('GET','POST','PUT','DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path, # t.ex. /me/player/currently-playing
        [hashtable]$Query,
        $Body
    )
    $access = Get-SpotifyAccessToken
    $uri = $ApiBase + $Path
    if ($Query) {
        $q = ($Query.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, [System.Uri]::EscapeDataString([string]$_.Value) }) -join "&"
        $uri = "$uri?$q"
    }
    $headers = @{ Authorization = "Bearer $access" }
    if ($Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 10)
    } else {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
    }
}

function Format-Time {
    param([int]$ms)
    $totalSec = [int][Math]::Round($ms / 1000.0)
    $m = [int]($totalSec / 60)
    $s = $totalSec % 60
    "{0}:{1:D2}" -f $m,$s
}
#endregion Hjälpfunktioner

#region Spotify-kommandon
function Show-CurrentTrack {
    try {
        $resp = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
    } catch {
        Write-Warning "Kunde inte hämta aktuell låt. Är någon enhet aktiv via Spotify Connect?"
        return
    }
    if (-not $resp) {
        Write-Host "Ingen uppspelning hittades."
        return
    }

    $isPlaying = $resp.is_playing
    $progress  = $resp.progress_ms
    $item      = $resp.item
    if (-not $item) { Write-Host "Ingen låtinfo tillgänglig."; return }

    $name   = $item.name
    $artists= ($item.artists | ForEach-Object { $_.name }) -join ", "
    $album  = $item.album.name
    $dur    = $item.duration_ms

    Write-Host "🎵 $name"
    Write-Host "👤 $artists"
    Write-Host "📀 $album"
    Write-Host ("⏱ {0} / {1} {2}" -f (Format-Time $progress),(Format-Time $dur), ($(if($isPlaying){"(spelar)"}else{"(paus)"})))
}

function Next-Track {
    try {
        Invoke-SpotifyApi -Method POST -Path "/me/player/next" | Out-Null
        Write-Host "⏭️ Nästa låt."
    } catch { Write-Warning "Kunde inte hoppa till nästa låt." }
}

function Pause-Playback {
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
        Write-Host "⏸️ Pausad."
    } catch { Write-Warning "Kunde inte pausa. Är enheten aktiv?" }
}

function Resume-Playback {
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" | Out-Null
        Write-Host "▶️ Spelar."
    } catch { Write-Warning "Kunde inte starta uppspelning. Öppna Spotify på en enhet och försök igen." }
}
#endregion Spotify-kommandon

#region CLI-loop
function Handle-SpotifyCommand {
    param([string]$Input)
    switch -Regex ($Input.Trim()) {
        "^/spotify$" { Show-CurrentTrack }
        "^/next$"    { Next-Track }
        "^/pause$"   { Pause-Playback }
        "^/play$"    { Resume-Playback }
        "^/quit$"    { Write-Host "Avslutar."; exit }
        default      { Write-Host "Okänt kommando. Tillgängliga: /spotify, /next, /pause, /play, /quit" }
    }
}

# Init: se till att vi har tokens (triggar auth vid behov)
[void](Get-SpotifyAccessToken)

Write-Host "Spotify CLI redo. Skriv kommandon:"
Write-Host "  /spotify  – visa nu spelas"
Write-Host "  /next     – nästa låt"
Write-Host "  /pause    – pausa"
Write-Host "  /play     – spela"
Write-Host "  /quit     – avsluta"

while ($true) {
    $cmd = Read-Host ">"
    Handle-SpotifyCommand $cmd
}
#endregion CLI-loop
