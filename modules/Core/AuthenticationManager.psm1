# Authentication Manager
# Handles OAuth 2.0 flow, token storage, and credential management for SpotifyCLI.

# --- Module State ---
$script:ClientId      = $null
$script:ClientSecret  = $null
$script:RedirectUri   = "http://127.0.0.1:8888/callback"
$script:TokenEndpoint = "https://accounts.spotify.com/api/token"
$script:Scopes        = @(
    "user-read-playback-state",
    "user-modify-playback-state",
    "user-read-currently-playing",
    "user-read-private",
    "playlist-read-private",
    "user-library-read",
    "user-library-modify",
    "user-read-recently-played",
    "user-top-read",
    "playlist-modify-public",
    "playlist-modify-private"
) -join " "
$script:AppDataDir    = Join-Path $env:APPDATA "SpotifyCLI"
$script:TokenFile     = Join-Path $script:AppDataDir "tokens.json"

# --- Credential Setup ---

function Initialize-SpotifyCredentials {
    <#
    .SYNOPSIS
    Load Spotify API credentials in priority order: parameters > env vars > .env file > prompt.
    #>
    param([string]$ClientId, [string]$ClientSecret)

    if (-not $ClientId)     { $ClientId     = $env:SPOTIFY_CLIENT_ID }
    if (-not $ClientSecret) { $ClientSecret = $env:SPOTIFY_CLIENT_SECRET }

    if (-not $ClientId -or -not $ClientSecret) {
        $envFile = Join-Path (Get-Location) ".env"
        if (Test-Path $envFile) {
            Get-Content $envFile | ForEach-Object {
                if ($_ -match "^(.*?)=(.*)$") {
                    $key = $matches[1].Trim()
                    $val = $matches[2].Trim()
                    if ($key -eq "SPOTIFY_CLIENT_ID"     -and -not $ClientId)     { $ClientId     = $val }
                    if ($key -eq "SPOTIFY_CLIENT_SECRET" -and -not $ClientSecret) { $ClientSecret = $val }
                }
            }
        }
    }

    if (-not $ClientId) {
        Write-Host ""
        Write-Host "Spotify API credentials required." -ForegroundColor Yellow
        Write-Host "Get them at: https://developer.spotify.com/dashboard" -ForegroundColor Cyan
        Write-Host ""
        $ClientId = Read-Host "Enter SPOTIFY_CLIENT_ID"
    }
    if (-not $ClientSecret) {
        $ClientSecret = Read-Host "Enter SPOTIFY_CLIENT_SECRET"
    }

    $script:ClientId     = $ClientId
    $script:ClientSecret = $ClientSecret

    # Also set env vars so other modules that read them directly still work
    $env:SPOTIFY_CLIENT_ID     = $ClientId
    $env:SPOTIFY_CLIENT_SECRET = $ClientSecret
}

# --- Token Storage ---

function Initialize-TokenStore {
    if (-not (Test-Path $script:AppDataDir)) {
        New-Item -ItemType Directory -Path $script:AppDataDir | Out-Null
    }
    if (-not (Test-Path $script:TokenFile)) {
        '{}' | Set-Content -Path $script:TokenFile -Encoding UTF8
    }
}

function Get-StoredTokens {
    Initialize-TokenStore
    try {
        $json = Get-Content -Path $script:TokenFile -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($json)) { return @{} }
        return ($json | ConvertFrom-Json)
    } catch { return @{} }
}

function Set-StoredTokens {
    param($Tokens)
    Initialize-TokenStore
    ($Tokens | ConvertTo-Json -Depth 5) | Set-Content -Path $script:TokenFile -Encoding UTF8
}

# --- OAuth Flow ---

function Start-SpotifyAuth {
    <#
    .SYNOPSIS
    Run the Spotify OAuth 2.0 Authorization Code flow. Opens the browser and listens on port 8888.
    #>
    if (-not $script:ClientId -or -not $script:ClientSecret) {
        Write-Host "Credentials not set. Call Initialize-SpotifyCredentials first." -ForegroundColor Red
        return $null
    }

    Write-Host "Starting Spotify authentication..." -ForegroundColor Cyan
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add(($script:RedirectUri.TrimEnd('/') + "/"))
    try {
        $listener.Start()
    } catch {
        Write-Host ""
        Write-Host "Authentication Setup Error" -ForegroundColor Red
        Write-Host "Could not start local authentication server on port 8888." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Solutions:" -ForegroundColor Green
        Write-Host "  Run PowerShell as Administrator" -ForegroundColor White
        Write-Host "  Make sure port 8888 is not in use" -ForegroundColor White
        Write-Host "  Check Windows Firewall settings" -ForegroundColor White
        return $null
    }

    $state   = [Guid]::NewGuid().ToString()
    $authUrl = "https://accounts.spotify.com/authorize" +
               "?response_type=code" +
               "&client_id=$($script:ClientId)" +
               "&redirect_uri=$($script:RedirectUri)" +
               "&scope=$($script:Scopes)" +
               "&state=$state"

    try {
        Start-Process $authUrl -ErrorAction Stop | Out-Null
        Write-Host "Browser opened — log in and authorize SpotifyCLI." -ForegroundColor Green
    } catch {
        Write-Host "Could not open browser automatically. Open this URL manually:" -ForegroundColor Yellow
        Write-Host $authUrl -ForegroundColor White
    }

    $context   = $listener.GetContext()
    $request   = $context.Request
    $response  = $context.Response

    $queryParams = [System.Web.HttpUtility]::ParseQueryString($request.Url.Query)
    $code        = $queryParams["code"]
    $retState    = $queryParams["state"]
    $authError   = $queryParams["error"]

    $html   = "<html><body style='font-family:sans-serif'><h2>Done!</h2><p>You can close this tab and return to PowerShell.</p></body></html>"
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.OutputStream.Close()
    $listener.Stop()

    if ($authError)        { Write-Error "Spotify auth error: $authError"; return $null }
    if ($retState -ne $state) { Write-Error "State mismatch — possible CSRF."; return $null }
    if (-not $code)        { Write-Error "No auth code received."; return $null }

    $body = @{
        grant_type    = "authorization_code"
        code          = $code
        redirect_uri  = $script:RedirectUri
        client_id     = $script:ClientId
        client_secret = $script:ClientSecret
    }

    $tokenResp = Invoke-RestMethod -Method Post -Uri $script:TokenEndpoint -Body $body
    $tokens = [ordered]@{
        access_token  = $tokenResp.access_token
        token_type    = $tokenResp.token_type
        expires_in    = $tokenResp.expires_in
        refresh_token = $tokenResp.refresh_token
        obtained_at   = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        scopes        = $script:Scopes
    }
    Set-StoredTokens $tokens
    Write-Host "Authentication complete." -ForegroundColor Green
    return $tokens
}

# --- Token Scope Validation ---

function Test-TokenScopes {
    param($Tokens)
    if (-not $Tokens.scopes) { return $false }
    $requiredScopes = $script:Scopes -split ' '
    $tokenScopes    = $Tokens.scopes  -split ' '
    foreach ($scope in $requiredScopes) {
        if ($scope -notin $tokenScopes) { return $false }
    }
    return $true
}

# --- Token Access (with auto-refresh and re-auth) ---

function Get-SpotifyAccessToken {
    $tokens = Get-StoredTokens
    if (-not $tokens.access_token) {
        $tokens = Start-SpotifyAuth
        if (-not $tokens) { return $null }
        return $tokens.access_token
    }

    if (-not (Test-TokenScopes $tokens)) {
        Write-Host "Token needs additional permissions. Re-authenticating..." -ForegroundColor Yellow
        $tokens = Start-SpotifyAuth
        if (-not $tokens) { return $null }
        return $tokens.access_token
    }

    $obtained  = [long]$tokens.obtained_at
    $expiresIn = [int]$tokens.expires_in
    $age       = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $obtained
    if ($age -ge ($expiresIn - 60)) {
        if (-not $tokens.refresh_token) {
            $tokens = Start-SpotifyAuth
            if (-not $tokens) { return $null }
            return $tokens.access_token
        }
        $body = @{
            grant_type    = "refresh_token"
            refresh_token = $tokens.refresh_token
            client_id     = $script:ClientId
            client_secret = $script:ClientSecret
        }
        try {
            $tokenResp = Invoke-RestMethod -Method Post -Uri $script:TokenEndpoint -Body $body
            $tokens.access_token = $tokenResp.access_token
            if ($tokenResp.refresh_token) { $tokens.refresh_token = $tokenResp.refresh_token }
            $tokens.expires_in  = $tokenResp.expires_in
            $tokens.obtained_at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            Set-StoredTokens $tokens
        } catch {
            Write-Host "Token refresh failed. Re-authenticating..." -ForegroundColor Yellow
            $tokens = Start-SpotifyAuth
            if (-not $tokens) { return $null }
        }
    }
    return $tokens.access_token
}

# --- Exports ---
Export-ModuleMember -Function @(
    'Initialize-SpotifyCredentials',
    'Initialize-TokenStore',
    'Get-StoredTokens',
    'Set-StoredTokens',
    'Start-SpotifyAuth',
    'Get-SpotifyAccessToken'
)
