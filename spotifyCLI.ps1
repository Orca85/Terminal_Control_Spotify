<# 
.SYNOPSIS
Spotify CLI GUI-lite för PowerShell

.DESCRIPTION
- Autentiserar via Spotify Authorization Code Flow
- Lagrar och uppdaterar access/refresh tokens lokalt
- Kommandon: /spotify (nu spelas), /next, /pause, /play, /quit
- Kräver: Spotify Developer App (Client ID/Secret), Premium-konto, aktiv Spotify-enhet via Spotify Connect

.PARAMETER Sidecar
Launch in sidecar/split window mode if supported by the terminal

.PARAMETER NewWindow
Force launch in a new window instead of split window

.PARAMETER SplitDirection
Direction for split window (right, down, left, up). Only applies to Windows Terminal.

.PARAMETER Live
Launch directly into live display mode with real-time track updates

.PARAMETER LiveMode
Display mode for live view (detailed, compact, minimal). Only applies when -Live is used.

.EXAMPLE
.\spotifyCLI.ps1
Launch normally in current terminal

.EXAMPLE
.\spotifyCLI.ps1 -Sidecar
Launch in split window if supported, otherwise new window

.EXAMPLE
.\spotifyCLI.ps1 -NewWindow
Force launch in new window

.EXAMPLE
.\spotifyCLI.ps1 -Sidecar -SplitDirection down
Launch in Windows Terminal split pane below current pane

.EXAMPLE
.\spotifyCLI.ps1 -Live
Launch directly into live display mode with detailed view

.EXAMPLE
.\spotifyCLI.ps1 -Live -LiveMode compact
Launch into live display mode with compact single-line view
#>

[CmdletBinding()]
param(
    [switch]$Sidecar,
    [switch]$NewWindow,
    [switch]$Live,
    [ValidateSet("right", "down", "left", "up")]
    [string]$SplitDirection = "right",
    [ValidateSet("detailed", "compact", "minimal")]
    [string]$LiveMode = "detailed",
    [string]$Setlist = ""
)

#region Konfiguration
Get-Content .env | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}
# Debug output (remove in production)
#Write-Host "ClientId: $env:SPOTIFY_CLIENT_ID" -ForegroundColor DarkGray
#Write-Host "ClientSecret: $env:SPOTIFY_CLIENT_SECRET" -ForegroundColor DarkGray

# Fyll i dina uppgifter från Spotify Developer Dashboard
$ClientId = $env:SPOTIFY_CLIENT_ID
$ClientSecret = $env:SPOTIFY_CLIENT_SECRET

# Redirect URI måste exakt matcha den du lagt till i appens inställningar
$RedirectUri = "http://127.0.0.1:8888/callback"

# Enhanced scopes for full functionality including playlists, library, and search
$Scopes = @(
    "user-read-playback-state",
    "user-modify-playback-state", 
    "user-read-currently-playing",
    "user-read-private",           # For playlists
    "playlist-read-private",       # For private playlists
    "user-library-read",           # For liked songs
    "user-library-modify",         # For save/unsave
    "user-read-recently-played",   # For recent tracks
    "user-top-read",              # For enhanced features
    "playlist-modify-public",      # For creating public playlists
    "playlist-modify-private"      # For creating private playlists
) -join " "

# Lagring av tokens och konfiguration
$AppDataDir = Join-Path $env:APPDATA "SpotifyCLI"
$TokenFile = Join-Path $AppDataDir "tokens.json"
$ConfigFile = Join-Path $AppDataDir "config.json"

# Spotify API endpoints
$TokenEndpoint = "https://accounts.spotify.com/api/token"
$ApiBase = "https://api.spotify.com/v1"

# Default configuration structure
$DefaultConfig = @{
    PreferredDevice = $null
    CompactMode = $false
    NotificationsEnabled = $false
    AutoRefreshInterval = 0
    LoggingEnabled = $false
    HistoryEnabled = $true
    MaxHistoryEntries = 100
    LogLevel = "Info"  # Debug, Info, Warning, Error
    MaxLogSizeMB = 10
    LogRetentionDays = 30
    Colors = @{
        Playing = "Green"
        Paused = "Yellow"
        Track = "Cyan"
        Artist = "Yellow"
        Album = "Green"
        Progress = "Magenta"
    }
}

# Logging configuration
$LogFile = Join-Path $AppDataDir "spotify-cli.log"
$HistoryFile = Join-Path $AppDataDir "playback-history.json"

# Track previous track for notifications
$script:PreviousTrackId = $null

# Auto-refresh control
$script:AutoRefreshActive = $false
#endregion Konfiguration

#region Windows Notification Functions
function Show-TrackNotification {
    <#
    .SYNOPSIS
    Display a Windows notification for track changes
    .PARAMETER Title
    Notification title
    .PARAMETER Message
    Notification message
    .PARAMETER TrackInfo
    Track information object from Spotify API
    .PARAMETER IsTest
    Whether this is a test notification
    #>
    param(
        [string]$Title,
        [string]$Message,
        $TrackInfo,
        [bool]$IsTest = $false
    )
    
    $config = Get-SpotifyConfig
    if (-not $config.NotificationsEnabled -and -not $IsTest) {
        return
    }
    
    try {
        # Create notification content
        if ($TrackInfo) {
            $trackName = $TrackInfo.name
            $artists = ($TrackInfo.artists | ForEach-Object { $_.name }) -join ", "
            $album = $TrackInfo.album.name
            
            $notificationTitle = "🎵 Now Playing"
            $notificationText = "$trackName by $artists"
            if ($album) {
                $notificationText += " from $album"
            }
        } else {
            $notificationTitle = $Title
            $notificationText = $Message
        }
        
        # Try Windows 10+ toast notifications first
        if ([System.Environment]::OSVersion.Version.Major -ge 10) {
            try {
                # Use PowerShell's built-in toast notification capability
                $null = New-BurntToastNotification -Text $notificationTitle, $notificationText -Silent -ErrorAction Stop
                return
            } catch {
                # BurntToast module not available, try alternative approach
            }
            
            try {
                # Alternative: Use Windows Shell notification
                $shell = New-Object -ComObject "Wscript.Shell"
                $shell.Popup($notificationText, 5, $notificationTitle, 64) | Out-Null
                return
            } catch {
                # Shell popup failed, continue to fallback
            }
        }
        
        # Fallback to console notification
        if ($TrackInfo) {
            Write-Host "🎵 Now Playing: $($TrackInfo.name) by $(($TrackInfo.artists | ForEach-Object { $_.name }) -join ', ')" -ForegroundColor Cyan
        } else {
            Write-Host "🔔 $Title`: $Message" -ForegroundColor Cyan
        }
        
    } catch {
        # Final fallback to console notification
        if ($TrackInfo) {
            Write-Host "🎵 Now Playing: $($TrackInfo.name) by $(($TrackInfo.artists | ForEach-Object { $_.name }) -join ', ')" -ForegroundColor Cyan
        } else {
            Write-Host "🔔 $Title`: $Message" -ForegroundColor Cyan
        }
    }
}

function Test-NotificationSupport {
    <#
    .SYNOPSIS
    Test if Windows notifications are supported on this system
    .DESCRIPTION
    Checks Windows version and available notification methods
    #>
    try {
        # Check Windows version
        if ([System.Environment]::OSVersion.Version.Major -lt 6) {
            return @{
                Supported = $false
                Reason = "Notifications require Windows Vista or later"
            }
        }
        
        # Test BurntToast module availability
        try {
            $null = Get-Command New-BurntToastNotification -ErrorAction Stop
            return @{
                Supported = $true
                Reason = "BurntToast module available for toast notifications"
            }
        } catch {
            # BurntToast not available, check for shell popup support
        }
        
        # Test Windows Shell popup support
        try {
            $shell = New-Object -ComObject "Wscript.Shell" -ErrorAction Stop
            return @{
                Supported = $true
                Reason = "Windows Shell popup notifications available"
            }
        } catch {
            # Shell popup not available
        }
        
        # At minimum, console notifications are always supported
        return @{
            Supported = $true
            Reason = "Console notifications available (fallback)"
        }
    } catch {
        return @{
            Supported = $true
            Reason = "Console notifications available (fallback)"
        }
    }
}

function Initialize-NotificationSystem {
    <#
    .SYNOPSIS
    Initialize the notification system and check compatibility
    #>
    $support = Test-NotificationSupport
    
    if (-not $support.Supported) {
        Write-Host "⚠️ Notification system not supported: $($support.Reason)" -ForegroundColor Yellow
        
        # Disable notifications in config if not supported
        $config = Get-SpotifyConfig
        if ($config.NotificationsEnabled) {
            $config.NotificationsEnabled = $false
            Set-SpotifyConfig -Config $config
            Write-Host "⚠️ Notifications disabled: $($support.Reason)" -ForegroundColor Yellow
        }
        return $false
    }
    
    return $true
}

function Update-TrackNotification {
    <#
    .SYNOPSIS
    Check for track changes and show notifications if enabled
    .PARAMETER CurrentTrack
    Current track information from Spotify API
    #>
    param($CurrentTrack)
    
    $config = Get-SpotifyConfig
    if (-not $config.NotificationsEnabled) {
        return
    }
    
    if (-not $CurrentTrack -or -not $CurrentTrack.item) {
        return
    }
    
    $currentTrackId = $CurrentTrack.item.id
    
    # Check if track has changed
    if ($script:PreviousTrackId -and $script:PreviousTrackId -ne $currentTrackId) {
        # Track has changed, show notification
        Show-TrackNotification -TrackInfo $CurrentTrack.item
    }
    
    # Update previous track ID
    $script:PreviousTrackId = $currentTrackId
}
#endregion

#region Hjälpfunktioner
function Initialize-TokenStore {
    if (-not (Test-Path $AppDataDir)) { 
        New-Item -ItemType Directory -Path $AppDataDir | Out-Null 
    }
    if (-not (Test-Path $TokenFile)) { 
        '{}' | Set-Content -Path $TokenFile -Encoding UTF8 
    }
}

function Get-StoredTokens {
    Initialize-TokenStore
    try {
        $json = Get-Content -Path $TokenFile -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($json)) { 
            return @{} 
        }
        return ($json | ConvertFrom-Json)
    }
    catch { 
        return @{} 
    }
}

function Set-StoredTokens {
    param([hashtable]$Tokens)
    
    Initialize-TokenStore
    ($Tokens | ConvertTo-Json -Depth 5) | Set-Content -Path $TokenFile -Encoding UTF8
}

# Note: PKCE implementation could be added here for enhanced security
# Currently using Authorization Code flow with client secret

function Start-SpotifyAuth {
    Write-Host "Startar autentisering mot Spotify..."
    # Starta en lokal HTTP-listener för att få 'code'
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add(($RedirectUri.TrimEnd('/') + "/"))
    try {
        $listener.Start()
    }
    catch {
        Write-Host "🔐 Authentication Setup Error" -ForegroundColor Red
        Write-Host "Could not start local authentication server." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "SOLUTION:" -ForegroundColor Green
        Write-Host "• Run PowerShell as Administrator" -ForegroundColor White
        Write-Host "• Make sure port 8888 is not in use by another application" -ForegroundColor White
        Write-Host "• Check Windows Firewall settings" -ForegroundColor White
        return $null
    }

    $state = [Guid]::NewGuid().ToString()
    $authUrl = "https://accounts.spotify.com/authorize?response_type=code&client_id=$ClientId&redirect_uri=$RedirectUri&scope=$Scopes&state=$State"

    try {
        Start-Process $authUrl -ErrorAction Stop | Out-Null
        Write-Host "✅ Browser opened for Spotify authentication" -ForegroundColor Green
        Write-Host "Please log in and authorize the application in your browser..." -ForegroundColor Cyan
    } catch {
        Write-Host "⚠️ Could not automatically open browser" -ForegroundColor Yellow
        Write-Host "Please manually open this URL in your browser:" -ForegroundColor Cyan
        Write-Host $authUrl -ForegroundColor White
        Write-Host "Then return here to complete authentication..." -ForegroundColor Cyan
    }

    # Vänta på callback
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    $query = $request.Url.Query
    $params = [System.Web.HttpUtility]::ParseQueryString($query)
    $code = $params["code"]
    $retState = $params["state"]
    $authError = $params["error"]

    $html = "<html><body style='font-family:sans-serif'><h2>Klart!</h2><p>Du kan stänga denna flik och gå tillbaka till PowerShell.</p></body></html>"
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
        Write-Error "Ogiltig state-mismatch."
        return $null
    }
    if (-not $code) {
        Write-Error "Ingen auth code mottagen."
        return $null
    }

    # Byt code mot tokens
    $body = @{
        grant_type    = "authorization_code"
        code          = $code
        redirect_uri  = $RedirectUri
        client_id     = $ClientId
        client_secret = $ClientSecret
    }

    $tokenResp = Invoke-RestMethod -Method Post -Uri $TokenEndpoint -Body $body
    $tokens = [ordered]@{
        access_token  = $tokenResp.access_token
        token_type    = $tokenResp.token_type
        expires_in    = $tokenResp.expires_in
        refresh_token = $tokenResp.refresh_token
        obtained_at   = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        scopes        = $Scopes
    }
    Set-StoredTokens $tokens
    Write-Host "Autentisering slutförd."
    return $tokens
}

function Test-TokenScopes {
    <#
    .SYNOPSIS
    Test if current token has required scopes for enhanced features
    .DESCRIPTION
    Checks if the stored token was obtained with the current scope requirements.
    Returns false if scopes are insufficient, triggering re-authentication.
    #>
    param($Tokens)
    
    # If no scope information is stored, assume old token and require re-auth
    if (-not $Tokens.scopes) {
        return $false
    }
    
    # Check if all required scopes are present
    $requiredScopes = $Scopes -split ' '
    $tokenScopes = $Tokens.scopes -split ' '
    
    foreach ($scope in $requiredScopes) {
        if ($scope -notin $tokenScopes) {
            Write-Verbose "Missing required scope: $scope"
            return $false
        }
    }
    
    return $true
}

function Get-SpotifyAccessToken {
    $tokens = Get-StoredTokens
    if (-not $tokens.access_token) {
        $tokens = Start-SpotifyAuth
        return $tokens.access_token
    }

    # Check if token has required scopes for enhanced features
    if (-not (Test-TokenScopes $tokens)) {
        Write-Host "Token requires additional permissions for enhanced features. Re-authenticating..." -ForegroundColor Yellow
        $tokens = Start-SpotifyAuth
        return $tokens.access_token
    }

    $obtained = [long]$tokens.obtained_at
    $expiresIn = [int]$tokens.expires_in
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
            $tokens.obtained_at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            Set-StoredTokens $tokens
        }
        catch {
            Write-Host "🔄 Token Refresh Failed" -ForegroundColor Red
            Write-Host "Could not refresh access token. Re-authenticating..." -ForegroundColor Yellow
            $tokens = Start-SpotifyAuth
        }
    }
    return $tokens.access_token
}

function Invoke-SpotifyApi {
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'DELETE')][string]$Method,
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
    }
    else {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
    }
}

function Format-Time {
    param([int]$ms)
    $totalSec = [int][Math]::Round($ms / 1000.0)
    $m = [int]($totalSec / 60)
    $s = $totalSec % 60
    "{0}:{1:D2}" -f $m, $s
}

function Show-ProgressBar {
    param(
        [int]$Current,
        [int]$Total,
        [int]$Width = 30
    )
    
    if ($Total -le 0) {
        return "[$("░" * $Width)] 0%"
    }
    
    $percentage = [Math]::Round(($Current / $Total) * 100)
    $filled = [Math]::Round(($Current / $Total) * $Width)
    $empty = $Width - $filled
    
    # Ensure we don't exceed bounds
    if ($filled -gt $Width) { $filled = $Width; $empty = 0 }
    if ($filled -lt 0) { $filled = 0; $empty = $Width }
    
    $bar = "█" * $filled + "░" * $empty
    return "[$bar] $percentage%"
}

function Get-StatusColor {
    param([bool]$IsPlaying)
    
    $config = Get-SpotifyConfig
    if ($IsPlaying) { 
        return $config.Colors.Playing 
    } else { 
        return $config.Colors.Paused 
    }
}

function Get-TrackColor {
    $config = Get-SpotifyConfig
    return $config.Colors.Track
}

function Get-ArtistColor {
    $config = Get-SpotifyConfig
    return $config.Colors.Artist
}

function Get-AlbumColor {
    $config = Get-SpotifyConfig
    return $config.Colors.Album
}

function Get-ProgressColor {
    $config = Get-SpotifyConfig
    return $config.Colors.Progress
}

function Show-CompactTrack {
    param($TrackData)
    
    if (-not $TrackData -or -not $TrackData.item) {
        Write-Host "No track playing" -ForegroundColor Yellow
        return
    }
    
    $isPlaying = $TrackData.is_playing
    $progress = $TrackData.progress_ms
    $item = $TrackData.item
    $device = $TrackData.device
    
    $name = $item.name
    $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
    $dur = $item.duration_ms
    
    # Create compact progress indicator (shorter bar)
    $progressBar = Show-ProgressBar -Current $progress -Total $dur -Width 15
    $timeInfo = "{0}/{1}" -f (Format-Time $progress), (Format-Time $dur)
    $playIcon = if ($isPlaying) { "▶️" } else { "⏸️" }
    
    # Device info (shortened)
    $deviceInfo = if ($device) {
        $deviceIcon = switch ($device.type.ToLower()) {
            "computer" { "💻" }
            "smartphone" { "📱" }
            "speaker" { "🔊" }
            "tv" { "📺" }
            default { "🎵" }
        }
        " on $deviceIcon"
    } else { "" }
    
    # Truncate long names for compact display
    $maxNameLength = 25
    $maxArtistLength = 20
    
    $displayName = if ($name.Length -gt $maxNameLength) { 
        $name.Substring(0, $maxNameLength - 3) + "..." 
    } else { 
        $name 
    }
    
    $displayArtists = if ($artists.Length -gt $maxArtistLength) { 
        $artists.Substring(0, $maxArtistLength - 3) + "..." 
    } else { 
        $artists 
    }
    
    # Use color coding for compact display
    $trackColor = Get-TrackColor
    $artistColor = Get-ArtistColor
    $progressColor = Get-ProgressColor
    
    # Single line format: [Icon] Track - Artist | [Progress] Time | Device
    Write-Host "$playIcon " -NoNewline -ForegroundColor (Get-StatusColor -IsPlaying $isPlaying)
    Write-Host "$displayName" -NoNewline -ForegroundColor $trackColor
    Write-Host " - " -NoNewline -ForegroundColor Gray
    Write-Host "$displayArtists" -NoNewline -ForegroundColor $artistColor
    Write-Host " | " -NoNewline -ForegroundColor Gray
    Write-Host "$progressBar" -NoNewline -ForegroundColor $progressColor
    Write-Host " $timeInfo" -NoNewline -ForegroundColor $progressColor
    Write-Host "$deviceInfo" -ForegroundColor Gray
}

function Initialize-ConfigStore {
    if (-not (Test-Path $AppDataDir)) { 
        New-Item -ItemType Directory -Path $AppDataDir | Out-Null 
    }
    if (-not (Test-Path $ConfigFile)) { 
        $DefaultConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigFile -Encoding UTF8
    }
}

function Get-SpotifyConfig {
    Initialize-ConfigStore
    try {
        $json = Get-Content -Path $ConfigFile -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($json)) { 
            return $DefaultConfig.Clone()
        }
        $config = ($json | ConvertFrom-Json)
        
        # Convert PSCustomObject to hashtable and merge with defaults
        $result = $DefaultConfig.Clone()
        
        # Merge top-level properties
        $config.PSObject.Properties | ForEach-Object {
            if ($_.Name -eq "Colors" -and $_.Value) {
                # Handle Colors object specially
                $result.Colors = @{}
                $_.Value.PSObject.Properties | ForEach-Object {
                    $result.Colors[$_.Name] = $_.Value
                }
                # Ensure all default colors exist
                $DefaultConfig.Colors.GetEnumerator() | ForEach-Object {
                    if (-not $result.Colors.ContainsKey($_.Key)) {
                        $result.Colors[$_.Key] = $_.Value
                    }
                }
            } else {
                $result[$_.Name] = $_.Value
            }
        }
        
        return $result
    } catch { 
        Write-Warning "Could not load configuration, using defaults: $($_.Exception.Message)"
        return $DefaultConfig.Clone()
    }
}

function Set-SpotifyConfig {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    Initialize-ConfigStore
    try {
        ($Config | ConvertTo-Json -Depth 5) | Set-Content -Path $ConfigFile -Encoding UTF8
        return $true
    } catch {
        Write-Error "Could not save configuration: $($_.Exception.Message)"
        return $false
    }
}

function Test-SpotifyConfigValue {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        $Value
    )
    
    switch ($Key) {
        "PreferredDevice" { 
            return ($Value -eq $null -or $Value -is [string])
        }
        "CompactMode" { 
            return ($Value -is [bool])
        }
        "NotificationsEnabled" { 
            return ($Value -is [bool])
        }
        "AutoRefreshInterval" { 
            return ($Value -is [int] -and $Value -ge 0)
        }
        "LoggingEnabled" { 
            return ($Value -is [bool])
        }
        "HistoryEnabled" { 
            return ($Value -is [bool])
        }
        "MaxHistoryEntries" { 
            return ($Value -is [int] -and $Value -gt 0)
        }
        "Colors" {
            if ($Value -isnot [hashtable]) { return $false }
            $validColors = @("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")
            foreach ($colorValue in $Value.Values) {
                if ($colorValue -notin $validColors) { return $false }
            }
            return $true
        }
        default { 
            return $false 
        }
    }
}

function Handle-SpotifyError {
    <#
    .SYNOPSIS
    Centralized error handling for Spotify API errors
    .PARAMETER ErrorRecord
    The error record from the API call
    .PARAMETER Context
    Context information about what operation failed
    .PARAMETER ShowSuggestions
    Whether to show actionable suggestions
    #>
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$Context = "API operation",
        [bool]$ShowSuggestions = $true
    )
    
    $statusCode = $null
    $errorMessage = $ErrorRecord.Exception.Message
    
    # Extract HTTP status code if available
    if ($ErrorRecord.Exception.Response) {
        $statusCode = [int]$ErrorRecord.Exception.Response.StatusCode
    }
    
    switch ($statusCode) {
        401 {
            Write-Host "🔐 Authentication Error" -ForegroundColor Red
            Write-Host "Your Spotify session has expired." -ForegroundColor Yellow
            if ($ShowSuggestions) {
                Write-Host ""
                Write-Host "SOLUTION:" -ForegroundColor Green
                Write-Host "• The CLI will automatically re-authenticate you" -ForegroundColor White
                Write-Host "• If problems persist, restart the CLI" -ForegroundColor White
            }
            # Trigger re-authentication
            try {
                [void](Get-SpotifyAccessToken)
                Write-Host "✅ Re-authentication completed. Please try your command again." -ForegroundColor Green
            } catch {
                Write-Host "❌ Re-authentication failed. Please restart the CLI." -ForegroundColor Red
            }
        }
        403 {
            Write-Host "🚫 Permission Error" -ForegroundColor Red
            Write-Host "This operation requires Spotify Premium." -ForegroundColor Yellow
            if ($ShowSuggestions) {
                Write-Host ""
                Write-Host "AFFECTED FEATURES:" -ForegroundColor Yellow
                Write-Host "• Seek, volume, shuffle, repeat controls" -ForegroundColor White
                Write-Host "• Device transfer and queue management" -ForegroundColor White
                Write-Host "• Playing specific tracks/albums/playlists" -ForegroundColor White
                Write-Host ""
                Write-Host "AVAILABLE WITH FREE:" -ForegroundColor Green
                Write-Host "• View current track (/spotify)" -ForegroundColor White
                Write-Host "• Browse playlists and liked songs" -ForegroundColor White
                Write-Host "• Search for music" -ForegroundColor White
            }
        }
        404 {
            if ($Context -like "*device*") {
                Write-Host "📱 No Active Device" -ForegroundColor Red
                Write-Host "No Spotify device is currently active." -ForegroundColor Yellow
                if ($ShowSuggestions) {
                    Write-Host ""
                    Write-Host "SOLUTION:" -ForegroundColor Green
                    Write-Host "1. Open Spotify on any device (phone, computer, speaker)" -ForegroundColor White
                    Write-Host "2. Start playing any song" -ForegroundColor White
                    Write-Host "3. Use /devices to see available devices" -ForegroundColor White
                    Write-Host "4. Use /transfer <device_id> if needed" -ForegroundColor White
                }
            } elseif ($Context -like "*track*" -or $Context -like "*content*") {
                Write-Host "🎵 Content Not Found" -ForegroundColor Red
                Write-Host "The requested track, album, or playlist was not found." -ForegroundColor Yellow
                if ($ShowSuggestions) {
                    Write-Host ""
                    Write-Host "POSSIBLE CAUSES:" -ForegroundColor Yellow
                    Write-Host "• Invalid or expired Spotify URI" -ForegroundColor White
                    Write-Host "• Content removed from Spotify" -ForegroundColor White
                    Write-Host "• Content not available in your region" -ForegroundColor White
                    Write-Host ""
                    Write-Host "TIP: Use /search to find current URIs" -ForegroundColor Green
                }
            } else {
                Write-Host "❓ Not Found" -ForegroundColor Red
                Write-Host "The requested resource was not found." -ForegroundColor Yellow
            }
        }
        429 {
            Write-Host "⏳ Rate Limit Exceeded" -ForegroundColor Red
            Write-Host "Too many requests sent to Spotify. Waiting before retry..." -ForegroundColor Yellow
            if ($ShowSuggestions) {
                Write-Host ""
                Write-Host "AUTOMATIC RETRY:" -ForegroundColor Green
                Write-Host "• The CLI will wait and retry automatically" -ForegroundColor White
                Write-Host "• Please wait a moment before trying again" -ForegroundColor White
            }
            Start-Sleep -Seconds 5
        }
        500 {
            Write-Host "🔧 Spotify Server Error" -ForegroundColor Red
            Write-Host "Spotify's servers are experiencing issues." -ForegroundColor Yellow
            if ($ShowSuggestions) {
                Write-Host ""
                Write-Host "SOLUTION:" -ForegroundColor Green
                Write-Host "• Wait a few minutes and try again" -ForegroundColor White
                Write-Host "• Check Spotify's status page if issues persist" -ForegroundColor White
            }
        }
        { $_ -in @(502, 503, 504) } {
            Write-Host "🌐 Service Unavailable" -ForegroundColor Red
            Write-Host "Spotify's API is temporarily unavailable." -ForegroundColor Yellow
            if ($ShowSuggestions) {
                Write-Host ""
                Write-Host "SOLUTION:" -ForegroundColor Green
                Write-Host "• This is usually temporary - try again in a few minutes" -ForegroundColor White
                Write-Host "• Check your internet connection" -ForegroundColor White
            }
        }
        default {
            if ($errorMessage -like "*network*" -or $errorMessage -like "*connection*" -or $errorMessage -like "*timeout*") {
                Write-Host "🌐 Network Error" -ForegroundColor Red
                Write-Host "Unable to connect to Spotify's servers." -ForegroundColor Yellow
                if ($ShowSuggestions) {
                    Write-Host ""
                    Write-Host "TROUBLESHOOTING:" -ForegroundColor Green
                    Write-Host "• Check your internet connection" -ForegroundColor White
                    Write-Host "• Try again in a few moments" -ForegroundColor White
                    Write-Host "• Restart the CLI if problems persist" -ForegroundColor White
                }
            } else {
                Write-Host "❌ Unexpected Error" -ForegroundColor Red
                Write-Host "An unexpected error occurred during $Context." -ForegroundColor Yellow
                if ($ShowSuggestions) {
                    Write-Host ""
                    Write-Host "ERROR DETAILS:" -ForegroundColor Yellow
                    Write-Host "$errorMessage" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "TROUBLESHOOTING:" -ForegroundColor Green
                    Write-Host "• Try the command again" -ForegroundColor White
                    Write-Host "• Use /help <command> for usage information" -ForegroundColor White
                    Write-Host "• Restart the CLI if problems persist" -ForegroundColor White
                }
            }
        }
    }
}

function Test-SpotifyConnection {
    <#
    .SYNOPSIS
    Test connection to Spotify API and provide helpful feedback
    .DESCRIPTION
    Performs a simple API call to test connectivity and authentication
    #>
    try {
        $response = Invoke-SpotifyApi -Method GET -Path "/me" -ErrorAction Stop
        return $true
    } catch {
        Handle-SpotifyError -ErrorRecord $_ -Context "connection test" -ShowSuggestions $true
        return $false
    }
}

function Show-UnknownCommand {
    param([string]$Command)
    
    $availableCommands = @(
        "spotify", "next", "pause", "play", "previous", "seek", "volume", "shuffle", "repeat",
        "devices", "transfer", "search", "queue", "play-queue", "playlists", "liked", "recent", "save", "unsave",
        "config", "help", "history", "notifications", "auto-refresh", "live", "sidecar", "quiz", "peak", "setlist", "quit", "exit"
    )
    
    Write-Host "❓ Unknown Command: $Command" -ForegroundColor Red
    
    # Find similar commands using simple string matching
    $suggestions = $availableCommands | Where-Object { 
        $_ -like "*$($Command.TrimStart('/').ToLower())*" -or 
        $Command.TrimStart('/').ToLower() -like "*$_*" 
    } | Select-Object -First 3
    
    if ($suggestions) {
        Write-Host ""
        Write-Host "💡 Did you mean:" -ForegroundColor Yellow
        $suggestions | ForEach-Object {
            Write-Host "  /$_" -ForegroundColor Green
        }
    } else {
        Write-Host ""
        Write-Host "💡 HELP:" -ForegroundColor Yellow
        Write-Host "• Use /help to see all available commands" -ForegroundColor White
        Write-Host "• Use /help <command> for detailed command help" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "🔍 QUICK COMMANDS:" -ForegroundColor Cyan
    Write-Host "  /spotify  - Show current track" -ForegroundColor White
    Write-Host "  /help     - Show all commands" -ForegroundColor White
    Write-Host "  /devices  - List Spotify devices" -ForegroundColor White
}

function Invoke-HelpCommand {
    param([string]$Arguments)
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        # Show general help overview
        Write-Host "Spotify CLI - Enhanced PowerShell Interface" -ForegroundColor Cyan
        Write-Host "===========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "PLAYBACK CONTROLS:" -ForegroundColor Yellow
        Write-Host "  /spotify [compact] - Show current track (add 'compact' for single-line)" -ForegroundColor White
        Write-Host "  /play              - Resume playback" -ForegroundColor White
        Write-Host "  /pause             - Pause playback" -ForegroundColor White
        Write-Host "  /next              - Skip to next track" -ForegroundColor White
        Write-Host "  /previous          - Go to previous track" -ForegroundColor White
        Write-Host "  /seek <seconds>    - Seek forward/backward (use negative for backward)" -ForegroundColor White
        Write-Host "  /volume <0-100>    - Set playback volume" -ForegroundColor White
        Write-Host "  /shuffle <on|off>  - Toggle shuffle mode" -ForegroundColor White
        Write-Host "  /repeat <track|context|off> - Set repeat mode" -ForegroundColor White
        Write-Host ""
        Write-Host "DEVICE MANAGEMENT:" -ForegroundColor Yellow
        Write-Host "  /devices           - List available Spotify Connect devices" -ForegroundColor White
        Write-Host "  /transfer <id>     - Transfer playback to device" -ForegroundColor White
        Write-Host ""
        Write-Host "SEARCH & PLAYBACK:" -ForegroundColor Yellow
        Write-Host "  /search <query>    - Search for tracks, artists, albums" -ForegroundColor White
        Write-Host "  /queue <uri>       - Add track to playback queue" -ForegroundColor White
        Write-Host "  /play track <uri>  - Play specific track" -ForegroundColor White
        Write-Host "  /play album <uri>  - Play specific album" -ForegroundColor White
        Write-Host "  /play playlist <uri> - Play specific playlist" -ForegroundColor White
        Write-Host ""
        Write-Host "LIBRARY MANAGEMENT:" -ForegroundColor Yellow
        Write-Host "  /playlists         - Show your playlists" -ForegroundColor White
        Write-Host "  /liked             - Show your liked songs" -ForegroundColor White
        Write-Host "  /recent            - Show recently played tracks" -ForegroundColor White
        Write-Host "  /save              - Add current track to liked songs" -ForegroundColor White
        Write-Host "  /unsave            - Remove current track from liked songs" -ForegroundColor White
        Write-Host ""
        Write-Host "LIVE FEATURES:" -ForegroundColor Yellow
        Write-Host "  /live [mode]       - Start live display mode (detailed/compact/minimal)" -ForegroundColor White
        Write-Host "  /sidecar [options] - Launch CLI in split window/sidecar mode" -ForegroundColor White
        Write-Host ""
        Write-Host "FUN:" -ForegroundColor Yellow
        Write-Host "  /quiz [rounds]     - Music quiz: guess songs from your liked tracks" -ForegroundColor White
        Write-Host "  /peak              - Track insights dashboard (popularity, genres, etc.)" -ForegroundColor White
        Write-Host "  /setlist <artist>  - Concert setlists + create Spotify playlist" -ForegroundColor White
        Write-Host ""
        Write-Host "SYSTEM COMMANDS:" -ForegroundColor Yellow
        Write-Host "  /config [key] [value] - View/modify configuration" -ForegroundColor White
        Write-Host "  /config-live [command] - Manage live features configuration" -ForegroundColor White
        Write-Host "  /history           - Show playback history" -ForegroundColor White
        Write-Host "  /notifications <on|off> - Toggle notifications" -ForegroundColor White
        Write-Host "  /auto-refresh <seconds> - Auto-refresh display every X seconds" -ForegroundColor White
        Write-Host "  /help [command]    - Show help (add command for detailed help)" -ForegroundColor White
        Write-Host "  /quit              - Exit the CLI" -ForegroundColor White
        Write-Host ""
        Write-Host "For detailed help on a specific command, use: /help <command>" -ForegroundColor Gray
        Write-Host "Example: /help seek" -ForegroundColor Gray
        return
    }
    
    # Show detailed help for specific command
    $command = $Arguments.Trim().ToLower().TrimStart('/')
    
    switch ($command) {
        "spotify" {
            Write-Host "COMMAND: /spotify [compact]" -ForegroundColor Cyan
            Write-Host "=========================" -ForegroundColor Cyan
            Write-Host "Shows information about the currently playing track." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /spotify          - Show full track information with progress bar" -ForegroundColor White
            Write-Host "  /spotify compact  - Show compact single-line format" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /spotify" -ForegroundColor Gray
            Write-Host "  /spotify compact" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTE: Compact mode can also be enabled globally via /config CompactMode true" -ForegroundColor Gray
        }
        "seek" {
            Write-Host "COMMAND: /seek <seconds>" -ForegroundColor Cyan
            Write-Host "======================" -ForegroundColor Cyan
            Write-Host "Seeks forward or backward in the current track." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /seek <seconds>   - Positive numbers seek forward, negative backward" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /seek 30          - Skip forward 30 seconds" -ForegroundColor Gray
            Write-Host "  /seek -15         - Skip backward 15 seconds" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
            Write-Host "  - Active device with current track playing" -ForegroundColor Gray
        }
        "volume" {
            Write-Host "COMMAND: /volume <0-100>" -ForegroundColor Cyan
            Write-Host "======================" -ForegroundColor Cyan
            Write-Host "Sets the playback volume on the active device." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /volume <level>   - Volume level from 0 (mute) to 100 (maximum)" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /volume 50        - Set volume to 50%" -ForegroundColor Gray
            Write-Host "  /volume 0         - Mute playback" -ForegroundColor Gray
            Write-Host "  /volume 100       - Set to maximum volume" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
            Write-Host "  - Active device that supports volume control" -ForegroundColor Gray
        }
        "shuffle" {
            Write-Host "COMMAND: /shuffle <on|off>" -ForegroundColor Cyan
            Write-Host "========================" -ForegroundColor Cyan
            Write-Host "Enables or disables shuffle mode for the current playback context." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /shuffle on       - Enable shuffle mode" -ForegroundColor White
            Write-Host "  /shuffle off      - Disable shuffle mode" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /shuffle on" -ForegroundColor Gray
            Write-Host "  /shuffle off" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
            Write-Host "  - Active playback context (playlist, album, etc.)" -ForegroundColor Gray
        }
        "repeat" {
            Write-Host "COMMAND: /repeat <track|context|off>" -ForegroundColor Cyan
            Write-Host "===================================" -ForegroundColor Cyan
            Write-Host "Sets the repeat mode for playback." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /repeat track     - Repeat current track" -ForegroundColor White
            Write-Host "  /repeat context   - Repeat current playlist/album" -ForegroundColor White
            Write-Host "  /repeat off       - Disable repeat" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /repeat track" -ForegroundColor Gray
            Write-Host "  /repeat context" -ForegroundColor Gray
            Write-Host "  /repeat off" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
            Write-Host "  - Active playback context" -ForegroundColor Gray
        }
        "devices" {
            Write-Host "COMMAND: /devices" -ForegroundColor Cyan
            Write-Host "================" -ForegroundColor Cyan
            Write-Host "Lists all available Spotify Connect devices." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /devices          - Show all available devices with status" -ForegroundColor White
            Write-Host ""
            Write-Host "DISPLAYED INFO:" -ForegroundColor Yellow
            Write-Host "  - Device name and type" -ForegroundColor Gray
            Write-Host "  - Active status (which device is currently playing)" -ForegroundColor Gray
            Write-Host "  - Volume level (if available)" -ForegroundColor Gray
            Write-Host "  - Device ID (for use with /transfer command)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "TIP: Use device IDs with /transfer command to switch playback" -ForegroundColor Gray
        }
        "transfer" {
            Write-Host "COMMAND: /transfer <device_id>" -ForegroundColor Cyan
            Write-Host "=============================" -ForegroundColor Cyan
            Write-Host "Transfers playback to a different Spotify Connect device." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /transfer <id>    - Transfer to device with specified ID" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /transfer abc123  - Transfer to device with ID 'abc123'" -ForegroundColor Gray
            Write-Host ""
            Write-Host "HOW TO GET DEVICE ID:" -ForegroundColor Yellow
            Write-Host "  1. Run /devices to see available devices" -ForegroundColor Gray
            Write-Host "  2. Copy the device ID from the list" -ForegroundColor Gray
            Write-Host "  3. Use it with /transfer command" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Target device must be active and available" -ForegroundColor Gray
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
        }
        "search" {
            Write-Host "COMMAND: /search <query>" -ForegroundColor Cyan
            Write-Host "======================" -ForegroundColor Cyan
            Write-Host "Searches for tracks, artists, and albums on Spotify." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /search <query>   - Search for music content" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /search bohemian rhapsody" -ForegroundColor Gray
            Write-Host "  /search artist:queen" -ForegroundColor Gray
            Write-Host "  /search album:\"a night at the opera\"" -ForegroundColor Gray
            Write-Host ""
            Write-Host "SEARCH TIPS:" -ForegroundColor Yellow
            Write-Host "  - Use quotes for exact phrases" -ForegroundColor Gray
            Write-Host "  - Use 'artist:', 'album:', 'track:' prefixes for specific searches" -ForegroundColor Gray
            Write-Host "  - Results show URIs that can be used with /play and /queue commands" -ForegroundColor Gray
        }
        "queue" {
            Write-Host "COMMAND: /queue" -ForegroundColor Cyan
            Write-Host "==============" -ForegroundColor Cyan
            Write-Host "Show and manage the playback queue." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /queue              - Show current queue with numbered tracks" -ForegroundColor White
            Write-Host "  /queue <number>     - Add search result #N to queue" -ForegroundColor White
            Write-Host "  /queue <uri>        - Add track to queue by Spotify URI" -ForegroundColor White
            Write-Host ""
            Write-Host "SMART NUMBERS:" -ForegroundColor Yellow
            Write-Host "  After running /queue, tracks are numbered." -ForegroundColor Gray
            Write-Host "  Use 'play-queue <number>' or 'pq <number>' to jump to a track." -ForegroundColor Gray
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /queue          - Show queue" -ForegroundColor Gray
            Write-Host "  /queue 2        - Add search result #2" -ForegroundColor Gray
            Write-Host "  play-queue 3    - Play queue track #3" -ForegroundColor Gray
            Write-Host "  pq 1            - Play next in queue" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
            Write-Host "  - Active device with playback" -ForegroundColor Gray
        }
        "play" {
            Write-Host "COMMAND: /play <type> <uri>" -ForegroundColor Cyan
            Write-Host "==========================" -ForegroundColor Cyan
            Write-Host "Plays specific content immediately." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /play track <uri>     - Play specific track" -ForegroundColor White
            Write-Host "  /play album <uri>     - Play specific album" -ForegroundColor White
            Write-Host "  /play playlist <uri>  - Play specific playlist" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /play track spotify:track:4iV5W9uYEdYUVa79Axb7Rh" -ForegroundColor Gray
            Write-Host "  /play album spotify:album:4aawyAB9vmqN3uQ7FjRGTy" -ForegroundColor Gray
            Write-Host "  /play playlist spotify:playlist:37i9dQZF1DXcBWIGoYBM5M" -ForegroundColor Gray
            Write-Host ""
            Write-Host "HOW TO GET URIs:" -ForegroundColor Yellow
            Write-Host "  - Use /search for tracks and albums" -ForegroundColor Gray
            Write-Host "  - Use /playlists to see your playlists with URIs" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Spotify Premium subscription" -ForegroundColor Gray
            Write-Host "  - Active device" -ForegroundColor Gray
        }
        "playlists" {
            Write-Host "COMMAND: /playlists" -ForegroundColor Cyan
            Write-Host "==================" -ForegroundColor Cyan
            Write-Host "Shows your Spotify playlists." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /playlists        - List all your playlists" -ForegroundColor White
            Write-Host ""
            Write-Host "DISPLAYED INFO:" -ForegroundColor Yellow
            Write-Host "  - Playlist name and description" -ForegroundColor Gray
            Write-Host "  - Number of tracks" -ForegroundColor Gray
            Write-Host "  - Playlist URI (for use with /play playlist command)" -ForegroundColor Gray
            Write-Host "  - Public/private status" -ForegroundColor Gray
            Write-Host ""
            Write-Host "TIP: Copy playlist URIs to use with /play playlist <uri>" -ForegroundColor Gray
        }
        "liked" {
            Write-Host "COMMAND: /liked" -ForegroundColor Cyan
            Write-Host "==============" -ForegroundColor Cyan
            Write-Host "Shows your liked/saved songs." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /liked            - Show your liked songs" -ForegroundColor White
            Write-Host ""
            Write-Host "DISPLAYED INFO:" -ForegroundColor Yellow
            Write-Host "  - Track name and artist" -ForegroundColor Gray
            Write-Host "  - Album name" -ForegroundColor Gray
            Write-Host "  - Date added to liked songs" -ForegroundColor Gray
            Write-Host "  - Track URI" -ForegroundColor Gray
            Write-Host ""
            Write-Host "RELATED COMMANDS:" -ForegroundColor Yellow
            Write-Host "  /save   - Add current track to liked songs" -ForegroundColor Gray
            Write-Host "  /unsave - Remove current track from liked songs" -ForegroundColor Gray
        }
        "recent" {
            Write-Host "COMMAND: /recent" -ForegroundColor Cyan
            Write-Host "===============" -ForegroundColor Cyan
            Write-Host "Shows recently played tracks from Spotify." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /recent           - Show recently played tracks" -ForegroundColor White
            Write-Host ""
            Write-Host "DISPLAYED INFO:" -ForegroundColor Yellow
            Write-Host "  - Track name and artist" -ForegroundColor Gray
            Write-Host "  - Album name" -ForegroundColor Gray
            Write-Host "  - When it was played" -ForegroundColor Gray
            Write-Host "  - Track URI" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTE: This shows Spotify's recent tracks, not local CLI history" -ForegroundColor Gray
            Write-Host "For local history, use /history command" -ForegroundColor Gray
        }
        "save" {
            Write-Host "COMMAND: /save" -ForegroundColor Cyan
            Write-Host "=============" -ForegroundColor Cyan
            Write-Host "Adds the currently playing track to your liked songs." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /save             - Save current track to liked songs" -ForegroundColor White
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - A track must be currently playing" -ForegroundColor Gray
            Write-Host "  - Track must not already be in liked songs" -ForegroundColor Gray
            Write-Host ""
            Write-Host "RELATED COMMANDS:" -ForegroundColor Yellow
            Write-Host "  /unsave - Remove current track from liked songs" -ForegroundColor Gray
            Write-Host "  /liked  - View all your liked songs" -ForegroundColor Gray
        }
        "unsave" {
            Write-Host "COMMAND: /unsave" -ForegroundColor Cyan
            Write-Host "===============" -ForegroundColor Cyan
            Write-Host "Removes the currently playing track from your liked songs." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /unsave           - Remove current track from liked songs" -ForegroundColor White
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - A track must be currently playing" -ForegroundColor Gray
            Write-Host "  - Track must be in your liked songs" -ForegroundColor Gray
            Write-Host ""
            Write-Host "RELATED COMMANDS:" -ForegroundColor Yellow
            Write-Host "  /save  - Add current track to liked songs" -ForegroundColor Gray
            Write-Host "  /liked - View all your liked songs" -ForegroundColor Gray
        }
        "config" {
            Write-Host "COMMAND: /config [key] [value]" -ForegroundColor Cyan
            Write-Host "=============================" -ForegroundColor Cyan
            Write-Host "View or modify CLI configuration settings." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /config           - Show current configuration" -ForegroundColor White
            Write-Host "  /config list      - Show available configuration keys" -ForegroundColor White
            Write-Host "  /config reset     - Reset to default configuration" -ForegroundColor White
            Write-Host "  /config <key> <value> - Set configuration value" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /config CompactMode true" -ForegroundColor Gray
            Write-Host "  /config Colors.Playing Blue" -ForegroundColor Gray
            Write-Host "  /config AutoRefreshInterval 5" -ForegroundColor Gray
        }
        "config-live" {
            Write-Host "COMMAND: /config-live [command] [arguments]" -ForegroundColor Cyan
            Write-Host "=========================================" -ForegroundColor Cyan
            Write-Host "Manage live features configuration (display, lyrics, statistics)." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /config-live show                    - Show current live features config" -ForegroundColor White
            Write-Host "  /config-live set <section.key=value> - Set configuration value" -ForegroundColor White
            Write-Host "  /config-live reset [section]         - Reset to defaults" -ForegroundColor White
            Write-Host "  /config-live schema [section]        - Show valid settings" -ForegroundColor White
            Write-Host "  /config-live backup                  - Create configuration backup" -ForegroundColor White
            Write-Host "  /config-live info                    - Show system information" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /config-live set liveDisplay.refreshInterval=1500" -ForegroundColor Gray
            Write-Host "  /config-live set lyrics.preferredProvider=genius" -ForegroundColor Gray
            Write-Host "  /config-live reset liveDisplay" -ForegroundColor Gray
            Write-Host "  /config-live schema lyrics" -ForegroundColor Gray
            Write-Host ""
            Write-Host "SECTIONS:" -ForegroundColor Yellow
            Write-Host "  liveDisplay - Real-time display settings" -ForegroundColor White
            Write-Host "  lyrics      - Lyrics fetching and display" -ForegroundColor White
            Write-Host "  statistics  - Data collection and analytics" -ForegroundColor White
            Write-Host "  apiClient   - API client configuration" -ForegroundColor White
            Write-Host ""
            Write-Host "MAIN SETTINGS:" -ForegroundColor Yellow
            Write-Host "  CompactMode, NotificationsEnabled, LoggingEnabled" -ForegroundColor Gray
            Write-Host "  AutoRefreshInterval, HistoryEnabled, MaxHistoryEntries" -ForegroundColor Gray
            Write-Host "  Colors.* (Playing, Paused, Track, Artist, Album, Progress)" -ForegroundColor Gray
        }
        "history" {
            Write-Host "COMMAND: /history" -ForegroundColor Cyan
            Write-Host "================" -ForegroundColor Cyan
            Write-Host "Shows local playback history tracked by the CLI." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /history          - Show recent playback history" -ForegroundColor White
            Write-Host ""
            Write-Host "DISPLAYED INFO:" -ForegroundColor Yellow
            Write-Host "  - Track name and artist" -ForegroundColor Gray
            Write-Host "  - Album name" -ForegroundColor Gray
            Write-Host "  - When it was played (local time)" -ForegroundColor Gray
            Write-Host "  - Duration" -ForegroundColor Gray
            Write-Host ""
            Write-Host "CONFIGURATION:" -ForegroundColor Yellow
            Write-Host "  - Enable/disable: /config HistoryEnabled true/false" -ForegroundColor Gray
            Write-Host "  - Max entries: /config MaxHistoryEntries <number>" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTE: This is different from /recent (Spotify's recent tracks)" -ForegroundColor Gray
        }
        "notifications" {
            Write-Host "COMMAND: /notifications <on|off>" -ForegroundColor Cyan
            Write-Host "===============================" -ForegroundColor Cyan
            Write-Host "Enable or disable Windows toast notifications for track changes." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /notifications on  - Enable notifications" -ForegroundColor White
            Write-Host "  /notifications off - Disable notifications" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /notifications on" -ForegroundColor Gray
            Write-Host "  /notifications off" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Windows 10/11 with toast notification support" -ForegroundColor Gray
            Write-Host "  - Notification permissions for PowerShell" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTE: Can also be configured via /config NotificationsEnabled true/false" -ForegroundColor Gray
        }
        "auto-refresh" {
            Write-Host "COMMAND: /auto-refresh <seconds>" -ForegroundColor Cyan
            Write-Host "===============================" -ForegroundColor Cyan
            Write-Host "Automatically refresh the display at specified intervals." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /auto-refresh <seconds> - Set refresh interval (0 to disable)" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /auto-refresh 5   - Refresh every 5 seconds" -ForegroundColor Gray
            Write-Host "  /auto-refresh 0   - Disable auto-refresh" -ForegroundColor Gray
            Write-Host ""
            Write-Host "BEHAVIOR:" -ForegroundColor Yellow
            Write-Host "  - Shows current track info at specified intervals" -ForegroundColor Gray
            Write-Host "  - Press any key to interrupt and return to command mode" -ForegroundColor Gray
            Write-Host "  - Useful for monitoring playback without manual commands" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTE: Can also be configured via /config AutoRefreshInterval <seconds>" -ForegroundColor Gray
        }
        "live" {
            Write-Host "COMMAND: /live [mode]" -ForegroundColor Cyan
            Write-Host "====================" -ForegroundColor Cyan
            Write-Host "Start real-time live display mode with continuous track updates." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /live              - Start live display in detailed mode" -ForegroundColor White
            Write-Host "  /live detailed     - Start with detailed track information" -ForegroundColor White
            Write-Host "  /live compact      - Start with compact single-line display" -ForegroundColor White
            Write-Host "  /live minimal      - Start with minimal display" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /live" -ForegroundColor Gray
            Write-Host "  /live compact" -ForegroundColor Gray
            Write-Host "  /live minimal" -ForegroundColor Gray
            Write-Host ""
            Write-Host "FEATURES:" -ForegroundColor Yellow
            Write-Host "  - Real-time track information updates" -ForegroundColor Gray
            Write-Host "  - Animated progress bar" -ForegroundColor Gray
            Write-Host "  - Automatic refresh every second" -ForegroundColor Gray
            Write-Host "  - Graceful exit with Ctrl+C" -ForegroundColor Gray
            Write-Host ""
            Write-Host "STARTUP OPTION:" -ForegroundColor Yellow
            Write-Host "  You can also start the CLI directly in live mode:" -ForegroundColor Gray
            Write-Host "  .\\spotifyCLI.ps1 -Live -LiveMode compact" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Active Spotify device with current playback" -ForegroundColor Gray
            Write-Host "  - Terminal that supports ANSI escape codes (recommended)" -ForegroundColor Gray
        }
        "sidecar" {
            Write-Host "COMMAND: /sidecar [options]" -ForegroundColor Cyan
            Write-Host "=========================" -ForegroundColor Cyan
            Write-Host "Launch Spotify CLI in a split window or sidecar mode." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /sidecar           - Launch in sidecar with default settings" -ForegroundColor White
            Write-Host "  /sidecar live      - Launch sidecar in live display mode" -ForegroundColor White
            Write-Host "  /sidecar compact   - Launch sidecar with compact live display" -ForegroundColor White
            Write-Host "  /sidecar right     - Launch sidecar split to the right" -ForegroundColor White
            Write-Host "  /sidecar down live - Launch sidecar below with live mode" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /sidecar" -ForegroundColor Gray
            Write-Host "  /sidecar live" -ForegroundColor Gray
            Write-Host "  /sidecar compact right" -ForegroundColor Gray
            Write-Host "  /sidecar down minimal" -ForegroundColor Gray
            Write-Host ""
            Write-Host "OPTIONS:" -ForegroundColor Yellow
            Write-Host "  Live Modes: detailed, compact, minimal" -ForegroundColor Gray
            Write-Host "  Split Directions: right, down, left, up" -ForegroundColor Gray
            Write-Host "  Keywords: live (enables live display mode)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "STARTUP OPTIONS:" -ForegroundColor Yellow
            Write-Host "  You can also start directly in sidecar mode:" -ForegroundColor Gray
            Write-Host "  .\\spotifyCLI.ps1 -Sidecar -Live -LiveMode compact" -ForegroundColor Gray
            Write-Host ""
            Write-Host "SUPPORTED TERMINALS:" -ForegroundColor Yellow
            Write-Host "  - Windows Terminal (recommended)" -ForegroundColor Gray
            Write-Host "  - VS Code integrated terminal" -ForegroundColor Gray
            Write-Host "  - Falls back to new window if split not supported" -ForegroundColor Gray
        }
        "peak" {
            Write-Host "COMMAND: /peak" -ForegroundColor Cyan
            Write-Host "==============" -ForegroundColor Cyan
            Write-Host "Track insights dashboard for the currently playing track." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /peak              - Open the Peak Dashboard window" -ForegroundColor White
            Write-Host ""
            Write-Host "METRICS SHOWN:" -ForegroundColor Yellow
            Write-Host "  Track Popularity  - How popular the track is (0-100)" -ForegroundColor Gray
            Write-Host "  Artist Popularity - How popular the artist is (0-100)" -ForegroundColor Gray
            Write-Host "  Followers         - Artist follower count" -ForegroundColor Gray
            Write-Host "  Duration          - Track length" -ForegroundColor Gray
            Write-Host "  Album             - Album name, release date, track number" -ForegroundColor Gray
            Write-Host "  Genres            - Artist genres" -ForegroundColor Gray
            Write-Host ""
            Write-Host "FEATURES:" -ForegroundColor Yellow
            Write-Host "  - Auto-updates when track changes" -ForegroundColor Gray
            Write-Host "  - Mini-graph showing popularity of last 10 tracks" -ForegroundColor Gray
            Write-Host "  - Always-on-top dark-themed window" -ForegroundColor Gray
        }
        "setlist" {
            Write-Host "COMMAND: /setlist <artist>" -ForegroundColor Cyan
            Write-Host "========================" -ForegroundColor Cyan
            Write-Host "Find concert setlists and create Spotify playlists from them." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /setlist <artist>  - Search for recent concerts by artist" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /setlist Tame Impala    - Find Tame Impala's recent setlists" -ForegroundColor Gray
            Write-Host "  /setlist Metallica      - Find Metallica's recent setlists" -ForegroundColor Gray
            Write-Host "  /setlist Taylor Swift   - Find Taylor Swift's recent setlists" -ForegroundColor Gray
            Write-Host ""
            Write-Host "HOW IT WORKS:" -ForegroundColor Yellow
            Write-Host "  1. Searches setlist.fm for the artist's recent concerts" -ForegroundColor Gray
            Write-Host "  2. Shows up to 5 concerts with venue, date, and song count" -ForegroundColor Gray
            Write-Host "  3. Pick a concert to see the full setlist" -ForegroundColor Gray
            Write-Host "  4. Optionally create a Spotify playlist from the setlist" -ForegroundColor Gray
            Write-Host "  5. Matched songs are added, missing ones are reported" -ForegroundColor Gray
            Write-Host ""
            Write-Host "SETUP:" -ForegroundColor Yellow
            Write-Host "  Requires a free setlist.fm API key:" -ForegroundColor Gray
            Write-Host "  1. Register at https://api.setlist.fm" -ForegroundColor Gray
            Write-Host "  2. Add to .env: SETLISTFM_API_KEY=your_key_here" -ForegroundColor Gray
        }
        "quiz" {
            Write-Host "COMMAND: /quiz [rounds]" -ForegroundColor Cyan
            Write-Host "======================" -ForegroundColor Cyan
            Write-Host "Music quiz! Guess songs from short snippets of your liked tracks." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /quiz             - Start a 5-round quiz (default)" -ForegroundColor White
            Write-Host "  /quiz <N>         - Start a quiz with N rounds (1-20)" -ForegroundColor White
            Write-Host ""
            Write-Host "EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  /quiz             - Play 5 rounds with 5-second snippets" -ForegroundColor Gray
            Write-Host "  /quiz 10          - Play 10 rounds" -ForegroundColor Gray
            Write-Host ""
            Write-Host "SCORING:" -ForegroundColor Yellow
            Write-Host "  Exact title match:   20 points" -ForegroundColor Gray
            Write-Host "  Exact artist match:  10 points" -ForegroundColor Gray
            Write-Host "  Partial match:        5 points" -ForegroundColor Gray
            Write-Host ""
            Write-Host "HOW IT WORKS:" -ForegroundColor Yellow
            Write-Host "  - Picks random songs from your liked tracks" -ForegroundColor Gray
            Write-Host "  - Plays a 5-second snippet from the middle of each song" -ForegroundColor Gray
            Write-Host "  - You type your guess (song title or artist name)" -ForegroundColor Gray
            Write-Host "  - Highscores are saved per round count" -ForegroundColor Gray
            Write-Host ""
            Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
            Write-Host "  - Active Spotify device" -ForegroundColor Gray
            Write-Host "  - At least as many liked songs as quiz rounds" -ForegroundColor Gray
        }
        "quit" {
            Write-Host "COMMAND: /quit" -ForegroundColor Cyan
            Write-Host "=============" -ForegroundColor Cyan
            Write-Host "Exits the Spotify CLI application." -ForegroundColor White
            Write-Host ""
            Write-Host "USAGE:" -ForegroundColor Yellow
            Write-Host "  /quit             - Exit the CLI" -ForegroundColor White
            Write-Host ""
            Write-Host "ALIASES:" -ForegroundColor Yellow
            Write-Host "  /exit, /q         - Same as /quit" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTE: All configuration and history are automatically saved" -ForegroundColor Gray
        }
        default {
            Write-Host "Unknown command: $command" -ForegroundColor Red
            Write-Host ""
            Write-Host "Available commands for detailed help:" -ForegroundColor Yellow
            $availableCommands = @(
                "spotify", "seek", "volume", "shuffle", "repeat",
                "devices", "transfer", "search", "queue", "play",
                "playlists", "liked", "recent", "save", "unsave",
                "config", "config-live", "history", "notifications", "auto-refresh", "live", "sidecar", "quiz", "peak", "setlist", "quit"
            )
            $availableCommands | ForEach-Object {
                Write-Host "  /help $_" -ForegroundColor Gray
            }
            Write-Host ""
            Write-Host "Use /help without arguments to see the general command overview." -ForegroundColor Gray
        }
    }
}

function Invoke-ConfigCommand {
    param([string]$Arguments)
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        # Show current configuration
        $config = Get-SpotifyConfig
        Write-Host "Current Spotify CLI Configuration:" -ForegroundColor Cyan
        Write-Host "=================================" -ForegroundColor Cyan
        Write-Host "PreferredDevice: $($config.PreferredDevice ?? 'None')" -ForegroundColor White
        Write-Host "CompactMode: $($config.CompactMode)" -ForegroundColor White
        Write-Host "NotificationsEnabled: $($config.NotificationsEnabled)" -ForegroundColor White
        Write-Host "AutoRefreshInterval: $($config.AutoRefreshInterval) seconds" -ForegroundColor White
        Write-Host "LoggingEnabled: $($config.LoggingEnabled)" -ForegroundColor White
        Write-Host "HistoryEnabled: $($config.HistoryEnabled)" -ForegroundColor White
        Write-Host "MaxHistoryEntries: $($config.MaxHistoryEntries)" -ForegroundColor White
        Write-Host "Colors:" -ForegroundColor White
        $config.Colors.GetEnumerator() | Sort-Object Key | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "Usage: /config <key> <value> - Set a configuration value" -ForegroundColor Gray
        Write-Host "       /config reset - Reset to default configuration" -ForegroundColor Gray
        Write-Host "       /config list - Show available configuration keys" -ForegroundColor Gray
        return
    }
    
    $parts = $Arguments.Trim() -split '\s+', 2
    $key = $parts[0]
    $value = if ($parts.Length -gt 1) { $parts[1] } else { $null }
    
    if ($key -eq "reset") {
        if (Set-SpotifyConfig -Config $DefaultConfig.Clone()) {
            Write-Host "Configuration reset to defaults." -ForegroundColor Green
        }
        return
    }
    
    if ($key -eq "list") {
        Write-Host "Available configuration keys:" -ForegroundColor Cyan
        Write-Host "============================" -ForegroundColor Cyan
        Write-Host "PreferredDevice - Set preferred Spotify device (string or null)" -ForegroundColor White
        Write-Host "CompactMode - Enable compact display mode (true/false)" -ForegroundColor White
        Write-Host "NotificationsEnabled - Enable Windows notifications (true/false)" -ForegroundColor White
        Write-Host "AutoRefreshInterval - Auto-refresh interval in seconds (number)" -ForegroundColor White
        Write-Host "LoggingEnabled - Enable debug logging (true/false)" -ForegroundColor White
        Write-Host "HistoryEnabled - Enable playback history tracking (true/false)" -ForegroundColor White
        Write-Host "MaxHistoryEntries - Maximum history entries to keep (number)" -ForegroundColor White
        Write-Host "Colors.* - Color settings for different elements:" -ForegroundColor White
        Write-Host "  Colors.Playing, Colors.Paused, Colors.Track, Colors.Artist, Colors.Album, Colors.Progress" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Valid colors: Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White" -ForegroundColor Gray
        return
    }
    
    if ($null -eq $value) {
        Write-Error "Please provide a value for '$key'. Usage: /config <key> <value>"
        return
    }
    
    $config = Get-SpotifyConfig
    
    # Handle special cases for value parsing
    switch ($key) {
        "CompactMode" { 
            $value = $value.ToLower() -in @("true", "1", "yes", "on")
        }
        "NotificationsEnabled" { 
            $value = $value.ToLower() -in @("true", "1", "yes", "on")
        }
        "LoggingEnabled" { 
            $value = $value.ToLower() -in @("true", "1", "yes", "on")
        }
        "HistoryEnabled" { 
            $value = $value.ToLower() -in @("true", "1", "yes", "on")
        }
        "AutoRefreshInterval" { 
            try { $value = [int]$value } catch { Write-Error "AutoRefreshInterval must be a number"; return }
        }
        "MaxHistoryEntries" { 
            try { $value = [int]$value } catch { Write-Error "MaxHistoryEntries must be a number"; return }
        }
        "PreferredDevice" {
            if ($value.ToLower() -in @("null", "none", "")) { $value = $null }
        }
    }
    
    # Handle color configuration
    if ($key -like "Colors.*") {
        $colorKey = $key.Substring(7) # Remove "Colors." prefix
        if (-not $config.Colors.ContainsKey($colorKey)) {
            Write-Error "Unknown color setting '$colorKey'. Available: $($config.Colors.Keys -join ', ')"
            return
        }
        if (-not (Test-SpotifyConfigValue -Key "Colors" -Value @{$colorKey = $value})) {
            Write-Error "Invalid color value '$value'. Valid colors: Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White"
            return
        }
        $config.Colors[$colorKey] = $value
    } else {
        # Validate the configuration value
        if (-not (Test-SpotifyConfigValue -Key $key -Value $value)) {
            Write-Error "Invalid value '$value' for configuration key '$key'"
            return
        }
        
        if (-not $config.ContainsKey($key)) {
            Write-Error "Unknown configuration key '$key'. Available keys: $($config.Keys -join ', '), Colors.*"
            return
        }
        
        $config[$key] = $value
    }
    
    if (Set-SpotifyConfig -Config $config) {
        Write-Host "Configuration updated: $key = $value" -ForegroundColor Green
    }
}

function Invoke-LiveFeaturesConfigCommand {
    param([string]$Arguments)
    
    # Import the configuration modules if not already loaded
    $configModulePath = Join-Path $PSScriptRoot "modules\Core\ConfigurationCommands.psm1"
    if (Test-Path $configModulePath) {
        try {
            Import-Module $configModulePath -Force -Global -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Could not load live features configuration module: $($_.Exception.Message)"
            Write-Host "Live features configuration is not available." -ForegroundColor Yellow
            return
        }
    } else {
        Write-Host "Live features configuration module not found." -ForegroundColor Yellow
        Write-Host "Please ensure the live features modules are properly installed." -ForegroundColor Gray
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        # Show current live features configuration
        try {
            Get-LiveFeaturesConfig
        } catch {
            Write-Warning "Failed to load live features configuration: $($_.Exception.Message)"
            Write-Host "💡 Try running: /config-live info" -ForegroundColor Yellow
        }
        return
    }
    
    # Parse arguments
    $argParts = $Arguments.Trim() -split '\s+', 2
    $command = $argParts[0].ToLower()
    $commandArgs = if ($argParts.Length -gt 1) { $argParts[1] } else { "" }
    
    try {
        switch ($command) {
            "show" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Get-LiveFeaturesConfig
                } else {
                    $parts = $commandArgs -split '\.'
                    if ($parts.Length -eq 1) {
                        Get-LiveFeaturesConfig -Section $parts[0]
                    } elseif ($parts.Length -eq 2) {
                        Get-LiveFeaturesConfig -Section $parts[0] -Key $parts[1]
                    } else {
                        Write-Error "Invalid format. Use 'section' or 'section.key'"
                    }
                }
            }
            
            "set" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Write-Error "Missing arguments. Use format: section.key=value"
                    Write-Host "Example: /config-live set liveDisplay.refreshInterval=1500" -ForegroundColor Gray
                    return
                }
                
                if ($commandArgs -match '^([^.]+)\.([^=]+)=(.+)$') {
                    $section = $matches[1]
                    $key = $matches[2]
                    $valueStr = $matches[3]
                    
                    # Parse value based on type
                    $value = ConvertTo-ConfigValue -ValueString $valueStr
                    
                    Set-LiveFeaturesConfig -Section $section -Key $key -Value $value
                } else {
                    Write-Error "Invalid format. Use: section.key=value"
                    Write-Host "Example: /config-live set liveDisplay.refreshInterval=1500" -ForegroundColor Gray
                }
            }
            
            "reset" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Reset-LiveFeaturesConfig
                } else {
                    Reset-LiveFeaturesConfig -Section $commandArgs
                }
            }
            
            "schema" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Get-LiveFeaturesConfigSchema
                } else {
                    Get-LiveFeaturesConfigSchema -Section $commandArgs
                }
            }
            
            "backup" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Backup-LiveFeaturesConfig
                } else {
                    Backup-LiveFeaturesConfig -Path $commandArgs
                }
            }
            
            "restore" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Write-Error "Missing backup file path"
                    Write-Host "Usage: /config-live restore <backup-file-path>" -ForegroundColor Gray
                } else {
                    Restore-LiveFeaturesConfig -Path $commandArgs
                }
            }
            
            "export" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Export-LiveFeaturesConfig
                } else {
                    Export-LiveFeaturesConfig -Path $commandArgs
                }
            }
            
            "import" {
                if ([string]::IsNullOrWhiteSpace($commandArgs)) {
                    Write-Error "Missing configuration file path"
                    Write-Host "Usage: /config-live import <config-file-path>" -ForegroundColor Gray
                } else {
                    Import-LiveFeaturesConfig -Path $commandArgs
                }
            }
            
            "test" {
                Test-LiveFeaturesConfig
            }
            
            "info" {
                Get-LiveFeaturesConfigInfo
            }
            
            "help" {
                Write-Host "Live Features Configuration Commands" -ForegroundColor Cyan
                Write-Host "====================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "COMMANDS:" -ForegroundColor Yellow
                Write-Host "  show [section[.key]]     - Display configuration" -ForegroundColor White
                Write-Host "  set section.key=value    - Set configuration value" -ForegroundColor White
                Write-Host "  reset [section]          - Reset to defaults" -ForegroundColor White
                Write-Host "  schema [section]         - Show valid settings" -ForegroundColor White
                Write-Host "  backup [path]            - Create backup" -ForegroundColor White
                Write-Host "  restore <path>           - Restore from backup" -ForegroundColor White
                Write-Host "  export [path]            - Export configuration" -ForegroundColor White
                Write-Host "  import <path>            - Import configuration" -ForegroundColor White
                Write-Host "  test                     - Validate configuration" -ForegroundColor White
                Write-Host "  info                     - Show system information" -ForegroundColor White
                Write-Host "  help                     - Show this help" -ForegroundColor White
                Write-Host ""
                Write-Host "EXAMPLES:" -ForegroundColor Yellow
                Write-Host "  /config-live show" -ForegroundColor Gray
                Write-Host "  /config-live set liveDisplay.refreshInterval=1500" -ForegroundColor Gray
                Write-Host "  /config-live reset liveDisplay" -ForegroundColor Gray
                Write-Host "  /config-live backup" -ForegroundColor Gray
            }
            
            default {
                Write-Error "Unknown command: $command"
                Write-Host "Use '/config-live help' to see available commands" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Error "Live features configuration command failed: $($_.Exception.Message)"
        Write-Host "💡 Use '/config-live info' to check system status" -ForegroundColor Yellow
    }
}

function ConvertTo-ConfigValue {
    <#
    .SYNOPSIS
    Convert string value to appropriate type for configuration
    #>
    param([string]$ValueString)
    
    # Try to parse as boolean
    if ($ValueString -eq "true" -or $ValueString -eq "True" -or $ValueString -eq "TRUE") {
        return $true
    }
    if ($ValueString -eq "false" -or $ValueString -eq "False" -or $ValueString -eq "FALSE") {
        return $false
    }
    
    # Try to parse as integer
    if ($ValueString -match '^\d+$') {
        return [int]$ValueString
    }
    
    # Return as string
    return $ValueString
}

#endregion Hjälpfunktioner

#region Spotify-kommandon
function Show-CurrentTrack {
    param([string]$Arguments)
    
    # Check if compact mode is requested
    $compactMode = $Arguments -and $Arguments.Trim().ToLower() -eq "compact"
    
    try {
        $resp = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
    }
    catch {
        Handle-SpotifyError -ErrorRecord $_ -Context "getting current track" -ShowSuggestions $true
        return
    }
    
    if (-not $resp) {
        Write-Host "Ingen uppspelning hittades." -ForegroundColor Yellow
        return
    }

    # Check for track changes and show notifications if enabled
    Update-TrackNotification -CurrentTrack $resp

    # Check if compact mode is enabled via configuration or parameter
    $config = Get-SpotifyConfig
    $useCompactMode = $compactMode -or $config.CompactMode
    
    if ($useCompactMode) {
        Show-CompactTrack -TrackData $resp
        return
    }

    $isPlaying = $resp.is_playing
    $progress = $resp.progress_ms
    $item = $resp.item
    $device = $resp.device
    
    if (-not $item) { 
        Write-Host "Ingen låtinfo tillgänglig." -ForegroundColor Yellow
        return 
    }

    $name = $item.name
    $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
    $album = $item.album.name
    $duration = $item.duration_ms

    # Use color coding system based on configuration
    Write-Host "🎵 $name" -ForegroundColor (Get-TrackColor)
    Write-Host "👤 $artists" -ForegroundColor (Get-ArtistColor)
    Write-Host "📀 $album" -ForegroundColor (Get-AlbumColor)
    
    # Create and display progress bar with time information
    $progressBar = Show-ProgressBar -Current $progress -Total $duration -Width 30
    $timeInfo = "{0} / {1}" -f (Format-Time $progress), (Format-Time $duration)
    $playbackStatus = if ($isPlaying) { "(spelar)" } else { "(paus)" }
    
    # Use status-based color for time and progress information
    $statusColor = Get-StatusColor -IsPlaying $isPlaying
    $progressColor = Get-ProgressColor
    
    Write-Host "⏱ $timeInfo $playbackStatus" -ForegroundColor $statusColor
    Write-Host "   $progressBar" -ForegroundColor $progressColor
    
    # Display device information if available
    if ($device) {
        $deviceIcon = switch ($device.type.ToLower()) {
            "computer" { "💻" }
            "smartphone" { "📱" }
            "speaker" { "🔊" }
            "tv" { "📺" }
            "automobile" { "🚗" }
            "cast_video" { "📺" }
            "cast_audio" { "🔊" }
            "tablet" { "📱" }
            "game_console" { "🎮" }
            default { "🎵" }
        }
        
        $volumeInfo = if ($device.volume_percent -ne $null) {
            " (Volume: $($device.volume_percent)%)"
        } else {
            ""
        }
        
        Write-Host "$deviceIcon $($device.name)$volumeInfo" -ForegroundColor Gray
    }
}

function Skip-ToNextTrack {
    try {
        Invoke-SpotifyApi -Method POST -Path "/me/player/next" | Out-Null
        Write-Host "⏭️ Nästa låt." -ForegroundColor Green
        
        # Wait a moment for the track to change, then check for notifications
        Start-Sleep -Milliseconds 500
        try {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            Update-TrackNotification -CurrentTrack $currentTrack
        } catch {
            # Ignore errors when checking for notifications
        }
    }
    catch { 
        Handle-SpotifyError -ErrorRecord $_ -Context "skipping to next track" -ShowSuggestions $true
    }
}

function Skip-ToPreviousTrack {
    try {
        Invoke-SpotifyApi -Method POST -Path "/me/player/previous" | Out-Null
        Write-Host "⏮️ Föregående låt." -ForegroundColor Green
        
        # Wait a moment for the track to change, then check for notifications
        Start-Sleep -Milliseconds 500
        try {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            Update-TrackNotification -CurrentTrack $currentTrack
        } catch {
            # Ignore errors when checking for notifications
        }
    }
    catch { 
        Handle-SpotifyError -ErrorRecord $_ -Context "going to previous track" -ShowSuggestions $true
    }
}

function Stop-SpotifyPlayback {
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
        Write-Host "⏸️ Pausad." -ForegroundColor Yellow
    }
    catch { 
        Handle-SpotifyError -ErrorRecord $_ -Context "pausing playback" -ShowSuggestions $true
    }
}

function Start-SpotifyPlayback {
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" | Out-Null
        Write-Host "▶️ Spelar." -ForegroundColor Green
    }
    catch { 
        Handle-SpotifyError -ErrorRecord $_ -Context "starting playback" -ShowSuggestions $true
    }
}

function Invoke-SeekCommand {
    param([string]$Arguments)
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        Write-Error "Please provide seek time in seconds. Usage: /seek <seconds> (positive for forward, negative for backward)"
        return
    }
    
    try {
        $seekSeconds = [int]$Arguments
    }
    catch {
        Write-Error "Invalid seek time '$Arguments'. Please provide a number (positive for forward, negative for backward)"
        return
    }
    
    try {
        # Get current playback state to calculate new position
        $currentState = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        
        if (-not $currentState -or -not $currentState.item) {
            Write-Warning "No track currently playing. Cannot seek."
            return
        }
        
        $currentProgress = $currentState.progress_ms
        $trackDuration = $currentState.item.duration_ms
        $seekMs = $seekSeconds * 1000
        $newPosition = $currentProgress + $seekMs
        
        # Validate new position bounds
        if ($newPosition -lt 0) {
            $newPosition = 0
            Write-Warning "Seeking to beginning of track (cannot seek before start)"
        }
        elseif ($newPosition -gt $trackDuration) {
            Write-Warning "Cannot seek beyond track duration. Skipping to next track instead."
            Skip-ToNextTrack
            return
        }
        
        # Perform the seek operation
        $query = @{ position_ms = $newPosition }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/seek" -Query $query | Out-Null
        
        $direction = if ($seekSeconds -gt 0) { "forward" } else { "backward" }
        $timeStr = Format-Time $newPosition
        Write-Host "⏩ Seeked $direction $([Math]::Abs($seekSeconds)) seconds to $timeStr" -ForegroundColor Green
    }
    catch {
        Handle-SpotifyError -ErrorRecord $_ -Context "seeking in track" -ShowSuggestions $true
    }
}

function Invoke-VolumeCommand {
    param([string]$Arguments)
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        Write-Error "Please provide volume level (0-100). Usage: /volume <0-100>"
        return
    }
    
    try {
        $volumeLevel = [int]$Arguments
    }
    catch {
        Write-Error "Invalid volume level '$Arguments'. Please provide a number between 0 and 100"
        return
    }
    
    # Validate volume range
    if ($volumeLevel -lt 0 -or $volumeLevel -gt 100) {
        Write-Error "Volume level must be between 0 and 100. Provided: $volumeLevel"
        return
    }
    
    try {
        # Set volume using Spotify API
        $query = @{ volume_percent = $volumeLevel }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/volume" -Query $query | Out-Null
        
        $volumeIcon = if ($volumeLevel -eq 0) { "🔇" } 
                     elseif ($volumeLevel -lt 30) { "🔈" }
                     elseif ($volumeLevel -lt 70) { "🔉" }
                     else { "🔊" }
        
        Write-Host "$volumeIcon Volume set to $volumeLevel%" -ForegroundColor Green
    }
    catch {
        Handle-SpotifyError -ErrorRecord $_ -Context "setting volume" -ShowSuggestions $true
    }
}

function Invoke-ShuffleCommand {
    param([string]$Arguments)
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        Write-Error "Please specify shuffle state. Usage: /shuffle on|off"
        return
    }
    
    $shuffleState = $Arguments.Trim().ToLower()
    
    if ($shuffleState -notin @("on", "off", "true", "false", "1", "0")) {
        Write-Error "Invalid shuffle state '$Arguments'. Use: on, off, true, false, 1, or 0"
        return
    }
    
    # Convert to boolean
    $enableShuffle = $shuffleState -in @("on", "true", "1")
    
    try {
        # Set shuffle state using Spotify API
        $query = @{ state = $enableShuffle.ToString().ToLower() }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/shuffle" -Query $query | Out-Null
        
        $shuffleIcon = if ($enableShuffle) { "🔀" } else { "➡️" }
        $stateText = if ($enableShuffle) { "enabled" } else { "disabled" }
        
        Write-Host "$shuffleIcon Shuffle $stateText" -ForegroundColor Green
    }
    catch {
        Handle-SpotifyError -ErrorRecord $_ -Context "setting shuffle mode" -ShowSuggestions $true
    }
}

function Invoke-RepeatCommand {
    param([string]$Arguments)
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        Write-Error "Please specify repeat mode. Usage: /repeat track|context|off"
        return
    }
    
    $repeatMode = $Arguments.Trim().ToLower()
    
    if ($repeatMode -notin @("track", "context", "off")) {
        Write-Error "Invalid repeat mode '$Arguments'. Use: track, context, or off"
        return
    }
    
    try {
        # Set repeat state using Spotify API
        $query = @{ state = $repeatMode }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/repeat" -Query $query | Out-Null
        
        $repeatIcon = switch ($repeatMode) {
            "track" { "🔂" }
            "context" { "🔁" }
            "off" { "➡️" }
        }
        
        $modeText = switch ($repeatMode) {
            "track" { "current track" }
            "context" { "playlist/album" }
            "off" { "disabled" }
        }
        
        Write-Host "$repeatIcon Repeat $modeText" -ForegroundColor Green
    }
    catch {
        Handle-SpotifyError -ErrorRecord $_ -Context "setting repeat mode" -ShowSuggestions $true
    }
}

function Invoke-DevicesCommand {
    try {
        $devicesResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/devices"
        
        if (-not $devicesResponse -or -not $devicesResponse.devices -or $devicesResponse.devices.Count -eq 0) {
            Write-Host "No Spotify Connect devices found." -ForegroundColor Yellow
            Write-Host "Make sure Spotify is open on at least one device (phone, computer, speaker, etc.)" -ForegroundColor Gray
            return
        }
        
        Write-Host "Available Spotify Connect Devices:" -ForegroundColor Cyan
        Write-Host "==================================" -ForegroundColor Cyan
        
        foreach ($device in $devicesResponse.devices) {
            $deviceIcon = switch ($device.type.ToLower()) {
                "computer" { "💻" }
                "smartphone" { "📱" }
                "speaker" { "🔊" }
                "tv" { "📺" }
                "automobile" { "🚗" }
                "cast_video" { "📺" }
                "cast_audio" { "🔊" }
                "tablet" { "📱" }
                "game_console" { "🎮" }
                default { "🎵" }
            }
            
            $activeStatus = if ($device.is_active) { 
                "[ACTIVE]" 
            } else { 
                "[INACTIVE]" 
            }
            
            $volumeInfo = if ($device.volume_percent -ne $null) {
                " - Volume: $($device.volume_percent)%"
            } else {
                ""
            }
            
            $restrictedInfo = if ($device.is_restricted) {
                " (Restricted)"
            } else {
                ""
            }
            
            $statusColor = if ($device.is_active) { "Green" } else { "White" }
            
            Write-Host "$deviceIcon $($device.name) $activeStatus" -ForegroundColor $statusColor
            Write-Host "   Type: $($device.type)$volumeInfo$restrictedInfo" -ForegroundColor Gray
            Write-Host "   ID: $($device.id)" -ForegroundColor DarkGray
            Write-Host ""
        }
        
        Write-Host "Use '/transfer <device_id>' to switch playback to a specific device" -ForegroundColor Gray
    }
    catch {
        Handle-SpotifyError -ErrorRecord $_ -Context "retrieving devices" -ShowSuggestions $true
    }
}

function Invoke-TransferCommand {
    param([string]$Arguments)
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        Write-Error "Please provide a device ID. Usage: /transfer <device_id>"
        Write-Host "Use '/devices' to see available devices and their IDs" -ForegroundColor Gray
        return
    }
    
    $deviceId = $Arguments.Trim()
    
    try {
        # First, get available devices to validate the device ID
        $devicesResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/devices"
        
        if (-not $devicesResponse -or -not $devicesResponse.devices -or $devicesResponse.devices.Count -eq 0) {
            Write-Warning "No Spotify Connect devices found. Make sure Spotify is open on at least one device"
            return
        }
        
        # Find the target device
        $targetDevice = $devicesResponse.devices | Where-Object { $_.id -eq $deviceId }
        
        if (-not $targetDevice) {
            Write-Error "Device ID '$deviceId' not found in available devices"
            Write-Host "Available device IDs:" -ForegroundColor Gray
            foreach ($device in $devicesResponse.devices) {
                Write-Host "  $($device.id) - $($device.name)" -ForegroundColor Gray
            }
            return
        }
        
        # Check if device is already active
        if ($targetDevice.is_active) {
            Write-Host "🎵 Device '$($targetDevice.name)' is already the active playback device" -ForegroundColor Yellow
            return
        }
        
        # Check if device is restricted
        if ($targetDevice.is_restricted) {
            Write-Warning "Device '$($targetDevice.name)' is restricted and may not accept playback transfer"
        }
        
        # Transfer playback to the device
        $transferBody = @{
            device_ids = @($deviceId)
            play = $true  # Continue playback on the new device
        }
        
        Invoke-SpotifyApi -Method PUT -Path "/me/player" -Body $transferBody | Out-Null
        
        $deviceIcon = switch ($targetDevice.type.ToLower()) {
            "computer" { "💻" }
            "smartphone" { "📱" }
            "speaker" { "🔊" }
            "tv" { "📺" }
            "automobile" { "🚗" }
            "cast_video" { "📺" }
            "cast_audio" { "🔊" }
            "tablet" { "📱" }
            "game_console" { "🎮" }
            default { "🎵" }
        }
        
        Write-Host "$deviceIcon Playback transferred to '$($targetDevice.name)'" -ForegroundColor Green
        
        # Brief pause to allow the transfer to complete
        Start-Sleep -Milliseconds 500
        
        # Show current track on the new device
        Write-Host ""
        Show-CurrentTrack
    }
    catch {
        Handle-SpotifyError -ErrorRecord $_ -Context "transferring playback to device" -ShowSuggestions $true
    }
}

function Invoke-SearchCommand {
    param([string]$Arguments)
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        Write-Error "Please provide a search query. Usage: /search <query>"
        return
    }
    
    try {
        # Search for tracks, artists, and albums
        $query = @{
            q = $Arguments.Trim()
            type = "track,artist,album"
            limit = 10
        }
        
        $searchResults = Invoke-SpotifyApi -Method GET -Path "/search" -Query $query
        
        if (-not $searchResults) {
            Write-Host "No search results found for '$Arguments'" -ForegroundColor Yellow
            return
        }
        
        Write-Host "Search Results for: '$Arguments'" -ForegroundColor Cyan
        Write-Host "=================================" -ForegroundColor Cyan
        
        # Display tracks
        if ($searchResults.tracks -and $searchResults.tracks.items -and $searchResults.tracks.items.Count -gt 0) {
            Write-Host "`n🎵 Tracks:" -ForegroundColor Green
            for ($i = 0; $i -lt [Math]::Min(5, $searchResults.tracks.items.Count); $i++) {
                $track = $searchResults.tracks.items[$i]
                $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
                $duration = Format-Time $track.duration_ms
                Write-Host "  $($i+1). $($track.name)" -ForegroundColor White
                Write-Host "     👤 $artists" -ForegroundColor Yellow
                Write-Host "     📀 $($track.album.name)" -ForegroundColor Green
                Write-Host "     ⏱ $duration" -ForegroundColor Magenta
                Write-Host "     🔗 URI: $($track.uri)" -ForegroundColor Gray
                Write-Host ""
            }
        }
        
        # Display artists
        if ($searchResults.artists -and $searchResults.artists.items -and $searchResults.artists.items.Count -gt 0) {
            Write-Host "👤 Artists:" -ForegroundColor Green
            for ($i = 0; $i -lt [Math]::Min(3, $searchResults.artists.items.Count); $i++) {
                $artist = $searchResults.artists.items[$i]
                $followers = if ($artist.followers -and $artist.followers.total) {
                    " ($($artist.followers.total) followers)"
                } else { "" }
                Write-Host "  $($i+1). $($artist.name)$followers" -ForegroundColor White
                Write-Host "     🔗 URI: $($artist.uri)" -ForegroundColor Gray
                Write-Host ""
            }
        }
        
        # Display albums
        if ($searchResults.albums -and $searchResults.albums.items -and $searchResults.albums.items.Count -gt 0) {
            Write-Host "📀 Albums:" -ForegroundColor Green
            for ($i = 0; $i -lt [Math]::Min(3, $searchResults.albums.items.Count); $i++) {
                $album = $searchResults.albums.items[$i]
                $artists = ($album.artists | ForEach-Object { $_.name }) -join ", "
                $releaseYear = if ($album.release_date) {
                    " (" + $album.release_date.Substring(0, 4) + ")"
                } else { "" }
                Write-Host "  $($i+1). $($album.name)$releaseYear" -ForegroundColor White
                Write-Host "     👤 $artists" -ForegroundColor Yellow
                Write-Host "     🔗 URI: $($album.uri)" -ForegroundColor Gray
                Write-Host ""
            }
        }
        
        Write-Host "Use /play track <uri>, /play album <uri>, or /queue <uri> to play content" -ForegroundColor Gray
        
    }
    catch {
        Handle-SpotifyError -ErrorRecord $_ -Context "searching for content" -ShowSuggestions $true
    }
}

function Invoke-QueueCommand {
    param([string]$Arguments)
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        Write-Error "Please provide a track URI. Usage: /queue <track_uri>"
        return
    }
    
    $trackUri = $Arguments.Trim()
    
    # Validate URI format
    if (-not ($trackUri -match "^spotify:(track|episode):[a-zA-Z0-9]{22}$")) {
        Write-Error "Invalid URI format. Expected format: spotify:track:xxxxxxxxxxxxxxxxxx or spotify:episode:xxxxxxxxxxxxxxxxxx"
        return
    }
    
    try {
        # Add track to queue
        $query = @{ uri = $trackUri }
        Invoke-SpotifyApi -Method POST -Path "/me/player/queue" -Query $query | Out-Null
        
        Write-Host "🎵 Track added to queue" -ForegroundColor Green
        
        # Try to get track info for confirmation
        try {
            $trackId = $trackUri -replace "spotify:track:", ""
            $trackInfo = Invoke-SpotifyApi -Method GET -Path "/tracks/$trackId"
            if ($trackInfo) {
                $artists = ($trackInfo.artists | ForEach-Object { $_.name }) -join ", "
                Write-Host "   $($trackInfo.name) by $artists" -ForegroundColor White
            }
        }
        catch {
            # Ignore errors when getting track info for display
        }
        
    }
    catch {
        $errorMsg = if ($_.Exception.Response.StatusCode -eq 403) {
            "Spotify Premium required for queue functionality"
        }
        elseif ($_.Exception.Response.StatusCode -eq 404) {
            "No active device found or track not found. Please start Spotify on a device"
        }
        else {
            "Could not add track to queue: $($_.Exception.Message)"
        }
        Write-Warning $errorMsg
    }
}

function Invoke-PlayCommand {
    param([string]$Arguments)
    
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        Write-Error "Please specify what to play. Usage: /play track <uri>, /play album <uri>, or /play playlist <uri>"
        return
    }
    
    $parts = $Arguments.Trim() -split '\s+', 2
    $playType = $parts[0].ToLower()
    $uri = if ($parts.Length -gt 1) { $parts[1] } else { "" }
    
    if ([string]::IsNullOrWhiteSpace($uri)) {
        Write-Error "Please provide a URI. Usage: /play $playType <uri>"
        return
    }
    
    # Validate URI format based on type
    $validUri = $false
    switch ($playType) {
        "track" {
            $validUri = $uri -match "^spotify:track:[a-zA-Z0-9]{22}$"
        }
        "album" {
            $validUri = $uri -match "^spotify:album:[a-zA-Z0-9]{22}$"
        }
        "playlist" {
            $validUri = $uri -match "^spotify:playlist:[a-zA-Z0-9]{22}$"
        }
        default {
            Write-Error "Invalid play type '$playType'. Use: track, album, or playlist"
            return
        }
    }
    
    if (-not $validUri) {
        Write-Error "Invalid URI format for $playType. Expected format: spotify:$playType`:xxxxxxxxxxxxxxxxxx"
        return
    }
    
    try {
        # Prepare play request body
        $body = @{}
        
        if ($playType -eq "track") {
            $body.uris = @($uri)
        } else {
            $body.context_uri = $uri
        }
        
        # Start playback
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
        
        $playIcon = switch ($playType) {
            "track" { "🎵" }
            "album" { "📀" }
            "playlist" { "📋" }
        }
        
        Write-Host "$playIcon Started playing $playType" -ForegroundColor Green
        
        # Try to get content info for confirmation
        try {
            $contentId = $uri -replace "spotify:$playType`:", ""
            $contentInfo = $null
            
            switch ($playType) {
                "track" {
                    $contentInfo = Invoke-SpotifyApi -Method GET -Path "/tracks/$contentId"
                    if ($contentInfo) {
                        $artists = ($contentInfo.artists | ForEach-Object { $_.name }) -join ", "
                        Write-Host "   $($contentInfo.name) by $artists" -ForegroundColor White
                    }
                }
                "album" {
                    $contentInfo = Invoke-SpotifyApi -Method GET -Path "/albums/$contentId"
                    if ($contentInfo) {
                        $artists = ($contentInfo.artists | ForEach-Object { $_.name }) -join ", "
                        Write-Host "   $($contentInfo.name) by $artists" -ForegroundColor White
                    }
                }
                "playlist" {
                    $contentInfo = Invoke-SpotifyApi -Method GET -Path "/playlists/$contentId"
                    if ($contentInfo) {
                        Write-Host "   $($contentInfo.name)" -ForegroundColor White
                        if ($contentInfo.description) {
                            Write-Host "   $($contentInfo.description)" -ForegroundColor Gray
                        }
                    }
                }
            }
        }
        catch {
            # Ignore errors when getting content info for display
        }
        
    }
    catch {
        $errorMsg = if ($_.Exception.Response.StatusCode -eq 403) {
            "Spotify Premium required for playback control"
        }
        elseif ($_.Exception.Response.StatusCode -eq 404) {
            "No active device found or content not found. Please start Spotify on a device"
        }
        else {
            "Could not start playback: $($_.Exception.Message)"
        }
        Write-Warning $errorMsg
    }
}
#endregion Spotify-kommandon

function Invoke-PlaylistsCommand {
    <#
    .SYNOPSIS
    Display user playlists with metadata
    .DESCRIPTION
    Shows user's playlists including name, track count, and description.
    Handles both public and private playlists based on access permissions.
    #>
    try {
        Write-Host "Loading playlists..." -ForegroundColor Gray
        
        # Get user's playlists with pagination support
        $limit = 50
        $offset = 0
        $allPlaylists = @()
        
        do {
            $query = @{
                limit = $limit
                offset = $offset
            }
            
            $playlistsResponse = Invoke-SpotifyApi -Method GET -Path "/me/playlists" -Query $query
            
            if ($playlistsResponse -and $playlistsResponse.items) {
                $allPlaylists += $playlistsResponse.items
                $offset += $limit
            } else {
                break
            }
        } while ($playlistsResponse.items.Count -eq $limit -and $allPlaylists.Count -lt 200) # Limit to 200 playlists max
        
        if ($allPlaylists.Count -eq 0) {
            Write-Host "No playlists found." -ForegroundColor Yellow
            Write-Host "Create some playlists in Spotify to see them here." -ForegroundColor Gray
            return
        }
        
        # Get terminal width for truncation
        $termWidth = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
        if ($termWidth -lt 40) { $termWidth = 40 }
        $maxLineLen = $termWidth - 2
        $separatorLen = [Math]::Min($termWidth - 1, 40)

        Write-Host "Your Spotify Playlists:" -ForegroundColor Cyan
        Write-Host ("=" * $separatorLen) -ForegroundColor Cyan
        Write-Host ""

        foreach ($playlist in $allPlaylists) {
            $playlistIcon = if ($playlist.public -eq $false) { "🔒" } else { "📋" }
            $ownerInfo = if ($playlist.owner.display_name) {
                " by $($playlist.owner.display_name)"
            } else {
                ""
            }

            # Handle collaborative playlists
            if ($playlist.collaborative) {
                $playlistIcon = "👥"
            }

            $nameLine = "$playlistIcon $($playlist.name)$ownerInfo"
            if ($nameLine.Length -gt $maxLineLen) {
                $nameLine = $nameLine.Substring(0, $maxLineLen - 3) + "..."
            }
            Write-Host $nameLine -ForegroundColor White
            Write-Host "   📊 $($playlist.tracks.total) tracks" -ForegroundColor Gray

            if ($playlist.description -and $playlist.description.Trim() -ne "") {
                # Clean up HTML entities and limit description length
                $description = $playlist.description -replace '&quot;', '"' -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>'
                $maxDescLen = $maxLineLen - 6  # account for "   📝 " prefix
                if ($description.Length -gt $maxDescLen) {
                    $description = $description.Substring(0, $maxDescLen - 3) + "..."
                }
                Write-Host "   📝 $description" -ForegroundColor DarkGray
            }

            Write-Host "   🔗 URI: $($playlist.uri)" -ForegroundColor DarkGray
            Write-Host ""
        }
        
        Write-Host "Total: $($allPlaylists.Count) playlists" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Use '/play playlist <uri>' to play a playlist" -ForegroundColor Gray
        
    }
    catch {
        $errorMsg = if ($_.Exception.Response.StatusCode -eq 403) {
            "Access denied. Make sure you have granted playlist permissions during authentication."
        }
        elseif ($_.Exception.Response.StatusCode -eq 401) {
            "Authentication required. Please re-authenticate with '/config' or restart the CLI."
        }
        else {
            "Could not load playlists: $($_.Exception.Message)"
        }
        Write-Warning $errorMsg
    }
}

function Invoke-LikedCommand {
    <#
    .SYNOPSIS
    Display user's saved/liked tracks
    .DESCRIPTION
    Shows the user's saved tracks (liked songs) with metadata including track name, artist, album, and duration.
    #>
    try {
        Write-Host "Loading liked songs..." -ForegroundColor Gray
        
        # Get user's saved tracks with pagination support
        $limit = 50
        $offset = 0
        $allTracks = @()
        
        do {
            $query = @{
                limit = $limit
                offset = $offset
            }
            
            $tracksResponse = Invoke-SpotifyApi -Method GET -Path "/me/tracks" -Query $query
            
            if ($tracksResponse -and $tracksResponse.items) {
                $allTracks += $tracksResponse.items
                $offset += $limit
            } else {
                break
            }
        } while ($tracksResponse.items.Count -eq $limit -and $allTracks.Count -lt 200) # Limit to 200 tracks max for display
        
        if ($allTracks.Count -eq 0) {
            Write-Host "No liked songs found." -ForegroundColor Yellow
            Write-Host "Like some songs in Spotify or use '/save' to add the current track." -ForegroundColor Gray
            return
        }
        
        Write-Host "Your Liked Songs:" -ForegroundColor Cyan
        Write-Host "=================" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($item in $allTracks) {
            $track = $item.track
            $addedAt = [DateTime]::Parse($item.added_at).ToString("yyyy-MM-dd")
            
            Write-Host "💚 $($track.name)" -ForegroundColor Green
            Write-Host "   👤 $($track.artists | ForEach-Object { $_.name } | Join-String -Separator ', ')" -ForegroundColor Yellow
            Write-Host "   📀 $($track.album.name)" -ForegroundColor Cyan
            Write-Host "   ⏱ $(Format-Time $track.duration_ms) | Added: $addedAt" -ForegroundColor Gray
            Write-Host "   🔗 URI: $($track.uri)" -ForegroundColor DarkGray
            Write-Host ""
        }
        
        Write-Host "Total: $($allTracks.Count) liked songs" -ForegroundColor Cyan
        if ($allTracks.Count -eq 200) {
            Write-Host "(Showing first 200 songs)" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "Use '/save' to add current track to liked songs" -ForegroundColor Gray
        Write-Host "Use '/unsave' to remove current track from liked songs" -ForegroundColor Gray
        
    }
    catch {
        $errorMsg = if ($_.Exception.Response.StatusCode -eq 403) {
            "Access denied. Make sure you have granted library permissions during authentication."
        }
        elseif ($_.Exception.Response.StatusCode -eq 401) {
            "Authentication required. Please re-authenticate with '/config' or restart the CLI."
        }
        else {
            "Could not load liked songs: $($_.Exception.Message)"
        }
        Write-Warning $errorMsg
    }
}

function Invoke-SaveCommand {
    <#
    .SYNOPSIS
    Add current track to liked songs
    .DESCRIPTION
    Saves the currently playing track to the user's "Liked Songs" library.
    Validates that a track is currently playing before attempting to save.
    #>
    try {
        # Get current track
        $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        
        if (-not $currentTrack -or -not $currentTrack.item) {
            Write-Warning "No track currently playing. Cannot save to liked songs."
            Write-Host "Start playing a track first, then use '/save' to add it to your liked songs." -ForegroundColor Gray
            return
        }
        
        $track = $currentTrack.item
        $trackId = $track.id
        
        # Check if track is already saved
        $query = @{ ids = $trackId }
        $checkResponse = Invoke-SpotifyApi -Method GET -Path "/me/tracks/contains" -Query $query
        
        if ($checkResponse -and $checkResponse[0] -eq $true) {
            Write-Host "💚 '$($track.name)' is already in your liked songs." -ForegroundColor Green
            return
        }
        
        # Save the track
        $query = @{ ids = $trackId }
        Invoke-SpotifyApi -Method PUT -Path "/me/tracks" -Query $query | Out-Null
        
        Write-Host "💚 Added '$($track.name)' by $($track.artists | ForEach-Object { $_.name } | Join-String -Separator ', ') to liked songs!" -ForegroundColor Green
        
    }
    catch {
        $errorMsg = if ($_.Exception.Response.StatusCode -eq 403) {
            "Access denied. Make sure you have granted library permissions during authentication."
        }
        elseif ($_.Exception.Response.StatusCode -eq 401) {
            "Authentication required. Please re-authenticate with '/config' or restart the CLI."
        }
        else {
            "Could not save track: $($_.Exception.Message)"
        }
        Write-Warning $errorMsg
    }
}

function Invoke-UnsaveCommand {
    <#
    .SYNOPSIS
    Remove current track from liked songs
    .DESCRIPTION
    Removes the currently playing track from the user's "Liked Songs" library.
    Validates that a track is currently playing before attempting to remove.
    #>
    try {
        # Get current track
        $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        
        if (-not $currentTrack -or -not $currentTrack.item) {
            Write-Warning "No track currently playing. Cannot remove from liked songs."
            Write-Host "Start playing a track first, then use '/unsave' to remove it from your liked songs." -ForegroundColor Gray
            return
        }
        
        $track = $currentTrack.item
        $trackId = $track.id
        
        # Check if track is currently saved
        $query = @{ ids = $trackId }
        $checkResponse = Invoke-SpotifyApi -Method GET -Path "/me/tracks/contains" -Query $query
        
        if ($checkResponse -and $checkResponse[0] -eq $false) {
            Write-Host "💔 '$($track.name)' is not in your liked songs." -ForegroundColor Yellow
            return
        }
        
        # Remove the track
        $query = @{ ids = $trackId }
        Invoke-SpotifyApi -Method DELETE -Path "/me/tracks" -Query $query | Out-Null
        
        Write-Host "💔 Removed '$($track.name)' by $($track.artists | ForEach-Object { $_.name } | Join-String -Separator ', ') from liked songs." -ForegroundColor Yellow
        
    }
    catch {
        $errorMsg = if ($_.Exception.Response.StatusCode -eq 403) {
            "Access denied. Make sure you have granted library permissions during authentication."
        }
        elseif ($_.Exception.Response.StatusCode -eq 401) {
            "Authentication required. Please re-authenticate with '/config' or restart the CLI."
        }
        else {
            "Could not remove track: $($_.Exception.Message)"
        }
        Write-Warning $errorMsg
    }
}

function Invoke-RecentCommand {
    <#
    .SYNOPSIS
    Display recently played tracks
    .DESCRIPTION
    Shows the user's recently played tracks with timestamps and metadata including track name, artist, album, and when it was played.
    #>
    try {
        Write-Host "Loading recently played tracks..." -ForegroundColor Gray
        
        # Get recently played tracks (limit to 50, which is the maximum allowed by Spotify API)
        $query = @{
            limit = 50
        }
        
        $recentResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/recently-played" -Query $query
        
        if (-not $recentResponse -or -not $recentResponse.items -or $recentResponse.items.Count -eq 0) {
            Write-Host "No recently played tracks found." -ForegroundColor Yellow
            Write-Host "Play some music in Spotify to see your listening history here." -ForegroundColor Gray
            return
        }
        
        Write-Host "Recently Played Tracks:" -ForegroundColor Cyan
        Write-Host "======================" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($item in $recentResponse.items) {
            $track = $item.track
            $playedAt = [DateTime]::Parse($item.played_at)
            
            # Format the timestamp based on how recent it is
            $now = [DateTime]::UtcNow
            $timeDiff = $now - $playedAt
            
            $timeDisplay = if ($timeDiff.TotalDays -ge 1) {
                $playedAt.ToString("MMM dd, HH:mm")
            } elseif ($timeDiff.TotalHours -ge 1) {
                "$([int]$timeDiff.TotalHours)h ago"
            } elseif ($timeDiff.TotalMinutes -ge 1) {
                "$([int]$timeDiff.TotalMinutes)m ago"
            } else {
                "Just now"
            }
            
            Write-Host "🎵 $($track.name)" -ForegroundColor Cyan
            Write-Host "   👤 $($track.artists | ForEach-Object { $_.name } | Join-String -Separator ', ')" -ForegroundColor Yellow
            Write-Host "   📀 $($track.album.name)" -ForegroundColor Green
            Write-Host "   ⏱ $(Format-Time $track.duration_ms) | Played: $timeDisplay" -ForegroundColor Gray
            Write-Host "   🔗 URI: $($track.uri)" -ForegroundColor DarkGray
            Write-Host ""
        }
        
        Write-Host "Total: $($recentResponse.items.Count) recent tracks" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Use '/play track <uri>' to play any of these tracks again" -ForegroundColor Gray
        
    }
    catch {
        $errorMsg = if ($_.Exception.Response.StatusCode -eq 403) {
            "Access denied. Make sure you have granted recently played permissions during authentication."
        }
        elseif ($_.Exception.Response.StatusCode -eq 401) {
            "Authentication required. Please re-authenticate with '/config' or restart the CLI."
        }
        else {
            "Could not load recently played tracks: $($_.Exception.Message)"
        }
        Write-Warning $errorMsg
    }
}

function Invoke-HistoryCommand {
    <#
    .SYNOPSIS
    Display local playback history tracked by the CLI
    .PARAMETER Arguments
    Command arguments (optional: number of entries to show or 'clear')
    #>
    param([string]$Arguments)
    
    try {
        if ([string]::IsNullOrWhiteSpace($Arguments)) {
            # Show default number of entries (20)
            history
        }
        elseif ($Arguments -eq "clear") {
            # Clear history
            history -Clear
        }
        elseif ($Arguments -match '^\d+$') {
            # Show specific number of entries
            $count = [int]$Arguments
            if ($count -le 0) {
                Write-Host "❌ Invalid number. Please specify a positive number." -ForegroundColor Red
                return
            }
            history -Last $count
        }
        else {
            Write-Host "❌ Invalid argument. Usage: /history [number|clear]" -ForegroundColor Red
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor Yellow
            Write-Host "  /history        - Show last 20 entries" -ForegroundColor White
            Write-Host "  /history 50     - Show last 50 entries" -ForegroundColor White
            Write-Host "  /history clear  - Clear all history" -ForegroundColor White
        }
    }
    catch {
        $errorMsg = if ($_.Exception.Response.StatusCode -eq 401) {
            "Authentication required. Please re-authenticate with Spotify."
        }
        else {
            "Could not access playback history: $($_.Exception.Message)"
        }
        Write-Warning $errorMsg
    }
}

function Invoke-NotificationsCommand {
    <#
    .SYNOPSIS
    Enable or disable Windows toast notifications for track changes
    .PARAMETER Arguments
    Command arguments (on/off)
    #>
    param([string]$Arguments)
    
    try {
        if ([string]::IsNullOrWhiteSpace($Arguments)) {
            # Show current status
            $config = Get-SpotifyConfig
            $status = if ($config.NotificationsEnabled) { "enabled" } else { "disabled" }
            Write-Host "🔔 Notifications are currently $status" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Usage: /notifications <on|off>" -ForegroundColor Yellow
            return
        }
        
        $arg = $Arguments.ToLower().Trim()
        
        if ($arg -eq "on" -or $arg -eq "enable" -or $arg -eq "true") {
            # Enable notifications
            $config = Get-SpotifyConfig
            $config.NotificationsEnabled = $true
            
            if (Set-SpotifyConfig -Config $config) {
                Write-Host "✅ Notifications enabled" -ForegroundColor Green
                Write-Host "You will now receive Windows toast notifications when tracks change." -ForegroundColor White
                
                # Test notification
                Show-TrackNotification -Title "Notifications Enabled" -Message "You will now receive track change notifications" -IsTest $true
            } else {
                Write-Host "❌ Failed to enable notifications" -ForegroundColor Red
            }
        }
        elseif ($arg -eq "off" -or $arg -eq "disable" -or $arg -eq "false") {
            # Disable notifications
            $config = Get-SpotifyConfig
            $config.NotificationsEnabled = $false
            
            if (Set-SpotifyConfig -Config $config) {
                Write-Host "✅ Notifications disabled" -ForegroundColor Green
                Write-Host "You will no longer receive track change notifications." -ForegroundColor White
            } else {
                Write-Host "❌ Failed to disable notifications" -ForegroundColor Red
            }
        }
        else {
            Write-Host "❌ Invalid argument. Use 'on' or 'off'" -ForegroundColor Red
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor Yellow
            Write-Host "  /notifications on   - Enable notifications" -ForegroundColor White
            Write-Host "  /notifications off  - Disable notifications" -ForegroundColor White
        }
    }
    catch {
        Write-Warning "Could not modify notification settings: $($_.Exception.Message)"
    }
}

function Invoke-AutoRefreshCommand {
    <#
    .SYNOPSIS
    Enable or disable auto-refresh functionality for automatic display updates
    .PARAMETER Arguments
    Command arguments (interval in seconds, or 'off' to disable)
    #>
    param([string]$Arguments)
    
    try {
        if ([string]::IsNullOrWhiteSpace($Arguments)) {
            # Show current status
            $config = Get-SpotifyConfig
            $status = if ($config.AutoRefreshInterval -gt 0) { 
                "enabled ($($config.AutoRefreshInterval) seconds)" 
            } else { 
                "disabled" 
            }
            Write-Host "🔄 Auto-refresh is currently $status" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Usage: /auto-refresh <seconds> - Enable auto-refresh with specified interval" -ForegroundColor Yellow
            Write-Host "       /auto-refresh off        - Disable auto-refresh" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor Yellow
            Write-Host "  /auto-refresh 5   - Refresh every 5 seconds" -ForegroundColor Gray
            Write-Host "  /auto-refresh 10  - Refresh every 10 seconds" -ForegroundColor Gray
            Write-Host "  /auto-refresh off - Disable auto-refresh" -ForegroundColor Gray
            return
        }
        
        $arg = $Arguments.Trim().ToLower()
        
        if ($arg -eq "off" -or $arg -eq "disable" -or $arg -eq "stop") {
            # Disable auto-refresh
            $config = Get-SpotifyConfig
            $config.AutoRefreshInterval = 0
            
            if (Set-SpotifyConfig -Config $config) {
                Write-Host "✅ Auto-refresh disabled" -ForegroundColor Green
                Write-Host "Display will no longer update automatically." -ForegroundColor White
                
                # Stop any running auto-refresh
                $script:AutoRefreshActive = $false
            } else {
                Write-Host "❌ Failed to disable auto-refresh" -ForegroundColor Red
            }
        }
        elseif ($arg -match '^\d+$') {
            # Enable auto-refresh with specified interval
            $interval = [int]$arg
            
            if ($interval -lt 1) {
                Write-Host "❌ Invalid interval: $interval" -ForegroundColor Red
                Write-Host "Interval must be at least 1 second." -ForegroundColor Yellow
                return
            }
            
            if ($interval -gt 300) {
                Write-Host "⚠️ Warning: Interval of $interval seconds is quite long." -ForegroundColor Yellow
                Write-Host "Consider using a shorter interval for better responsiveness." -ForegroundColor White
            }
            
            $config = Get-SpotifyConfig
            $config.AutoRefreshInterval = $interval
            
            if (Set-SpotifyConfig -Config $config) {
                Write-Host "✅ Auto-refresh enabled" -ForegroundColor Green
                Write-Host "Display will update every $interval seconds." -ForegroundColor White
                Write-Host ""
                Write-Host "💡 Tips:" -ForegroundColor Cyan
                Write-Host "• Any manual command will interrupt the refresh cycle" -ForegroundColor White
                Write-Host "• Use /auto-refresh off to disable" -ForegroundColor White
                Write-Host "• Press Ctrl+C to stop if needed" -ForegroundColor White
                
                # Start auto-refresh
                Start-AutoRefresh -Interval $interval
            } else {
                Write-Host "❌ Failed to enable auto-refresh" -ForegroundColor Red
            }
        }
        else {
            Write-Host "❌ Invalid argument: $arg" -ForegroundColor Red
            Write-Host ""
            Write-Host "Valid options:" -ForegroundColor Yellow
            Write-Host "• A number (seconds): /auto-refresh 5" -ForegroundColor White
            Write-Host "• 'off' to disable: /auto-refresh off" -ForegroundColor White
        }
    }
    catch {
        Write-Warning "Could not modify auto-refresh settings: $($_.Exception.Message)"
    }
}

function Start-AutoRefresh {
    <#
    .SYNOPSIS
    Start the auto-refresh loop with specified interval
    .PARAMETER Interval
    Refresh interval in seconds
    #>
    param([int]$Interval)
    
    $script:AutoRefreshActive = $true
    
    Write-Host ""
    Write-Host "🔄 Auto-refresh started (every $Interval seconds)" -ForegroundColor Green
    Write-Host "Press any key to interrupt and return to command prompt..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        while ($script:AutoRefreshActive) {
            # Clear screen and show current track
            Clear-Host
            Write-Host "🔄 Auto-refresh active (every $Interval seconds) - Press any key to stop" -ForegroundColor Gray
            Write-Host "=" * 60 -ForegroundColor Gray
            Write-Host ""
            
            # Show current track
            try {
                Show-CurrentTrack
            } catch {
                Write-Host "❌ Error refreshing track info: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            Write-Host ""
            Write-Host "=" * 60 -ForegroundColor Gray
            Write-Host "Next refresh in $Interval seconds... (Press any key to stop)" -ForegroundColor Gray
            
            # Wait for interval or user input
            $timeout = $Interval * 1000  # Convert to milliseconds
            $startTime = Get-Date
            
            while (((Get-Date) - $startTime).TotalMilliseconds -lt $timeout -and $script:AutoRefreshActive) {
                if ([Console]::KeyAvailable) {
                    # User pressed a key, stop auto-refresh
                    $key = [Console]::ReadKey($true)
                    $script:AutoRefreshActive = $false
                    break
                }
                Start-Sleep -Milliseconds 100
            }
        }
    }
    catch {
        Write-Host "❌ Auto-refresh error: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        $script:AutoRefreshActive = $false
        Clear-Host
        Write-Host "🔄 Auto-refresh stopped" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Returning to command prompt..." -ForegroundColor Gray
        Write-Host ""
    }
}

function Stop-AutoRefresh {
    <#
    .SYNOPSIS
    Stop the auto-refresh loop
    #>
    $script:AutoRefreshActive = $false
}

#region CLI-loop
function Invoke-LyricsCommand {
    <#
    .SYNOPSIS
    Display lyrics for the currently playing track or a specified track with interactive scrollable display
    .PARAMETER Arguments
    Optional arguments: artist and track name, or empty for current track. Use -interactive or -i for scrollable display
    #>
    param([string]$Arguments)
    
    try {
        # Import lyrics engine directly
        $lyricsModulePath = Join-Path $PSScriptRoot "modules\Lyrics\LyricsEngine.psm1"
        if (-not (Test-Path $lyricsModulePath)) {
            Write-Host "❌ Lyrics module not found at: $lyricsModulePath" -ForegroundColor Red
            Write-Host "💡 Lyrics functionality requires the lyrics module" -ForegroundColor Yellow
            return
        }
        
        # Import the lyrics module
        Import-Module $lyricsModulePath -Force -ErrorAction Stop
        
        # Parse arguments for interactive mode flag
        $interactive = $false
        $cleanArgs = $Arguments
        if ($Arguments -match '\s*-i(nteractive)?\s*') {
            $interactive = $true
            $cleanArgs = $Arguments -replace '\s*-i(nteractive)?\s*', ''
        }
        
        # Create lyrics manager with default configuration
        $config = @{
            CacheDirectory = Join-Path $env:APPDATA "SpotifyCLI\Lyrics"
        }
        $lyricsManager = New-LyricsManager -Configuration $config
        
        if ([string]::IsNullOrWhiteSpace($cleanArgs)) {
            # Get lyrics for current track
            Write-Host "🎵 Fetching lyrics for current track..." -ForegroundColor Cyan
            
            # Get current track info
            $currentTrack = $null
            try {
                $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            } catch {
                Write-Host "❌ Could not get current track information" -ForegroundColor Red
                Write-Host "💡 Make sure Spotify is playing and you're authenticated" -ForegroundColor Yellow
                return
            }
            
            if (-not $currentTrack -or -not $currentTrack.item) {
                Write-Host "❌ No track currently playing" -ForegroundColor Red
                Write-Host "💡 Start playing a track in Spotify first" -ForegroundColor Yellow
                return
            }
            
            $track = $currentTrack.item
            $artist = ($track.artists | ForEach-Object { $_.name }) -join ", "
            $lyricsResult = $lyricsManager.GetLyrics($artist, $track.name)
            
        } else {
            # Parse artist and track from arguments
            $parts = $cleanArgs.Trim() -split '\s+', 2
            if ($parts.Length -lt 2) {
                Write-Host "❌ Please provide both artist and track name" -ForegroundColor Red
                Write-Host "💡 Usage: lyrics <artist> <track> [-interactive]" -ForegroundColor Yellow
                Write-Host "💡 Example: lyrics Queen 'Bohemian Rhapsody'" -ForegroundColor Yellow
                Write-Host "💡 Example: lyrics Queen 'Bohemian Rhapsody' -i" -ForegroundColor Yellow
                Write-Host "💡 Or use: lyrics (for current track)" -ForegroundColor Yellow
                return
            }
            
            $artist = $parts[0]
            $track = $parts[1]
            Write-Host "🎵 Fetching lyrics for '$track' by $artist..." -ForegroundColor Cyan
            $lyricsResult = $lyricsManager.GetLyrics($artist, $track)
            $currentTrack = $null  # No position info for manual searches
        }
        
        if (-not $lyricsResult.Success) {
            Write-Host "❌ Could not fetch lyrics: $($lyricsResult.Error)" -ForegroundColor Red
            Write-Host ""
            Write-Host "🔧 POSSIBLE REASONS:" -ForegroundColor Yellow
            Write-Host "• Lyrics not available for this track" -ForegroundColor White
            Write-Host "• No current track playing (if using without arguments)" -ForegroundColor White
            Write-Host "• Network connectivity issues" -ForegroundColor White
            Write-Host "• Lyrics provider API limitations" -ForegroundColor White
            Write-Host ""
            Write-Host "💡 TIP: Try using mock provider for testing: lyrics 'Test Artist' 'Test Track'" -ForegroundColor Cyan
            return
        }
        
        # Check if interactive mode is requested and supported
        if ($interactive) {
            try {
                # Test if console supports interactive input
                $canUseInteractive = $true
                try {
                    $null = [Console]::KeyAvailable
                    $null = [Console]::CursorVisible
                } catch {
                    $canUseInteractive = $false
                }
                
                if ($canUseInteractive) {
                    Write-Host "🎮 Starting interactive lyrics viewer..." -ForegroundColor Cyan
                    Write-Host "Use ↑↓ to scroll, / to search, T to toggle timestamps, Esc to exit" -ForegroundColor Gray
                    Write-Host ""
                    
                    # Get current position if available
                    $currentPositionMs = 0
                    if ($currentTrack -and $currentTrack.progress_ms) {
                        $currentPositionMs = $currentTrack.progress_ms
                    }
                    
                    # Start interactive viewer
                    Show-Lyrics -LyricsData $lyricsResult -InitialPositionMs $currentPositionMs
                    return
                } else {
                    Write-Host "⚠️ Interactive mode not supported in this environment" -ForegroundColor Yellow
                    Write-Host "💡 Falling back to static display" -ForegroundColor Cyan
                }
            } catch {
                Write-Host "⚠️ Interactive mode failed: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "💡 Falling back to static display" -ForegroundColor Cyan
            }
        }
        
        # Static display mode with synchronized highlighting
        Write-Host ""
        Write-Host "🎵 Lyrics" -ForegroundColor Cyan
        Write-Host "========" -ForegroundColor Cyan
        Write-Host ""
        
        if ($lyricsResult.TrackId) {
            Write-Host "Track: $($lyricsResult.TrackId)" -ForegroundColor Yellow
        }
        
        if ($lyricsResult.Source) {
            Write-Host "Source: $($lyricsResult.Source)" -ForegroundColor Gray
        }
        
        Write-Host ""
        
        if ($lyricsResult.HasSyncedLyrics -and $lyricsResult.SyncedLines) {
            # Display synced lyrics with timestamps and current line highlighting
            Write-Host "📝 Synced Lyrics:" -ForegroundColor Green
            Write-Host ""
            
            $currentPositionMs = 0
            if ($currentTrack -and $currentTrack.progress_ms) {
                $currentPositionMs = $currentTrack.progress_ms
            }
            
            # Find current line for highlighting
            $currentLineIndex = -1
            if ($currentPositionMs -gt 0) {
                for ($i = $lyricsResult.SyncedLines.Count - 1; $i -ge 0; $i--) {
                    if ($lyricsResult.SyncedLines[$i].Timestamp -le $currentPositionMs) {
                        $currentLineIndex = $i
                        break
                    }
                }
            }
            
            for ($i = 0; $i -lt $lyricsResult.SyncedLines.Count; $i++) {
                $line = $lyricsResult.SyncedLines[$i]
                
                # Handle timestamp formatting safely
                try {
                    $timestampValue = $line.Timestamp
                    if ($timestampValue -is [string]) {
                        $timestampValue = [int]$timestampValue
                    }
                    $timestamp = Format-LyricsTimestamp -TimestampMs $timestampValue
                } catch {
                    $timestamp = "00:00"
                }
                
                if ($i -eq $currentLineIndex) {
                    # Highlight current line
                    Write-Host "► [$timestamp] " -NoNewline -ForegroundColor Yellow
                    Write-Host $line.Text -ForegroundColor Yellow
                } else {
                    Write-Host "  [$timestamp] " -NoNewline -ForegroundColor Gray
                    Write-Host $line.Text -ForegroundColor White
                }
            }
            
            if ($currentLineIndex -ge 0) {
                Write-Host ""
                Write-Host "► Currently at line $(($currentLineIndex + 1)) of $($lyricsResult.SyncedLines.Count)" -ForegroundColor Cyan
            }
            
        } elseif ($lyricsResult.FullText) {
            # Display plain text lyrics
            Write-Host "📝 Lyrics:" -ForegroundColor Green
            Write-Host ""
            
            $lines = $lyricsResult.FullText -split "`n"
            foreach ($line in $lines) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-Host $line.Trim() -ForegroundColor White
                }
            }
        } else {
            Write-Host "❌ No lyrics content available" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "💡 TIPS:" -ForegroundColor Cyan
        Write-Host "• Use 'lyrics <artist> <track>' to get lyrics for a specific song" -ForegroundColor White
        Write-Host "• Use 'lyrics -interactive' or 'lyrics -i' for scrollable display" -ForegroundColor White
        Write-Host "• Synchronized highlighting shows current line for playing tracks" -ForegroundColor White
        
    } catch {
        Write-Host "❌ Lyrics command error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Make sure the lyrics module is properly installed" -ForegroundColor Yellow
        Write-Host "💡 Try: lyrics 'Test Artist' 'Test Track' (uses mock provider)" -ForegroundColor Yellow
    }
}

function Format-LyricsTimestamp {
    <#
    .SYNOPSIS
    Format timestamp in milliseconds to MM:SS format
    .PARAMETER TimestampMs
    Timestamp in milliseconds
    #>
    param([int]$TimestampMs)
    
    $totalSeconds = [Math]::Floor($TimestampMs / 1000)
    $minutes = [Math]::Floor($totalSeconds / 60)
    $seconds = $totalSeconds % 60
    return "{0:D2}:{1:D2}" -f $minutes, $seconds
}

function Invoke-SidecarCommand {
    <#
    .SYNOPSIS
    Launch Spotify CLI in sidecar/split window mode
    .PARAMETER Arguments
    Optional arguments: live mode (detailed, compact, minimal) and split direction
    #>
    param([string]$Arguments)
    
    try {
        # Parse arguments
        $parts = if ($Arguments) { $Arguments.Trim() -split '\s+' } else { @() }
        $liveMode = $null
        $splitDirection = "right"
        $startLive = $false
        
        foreach ($part in $parts) {
            switch ($part.ToLower()) {
                { $_ -in @("detailed", "compact", "minimal") } { 
                    $liveMode = $_
                    $startLive = $true
                }
                { $_ -in @("right", "down", "left", "up") } { 
                    $splitDirection = $_
                }
                "live" { 
                    $startLive = $true
                    if (-not $liveMode) { $liveMode = "detailed" }
                }
            }
        }
        
        # Import the SpotifyModule to get sidecar functions
        $modulePath = Join-Path $PSScriptRoot "SpotifyModule.psm1"
        if (-not (Test-Path $modulePath)) {
            Write-Host "❌ SpotifyModule not found at: $modulePath" -ForegroundColor Red
            Write-Host "💡 Sidecar functionality requires the SpotifyModule" -ForegroundColor Yellow
            return
        }
        
        Import-Module $modulePath -Force -ErrorAction Stop
        
        # Build command line arguments for sidecar
        $sidecarArgs = @()
        if ($startLive) {
            $sidecarArgs += "-Live"
            if ($liveMode -and $liveMode -ne "detailed") {
                $sidecarArgs += "-LiveMode", $liveMode
            }
        }
        
        Write-Host "🪟 Launching Spotify CLI in sidecar mode..." -ForegroundColor Cyan
        if ($startLive) {
            Write-Host "🎵 Sidecar will start in live display mode ($liveMode)" -ForegroundColor Cyan
        }
        
        $success = Start-SpotifyCliInSidecar -ScriptPath $PSCommandPath -SplitDirection $splitDirection -AdditionalArgs $sidecarArgs
        
        if ($success) {
            Write-Host "✅ Spotify CLI launched successfully in sidecar" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to launch sidecar mode" -ForegroundColor Red
            Write-Host ""
            Write-Host "🔧 TROUBLESHOOTING:" -ForegroundColor Yellow
            Write-Host "• Make sure you're using Windows Terminal or VS Code" -ForegroundColor White
            Write-Host "• Check that split window functionality is supported" -ForegroundColor White
            Write-Host "• Try using 'Test-SplitWindowSupport' to check compatibility" -ForegroundColor White
        }
        
    } catch {
        Write-Host "❌ Sidecar command error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Make sure the SpotifyModule is properly installed" -ForegroundColor Yellow
    }
}

function Invoke-LiveDisplayCommand {
    <#
    .SYNOPSIS
    Start live display mode with real-time track updates
    .PARAMETER Arguments
    Optional arguments for display mode (detailed, compact, minimal)
    #>
    param([string]$Arguments)
    
    try {
        # Parse display mode from arguments
        $displayMode = "detailed"
        if (-not [string]::IsNullOrWhiteSpace($Arguments)) {
            $mode = $Arguments.Trim().ToLower()
            if ($mode -in @("detailed", "compact", "minimal")) {
                $displayMode = $mode
            }
        }
        
        # Import live features module
        $liveModulePath = Join-Path $PSScriptRoot "modules\SpotifyLiveFeatures.psm1"
        if (-not (Test-Path $liveModulePath)) {
            Write-Host "❌ Live features module not found at: $liveModulePath" -ForegroundColor Red
            Write-Host "💡 Make sure the modules directory exists and contains the live features" -ForegroundColor Yellow
            return
        }
        
        Import-Module $liveModulePath -Force -ErrorAction Stop
        
        # Initialize live features
        Write-Host "🎵 Initializing Spotify Live Features..." -ForegroundColor Cyan
        Initialize-SpotifyLiveFeatures
        
        # Start live display
        Write-Host "🚀 Starting live display mode ($displayMode)..." -ForegroundColor Green
        Write-Host "Press Ctrl+C to exit live mode" -ForegroundColor Gray
        Write-Host ""
        
        Start-SpotifyLiveDisplay -Mode $displayMode
        
    } catch [System.OperationCanceledException] {
        Write-Host ""
        Write-Host "✅ Live display stopped" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "❌ Live display error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Make sure Spotify is running and you have an active device" -ForegroundColor Yellow
        
        # Provide troubleshooting information
        Write-Host ""
        Write-Host "🔧 TROUBLESHOOTING:" -ForegroundColor Yellow
        Write-Host "• Ensure Spotify is open and playing music" -ForegroundColor White
        Write-Host "• Check that you have an active Spotify device" -ForegroundColor White
        Write-Host "• Verify your internet connection" -ForegroundColor White
        Write-Host "• Try running 'spotify' command first to test connectivity" -ForegroundColor White
    } finally {
        # Cleanup
        try {
            Stop-SpotifyLiveFeatures
        } catch {
            # Ignore cleanup errors
        }
    }
}

function Invoke-SpotifyCommand {
    param([string]$Command)

    $parts = $Command.Trim() -split '\s+', 2
    $cmd = $parts[0].ToLower()
    $args = if ($parts.Length -gt 1) { $parts[1] } else { "" }

    switch ($cmd) {
        "spotify" { Show-CurrentTrack $args }
        "/spotify" { Show-CurrentTrack $args }
        "next" { Skip-ToNextTrack }
        "/next" { Skip-ToNextTrack }
        "previous" { Skip-ToPreviousTrack }
        "/previous" { Skip-ToPreviousTrack }
        "pause" { Stop-SpotifyPlayback }
        "/pause" { Stop-SpotifyPlayback }
        "play" { 
            if ($args -match "^(track|album|playlist)\s+") {
                Invoke-PlayCommand $args
            } else {
                Start-SpotifyPlayback
            }
        }
        "/play" { 
            if ($args -match "^(track|album|playlist)\s+") {
                Invoke-PlayCommand $args
            } else {
                Start-SpotifyPlayback
            }
        }
        "seek" { Invoke-SeekCommand $args }
        "/seek" { Invoke-SeekCommand $args }
        "volume" { Invoke-VolumeCommand $args }
        "/volume" { Invoke-VolumeCommand $args }
        "shuffle" { Invoke-ShuffleCommand $args }
        "/shuffle" { Invoke-ShuffleCommand $args }
        "repeat" { Invoke-RepeatCommand $args }
        "/repeat" { Invoke-RepeatCommand $args }
        "devices" { Invoke-DevicesCommand }
        "/devices" { Invoke-DevicesCommand }
        "transfer" { Invoke-TransferCommand $args }
        "/transfer" { Invoke-TransferCommand $args }
        "search" { Invoke-SearchCommand $args }
        "/search" { Invoke-SearchCommand $args }
        "queue" { Invoke-QueueCommand $args }
        "/queue" { Invoke-QueueCommand $args }
        "play-queue" { play-queue @args }
        "/play-queue" { play-queue @args }
        "pq" { play-queue @args }
        "playlists" { Invoke-PlaylistsCommand }
        "/playlists" { Invoke-PlaylistsCommand }
        "liked" { Invoke-LikedCommand }
        "/liked" { Invoke-LikedCommand }
        "save" { Invoke-SaveCommand }
        "/save" { Invoke-SaveCommand }
        "unsave" { Invoke-UnsaveCommand }
        "/unsave" { Invoke-UnsaveCommand }
        "recent" { Invoke-RecentCommand }
        "/recent" { Invoke-RecentCommand }
        "config" { Invoke-ConfigCommand $args }
        "/config" { Invoke-ConfigCommand $args }
        "config-live" { Invoke-LiveFeaturesConfigCommand $args }
        "/config-live" { Invoke-LiveFeaturesConfigCommand $args }
        "help" { Invoke-HelpCommand $args }
        "/help" { Invoke-HelpCommand $args }
        "history" { Invoke-HistoryCommand $args }
        "/history" { Invoke-HistoryCommand $args }
        "notifications" { Invoke-NotificationsCommand $args }
        "/notifications" { Invoke-NotificationsCommand $args }
        "auto-refresh" { Invoke-AutoRefreshCommand $args }
        "/auto-refresh" { Invoke-AutoRefreshCommand $args }
        "live" { Invoke-LiveDisplayCommand $args }
        "/live" { Invoke-LiveDisplayCommand $args }
        "sidecar" { Invoke-SidecarCommand $args }
        "/sidecar" { Invoke-SidecarCommand $args }
        "lyrics" { Invoke-LyricsCommand $args }
        "/lyrics" { Invoke-LyricsCommand $args }
        "peak" {
            $peakModulePath = Join-Path $PSScriptRoot "modules\UI\PeakDashboard.psm1"
            if (Test-Path $peakModulePath) {
                Import-Module $peakModulePath -Force -ErrorAction SilentlyContinue
                Show-PeakDashboard
            } else {
                Write-Host "Peak Dashboard module not found" -ForegroundColor Red
            }
        }
        "/peak" {
            $peakModulePath = Join-Path $PSScriptRoot "modules\UI\PeakDashboard.psm1"
            if (Test-Path $peakModulePath) {
                Import-Module $peakModulePath -Force -ErrorAction SilentlyContinue
                Show-PeakDashboard
            } else {
                Write-Host "Peak Dashboard module not found" -ForegroundColor Red
            }
        }
        "quiz" { Start-MusicQuiz $args }
        "/quiz" { Start-MusicQuiz $args }
        "setlist" {
            $setlistModulePath = Join-Path $PSScriptRoot "modules\Core\SetlistCommands.psm1"
            if (Test-Path $setlistModulePath) {
                Import-Module $setlistModulePath -Force -ErrorAction SilentlyContinue
                Invoke-SetlistCommand $args
            } else {
                Write-Host "Setlist module not found" -ForegroundColor Red
            }
        }
        "/setlist" {
            $setlistModulePath = Join-Path $PSScriptRoot "modules\Core\SetlistCommands.psm1"
            if (Test-Path $setlistModulePath) {
                Import-Module $setlistModulePath -Force -ErrorAction SilentlyContinue
                Invoke-SetlistCommand $args
            } else {
                Write-Host "Setlist module not found" -ForegroundColor Red
            }
        }
        "quit" { Write-Host "Avslutar." -ForegroundColor Cyan; exit }
        "/quit" { Write-Host "Avslutar." -ForegroundColor Cyan; exit }
        "exit" { Write-Host "Avslutar." -ForegroundColor Cyan; exit }
        "/exit" { Write-Host "Avslutar." -ForegroundColor Cyan; exit }
        "q" { Write-Host "Avslutar." -ForegroundColor Cyan; exit }
        "/q" { Write-Host "Avslutar." -ForegroundColor Cyan; exit }
        default { 
            Show-UnknownCommand $cmd
        }
    }
}

# Init: se till att vi har tokens (triggar auth vid behov)
[void](Get-SpotifyAccessToken)

Write-Host "Spotify CLI - Enhanced PowerShell Interface" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Welcome! Type /help to see all available commands." -ForegroundColor Green
Write-Host ""
Write-Host "Quick start commands:" -ForegroundColor Yellow
Write-Host "  /spotify    – Show current track" -ForegroundColor White
Write-Host "  /help       – Show all commands and detailed help" -ForegroundColor White
Write-Host "  /devices    – List available Spotify devices" -ForegroundColor White
Write-Host "  /search     – Search for music" -ForegroundColor White
Write-Host "  /playlists  – Show your playlists" -ForegroundColor White
Write-Host "  /config     – View/modify settings" -ForegroundColor White
Write-Host "  /quit       – Exit the CLI" -ForegroundColor White

# Initialize logging system
$config = Get-SpotifyConfig
if ($config.LoggingEnabled) {
    Write-Host "📝 Logging enabled (Level: $($config.LogLevel))" -ForegroundColor Gray
}

# Initialize notification system
if ($config.NotificationsEnabled) {
    $notificationSupport = Initialize-NotificationSystem
    if ($notificationSupport) {
        Write-Host "🔔 Notifications enabled" -ForegroundColor Gray
        
        # Initialize previous track ID with current track for proper change detection
        try {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing" -ErrorAction SilentlyContinue
            if ($currentTrack -and $currentTrack.item) {
                $script:PreviousTrackId = $currentTrack.item.id
            }
        } catch {
            # Ignore errors during initialization
        }
    }
}

#region Sidecar Mode Handling
# Handle sidecar/split window launch requests
if ($Sidecar -or $NewWindow) {
    try {
        # Import the SpotifyModule to get sidecar functions
        $modulePath = Join-Path $PSScriptRoot "SpotifyModule.psm1"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction SilentlyContinue
        }
        
        if ($Sidecar -and -not $NewWindow) {
            Write-Host "🪟 Launching Spotify CLI in sidecar mode..." -ForegroundColor Cyan
            
            # Build command line arguments for sidecar
            $sidecarArgs = @()
            if ($Live) {
                $sidecarArgs += "-Live"
                if ($LiveMode -ne "detailed") {
                    $sidecarArgs += "-LiveMode", $LiveMode
                }
            }
            
            $success = Start-SpotifyCliInSidecar -ScriptPath $PSCommandPath -SplitDirection $SplitDirection -AdditionalArgs $sidecarArgs
            if ($success) {
                Write-Host "✅ Spotify CLI launched successfully in sidecar" -ForegroundColor Green
                if ($Live) {
                    Write-Host "🎵 Sidecar will start in live display mode ($LiveMode)" -ForegroundColor Cyan
                }
                exit 0
            } else {
                Write-Host "⚠️ Sidecar launch failed, continuing in current terminal" -ForegroundColor Yellow
            }
        } elseif ($NewWindow) {
            Write-Host "🪟 Launching Spotify CLI in new window..." -ForegroundColor Cyan
            $success = Start-SpotifyCliInNewWindow -ScriptPath $PSCommandPath
            if ($success) {
                Write-Host "✅ Spotify CLI launched successfully in new window" -ForegroundColor Green
                exit 0
            } else {
                Write-Host "⚠️ New window launch failed, continuing in current terminal" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "❌ Error launching sidecar: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Continuing in current terminal..." -ForegroundColor Yellow
    }
}
#endregion

# Handle live mode launch
if ($Live) {
    Write-Host "🎵 Starting Spotify CLI in live display mode..." -ForegroundColor Cyan
    Write-Host ""

    # Start live display immediately
    Invoke-LiveDisplayCommand $LiveMode

    # Exit after live mode ends
    exit 0
}

# Handle setlist launch
if ($Setlist) {
    $setlistModulePath = Join-Path $PSScriptRoot "modules\Core\SetlistCommands.psm1"
    if (Test-Path $setlistModulePath) {
        Import-Module $setlistModulePath -Force -ErrorAction SilentlyContinue
        Invoke-SetlistCommand $Setlist
    } else {
        Write-Host "Setlist module not found" -ForegroundColor Red
    }
    exit 0
}

while ($true) {
    $cmd = Read-Host ">"

    Invoke-SpotifyCommand $cmd
}
#endregion CLI-loop

