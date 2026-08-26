# Search Commands — devices, search, search-albums, play-album, queue-album

function devices {
    try {
        $devicesResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/devices"
        if (-not $devicesResponse -or -not $devicesResponse.devices -or $devicesResponse.devices.Count -eq 0) {
            Write-Host "📱 No Spotify Connect devices found" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "💡 To use device management features:" -ForegroundColor Cyan
            Write-Host "1. Open Spotify on any device (phone, computer, speaker, etc.)" -ForegroundColor White
            Write-Host "2. Start playing any song to activate the device" -ForegroundColor White
            Write-Host "3. Run 'devices' again to see available devices" -ForegroundColor White
            Write-Host ""
            Write-Host "🎵 Supported device types: Computer, Phone, Speaker, TV, Tablet" -ForegroundColor Gray
            return
        }
        # Store devices in session for numbered reference
        Set-SessionDevices -Devices $devicesResponse.devices
        Write-Host "📱 Available Devices:" -ForegroundColor Cyan
        $i = 1
        foreach ($device in $devicesResponse.devices) {
            $deviceIcon = switch ($device.type.ToLower()) {
                "computer" { "[PC]" }
                "smartphone" { "[Phone]" }
                "speaker" { "[Speaker]" }
                "tv" { "[TV]" }
                default { "[Device]" }
            }
            $activeStatus = if ($device.is_active) { "Active" } else { "Inactive" }
            $volumeInfo = if ($device.volume_percent -ne $null) { ", Volume: $($device.volume_percent)%" } else { "" }
            Write-Host "$i. $deviceIcon $($device.name) ($($device.type)) - $activeStatus$volumeInfo" -ForegroundColor White
            $i++
        }
        Write-Host ""
        Write-Host "💡 Tip: Use 'transfer 1' to switch to device #1" -ForegroundColor Gray
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($_.Exception.StatusCode -eq 403) {
            Write-Host "🚫 Permission Error: Device management requires Spotify Premium." -ForegroundColor Red
        }
        else {
            Write-Host "❌ API Error: $errorMessage" -ForegroundColor Red
            Write-Host "💡 Check your internet connection and try again" -ForegroundColor Yellow
        }
    }
}

function search {
    <#
    .SYNOPSIS
    Search for music with advanced filters
    .PARAMETER Query
    Search query (supports Spotify search syntax)
    .PARAMETER Type
    Filter by type: track, artist, album, episode, or all (default)
    .PARAMETER Genre
    Filter by genre
    .PARAMETER Year
    Filter by release year (e.g., 2023 or 2020-2023)
    .PARAMETER Limit
    Number of results to return (default: 10, max: 50)
    .EXAMPLE
    search "bohemian rhapsody"
    Basic search for tracks, artists, albums, and episodes
    .EXAMPLE
    search -Query "love" -Type track -Limit 20
    Search for 20 tracks containing "love"
    #>
    param(
        [Parameter(Position=0)]
        [string]$Query,

        [ValidateSet("track", "artist", "album", "episode", "all")]
        [string]$Type = "all",

        [string]$Genre,

        [string]$Year,

        [int]$Limit = 10
    )

    if ([string]::IsNullOrWhiteSpace($Query)) {
        Write-Host "Usage: search '<query>'" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Advanced options:" -ForegroundColor Cyan
        Write-Host "  search '<query>' -Type track     # Search only tracks" -ForegroundColor Gray
        Write-Host "  search '<query>' -Genre rock     # Filter by genre" -ForegroundColor Gray
        Write-Host "  search '<query>' -Year 2023      # Filter by year" -ForegroundColor Gray
        Write-Host "  search '<query>' -Limit 20       # Show more results" -ForegroundColor Gray
        return
    }

    # Build advanced query
    $advancedQuery = $Query

    if ($Genre) {
        $advancedQuery += " genre:$Genre"
    }

    if ($Year) {
        $advancedQuery += " year:$Year"
    }

    # Validate limit
    $Limit = [Math]::Min(50, [Math]::Max(1, $Limit))

    try {
        $searchType = if ($Type -eq "all") { "track,artist,album,episode" } else { $Type }

        $searchQuery = @{
            q = $advancedQuery
            type = $searchType
            limit = $Limit.ToString()
        }

        # Show search info
        Write-Host "🔍 Searching for: $Query" -ForegroundColor Cyan
        if ($Genre -or $Year) {
            Write-Host "   Filters: " -ForegroundColor Gray -NoNewline
            if ($Genre) { Write-Host "Genre=$Genre " -ForegroundColor Yellow -NoNewline }
            if ($Year) { Write-Host "Year=$Year" -ForegroundColor Yellow -NoNewline }
            Write-Host ""
        }
        Write-Host ""

        $results = Invoke-SpotifyApi -Method GET -Path "/search" -Query $searchQuery
        if (-not $results) {
            Write-Host "🔍 No results found for '$Query'." -ForegroundColor Yellow
            return
        }
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
        Set-SessionTracks -Tracks $allItems[0..9]  # Store up to 10 items (tracks + episodes)
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
            Write-Host "🎮 Press Enter for interactive navigation mode..." -ForegroundColor Cyan
            # Check if user wants to enter interactive mode
            $capabilities = Get-TerminalCapabilities
            if ($capabilities.SupportsInteractiveInput) {
                try {
                    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    if ($key.VirtualKeyCode -eq 13) { # Enter key
                        Start-InteractiveMode -Items $allItems -Mode "search"
                    }
                } catch {
                    Write-Host "ℹ️ Interactive mode not available in this terminal" -ForegroundColor Yellow
                }
            } else {
                Write-Host "ℹ️ Interactive mode not supported in this terminal" -ForegroundColor Yellow
            }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Search failed: $errorMessage" -ForegroundColor Red
            Write-Host "💡 Check your internet connection and Spotify authentication." -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred during search: $errorMessage" -ForegroundColor Red
        }
    }
}

function search-albums {
    <#
    .SYNOPSIS
    Search for albums only on Spotify
    .DESCRIPTION
    Searches Spotify for albums matching the query and displays results with smart numbering.
    Results are stored in session for use with play-album and queue-album commands.
    .PARAMETER Query
    The search query for albums
    .EXAMPLE
    search-albums "pink floyd"
    Search for Pink Floyd albums
    #>
    param([string]$Query)
    if ([string]::IsNullOrWhiteSpace($Query)) {
        Write-Host "Usage: search-albums '<query>'" -ForegroundColor Yellow
        Write-Host "Example: search-albums 'pink floyd'" -ForegroundColor Gray
        return
    }
    try {
        $searchQuery = @{
            q = $Query
            type = "album"
            limit = "10"
        }
        Write-Host "🔍 Searching albums for: $Query" -ForegroundColor Gray
        $results = Invoke-SpotifyApi -Method GET -Path "/search" -Query $searchQuery
        if (-not $results -or -not $results.albums -or -not $results.albums.items -or $results.albums.items.Count -eq 0) {
            Write-Host "💿 No albums found for '$Query'" -ForegroundColor Yellow
            Write-Host "💡 Try a different search term or check spelling" -ForegroundColor Gray
            return
        }
        Write-Host "💿 Album Search Results for '$Query':" -ForegroundColor Cyan
        Write-Host ""
        # Store albums in session for numbered reference
        Set-SessionAlbums -Albums $results.albums.items[0..9]  # Store up to 10 albums
        $i = 1
        foreach ($album in $results.albums.items[0..9]) {
            if (-not $album) { break }
            $artists = ($album.artists | ForEach-Object { $_.name }) -join ", "
            $releaseYear = if ($album.release_date) {
                try {
                    [DateTime]::Parse($album.release_date).Year
                } catch {
                    $album.release_date.Split('-')[0]
                }
            } else {
                "Unknown"
            }
            Write-Host "$i. " -NoNewline -ForegroundColor White
            Write-Host "$($album.name)" -NoNewline -ForegroundColor Cyan
            Write-Host " - " -NoNewline -ForegroundColor Gray
            Write-Host "$artists" -NoNewline -ForegroundColor Yellow
            Write-Host " ($releaseYear)" -ForegroundColor Green
            Write-Host "   💿 $($album.total_tracks) tracks" -ForegroundColor Gray
            $i++
        }
        Write-Host ""
        Write-Host "💡 Tip: Use 'play-album 1' to play album #1, or 'queue-album 2' to add album #2 to queue" -ForegroundColor Gray
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Album search failed: $errorMessage" -ForegroundColor Red
            Write-Host "💡 Check your internet connection and Spotify authentication." -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred during album search: $errorMessage" -ForegroundColor Red
        }
    }
}

function play-album {
    <#
    .SYNOPSIS
    Play an album by number from the album search results
    .PARAMETER AlbumNumber
    The number of the album from the search-albums command (1-10)
    .EXAMPLE
    play-album 1
    Play the first album from the search results
    #>
    param([Parameter(Mandatory)][int]$AlbumNumber)
    try {
        $sessionAlbums = Get-SessionAlbums
        if (-not $sessionAlbums -or $sessionAlbums.Count -eq 0) {
            Write-Host "❌ No albums in session. Run 'search-albums' first." -ForegroundColor Red
            Write-Host "💡 Example: search-albums 'pink floyd'" -ForegroundColor Yellow
            return
        }
        if ($AlbumNumber -lt 1 -or $AlbumNumber -gt $sessionAlbums.Count) {
            Write-Host "❌ Invalid album number. Use 1-$($sessionAlbums.Count)" -ForegroundColor Red
            Write-Host "💡 Use 'search-albums' to see available albums" -ForegroundColor Yellow
            return
        }
        $album = $sessionAlbums[$AlbumNumber - 1]
        $albumName = $album.name
        $albumUri = $album.uri
        $artists = ($album.artists | ForEach-Object { $_.name }) -join ", "
        Write-Host "🎵 Playing album #${AlbumNumber}: '$albumName' by $artists..." -ForegroundColor Cyan
        $body = @{ context_uri = $albumUri }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body | Out-Null
        Write-Host "▶️ Now playing: '$albumName'" -ForegroundColor Green
        Write-Host "👤 Artist: $artists" -ForegroundColor Yellow
        Write-Host "💿 $($album.total_tracks) tracks" -ForegroundColor Gray
        if ($album.release_date) {
            try {
                $releaseYear = [DateTime]::Parse($album.release_date).Year
                Write-Host "📅 Released: $releaseYear" -ForegroundColor Gray
            } catch {
                Write-Host "📅 Released: $($album.release_date)" -ForegroundColor Gray
            }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($_.Exception.StatusCode -eq 403 -or $_.Exception.StatusCode -eq 404) {
            Write-Host "❌ Could not play album." -ForegroundColor Red
            if ($_.Exception.StatusCode -eq 403) {
                Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
            } elseif ($_.Exception.StatusCode -eq 404) {
                Write-Host "💡 Make sure Spotify is running on an active device." -ForegroundColor Yellow
                Write-Host "💡 Try running 'devices' to see available devices." -ForegroundColor Yellow
            }
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while trying to play the album: $errorMessage" -ForegroundColor Red
        }
    }
}

function queue-album {
    <#
    .SYNOPSIS
    Add an entire album to the queue by number from album search results
    .PARAMETER AlbumNumber
    The number of the album from the search-albums command (1-10)
    .EXAMPLE
    queue-album 1
    Add all tracks from album #1 to the queue
    #>
    param([Parameter(Mandatory)][int]$AlbumNumber)
    try {
        $sessionAlbums = Get-SessionAlbums
        if (-not $sessionAlbums -or $sessionAlbums.Count -eq 0) {
            Write-Host "❌ No albums in session. Run 'search-albums' first." -ForegroundColor Red
            Write-Host "💡 Example: search-albums 'radiohead'" -ForegroundColor Yellow
            return
        }
        if ($AlbumNumber -lt 1 -or $AlbumNumber -gt $sessionAlbums.Count) {
            Write-Host "❌ Invalid album number. Use 1-$($sessionAlbums.Count)" -ForegroundColor Red
            Write-Host "💡 Use 'search-albums' to see available albums" -ForegroundColor Yellow
            return
        }
        $album = $sessionAlbums[$AlbumNumber - 1]
        $albumName = $album.name
        $albumId = $album.id
        $artists = ($album.artists | ForEach-Object { $_.name }) -join ", "
        Write-Host "🎵 Adding album '$albumName' by $artists to queue..." -ForegroundColor Cyan
        $tracksResponse = Invoke-SpotifyApi -Method GET -Path "/albums/$albumId/tracks" -Query @{ limit = 50 }
        if (-not $tracksResponse -or -not $tracksResponse.items) {
            Write-Host "❌ Could not get album tracks" -ForegroundColor Red
            return
        }
        $addedCount = 0
        $skippedCount = 0
        Write-Host "📀 Adding $($tracksResponse.items.Count) tracks to queue..." -ForegroundColor Gray
        foreach ($track in $tracksResponse.items) {
            if ($track -and $track.uri -and $track.uri.StartsWith("spotify:track:")) {
                try {
                    $query = @{ uri = $track.uri }
                    Invoke-SpotifyApi -Method POST -Path "/me/player/queue" -Query $query | Out-Null
                    $addedCount++
                    Start-Sleep -Milliseconds 100
                }
                catch {
                    $errorMessage = $_.Exception.Message
                    if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
                        Write-Host "🔐 Authentication Error during track queueing (track: $($track.name)): Your Spotify session has expired." -ForegroundColor Red
                        Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
                        $skippedCount++
                        break
                    }
                    elseif ($_.Exception.StatusCode -eq 403) {
                        Write-Host "❌ Could not add track '$($track.name)' to queue: $errorMessage" -ForegroundColor Red
                        Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
                        $skippedCount++
                    }
                    else {
                        Write-Host "❌ An unexpected error occurred while queuing track '$($track.name)': $errorMessage" -ForegroundColor Red
                        $skippedCount++
                    }
                }
            }
        }
        Write-Host "✅ Album '$albumName' added to queue. $addedCount tracks added, $skippedCount tracks skipped." -ForegroundColor Green
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($_.Exception.StatusCode -eq 403) {
            Write-Host "❌ Could not add album to queue." -ForegroundColor Red
            Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while processing the album: $errorMessage" -ForegroundColor Red
        }
    }
}
