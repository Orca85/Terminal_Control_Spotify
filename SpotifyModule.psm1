# Spotify PowerShell Module - Fixed Version
# Simple, working version with core functionality

#region Configuration
$script:ClientId = $env:SPOTIFY_CLIENT_ID
$script:ClientSecret = $env:SPOTIFY_CLIENT_SECRET
$script:RedirectUri = "http://127.0.0.1:8888/callback"
$script:Scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing user-read-private playlist-read-private user-library-read user-library-modify user-read-recently-played user-top-read"
$script:AppDataDir = Join-Path $env:APPDATA "SpotifyCLI"
$script:TokenFile = Join-Path $script:AppDataDir "tokens.json"
$script:ConfigFile = Join-Path $script:AppDataDir "config.json"
$script:TokenEndpoint = "https://accounts.spotify.com/api/token"
$script:ApiBase = "https://api.spotify.com/v1"

# Session storage for numbered references
$script:SessionDevices = @()
$script:SessionTracks = @()
$script:SessionPlaylists = @()

# Default configuration
$script:DefaultConfig = @{
    PreferredDevice = $null
    CompactMode = $false
    NotificationsEnabled = $false
    AutoRefreshInterval = 0
    LoggingEnabled = $false
    HistoryEnabled = $true
    MaxHistoryEntries = 100
    LogLevel = "Info"
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
    Aliases = @{
        'spotify' = 'Show-SpotifyTrack'
        'music' = 'Show-SpotifyTrack'
        'vol' = 'volume'
        'sh' = 'shuffle'
        'rep' = 'repeat'
        'tr' = 'transfer'
        'q' = 'queue'
        'pl' = 'playlists'
        'help' = 'Get-SpotifyHelp'
    }
}
#endregion

#region Helper Functions
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
            
            $tokenResp = Invoke-RestMethod -Method Post -Uri "https://accounts.spotify.com/api/token" -Body $body
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
    $requiredScopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing user-read-private playlist-read-private user-library-read user-library-modify user-read-recently-played user-top-read" -split ' '
    $tokenScopes = $Tokens.scopes -split ' '
    
    foreach ($scope in $requiredScopes) {
        if ($scope -notin $tokenScopes) {
            Write-Verbose "Missing required scope: $scope"
            return $false
        }
    }
    
    return $true
}

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
    $uri = "https://api.spotify.com/v1$Path"
    
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
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        
        switch ($statusCode) {
            401 {
                Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
                Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
            }
            403 {
                Write-Host "🚫 Permission Error: This operation requires Spotify Premium." -ForegroundColor Red
            }
            404 {
                if ($Path -like "*device*") {
                    Write-Host "📱 No Active Device: Please start Spotify on any device first." -ForegroundColor Red
                } else {
                    Write-Host "❓ Not Found: The requested resource was not found." -ForegroundColor Red
                }
            }
            429 {
                Write-Host "⏳ Rate Limit: Too many requests. Please wait a moment." -ForegroundColor Yellow
            }
            default {
                Write-Host "❌ API Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        return $null
    }
}

function Get-SpotifyConfig {
    if (-not (Test-Path $script:ConfigFile)) {
        return $script:DefaultConfig.Clone()
    }
    try {
        $json = Get-Content -Path $script:ConfigFile -Raw -ErrorAction Stop
        $config = ($json | ConvertFrom-Json)
        $result = $script:DefaultConfig.Clone()
        
        $config.PSObject.Properties | ForEach-Object {
            if ($_.Name -eq "Colors" -and $_.Value) {
                $result.Colors = @{}
                $_.Value.PSObject.Properties | ForEach-Object {
                    $result.Colors[$_.Name] = $_.Value
                }
            } elseif ($_.Name -eq "Aliases" -and $_.Value) {
                $result.Aliases = @{}
                $_.Value.PSObject.Properties | ForEach-Object {
                    $result.Aliases[$_.Name] = $_.Value
                }
            } else {
                $result[$_.Name] = $_.Value
            }
        }
        return $result
    } catch {
        return $script:DefaultConfig.Clone()
    }
}

function Set-SpotifyConfig {
    param([hashtable]$Config)
    try {
        if (-not (Test-Path $script:AppDataDir)) {
            New-Item -ItemType Directory -Path $script:AppDataDir | Out-Null
        }
        ($Config | ConvertTo-Json -Depth 5) | Set-Content -Path $script:ConfigFile -Encoding UTF8
        return $true
    } catch {
        return $false
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
    param([int]$Current, [int]$Total, [int]$Width = 30)
    if ($Total -le 0) { return "[$("░" * $Width)] 0%" }
    $percentage = [Math]::Round(($Current / $Total) * 100)
    $filled = [Math]::Round(($Current / $Total) * $Width)
    $empty = $Width - $filled
    if ($filled -gt $Width) { $filled = $Width; $empty = 0 }
    if ($filled -lt 0) { $filled = 0; $empty = $Width }
    $bar = "█" * $filled + "░" * $empty
    return "[$bar] $percentage%"
}
#endregion

#region Core Commands
function Show-SpotifyTrack {
    param([string]$Mode)
    
    try {
        $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        if (-not $currentTrack -or -not $currentTrack.item) {
            Write-Host "No track currently playing" -ForegroundColor Yellow
            return
        }
        
        $config = Get-SpotifyConfig
        $isCompact = ($Mode -eq "compact") -or $config.CompactMode
        
        $item = $currentTrack.item
        $isPlaying = $currentTrack.is_playing
        $progress = $currentTrack.progress_ms
        $duration = $item.duration_ms
        
        if ($isCompact) {
            $playIcon = if ($isPlaying) { "▶️" } else { "⏸️" }
            $name = if ($item.name.Length -gt 25) { $item.name.Substring(0, 22) + "..." } else { $item.name }
            $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
            if ($artists.Length -gt 20) { $artists = $artists.Substring(0, 17) + "..." }
            $progressBar = Show-ProgressBar -Current $progress -Total $duration -Width 15
            $timeInfo = "{0}/{1}" -f (Format-Time $progress), (Format-Time $duration)
            Write-Host "$playIcon $name - $artists | $progressBar $timeInfo" -ForegroundColor Cyan
        } else {
            Write-Host "🎵 " -NoNewline -ForegroundColor Cyan
            Write-Host $item.name -ForegroundColor Cyan
            Write-Host "👤 " -NoNewline -ForegroundColor Yellow
            Write-Host (($item.artists | ForEach-Object { $_.name }) -join ", ") -ForegroundColor Yellow
            Write-Host "📀 " -NoNewline -ForegroundColor Green
            Write-Host $item.album.name -ForegroundColor Green
            
            $progressBar = Show-ProgressBar -Current $progress -Total $duration
            Write-Host $progressBar -ForegroundColor Magenta
            
            $timeInfo = "{0} / {1}" -f (Format-Time $progress), (Format-Time $duration)
            $statusIcon = if ($isPlaying) { "▶️ Playing" } else { "⏸️ Paused" }
            Write-Host "⏱ $timeInfo $statusIcon" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Error getting current track: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Create alias for backward compatibility and easier typing
function spotify-now {
    param([string]$Mode)
    Show-SpotifyTrack $Mode
}

function play {
    param([string]$TrackReference)
    
    # If no parameter, just resume playback
    if ([string]::IsNullOrWhiteSpace($TrackReference)) {
        try {
            Invoke-SpotifyApi -Method PUT -Path "/me/player/play" | Out-Null
            Write-Host "▶️ Resumed playback" -ForegroundColor Green
        } catch {
            Write-Host "❌ Could not resume playback" -ForegroundColor Red
        }
        return
    }
    
    $trackUri = $TrackReference
    
    # Check if it's a number (track index from search)
    if ($TrackReference -match '^\d+$') {
        $trackIndex = [int]$TrackReference - 1
        if ($script:SessionTracks -and $trackIndex -ge 0 -and $trackIndex -lt $script:SessionTracks.Count) {
            $trackUri = $script:SessionTracks[$trackIndex].uri
            $trackName = $script:SessionTracks[$trackIndex].name
            $artists = ($script:SessionTracks[$trackIndex].artists | ForEach-Object { $_.name }) -join ", "
            Write-Host "🎯 Playing track #$TrackReference ($trackName by $artists)..." -ForegroundColor Cyan
        } else {
            Write-Host "❌ Invalid track number. Use 'search' to find tracks first." -ForegroundColor Red
            return
        }
    }
    
    # Ensure it's a valid Spotify URI
    if (-not $trackUri.StartsWith("spotify:track:")) {
        Write-Host "❌ Invalid track URI. Must start with 'spotify:track:'" -ForegroundColor Red
        return
    }
    
    try {
        $body = @{ uris = @($trackUri) }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
        Write-Host "▶️ Playing track" -ForegroundColor Green
    } catch {
        Write-Host "❌ Could not play track" -ForegroundColor Red
    }
}

function pause {
    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
        Write-Host "⏸️ Paused playback" -ForegroundColor Yellow
    } catch {
        Write-Host "❌ Could not pause playback" -ForegroundColor Red
    }
}

function next {
    try {
        Invoke-SpotifyApi -Method POST -Path "/me/player/next" | Out-Null
        Write-Host "⏭️ Skipped to next track" -ForegroundColor Green
        
        # Wait a moment for Spotify to update, then show notification
        Start-Sleep -Milliseconds 500
        
        # Get current track info and show notification
        try {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            if ($currentTrack -and $currentTrack.item) {
                Show-TrackNotification -TrackInfo $currentTrack.item
            }
        } catch {
            # If we can't get track info, show generic notification
            Show-TrackNotification -Title "Spotify" -Message "Skipped to next track"
        }
    } catch {
        Write-Host "❌ Could not skip to next track" -ForegroundColor Red
    }
}

function previous {
    try {
        Invoke-SpotifyApi -Method POST -Path "/me/player/previous" | Out-Null
        Write-Host "⏮️ Skipped to previous track" -ForegroundColor Green
        
        # Wait a moment for Spotify to update, then show notification
        Start-Sleep -Milliseconds 500
        
        # Get current track info and show notification
        try {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            if ($currentTrack -and $currentTrack.item) {
                Show-TrackNotification -TrackInfo $currentTrack.item
            }
        } catch {
            # If we can't get track info, show generic notification
            Show-TrackNotification -Title "Spotify" -Message "Skipped to previous track"
        }
    } catch {
        Write-Host "❌ Could not skip to previous track" -ForegroundColor Red
    }
}

function devices {
    try {
        $devicesResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/devices"
        if (-not $devicesResponse -or -not $devicesResponse.devices) {
            Write-Host "No devices found" -ForegroundColor Yellow
            return
        }
        
        # Store devices in session for numbered reference
        $script:SessionDevices = $devicesResponse.devices
        
        Write-Host "📱 Available Devices:" -ForegroundColor Cyan
        $i = 1
        foreach ($device in $devicesResponse.devices) {
            $deviceIcon = switch ($device.type.ToLower()) {
                "computer" { "💻" }
                "smartphone" { "📱" }
                "speaker" { "🔊" }
                "tv" { "📺" }
                default { "🎵" }
            }
            
            $activeStatus = if ($device.is_active) { "Active" } else { "Inactive" }
            $volumeInfo = if ($device.volume_percent -ne $null) { ", Volume: $($device.volume_percent)%" } else { "" }
            
            Write-Host "$i. $deviceIcon $($device.name) ($($device.type)) - $activeStatus$volumeInfo" -ForegroundColor White
            $i++
        }
        Write-Host ""
        Write-Host "💡 Tip: Use 'transfer 1' to switch to device #1" -ForegroundColor Gray
    } catch {
        Write-Host "❌ Could not get devices" -ForegroundColor Red
    }
}

function search {
    param([string]$Query)
    
    if ([string]::IsNullOrWhiteSpace($Query)) {
        Write-Host "Usage: search '<query>'" -ForegroundColor Yellow
        return
    }
    
    try {
        $searchQuery = @{ 
            q = $Query
            type = "track,artist,album"
            limit = "10"
        }
        Write-Host "Searching for: $Query" -ForegroundColor Gray
        $results = Invoke-SpotifyApi -Method GET -Path "/search" -Query $searchQuery
        
        if (-not $results) { return }
        
        Write-Host "🔍 Search Results for '$Query':" -ForegroundColor Cyan
        Write-Host ""
        
        if ($results.tracks -and $results.tracks.items) {
            # Store tracks in session for numbered reference
            $script:SessionTracks = $results.tracks.items[0..9]  # Store up to 10 tracks
            
            Write-Host "TRACKS:" -ForegroundColor Yellow
            $i = 1
            foreach ($track in $results.tracks.items[0..4]) {
                $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
                Write-Host "$i. $($track.name) - $artists ($($track.album.name))" -ForegroundColor White
                $i++
            }
            Write-Host ""
            Write-Host "💡 Tip: Use 'play 1' to play track #1, or 'queue 2' to add track #2 to queue" -ForegroundColor Gray
        }
    } catch {
        Write-Host "❌ Search failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-SpotifyHelp {
    param([string]$Command)
    
    if ([string]::IsNullOrWhiteSpace($Command)) {
        Write-Host "🎵 Spotify CLI - Complete Global Commands Help" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "BASIC PLAYBACK:" -ForegroundColor Yellow
        Write-Host "  spotify / music      - Show current track (detailed)" -ForegroundColor White
        Write-Host "  spotify-now          - Show current track (compact)" -ForegroundColor White
        Write-Host "  play                 - Resume playback" -ForegroundColor White
        Write-Host "  pause                - Pause playback" -ForegroundColor White
        Write-Host "  next                 - Skip to next track" -ForegroundColor White
        Write-Host "  previous             - Skip to previous track" -ForegroundColor White
        Write-Host ""
        Write-Host "ADVANCED CONTROLS:" -ForegroundColor Yellow
        Write-Host "  volume 75 / vol 75   - Set volume to 75%" -ForegroundColor White
        Write-Host "  seek 30              - Seek forward 30 seconds (negative for backward)" -ForegroundColor White
        Write-Host "  shuffle on / sh on   - Enable shuffle (on/off/toggle)" -ForegroundColor White
        Write-Host "  repeat track / rep track - Set repeat mode (track/context/off)" -ForegroundColor White
        Write-Host ""
        Write-Host "DEVICE MANAGEMENT:" -ForegroundColor Yellow
        Write-Host "  devices              - List available Spotify devices" -ForegroundColor White
        Write-Host "  transfer <id> / tr <id> - Transfer playback to device" -ForegroundColor White
        Write-Host ""
        Write-Host "SEARCH & QUEUE:" -ForegroundColor Yellow
        Write-Host "  search '<query>'     - Search for tracks, artists, albums" -ForegroundColor White
        Write-Host "  queue <uri> / q <uri> - Add track to playback queue" -ForegroundColor White
        Write-Host ""
        Write-Host "LIBRARY MANAGEMENT:" -ForegroundColor Yellow
        Write-Host "  playlists / pl       - Show your playlists" -ForegroundColor White
        Write-Host "  liked                - Show your liked songs" -ForegroundColor White
        Write-Host "  recent               - Show recently played tracks" -ForegroundColor White
        Write-Host "  save-track           - Save current track to library" -ForegroundColor White
        Write-Host "  unsave-track         - Remove current track from library" -ForegroundColor White
        Write-Host ""
        Write-Host "CONFIGURATION:" -ForegroundColor Yellow
        Write-Host "  Get-SpotifyConfig    - View current settings" -ForegroundColor White
        Write-Host "  Set-SpotifyConfig    - Modify settings" -ForegroundColor White
        Write-Host "  notifications on/off - Control notifications" -ForegroundColor White
        Write-Host "  Test-SpotifyAuth     - Check authentication status" -ForegroundColor White
        Write-Host ""
        Write-Host "ALIAS MANAGEMENT:" -ForegroundColor Yellow
        Write-Host "  Get-SpotifyAliases   - Show all configured aliases" -ForegroundColor White
        Write-Host "  Set-SpotifyAlias     - Create custom alias" -ForegroundColor White
        Write-Host "  Remove-SpotifyAlias  - Remove custom alias" -ForegroundColor White
        Write-Host "  Test-AliasConflicts  - Check for PowerShell conflicts" -ForegroundColor White
        Write-Host ""
        Write-Host "HELP:" -ForegroundColor Yellow
        Write-Host "  Get-SpotifyHelp / help - Show this help" -ForegroundColor White
        Write-Host "  spotify-help         - Short alias for help" -ForegroundColor White
        Write-Host ""
        Write-Host "EXAMPLES:" -ForegroundColor Green
        Write-Host "  spotify-now" -ForegroundColor Gray
        Write-Host "  Show-SpotifyTrack compact" -ForegroundColor Gray
        Write-Host "  search 'bohemian rhapsody'" -ForegroundColor Gray
        Write-Host "  Set-SpotifyConfig @{CompactMode=`$true}" -ForegroundColor Gray
        return
    }
    
    switch ($Command.ToLower()) {
        "spotify-now" {
            Write-Host "COMMAND: spotify-now [compact]" -ForegroundColor Cyan
            Write-Host "Shows current track information" -ForegroundColor White
            Write-Host "Use 'compact' for single-line display" -ForegroundColor Gray
        }
        "show-spotifytrack" {
            Write-Host "COMMAND: Show-SpotifyTrack [compact]" -ForegroundColor Cyan
            Write-Host "Shows current track information" -ForegroundColor White
            Write-Host "Use 'compact' for single-line display" -ForegroundColor Gray
        }
        "search" {
            Write-Host "COMMAND: search '<query>'" -ForegroundColor Cyan
            Write-Host "Search for tracks, artists, and albums" -ForegroundColor White
            Write-Host "Example: search 'the beatles'" -ForegroundColor Gray
        }
        "notifications" {
            Write-Host "COMMAND: notifications [on|off|status|test]" -ForegroundColor Cyan
            Write-Host "Control Windows toast notifications for track changes" -ForegroundColor White
            Write-Host ""
            Write-Host "Options:" -ForegroundColor Yellow
            Write-Host "  on      - Enable notifications" -ForegroundColor White
            Write-Host "  off     - Disable notifications" -ForegroundColor White
            Write-Host "  status  - Show current status (default)" -ForegroundColor White
            Write-Host "  test    - Test notification system" -ForegroundColor White
        }
        default {
            Write-Host "Unknown command: $Command" -ForegroundColor Red
            Write-Host "Available commands for detailed help:" -ForegroundColor Yellow
            Write-Host "  spotify-now, show-spotifytrack, search, notifications" -ForegroundColor White
            Write-Host ""
            Write-Host "Use Get-SpotifyHelp for all commands" -ForegroundColor Yellow
        }
    }
}

function spotify-help {
    param([string]$Command)
    Get-SpotifyHelp $Command
}

function Show-TrackNotification {
    <#
    .SYNOPSIS
    Display a Windows notification for track changes
    .PARAMETER TrackInfo
    Track information object from Spotify API
    .PARAMETER Title
    Custom notification title
    .PARAMETER Message
    Custom notification message
    .PARAMETER IsTest
    Whether this is a test notification
    #>
    param(
        $TrackInfo,
        [string]$Title,
        [string]$Message,
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
            $notificationTitle = if ($Title) { $Title } else { "Spotify CLI" }
            $notificationText = if ($Message) { $Message } else { "Notification" }
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
            Write-Host "🔔 $notificationTitle`: $notificationText" -ForegroundColor Cyan
        }
        
    } catch {
        # Final fallback to console notification
        if ($TrackInfo) {
            Write-Host "🎵 Now Playing: $($TrackInfo.name) by $(($TrackInfo.artists | ForEach-Object { $_.name }) -join ', ')" -ForegroundColor Cyan
        } else {
            Write-Host "🔔 $notificationTitle`: $notificationText" -ForegroundColor Cyan
        }
    }
}

function Test-NotificationSupport {
    <#
    .SYNOPSIS
    Test if Windows notifications are supported on this system
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

function notifications {
    <#
    .SYNOPSIS
    Control notification settings
    .PARAMETER Action
    Action to perform: 'on', 'off', 'status', or 'test'
    .EXAMPLE
    notifications on
    Enable notifications
    .EXAMPLE
    notifications test
    Test notification system
    #>
    param(
        [ValidateSet('on', 'off', 'status', 'test')]
        [string]$Action = 'status'
    )
    
    $config = Get-SpotifyConfig
    
    switch ($Action.ToLower()) {
        'on' {
            $config.NotificationsEnabled = $true
            if (Set-SpotifyConfig -Config $config) {
                Write-Host "🔔 Notifications enabled" -ForegroundColor Green
                
                # Test notification support
                $support = Test-NotificationSupport
                if ($support.Supported) {
                    Write-Host "✅ Notification system ready: $($support.Reason)" -ForegroundColor Green
                } else {
                    Write-Host "⚠️ Notification system limited: $($support.Reason)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "❌ Failed to enable notifications" -ForegroundColor Red
            }
        }
        'off' {
            $config.NotificationsEnabled = $false
            if (Set-SpotifyConfig -Config $config) {
                Write-Host "🔕 Notifications disabled" -ForegroundColor Yellow
            } else {
                Write-Host "❌ Failed to disable notifications" -ForegroundColor Red
            }
        }
        'test' {
            Write-Host "🧪 Testing notification system..." -ForegroundColor Cyan
            Show-TrackNotification -Title "Test Notification" -Message "Spotify CLI notification system is working!" -IsTest $true
        }
        'status' {
            $status = if ($config.NotificationsEnabled) { "Enabled" } else { "Disabled" }
            $color = if ($config.NotificationsEnabled) { "Green" } else { "Yellow" }
            
            Write-Host "🔔 Notifications: $status" -ForegroundColor $color
            
            if ($config.NotificationsEnabled) {
                $support = Test-NotificationSupport
                Write-Host "📋 System support: $($support.Reason)" -ForegroundColor Gray
            }
        }
    }
}

# Additional functions from CLI that should be available globally
function volume {
    <#
    .SYNOPSIS
    Control Spotify volume
    .PARAMETER Level
    Volume level (0-100)
    .EXAMPLE
    volume 75
    Set volume to 75%
    #>
    param([int]$Level)
    
    if ($Level -lt 0 -or $Level -gt 100) {
        Write-Host "❌ Volume must be between 0 and 100" -ForegroundColor Red
        return
    }
    
    try {
        $query = @{ volume_percent = $Level }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/volume" -Query $query | Out-Null
        Write-Host "🔊 Volume set to $Level%" -ForegroundColor Green
    } catch {
        Write-Host "❌ Could not set volume" -ForegroundColor Red
    }
}

function seek {
    <#
    .SYNOPSIS
    Seek in current track
    .PARAMETER Seconds
    Seconds to seek (positive = forward, negative = backward)
    .EXAMPLE
    seek 30
    Seek forward 30 seconds
    .EXAMPLE
    seek -10
    Seek backward 10 seconds
    #>
    param([int]$Seconds)
    
    try {
        $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        if (-not $currentTrack -or -not $currentTrack.item) {
            Write-Host "❌ No track currently playing" -ForegroundColor Red
            return
        }
        
        $currentPosition = $currentTrack.progress_ms
        $newPosition = $currentPosition + ($Seconds * 1000)
        $maxPosition = $currentTrack.item.duration_ms
        
        # Ensure position is within bounds
        if ($newPosition -lt 0) { $newPosition = 0 }
        if ($newPosition -gt $maxPosition) { $newPosition = $maxPosition }
        
        $query = @{ position_ms = $newPosition }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/seek" -Query $query | Out-Null
        
        $direction = if ($Seconds -gt 0) { "forward" } else { "backward" }
        Write-Host "⏩ Seeked $direction $([Math]::Abs($Seconds)) seconds" -ForegroundColor Green
    } catch {
        Write-Host "❌ Could not seek in track" -ForegroundColor Red
    }
}

function shuffle {
    <#
    .SYNOPSIS
    Control shuffle mode
    .PARAMETER State
    Shuffle state: 'on', 'off', or 'toggle'
    .EXAMPLE
    shuffle on
    Enable shuffle
    .EXAMPLE
    shuffle toggle
    Toggle shuffle state
    #>
    param([ValidateSet('on', 'off', 'toggle')][string]$State = 'toggle')
    
    try {
        if ($State -eq 'toggle') {
            # Get current state first
            $currentState = Invoke-SpotifyApi -Method GET -Path "/me/player"
            $currentShuffle = $currentState.shuffle_state
            $newState = -not $currentShuffle
        } else {
            $newState = ($State -eq 'on')
        }
        
        $query = @{ state = $newState.ToString().ToLower() }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/shuffle" -Query $query | Out-Null
        
        $stateText = if ($newState) { "enabled" } else { "disabled" }
        $icon = if ($newState) { "🔀" } else { "➡️" }
        Write-Host "$icon Shuffle $stateText" -ForegroundColor Green
    } catch {
        Write-Host "❌ Could not change shuffle state" -ForegroundColor Red
    }
}

function repeat {
    <#
    .SYNOPSIS
    Control repeat mode
    .PARAMETER Mode
    Repeat mode: 'track', 'context', 'off'
    .EXAMPLE
    repeat track
    Repeat current track
    .EXAMPLE
    repeat off
    Disable repeat
    #>
    param([ValidateSet('track', 'context', 'off')][string]$Mode = 'off')
    
    try {
        $query = @{ state = $Mode }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/repeat" -Query $query | Out-Null
        
        $icon = switch ($Mode) {
            "track" { "🔂" }
            "context" { "🔁" }
            "off" { "➡️" }
        }
        
        $modeText = switch ($Mode) {
            "track" { "current track" }
            "context" { "playlist/album" }
            "off" { "disabled" }
        }
        
        Write-Host "$icon Repeat $modeText" -ForegroundColor Green
    } catch {
        Write-Host "❌ Could not change repeat mode" -ForegroundColor Red
    }
}

function transfer {
    <#
    .SYNOPSIS
    Transfer playback to another device
    .PARAMETER DeviceId
    Device ID or number (from devices list) to transfer to
    .EXAMPLE
    transfer 1
    Transfer playback to device #1 from devices list
    .EXAMPLE
    transfer abc123
    Transfer playback to device with ID abc123
    #>
    param([string]$DeviceId)
    
    if ([string]::IsNullOrWhiteSpace($DeviceId)) {
        Write-Host "Usage: transfer <device_number_or_id>" -ForegroundColor Yellow
        Write-Host "Use 'devices' command to see available devices" -ForegroundColor Gray
        return
    }
    
    $actualDeviceId = $DeviceId
    
    # Check if it's a number (device index)
    if ($DeviceId -match '^\d+$') {
        $deviceIndex = [int]$DeviceId - 1
        if ($script:SessionDevices -and $deviceIndex -ge 0 -and $deviceIndex -lt $script:SessionDevices.Count) {
            $actualDeviceId = $script:SessionDevices[$deviceIndex].id
            $deviceName = $script:SessionDevices[$deviceIndex].name
            Write-Host "🎯 Transferring to device #$DeviceId ($deviceName)..." -ForegroundColor Cyan
        } else {
            Write-Host "❌ Invalid device number. Use 'devices' to see available devices." -ForegroundColor Red
            return
        }
    }
    
    try {
        $body = @{ device_ids = @($actualDeviceId) }
        Invoke-SpotifyApi -Method PUT -Path "/me/player" -Body $body | Out-Null
        Write-Host "📱 Playback transferred successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Could not transfer playback" -ForegroundColor Red
        Write-Host "Make sure the device is online and available" -ForegroundColor Gray
    }
}

function queue {
    <#
    .SYNOPSIS
    Add track to playback queue
    .PARAMETER TrackReference
    Track number (from search) or Spotify track URI
    .EXAMPLE
    queue 1
    Add track #1 from search results to queue
    .EXAMPLE
    queue spotify:track:4iV5W9uYEdYUVa79Axb7Rh
    Add track to queue by URI
    #>
    param([string]$TrackReference)
    
    if ([string]::IsNullOrWhiteSpace($TrackReference)) {
        Write-Host "Usage: queue <track_number_or_uri>" -ForegroundColor Yellow
        Write-Host "Use 'search' command to find tracks first" -ForegroundColor Gray
        return
    }
    
    $trackUri = $TrackReference
    
    # Check if it's a number (track index from search)
    if ($TrackReference -match '^\d+$') {
        $trackIndex = [int]$TrackReference - 1
        if ($script:SessionTracks -and $trackIndex -ge 0 -and $trackIndex -lt $script:SessionTracks.Count) {
            $trackUri = $script:SessionTracks[$trackIndex].uri
            $trackName = $script:SessionTracks[$trackIndex].name
            $artists = ($script:SessionTracks[$trackIndex].artists | ForEach-Object { $_.name }) -join ", "
            Write-Host "🎯 Adding track #$TrackReference ($trackName by $artists) to queue..." -ForegroundColor Cyan
        } else {
            Write-Host "❌ Invalid track number. Use 'search' to find tracks first." -ForegroundColor Red
            return
        }
    }
    
    # Ensure it's a valid Spotify URI
    if (-not $trackUri.StartsWith("spotify:track:")) {
        Write-Host "❌ Invalid track URI. Must start with 'spotify:track:'" -ForegroundColor Red
        return
    }
    
    try {
        $query = @{ uri = $trackUri }
        Invoke-SpotifyApi -Method POST -Path "/me/player/queue" -Query $query | Out-Null
        Write-Host "➕ Track added to queue" -ForegroundColor Green
    } catch {
        Write-Host "❌ Could not add track to queue" -ForegroundColor Red
    }
}

function playlists {
    <#
    .SYNOPSIS
    Show user's playlists
    .EXAMPLE
    playlists
    Show your playlists
    #>
    try {
        $playlistsResponse = Invoke-SpotifyApi -Method GET -Path "/me/playlists" -Query @{ limit = 20 }
        
        if (-not $playlistsResponse -or -not $playlistsResponse.items) {
            Write-Host "No playlists found" -ForegroundColor Yellow
            return
        }
        
        Write-Host "📚 Your Playlists:" -ForegroundColor Cyan
        Write-Host ""
        
        $i = 1
        foreach ($playlist in $playlistsResponse.items) {
            $trackCount = $playlist.tracks.total
            $owner = $playlist.owner.display_name
            $isOwn = $playlist.owner.id -eq $playlistsResponse.items[0].owner.id
            $ownerText = if ($isOwn) { "You" } else { $owner }
            
            Write-Host "$i. $($playlist.name)" -ForegroundColor White
            Write-Host "   $trackCount tracks • by $ownerText" -ForegroundColor Gray
            Write-Host "   URI: $($playlist.uri)" -ForegroundColor Gray
            Write-Host ""
            $i++
        }
    } catch {
        Write-Host "❌ Could not get playlists" -ForegroundColor Red
    }
}

function liked {
    <#
    .SYNOPSIS
    Show liked/saved tracks
    .EXAMPLE
    liked
    Show your liked songs
    #>
    try {
        $likedResponse = Invoke-SpotifyApi -Method GET -Path "/me/tracks" -Query @{ limit = 20 }
        
        if (-not $likedResponse -or -not $likedResponse.items) {
            Write-Host "No liked songs found" -ForegroundColor Yellow
            return
        }
        
        Write-Host "❤️ Your Liked Songs:" -ForegroundColor Cyan
        Write-Host ""
        
        $i = 1
        foreach ($item in $likedResponse.items) {
            $track = $item.track
            $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
            $addedDate = [DateTime]::Parse($item.added_at).ToString("yyyy-MM-dd")
            
            Write-Host "$i. $($track.name)" -ForegroundColor White
            Write-Host "   by $artists • $($track.album.name)" -ForegroundColor Gray
            Write-Host "   Added: $addedDate • URI: $($track.uri)" -ForegroundColor Gray
            Write-Host ""
            $i++
        }
    } catch {
        Write-Host "❌ Could not get liked songs" -ForegroundColor Red
    }
}

function recent {
    <#
    .SYNOPSIS
    Show recently played tracks
    .EXAMPLE
    recent
    Show recently played tracks
    #>
    try {
        $recentResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/recently-played" -Query @{ limit = 20 }
        
        if (-not $recentResponse -or -not $recentResponse.items) {
            Write-Host "No recent tracks found" -ForegroundColor Yellow
            return
        }
        
        Write-Host "🕒 Recently Played:" -ForegroundColor Cyan
        Write-Host ""
        
        $i = 1
        foreach ($item in $recentResponse.items) {
            $track = $item.track
            $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
            $playedDate = [DateTime]::Parse($item.played_at).ToString("yyyy-MM-dd HH:mm")
            
            Write-Host "$i. $($track.name)" -ForegroundColor White
            Write-Host "   by $artists • $($track.album.name)" -ForegroundColor Gray
            Write-Host "   Played: $playedDate • URI: $($track.uri)" -ForegroundColor Gray
            Write-Host ""
            $i++
        }
    } catch {
        Write-Host "❌ Could not get recent tracks" -ForegroundColor Red
    }
}

function save-track {
    <#
    .SYNOPSIS
    Save current track to library
    .EXAMPLE
    save-track
    Save the currently playing track
    #>
    try {
        $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        if (-not $currentTrack -or -not $currentTrack.item) {
            Write-Host "❌ No track currently playing" -ForegroundColor Red
            return
        }
        
        $trackId = $currentTrack.item.id
        $query = @{ ids = $trackId }
        Invoke-SpotifyApi -Method PUT -Path "/me/tracks" -Query $query | Out-Null
        
        Write-Host "❤️ Saved '$($currentTrack.item.name)' to your library" -ForegroundColor Green
    } catch {
        Write-Host "❌ Could not save track" -ForegroundColor Red
    }
}

function unsave-track {
    <#
    .SYNOPSIS
    Remove current track from library
    .EXAMPLE
    unsave-track
    Remove the currently playing track from library
    #>
    try {
        $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        if (-not $currentTrack -or -not $currentTrack.item) {
            Write-Host "❌ No track currently playing" -ForegroundColor Red
            return
        }
        
        $trackId = $currentTrack.item.id
        $query = @{ ids = $trackId }
        Invoke-SpotifyApi -Method DELETE -Path "/me/tracks" -Query $query | Out-Null
        
        Write-Host "💔 Removed '$($currentTrack.item.name)' from your library" -ForegroundColor Yellow
    } catch {
        Write-Host "❌ Could not remove track" -ForegroundColor Red
    }
}

function Test-AliasConflicts {
    <#
    .SYNOPSIS
    Test for alias conflicts with PowerShell built-ins
    .DESCRIPTION
    Checks if any Spotify aliases conflict with existing PowerShell commands
    .EXAMPLE
    Test-AliasConflicts
    Check for conflicts and show recommendations
    #>
    Write-Host "🔍 Checking for alias conflicts..." -ForegroundColor Cyan
    
    $config = Get-SpotifyConfig
    $conflicts = @()
    
    foreach ($alias in $config.Aliases.GetEnumerator()) {
        $existingCommand = Get-Command -Name $alias.Key -ErrorAction SilentlyContinue
        if ($existingCommand -and $existingCommand.CommandType -in @('Cmdlet', 'Alias') -and $existingCommand.Source -eq '') {
            $conflicts += @{
                Alias = $alias.Key
                Target = $alias.Value
                Conflicts = $existingCommand.Name
                Type = $existingCommand.CommandType
            }
        }
    }
    
    if ($conflicts.Count -eq 0) {
        Write-Host "✅ No conflicts found!" -ForegroundColor Green
        return
    }
    
    Write-Host "⚠️ Found $($conflicts.Count) conflict(s):" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($conflict in $conflicts) {
        Write-Host "  ❌ '$($conflict.Alias)' conflicts with PowerShell $($conflict.Type): $($conflict.Conflicts)" -ForegroundColor Red
        Write-Host "     Intended target: $($conflict.Target)" -ForegroundColor Gray
        
        # Suggest alternatives
        $alternatives = @("s$($conflict.Alias)", "$($conflict.Alias)s", "my$($conflict.Alias)")
        Write-Host "     Suggested alternatives: $($alternatives -join ', ')" -ForegroundColor Green
        Write-Host ""
    }
    
    Write-Host "💡 To fix conflicts:" -ForegroundColor Cyan
    Write-Host "1. Remove conflicting alias: Remove-SpotifyAlias -Alias 'sp'" -ForegroundColor White
    Write-Host "2. Create new alias: Set-SpotifyAlias -Alias 'spo' -Command 'Show-SpotifyTrack'" -ForegroundColor White
    Write-Host "3. Or use the full command names instead" -ForegroundColor White
}

function Test-SpotifyAuth {
    <#
    .SYNOPSIS
    Test Spotify authentication status
    .DESCRIPTION
    Checks if you're properly authenticated with Spotify and shows status
    .EXAMPLE
    Test-SpotifyAuth
    Check authentication status
    #>
    Write-Host "🔍 Checking Spotify authentication..." -ForegroundColor Cyan
    
    # Check if environment variables are set
    if (-not $env:SPOTIFY_CLIENT_ID -or -not $env:SPOTIFY_CLIENT_SECRET) {
        Write-Host "❌ Spotify credentials not found in environment variables" -ForegroundColor Red
        Write-Host "💡 Make sure .env file exists with SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET" -ForegroundColor Yellow
        return $false
    }
    
    # Check if tokens exist
    $tokens = Get-StoredTokens
    if (-not $tokens.access_token) {
        Write-Host "❌ No access token found" -ForegroundColor Red
        Write-Host "💡 Run .\spotifyCLI.ps1 to authenticate" -ForegroundColor Yellow
        return $false
    }
    
    # Test API call
    try {
        $profile = Invoke-SpotifyApi -Method GET -Path "/me"
        if ($profile) {
            Write-Host "✅ Authentication successful!" -ForegroundColor Green
            Write-Host "👤 Logged in as: $($profile.display_name)" -ForegroundColor Cyan
            Write-Host "📧 Email: $($profile.email)" -ForegroundColor Gray
            Write-Host "🎵 Subscription: $($profile.product)" -ForegroundColor Gray
            return $true
        } else {
            Write-Host "❌ Authentication failed" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Authentication test failed" -ForegroundColor Red
        return $false
    }
}
#endregion

# Alias management functions
function Initialize-SpotifyAliases {
    <#
    .SYNOPSIS
    Initialize default Spotify command aliases as wrapper functions
    #>
    $config = Get-SpotifyConfig
    
    # Default aliases if not configured
    if (-not $config.Aliases) {
        $config.Aliases = @{
            'sp' = 'Show-SpotifyTrack'
            'spotify' = 'Show-SpotifyTrack'
            'vol' = 'volume'
            'sh' = 'shuffle'
            'rep' = 'repeat'
            'tr' = 'transfer'
            'q' = 'queue'
            'pl' = 'playlists'
        }
        Set-SpotifyConfig -Config $config | Out-Null
    }
    
    # Create wrapper functions for each alias
    foreach ($alias in $config.Aliases.GetEnumerator()) {
        $aliasName = $alias.Key
        $targetCommand = $alias.Value
        
        # Check for conflicts with built-in PowerShell commands
        $existingCommand = Get-Command -Name $aliasName -ErrorAction SilentlyContinue
        if ($existingCommand -and $existingCommand.CommandType -in @('Cmdlet', 'Alias') -and $existingCommand.Source -eq '') {
            Write-Verbose "Skipping alias '$aliasName' - conflicts with built-in PowerShell command"
            continue
        }
        
        # Always recreate the function to ensure it's current
        try {
            # Create wrapper function dynamically with higher precedence
            $functionBody = @"
function global:$aliasName {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]`$Arguments)
    
    # Call the target Spotify command directly
    try {
        `$command = Get-Command -Name '$targetCommand' -CommandType Function -Module SpotifyModule -ErrorAction Stop
        if (`$Arguments) {
            & `$command @Arguments
        } else {
            & `$command
        }
    } catch {
        Write-Host "❌ Error calling Spotify command '$targetCommand': `$(`$_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Try running: Import-Module SpotifyModule -Force" -ForegroundColor Yellow
    }
}
"@
            
            # Execute the function definition
            Invoke-Expression $functionBody
            Write-Verbose "Created wrapper function: $aliasName -> $targetCommand"
            
        } catch {
            Write-Verbose "Failed to create wrapper function $aliasName`: $($_.Exception.Message)"
        }
    }
}

function Set-SpotifyAlias {
    <#
    .SYNOPSIS
    Set a custom alias for a Spotify command
    .PARAMETER Alias
    The alias name to create
    .PARAMETER Command
    The command the alias should point to
    .EXAMPLE
    Set-SpotifyAlias -Alias 'music' -Command 'Show-SpotifyTrack'
    Create alias 'music' for Show-SpotifyTrack
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Alias,
        [Parameter(Mandatory)]
        [string]$Command
    )
    
    $config = Get-SpotifyConfig
    if (-not $config.Aliases) {
        $config.Aliases = @{}
    }
    
    # Validate command exists
    $validCommands = @(
        'Show-SpotifyTrack', 'spotify-now', 'play', 'pause', 'next', 'previous',
        'volume', 'seek', 'shuffle', 'repeat', 'devices', 'transfer',
        'search', 'queue', 'playlists', 'liked', 'recent', 'save-track', 'unsave-track',
        'Get-SpotifyConfig', 'Set-SpotifyConfig', 'Get-SpotifyHelp', 'notifications', 'Test-SpotifyAuth'
    )
    
    if ($Command -notin $validCommands) {
        Write-Host "❌ Invalid command: $Command" -ForegroundColor Red
        Write-Host "Valid commands: $($validCommands -join ', ')" -ForegroundColor Gray
        return
    }
    
    # Add to config
    $config.Aliases[$Alias] = $Command
    
    if (Set-SpotifyConfig -Config $config) {
        # Create wrapper function immediately
        try {
            $functionBody = @"
function global:$Alias {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]`$Arguments)
    
    # Force use of the Spotify module command, not external applications
    `$command = Get-Command -Name '$Command' -CommandType Function -ErrorAction SilentlyContinue
    if (`$command) {
        if (`$Arguments) {
            & `$command @Arguments
        } else {
            & `$command
        }
    } else {
        Write-Host "❌ Spotify command '$Command' not found" -ForegroundColor Red
    }
}
"@
            Invoke-Expression $functionBody
            Write-Host "✅ Created alias '$Alias' → '$Command'" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Alias saved to config but couldn't create immediately: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "Restart PowerShell or reimport the module to activate" -ForegroundColor Gray
        }
    } else {
        Write-Host "❌ Failed to save alias configuration" -ForegroundColor Red
    }
}

function Remove-SpotifyAlias {
    <#
    .SYNOPSIS
    Remove a custom Spotify alias
    .PARAMETER Alias
    The alias name to remove
    .EXAMPLE
    Remove-SpotifyAlias -Alias 'music'
    Remove the 'music' alias
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Alias
    )
    
    $config = Get-SpotifyConfig
    if (-not $config.Aliases -or -not $config.Aliases.ContainsKey($Alias)) {
        Write-Host "❌ Alias '$Alias' not found" -ForegroundColor Red
        return
    }
    
    # Remove from config
    $config.Aliases.Remove($Alias)
    
    if (Set-SpotifyConfig -Config $config) {
        # Remove the wrapper function
        try {
            Remove-Item -Path "Function:\$Alias" -Force -ErrorAction SilentlyContinue
            Write-Host "✅ Removed alias '$Alias'" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Alias removed from config but couldn't remove immediately" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Failed to save alias configuration" -ForegroundColor Red
    }
}

function Get-SpotifyAliases {
    <#
    .SYNOPSIS
    Show all current Spotify aliases
    .EXAMPLE
    Get-SpotifyAliases
    List all configured aliases
    #>
    $config = Get-SpotifyConfig
    
    if (-not $config.Aliases -or $config.Aliases.Count -eq 0) {
        Write-Host "No aliases configured" -ForegroundColor Yellow
        return
    }
    
    Write-Host "🔗 Current Spotify Aliases:" -ForegroundColor Cyan
    Write-Host ""
    
    $config.Aliases.GetEnumerator() | Sort-Object Key | ForEach-Object {
        $aliasCommand = Get-Command -Name $_.Key -ErrorAction SilentlyContinue
        
        if ($aliasCommand) {
            if ($aliasCommand.CommandType -eq 'Function' -and $aliasCommand.Source -eq 'SpotifyModule') {
                $status = "✅"
                $note = ""
            } elseif ($aliasCommand.CommandType -in @('Cmdlet', 'Alias') -and $aliasCommand.Source -eq '') {
                $status = "⚠️"
                $note = " (conflicts with PowerShell built-in)"
            } else {
                $status = "❓"
                $note = " (unknown conflict)"
            }
        } else {
            $status = "❌"
            $note = " (not found)"
        }
        
        Write-Host "  $status $($_.Key) → $($_.Value)$note" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "Legend:" -ForegroundColor Gray
    Write-Host "  ✅ Working correctly" -ForegroundColor Green
    Write-Host "  ⚠️ Conflicts with PowerShell built-in" -ForegroundColor Yellow
    Write-Host "  ❌ Not available" -ForegroundColor Red
}

# Create default wrapper functions directly
function sp {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    if ($Arguments) {
        Show-SpotifyTrack @Arguments
    } else {
        Show-SpotifyTrack
    }
}

function spotify {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    if ($Arguments) {
        Show-SpotifyTrack @Arguments
    } else {
        Show-SpotifyTrack
    }
}

function vol {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    if ($Arguments) {
        volume @Arguments
    } else {
        volume
    }
}

function sh {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    if ($Arguments) {
        shuffle @Arguments
    } else {
        shuffle
    }
}

function rep {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    if ($Arguments) {
        repeat @Arguments
    } else {
        repeat
    }
}

function tr {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    if ($Arguments) {
        transfer @Arguments
    } else {
        transfer
    }
}

function q {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    if ($Arguments) {
        queue @Arguments
    } else {
        queue
    }
}

function pl {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    if ($Arguments) {
        playlists @Arguments
    } else {
        playlists
    }
}

# Initialize custom aliases when module loads
Initialize-SpotifyAliases

# Export functions and aliases
Export-ModuleMember -Function @(
    # Core playback
    'Show-SpotifyTrack', 'spotify-now', 'play', 'pause', 'next', 'previous',
    
    # Advanced controls
    'volume', 'seek', 'shuffle', 'repeat',
    
    # Device management
    'devices', 'transfer',
    
    # Search and queue
    'search', 'queue',
    
    # Library management
    'playlists', 'liked', 'recent', 'save-track', 'unsave-track',
    
    # Configuration and help
    'Get-SpotifyConfig', 'Set-SpotifyConfig', 'Get-SpotifyHelp', 'spotify-help',
    
    # Authentication
    'Test-SpotifyAuth',
    
    # Alias management
    'Set-SpotifyAlias', 'Remove-SpotifyAlias', 'Get-SpotifyAliases', 'Test-AliasConflicts',
    
    # Notifications
    'notifications', 'Show-TrackNotification', 'Test-NotificationSupport',
    
    # Default aliases as functions
    'sp', 'spotify', 'vol', 'sh', 'rep', 'tr', 'q', 'pl'
)