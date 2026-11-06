# Spotify Insights Module
# Fun listening insights in the terminal: today's listening and an artist card.
# Uses only endpoints available to standard apps (no audio-features / recommendations).

function Write-InsightRow([string]$Label, [string]$Text, [string]$Color = 'White') {
    Write-Host ("  {0,-12} " -f $Label) -ForegroundColor DarkGray -NoNewline
    Write-Host $Text -ForegroundColor $Color
}

function Format-InsightNumber([long]$n) {
    if ($n -ge 1000000) { return "{0:N1}M" -f ($n / 1000000) }
    if ($n -ge 1000) { return "{0:N1}K" -f ($n / 1000) }
    return $n.ToString('N0')
}

function ConvertTo-LocalTime($value) {
    # Invoke-RestMethod may return played_at as a UTC DateTime or as an ISO string
    if ($value -is [datetime]) {
        if ($value.Kind -eq [DateTimeKind]::Local) { return $value }
        return [DateTime]::SpecifyKind($value, [DateTimeKind]::Utc).ToLocalTime()
    }
    return [DateTimeOffset]::Parse([string]$value, [Globalization.CultureInfo]::InvariantCulture).LocalDateTime
}

function Show-SpotifyToday {
    <#
    .SYNOPSIS
    Show what you have listened to today (time, tracks, top artist, most played, listening by hour)
    .DESCRIPTION
    Based on Spotify's recently played history, which only returns the last 50 tracks.
    On heavy listening days the oldest plays of the day may therefore be missing.
    .EXAMPLE
    today
    #>
    $response = Invoke-SpotifyApi -Method GET -Path '/me/player/recently-played' -Query @{ limit = 50 }
    $all = @($response.items | Where-Object { $_.track })
    $today = (Get-Date).Date
    $plays = @($all | ForEach-Object {
        [PSCustomObject]@{ Track = $_.track; PlayedAt = ConvertTo-LocalTime $_.played_at }
    } | Where-Object { $_.PlayedAt.Date -eq $today })

    Write-Host ''
    Write-Host "  TODAY - $((Get-Date).ToString('dddd d MMMM'))" -ForegroundColor Cyan
    Write-Host ''
    if (-not $plays.Count) {
        Write-Host '  Nothing played yet today.' -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    $totalMs = ($plays | ForEach-Object { [long]$_.Track.duration_ms } | Measure-Object -Sum).Sum
    $time = [TimeSpan]::FromMilliseconds($totalMs)
    $timeText = if ($time.TotalHours -ge 1) { '{0} h {1} min' -f [int][Math]::Floor($time.TotalHours), $time.Minutes } else { '{0} min' -f [int][Math]::Round($time.TotalMinutes) }
    $artists = @($plays | ForEach-Object { $_.Track.artists[0].name })
    $artistCount = @($artists | Sort-Object -Unique).Count
    $more = if ($plays.Count -eq $all.Count -and $all.Count -ge 50) { '+' } else { '' }

    Write-InsightRow 'Listened' "$timeText  |  $($plays.Count)$more tracks  |  $artistCount artists" 'White'

    $topArtist = $artists | Group-Object | Sort-Object Count -Descending | Select-Object -First 1
    Write-InsightRow 'Top artist' "$($topArtist.Name) ($($topArtist.Count) tracks)" 'Green'

    $topTrack = $plays | Group-Object { $_.Track.id } | Sort-Object Count -Descending | Select-Object -First 1
    $topTrackItem = $topTrack.Group[0].Track
    $timesText = if ($topTrack.Count -gt 1) { "$($topTrack.Count)x" } else { 'once each' }
    Write-InsightRow 'Most played' "$($topTrackItem.name) - $($topTrackItem.artists[0].name) ($timesText)" 'Yellow'

    $first = ($plays | Sort-Object PlayedAt | Select-Object -First 1).PlayedAt
    Write-InsightRow 'First play' $first.ToString('HH:mm') 'Gray'

    # Plays per hour as a 24-character sparkline
    $perHour = [int[]]::new(24)
    foreach ($p in $plays) { $perHour[$p.PlayedAt.Hour]++ }
    $max = ($perHour | Measure-Object -Maximum).Maximum
    $blocks = 0x2581..0x2588 | ForEach-Object { [char]$_ }
    $line = -join ($perHour | ForEach-Object { if ($_ -eq 0) { [char]0x00B7 } else { $blocks[[Math]::Min(7, [int][Math]::Ceiling($_ / $max * 8) - 1)] } })
    Write-Host ''
    Write-InsightRow 'By hour' $line 'Cyan'
    Write-InsightRow '' '0     6     12    18    23' 'DarkGray'
    if ($more) {
        Write-Host ''
        Write-Host '  Spotify only returns the last 50 plays, so earlier plays today are not counted.' -ForegroundColor DarkGray
    }
    Write-Host ''
}

function Show-SpotifyArtist {
    <#
    .SYNOPSIS
    Artist card: followers, popularity, genres, top 5 tracks, latest release and discography
    .PARAMETER Name
    Artist to look up. Default: the artist of the track that is playing now.
    .PARAMETER Play
    Play the artist's top track number N (1-10) instead of only showing the card.
    .EXAMPLE
    artist
    .EXAMPLE
    artist "Gracie Abrams"
    .EXAMPLE
    artist -Play 1
    #>
    param([string]$Name, [int]$Play = 0)

    $artistId = $null
    if ($Name) {
        $found = Invoke-SpotifyApi -Method GET -Path '/search' -Query @{ q = $Name; type = 'artist'; limit = 1 }
        $artistId = @($found.artists.items)[0].id
        if (-not $artistId) { Write-Host "No artist found for '$Name'" -ForegroundColor Yellow; return }
    } else {
        $playback = Invoke-SpotifyApi -Method GET -Path '/me/player'
        if (-not $playback -or -not $playback.item -or -not $playback.item.artists) {
            Write-Host "Nothing playing. Use: artist <name>" -ForegroundColor Yellow
            return
        }
        $artistId = $playback.item.artists[0].id
    }

    $artist = Invoke-SpotifyApi -Method GET -Path "/artists/$artistId"
    $topTracks = @((Invoke-SpotifyApi -Method GET -Path "/artists/$artistId/top-tracks" -Query @{ market = 'from_token' }).tracks)

    if ($Play -gt 0) {
        if ($Play -gt $topTracks.Count) { Write-Host "Only $($topTracks.Count) top tracks available." -ForegroundColor Yellow; return }
        $track = $topTracks[$Play - 1]
        # Play inside the album: Spotify can silently ignore a bare single-track request
        $body = @{ context_uri = $track.album.uri; offset = @{ uri = $track.uri } }
        Invoke-SpotifyApi -Method PUT -Path '/me/player/play' -Body $body | Out-Null
        Write-Host "▶️ Playing $($artist.name)'s #$Play`: $($track.name)" -ForegroundColor Green
        return
    }

    $releases = @((Invoke-SpotifyApi -Method GET -Path "/artists/$artistId/albums" -Query @{ include_groups = 'album,single'; limit = 50 }).items)
    $albums = @($releases | Where-Object { $_.album_type -eq 'album' })
    $singles = @($releases | Where-Object { $_.album_type -eq 'single' })
    $latest = $releases | Sort-Object { [string]$_.release_date } -Descending | Select-Object -First 1

    Write-Host ''
    Write-Host "  $($artist.name)" -ForegroundColor Cyan
    Write-Host ''
    $width = 30
    $pop = [int]$artist.popularity
    $filled = [int][Math]::Round($pop / 100 * $width)
    Write-Host ("  {0,-12} " -f 'Popularity') -ForegroundColor DarkGray -NoNewline
    Write-Host ([string][char]0x2588 * $filled) -ForegroundColor Cyan -NoNewline
    Write-Host ([string][char]0x2591 * ($width - $filled)) -ForegroundColor DarkGray -NoNewline
    Write-Host ("  {0,3}/100" -f $pop) -ForegroundColor White
    Write-InsightRow 'Followers' (Format-InsightNumber ([long]$artist.followers.total)) 'Yellow'
    Write-InsightRow 'Genres' $(if (@($artist.genres).Count) { (@($artist.genres) | Select-Object -First 4) -join ', ' } else { 'n/a' }) 'Cyan'

    Write-Host ''
    Write-Host '  TOP TRACKS' -ForegroundColor Yellow
    $i = 0
    foreach ($t in ($topTracks | Select-Object -First 5)) {
        $i++
        Write-Host ("    {0}. {1,-36}" -f $i, $(if ($t.name.Length -gt 36) { $t.name.Substring(0, 35) + [char]0x2026 } else { $t.name })) -ForegroundColor White -NoNewline
        Write-Host ("pop {0,3}" -f $t.popularity) -ForegroundColor DarkGray
    }

    Write-Host ''
    if ($latest) {
        Write-InsightRow 'Latest' "$($latest.name) ($($latest.album_type), $($latest.release_date))" 'Green'
    }
    $count = "$($albums.Count) albums  |  $($singles.Count) singles"
    if ($releases.Count -ge 50) { $count += '  (50+ releases)' }
    Write-InsightRow 'Releases' $count 'Gray'
    Write-Host ''
    Write-Host "  artist -Play <n> plays a top track" -ForegroundColor DarkGray
    Write-Host ''
}

Set-Alias -Name today -Value Show-SpotifyToday -ErrorAction SilentlyContinue
Set-Alias -Name artist -Value Show-SpotifyArtist -ErrorAction SilentlyContinue

Export-ModuleMember -Function @('Show-SpotifyToday', 'Show-SpotifyArtist') -Alias @('today', 'artist')
