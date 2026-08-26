# Legacy API Client Module
# Handles the simple token management and API invocation for the main Spotify CLI module.

# --- Module State ---
$script:ApiBase = "https://api.spotify.com/v1"

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


function Test-SpotifyAuth {
    <#
    .SYNOPSIS
    Check the current Spotify authentication status
    .DESCRIPTION
    Reads the stored token file and reports whether authentication is valid,
    how long until expiry, and which scopes are granted.
    .EXAMPLE
    Test-SpotifyAuth
    #>
    $result = [PSCustomObject]@{
        IsAuthenticated  = $false
        ExpiresInSeconds = 0
        Scopes           = @()
        TokenPath        = (Join-Path $env:APPDATA "SpotifyCLI\tokens.json")
        Error            = $null
    }

    $tokenFile = Join-Path $env:APPDATA "SpotifyCLI\tokens.json"
    if (-not (Test-Path $tokenFile)) {
        $result.Error = "Token file not found. Run Start-SpotifyCLI to authenticate."
        Write-Host "Not authenticated — token file missing." -ForegroundColor Red
        Write-Host "  Run: Start-SpotifyCLI" -ForegroundColor Cyan
        return $result
    }

    try {
        $tokens = Get-Content -Path $tokenFile -Raw | ConvertFrom-Json
    } catch {
        $result.Error = "Could not read token file: $_"
        Write-Host "❌ Token file is corrupt or unreadable" -ForegroundColor Red
        return $result
    }

    if (-not $tokens.access_token) {
        $result.Error = "No access token in token file."
        Write-Host "❌ Not authenticated — no access token stored" -ForegroundColor Red
        return $result
    }

    $obtained    = [long]$tokens.obtained_at
    $expiresIn   = [int]$tokens.expires_in
    $age         = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $obtained
    $remaining   = $expiresIn - $age

    if ($remaining -le 0) {
        $result.Error = "Token has expired."
        Write-Host "❌ Token expired" -ForegroundColor Red
        if ($tokens.refresh_token) {
            Write-Host "   A refresh token is available — run .\spotifyCLI.ps1 to refresh" -ForegroundColor Yellow
        }
        return $result
    }

    $result.IsAuthenticated  = $true
    $result.ExpiresInSeconds = [int]$remaining
    $result.Scopes           = if ($tokens.scopes) { $tokens.scopes -split ' ' } else { @() }

    $minutesLeft = [Math]::Floor($remaining / 60)
    Write-Host "✅ Authenticated" -ForegroundColor Green
    Write-Host "   Token expires in: $minutesLeft minutes" -ForegroundColor Gray
    Write-Host "   Scopes: $($result.Scopes.Count) granted" -ForegroundColor Gray
    Write-Host "   Token file: $(Join-Path $env:APPDATA 'SpotifyCLI\tokens.json')" -ForegroundColor Gray

    return $result
}


# --- Module Exports ---

Export-ModuleMember -Function 'Invoke-SpotifyApi', 'Test-SpotifyAuth'
