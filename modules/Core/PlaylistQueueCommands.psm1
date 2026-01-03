function playlists {
    <#
    .SYNOPSIS
    Show user's playlists with smart numbering
    .EXAMPLE
    playlists
    Show your playlists
    .EXAMPLE
    pl
    Show your playlists (alias)
    #>
    try {
        $playlistsResponse = Invoke-SpotifyApi -Method GET -Path "/me/playlists" -Query @{ limit = 20 }
        if (-not $playlistsResponse -or -not $playlistsResponse.items) {
            Write-Host "No playlists found" -ForegroundColor Yellow
            Set-SessionPlaylists -Playlists @() # Clear session playlists if no results
            return
        }
        # Store playlists in session for smart numbering
        Set-SessionPlaylists -Playlists $playlistsResponse.items
        Write-Host "📚 Your Playlists:" -ForegroundColor Cyan
        Write-Host ""
        $i = 1
        foreach ($playlist in $playlistsResponse.items) {
            $trackCount = $playlist.tracks.total
            $owner = $playlist.owner.display_name
            # Need to get current user ID for comparison
            # This is a general improvement: centralize current user info.
            # For now, rely on first item owner ID for comparison if available.
            $isOwn = $playlist.owner.id -eq $playlistsResponse.items[0].owner.id
            $ownerText = if ($isOwn) { "You" } else { $owner }
            Write-Host "$i. $($playlist.name)" -ForegroundColor White
            Write-Host "   $trackCount tracks • by $ownerText" -ForegroundColor Gray
            Write-Host "   URI: $($playlist.uri)" -ForegroundColor Gray
            Write-Host ""
            $i++
        }
        Write-Host "💡 Use 'play-playlist <number>' to play a playlist" -ForegroundColor Cyan
        Write-Host "💡 Use 'play-playlist <number> <track>' to play specific track" -ForegroundColor Cyan
        Write-Host "💡 Use 'queue-playlist <number>' to add playlist to queue" -ForegroundColor Cyan
        Write-Host "🎮 Press Enter for interactive navigation mode..." -ForegroundColor Cyan
        # Check if user wants to enter interactive mode
        $capabilities = Get-TerminalCapabilities
        if ($capabilities.SupportsInteractiveInput) {
            try {
                $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                if ($key.VirtualKeyCode -eq 13) { # Enter key
                    # Prepare playlist items for interactive mode
                    $interactiveItems = @()
                    $i = 0
                    foreach ($playlist in $playlistsResponse.items) {
                        $trackCount = $playlist.tracks.total
                        $owner = $playlist.owner.display_name
                        $isOwn = $playlist.owner.id -eq $playlistsResponse.items[0].owner.id
                        $ownerText = if ($isOwn) { "You" } else { $owner }
                        $interactiveItems += [PSCustomObject]@{
                            name = $playlist.name
                            uri = $playlist.uri
                            id = $playlist.id
                            type = "playlist"
                            search_type = "playlist"
                            description = "$trackCount tracks • by $ownerText"
                            tracks = @{ total = $trackCount }
                            owner = $playlist.owner
                        }
                        $i++
                    }
                    Start-InteractiveMode -Items $interactiveItems -Title "Your Playlists"
                }
            } catch {
                # If ReadKey fails, just continue without interactive mode
                Write-Host "ℹ️ Interactive mode not available in this terminal" -ForegroundColor Yellow
            }
        } else {
            Write-Host "ℹ️ Interactive mode not supported in this terminal" -ForegroundColor Yellow
        }
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        Set-SessionPlaylists -Playlists @()
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not get playlists." -ForegroundColor Red
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
        Set-SessionPlaylists -Playlists @()
    }
    catch {
        Write-Host "❌ An unexpected error occurred while retrieving playlists: $($_.Exception.Message)" -ForegroundColor Red
        Set-SessionPlaylists -Playlists @()
    }
}
function play-playlist {
    <#
    .SYNOPSIS
    Play a playlist by number from the playlists list
    .PARAMETER PlaylistNumber
    The number of the playlist from the playlists command
    .PARAMETER TrackNumber
    Optional track number within the playlist to start from
    .EXAMPLE
    play-playlist 1
    Play the first playlist from the list
    .EXAMPLE
    play-playlist 1 5
    Play track #5 from the first playlist
    #>
    param(
        [Parameter(Mandatory)][int]$PlaylistNumber,
        [int]$TrackNumber
    )
    try {
        $sessionPlaylists = Get-SessionPlaylists
        # Check if we have session playlists
        if (-not $sessionPlaylists -or $sessionPlaylists.Count -eq 0) {
            Write-Host "❌ No playlists in session. Run 'playlists' first." -ForegroundColor Red
            return
        }
        # Validate playlist number
        if ($PlaylistNumber -lt 1 -or $PlaylistNumber -gt $sessionPlaylists.Count) {
            Write-Host "❌ Invalid playlist number. Use 1-$($sessionPlaylists.Count)" -ForegroundColor Red
            return
        }
        $playlist = $sessionPlaylists[$PlaylistNumber - 1]
        $playlistName = $playlist.name
        $playlistUri = $playlist.uri
        if ($TrackNumber) {
            # Play specific track from playlist
            Write-Host "🎵 Getting tracks from playlist '$playlistName'..." -ForegroundColor Cyan
            # Get playlist tracks
            $playlistId = $playlist.id
            $tracksResponse = Invoke-SpotifyApi -Method GET -Path "/playlists/$playlistId/tracks" -Query @{ limit = 50 }
            if (-not $tracksResponse -or -not $tracksResponse.items) {
                Write-Host "❌ Could not get playlist tracks" -ForegroundColor Red
                return
            }
            # Validate track number
            if ($TrackNumber -lt 1 -or $TrackNumber -gt $tracksResponse.items.Count) {
                Write-Host "❌ Invalid track number. Playlist has $($tracksResponse.items.Count) tracks" -ForegroundColor Red
                return
            }
            $trackItem = $tracksResponse.items[$TrackNumber - 1]
            $track = $trackItem.track
            if (-not $track -or -not $track.uri) {
                Write-Host "❌ Track not available or invalid" -ForegroundColor Red
                return
            }
            # Play specific track
            $body = @{
                context_uri = $playlistUri
                offset = @{ position = $TrackNumber - 1 }
            }
            Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body
            $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
            Write-Host "▶️ Playing track #${TrackNumber}: '$($track.name)' by $artists" -ForegroundColor Green
            Write-Host "📚 From playlist: '$playlistName'" -ForegroundColor Cyan
        } else {
            # Play entire playlist from beginning
            $body = @{ context_uri = $playlistUri }
            Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body
            Write-Host "▶️ Playing playlist: '$playlistName'" -ForegroundColor Green
            Write-Host "📊 $($playlist.tracks.total) tracks" -ForegroundColor Cyan
        }
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not play playlist." -ForegroundColor Red
        if ($_.Exception.StatusCode -eq 403) {
            Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
        } elseif ($_.Exception.StatusCode -eq 404) {
            Write-Host "💡 Make sure Spotify is running on an active device." -ForegroundColor Yellow
            Write-Host "💡 Try running 'devices' to see available devices." -ForegroundColor Yellow
        }
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred while playing the playlist: $($_.Exception.Message)" -ForegroundColor Red
    }
}
function queue-playlist {
    <#
    .SYNOPSIS
    Add entire playlist to queue by number
    .PARAMETER PlaylistNumber
    The number of the playlist from the playlists command
    .EXAMPLE
    queue-playlist 2
    Add playlist #2 to the queue
    #>
    param([Parameter(Mandatory)][int]$PlaylistNumber)
    try {
        $sessionPlaylists = Get-SessionPlaylists
        # Check if we have session playlists
        if (-not $sessionPlaylists -or $sessionPlaylists.Count -eq 0) {
            Write-Host "❌ No playlists in session. Run 'playlists' first." -ForegroundColor Red
            return
        }
        # Validate playlist number
        if ($PlaylistNumber -lt 1 -or $PlaylistNumber -gt $sessionPlaylists.Count) {
            Write-Host "❌ Invalid playlist number. Use 1-$($sessionPlaylists.Count)" -ForegroundColor Red
            return
        }
        $playlist = $sessionPlaylists[$PlaylistNumber - 1]
        $playlistName = $playlist.name
        $playlistId = $playlist.id
        Write-Host "🎵 Adding playlist '$playlistName' to queue..." -ForegroundColor Cyan
        # Get playlist tracks
        $tracksResponse = Invoke-SpotifyApi -Method GET -Path "/playlists/$playlistId/tracks" -Query @{ limit = 50 }
        if (-not $tracksResponse -or -not $tracksResponse.items) {
            Write-Host "❌ Could not get playlist tracks" -ForegroundColor Red
            return
        }
        $addedCount = 0
        $skippedCount = 0
        foreach ($trackItem in $tracksResponse.items) {
            $track = $trackItem.track
            if ($track -and $track.uri -and $track.uri.StartsWith("spotify:track:")) {
                try {
                    # Add track to queue
                    Invoke-SpotifyApi -Method POST -Path "/me/player/queue" -Query @{ uri = $track.uri }
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
            } else {
                $skippedCount++
            }
        }
        Write-Host "✅ Added $addedCount tracks from '$playlistName' to queue" -ForegroundColor Green
        if ($skippedCount -gt 0) {
            Write-Host "⚠️ Skipped $skippedCount unavailable tracks" -ForegroundColor Yellow
        }
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not queue playlist." -ForegroundColor Red
        if ($_.Exception.StatusCode -eq 403) {
            Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
        }
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred while processing the playlist: $($_.Exception.Message)" -ForegroundColor Red
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
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not get liked songs." -ForegroundColor Red
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred while retrieving liked songs: $($_.Exception.Message)" -ForegroundColor Red
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
            $playedAt = [DateTime]::Parse($item.played_at).ToString("yyyy-MM-dd HH:mm")
            Write-Host "$i. $($track.name)" -ForegroundColor White
            Write-Host "   by $artists • $($track.album.name)" -ForegroundColor Gray
            Write-Host "   Played: $playedAt • URI: $($track.uri)" -ForegroundColor Gray
            Write-Host ""
            $i++
        }
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not get recently played songs." -ForegroundColor Red
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred while retrieving recently played songs: $($_.Exception.Message)" -ForegroundColor Red
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
                $sessionTracks = Get-SessionTracks
                if ($sessionTracks -and $itemIndex -ge 0 -and $itemIndex -lt $sessionTracks.Count) {
                    $item = $sessionTracks[$itemIndex]
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
            Invoke-SpotifyApi -Method PUT -Path "/me/episodes" -Query $query
            Write-Host "❤️ Saved podcast episode '$itemName' to your library" -ForegroundColor Magenta
        } else {
            # Save music track
            Invoke-SpotifyApi -Method PUT -Path "/me/tracks" -Query $query
            Write-Host "❤️ Saved track '$itemName' to your library" -ForegroundColor Green
        }
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not save item." -ForegroundColor Red
        Write-Host "💡 Make sure a track is playing or the item ID is valid." -ForegroundColor Yellow
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred while saving the item: $($_.Exception.Message)" -ForegroundColor Red
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
                $sessionTracks = Get-SessionTracks
                if ($sessionTracks -and $itemIndex -ge 0 -and $itemIndex -lt $sessionTracks.Count) {
                    $item = $sessionTracks[$itemIndex]
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
            Invoke-SpotifyApi -Method DELETE -Path "/me/episodes" -Query $query
            Write-Host "💔 Removed podcast episode '$itemName' from your library" -ForegroundColor Yellow
        } else {
            # Unsave music track
            Invoke-SpotifyApi -Method DELETE -Path "/me/tracks" -Query $query
            Write-Host "💔 Removed track '$itemName' from your library" -ForegroundColor Yellow
        }
    }
    catch [AuthenticationException] {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    catch [ApiClientException] {
        Write-Host "❌ Could not remove item from library." -ForegroundColor Red
        Write-Host "💡 Make sure a track is playing or the item ID is valid." -ForegroundColor Yellow
        Write-Host "💡 API Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ An unexpected error occurred while removing the item: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Export-ModuleMember -Function @(
    'playlists',
    'play-playlist',
    'queue-playlist',
    'liked',
    'recent',
    'save-track',
    'unsave-track'
)
