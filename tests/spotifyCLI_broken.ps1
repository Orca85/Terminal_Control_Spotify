<# 
.SYNOPSIS
Spotify CLI - Advanced Edition för PowerShell

.DESCRIPTION
En omfattande kommandoradsgränssnitt för att kontrollera Spotify-uppspelning direkt från PowerShell 
med avancerade funktioner inklusive interaktiv navigering, smarta spellistor, plattformsoberoende 
kompatibilitet och förbättrad användarupplevelse.

.PARAMETER Sidecar
Launch in sidecar/split window mode if supported by the terminal

.PARAMETER NewWindow
Force launch in a new window instead of split window

.PARAMETER SplitDirection
Direction for split window (right, down, left, up). Only applies to Windows Terminal.

.EXAMPLE
.\spotifyCLI.ps1
Launch normally in current terminal

.EXAMPLE
.\spotifyCLI.ps1 -Sidecar
Launch in split window if supported, otherwise new window
#>

[CmdletBinding()]
param(
    [switch]$Sidecar,
    [switch]$NewWindow,
    [ValidateSet("right", "down", "left", "up")]
    [string]$SplitDirection = "right"
)

#region Configuration
# Load environment variables from .env file
if (Test-Path ".env") {
    Get-Content .env | ForEach-Object {
        if ($_ -match "^(.*?)=(.*)$") {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }
}

$ClientId = $env:SPOTIFY_CLIENT_ID
$ClientSecret = $env:SPOTIFY_CLIENT_SECRET
$RedirectUri = "http://127.0.0.1:8888/callback"

# Enhanced scopes for full functionality
$Scopes = @(
    "user-read-playback-state",
    "user-modify-playback-state", 
    "user-read-currently-playing",
    "user-read-private",
    "playlist-read-private",
    "user-library-read",
    "user-library-modify",
    "user-read-recently-played",
    "user-top-read"
) -join " "

# Storage paths
$AppDataDir = Join-Path $env:APPDATA "SpotifyCLI"
$TokenFile = Join-Path $AppDataDir "tokens.json"
$ConfigFile = Join-Path $AppDataDir "config.json"

# API endpoints
$TokenEndpoint = "https://accounts.spotify.com/api/token"
$ApiBase = "https://api.spotify.com/v1"

# Session storage for smart numbers
$script:SessionDevices = @()
$script:SessionTracks = @()
$script:SessionPlaylists = @()
$script:SessionAlbums = @()
$script:InteractiveMode = $false
$script:SelectedIndex = 0
$script:CurrentItems = @()

# Default configuration
$DefaultConfig = @{
    PreferredDevice = $null
    CompactMode = $false
    NotificationsEnabled = $true
    AutoRefreshInterval = 0
    Colors = @{
        Playing = "Green"
        Paused = "Yellow"
        Track = "Cyan"
        Artist = "Yellow"
        Album = "Green"
        Progress = "Magenta"
    }
}
#endregion Configuration

#region Helper Functions
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
        if ([string]::IsNullOrWhiteSpace($json)) { return @{} }
        return ($json | ConvertFrom-Json)
    } catch { return @{} }
}

function Set-StoredTokens($Tokens) {
    Initialize-TokenStore
    ($Tokens | ConvertTo-Json -Depth 5) | Set-Content -Path $TokenFile -Encoding UTF8
}

function Start-SpotifyAuth {
    Write-Host "🔐 Starting Spotify authentication..." -ForegroundColor Cyan
    
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add(($RedirectUri.TrimEnd('/') + "/"))
    
    try {
        $listener.Start()
    } catch {
        Write-Host "❌ Could not start authentication server on port 8888" -ForegroundColor Red
        Write-Host "💡 Make sure port 8888 is available and try running as Administrator" -ForegroundColor Yellow
        return $null
    }

    $state = [Guid]::NewGuid().ToString()
    $authUrl = "https://accounts.spotify.com/authorize?response_type=code&client_id=$ClientId&redirect_uri=$RedirectUri&scope=$Scopes&state=$state"

    Start-Process $authUrl | Out-Null
    Write-Host "🌐 Browser opened for Spotify login..." -ForegroundColor Yellow

    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    $query = $request.Url.Query
    $params = [System.Web.HttpUtility]::ParseQueryString($query)
    $code = $params["code"]
    $retState = $params["state"]
    $authError = $params["error"]

    $html = "<html><body style='font-family:sans-serif;text-align:center;padding:50px'><h2>✅ Authentication Complete!</h2><p>You can close this tab and return to PowerShell.</p></body></html>"
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.OutputStream.Close()
    $listener.Stop()

    if ($authError) { 
        Write-Host "❌ Authentication error: $authError" -ForegroundColor Red
        return $null
    }
    if ($retState -ne $state) {
        Write-Host "❌ Security error: state mismatch" -ForegroundColor Red
        return $null
    }
    if (-not $code) {
        Write-Host "❌ No authorization code received" -ForegroundColor Red
        return $null
    }

    # Exchange code for tokens
    $body = @{
        grant_type = "authorization_code"
        code = $code
        redirect_uri = $RedirectUri
        client_id = $ClientId
        client_secret = $ClientSecret
    }

    try {
        $tokenResp = Invoke-RestMethod -Method Post -Uri $TokenEndpoint -Body $body
        $tokens = @{
            access_token = $tokenResp.access_token
            token_type = $tokenResp.token_type
            expires_in = $tokenResp.expires_in
            refresh_token = $tokenResp.refresh_token
            obtained_at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            scopes = $Scopes
        }
        Set-StoredTokens $tokens
        Write-Host "✅ Authentication completed successfully!" -ForegroundColor Green
        return $tokens
    } catch {
        Write-Host "❌ Token exchange failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-SpotifyAccessToken {
    $tokens = Get-StoredTokens
    if (-not $tokens.access_token) {
        $tokens = Start-SpotifyAuth
        if (-not $tokens) { return $null }
        return $tokens.access_token
    }

    # Check token expiration
    $obtained = [long]$tokens.obtained_at
    $expiresIn = [int]$tokens.expires_in
    $age = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $obtained
    
    if ($age -ge ($expiresIn - 60)) {
        if (-not $tokens.refresh_token) {
            Write-Host "🔄 Token expired, re-authenticating..." -ForegroundColor Yellow
            $tokens = Start-SpotifyAuth
            if (-not $tokens) { return $null }
            return $tokens.access_token
        }
        
        try {
            $body = @{
                grant_type = "refresh_token"
                refresh_token = $tokens.refresh_token
                client_id = $ClientId
                client_secret = $ClientSecret
            }
            $tokenResp = Invoke-RestMethod -Method Post -Uri $TokenEndpoint -Body $body
            $tokens.access_token = $tokenResp.access_token
            if ($tokenResp.refresh_token) { $tokens.refresh_token = $tokenResp.refresh_token }
            $tokens.expires_in = $tokenResp.expires_in
            $tokens.obtained_at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            Set-StoredTokens $tokens
        } catch {
            Write-Host "🔄 Token refresh failed, re-authenticating..." -ForegroundColor Yellow
            $tokens = Start-SpotifyAuth
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
    if (-not $access) { return $null }
    
    $uri = $ApiBase + $Path
    if ($Query) {
        $q = ($Query.GetEnumerator() | ForEach-Object { 
            "{0}={1}" -f $_.Key, [System.Uri]::EscapeDataString([string]$_.Value) 
        }) -join "&"
        $uri = "$uri?$q"
    }
    
    $headers = @{ Authorization = "Bearer $access" }
    
    try {
        if ($Body) {
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 10)
        } else {
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
        }
    } catch {
        Handle-SpotifyError -ErrorRecord $_ -Context $Path
        return $null
    }
}

function Handle-SpotifyError {
    param($ErrorRecord, $Context)
    
    $statusCode = $null
    if ($ErrorRecord.Exception.Response) {
        $statusCode = [int]$ErrorRecord.Exception.Response.StatusCode
    }
    
    switch ($statusCode) {
        401 { Write-Host "🔐 Authentication expired. Please restart the CLI." -ForegroundColor Red }
        403 { Write-Host "🚫 This feature requires Spotify Premium." -ForegroundColor Red }
        404 { 
            if ($Context -like "*device*") {
                Write-Host "📱 No active device. Start Spotify on any device first." -ForegroundColor Red
            } else {
                Write-Host "❓ Content not found." -ForegroundColor Red
            }
        }
        429 { 
            Write-Host "⏳ Rate limited. Waiting..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
        default { Write-Host "❌ API Error: $($ErrorRecord.Exception.Message)" -ForegroundColor Red }
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
#endregion Helper Functions

#region Core Commands
function Show-CurrentTrack {
    param([string]$Mode)
    
    try {
        $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        if (-not $currentTrack -or -not $currentTrack.item) {
            Write-Host "🎵 No track currently playing" -ForegroundColor Yellow
            return
        }
        
        $item = $currentTrack.item
        $isPlaying = $currentTrack.is_playing
        $progress = $currentTrack.progress_ms
        $duration = $item.duration_ms
        $device = $currentTrack.device
        
        # Detect if this is a podcast episode
        $isPodcast = $item.type -eq "episode" -or ($currentTrack.currently_playing_type -eq "episode")
        
        if ($Mode -eq "compact") {
            # Compact single-line display
            $playIcon = if ($isPlaying) { "▶️" } else { "⏸️" }
            $name = if ($item.name.Length -gt 25) { $item.name.Substring(0, 22) + "..." } else { $item.name }
            
            if ($isPodcast) {
                $showName = if ($item.show.name.Length -gt 20) { $item.show.name.Substring(0, 17) + "..." } else { $item.show.name }
                $progressBar = Show-ProgressBar -Current $progress -Total $duration -Width 15
                $timeInfo = "{0}/{1}" -f (Format-Time $progress), (Format-Time $duration)
                Write-Host "$playIcon $name - 🎙️ $showName | $progressBar $timeInfo" -ForegroundColor Cyan
            } else {
                $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                if ($artists.Length -gt 20) { $artists = $artists.Substring(0, 17) + "..." }
                $progressBar = Show-ProgressBar -Current $progress -Total $duration -Width 15
                $timeInfo = "{0}/{1}" -f (Format-Time $progress), (Format-Time $duration)
                Write-Host "$playIcon $name - $artists | $progressBar $timeInfo" -ForegroundColor Cyan
            }
        } else {
            # Full detailed display
            if ($isPodcast) {
                Write-Host "🎙️ " -NoNewline -ForegroundColor Magenta
                Write-Host $item.name -ForegroundColor Cyan
                Write-Host "📻 " -NoNewline -ForegroundColor Yellow
                Write-Host $item.show.name -ForegroundColor Yellow
                
                if ($item.description) {
                    $description = if ($item.description.Length -gt 100) { 
                        $item.description.Substring(0, 97) + "..." 
                    } else { $item.description }
                    Write-Host "📝 $description" -ForegroundColor Gray
                }
            } else {
                Write-Host "🎵 " -NoNewline -ForegroundColor Cyan
                Write-Host $item.name -ForegroundColor Cyan
                Write-Host "👤 " -NoNewline -ForegroundColor Yellow
                Write-Host (($item.artists | ForEach-Object { $_.name }) -join ", ") -ForegroundColor Yellow
                Write-Host "📀 " -NoNewline -ForegroundColor Green
                Write-Host $item.album.name -ForegroundColor Green
            }
            
            $progressBar = Show-ProgressBar -Current $progress -Total $duration
            Write-Host $progressBar -ForegroundColor Magenta
            
            $timeInfo = "{0} / {1}" -f (Format-Time $progress), (Format-Time $duration)
            $statusIcon = if ($isPlaying) { "▶️ Playing" } else { "⏸️ Paused" }
            Write-Host "⏱ $timeInfo $statusIcon" -ForegroundColor Gray
            
            if ($device) {
                $deviceIcon = switch ($device.type.ToLower()) {
                    "computer" { "💻" }
                    "smartphone" { "📱" }
                    "speaker" { "🔊" }
                    "tv" { "📺" }
                    default { "🎵" }
                }
                Write-Host "📱 Playing on $deviceIcon $($device.name)" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "❌ Error getting current track: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Search-SpotifyContent {
    param([string]$Query)
    
    if ([string]::IsNullOrWhiteSpace($Query)) {
        Write-Host "Usage: /search <query>" -ForegroundColor Yellow
        return
    }
    
    try {
        $searchQuery = @{ 
            q = $Query
            type = "track,artist,album,episode"
            limit = "10"
        }
        
        Write-Host "🔍 Searching for: $Query" -ForegroundColor Gray
        $results = Invoke-SpotifyApi -Method GET -Path "/search" -Query $searchQuery
        
        if (-not $results) { return }
        
        Write-Host ""
        Write-Host "🔍 Search Results for '$Query':" -ForegroundColor Cyan
        Write-Host ""
        
        # Combine all results for smart numbering
        $allItems = @()
        
        if ($results.tracks -and $results.tracks.items) {
            Write-Host "TRACKS:" -ForegroundColor Yellow
            $i = 1
            foreach ($track in $results.tracks.items[0..4]) {
                $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
                Write-Host "$i. $($track.name) - $artists ($($track.album.name))" -ForegroundColor White
                $allItems += $track | Add-Member -NotePropertyName "search_type" -NotePropertyValue "track" -PassThru
                $i++
            }
            Write-Host ""
        }
        
        if ($results.episodes -and $results.episodes.items) {
            Write-Host "PODCAST EPISODES:" -ForegroundColor Magenta
            $startIndex = $allItems.Count + 1
            foreach ($episode in $results.episodes.items[0..4]) {
                $showName = $episode.show.name
                $description = if ($episode.description -and $episode.description.Length -gt 50) { 
                    $episode.description.Substring(0, 47) + "..." 
                } else { $episode.description }
                Write-Host "$startIndex. 🎙️ $($episode.name) - $showName" -ForegroundColor White
                if ($description) {
                    Write-Host "   📝 $description" -ForegroundColor Gray
                }
                $allItems += $episode | Add-Member -NotePropertyName "search_type" -NotePropertyValue "episode" -PassThru
                $startIndex++
            }
            Write-Host ""
        }
        
        # Store results for smart numbering
        $script:SessionTracks = $allItems
        
        if ($allItems.Count -gt 0) {
            Write-Host "💡 Press Enter to start interactive mode, or use numbers directly" -ForegroundColor Gray
            Write-Host "💡 Use 'play 1' to play item #1, or 'queue 2' to add item #2 to queue" -ForegroundColor Gray
            
            # Check for Enter key to start interactive mode
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.VirtualKeyCode -eq 13) { # Enter key
                Start-InteractiveMode -Items $allItems -Type "search"
            }
        }
    } catch {
        Write-Host "❌ Search failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Start-InteractiveMode {
    param($Items, $Type)
    
    if (-not $Items -or $Items.Count -eq 0) {
        Write-Host "❌ No items to navigate" -ForegroundColor Red
        return
    }
    
    $script:InteractiveMode = $true
    $script:CurrentItems = $Items
    $script:SelectedIndex = 0
    
    Write-Host ""
    Write-Host "🎮 Interactive Mode - Use arrow keys to navigate" -ForegroundColor Cyan
    Write-Host "⌨️  Controls: ↑↓ Navigate | Enter Play | Space Queue | Esc Exit" -ForegroundColor Gray
    Write-Host ""
    
    Show-InteractiveItems
    
    while ($script:InteractiveMode) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                if ($script:SelectedIndex -gt 0) {
                    $script:SelectedIndex--
                    Show-InteractiveItems
                }
            }
            40 { # Down arrow
                if ($script:SelectedIndex -lt ($script:CurrentItems.Count - 1)) {
                    $script:SelectedIndex++
                    Show-InteractiveItems
                }
            }
            13 { # Enter - Play
                $selectedItem = $script:CurrentItems[$script:SelectedIndex]
                Play-SpotifyItem -Item $selectedItem
                $script:InteractiveMode = $false
            }
            32 { # Space - Queue
                $selectedItem = $script:CurrentItems[$script:SelectedIndex]
                Queue-SpotifyItem -Item $selectedItem
            }
            27 { # Escape - Exit
                $script:InteractiveMode = $false
                Write-Host ""
                Write-Host "👋 Exited interactive mode" -ForegroundColor Yellow
            }
            { $_ -ge 49 -and $_ -le 57 } { # Number keys 1-9
                $number = $_ - 48
                if ($number -le $script:CurrentItems.Count) {
                    $script:SelectedIndex = $number - 1
                    Show-InteractiveItems
                }
            }
        }
    }
}

function Show-InteractiveItems {
    # Clear previous display
    [Console]::SetCursorPosition(0, [Console]::CursorTop - $script:CurrentItems.Count - 2)
    
    for ($i = 0; $i -lt $script:CurrentItems.Count; $i++) {
        $item = $script:CurrentItems[$i]
        $isSelected = ($i -eq $script:SelectedIndex)
        $prefix = if ($isSelected) { "► " } else { "  " }
        $color = if ($isSelected) { "Yellow" } else { "White" }
        
        if ($item.search_type -eq "episode" -or $item.type -eq "episode") {
            Write-Host "$prefix$($i + 1). 🎙️ $($item.name) - $($item.show.name)" -ForegroundColor $color
        } else {
            $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
            Write-Host "$prefix$($i + 1). $($item.name) - $artists" -ForegroundColor $color
        }
    }
    Write-Host ""
}

function Play-SpotifyItem {
    param($Item)
    
    if (-not $Item) { return }
    
    try {
        $uri = $Item.uri
        $body = @{ uris = @($uri) }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
        
        if ($Item.search_type -eq "episode" -or $Item.type -eq "episode") {
            Write-Host "▶️ Playing podcast episode: $($Item.name)" -ForegroundColor Magenta
        } else {
            $artists = ($Item.artists | ForEach-Object { $_.name }) -join ", "
            Write-Host "▶️ Playing: $($Item.name) by $artists" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Could not play item" -ForegroundColor Red
    }
}

function Queue-SpotifyItem {
    param($Item)
    
    if (-not $Item) { return }
    
    try {
        $uri = $Item.uri
        $query = @{ uri = $uri }
        Invoke-SpotifyApi -Method POST -Path "/me/player/queue" -Query $query | Out-Null
        
        if ($Item.search_type -eq "episode" -or $Item.type -eq "episode") {
            Write-Host "➕ Queued podcast episode: $($Item.name)" -ForegroundColor Cyan
        } else {
            $artists = ($Item.artists | ForEach-Object { $_.name }) -join ", "
            Write-Host "➕ Queued: $($Item.name) by $artists" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "❌ Could not queue item" -ForegroundColor Red
    }
}

function Show-Devices {
    try {
        $devicesResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/devices"
        if (-not $devicesResponse -or -not $devicesResponse.devices) {
            Write-Host "📱 No devices found" -ForegroundColor Yellow
            return
        }
        
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
        Write-Host "💡 Use 'transfer 1' to switch to device #1" -ForegroundColor Gray
    } catch {
        Write-Host "❌ Could not get devices" -ForegroundColor Red
    }
}

function Show-Playlists {
    try {
        $playlistsResponse = Invoke-SpotifyApi -Method GET -Path "/me/playlists" -Query @{ limit = "20" }
        if (-not $playlistsResponse -or -not $playlistsResponse.items) {
            Write-Host "📚 No playlists found" -ForegroundColor Yellow
            return
        }
        
        $script:SessionPlaylists = $playlistsResponse.items
        
        Write-Host "📚 Your Playlists:" -ForegroundColor Cyan
        $i = 1
        foreach ($playlist in $playlistsResponse.items) {
            $trackCount = $playlist.tracks.total
            $description = if ($playlist.description) { " - $($playlist.description)" } else { "" }
            Write-Host "$i. $($playlist.name) ($trackCount tracks)$description" -ForegroundColor White
            $i++
        }
        Write-Host ""
        Write-Host "💡 Use 'play-playlist 1' to play playlist #1" -ForegroundColor Gray
    } catch {
        Write-Host "❌ Could not get playlists" -ForegroundColor Red
    }
}

function Start-SpotifyApp {
    Write-Host "🚀 Launching Spotify application..." -ForegroundColor Cyan
    
    # Check if Spotify is already running
    $spotifyProcess = Get-Process -Name "Spotify" -ErrorAction SilentlyContinue
    if ($spotifyProcess) {
        Write-Host "✅ Spotify is already running" -ForegroundColor Green
        return
    }
    
    # Try multiple methods to launch Spotify
    $launched = $false
    
    # Method 1: Try common installation paths
    $spotifyPaths = @(
        "$env:APPDATA\Spotify\Spotify.exe",
        "${env:ProgramFiles}\Spotify\Spotify.exe",
        "${env:ProgramFiles(x86)}\Spotify\Spotify.exe"
    )
    
    foreach ($path in $spotifyPaths) {
        if (Test-Path $path) {
            try {
                Start-Process $path -ErrorAction Stop
                $launched = $true
                Write-Host "✅ Spotify launched successfully!" -ForegroundColor Green
                break
            } catch {
                Write-Verbose "Failed to launch from $path"
            }
        }
    }
    
    # Method 2: Try Windows Store version
    if (-not $launched) {
        try {
            Start-Process "spotify:" -ErrorAction Stop
            $launched = $true
            Write-Host "✅ Spotify launched (Windows Store version)" -ForegroundColor Green
        } catch {
            Write-Verbose "Failed to launch Windows Store version"
        }
    }
    
    if (-not $launched) {
        Write-Host "❌ Could not find Spotify. Please install it from https://spotify.com" -ForegroundColor Red
        Write-Host "💡 Or try opening Spotify manually first" -ForegroundColor Yellow
    } else {
        Write-Host "⏳ Waiting for Spotify to start up..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        Write-Host "💡 Now try playing some music in Spotify, then use 'spotify' to see current track" -ForegroundColor Cyan
    }
}
#endregion Core Commands

#region Main CLI Loop
function Start-SpotifyCLI {
    Write-Host "🎵 Spotify CLI - Advanced Edition" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Welcome! This is the new advanced version with:" -ForegroundColor Green
    Write-Host "• Interactive navigation with arrow keys" -ForegroundColor White
    Write-Host "• Smart numbered references" -ForegroundColor White
    Write-Host "• Enhanced search with tracks and podcasts" -ForegroundColor White
    Write-Host "• Cross-platform compatibility" -ForegroundColor White
    Write-Host ""
    Write-Host "Type /help to see all available commands." -ForegroundColor Yellow
    Write-Host ""
    
    # Quick start commands
    Write-Host "Quick start commands:" -ForegroundColor Cyan
    Write-Host "/spotify    – Show current track" -ForegroundColor White
    Write-Host "/search     – Search for music and podcasts" -ForegroundColor White
    Write-Host "/devices    – List available Spotify devices" -ForegroundColor White
    Write-Host "/playlists  – Show your playlists" -ForegroundColor White
    Write-Host "/help       – Show all commands" -ForegroundColor White
    Write-Host "/quit       – Exit the CLI" -ForegroundColor White
    Write-Host ""
    
    while ($true) {
        Write-Host ">: " -NoNewline -ForegroundColor Green
        $input = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($input)) { continue }
        
        $parts = $input.Trim() -split '\s+', 2
        $command = $parts[0].ToLower()
        $args = if ($parts.Length -gt 1) { $parts[1] } else { "" }
        
        Write-Host "DEBUG: '$input'" -ForegroundColor DarkGray
        
        switch ($command) {
            "/spotify" { Show-CurrentTrack $args }
            "spotify" { Show-CurrentTrack $args }
            "/start-spotify" { Start-SpotifyApp }
            "start-spotify" { Start-SpotifyApp }
            "/launch" { Start-SpotifyApp }
            "launch" { Start-SpotifyApp }
            "/search" { Search-SpotifyContent $args }
            "search" { Search-SpotifyContent $args }
            "/devices" { Show-Devices }
            "devices" { Show-Devices }
            "/playlists" { Show-Playlists }
            "playlists" { Show-Playlists }
            "/play" { 
                if ($args -match '^\d+$') {
                    $index = [int]$args - 1
                    if ($script:SessionTracks -and $index -ge 0 -and $index -lt $script:SessionTracks.Count) {
                        Play-SpotifyItem -Item $script:SessionTracks[$index]
                    } else {
                        Write-Host "❌ Invalid track number. Use search first." -ForegroundColor Red
                    }
                } else {
                    try {
                        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" | Out-Null
                        Write-Host "▶️ Resumed playback" -ForegroundColor Green
                    } catch {
                        Write-Host "❌ Could not resume playback" -ForegroundColor Red
                    }
                }
            }
            "play" { 
                if ($args -match '^\d+$') {
                    $index = [int]$args - 1
                    if ($script:SessionTracks -and $index -ge 0 -and $index -lt $script:SessionTracks.Count) {
                        Play-SpotifyItem -Item $script:SessionTracks[$index]
                    } else {
                        Write-Host "❌ Invalid track number. Use search first." -ForegroundColor Red
                    }
                } else {
                    try {
                        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" | Out-Null
                        Write-Host "▶️ Resumed playback" -ForegroundColor Green
                    } catch {
                        Write-Host "❌ Could not resume playback" -ForegroundColor Red
                    }
                }
            }
            "/pause" {
                try {
                    Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
                    Write-Host "⏸️ Paused playback" -ForegroundColor Yellow
                } catch {
                    Write-Host "❌ Could not pause playback" -ForegroundColor Red
                }
            }
            "pause" {
                try {
                    Invoke-SpotifyApi -Method PUT -Path "/me/player/pause" | Out-Null
                    Write-Host "⏸️ Paused playback" -ForegroundColor Yellow
                } catch {
                    Write-Host "❌ Could not pause playback" -ForegroundColor Red
                }
            }
            "/next" {
                try {
                    Invoke-SpotifyApi -Method POST -Path "/me/player/next" | Out-Null
                    Write-Host "⏭️ Skipped to next track" -ForegroundColor Green
                } catch {
                    Write-Host "❌ Could not skip track" -ForegroundColor Red
                }
            }
            "next" {
                try {
                    Invoke-SpotifyApi -Method POST -Path "/me/player/next" | Out-Null
                    Write-Host "⏭️ Skipped to next track" -ForegroundColor Green
                } catch {
                    Write-Host "❌ Could not skip track" -ForegroundColor Red
                }
            }
            "/previous" {
                try {
                    Invoke-SpotifyApi -Method POST -Path "/me/player/previous" | Out-Null
                    Write-Host "⏮️ Skipped to previous track" -ForegroundColor Green
                } catch {
                    Write-Host "❌ Could not skip track" -ForegroundColor Red
                }
            }
            "previous" {
                try {
                    Invoke-SpotifyApi -Method POST -Path "/me/player/previous" | Out-Null
                    Write-Host "⏮️ Skipped to previous track" -ForegroundColor Green
                } catch {
                    Write-Host "❌ Could not skip track" -ForegroundColor Red
                }
            }
            "/help" {
                Show-Help
            }
            "help" {
                Show-Help
            }
            "/quit" {
                Write-Host "👋 Goodbye!" -ForegroundColor Cyan
                break
            }
            "quit" {
                Write-Host "👋 Goodbye!" -ForegroundColor Cyan
                break
            }
            default {
                Write-Host "❓ Unknown command: $command" -ForegroundColor Red
                Write-Host "💡 Type /help to see available commands" -ForegroundColor Yellow
            }
        }
        Write-Host ""
    }
}

function Show-Help {
    Write-Host "🎵 Spotify CLI - Advanced Edition Help" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "🎮 NEW FEATURES:" -ForegroundColor Green
    Write-Host "• Interactive navigation with arrow keys" -ForegroundColor White
    Write-Host "• Smart numbered references (no more copying URIs!)" -ForegroundColor White
    Write-Host "• Enhanced search with tracks and podcasts" -ForegroundColor White
    Write-Host "• Cross-platform compatibility" -ForegroundColor White
    Write-Host ""
    
    Write-Host "PLAYBACK CONTROLS:" -ForegroundColor Yellow
    Write-Host "/spotify [compact] - Show current track (add 'compact' for single-line)" -ForegroundColor White
    Write-Host "/play              - Resume playback or play track by number" -ForegroundColor White
    Write-Host "/pause             - Pause playback" -ForegroundColor White
    Write-Host "/next              - Skip to next track" -ForegroundColor White
    Write-Host "/previous          - Go to previous track" -ForegroundColor White
    Write-Host ""
    
    Write-Host "SEARCH & DISCOVERY:" -ForegroundColor Yellow
    Write-Host "/search <query>    - Search for tracks, artists, albums, and podcasts" -ForegroundColor White
    Write-Host "                   - Press Enter after search for interactive mode!" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "DEVICE MANAGEMENT:" -ForegroundColor Yellow
    Write-Host "/devices           - List available Spotify Connect devices" -ForegroundColor White
    Write-Host ""
    
    Write-Host "LIBRARY MANAGEMENT:" -ForegroundColor Yellow
    Write-Host "/playlists         - Show your playlists with smart numbers" -ForegroundColor White
    Write-Host ""
    
    Write-Host "SMART NUMBERS:" -ForegroundColor Green
    Write-Host "After searching or listing items, use numbers instead of long URIs:" -ForegroundColor White
    Write-Host "• /play 1          - Play the first item from your last search" -ForegroundColor Gray
    Write-Host "• Numbers stay valid until you search again" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "INTERACTIVE MODE:" -ForegroundColor Green
    Write-Host "Press Enter after any search to start interactive navigation:" -ForegroundColor White
    Write-Host "• ↑↓ arrows        - Navigate through results" -ForegroundColor Gray
    Write-Host "• Enter            - Play selected item" -ForegroundColor Gray
    Write-Host "• Space            - Add to queue" -ForegroundColor Gray
    Write-Host "• 1-9              - Jump to numbered item" -ForegroundColor Gray
    Write-Host "• Escape           - Exit interactive mode" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "SYSTEM COMMANDS:" -ForegroundColor Yellow
    Write-Host "/help              - Show this help" -ForegroundColor White
    Write-Host "/quit              - Exit the CLI" -ForegroundColor White
    Write-Host ""
    
    Write-Host "💡 TIP: This is the new advanced version! Try the interactive features!" -ForegroundColor Cyan
}
#endregion Main CLI Loop

# Start the CLI
if (-not $ClientId -or -not $ClientSecret) {
    Write-Host "❌ Missing Spotify credentials!" -ForegroundColor Red
    Write-Host "Please make sure you have a .env file with:" -ForegroundColor Yellow
    Write-Host "SPOTIFY_CLIENT_ID=your_client_id" -ForegroundColor White
    Write-Host "SPOTIFY_CLIENT_SECRET=your_client_secret" -ForegroundColor White
    exit 1
}

Start-SpotifyCLI