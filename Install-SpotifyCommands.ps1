# Installationsskript för Spotify-kommandon
# Kör detta en gång för att göra kommandona tillgängliga globalt

Write-Host "Installerar Spotify-kommandon globalt..." -ForegroundColor Cyan

# Kontrollera om .env finns
if (-not (Test-Path ".env")) {
    Write-Warning ".env-fil saknas. Skapa den med dina Spotify-uppgifter:"
    Write-Host "SPOTIFY_CLIENT_ID=din_client_id"
    Write-Host "SPOTIFY_CLIENT_SECRET=din_client_secret"
    return
}

# Ladda miljövariabler från .env
Get-Content .env | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "User")
    }
}

# Hitta PowerShell-profilen
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path $profilePath -Parent

# Skapa profilmapp om den inte finns
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Kopiera modulen till PowerShell-moduler
$modulesPath = Join-Path (Split-Path $PROFILE -Parent) "Modules\SpotifyCommands"
if (-not (Test-Path $modulesPath)) {
    New-Item -ItemType Directory -Path $modulesPath -Force | Out-Null
}

Copy-Item "SpotifyModule.psm1" -Destination (Join-Path $modulesPath "SpotifyCommands.psm1") -Force

# Lägg till import i profilen
$importLine = "Import-Module SpotifyCommands -DisableNameChecking"
$profileContent = ""
if (Test-Path $profilePath) {
    $profileContent = Get-Content $profilePath -Raw
}

if ($profileContent -notmatch "Import-Module SpotifyCommands") {
    Add-Content -Path $profilePath -Value "`n# Spotify Commands`n$importLine"
    Write-Host "✅ Lade till Spotify-kommandon i PowerShell-profilen" -ForegroundColor Green
} else {
    Write-Host "✅ Spotify-kommandon redan i profilen" -ForegroundColor Yellow
}

Write-Host "`n🎵 Installation klar! Starta om PowerShell eller kör:" -ForegroundColor Green
Write-Host ". `$PROFILE" -ForegroundColor Cyan
Write-Host "`nTillgängliga kommandon:" -ForegroundColor Yellow
Write-Host "  spotify   - visa vad som spelas"
Write-Host "  next      - nästa låt"
Write-Host "  previous  - föregående låt"
Write-Host "  pause     - pausa"
Write-Host "  play      - spela"