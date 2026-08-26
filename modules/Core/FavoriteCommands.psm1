# Favorite Playlists
# Lets users save named shortcuts to playlists and play them instantly.
# Data stored in $env:APPDATA\SpotifyCLI\favorites.json

$script:FavFile = Join-Path $env:APPDATA "SpotifyCLI\favorites.json"

function Get-FavoritesStore {
    if (-not (Test-Path $script:FavFile)) { return @{} }
    try {
        $json = Get-Content $script:FavFile -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($json)) { return @{} }
        $obj = $json | ConvertFrom-Json
        $ht  = @{}
        $obj.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
        return $ht
    } catch { return @{} }
}

function Save-FavoritesStore {
    param([hashtable]$Favorites)
    $dir = Split-Path $script:FavFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Favorites | ConvertTo-Json -Depth 3 | Set-Content $script:FavFile -Encoding UTF8
}

function Invoke-FavoriteCommand {
    <#
    .SYNOPSIS
    Manage and play favorite playlists.

    .DESCRIPTION
    Save named shortcuts to Spotify playlists and play them with one word.

    .EXAMPLE
    fav                  # List saved favorites
    fav list             # Same as above
    fav add workout      # Save the currently playing playlist as "workout"
    fav workout          # Play the "workout" playlist
    fav remove workout   # Delete the shortcut
    #>
    param([string]$Subcommand = "")

    $parts = $Subcommand.Trim() -split '\s+', 2
    $sub   = $parts[0].ToLower()
    $name  = if ($parts.Length -gt 1) { $parts[1].ToLower().Trim() } else { "" }

    switch ($sub) {
        { $_ -in '', 'list' } { Show-Favorites }
        'add'    { Add-Favorite $name }
        { $_ -in 'remove', 'rm', 'delete', 'del' } { Remove-Favorite $name }
        default  { Play-Favorite $sub }   # fav workout → play "workout"
    }
}

function Show-Favorites {
    $favs = Get-FavoritesStore
    Write-Host ""
    Write-Host "  Favorite Playlists" -ForegroundColor Cyan
    Write-Host "  ==================" -ForegroundColor Cyan

    if ($favs.Count -eq 0) {
        Write-Host "  No favorites saved yet." -ForegroundColor Gray
        Write-Host "  Use 'fav add <name>' while a playlist is playing to save one." -ForegroundColor DarkGray
    } else {
        foreach ($key in ($favs.Keys | Sort-Object)) {
            $entry = $favs[$key]
            Write-Host ("  {0,-20} {1}" -f $key, $entry.name) -ForegroundColor White
        }
        Write-Host ""
        Write-Host "  Play with: fav <name>" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Add-Favorite {
    param([string]$Name)

    if (-not $Name) {
        Write-Host "Usage: fav add <name>" -ForegroundColor Yellow
        return
    }

    # Get current playback context
    try {
        $playback = Invoke-SpotifyApi -Method GET -Path "/me/player"
    } catch {
        Write-Host "Could not reach Spotify API." -ForegroundColor Red
        return
    }

    if (-not $playback -or -not $playback.context) {
        Write-Host "No playlist currently playing. Start a playlist first, then run 'fav add <name>'." -ForegroundColor Yellow
        return
    }

    $contextType = $playback.context.type
    if ($contextType -ne 'playlist') {
        Write-Host "Current context is '$contextType' — favorites only support playlists." -ForegroundColor Yellow
        return
    }

    $uri = $playback.context.uri  # e.g. spotify:playlist:37i9dQZF1DXcBWIGoYBM5M
    $id  = $uri -replace 'spotify:playlist:', ''

    # Fetch playlist name
    try {
        $playlist = Invoke-SpotifyApi -Method GET -Path "/playlists/$id" -Query @{ fields = 'name' }
        $playlistName = $playlist.name
    } catch {
        $playlistName = $id
    }

    $favs        = Get-FavoritesStore
    $favs[$Name] = @{ uri = $uri; name = $playlistName }
    Save-FavoritesStore $favs

    Write-Host ""
    Write-Host "  Saved '$Name' -> $playlistName" -ForegroundColor Green
    Write-Host "  Play with: fav $Name" -ForegroundColor DarkGray
    Write-Host ""
}

function Remove-Favorite {
    param([string]$Name)

    if (-not $Name) {
        Write-Host "Usage: fav remove <name>" -ForegroundColor Yellow
        return
    }

    $favs = Get-FavoritesStore
    if (-not $favs.ContainsKey($Name)) {
        Write-Host "No favorite named '$Name'. Run 'fav list' to see saved favorites." -ForegroundColor Yellow
        return
    }

    $removed = $favs[$Name].name
    $favs.Remove($Name)
    Save-FavoritesStore $favs

    Write-Host "Removed '$Name' ($removed)." -ForegroundColor Green
}

function Play-Favorite {
    param([string]$Name)

    if (-not $Name) {
        Show-Favorites
        return
    }

    $favs = Get-FavoritesStore
    if (-not $favs.ContainsKey($Name)) {
        Write-Host "No favorite named '$Name'. Run 'fav list' to see saved favorites." -ForegroundColor Yellow
        return
    }

    $entry = $favs[$Name]
    Write-Host "Playing: $($entry.name)" -ForegroundColor Cyan

    try {
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body @{
            context_uri = $entry.uri
        } | Out-Null
        Write-Host "Now playing '$($entry.name)'." -ForegroundColor Green
    } catch {
        Write-Host "Could not start playback: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function fav {
    Invoke-FavoriteCommand ($args -join ' ')
}

Export-ModuleMember -Function 'Invoke-FavoriteCommand', 'fav'
