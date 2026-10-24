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
$script:CredentialsFile = Join-Path $script:AppDataDir ".env"

# --- Credential Setup ---

function Read-CredentialsFile {
    param([string]$Path)
    $result = @{}
    if (Test-Path $Path) {
        Get-Content $Path | ForEach-Object {
            if ($_ -match "^(.*?)=(.*)$") { $result[$matches[1].Trim()] = $matches[2].Trim() }
        }
    }
    return $result
}

function Initialize-SpotifyCredentials {
    <#
    .SYNOPSIS
    Load Spotify API credentials in priority order:
    parameters > .env in current directory > %APPDATA%\SpotifyCLI\.env > env vars > prompt.

    .DESCRIPTION
    .env files are checked before inherited environment variables on purpose: .env is the
    documented, per-project way to set or rotate credentials (see README), while an
    inherited $env:SPOTIFY_CLIENT_* value may be a stale User/Machine-level variable set
    during initial setup (see docs/Spotify-API-Guide.md) that never gets updated again.
    Without this order, regenerating the client secret in the Spotify dashboard and
    updating .env would silently keep using the old, now-invalid secret.

    The current-directory .env only helps when a command is run from the project folder.
    Bare aliases (play, next, ...) are usually run from anywhere, so credentials taken
    from the current-directory .env or typed at the prompt are persisted to the fixed
    %APPDATA%\SpotifyCLI\.env, which is found regardless of the working directory.
    #>
    param([string]$ClientId, [string]$ClientSecret)

    $persist = $false

    if (-not $ClientId -or -not $ClientSecret) {
        $local = Read-CredentialsFile (Join-Path (Get-Location) ".env")
        if (-not $ClientId     -and $local.SPOTIFY_CLIENT_ID)     { $ClientId     = $local.SPOTIFY_CLIENT_ID;     $persist = $true }
        if (-not $ClientSecret -and $local.SPOTIFY_CLIENT_SECRET) { $ClientSecret = $local.SPOTIFY_CLIENT_SECRET; $persist = $true }
    }

    if (-not $ClientId -or -not $ClientSecret) {
        $stored = Read-CredentialsFile $script:CredentialsFile
        if (-not $ClientId)     { $ClientId     = $stored.SPOTIFY_CLIENT_ID }
        if (-not $ClientSecret) { $ClientSecret = $stored.SPOTIFY_CLIENT_SECRET }
    }

    if (-not $ClientId)     { $ClientId     = $env:SPOTIFY_CLIENT_ID }
    if (-not $ClientSecret) { $ClientSecret = $env:SPOTIFY_CLIENT_SECRET }

    if (-not $ClientId) {
        Write-Host ""
        Write-Host "Spotify API credentials required." -ForegroundColor Yellow
        Write-Host "Get them at: https://developer.spotify.com/dashboard" -ForegroundColor Cyan
        Write-Host ""
        $ClientId = Read-Host "Enter SPOTIFY_CLIENT_ID"
        $persist = $true
    }
    if (-not $ClientSecret) {
        $ClientSecret = Read-Host "Enter SPOTIFY_CLIENT_SECRET"
        $persist = $true
    }

    if ($persist -and $ClientId -and $ClientSecret) {
        $stored = Read-CredentialsFile $script:CredentialsFile
        if ($stored.SPOTIFY_CLIENT_ID -ne $ClientId -or $stored.SPOTIFY_CLIENT_SECRET -ne $ClientSecret) {
            Initialize-TokenStore
            @("SPOTIFY_CLIENT_ID=$ClientId", "SPOTIFY_CLIENT_SECRET=$ClientSecret") |
                Set-Content -Path $script:CredentialsFile -Encoding UTF8
        }
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
    <#
    .SYNOPSIS
    Get a valid Spotify access token, refreshing or re-authenticating as needed.

    .DESCRIPTION
    Self-heals missing credentials: callers that only import the module and invoke
    a bare command (next, play, ...) never go through CliLoop's startup, so
    $script:ClientId/$script:ClientSecret can still be unset here. Without this,
    a stored access token works fine until it needs refreshing (~hourly), at which
    point the refresh call silently fails with empty client_id/client_secret.
    #>
    if (-not $script:ClientId -or -not $script:ClientSecret) {
        Initialize-SpotifyCredentials
    }

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
