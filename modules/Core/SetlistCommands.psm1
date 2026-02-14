# Setlist Commands Module - Concert setlists via setlist.fm API

function Search-SetlistFm {
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName
    )

    $apiKey = $env:SETLISTFM_API_KEY
    if (-not $apiKey) {
        Write-Host ""
        Write-Host "  No setlist.fm API key found." -ForegroundColor Red
        Write-Host ""
        Write-Host "  To use this feature:" -ForegroundColor Yellow
        Write-Host "  1. Register for free at https://api.setlist.fm" -ForegroundColor Gray
        Write-Host "  2. Go to your profile and copy your API key" -ForegroundColor Gray
        Write-Host "  3. Add to your .env file: SETLISTFM_API_KEY=your_key_here" -ForegroundColor Gray
        Write-Host "  4. Restart the CLI" -ForegroundColor Gray
        Write-Host ""
        return $null
    }

    $headers = @{
        "x-api-key" = $apiKey
        "Accept"    = "application/json"
    }

    $encodedArtist = [System.Uri]::EscapeDataString($ArtistName)
    $url = "https://api.setlist.fm/rest/1.0/search/setlists?artistName=$encodedArtist&p=1"

    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Write-Host "  No setlists found for '$ArtistName'." -ForegroundColor Yellow
        }
        elseif ($statusCode -eq 403) {
            Write-Host "  Invalid setlist.fm API key. Check your .env file." -ForegroundColor Red
        }
        else {
            Write-Host "  setlist.fm API error: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $null
    }

    if (-not $response.setlist -or $response.setlist.Count -eq 0) {
        Write-Host "  No setlists found for '$ArtistName'." -ForegroundColor Yellow
        return $null
    }

    # Filter to setlists that actually have songs, take up to 5
    $withSongs = $response.setlist | Where-Object {
        $songCount = 0
        if ($_.sets -and $_.sets.set) {
            foreach ($set in $_.sets.set) {
                if ($set.song) { $songCount += $set.song.Count }
            }
        }
        $songCount -gt 0
    } | Select-Object -First 5

    if ($withSongs.Count -eq 0) {
        Write-Host "  Found setlists for '$ArtistName' but none have song data." -ForegroundColor Yellow
        return $null
    }

    return @($withSongs)
}

function Show-SetlistResults {
    param(
        [Parameter(Mandatory)]
        [array]$Setlists
    )

    Write-Host ""
    Write-Host "  RECENT CONCERTS" -ForegroundColor Cyan
    Write-Host "  ===============" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $Setlists.Count; $i++) {
        $s = $Setlists[$i]
        $artistName = $s.artist.name
        $venueName = if ($s.venue.name) { $s.venue.name } else { "Unknown venue" }
        $cityName = if ($s.venue.city.name) { $s.venue.city.name } else { "Unknown city" }
        $eventDate = $s.eventDate  # dd-MM-yyyy format

        # Count songs
        $songCount = 0
        if ($s.sets -and $s.sets.set) {
            foreach ($set in $s.sets.set) {
                if ($set.song) { $songCount += $set.song.Count }
            }
        }

        $num = $i + 1
        Write-Host "  $num. " -ForegroundColor Yellow -NoNewline
        Write-Host "$artistName" -ForegroundColor White -NoNewline
        Write-Host " @ " -ForegroundColor Gray -NoNewline
        Write-Host "$venueName, $cityName" -ForegroundColor Cyan -NoNewline
        Write-Host " - $eventDate " -ForegroundColor Gray -NoNewline
        Write-Host "($songCount songs)" -ForegroundColor DarkGray
    }

    Write-Host ""
    $choice = Read-Host "  Pick a concert (1-$($Setlists.Count)), or press Enter to cancel"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        return -1
    }

    $index = 0
    if ([int]::TryParse($choice, [ref]$index)) {
        if ($index -ge 1 -and $index -le $Setlists.Count) {
            return $index - 1
        }
    }

    Write-Host "  Invalid selection." -ForegroundColor Red
    return -1
}

function Show-SetlistSongs {
    param(
        [Parameter(Mandatory)]
        $Setlist
    )

    $artistName = $Setlist.artist.name
    $venueName = if ($Setlist.venue.name) { $Setlist.venue.name } else { "Unknown venue" }
    $cityName = if ($Setlist.venue.city.name) { $Setlist.venue.city.name } else { "Unknown city" }
    $eventDate = $Setlist.eventDate

    Write-Host ""
    Write-Host "  $artistName @ $venueName, $cityName" -ForegroundColor Cyan
    Write-Host "  $eventDate" -ForegroundColor Gray
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray

    $songs = @()
    $setNumber = 0

    foreach ($set in $Setlist.sets.set) {
        $setNumber++
        if ($Setlist.sets.set.Count -gt 1) {
            $setLabel = if ($set.name) { $set.name } elseif ($set.encore -and $set.encore -gt 0) { "Encore" } else { "Set $setNumber" }
            Write-Host ""
            Write-Host "  $setLabel" -ForegroundColor Yellow
        }

        if ($set.song) {
            foreach ($song in $set.song) {
                $songs += $song.name
                $num = $songs.Count
                $coverInfo = ""
                if ($song.cover -and $song.cover.name) {
                    $coverInfo = " (cover: $($song.cover.name))"
                }
                Write-Host "  $num. $($song.name)$coverInfo" -ForegroundColor White
            }
        }
    }

    Write-Host ""
    return $songs
}

function New-SetlistPlaylist {
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string[]]$Songs,

        [string]$VenueName = "",
        [string]$EventDate = ""
    )

    Write-Host "  Searching Spotify for $($Songs.Count) songs..." -ForegroundColor Gray

    $matchedUris = @()
    $missedSongs = @()

    foreach ($song in $Songs) {
        $query = "track:$song artist:$ArtistName"
        $searchQuery = @{
            q     = $query
            type  = "track"
            limit = "1"
        }

        try {
            $result = Invoke-SpotifyApi -Method GET -Path "/search" -Query $searchQuery
            if ($result.tracks -and $result.tracks.items -and $result.tracks.items.Count -gt 0) {
                $matchedUris += $result.tracks.items[0].uri
                Write-Host "  + $song" -ForegroundColor Green
            }
            else {
                $missedSongs += $song
                Write-Host "  - $song (not found)" -ForegroundColor DarkGray
            }
        }
        catch {
            $missedSongs += $song
            Write-Host "  - $song (search error)" -ForegroundColor DarkGray
        }
    }

    if ($matchedUris.Count -eq 0) {
        Write-Host ""
        Write-Host "  No songs could be matched on Spotify." -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "  Matched $($matchedUris.Count)/$($Songs.Count) songs." -ForegroundColor Cyan

    # Get current user ID
    try {
        $userProfile = Invoke-SpotifyApi -Method GET -Path "/me"
        $userId = $userProfile.id
    }
    catch {
        Write-Host "  Could not get user profile." -ForegroundColor Red
        return
    }

    # Build playlist name
    $playlistName = "$ArtistName"
    if ($VenueName) { $playlistName += " @ $VenueName" }
    if ($EventDate) { $playlistName += " $EventDate" }

    # Create playlist
    $playlistBody = @{
        name        = $playlistName
        description = "Concert setlist - created by Spotify CLI"
        public      = $false
    }

    try {
        Write-Host "  Creating playlist '$playlistName'..." -ForegroundColor Gray
        $playlist = Invoke-SpotifyApi -Method POST -Path "/users/$userId/playlists" -Body $playlistBody
    }
    catch {
        Write-Host "  Failed to create playlist: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # Add tracks (batch up to 100)
    try {
        $addBody = @{ uris = $matchedUris }
        Invoke-SpotifyApi -Method POST -Path "/playlists/$($playlist.id)/tracks" -Body $addBody | Out-Null
    }
    catch {
        Write-Host "  Failed to add tracks: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "  Playlist created with $($matchedUris.Count)/$($Songs.Count) tracks!" -ForegroundColor Green
    if ($missedSongs.Count -gt 0) {
        Write-Host "  Missing: $($missedSongs -join ', ')" -ForegroundColor DarkGray
    }
    Write-Host "  $($playlist.external_urls.spotify)" -ForegroundColor Cyan
    Write-Host ""

    # Offer to play
    $playChoice = Read-Host "  Play now? [Y/n]"
    if ($playChoice -ne 'n' -and $playChoice -ne 'N') {
        try {
            $body = @{ context_uri = $playlist.uri }
            Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
            Write-Host "  Playing!" -ForegroundColor Green
        }
        catch {
            Write-Host "  Could not start playback. Make sure a device is active." -ForegroundColor Yellow
        }
    }
}

function Invoke-SetlistCommand {
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        $Arguments
    )

    # Flatten and join arguments into artist name
    $artistName = if ($Arguments) {
        ($Arguments | ForEach-Object { "$_" }) -join " "
    } else { "" }

    $artistName = $artistName.Trim()

    if ([string]::IsNullOrWhiteSpace($artistName)) {
        Write-Host ""
        Write-Host "  SETLIST - Concert Setlist Finder" -ForegroundColor Cyan
        Write-Host "  ================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Usage: /setlist <artist name>" -ForegroundColor White
        Write-Host ""
        Write-Host "  Examples:" -ForegroundColor Yellow
        Write-Host "    /setlist Tame Impala" -ForegroundColor Gray
        Write-Host "    /setlist Metallica" -ForegroundColor Gray
        Write-Host "    /setlist Taylor Swift" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Shows recent concerts and their setlists." -ForegroundColor Gray
        Write-Host "  Optionally creates a Spotify playlist from the setlist." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Requires a free API key from https://api.setlist.fm" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    Write-Host ""
    Write-Host "  Searching setlist.fm for '$artistName'..." -ForegroundColor Gray

    # Search setlist.fm
    $setlists = Search-SetlistFm -ArtistName $artistName
    if (-not $setlists) { return }

    # Show results and let user pick
    $selectedIndex = Show-SetlistResults -Setlists $setlists
    if ($selectedIndex -lt 0) {
        Write-Host "  Cancelled." -ForegroundColor Gray
        return
    }

    $selected = $setlists[$selectedIndex]

    # Show song list
    $songs = Show-SetlistSongs -Setlist $selected

    if ($songs.Count -eq 0) {
        Write-Host "  No songs in this setlist." -ForegroundColor Yellow
        return
    }

    # Offer to create playlist
    $createChoice = Read-Host "  Create Spotify playlist from this setlist? [Y/n]"
    if ($createChoice -eq 'n' -or $createChoice -eq 'N') {
        Write-Host "  Done." -ForegroundColor Gray
        return
    }

    $venueName = if ($selected.venue.name) { $selected.venue.name } else { "" }
    $eventDate = if ($selected.eventDate) { $selected.eventDate } else { "" }

    New-SetlistPlaylist -ArtistName $selected.artist.name -Songs $songs -VenueName $venueName -EventDate $eventDate
}

# Export and alias
New-Alias -Name 'setlist' -Value 'Invoke-SetlistCommand' -Force
Export-ModuleMember -Function 'Invoke-SetlistCommand' -Alias 'setlist'
