# Spotify CLI Enhanced Edition - Global Installation Script
# Run this once to make all enhanced commands available globally in PowerShell

Write-Host "🎵 Installing Spotify CLI Enhanced Edition globally..." -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Check if .env file exists
if (-not (Test-Path ".env")) {
    Write-Host "⚠️ Missing .env file" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please create a .env file with your Spotify app credentials:" -ForegroundColor Yellow
    Write-Host "SPOTIFY_CLIENT_ID=your_client_id_here" -ForegroundColor White
    Write-Host "SPOTIFY_CLIENT_SECRET=your_client_secret_here" -ForegroundColor White
    Write-Host ""
    Write-Host "Get your credentials from: https://developer.spotify.com/dashboard" -ForegroundColor Cyan
    return
}

Write-Host "✅ Found .env file" -ForegroundColor Green

# Load environment variables from .env and set them permanently
Write-Host "🔧 Setting up environment variables..." -ForegroundColor Yellow
Get-Content .env | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        [System.Environment]::SetEnvironmentVariable($key, $value, "User")
        Write-Host "   Set $key" -ForegroundColor Gray
    }
}

# Find PowerShell profile path
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path $profilePath -Parent

Write-Host "📁 Profile location: $profilePath" -ForegroundColor Gray

# Create profile directory if it doesn't exist
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Write-Host "✅ Created profile directory" -ForegroundColor Green
}

# Set up module directory
$modulesPath = Join-Path (Split-Path $PROFILE -Parent) "Modules\SpotifyCommands"
if (-not (Test-Path $modulesPath)) {
    New-Item -ItemType Directory -Path $modulesPath -Force | Out-Null
    Write-Host "✅ Created module directory" -ForegroundColor Green
}

# Copy module file
Copy-Item "SpotifyModule.psm1" -Destination (Join-Path $modulesPath "SpotifyCommands.psm1") -Force
Write-Host "✅ Copied module to PowerShell modules directory" -ForegroundColor Green

# Add import to profile
$importLine = "Import-Module SpotifyCommands -DisableNameChecking -Force"
$profileContent = ""
if (Test-Path $profilePath) {
    $profileContent = Get-Content $profilePath -Raw
}

if ($profileContent -notmatch "Import-Module SpotifyCommands") {
    Add-Content -Path $profilePath -Value "`n# Spotify CLI Enhanced Edition`n$importLine"
    Write-Host "✅ Added Spotify commands to PowerShell profile" -ForegroundColor Green
} else {
    Write-Host "✅ Spotify commands already in profile" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 Installation Complete!" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host ""
Write-Host "To start using the commands, restart PowerShell or run:" -ForegroundColor Cyan
Write-Host "   . `$PROFILE" -ForegroundColor White
Write-Host ""

# Display all available commands organized by category
Write-Host "🎵 AVAILABLE GLOBAL COMMANDS:" -ForegroundColor Yellow
Write-Host ""

Write-Host "Basic Playback:" -ForegroundColor Cyan
Write-Host "  Show-SpotifyTrack    - Show current track (detailed view)" -ForegroundColor White
Write-Host "  spotify-now          - Show current track (short alias)" -ForegroundColor White
Write-Host "  spotify-now compact  - Show current track (single line)" -ForegroundColor White
Write-Host "  play                 - Resume playback" -ForegroundColor White
Write-Host "  pause                - Pause playback" -ForegroundColor White
Write-Host "  next                 - Skip to next track" -ForegroundColor White
Write-Host "  previous             - Skip to previous track" -ForegroundColor White

Write-Host ""
Write-Host "Advanced Controls:" -ForegroundColor Cyan
Write-Host "  Invoke-SeekCommand 30        - Seek forward 30 seconds" -ForegroundColor White
Write-Host "  Invoke-VolumeCommand 75      - Set volume to 75%" -ForegroundColor White
Write-Host "  Invoke-ShuffleCommand on     - Enable shuffle" -ForegroundColor White
Write-Host "  Invoke-RepeatCommand track   - Set repeat mode" -ForegroundColor White

Write-Host ""
Write-Host "Device Management:" -ForegroundColor Cyan
Write-Host "  devices              - List available Spotify devices" -ForegroundColor White
Write-Host "  transfer <device_id> - Switch playback to device" -ForegroundColor White

Write-Host ""
Write-Host "Search & Library:" -ForegroundColor Cyan
Write-Host "  search 'artist name' - Search for music" -ForegroundColor White
Write-Host "  playlists            - Show your playlists" -ForegroundColor White
Write-Host "  liked                - Show liked songs" -ForegroundColor White
Write-Host "  recent               - Show recently played tracks" -ForegroundColor White
Write-Host "  save-track           - Save current track to library" -ForegroundColor White
Write-Host "  unsave-track         - Remove current track from library" -ForegroundColor White

Write-Host ""
Write-Host "Queue & Playback:" -ForegroundColor Cyan
Write-Host "  queue <track_uri>    - Add track to queue" -ForegroundColor White
Write-Host "  play-track <uri>     - Play specific track" -ForegroundColor White
Write-Host "  play-album <uri>     - Play specific album" -ForegroundColor White
Write-Host "  play-playlist <uri>  - Play specific playlist" -ForegroundColor White

Write-Host ""
Write-Host "System & Configuration:" -ForegroundColor Cyan
Write-Host "  Get-SpotifyConfig    - View current settings" -ForegroundColor White
Write-Host "  Set-SpotifyConfig    - Modify settings" -ForegroundColor White
Write-Host "  notifications on/off - Control notifications" -ForegroundColor White
Write-Host "  auto-refresh 5       - Auto-update display every 5 seconds" -ForegroundColor White
Write-Host "  history              - Show playback history" -ForegroundColor White
Write-Host "  logs                 - View debug logs" -ForegroundColor White

Write-Host ""
Write-Host "Help & Information:" -ForegroundColor Cyan
Write-Host "  Get-SpotifyHelp      - Show comprehensive help for all commands" -ForegroundColor White
Write-Host "  spotify-help         - Short alias for Get-SpotifyHelp" -ForegroundColor White
Write-Host "  Get-SpotifyHelp <cmd> - Get detailed help for specific command" -ForegroundColor White

Write-Host ""
Write-Host "💡 QUICK START:" -ForegroundColor Green
Write-Host "1. Restart PowerShell or run: . `$PROFILE" -ForegroundColor White
Write-Host "2. Try: spotify-now" -ForegroundColor White
Write-Host "3. Get help: Get-SpotifyHelp or spotify-help" -ForegroundColor White
Write-Host "4. For interactive mode: .\spotifyCLI.ps1" -ForegroundColor White
Write-Host ""
Write-Host "📖 For detailed documentation, see README.md" -ForegroundColor Cyan