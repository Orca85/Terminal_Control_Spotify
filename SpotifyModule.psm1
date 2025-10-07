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
        
        # Detect if this is a podcast episode
        $isPodcast = $item.type -eq "episode" -or ($currentTrack.currently_playing_type -eq "episode")
        
        if ($isCompact) {
            $playIcon = if ($isPlaying) { "▶️" } else { "⏸️" }
            $name = if ($item.name.Length -gt 25) { $item.name.Substring(0, 22) + "..." } else { $item.name }
            
            if ($isPodcast) {
                # Podcast episode compact display
                $showName = if ($item.show.name.Length -gt 20) { $item.show.name.Substring(0, 17) + "..." } else { $item.show.name }
                $progressBar = Show-ProgressBar -Current $progress -Total $duration -Width 15
                $timeInfo = "{0}/{1}" -f (Format-Time $progress), (Format-Time $duration)
                Write-Host "$playIcon $name" -ForegroundColor Cyan
                Write-Host "    🎙️ $showName | $progressBar $timeInfo" -ForegroundColor Magenta
            } else {
                # Music track compact display
                $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                if ($artists.Length -gt 20) { $artists = $artists.Substring(0, 17) + "..." }
                $progressBar = Show-ProgressBar -Current $progress -Total $duration -Width 15
                $timeInfo = "{0}/{1}" -f (Format-Time $progress), (Format-Time $duration)
                Write-Host "$playIcon $name - $artists | $progressBar $timeInfo" -ForegroundColor Cyan
            }
        } else {
            if ($isPodcast) {
                # Enhanced detailed mode for podcast episodes
                Write-Host "🎙️ " -NoNewline -ForegroundColor Magenta
                Write-Host $item.name -ForegroundColor Cyan
                Write-Host "📻 " -NoNewline -ForegroundColor Yellow
                Write-Host $item.show.name -ForegroundColor Yellow
                
                # Show podcast description if available (truncated for readability)
                if ($item.description) {
                    $description = $item.description
                    if ($description.Length -gt 100) {
                        $description = $description.Substring(0, 97) + "..."
                    }
                    Write-Host "📝 " -NoNewline -ForegroundColor Gray
                    Write-Host $description -ForegroundColor Gray
                }
                
                # Show episode release date if available
                if ($item.release_date) {
                    try {
                        $releaseDate = [DateTime]::Parse($item.release_date)
                        Write-Host "📅 Released: $($releaseDate.ToString('MMM dd, yyyy'))" -ForegroundColor Gray
                    } catch {
                        Write-Host "📅 Released: $($item.release_date)" -ForegroundColor Gray
                    }
                }
                
                # Show episode language if available
                if ($item.language) {
                    Write-Host "🌐 Language: $($item.language.ToUpper())" -ForegroundColor Gray
                }
                
                # Show if episode is explicit
                if ($item.explicit) {
                    Write-Host "🔞 Explicit Content" -ForegroundColor Red
                }
                
                Write-Host ""  # New line after episode info
                
                # Progress bar for podcast episodes
                $progressBar = Show-ProgressBar -Current $progress -Total $duration
                Write-Host $progressBar -ForegroundColor Magenta
                
                $timeInfo = "{0} / {1}" -f (Format-Time $progress), (Format-Time $duration)
                $statusIcon = if ($isPlaying) { "▶️ Playing" } else { "⏸️ Paused" }
                Write-Host "⏱ $timeInfo $statusIcon" -ForegroundColor Gray
                
                # Show podcast show context
                Write-Host "💡 Podcast episode from '$($item.show.name)'" -ForegroundColor Cyan
                
            } else {
                # Music track detailed display
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
    
    # Check if it's a number (track/episode index from search)
    if ($TrackReference -match '^\d+$') {
        $itemIndex = [int]$TrackReference - 1
        if ($script:SessionTracks -and $itemIndex -ge 0 -and $itemIndex -lt $script:SessionTracks.Count) {
            $item = $script:SessionTracks[$itemIndex]
            $trackUri = $item.uri
            $itemName = $item.name
            
            if ($item.search_type -eq "episode" -or $item.type -eq "episode") {
                # Playing podcast episode
                $showName = $item.show.name
                Write-Host "🎯 Playing podcast episode #$TrackReference ($itemName from $showName)..." -ForegroundColor Magenta
            } else {
                # Playing music track
                $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                Write-Host "🎯 Playing track #$TrackReference ($itemName by $artists)..." -ForegroundColor Cyan
            }
        } else {
            Write-Host "❌ Invalid item number. Use 'search' to find tracks and episodes first." -ForegroundColor Red
            return
        }
    }
    
    # Ensure it's a valid Spotify URI
    if (-not ($trackUri.StartsWith("spotify:track:") -or $trackUri.StartsWith("spotify:episode:"))) {
        Write-Host "❌ Invalid URI. Must be a Spotify track or episode URI" -ForegroundColor Red
        return
    }
    
    try {
        $body = @{ uris = @($trackUri) }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
        if ($trackUri.StartsWith("spotify:episode:")) {
            Write-Host "▶️ Playing podcast episode" -ForegroundColor Magenta
        } else {
            Write-Host "▶️ Playing track" -ForegroundColor Green
        }
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
            type = "track,artist,album,episode"
            limit = "10"
        }
        Write-Host "Searching for: $Query" -ForegroundColor Gray
        $results = Invoke-SpotifyApi -Method GET -Path "/search" -Query $searchQuery
        
        if (-not $results) { return }
        
        Write-Host "🔍 Search Results for '$Query':" -ForegroundColor Cyan
        Write-Host ""
        
        # Combine tracks and episodes for numbered reference
        $allItems = @()
        $trackCount = 0
        $episodeCount = 0
        
        if ($results.tracks -and $results.tracks.items) {
            $trackCount = $results.tracks.items.Count
            $allItems += $results.tracks.items[0..4] | ForEach-Object { 
                $_ | Add-Member -NotePropertyName "search_type" -NotePropertyValue "track" -PassThru 
            }
        }
        
        if ($results.episodes -and $results.episodes.items) {
            $episodeCount = $results.episodes.items.Count
            $allItems += $results.episodes.items[0..4] | ForEach-Object { 
                $_ | Add-Member -NotePropertyName "search_type" -NotePropertyValue "episode" -PassThru 
            }
        }
        
        # Store combined items in session for numbered reference
        $script:SessionTracks = $allItems[0..9]  # Store up to 10 items (tracks + episodes)
        
        if ($results.tracks -and $results.tracks.items) {
            Write-Host "TRACKS:" -ForegroundColor Yellow
            $i = 1
            foreach ($track in $results.tracks.items[0..4]) {
                $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
                Write-Host "$i. $($track.name) - $artists ($($track.album.name))" -ForegroundColor White
                $i++
            }
            Write-Host ""
        }
        
        if ($results.episodes -and $results.episodes.items) {
            Write-Host "PODCAST EPISODES:" -ForegroundColor Magenta
            $startIndex = ($results.tracks.items.Count -gt 0) ? ($results.tracks.items[0..4].Count + 1) : 1
            $i = $startIndex
            foreach ($episode in $results.episodes.items[0..4]) {
                $showName = $episode.show.name
                $description = if ($episode.description -and $episode.description.Length -gt 50) { 
                    $episode.description.Substring(0, 47) + "..." 
                } else { 
                    $episode.description 
                }
                Write-Host "$i. 🎙️ $($episode.name) - $showName" -ForegroundColor White
                if ($description) {
                    Write-Host "   📝 $description" -ForegroundColor Gray
                }
                $i++
            }
            Write-Host ""
        }
        
        if ($allItems.Count -gt 0) {
            Write-Host "💡 Tip: Use 'play 1' to play item #1, or 'queue 2' to add item #2 to queue" -ForegroundColor Gray
            if ($episodeCount -gt 0) {
                Write-Host "💡 Podcast episodes can be saved using 'save-track <number>'" -ForegroundColor Gray
            }
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
    Seek in current track or podcast episode
    .PARAMETER Seconds
    Seconds to seek (positive = forward, negative = backward)
    .EXAMPLE
    seek 30
    Seek forward 30 seconds
    .EXAMPLE
    seek -10
    Seek backward 10 seconds
    .EXAMPLE
    seek -30
    Seek backward 30 seconds (useful for podcast replay)
    #>
    param([int]$Seconds)
    
    try {
        $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        if (-not $currentTrack -or -not $currentTrack.item) {
            Write-Host "❌ No track or episode currently playing" -ForegroundColor Red
            return
        }
        
        $item = $currentTrack.item
        $isPodcast = $item.type -eq "episode" -or ($currentTrack.currently_playing_type -eq "episode")
        
        $currentPosition = $currentTrack.progress_ms
        $newPosition = $currentPosition + ($Seconds * 1000)
        $maxPosition = $item.duration_ms
        
        # Ensure position is within bounds
        if ($newPosition -lt 0) { $newPosition = 0 }
        if ($newPosition -gt $maxPosition) { $newPosition = $maxPosition }
        
        $query = @{ position_ms = $newPosition }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/seek" -Query $query | Out-Null
        
        $direction = if ($Seconds -gt 0) { "forward" } else { "backward" }
        $absSeconds = [Math]::Abs($Seconds)
        
        if ($isPodcast) {
            Write-Host "⏩ Seeked $direction $absSeconds seconds in podcast episode" -ForegroundColor Magenta
            
            # Show current position for podcast episodes (more useful for long content)
            $currentTimeStr = Format-Time $newPosition
            $totalTimeStr = Format-Time $maxPosition
            Write-Host "📍 Position: $currentTimeStr / $totalTimeStr" -ForegroundColor Gray
        } else {
            Write-Host "⏩ Seeked $direction $absSeconds seconds" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Could not seek in current content" -ForegroundColor Red
    }
}

function skip-forward {
    <#
    .SYNOPSIS
    Skip forward 30 seconds (common podcast control)
    .EXAMPLE
    skip-forward
    Skip forward 30 seconds in current episode or track
    #>
    seek 30
}

function skip-back {
    <#
    .SYNOPSIS
    Skip backward 15 seconds (common podcast control)
    .EXAMPLE
    skip-back
    Skip backward 15 seconds in current episode or track
    #>
    seek -15
}

function replay {
    <#
    .SYNOPSIS
    Skip backward 30 seconds (useful for podcast replay)
    .EXAMPLE
    replay
    Skip backward 30 seconds to replay content
    #>
    seek -30
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
            $playedDate = [DateTime]::Parse($item.played_at).ToString("yyyy-MM-dd HH:mm")
            
            if ($item.track) {
                # Music track
                $track = $item.track
                $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
                
                Write-Host "$i. $($track.name)" -ForegroundColor White
                Write-Host "   by $artists • $($track.album.name)" -ForegroundColor Gray
                Write-Host "   Played: $playedDate • URI: $($track.uri)" -ForegroundColor Gray
            } elseif ($item.episode) {
                # Podcast episode
                $episode = $item.episode
                
                Write-Host "$i. 🎙️ $($episode.name)" -ForegroundColor Magenta
                Write-Host "   from $($episode.show.name)" -ForegroundColor Gray
                if ($episode.description) {
                    $description = if ($episode.description.Length -gt 60) { 
                        $episode.description.Substring(0, 57) + "..." 
                    } else { 
                        $episode.description 
                    }
                    Write-Host "   📝 $description" -ForegroundColor Gray
                }
                Write-Host "   Played: $playedDate • URI: $($episode.uri)" -ForegroundColor Gray
            }
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
    Save current track or podcast episode to library
    .EXAMPLE
    save-track
    Save the currently playing track or episode
    .EXAMPLE
    save-track 3
    Save item #3 from search results
    #>
    param([string]$ItemReference)
    
    try {
        $item = $null
        $itemName = ""
        $isEpisode = $false
        
        if ([string]::IsNullOrWhiteSpace($ItemReference)) {
            # Save currently playing item
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            if (-not $currentTrack -or -not $currentTrack.item) {
                Write-Host "❌ No track or episode currently playing" -ForegroundColor Red
                return
            }
            $item = $currentTrack.item
            $itemName = $item.name
            $isEpisode = $item.type -eq "episode" -or ($currentTrack.currently_playing_type -eq "episode")
        } else {
            # Save item from search results by number
            if ($ItemReference -match '^\d+$') {
                $itemIndex = [int]$ItemReference - 1
                if ($script:SessionTracks -and $itemIndex -ge 0 -and $itemIndex -lt $script:SessionTracks.Count) {
                    $item = $script:SessionTracks[$itemIndex]
                    $itemName = $item.name
                    $isEpisode = $item.search_type -eq "episode" -or $item.type -eq "episode"
                } else {
                    Write-Host "❌ Invalid item number. Use 'search' to find tracks and episodes first." -ForegroundColor Red
                    return
                }
            } else {
                Write-Host "❌ Invalid item reference. Use a number from search results." -ForegroundColor Red
                return
            }
        }
        
        $itemId = $item.id
        $query = @{ ids = $itemId }
        
        if ($isEpisode) {
            # Save podcast episode
            Invoke-SpotifyApi -Method PUT -Path "/me/episodes" -Query $query | Out-Null
            Write-Host "❤️ Saved podcast episode '$itemName' to your library" -ForegroundColor Magenta
        } else {
            # Save music track
            Invoke-SpotifyApi -Method PUT -Path "/me/tracks" -Query $query | Out-Null
            Write-Host "❤️ Saved track '$itemName' to your library" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Could not save item" -ForegroundColor Red
    }
}

function unsave-track {
    <#
    .SYNOPSIS
    Remove current track or podcast episode from library
    .EXAMPLE
    unsave-track
    Remove the currently playing track or episode from library
    .EXAMPLE
    unsave-track 3
    Remove item #3 from search results from library
    #>
    param([string]$ItemReference)
    
    try {
        $item = $null
        $itemName = ""
        $isEpisode = $false
        
        if ([string]::IsNullOrWhiteSpace($ItemReference)) {
            # Unsave currently playing item
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            if (-not $currentTrack -or -not $currentTrack.item) {
                Write-Host "❌ No track or episode currently playing" -ForegroundColor Red
                return
            }
            $item = $currentTrack.item
            $itemName = $item.name
            $isEpisode = $item.type -eq "episode" -or ($currentTrack.currently_playing_type -eq "episode")
        } else {
            # Unsave item from search results by number
            if ($ItemReference -match '^\d+$') {
                $itemIndex = [int]$ItemReference - 1
                if ($script:SessionTracks -and $itemIndex -ge 0 -and $itemIndex -lt $script:SessionTracks.Count) {
                    $item = $script:SessionTracks[$itemIndex]
                    $itemName = $item.name
                    $isEpisode = $item.search_type -eq "episode" -or $item.type -eq "episode"
                } else {
                    Write-Host "❌ Invalid item number. Use 'search' to find tracks and episodes first." -ForegroundColor Red
                    return
                }
            } else {
                Write-Host "❌ Invalid item reference. Use a number from search results." -ForegroundColor Red
                return
            }
        }
        
        $itemId = $item.id
        $query = @{ ids = $itemId }
        
        if ($isEpisode) {
            # Unsave podcast episode
            Invoke-SpotifyApi -Method DELETE -Path "/me/episodes" -Query $query | Out-Null
            Write-Host "💔 Removed podcast episode '$itemName' from your library" -ForegroundColor Yellow
        } else {
            # Unsave music track
            Invoke-SpotifyApi -Method DELETE -Path "/me/tracks" -Query $query | Out-Null
            Write-Host "💔 Removed track '$itemName' from your library" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ Could not remove item" -ForegroundColor Red
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

#region Window Management and Terminal Detection

function Get-TerminalCapabilities {
    <#
    .SYNOPSIS
    Detect terminal capabilities for split window support and other features
    
    .DESCRIPTION
    Analyzes the current PowerShell environment to determine what terminal features
    are available, including split window support, interactive input, and visual capabilities.
    
    .OUTPUTS
    Hashtable with capability information
    #>
    
    $capabilities = @{
        SupportsColors = $true
        SupportsInteractiveInput = $true
        SupportsSplitWindow = $false
        SupportsToastNotifications = $true
        TerminalType = "Unknown"
        CanCreateNewWindow = $true
        WindowsTerminalAvailable = $false
        VSCodeTerminal = $false
    }
    
    try {
        # Detect terminal type based on environment variables and process information
        $parentProcess = $null
        $currentProcess = Get-Process -Id $PID -ErrorAction SilentlyContinue
        
        if ($currentProcess -and $currentProcess.Parent) {
            $parentProcess = Get-Process -Id $currentProcess.Parent.Id -ErrorAction SilentlyContinue
        }
        
        # Check for Windows Terminal
        if ($env:WT_SESSION -or $env:WT_PROFILE_ID) {
            $capabilities.TerminalType = "WindowsTerminal"
            $capabilities.SupportsSplitWindow = $true
            $capabilities.WindowsTerminalAvailable = $true
        }
        # Check for VS Code terminal
        elseif ($env:TERM_PROGRAM -eq "vscode" -or $env:VSCODE_PID) {
            $capabilities.TerminalType = "VSCode"
            $capabilities.SupportsSplitWindow = $true
            $capabilities.VSCodeTerminal = $true
        }
        # Check for PowerShell ISE
        elseif ($psISE) {
            $capabilities.TerminalType = "PowerShellISE"
            $capabilities.SupportsInteractiveInput = $false
            $capabilities.SupportsSplitWindow = $false
        }
        # Check for Windows PowerShell Console Host
        elseif ($Host.Name -eq "ConsoleHost") {
            if ($parentProcess -and $parentProcess.ProcessName -eq "WindowsTerminal") {
                $capabilities.TerminalType = "WindowsTerminal"
                $capabilities.SupportsSplitWindow = $true
                $capabilities.WindowsTerminalAvailable = $true
            } elseif ($parentProcess -and $parentProcess.ProcessName -eq "Code") {
                $capabilities.TerminalType = "VSCode"
                $capabilities.SupportsSplitWindow = $true
                $capabilities.VSCodeTerminal = $true
            } else {
                $capabilities.TerminalType = "PowerShellConsole"
            }
        }
        # Check for PowerShell 7+ terminal
        elseif ($Host.Name -eq "ConsoleHost" -and $PSVersionTable.PSVersion.Major -ge 7) {
            $capabilities.TerminalType = "PowerShell7Console"
        }
        
        # Test for Windows Terminal availability even if not currently running in it
        if (-not $capabilities.WindowsTerminalAvailable) {
            try {
                $wtPath = Get-Command "wt" -ErrorAction SilentlyContinue
                if ($wtPath) {
                    $capabilities.WindowsTerminalAvailable = $true
                }
            } catch {
                # Windows Terminal not available
            }
        }
        
        # Test color support
        try {
            $capabilities.SupportsColors = $Host.UI.SupportsVirtualTerminal -or 
                                         ($env:TERM -and $env:TERM -ne "dumb") -or
                                         ($capabilities.TerminalType -in @("WindowsTerminal", "VSCode", "PowerShellConsole"))
        } catch {
            $capabilities.SupportsColors = $true  # Assume support by default
        }
        
        # Test interactive input support
        try {
            $capabilities.SupportsInteractiveInput = $Host.UI.RawUI -and 
                                                    $capabilities.TerminalType -ne "PowerShellISE"
        } catch {
            $capabilities.SupportsInteractiveInput = $true  # Assume support by default
        }
        
        # Test toast notification support
        try {
            $capabilities.SupportsToastNotifications = [System.Environment]::OSVersion.Platform -eq "Win32NT" -and
                                                      [System.Environment]::OSVersion.Version.Major -ge 10
        } catch {
            $capabilities.SupportsToastNotifications = $true  # Assume support by default
        }
        
    } catch {
        Write-Verbose "Error detecting terminal capabilities: $($_.Exception.Message)"
        # Return safe defaults on error
    }
    
    return $capabilities
}

function Test-SplitWindowSupport {
    <#
    .SYNOPSIS
    Test if the current terminal supports split window functionality
    
    .DESCRIPTION
    Checks if the current terminal environment supports creating split panes or windows
    
    .OUTPUTS
    Boolean indicating split window support
    #>
    
    $capabilities = Get-TerminalCapabilities
    return $capabilities.SupportsSplitWindow
}

function Get-WindowsTerminalPath {
    <#
    .SYNOPSIS
    Get the path to Windows Terminal executable
    
    .DESCRIPTION
    Attempts to locate the Windows Terminal executable in common locations
    
    .OUTPUTS
    String path to wt.exe or $null if not found
    #>
    
    try {
        # Try to find wt command
        $wtCommand = Get-Command "wt" -ErrorAction SilentlyContinue
        if ($wtCommand) {
            return $wtCommand.Source
        }
        
        # Try common installation paths
        $commonPaths = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe",
            "$env:ProgramFiles\WindowsApps\Microsoft.WindowsTerminal*\wt.exe",
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\wt.exe"
        )
        
        foreach ($path in $commonPaths) {
            $resolved = Resolve-Path $path -ErrorAction SilentlyContinue
            if ($resolved) {
                return $resolved.Path
            }
        }
        
        return $null
    } catch {
        return $null
    }
}

function Show-TerminalCapabilities {
    <#
    .SYNOPSIS
    Display current terminal capabilities for debugging
    
    .DESCRIPTION
    Shows detailed information about the current terminal environment and its capabilities
    #>
    
    $capabilities = Get-TerminalCapabilities
    
    Write-Host "🖥️ Terminal Capabilities Report" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Terminal Type: " -NoNewline -ForegroundColor Yellow
    Write-Host $capabilities.TerminalType -ForegroundColor White
    
    Write-Host "Supports Colors: " -NoNewline -ForegroundColor Yellow
    $colorStatus = if ($capabilities.SupportsColors) { "✅ Yes" } else { "❌ No" }
    Write-Host $colorStatus -ForegroundColor $(if ($capabilities.SupportsColors) { "Green" } else { "Red" })
    
    Write-Host "Supports Interactive Input: " -NoNewline -ForegroundColor Yellow
    $interactiveStatus = if ($capabilities.SupportsInteractiveInput) { "✅ Yes" } else { "❌ No" }
    Write-Host $interactiveStatus -ForegroundColor $(if ($capabilities.SupportsInteractiveInput) { "Green" } else { "Red" })
    
    Write-Host "Supports Split Window: " -NoNewline -ForegroundColor Yellow
    $splitStatus = if ($capabilities.SupportsSplitWindow) { "✅ Yes" } else { "❌ No" }
    Write-Host $splitStatus -ForegroundColor $(if ($capabilities.SupportsSplitWindow) { "Green" } else { "Red" })
    
    Write-Host "Supports Toast Notifications: " -NoNewline -ForegroundColor Yellow
    $toastStatus = if ($capabilities.SupportsToastNotifications) { "✅ Yes" } else { "❌ No" }
    Write-Host $toastStatus -ForegroundColor $(if ($capabilities.SupportsToastNotifications) { "Green" } else { "Red" })
    
    Write-Host "Windows Terminal Available: " -NoNewline -ForegroundColor Yellow
    $wtStatus = if ($capabilities.WindowsTerminalAvailable) { "✅ Yes" } else { "❌ No" }
    Write-Host $wtStatus -ForegroundColor $(if ($capabilities.WindowsTerminalAvailable) { "Green" } else { "Red" })
    
    Write-Host "VS Code Terminal: " -NoNewline -ForegroundColor Yellow
    $vscodeStatus = if ($capabilities.VSCodeTerminal) { "✅ Yes" } else { "❌ No" }
    Write-Host $vscodeStatus -ForegroundColor $(if ($capabilities.VSCodeTerminal) { "Green" } else { "Red" })
    
    Write-Host ""
    Write-Host "Environment Details:" -ForegroundColor Yellow
    Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "  Host Name: $($Host.Name)" -ForegroundColor Gray
    Write-Host "  Process ID: $PID" -ForegroundColor Gray
    
    if ($env:WT_SESSION) {
        Write-Host "  Windows Terminal Session: $($env:WT_SESSION)" -ForegroundColor Gray
    }
    if ($env:WT_PROFILE_ID) {
        Write-Host "  Windows Terminal Profile: $($env:WT_PROFILE_ID)" -ForegroundColor Gray
    }
    if ($env:VSCODE_PID) {
        Write-Host "  VS Code Process ID: $($env:VSCODE_PID)" -ForegroundColor Gray
    }
    if ($env:TERM_PROGRAM) {
        Write-Host "  Terminal Program: $($env:TERM_PROGRAM)" -ForegroundColor Gray
    }
}

function Start-SpotifyCliInSidecar {
    <#
    .SYNOPSIS
    Launch Spotify CLI in a split window or sidecar
    
    .DESCRIPTION
    Attempts to launch the Spotify CLI in a split window or sidecar based on the current terminal capabilities.
    Falls back to a new window if split window is not supported.
    
    .PARAMETER ScriptPath
    Path to the spotifyCLI.ps1 script to launch
    
    .PARAMETER ForceNewWindow
    Force opening in a new window instead of attempting split window
    
    .PARAMETER SplitDirection
    Direction for split window (right, down, left, up). Only applies to Windows Terminal.
    
    .OUTPUTS
    Boolean indicating success of the launch operation
    #>
    
    param(
        [string]$ScriptPath = ".\spotifyCLI.ps1",
        [switch]$ForceNewWindow,
        [ValidateSet("right", "down", "left", "up")]
        [string]$SplitDirection = "right"
    )
    
    $capabilities = Get-TerminalCapabilities
    
    # Resolve the script path
    if (-not (Test-Path $ScriptPath)) {
        # Try to find the script in the current directory or module directory
        $possiblePaths = @(
            $ScriptPath,
            ".\spotifyCLI.ps1",
            "$PSScriptRoot\spotifyCLI.ps1",
            "$(Split-Path $PSScriptRoot)\spotifyCLI.ps1"
        )
        
        $foundPath = $null
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $foundPath = Resolve-Path $path
                break
            }
        }
        
        if (-not $foundPath) {
            Write-Host "❌ Could not find spotifyCLI.ps1 script" -ForegroundColor Red
            Write-Host "💡 Please ensure the script is in the current directory or specify the full path" -ForegroundColor Yellow
            return $false
        }
        
        $ScriptPath = $foundPath.Path
    }
    
    # If force new window or split not supported, use new window
    if ($ForceNewWindow -or -not $capabilities.SupportsSplitWindow) {
        return Start-SpotifyCliInNewWindow -ScriptPath $ScriptPath
    }
    
    # Attempt split window based on terminal type
    switch ($capabilities.TerminalType) {
        "WindowsTerminal" {
            return Start-SpotifyCliInWindowsTerminalSplit -ScriptPath $ScriptPath -SplitDirection $SplitDirection
        }
        "VSCode" {
            return Start-SpotifyCliInVSCodeSplit -ScriptPath $ScriptPath
        }
        default {
            Write-Host "💡 Split window not supported in $($capabilities.TerminalType). Opening in new window..." -ForegroundColor Yellow
            return Start-SpotifyCliInNewWindow -ScriptPath $ScriptPath
        }
    }
}

function Start-SpotifyCliInWindowsTerminalSplit {
    <#
    .SYNOPSIS
    Launch Spotify CLI in Windows Terminal split pane
    
    .PARAMETER ScriptPath
    Path to the spotifyCLI.ps1 script
    
    .PARAMETER SplitDirection
    Direction for the split (right, down, left, up)
    #>
    
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        [string]$SplitDirection = "right"
    )
    
    try {
        $wtPath = Get-WindowsTerminalPath
        if (-not $wtPath) {
            Write-Host "❌ Windows Terminal not found" -ForegroundColor Red
            return $false
        }
        
        # Build Windows Terminal split command
        $splitArg = switch ($SplitDirection.ToLower()) {
            "right" { "--split-pane" }
            "down" { "--split-pane", "--vertical" }
            "left" { "--split-pane", "--horizontal" }
            "up" { "--split-pane", "--vertical" }
            default { "--split-pane" }
        }
        
        # Create the command arguments
        $arguments = @($splitArg) + @("--profile", "PowerShell") + @("powershell", "-NoExit", "-Command", "& '$ScriptPath'")
        
        Write-Host "🪟 Opening Spotify CLI in Windows Terminal split pane..." -ForegroundColor Cyan
        Start-Process -FilePath $wtPath -ArgumentList $arguments -ErrorAction Stop
        
        Write-Host "✅ Spotify CLI launched in split pane" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "❌ Failed to open Windows Terminal split: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Falling back to new window..." -ForegroundColor Yellow
        return Start-SpotifyCliInNewWindow -ScriptPath $ScriptPath
    }
}

function Start-SpotifyCliInVSCodeSplit {
    <#
    .SYNOPSIS
    Launch Spotify CLI in VS Code terminal split
    
    .PARAMETER ScriptPath
    Path to the spotifyCLI.ps1 script
    #>
    
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )
    
    try {
        # VS Code terminal splitting requires the VS Code command palette or extension
        # For now, provide user guidance and fall back to new terminal
        Write-Host "💡 VS Code Terminal Split Instructions:" -ForegroundColor Cyan
        Write-Host "   1. Press Ctrl+Shift+5 to split the terminal" -ForegroundColor Gray
        Write-Host "   2. In the new terminal pane, run: & '$ScriptPath'" -ForegroundColor Gray
        Write-Host "   3. Or use the Terminal menu > Split Terminal" -ForegroundColor Gray
        Write-Host ""
        Write-Host "🔄 Alternatively, opening in new VS Code terminal..." -ForegroundColor Yellow
        
        # Try to open a new terminal in VS Code
        # This uses the integrated terminal API if available
        if ($env:VSCODE_PID) {
            # Create a new terminal and run the script
            $command = "& '$ScriptPath'"
            Start-Process -FilePath "powershell" -ArgumentList "-NoExit", "-Command", $command -ErrorAction Stop
            
            Write-Host "✅ Spotify CLI launched in new terminal" -ForegroundColor Green
            return $true
        } else {
            return Start-SpotifyCliInNewWindow -ScriptPath $ScriptPath
        }
        
    } catch {
        Write-Host "❌ Failed to open VS Code terminal: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Falling back to new window..." -ForegroundColor Yellow
        return Start-SpotifyCliInNewWindow -ScriptPath $ScriptPath
    }
}

function Start-SpotifyCliInNewWindow {
    <#
    .SYNOPSIS
    Launch Spotify CLI in a new window
    
    .PARAMETER ScriptPath
    Path to the spotifyCLI.ps1 script
    #>
    
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )
    
    try {
        Write-Host "🪟 Opening Spotify CLI in new window..." -ForegroundColor Cyan
        
        # Determine the best PowerShell executable to use
        $psExecutable = if ($PSVersionTable.PSVersion.Major -ge 7) {
            "pwsh"
        } else {
            "powershell"
        }
        
        # Try to use the same PowerShell version as current session
        try {
            $currentPSPath = (Get-Process -Id $PID).Path
            if ($currentPSPath -and (Test-Path $currentPSPath)) {
                $psExecutable = $currentPSPath
            }
        } catch {
            # Fall back to default
        }
        
        $arguments = @("-NoExit", "-Command", "& '$ScriptPath'")
        Start-Process -FilePath $psExecutable -ArgumentList $arguments -ErrorAction Stop
        
        Write-Host "✅ Spotify CLI launched in new window" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "❌ Failed to open new window: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Try running the script manually: & '$ScriptPath'" -ForegroundColor Yellow
        return $false
    }
}

function Test-SidecarLaunch {
    <#
    .SYNOPSIS
    Test sidecar launching functionality
    
    .DESCRIPTION
    Tests the sidecar launching functionality without actually launching the CLI
    #>
    
    Write-Host "🧪 Testing Sidecar Launch Functionality" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""
    
    $capabilities = Get-TerminalCapabilities
    
    Write-Host "Current Terminal: $($capabilities.TerminalType)" -ForegroundColor Yellow
    Write-Host "Split Window Support: $(if ($capabilities.SupportsSplitWindow) { '✅ Yes' } else { '❌ No' })" -ForegroundColor $(if ($capabilities.SupportsSplitWindow) { "Green" } else { "Red" })
    Write-Host ""
    
    # Test script path detection
    $scriptPaths = @(
        ".\spotifyCLI.ps1",
        "$PSScriptRoot\spotifyCLI.ps1",
        "$(Split-Path $PSScriptRoot)\spotifyCLI.ps1"
    )
    
    $foundScript = $false
    foreach ($path in $scriptPaths) {
        if (Test-Path $path) {
            Write-Host "✅ Found script at: $path" -ForegroundColor Green
            $foundScript = $true
            break
        }
    }
    
    if (-not $foundScript) {
        Write-Host "⚠️ spotifyCLI.ps1 script not found in expected locations" -ForegroundColor Yellow
        Write-Host "   Checked paths:" -ForegroundColor Gray
        foreach ($path in $scriptPaths) {
            Write-Host "   - $path" -ForegroundColor Gray
        }
    }
    
    # Test Windows Terminal availability
    if ($capabilities.WindowsTerminalAvailable) {
        $wtPath = Get-WindowsTerminalPath
        Write-Host "✅ Windows Terminal available at: $wtPath" -ForegroundColor Green
    } else {
        Write-Host "❌ Windows Terminal not available" -ForegroundColor Red
    }
    
    # Provide recommendations
    Write-Host ""
    Write-Host "Recommendations:" -ForegroundColor Yellow
    
    if ($capabilities.SupportsSplitWindow) {
        switch ($capabilities.TerminalType) {
            "WindowsTerminal" {
                Write-Host "  ✅ Use Start-SpotifyCliInSidecar for Windows Terminal split pane" -ForegroundColor Green
            }
            "VSCode" {
                Write-Host "  ✅ Use Start-SpotifyCliInSidecar for VS Code terminal integration" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "  💡 Use Start-SpotifyCliInSidecar -ForceNewWindow for new window launch" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "Test completed successfully!" -ForegroundColor Green
}

#endregion

# Initialize custom aliases when module loads
Initialize-SpotifyAliases

# Export functions and aliases
Export-ModuleMember -Function @(
    # Core playback
    'Show-SpotifyTrack', 'spotify-now', 'play', 'pause', 'next', 'previous',
    
    # Advanced controls
    'volume', 'seek', 'shuffle', 'repeat',
    
    # Podcast-specific controls
    'skip-forward', 'skip-back', 'replay',
    
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
    
    # Window Management and Terminal Detection
    'Get-TerminalCapabilities', 'Test-SplitWindowSupport', 'Get-WindowsTerminalPath', 'Show-TerminalCapabilities',
    
    # Sidecar and Split Window Launching
    'Start-SpotifyCliInSidecar', 'Start-SpotifyCliInWindowsTerminalSplit', 'Start-SpotifyCliInVSCodeSplit', 
    'Start-SpotifyCliInNewWindow', 'Test-SidecarLaunch',
    
    # Default aliases as functions
    'sp', 'spotify', 'vol', 'sh', 'rep', 'tr', 'q', 'pl'
)