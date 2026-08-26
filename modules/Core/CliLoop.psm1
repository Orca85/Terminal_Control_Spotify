# CLI Loop
# Provides Start-SpotifyCLI (the public entry point) and Invoke-SpotifyCommand (command dispatcher).

# Path to the module root — two levels up from modules\Core\
$script:ModuleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$script:ExitRequested = $false

# --- Command Dispatcher ---

function Invoke-SpotifyCommand {
    param([string]$Command)

    if ([string]::IsNullOrWhiteSpace($Command)) { return }

    $parts = $Command.Trim() -split '\s+', 2
    $cmd   = $parts[0].ToLower().TrimStart('/')
    $arg   = if ($parts.Length -gt 1) { $parts[1] } else { "" }

    switch ($cmd) {
        { $_ -in 'spotify','pn','plays-now','music' } { Show-SpotifyTrack $arg }

        'next'          { next }
        'previous'      { previous }
        'pause'         { pause }
        'play'          { play $arg }
        'seek'          { seek $arg }
        'volume'        { volume $arg }
        'shuffle'       { shuffle $arg }
        'repeat'        { repeat $arg }
        'devices'       { devices }
        'transfer'      { transfer $arg }

        'search'        { search $arg }
        'search-albums' { search-albums $arg }

        'queue'         { queue $arg }
        'queue-album'   { queue-album $arg }
        'play-album'    { play-album $arg }
        'playlists'     { playlists }
        'play-playlist' { play-playlist $arg }
        'liked'         { liked }
        'save'          { save-track }
        'unsave'        { unsave-track }
        'recent'        { recent }

        'config'        { Invoke-SpotifyConfigCommand $arg }
        'config-live'   { Set-SpotifyLiveFeaturesConfiguration $arg }

        'live'          { Start-SpotifyLiveDisplay -Mode $arg }
        'sidecar'       { Start-SpotifySidecar }
        'lyrics'        { Get-SpotifyLyrics $arg }
        'peak'          { Show-PeakDashboard }
        'quiz'          { Start-MusicQuiz $arg }
        'setlist'       { Invoke-SetlistCommand $arg }
        'notifications' { notifications $arg }
        'fav'           { Invoke-FavoriteCommand $arg }
        'history'       { Show-SpotifyHistory $arg }
        'auto-refresh'  { Write-Host "Use 'live' command for real-time auto-refresh." -ForegroundColor Yellow }

        'help'          { Invoke-HelpCommand $arg }
        'commands'      { Show-AllSpotifyCommands }

        { $_ -in 'quit','exit','q' } {
            Write-Host "Goodbye." -ForegroundColor Cyan
            $script:ExitRequested = $true
        }
        default {
            Write-Host ""
            Write-Host "  Unknown command: '$cmd'" -ForegroundColor Yellow
            Write-Host "  Type 'help' to see all available commands." -ForegroundColor Gray
            Write-Host ""
        }
    }
}

# --- Config sub-command handler ---

function Invoke-SpotifyConfigCommand {
    param([string]$Args)

    $parts = $Args.Trim() -split '\s+', 3
    $sub   = if ($parts.Length -gt 0) { $parts[0].ToLower() } else { "" }

    switch ($sub) {
        "set" {
            if ($parts.Length -ge 3) {
                Set-SpotifyConfig -Key $parts[1] -Value $parts[2]
            } else {
                Write-Host "Usage: config set <key> <value>" -ForegroundColor Yellow
            }
        }
        "get" {
            if ($parts.Length -ge 2) {
                $cfg = Get-SpotifyConfig
                $val = $cfg.($parts[1])
                Write-Host "$($parts[1]) = $val" -ForegroundColor Cyan
            } else {
                Write-Host "Usage: config get <key>" -ForegroundColor Yellow
            }
        }
        "reset" {
            Write-Host "Reset config is not available via module. Delete $env:APPDATA\SpotifyCLI\config.json to reset." -ForegroundColor Yellow
        }
        default {
            $cfg = Get-SpotifyConfig
            Write-Host ""
            Write-Host "  Current Configuration:" -ForegroundColor Cyan
            $cfg.PSObject.Properties | ForEach-Object {
                Write-Host ("  {0,-30} {1}" -f $_.Name, $_.Value) -ForegroundColor Gray
            }
            Write-Host ""
            Write-Host "  Use 'config set <key> <value>' to change a setting." -ForegroundColor DarkGray
            Write-Host ""
        }
    }
}

# --- History helper ---

function Show-SpotifyHistory {
    param([string]$Args)

    $historyFile = Join-Path $env:APPDATA "SpotifyCLI\playback-history.json"
    if (-not (Test-Path $historyFile)) {
        Write-Host "No playback history found." -ForegroundColor Yellow
        return
    }

    try {
        $history = Get-Content $historyFile -Raw | ConvertFrom-Json
        $count = if ($Args -match '^\d+$') { [int]$Args } else { 20 }
        $entries = @($history) | Select-Object -Last $count

        Write-Host ""
        Write-Host "  Recent Playback History (last $($entries.Count))" -ForegroundColor Cyan
        Write-Host "  " + ("=" * 40) -ForegroundColor Cyan
        $i = 1
        foreach ($entry in $entries) {
            $name    = if ($entry.name)   { $entry.name }   else { $entry.track }
            $artist  = if ($entry.artist) { $entry.artist } else { "" }
            $display = if ($artist) { "$name - $artist" } else { "$name" }
            Write-Host ("  {0,3}. {1}" -f $i, $display) -ForegroundColor White
            $i++
        }
        Write-Host ""
    } catch {
        Write-Host "Could not read playback history." -ForegroundColor Red
    }
}

# --- Main Entry Point ---

function Start-SpotifyCLI {
    <#
    .SYNOPSIS
    Start the Spotify CLI interactive session.

    .DESCRIPTION
    Authenticates with Spotify and starts an interactive command loop.
    Credentials are loaded from parameters, environment variables, a .env file in
    the current directory, or prompted on first run.

    .PARAMETER ClientId
    Spotify Developer App Client ID. Falls back to $env:SPOTIFY_CLIENT_ID or .env file.

    .PARAMETER ClientSecret
    Spotify Developer App Client Secret. Falls back to $env:SPOTIFY_CLIENT_SECRET or .env file.

    .PARAMETER Live
    Launch directly into real-time live display mode.

    .PARAMETER LiveMode
    Display mode for live view: detailed (default), compact, or minimal.

    .PARAMETER Sidecar
    Launch in split-pane sidecar mode (Windows Terminal / VS Code).

    .PARAMETER NewWindow
    Force launch in a new terminal window.

    .PARAMETER SplitDirection
    Split pane direction for sidecar mode: right (default), down, left, up.

    .PARAMETER Setlist
    Launch directly into setlist lookup for the given artist.

    .PARAMETER Quiz
    Launch directly into the music quiz with the given number of rounds.

    .EXAMPLE
    Start-SpotifyCLI
    Start-SpotifyCLI -ClientId "abc" -ClientSecret "xyz"
    Start-SpotifyCLI -Live -LiveMode compact
    Start-SpotifyCLI -Setlist "Metallica"
    Start-SpotifyCLI -Quiz 10
    #>
    param(
        [string]$ClientId,
        [string]$ClientSecret,
        [switch]$Live,
        [ValidateSet("detailed", "compact", "minimal")]
        [string]$LiveMode = "detailed",
        [switch]$Sidecar,
        [switch]$NewWindow,
        [ValidateSet("right", "down", "left", "up")]
        [string]$SplitDirection = "right",
        [string]$Setlist = "",
        [int]$Quiz = 0
    )

    # Load credentials (env vars, .env file, or prompt)
    Initialize-SpotifyCredentials -ClientId $ClientId -ClientSecret $ClientSecret

    # Verify auth works (triggers OAuth on first run)
    $token = Get-SpotifyAccessToken
    if (-not $token) {
        Write-Host "Authentication failed. Exiting." -ForegroundColor Red
        return
    }

    # Initialize live features subsystem
    try { Initialize-SpotifyLiveFeatures } catch {}

    # --- Handle direct-launch flags ---

    if ($Sidecar -and -not $NewWindow) {
        Write-Host "Launching SpotifyCLI in sidecar mode..." -ForegroundColor Cyan
        Start-SpotifySidecar -Position $SplitDirection
        return
    }

    if ($NewWindow) {
        Write-Host "Launching SpotifyCLI in new window..." -ForegroundColor Cyan
        $scriptPath = Join-Path $script:ModuleRoot "spotifyCLI.ps1"
        if (Test-Path $scriptPath) {
            Start-SpotifyCliInNewWindow -ScriptPath $scriptPath
        } else {
            Write-Host "Cannot find spotifyCLI.ps1 for new-window launch. Run from the project directory." -ForegroundColor Yellow
        }
        return
    }

    if ($Live) {
        Start-SpotifyLiveDisplay -Mode $LiveMode
        return
    }

    if ($Setlist) {
        Invoke-SetlistCommand $Setlist
        return
    }

    if ($Quiz -gt 0) {
        Start-MusicQuiz $Quiz
        return
    }

    # --- Interactive loop ---

    Write-Host ""
    Write-Host "  Spotify CLI v3.0.0" -ForegroundColor Cyan
    Write-Host "  Type 'help' for commands, 'quit' to exit." -ForegroundColor DarkGray
    Write-Host ""

    $script:ExitRequested = $false
    while (-not $script:ExitRequested) {
        try {
            $cmd = Read-Host ">"
            Invoke-SpotifyCommand $cmd
        } catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# --- Exports ---
Export-ModuleMember -Function @(
    'Start-SpotifyCLI',
    'Invoke-SpotifyCommand'
)
