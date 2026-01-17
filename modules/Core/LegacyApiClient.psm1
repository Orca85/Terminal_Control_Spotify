# Legacy API Client Module
# Handles the simple token management and API invocation for the main Spotify CLI module.

# --- Private Module State ---
$script:AppDataDir = Join-Path $env:APPDATA "SpotifyCLI" # Duplicated from LegacyConfigManager, needs a better solution later.
$script:TokenFile = Join-Path $script:AppDataDir "tokens.json"
$script:TokenEndpoint = "https://accounts.spotify.com/api/token"
$script:ApiBase = "https://api.spotify.com/v1"
$script:RedirectUri = "http://127.0.0.1:8888/callback"
$script:Scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing user-read-private playlist-read-private user-library-read user-library-modify user-read-recently-played user-top-read"

# --- Public Functions ---

function Invoke-SpotifyApi {
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$Query,
        $Body
    )
    $access = Get-SpotifyAccessToken
    if (-not $access) { return $null }
    # Build the complete URI
    $uri = "$($script:ApiBase)$path"
    if ($Query -and $Query.Count -gt 0) {
        $queryString = ($Query.GetEnumerator() | ForEach-Object {
            "$($_.Key)=$([System.Uri]::EscapeDataString($_.Value))"
        }) -join "&"
        $uri += "?$queryString"
    }
    $headers = @{ Authorization = "Bearer $access" }
    try {
        if ($Body) {
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 10)
        } else {
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
        }
    } catch {
        $statusCode = 0
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        $responseBody = ""
        if ($_.Exception.Response.GetResponseStream) {
            $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $responseBody = $streamReader.ReadToEnd()
            $streamReader.Close()
        }

        switch ($statusCode) {
            401 {
                throw "Spotify API authentication failed. Token may be expired or invalid. (HTTP $statusCode)"
            }
            403 {
                $errorDetails = ($responseBody | ConvertFrom-Json -ErrorAction SilentlyContinue)
                $message = if ($errorDetails) { $errorDetails.error.message } else { "Permission denied. This operation may require a higher scope or Spotify Premium." }
                throw "$message (HTTP $statusCode)"
            }
            404 {
                throw "The requested resource was not found. (HTTP $statusCode)"
            }
            429 {
                $retryAfter = $_.Exception.Response.Headers['Retry-After']
                throw "Rate limited by Spotify. Retry after $retryAfter seconds. (HTTP $statusCode)"
            }
            default {
                throw "An unexpected Spotify API error occurred: $($_.Exception.Message) (HTTP $statusCode)"
            }
        }
    }
}

# --- Private Helper Functions ---

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

function Set-StoredTokens($Tokens) {
    Initialize-TokenStore
    ($Tokens | ConvertTo-Json -Depth 5) | Set-Content -Path $script:TokenFile -Encoding UTF8
}

function Get-SpotifyAccessToken {
    $tokens = Get-StoredTokens
    if (-not $tokens.access_token) {
        Write-Host "🔐 Authentication required. Please run the main CLI script first to authenticate." -ForegroundColor Yellow
        Write-Host "Run: .\spotifyCLI.ps1" -ForegroundColor Cyan
        return $null
    }
    # Check if token has required scopes for enhanced features
    if (-not (Test-TokenScopes $tokens)) {
        Write-Host "🔐 Token requires additional permissions. Please re-authenticate using the main CLI script." -ForegroundColor Yellow
        Write-Host "Run: .\spotifyCLI.ps1" -ForegroundColor Cyan
        return $null
    }
    # Check if token is expired and refresh if needed
    $obtained = [long]$tokens.obtained_at
    $expiresIn = [int]$tokens.expires_in
    $age = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $obtained
    if ($age -ge ($expiresIn - 60)) {
        # Token is expired, try to refresh
        if (-not $tokens.refresh_token) {
            Write-Host "🔐 Token expired and no refresh token available. Please re-authenticate." -ForegroundColor Yellow
            Write-Host "Run: .\spotifyCLI.ps1" -ForegroundColor Cyan
            return $null
        }
        try {
            $body = @{
                grant_type = "refresh_token"
                refresh_token = $tokens.refresh_token
                client_id = $env:SPOTIFY_CLIENT_ID
                client_secret = $env:SPOTIFY_CLIENT_SECRET
            }
            $tokenResp = Invoke-RestMethod -Method Post -Uri $script:TokenEndpoint -Body $body
            $tokens.access_token = $tokenResp.access_token
            if ($tokenResp.refresh_token) { $tokens.refresh_token = $tokenResp.refresh_token }
            $tokens.expires_in = $tokenResp.expires_in
            $tokens.obtained_at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            Set-StoredTokens $tokens
            Write-Host "🔄 Token refreshed successfully" -ForegroundColor Green
        } catch {
            Write-Host "🔄 Token refresh failed. Please re-authenticate." -ForegroundColor Red
            Write-Host "Run: .\spotifyCLI.ps1" -ForegroundColor Cyan
            return $null
        }
    }
    return $tokens.access_token
}

function Test-TokenScopes {
    <#
    .SYNOPSIS
    Test if current token has required scopes for enhanced features
    #>
    param($Tokens)
    # If no scope information is stored, assume old token and require re-auth
    if (-not $Tokens.scopes) {
        return $false
    }
    # Check if all required scopes are present
    $requiredScopes = $script:Scopes -split ' '
    $tokenScopes = $Tokens.scopes -split ' '
    foreach ($scope in $requiredScopes) {
        if ($scope -notin $tokenScopes) {
            Write-Verbose "Missing required scope: $scope"
            return $false
        }
    }
    return $true
}


# --- Module Exports ---

Export-ModuleMember -Function 'Invoke-SpotifyApi'
