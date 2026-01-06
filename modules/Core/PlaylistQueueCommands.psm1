# Playlist and Queue Commands Module

function queue {
    <#
    .SYNOPSIS
    Manage playback queue - display, add, clear, or remove tracks
    .DESCRIPTION
    Advanced queue management with multiple operations:
    - Display current queue (no parameters)
    - Add track by number or URI
    - Clear entire queue
    - Remove specific tracks from queue
    .PARAMETER Operation
    The first operation parameter (optional)
    .PARAMETER SecondArg
    The second argument for operations like 'remove <number>' (optional)
    .EXAMPLE
    queue
    Display current queue with track numbers
    .EXAMPLE
    queue 1
    Add track #1 from search results to queue
    .EXAMPLE
    queue clear
    Clear the entire queue
    .EXAMPLE
    queue remove 3
    Remove track #3 from the queue
    .EXAMPLE
    queue spotify:track:4iV5W9uYEdYUVa79Axb7Rh
    Add track to queue by URI
    #>
    param(
        [string]$Operation,
        [string]$SecondArg
    )
    # If no operation specified, display current queue
    if ([string]::IsNullOrWhiteSpace($Operation)) {
        Show-SpotifyQueue
        return
    }
    $operation = $Operation.ToLower()
    # Handle different operations
    switch ($operation) {
        "clear" {
            Clear-SpotifyQueue
            return
        }
        "remove" {
            if ([string]::IsNullOrWhiteSpace($SecondArg)) {
                Write-Host "❌ Usage: queue remove <track_number>" -ForegroundColor Red
                Write-Host "💡 Use 'queue' to see track numbers" -ForegroundColor Yellow
                return
            }
            Remove-SpotifyQueueTrack -TrackNumber $SecondArg
            return
        }
        default {
            # Add track to queue (existing functionality)
            Add-SpotifyQueueTrack -TrackReference $operation
        }
    }
}
function Show-SpotifyQueue {
    <#
    .SYNOPSIS
    Display the current Spotify queue with track numbers and statistics
    #>
    try {
        # Get current queue from Spotify API
        $queueResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/queue"
        if (-not $queueResponse) {
            Write-Host "📭 Queue is empty" -ForegroundColor Yellow
            return
        }

        Write-Host "🎵 Spotify Queue" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor DarkGray
        Write-Host ""

        # Show currently playing track
        if ($queueResponse.currently_playing) {
            $current = $queueResponse.currently_playing
            $isPodcast = $current.type -eq "episode"

            if ($isPodcast) {
                Write-Host "▶️  Now Playing" -ForegroundColor Green
                Write-Host "    🎙️  $($current.name)" -ForegroundColor White
                Write-Host "    📻 $($current.show.name)" -ForegroundColor Gray
                if ($current.duration_ms) {
                    $duration = Format-Time $current.duration_ms
                    Write-Host "    ⏱️  $duration" -ForegroundColor DarkGray
                }
            } else {
                $artists = ($current.artists | ForEach-Object { $_.name }) -join ", "
                Write-Host "▶️  Now Playing" -ForegroundColor Green
                Write-Host "    🎵 $($current.name)" -ForegroundColor White
                Write-Host "    👤 $artists" -ForegroundColor Gray
                Write-Host "    📀 $($current.album.name)" -ForegroundColor DarkGray
                if ($current.duration_ms) {
                    $duration = Format-Time $current.duration_ms
                    Write-Host "    ⏱️  $duration" -ForegroundColor DarkGray
                }
            }
            Write-Host ""
        }

        # Show queued tracks
        if ($queueResponse.queue -and $queueResponse.queue.Count -gt 0) {
            Write-Host "📋 Up Next ($($queueResponse.queue.Count) tracks)" -ForegroundColor Yellow
            Write-Host ""

            $i = 1
            $totalDuration = 0

            foreach ($track in $queueResponse.queue) {
                $isPodcast = $track.type -eq "episode"

                if ($isPodcast) {
                    Write-Host "  $i. 🎙️  $($track.name)" -ForegroundColor Magenta
                    Write-Host "      📻 $($track.show.name)" -ForegroundColor Gray
                } else {
                    $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
                    Write-Host "  $i. 🎵 $($track.name)" -ForegroundColor White
                    Write-Host "      👤 $artists" -ForegroundColor Gray
                }

                # Show duration and accumulate total
                if ($track.duration_ms) {
                    $duration = Format-Time $track.duration_ms
                    Write-Host "      ⏱️  $duration" -ForegroundColor DarkGray
                    $totalDuration += $track.duration_ms
                }

                Write-Host ""
                $i++

                # Limit display to first 20 tracks to avoid overwhelming output
                if ($i -gt 20) {
                    $remaining = $queueResponse.queue.Count - 20
                    Write-Host "  ... and $remaining more tracks" -ForegroundColor DarkGray
                    Write-Host ""

                    # Calculate remaining duration
                    $remainingTracks = $queueResponse.queue | Select-Object -Skip 20
                    foreach ($t in $remainingTracks) {
                        if ($t.duration_ms) {
                            $totalDuration += $t.duration_ms
                        }
                    }
                    break
                }
            }

            # Show queue statistics
            Write-Host ("=" * 60) -ForegroundColor DarkGray
            Write-Host "📊 Queue Statistics:" -ForegroundColor Cyan
            Write-Host "   Total tracks: $($queueResponse.queue.Count)" -ForegroundColor White

            if ($totalDuration -gt 0) {
                $hours = [Math]::Floor($totalDuration / 3600000)
                $minutes = [Math]::Floor(($totalDuration % 3600000) / 60000)
                if ($hours -gt 0) {
                    Write-Host "   Total duration: ${hours}h ${minutes}m" -ForegroundColor White
                } else {
                    Write-Host "   Total duration: ${minutes}m" -ForegroundColor White
                }
            }

            Write-Host ""
            Write-Host "💡 Commands:" -ForegroundColor Yellow
            Write-Host "   queue <number>  - Add track from search to queue" -ForegroundColor Gray
            Write-Host "   next            - Skip to next track" -ForegroundColor Gray

        } else {
            Write-Host "📭 Queue is empty" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "💡 Use 'search' then 'queue <number>' to add tracks" -ForegroundColor Cyan
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not retrieve queue information." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while retrieving the queue: $errorMessage" -ForegroundColor Red
        }
    }
}
function Clear-SpotifyQueue {
    <#
    .SYNOPSIS
    Clear the entire Spotify queue
    #>
    try {
        # Note: Spotify Web API doesn't have a direct "clear queue" endpoint
        # We need to get the queue and remove tracks individually
        Write-Host "🧹 Clearing Spotify queue..." -ForegroundColor Yellow
        $queueResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/queue"
        if (-not $queueResponse -or -not $queueResponse.queue -or $queueResponse.queue.Count -eq 0) {
            Write-Host "📭 Queue is already empty" -ForegroundColor Green
            return
        }
        # Unfortunately, Spotify Web API doesn't have a direct "clear queue" endpoint.
        # This is a limitation of the Spotify Web API itself.
        Write-Host "⚠️ Spotify Web API doesn't support clearing the queue directly" -ForegroundColor Yellow
        Write-Host "💡 Alternative solutions:" -ForegroundColor Cyan
        Write-Host "   • Skip to end of queue using next/previous controls" -ForegroundColor White
        Write-Host "   • Start playing a different playlist/album to replace queue" -ForegroundColor White
        Write-Host "   • Use Spotify app directly to clear queue" -ForegroundColor White
        # Show current queue size
        Write-Host "📊 Current queue has $($queueResponse.queue.Count) tracks" -ForegroundColor Gray
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not retrieve queue to clear." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while trying to clear the queue: $errorMessage" -ForegroundColor Red
        }
    }
}
function Remove-SpotifyQueueTrack {
    <#
    .SYNOPSIS
    Remove a specific track from the Spotify queue by number
    #>
    param([string]$TrackNumber)
    if (-not ($TrackNumber -match '^\d+$')) {
        Write-Host "❌ Invalid track number. Must be a number." -ForegroundColor Red
        return
    }
    try {
        Write-Host "🗑️ Attempting to remove track #$TrackNumber from queue..." -ForegroundColor Yellow
        # Unfortunately, Spotify Web API doesn't provide a way to remove specific tracks from queue
        # This is a limitation of the Spotify Web API itself
        Write-Host "⚠️ Spotify Web API doesn't support removing specific tracks from queue" -ForegroundColor Yellow
        Write-Host "💡 Alternative solutions:" -ForegroundColor Cyan
        Write-Host "   • Use 'queue' to see current queue" -ForegroundColor White
        Write-Host "   • Skip tracks using 'next' command" -ForegroundColor White
        Write-Host "   • Use Spotify app directly to manage queue" -ForegroundColor White
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not remove track from queue due to API issues." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while trying to remove the track: $errorMessage" -ForegroundColor Red
        }
    }
}
function Add-SpotifyQueueTrack {
    <#
    .SYNOPSIS
    Add a track to the Spotify queue by number or URI
    #>
    param([string]$TrackReference)
    if ([string]::IsNullOrWhiteSpace($TrackReference)) {
        Write-Host "❌ Usage: queue <track_number_or_uri>" -ForegroundColor Red
        Write-Host "💡 Use 'search' command to find tracks first" -ForegroundColor Yellow
        return
    }
    $trackUri = $TrackReference
    $trackName = ""
    $artistInfo = ""
    # Check if it's a number (track index from search)
    if ($TrackReference -match '^\d+$') {
        $trackIndex = [int]$TrackReference - 1
        $sessionTracks = Get-SessionTracks
        if ($sessionTracks -and $trackIndex -ge 0 -and $trackIndex -lt $sessionTracks.Count) {
            $item = $sessionTracks[$trackIndex]
            $trackUri = $item.uri
            $trackName = $item.name
            # Handle both tracks and episodes
            if ($item.search_type -eq "episode" -or $item.type -eq "episode") {
                $artistInfo = "from $($item.show.name)"
                Write-Host "🎯 Adding podcast episode #$TrackReference ($trackName $artistInfo) to queue..." -ForegroundColor Magenta
            } else {
                $artistInfo = "by " + (($item.artists | ForEach-Object { $_.name }) -join ", ")
                Write-Host "🎯 Adding track #$TrackReference ($trackName $artistInfo) to queue..." -ForegroundColor Cyan
            }
        } else {
            Write-Host "❌ Invalid track number. Use 'search' to find tracks first." -ForegroundColor Red
            return
        }
    }
    # Ensure it's a valid Spotify URI (track or episode)
    if (-not ($trackUri.StartsWith("spotify:track:") -or $trackUri.StartsWith("spotify:episode:"))) {
        Write-Host "❌ Invalid URI. Must be a Spotify track or episode URI" -ForegroundColor Red
        return
    }
    try {
        $query = @{ uri = $trackUri }
        Invoke-SpotifyApi -Method POST -Path "/me/player/queue" -Query $query
        if ($trackUri.StartsWith("spotify:episode:")) {
            Write-Host "➕ Podcast episode added to queue" -ForegroundColor Magenta
        } else {
            Write-Host "➕ Track added to queue" -ForegroundColor Green
        }
        # Show helpful tip
        Write-Host "💡 Use 'queue' to see current queue" -ForegroundColor Gray
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($_.Exception.StatusCode -eq 403 -or $_.Exception.StatusCode -eq 404) {
            Write-Host "❌ Could not add to queue." -ForegroundColor Red
            if ($_.Exception.StatusCode -eq 403) {
                Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
            } elseif ($_.Exception.StatusCode -eq 404) {
                Write-Host "💡 Make sure Spotify is running on an active device." -ForegroundColor Yellow
            }
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while adding to queue: $errorMessage" -ForegroundColor Red
        }
    }
}
function create-playlist {
    <#
    .SYNOPSIS
    Create a new Spotify playlist
    .PARAMETER Name
    Name of the new playlist
    .PARAMETER Description
    Optional description
    .PARAMETER Public
    Make playlist public (default: private)
    .EXAMPLE
    create-playlist "My Awesome Mix"
    Create a private playlist
    .EXAMPLE
    create-playlist -Name "Road Trip 2024" -Description "Best songs for driving" -Public
    Create a public playlist with description
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [string]$Description = "",

        [switch]$Public
    )

    try {
        # Get current user ID
        $userProfile = Invoke-SpotifyApi -Method GET -Path "/me"
        $userId = $userProfile.id

        $body = @{
            name = $Name
            description = $Description
            public = $Public.IsPresent
        }

        Write-Host "🎵 Creating playlist '$Name'..." -ForegroundColor Cyan

        $playlist = Invoke-SpotifyApi -Method POST -Path "/users/$userId/playlists" -Body $body

        if ($playlist) {
            Write-Host "✅ Playlist created successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "📚 $($playlist.name)" -ForegroundColor White
            if ($Description) {
                Write-Host "   📝 $Description" -ForegroundColor Gray
            }
            $visibility = if ($Public) { "Public" } else { "Private" }
            Write-Host "   👁️  $visibility" -ForegroundColor Gray
            Write-Host "   🔗 $($playlist.external_urls.spotify)" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "💡 Use 'add-to-playlist' to add tracks" -ForegroundColor Yellow
        }

    } catch {
        Write-Host "❌ Failed to create playlist: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function delete-playlist {
    <#
    .SYNOPSIS
    Unfollow/delete a playlist
    .PARAMETER PlaylistId
    Playlist number from 'playlists' command or playlist ID/URI
    .EXAMPLE
    delete-playlist 3
    Delete playlist #3 from your list
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$PlaylistId
    )

    try {
        $actualPlaylistId = $PlaylistId

        # Check if it's a number (playlist index)
        if ($PlaylistId -match '^\d+$') {
            $playlistIndex = [int]$PlaylistId - 1
            $sessionPlaylists = Get-SessionPlaylists

            if ($sessionPlaylists -and $playlistIndex -ge 0 -and $playlistIndex -lt $sessionPlaylists.Count) {
                $actualPlaylistId = $sessionPlaylists[$playlistIndex].id
                $playlistName = $sessionPlaylists[$playlistIndex].name
            } else {
                Write-Host "❌ Invalid playlist number. Run 'playlists' first." -ForegroundColor Red
                return
            }
        }

        # Extract ID from URI if needed
        if ($actualPlaylistId -like "spotify:playlist:*") {
            $actualPlaylistId = $actualPlaylistId -replace "spotify:playlist:", ""
        }

        Write-Host "⚠️  Are you sure you want to unfollow this playlist?" -ForegroundColor Yellow
        Write-Host "   This action cannot be undone." -ForegroundColor Gray
        $confirm = Read-Host "Type 'yes' to confirm"

        if ($confirm -eq "yes") {
            Invoke-SpotifyApi -Method DELETE -Path "/playlists/$actualPlaylistId/followers"
            Write-Host "✅ Playlist unfollowed successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ Cancelled" -ForegroundColor Yellow
        }

    } catch {
        Write-Host "❌ Failed to delete playlist: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function create-smart-playlist {
    <#
    .SYNOPSIS
    Create a smart playlist based on mood or similar tracks
    .PARAMETER Name
    Name for the new playlist
    .PARAMETER BasedOn
    Base on: current track, search result number, or track URI
    .PARAMETER Mood
    Target mood: energetic, chill, happy, sad, focus, party
    .PARAMETER Limit
    Number of tracks to generate (default: 20, max: 50)
    .EXAMPLE
    create-smart-playlist "Workout Mix" -Mood energetic -Limit 30
    Create an energetic playlist with 30 tracks
    .EXAMPLE
    create-smart-playlist "Like This" -BasedOn 1
    Create playlist similar to search result #1
    .EXAMPLE
    create-smart-playlist "Similar to Current" -BasedOn current
    Create playlist similar to currently playing track
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [string]$BasedOn = "current",

        [ValidateSet("energetic", "chill", "happy", "sad", "focus", "party", "none")]
        [string]$Mood = "none",

        [int]$Limit = 20
    )

    try {
        Write-Host "🎵 Creating smart playlist '$Name'..." -ForegroundColor Cyan
        Write-Host ""

        # Validate limit
        $Limit = [Math]::Min(50, [Math]::Max(1, $Limit))

        # Get seed tracks
        $seedTracks = @()

        if ($BasedOn -eq "current") {
            # Use current track
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            if ($currentTrack -and $currentTrack.item) {
                $seedTracks += $currentTrack.item.id
                Write-Host "🎯 Seed: $($currentTrack.item.name) by $(($currentTrack.item.artists | ForEach-Object { $_.name }) -join ', ')" -ForegroundColor Gray
            } else {
                Write-Host "❌ No track currently playing" -ForegroundColor Red
                return
            }
        } elseif ($BasedOn -match '^\d+$') {
            # Use search result
            $trackIndex = [int]$BasedOn - 1
            $sessionTracks = Get-SessionTracks

            if ($sessionTracks -and $trackIndex -ge 0 -and $trackIndex -lt $sessionTracks.Count) {
                $track = $sessionTracks[$trackIndex]
                $seedTracks += $track.id
                Write-Host "🎯 Seed: $($track.name)" -ForegroundColor Gray
            } else {
                Write-Host "❌ Invalid track number. Run 'search' first." -ForegroundColor Red
                return
            }
        } else {
            # Assume it's a track URI/ID
            $trackId = $BasedOn -replace "spotify:track:", ""
            $seedTracks += $trackId
            Write-Host "🎯 Seed track ID: $trackId" -ForegroundColor Gray
        }

        # Build recommendation parameters based on mood
        $recParams = @{
            limit = $Limit
            seed_tracks = $seedTracks -join ","
        }

        switch ($Mood) {
            "energetic" {
                $recParams.target_energy = 0.8
                $recParams.target_valence = 0.7
                $recParams.min_tempo = 120
                Write-Host "🎸 Mood: Energetic (high energy, upbeat)" -ForegroundColor Magenta
            }
            "chill" {
                $recParams.target_energy = 0.3
                $recParams.target_valence = 0.5
                $recParams.max_tempo = 100
                Write-Host "🌊 Mood: Chill (relaxed, low energy)" -ForegroundColor Cyan
            }
            "happy" {
                $recParams.target_valence = 0.8
                $recParams.target_energy = 0.6
                Write-Host "😊 Mood: Happy (positive, uplifting)" -ForegroundColor Yellow
            }
            "sad" {
                $recParams.target_valence = 0.2
                $recParams.target_energy = 0.3
                Write-Host "😢 Mood: Sad (melancholic, low valence)" -ForegroundColor Blue
            }
            "focus" {
                $recParams.target_instrumentalness = 0.7
                $recParams.target_energy = 0.4
                $recParams.max_speechiness = 0.3
                Write-Host "🎯 Mood: Focus (instrumental, moderate energy)" -ForegroundColor DarkCyan
            }
            "party" {
                $recParams.target_danceability = 0.8
                $recParams.target_energy = 0.8
                $recParams.min_tempo = 110
                Write-Host "🎉 Mood: Party (high danceability and energy)" -ForegroundColor Green
            }
        }

        Write-Host "🔍 Getting recommendations..." -ForegroundColor Cyan

        # Get recommendations
        $recommendations = Invoke-SpotifyApi -Method GET -Path "/recommendations" -Query $recParams

        if (-not $recommendations -or -not $recommendations.tracks) {
            Write-Host "❌ No recommendations found" -ForegroundColor Red
            return
        }

        Write-Host "✅ Found $($recommendations.tracks.Count) recommended tracks" -ForegroundColor Green
        Write-Host ""

        # Create playlist
        $userProfile = Invoke-SpotifyApi -Method GET -Path "/me"
        $userId = $userProfile.id

        $description = "Smart playlist"
        if ($Mood -ne "none") {
            $description += " with $Mood mood"
        }
        $description += " - Generated by Spotify CLI"

        $playlistBody = @{
            name = $Name
            description = $description
            public = $false
        }

        $playlist = Invoke-SpotifyApi -Method POST -Path "/users/$userId/playlists" -Body $playlistBody

        # Add tracks to playlist
        $trackUris = $recommendations.tracks | ForEach-Object { $_.uri }
        $addTracksBody = @{ uris = $trackUris }
        Invoke-SpotifyApi -Method POST -Path "/playlists/$($playlist.id)/tracks" -Body $addTracksBody

        Write-Host "✅ Smart playlist created successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📚 $($playlist.name)" -ForegroundColor White
        Write-Host "   📝 $description" -ForegroundColor Gray
        Write-Host "   🎵 $($recommendations.tracks.Count) tracks added" -ForegroundColor Gray
        Write-Host "   🔗 $($playlist.external_urls.spotify)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "💡 Use 'play-playlist' to start listening" -ForegroundColor Yellow

    } catch {
        Write-Host "❌ Failed to create smart playlist: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function get-recommendations {
    <#
    .SYNOPSIS
    Get track recommendations based on current track or mood
    .PARAMETER BasedOn
    Base on: current, track number, or track ID
    .PARAMETER Mood
    Target mood for recommendations
    .PARAMETER Limit
    Number of recommendations (default: 10)
    .EXAMPLE
    get-recommendations
    Get recommendations based on current track
    .EXAMPLE
    get-recommendations -Mood energetic -Limit 20
    Get 20 energetic track recommendations
    #>
    param(
        [string]$BasedOn = "current",

        [ValidateSet("energetic", "chill", "happy", "sad", "focus", "party", "none")]
        [string]$Mood = "none",

        [int]$Limit = 10
    )

    try {
        # Similar logic to create-smart-playlist but just displays
        Write-Host "🔍 Getting recommendations..." -ForegroundColor Cyan

        # Get seed (reuse logic from create-smart-playlist)
        $seedTracks = @()

        if ($BasedOn -eq "current") {
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
            if ($currentTrack -and $currentTrack.item) {
                $seedTracks += $currentTrack.item.id
            } else {
                Write-Host "❌ No track currently playing" -ForegroundColor Red
                return
            }
        }

        $recParams = @{
            limit = [Math]::Min(50, [Math]::Max(1, $Limit))
            seed_tracks = $seedTracks -join ","
        }

        # Add mood parameters
        switch ($Mood) {
            "energetic" { $recParams.target_energy = 0.8; $recParams.target_valence = 0.7 }
            "chill" { $recParams.target_energy = 0.3; $recParams.max_tempo = 100 }
            "happy" { $recParams.target_valence = 0.8 }
            "sad" { $recParams.target_valence = 0.2 }
            "focus" { $recParams.target_instrumentalness = 0.7 }
            "party" { $recParams.target_danceability = 0.8; $recParams.target_energy = 0.8 }
        }

        $recommendations = Invoke-SpotifyApi -Method GET -Path "/recommendations" -Query $recParams

        if ($recommendations -and $recommendations.tracks) {
            Write-Host "🎵 Recommended Tracks:" -ForegroundColor Green
            Write-Host ""

            $i = 1
            foreach ($track in $recommendations.tracks) {
                $artists = ($track.artists | ForEach-Object { $_.name }) -join ", "
                Write-Host "$i. $($track.name)" -ForegroundColor White
                Write-Host "   by $artists • $($track.album.name)" -ForegroundColor Gray
                $i++
            }

            Write-Host ""
            Write-Host "💡 Use 'create-smart-playlist' to save these as a playlist" -ForegroundColor Yellow
        } else {
            Write-Host "❌ No recommendations found" -ForegroundColor Red
        }

    } catch {
        Write-Host "❌ Failed to get recommendations: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function add-to-playlist {
    <#
    .SYNOPSIS
    Add current track or search result to playlist
    .PARAMETER PlaylistNumber
    Playlist number from 'playlists' command
    .PARAMETER TrackNumber
    Optional track number from search results
    .EXAMPLE
    add-to-playlist 1
    Add currently playing track to playlist #1
    .EXAMPLE
    add-to-playlist 2 3
    Add search result #3 to playlist #2
    #>
    param(
        [Parameter(Mandatory=$true)]
        [int]$PlaylistNumber,

        [int]$TrackNumber = 0
    )

    try {
        # Get playlist
        $sessionPlaylists = Get-SessionPlaylists
        $playlistIndex = $PlaylistNumber - 1

        if (-not $sessionPlaylists -or $playlistIndex -lt 0 -or $playlistIndex -ge $sessionPlaylists.Count) {
            Write-Host "❌ Invalid playlist number. Run 'playlists' first." -ForegroundColor Red
            return
        }

        $playlist = $sessionPlaylists[$playlistIndex]
        $playlistId = $playlist.id

        # Get track URI
        $trackUri = $null

        if ($TrackNumber -gt 0) {
            # Get from search results
            $sessionTracks = Get-SessionTracks
            $trackIndex = $TrackNumber - 1

            if ($sessionTracks -and $trackIndex -ge 0 -and $trackIndex -lt $sessionTracks.Count) {
                $trackUri = $sessionTracks[$trackIndex].uri
                $trackName = $sessionTracks[$trackIndex].name
            } else {
                Write-Host "❌ Invalid track number. Run 'search' first." -ForegroundColor Red
                return
            }
        } else {
            # Get current track
            $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"

            if (-not $currentTrack -or -not $currentTrack.item) {
                Write-Host "❌ No track playing. Use: add-to-playlist <playlist> <track>" -ForegroundColor Red
                return
            }

            $trackUri = $currentTrack.item.uri
            $trackName = $currentTrack.item.name
        }

        # Add track to playlist
        $body = @{ uris = @($trackUri) }
        Invoke-SpotifyApi -Method POST -Path "/playlists/$playlistId/tracks" -Body $body

        Write-Host "✅ Added '$trackName' to '$($playlist.name)'" -ForegroundColor Green

    } catch {
        Write-Host "❌ Failed to add track: $($_.Exception.Message)" -ForegroundColor Red
    }
}

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
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not get playlists." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while retrieving playlists: $errorMessage" -ForegroundColor Red
        }
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
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($_.Exception.StatusCode -eq 403 -or $_.Exception.StatusCode -eq 404) {
            Write-Host "❌ Could not play playlist." -ForegroundColor Red
            if ($_.Exception.StatusCode -eq 403) {
                Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
            } elseif ($_.Exception.StatusCode -eq 404) {
                Write-Host "💡 Make sure Spotify is running on an active device." -ForegroundColor Yellow
                Write-Host "💡 Try running 'devices' to see available devices." -ForegroundColor Yellow
            }
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while playing the playlist: $errorMessage" -ForegroundColor Red
        }
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
                catch {
                    $errorMessage = $_.Exception.Message
                    if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
                        Write-Host "🔐 Authentication Error during track queueing (track: $($track.name)): Your Spotify session has expired." -ForegroundColor Red
                        Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
                        $skippedCount++
                        break # Stop adding tracks if auth fails
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
            } else {
                $skippedCount++
            }
        }
        Write-Host "✅ Added $addedCount tracks from '$playlistName' to queue" -ForegroundColor Green
        if ($skippedCount -gt 0) {
            Write-Host "⚠️ Skipped $skippedCount unavailable tracks" -ForegroundColor Yellow
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($_.Exception.StatusCode -eq 403) {
            Write-Host "❌ Could not queue playlist." -ForegroundColor Red
            Write-Host "💡 This feature requires Spotify Premium." -ForegroundColor Yellow
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while processing the playlist: $errorMessage" -ForegroundColor Red
        }
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
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not get liked songs." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while retrieving liked songs: $errorMessage" -ForegroundColor Red
        }
    }
}
function recent {
    <#
    .SYNOPSIS
    Show recently played tracks or play a specific recent track
    .PARAMETER TrackNumber
    Track number to play immediately (1-20)
    .EXAMPLE
    recent
    Show recently played tracks
    .EXAMPLE
    recent 1
    Play the most recently played track
    .EXAMPLE
    recent 3
    Play the 3rd most recently played track
    #>
    param([int]$TrackNumber = 0)

    try {
        $recentResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/recently-played" -Query @{ limit = 20 }
        if (-not $recentResponse -or -not $recentResponse.items) {
            Write-Host "No recent tracks found" -ForegroundColor Yellow
            return
        }

        # If a track number is specified, play it directly
        if ($TrackNumber -gt 0) {
            if ($TrackNumber -gt $recentResponse.items.Count) {
                Write-Host "❌ Invalid track number. Only $($recentResponse.items.Count) recent tracks available." -ForegroundColor Red
                return
            }

            $selectedItem = $recentResponse.items[$TrackNumber - 1]
            $uri = $null
            $name = ""

            if ($selectedItem.track) {
                $uri = $selectedItem.track.uri
                $name = $selectedItem.track.name
                $artists = ($selectedItem.track.artists | ForEach-Object { $_.name }) -join ", "
                Write-Host "▶️ Playing recent track #$TrackNumber`: $name by $artists" -ForegroundColor Green
            } elseif ($selectedItem.episode) {
                $uri = $selectedItem.episode.uri
                $name = $selectedItem.episode.name
                Write-Host "▶️ Playing recent episode #$TrackNumber`: $name" -ForegroundColor Magenta
            }

            if ($uri) {
                $body = @{ uris = @($uri) }
                Invoke-SpotifyApi -Method PUT -Path "/me/player/play" -Body $body
            }
            return
        }

        # Otherwise, show the list
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
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not get recently played songs." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while retrieving recently played songs: $errorMessage" -ForegroundColor Red
        }
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
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not save item." -ForegroundColor Red
            Write-Host "💡 Make sure a track is playing or the item ID is valid." -ForegroundColor Yellow
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while saving the item: $errorMessage" -ForegroundColor Red
        }
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
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.psm1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not remove item from library." -ForegroundColor Red
            Write-Host "💡 Make sure a track is playing or the item ID is valid." -ForegroundColor Yellow
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while removing the item: $errorMessage" -ForegroundColor Red
        }
    }
}