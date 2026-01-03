# SearchCommands Module
# Contains all core functions for searching and playing content from search results.

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
                        Start-InteractiveMode -Items $allItems -Title "Search Results for '$Query'"
                    }
                } catch {
                    # If ReadKey fails, just continue without interactive mode
                    Write-Host "ℹ️ Interactive mode not available in this terminal" -ForegroundColor Yellow
                }
            } else {
                Write-Host "ℹ️ Interactive mode not supported in this terminal" -ForegroundColor Yellow
            }
        }
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Search failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Check your internet connection and Spotify authentication." -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred during search: $($_.Exception.Message)" -ForegroundColor Red
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
    .EXAMPLE
    search-albums "the beatles"
    Search for Beatles albums
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
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Album search failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Check your internet connection and Spotify authentication." -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred during album search: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function play-album {
    <#
    .SYNOPSIS
    Play an album by number from the album search results
    .DESCRIPTION
    Plays an album by its number from the most recent search-albums results.
    The album will be played from the beginning.
    .PARAMETER AlbumNumber
    The number of the album from the search-albums command (1-10)
    .EXAMPLE
    play-album 1
    Play the first album from the search results
    .EXAMPLE
    search-albums "pink floyd"; play-album 2
    Search for Pink Floyd albums and play the second result
    #>
    param([Parameter(Mandatory)][int]$AlbumNumber)
    try {
        $sessionAlbums = Get-SessionAlbums
        # Check if we have session albums
        if (-not $sessionAlbums -or $sessionAlbums.Count -eq 0) {
            Write-Host "❌ No albums in session. Run 'search-albums' first." -ForegroundColor Red
            Write-Host "💡 Example: search-albums 'pink floyd'" -ForegroundColor Yellow
            return
        }
        # Validate album number
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
        # Play the album using its context URI
        $body = @{ context_uri = $albumUri }
        Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body
        Write-Host "▶️ Now playing: '$albumName'" -ForegroundColor Green
        Write-Host "👤 Artist: $artists" -ForegroundColor Yellow
        Write-Host "💿 $($album.total_tracks) tracks" -ForegroundColor Gray
        # Show release info if available
        if ($album.release_date) {
            try {
                $releaseYear = [DateTime]::Parse($album.release_date).Year
                Write-Host "📅 Released: $releaseYear" -ForegroundColor Gray
            } catch {
                Write-Host "📅 Released: $($album.release_date)" -ForegroundColor Gray
            }
        }
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not play album." -ForegroundColor Red
        if ($_.Exception.StatusCode -eq 403) {
            Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
        } elseif ($_.Exception.StatusCode -eq 404) {
            Write-Host "💡 Make sure Spotify is running on an active device." -ForegroundColor Yellow
            Write-Host "💡 Try running 'devices' to see available devices." -ForegroundColor Yellow
        }
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred while trying to play the album: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function queue-album {
    <#
    .SYNOPSIS
    Add an entire album to the queue by number from album search results
    .DESCRIPTION
    Adds all tracks from an album to the current playback queue.
    The album is identified by its number from the most recent search-albums results.
    .PARAMETER AlbumNumber
    The number of the album from the search-albums command (1-10)
    .EXAMPLE
    queue-album 1
    Add all tracks from album #1 to the queue
    .EXAMPLE
    search-albums "radiohead"; queue-album 3
    Search for Radiohead albums and add the third result to queue
    #>
    param([Parameter(Mandatory)][int]$AlbumNumber)
    try {
        $sessionAlbums = Get-SessionAlbums
        # Check if we have session albums
        if (-not $sessionAlbums -or $sessionAlbums.Count -eq 0) {
            Write-Host "❌ No albums in session. Run 'search-albums' first." -ForegroundColor Red
            Write-Host "💡 Example: search-albums 'radiohead'" -ForegroundColor Yellow
            return
        }
        # Validate album number
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
        # Get album tracks
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
                    # Add track to queue
                    $query = @{ uri = $track.uri }
                    Invoke-SpotifyApi -Method POST -Path "/me/player/queue" -Query $query
                    $addedCount++
                    # Small delay to avoid rate limiting
                    Start-Sleep -Milliseconds 100
                }
                catch [AuthenticationException] {
                    Write-Host "🔐 Authentication Error during track queueing (track: $($track.name)): Your Spotify session has expired." -ForegroundColor Red
                    Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
                    $skippedCount++
                    break # Stop adding tracks if auth fails
                }
                catch [ApiClientException] {
                    Write-Host "❌ Could not add track '$($track.name)' to queue: $($_.Exception.Message)" -ForegroundColor Red
                    if ($_.Exception.StatusCode -eq 403) {
                        Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
                    }
                    $skippedCount++
                }
                catch {
                    Write-Host "❌ An unexpected error occurred while queuing track '$($track.name)': $($_.Exception.Message)" -ForegroundColor Red
                    $skippedCount++
                }
            }
        }
        Write-Host "✅ Album '$albumName' added to queue. $addedCount tracks added, $skippedCount tracks skipped." -ForegroundColor Green
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not add album to queue." -ForegroundColor Red
        if ($_.Exception.StatusCode -eq 403) {
            Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
        }
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred while processing the album: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Export-ModuleMember -Function @(
    'search',
    'search-albums',
    'play-album',
    'queue-album'
)
