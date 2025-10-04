# Spotify PowerShell Module
# Lägg till i din PowerShell-profil för globala kommandon

#region Konfiguration
$script:ClientId = $env:SPOTIFY_CLIENT_ID
$script:ClientSecret = $env:SPOTIFY_CLIENT_SECRET
$script:RedirectUri = "http://127.0.0.1:8888/callback"
$script:Scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing"
$script:AppDataDir = Join-Path $env:APPDATA "SpotifyCLI"
$script:TokenFile = Join-Path $script:AppDataDir "tokens.json"
$script:TokenEndpoint = "https://accounts.spotify.com/api/token"
$script:ApiBase = "https://api.spotify.com/v1"
#endregion

#region Hjälpfunktioner
function Initialize-TokenStore {
    if (-not (Test-Path $script:AppDataDir)) { New-Item -ItemType Directory -Path $script:AppDataDir | Out-Null }
    if (-not (Test-Path $script:TokenFile)) { '{}' | Set-Content -Path $script:TokenFile -Encoding UTF8 }
}

function Get-StoredTokens {
    Initialize-TokenStore
    try {
        $json = Get-Content -Path $script:TokenFile -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($json)) { return @{} }
        return ($json | ConvertFrom-Json)
    } catch { return @{} }
}

function Set-StoredTokens($Tokens) {
    Initialize-TokenStore
    ($Tokens | ConvertTo-Json -Depth 5) | Set-Content -Path $script:TokenFile -Encoding UTF8
}

function Start-SpotifyAuthentication {
    Write-Host "Startar autentisering mot Spotify..."
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add(($script:RedirectUri.TrimEnd('/') + "/"))
    try {
        $listener.Start()
    } catch {
        Write-Warning "Kunde inte starta lokal listener. Kör PowerShell som administratör."
        return $null
    }

    $state = [Guid]::NewGuid().ToString()
    $authUrl = "https://accounts.spotify.com/authorize?response_type=code&client_id=$($script:ClientId)&redirect_uri=$($script:RedirectUri)&scope=$($script:Scopes)&state=$state"

    Start-Process $authUrl | Out-Null
    Write-Host "Öppnade webbläsaren. Logga in och godkänn appen..."

    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    $query = $request.Url.Query
    $params = [System.Web.HttpUtility]::ParseQueryString($query)
    $code = $params["code"]
    $retState = $params["state"]
    $authError = $params["error"]

    $html = "<html><body style='font-family:sans-serif'><h2>Klart!</h2><p>Du kan stänga denna flik.</p></body></html>"
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.OutputStream.Close()
    $listener.Stop()

    if ($authError) { 
        Write-Error "Spotify auth fel: $authError"
        return $null
    }
    if ($retState -ne $state) {
        Write-Error "State mismatch."
        return $null
    }
    if (-not $code) {
        Write-Error "Ingen auth code."
        return $null
    }

    $body = @{
        grant_type = "authorization_code"
        code = $code
        redirect_uri = $script:RedirectUri
        client_id = $script:ClientId
        client_secret = $script:ClientSecret
    }

    $tokenResp = Invoke-RestMethod -Method Post -Uri $script:TokenEndpoint -Body $body
    $tokens = [ordered]@{
        access_token = $tokenResp.access_token
        token_type = $tokenResp.token_type
        expires_in = $tokenResp.expires_in
        refresh_token = $tokenResp.refresh_token
        obtained_at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    }
    Set-StoredTokens $tokens
    Write-Host "Autentisering slutförd."
    return $tokens
}

function Get-SpotifyAccessToken {
    $tokens = Get-StoredTokens
    if (-not $tokens.access_token) {
        $tokens = Start-SpotifyAuthentication
        if (-not $tokens) { return $null }
        return $tokens.access_token
    }

    $obtained = [long]$tokens.obtained_at
    $expiresIn = [int]$tokens.expires_in
    $age = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $obtained
    if ($age -ge ($expiresIn - 60)) {
        if (-not $tokens.refresh_token) {
            $tokens = Start-SpotifyAuthentication
            if (-not $tokens) { return $null }
            return $tokens.access_token
        }
        $body = @{
            grant_type = "refresh_token"
            refresh_token = $tokens.refresh_token
            client_id = $script:ClientId
            client_secret = $script:ClientSecret
        }
        try {
            $tokenResp = Invoke-RestMethod -Method Post -Uri $script:TokenEndpoint -Body $body
            $tokens.access_token = $tokenResp.access_token
            if ($tokenResp.refresh_token) { $tokens.refresh_token = $tokenResp.refresh_token }
            $tokens.expires_in = $tokenResp.expires_in
            $tokens.obtained_at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            Set-StoredTokens $tokens
        } catch {
            Write-Warning "Kunde inte uppdatera token, försöker ny auth..."
            $tokens = Start-SpotifyAuthentication
            if (-not $tokens) { return $null }
        }
    }
    return $tokens.access_token
}

function Invoke-SpotifyApi {
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$Query,
        $Body
    )
    $access = Get-SpotifyAccessToken
    if (-not $access) { 
        Write-Warning "Kunde inte få access token."
        return 
    }
    
    $uri = $script:ApiBase + $Path
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

function ConvertTo-TimeString {
    param([int]$ms)
    $totalSec = [int][Math]::Round($ms / 1000.0)
    $m = [int]($totalSec / 60)
    $s = $totalSec % 60
    "{0}:{1:D2}" -f $m, $s
}
#endregion

#region Globala kommandon
function spotify {
    <#
    .SYNOPSIS
    Visa vad som spelas just nu på Spotify
    #>
    try {
        $resp = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
    } catch {
        Write-Warning "Kunde inte hämta aktuell låt. Är Spotify öppet på en enhet?"
        return
    }
    if (-not $resp) {
        Write-Host "Ingen uppspelning hittades."
        return
    }

    $isPlaying = $resp.is_playing
    $progress = $resp.progress_ms
    $item = $resp.item
    if (-not $item) { Write-Host "Ingen låtinfo tillgänglig."; return }

    $name = $item.name
    $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
    $album = $item.album.name
    $dur = $item.duration_ms

    Write-Host "🎵 $name" -ForegroundColor Cyan
    Write-Host "👤 $artists" -ForegroundColor Yellow
    Write-Host "📀 $album" -ForegroundColor Green
    Write-Host ("⏱ {0} / {1} {2}" -f (ConvertTo-TimeString $progress), (ConvertTo-TimeString $dur), ($(if ($isPlaying) { "(spelar)" } else { "(paus)" }))) -ForegroundColor Magenta
}

function next {
    <#
    .SYNOPSIS
    Hoppa till nästa låt på Spotify
    #>
    try {
        Invoke-SpotifyApi -Method POST -Path "/me/player/next" | Out-Null
        Write-Host "⏭️ Nästa låt." -ForegroundColor Green
    } catch { Write-Warning "Kunde inte hoppa till nästa låt." }
}

function pause {
    <#
    .SYNOPSIS
    Pausa Spotify-uppspelning
    #>
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
        Write-Host "⏸️ Pausad." -ForegroundColor Yellow
    } catch { Write-Warning "Kunde inte pausa." }
}

function play {
    <#
    .SYNOPSIS
    Starta Spotify-uppspelning
    #>
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" | Out-Null
        Write-Host "▶️ Spelar." -ForegroundColor Green
    } catch { Write-Warning "Kunde inte starta uppspelning." }
}

function previous {
    <#
    .SYNOPSIS
    Hoppa till föregående låt på Spotify
    #>
    try {
        Invoke-SpotifyApi -Method POST -Path "/me/player/previous" | Out-Null
        Write-Host "⏮️ Föregående låt." -ForegroundColor Green
    } catch { Write-Warning "Kunde inte hoppa till föregående låt." }
}
#endregion

# Exportera funktionerna så de blir tillgängliga
Export-ModuleMember -Function spotify, next, pause, play, previous