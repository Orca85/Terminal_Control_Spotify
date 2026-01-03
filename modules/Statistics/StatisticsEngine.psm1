# Statistics Engine Module
# Provides listening data collection, analysis, and visualization for Spotify CLI

using namespace System.Management.Automation

# Data models for statistics
class PlaybackEvent {
    [string] $TrackId
    [string] $TrackName
    [string] $ArtistName
    [string] $AlbumName
    [string[]] $Genres
    [DateTime] $Timestamp
    [int] $DurationMs
    [int] $PositionMs
    [string] $EventType  # "play", "skip", "complete"
    [string] $DeviceType
    [bool] $IsExplicit
    
    PlaybackEvent([hashtable]$data) {
        $this.TrackId = $data.TrackId
        $this.TrackName = $data.TrackName
        $this.ArtistName = $data.ArtistName
        $this.AlbumName = $data.AlbumName
        $this.Genres = $data.Genres
        $this.Timestamp = $data.Timestamp
        $this.DurationMs = $data.DurationMs
        $this.PositionMs = $data.PositionMs
        $this.EventType = $data.EventType
        $this.DeviceType = $data.DeviceType
        $this.IsExplicit = $data.IsExplicit
    }
}

class ListeningStats {
    [hashtable] $TopTracks = @{}
    [hashtable] $TopArtists = @{}
    [hashtable] $TopAlbums = @{}
    [hashtable] $GenreDistribution = @{}
    [hashtable] $DailyPatterns = @{}
    [hashtable] $WeeklyPatterns = @{}
    [int] $TotalPlaytime = 0
    [int] $CurrentStreak = 0
    [DateTime] $PeriodStart
    [DateTime] $PeriodEnd
    [int] $TotalTracks = 0
    [int] $UniqueArtists = 0
    [int] $UniqueAlbums = 0
    
    ListeningStats([DateTime]$start, [DateTime]$end) {
        $this.PeriodStart = $start
        $this.PeriodEnd = $end
    }
}

# Data collector for tracking playback events
class DataCollector {
    [string] $DataDirectory
    [string] $DatabaseFile
    [int] $MaxRetentionDays = 365
    [bool] $IsEnabled = $true
    
    DataCollector([string]$dataDir) {
        $this.DataDirectory = $dataDir
        $this.DatabaseFile = Join-Path $dataDir "playback_history.json"
        $this.EnsureDataDirectory()
    }
    
    [void] EnsureDataDirectory() {
        if (-not (Test-Path $this.DataDirectory)) {
            New-Item -ItemType Directory -Path $this.DataDirectory -Force | Out-Null
        }
        return
    }
    
    [void] RecordPlayback([hashtable]$trackData, [DateTime]$timestamp) {
        if (-not $this.IsEnabled) {
            return
        }
        
        try {
            $event = [PlaybackEvent]::new(@{
                TrackId = $trackData.id
                TrackName = $trackData.name
                ArtistName = ($trackData.artists | ForEach-Object { $_.name }) -join ", "
                AlbumName = $trackData.album.name
                Genres = $trackData.genres ?? @()
                Timestamp = $timestamp
                DurationMs = $trackData.duration_ms
                PositionMs = $trackData.progress_ms ?? 0
                EventType = "play"
                DeviceType = $trackData.device_type ?? "unknown"
                IsExplicit = $trackData.explicit ?? $false
            })
            
            $this.SaveEvent($event)
        } catch {
            Write-Warning "Failed to record playback event: $($_.Exception.Message)"
        }
    }
    
    [void] RecordSkip([string]$trackId, [int]$positionMs) {
        if (-not $this.IsEnabled) {
            return
        }
        
        try {
            # Load recent events to get track details
            $recentEvents = $this.GetRecentEvents(1)
            if ($recentEvents.Count -gt 0 -and $recentEvents[0].TrackId -eq $trackId) {
                $lastEvent = $recentEvents[0]
                $event = [PlaybackEvent]::new(@{
                    TrackId = $lastEvent.TrackId
                    TrackName = $lastEvent.TrackName
                    ArtistName = $lastEvent.ArtistName
                    AlbumName = $lastEvent.AlbumName
                    Genres = $lastEvent.Genres
                    Timestamp = [DateTime]::UtcNow
                    DurationMs = $lastEvent.DurationMs
                    PositionMs = $positionMs
                    EventType = "skip"
                    DeviceType = $lastEvent.DeviceType
                    IsExplicit = $lastEvent.IsExplicit
                })
                
                $this.SaveEvent($event)
            }
        } catch {
            Write-Warning "Failed to record skip event: $($_.Exception.Message)"
        }
    }
    
    [void] SaveEvent([PlaybackEvent]$event) {
        try {
            # Use file locking to prevent concurrent access issues
            $lockFile = "$($this.DatabaseFile).lock"
            $maxWaitTime = 5000  # 5 seconds
            $waitTime = 0
            $waitIncrement = 100
            
            # Wait for lock to be released
            while ((Test-Path $lockFile) -and $waitTime -lt $maxWaitTime) {
                Start-Sleep -Milliseconds $waitIncrement
                $waitTime += $waitIncrement
            }
            
            # Create lock file
            New-Item -Path $lockFile -ItemType File -Force | Out-Null
            
            try {
                $events = $this.LoadEvents()
                $events += $event
                
                # Keep only events within retention period
                $cutoffDate = [DateTime]::UtcNow.AddDays(-$this.MaxRetentionDays)
                $events = $events | Where-Object { $_.Timestamp -gt $cutoffDate }
                
                # Optimize: Only save if we have events to save
                if ($events.Count -gt 0) {
                    $json = $events | ConvertTo-Json -Depth 10 -Compress
                    Set-Content -Path $this.DatabaseFile -Value $json -Encoding UTF8
                }
            } finally {
                # Always remove lock file
                if (Test-Path $lockFile) {
                    Remove-Item -Path $lockFile -Force -ErrorAction SilentlyContinue
                }
            }
        } catch {
            Write-Warning "Failed to save playback event: $($_.Exception.Message)"
        }
    }
    
    [PlaybackEvent[]] LoadEvents() {
        try {
            if (-not (Test-Path $this.DatabaseFile)) {
                return @()
            }
            
            # Check for lock file and wait briefly
            $lockFile = "$($this.DatabaseFile).lock"
            $maxWaitTime = 2000  # 2 seconds for read operations
            $waitTime = 0
            $waitIncrement = 50
            
            while ((Test-Path $lockFile) -and $waitTime -lt $maxWaitTime) {
                Start-Sleep -Milliseconds $waitIncrement
                $waitTime += $waitIncrement
            }
            
            $json = Get-Content -Path $this.DatabaseFile -Raw -Encoding UTF8
            if ([string]::IsNullOrWhiteSpace($json)) {
                return @()
            }
            
            $data = $json | ConvertFrom-Json
            $events = @()
            
            foreach ($item in $data) {
                try {
                    $eventData = @{}
                    $item.PSObject.Properties | ForEach-Object {
                        $eventData[$_.Name] = $_.Value
                    }
                    # Convert timestamp string back to DateTime if needed
                    if ($eventData.Timestamp -is [string]) {
                        $eventData.Timestamp = [DateTime]::Parse($eventData.Timestamp)
                    }
                    $events += [PlaybackEvent]::new($eventData)
                } catch {
                    Write-Warning "Failed to parse event data: $($_.Exception.Message)"
                    continue
                }
            }
            
            return $events
        } catch {
            Write-Warning "Failed to load playback events: $($_.Exception.Message)"
            return @()
        }
    }
    
    [PlaybackEvent[]] GetPlaybackHistory([DateTime]$startDate, [DateTime]$endDate) {
        $allEvents = $this.LoadEvents()
        return $allEvents | Where-Object { 
            $_.Timestamp -ge $startDate -and $_.Timestamp -le $endDate 
        }
    }
    
    [PlaybackEvent[]] GetRecentEvents([int]$count) {
        $allEvents = $this.LoadEvents()
        return $allEvents | Sort-Object Timestamp -Descending | Select-Object -First $count
    }
    
    [void] ClearHistory() {
        try {
            if (Test-Path $this.DatabaseFile) {
                Remove-Item -Path $this.DatabaseFile -Force
            }
        } catch {
            Write-Warning "Failed to clear history: $($_.Exception.Message)"
        }
        return
    }
    
    [void] RecordPlaybackAsync([hashtable]$trackData, [DateTime]$timestamp) {
        if (-not $this.IsEnabled) {
            return
        }
        
        # Use background job for non-blocking data collection
        $scriptBlock = {
            param($DataCollector, $TrackData, $Timestamp)
            try {
                $DataCollector.RecordPlayback($TrackData, $Timestamp)
            } catch {
                # Silently handle errors in background to avoid disrupting user experience
            }
        }
        
        Start-Job -ScriptBlock $scriptBlock -ArgumentList $this, $trackData, $timestamp | Out-Null
        
        # Clean up completed jobs to prevent memory leaks
        Get-Job | Where-Object { $_.State -eq 'Completed' } | Remove-Job
    }
    
    [hashtable] GetStorageStats() {
        try {
            $events = $this.LoadEvents()
            $fileSize = 0
            
            if (Test-Path $this.DatabaseFile) {
                $fileInfo = Get-Item $this.DatabaseFile
                $fileSize = $fileInfo.Length
            }
            
            return @{
                TotalEvents = $events.Count
                FileSizeMB = [Math]::Round($fileSize / 1MB, 2)
                OldestEvent = ($events | Sort-Object Timestamp | Select-Object -First 1)?.Timestamp
                NewestEvent = ($events | Sort-Object Timestamp -Descending | Select-Object -First 1)?.Timestamp
                RetentionDays = $this.MaxRetentionDays
                DatabaseFile = $this.DatabaseFile
                IsEnabled = $this.IsEnabled
            }
        } catch {
            return @{
                TotalEvents = 0
                FileSizeMB = 0
                Error = $_.Exception.Message
                IsEnabled = $this.IsEnabled
            }
        }
    }
}

# Analytics processor for calculating statistics
class AnalyticsProcessor {
    [DataCollector] $DataCollector
    
    AnalyticsProcessor([DataCollector]$collector) {
        $this.DataCollector = $collector
    }
    
    [hashtable] GetTopTracks([string]$period, [int]$limit) {
        $dateRange = $this.GetDateRange($period)
        $events = $this.DataCollector.GetPlaybackHistory($dateRange.Start, $dateRange.End)
        
        # Group by track and count plays
        $trackCounts = @{}
        foreach ($event in $events) {
            if ($event.EventType -eq "play") {
                $key = "$($event.TrackName) - $($event.ArtistName)"
                if (-not $trackCounts.ContainsKey($key)) {
                    $trackCounts[$key] = @{
                        Name = $event.TrackName
                        Artist = $event.ArtistName
                        Album = $event.AlbumName
                        PlayCount = 0
                        TotalPlaytime = 0
                    }
                }
                $trackCounts[$key].PlayCount++
                $trackCounts[$key].TotalPlaytime += $event.DurationMs
            }
        }
        
        # Sort by play count and take top N
        $topTracks = $trackCounts.Values | Sort-Object PlayCount -Descending | Select-Object -First $limit
        
        return @{
            Period = $period
            Tracks = $topTracks
            TotalTracks = $trackCounts.Count
        }
    }
    
    [hashtable] GetTopArtists([string]$period, [int]$limit) {
        $dateRange = $this.GetDateRange($period)
        $events = $this.DataCollector.GetPlaybackHistory($dateRange.Start, $dateRange.End)
        
        # Group by artist and count plays
        $artistCounts = @{}
        foreach ($event in $events) {
            if ($event.EventType -eq "play") {
                $artist = $event.ArtistName
                if (-not $artistCounts.ContainsKey($artist)) {
                    $artistCounts[$artist] = @{
                        Name = $artist
                        PlayCount = 0
                        TotalPlaytime = 0
                        UniqueAlbums = [System.Collections.Generic.HashSet[string]]::new()
                        UniqueTracks = [System.Collections.Generic.HashSet[string]]::new()
                    }
                }
                $artistCounts[$artist].PlayCount++
                $artistCounts[$artist].TotalPlaytime += $event.DurationMs
                $artistCounts[$artist].UniqueAlbums.Add($event.AlbumName) | Out-Null
                $artistCounts[$artist].UniqueTracks.Add($event.TrackName) | Out-Null
            }
        }
        
        # Convert HashSets to counts and sort
        $topArtists = $artistCounts.Values | ForEach-Object {
            @{
                Name = $_.Name
                PlayCount = $_.PlayCount
                TotalPlaytime = $_.TotalPlaytime
                UniqueAlbums = $_.UniqueAlbums.Count
                UniqueTracks = $_.UniqueTracks.Count
            }
        } | Sort-Object PlayCount -Descending | Select-Object -First $limit
        
        return @{
            Period = $period
            Artists = $topArtists
            TotalArtists = $artistCounts.Count
        }
    }
    
    [hashtable] GetGenreDistribution([string]$period) {
        $dateRange = $this.GetDateRange($period)
        $events = $this.DataCollector.GetPlaybackHistory($dateRange.Start, $dateRange.End)
        
        # Count genre occurrences and track playtime
        $genreCounts = @{}
        $genrePlaytime = @{}
        
        foreach ($event in $events) {
            if ($event.EventType -eq "play" -and $event.Genres) {
                foreach ($genre in $event.Genres) {
                    if (-not $genreCounts.ContainsKey($genre)) {
                        $genreCounts[$genre] = 0
                        $genrePlaytime[$genre] = 0
                    }
                    $genreCounts[$genre]++
                    $genrePlaytime[$genre] += $event.DurationMs
                }
            }
        }
        
        # Calculate percentages and rankings
        $totalGenreCount = ($genreCounts.Values | Measure-Object -Sum).Sum
        $totalPlaytime = ($genrePlaytime.Values | Measure-Object -Sum).Sum
        $distribution = @{}
        
        foreach ($genre in $genreCounts.Keys) {
            $countPercentage = if ($totalGenreCount -gt 0) { 
                [Math]::Round(($genreCounts[$genre] / $totalGenreCount) * 100, 1) 
            } else { 0 }
            
            $playtimePercentage = if ($totalPlaytime -gt 0) {
                [Math]::Round(($genrePlaytime[$genre] / $totalPlaytime) * 100, 1)
            } else { 0 }
            
            $distribution[$genre] = @{
                Count = $genreCounts[$genre]
                CountPercentage = $countPercentage
                PlaytimeMs = $genrePlaytime[$genre]
                PlaytimePercentage = $playtimePercentage
                PlaytimeHours = [Math]::Round($genrePlaytime[$genre] / (1000 * 60 * 60), 1)
            }
        }
        
        # Find dominant genre
        $dominantGenre = $null
        $maxPercentage = 0
        foreach ($genre in $distribution.Keys) {
            if ($distribution[$genre].CountPercentage -gt $maxPercentage) {
                $maxPercentage = $distribution[$genre].CountPercentage
                $dominantGenre = $genre
            }
        }
        
        return @{
            Period = $period
            Distribution = $distribution
            TotalGenres = $genreCounts.Count
            TotalPlays = $totalGenreCount
            TotalPlaytimeMs = $totalPlaytime
            DominantGenre = $dominantGenre
            DominantGenrePercentage = $maxPercentage
        }
    }
    
    [hashtable] GetListeningPatterns([string]$period) {
        $dateRange = $this.GetDateRange($period)
        $events = $this.DataCollector.GetPlaybackHistory($dateRange.Start, $dateRange.End)
        
        # Analyze daily patterns (by hour)
        $hourlyPattern = @{}
        for ($i = 0; $i -lt 24; $i++) {
            $hourlyPattern[$i] = 0
        }
        
        # Analyze weekly patterns (by day)
        $weeklyPattern = @{}
        for ($i = 0; $i -lt 7; $i++) {
            $weeklyPattern[$i] = 0
        }
        
        # Track daily listening sessions
        $dailySessions = @{}
        $peakHours = @{}
        
        foreach ($event in $events) {
            if ($event.EventType -eq "play") {
                $hour = $event.Timestamp.Hour
                $dayOfWeek = [int]$event.Timestamp.DayOfWeek
                $dateKey = $event.Timestamp.Date.ToString("yyyy-MM-dd")
                
                $hourlyPattern[$hour]++
                $weeklyPattern[$dayOfWeek]++
                
                # Track daily sessions
                if (-not $dailySessions.ContainsKey($dateKey)) {
                    $dailySessions[$dateKey] = @{
                        TrackCount = 0
                        TotalPlaytime = 0
                        FirstPlay = $event.Timestamp
                        LastPlay = $event.Timestamp
                        UniqueArtists = [System.Collections.Generic.HashSet[string]]::new()
                    }
                }
                
                $dailySessions[$dateKey].TrackCount++
                $dailySessions[$dateKey].TotalPlaytime += $event.DurationMs
                $dailySessions[$dateKey].UniqueArtists.Add($event.ArtistName) | Out-Null
                
                if ($event.Timestamp -lt $dailySessions[$dateKey].FirstPlay) {
                    $dailySessions[$dateKey].FirstPlay = $event.Timestamp
                }
                if ($event.Timestamp -gt $dailySessions[$dateKey].LastPlay) {
                    $dailySessions[$dateKey].LastPlay = $event.Timestamp
                }
            }
        }
        
        # Calculate peak listening hours
        $sortedHours = $hourlyPattern.GetEnumerator() | Sort-Object Value -Descending
        $peakHour = if ($sortedHours.Count -gt 0) { $sortedHours[0].Key } else { -1 }
        
        # Calculate average session length
        $avgSessionLength = 0
        if ($dailySessions.Count -gt 0) {
            $totalSessionTime = 0
            foreach ($session in $dailySessions.Values) {
                $sessionDuration = ($session.LastPlay - $session.FirstPlay).TotalMinutes
                $totalSessionTime += $sessionDuration
            }
            $avgSessionLength = [Math]::Round($totalSessionTime / $dailySessions.Count, 1)
        }
        
        return @{
            Period = $period
            HourlyPattern = $hourlyPattern
            WeeklyPattern = $weeklyPattern
            DailySessions = $dailySessions
            PeakListeningHour = $peakHour
            AverageSessionLength = $avgSessionLength
            TotalEvents = $events.Count
            ActiveDays = $dailySessions.Count
        }
    }
    
    [hashtable] GetDateRange([string]$period) {
        $now = [DateTime]::UtcNow
        
        switch ($period.ToLower()) {
            "day" { 
                return @{ Start = $now.AddDays(-1); End = $now }
            }
            "week" { 
                return @{ Start = $now.AddDays(-7); End = $now }
            }
            "month" { 
                return @{ Start = $now.AddDays(-30); End = $now }
            }
            "year" { 
                return @{ Start = $now.AddDays(-365); End = $now }
            }
            default { 
                return @{ Start = $now.AddDays(-30); End = $now }
            }
        }
    }
    
    [hashtable] CalculateListeningStreaks() {
        # Get all events sorted by date
        $allEvents = $this.DataCollector.LoadEvents() | Where-Object { $_.EventType -eq "play" }
        $eventsByDate = $allEvents | Group-Object { $_.Timestamp.Date.ToString("yyyy-MM-dd") } | Sort-Object Name
        
        if ($eventsByDate.Count -eq 0) {
            return @{
                CurrentStreak = 0
                LongestStreak = 0
                StreakStartDate = $null
                StreakEndDate = $null
                TotalActiveDays = 0
            }
        }
        
        $currentStreak = 0
        $longestStreak = 0
        $currentStreakStart = $null
        $longestStreakStart = $null
        $longestStreakEnd = $null
        $lastDate = $null
        
        foreach ($dateGroup in $eventsByDate) {
            $currentDate = [DateTime]::Parse($dateGroup.Name)
            
            if ($lastDate -eq $null) {
                # First date
                $currentStreak = 1
                $currentStreakStart = $currentDate
            } elseif (($currentDate - $lastDate).Days -eq 1) {
                # Consecutive day
                $currentStreak++
            } else {
                # Streak broken
                if ($currentStreak -gt $longestStreak) {
                    $longestStreak = $currentStreak
                    $longestStreakStart = $currentStreakStart
                    $longestStreakEnd = $lastDate
                }
                $currentStreak = 1
                $currentStreakStart = $currentDate
            }
            
            $lastDate = $currentDate
        }
        
        # Check if current streak is the longest
        if ($currentStreak -gt $longestStreak) {
            $longestStreak = $currentStreak
            $longestStreakStart = $currentStreakStart
            $longestStreakEnd = $lastDate
        }
        
        # Check if current streak is still active (today or yesterday)
        $today = [DateTime]::Today
        $isCurrentStreakActive = $lastDate -ne $null -and ($today - $lastDate).Days -le 1
        
        return @{
            CurrentStreak = if ($isCurrentStreakActive) { $currentStreak } else { 0 }
            LongestStreak = $longestStreak
            StreakStartDate = $longestStreakStart
            StreakEndDate = $longestStreakEnd
            TotalActiveDays = $eventsByDate.Count
            IsStreakActive = $isCurrentStreakActive
        }
    }
    
    [ListeningStats] GenerateComprehensiveStats([string]$period) {
        $dateRange = $this.GetDateRange($period)
        $stats = [ListeningStats]::new($dateRange.Start, $dateRange.End)
        
        # Get all data
        $topTracks = $this.GetTopTracks($period, 10)
        $topArtists = $this.GetTopArtists($period, 10)
        $genreDistribution = $this.GetGenreDistribution($period)
        $patterns = $this.GetListeningPatterns($period)
        $streaks = $this.CalculateListeningStreaks()
        
        # Populate stats object
        $stats.TopTracks = $topTracks
        $stats.TopArtists = $topArtists
        $stats.GenreDistribution = $genreDistribution
        $stats.DailyPatterns = $patterns.HourlyPattern
        $stats.WeeklyPatterns = $patterns.WeeklyPattern
        $stats.CurrentStreak = $streaks.CurrentStreak
        
        # Calculate totals
        $events = $this.DataCollector.GetPlaybackHistory($dateRange.Start, $dateRange.End)
        $playEvents = $events | Where-Object { $_.EventType -eq "play" }
        
        $stats.TotalPlaytime = ($playEvents | Measure-Object -Property DurationMs -Sum).Sum
        $stats.TotalTracks = $playEvents.Count
        $stats.UniqueArtists = ($playEvents | Select-Object -Property ArtistName -Unique).Count
        $stats.UniqueAlbums = ($playEvents | Select-Object -Property AlbumName -Unique).Count
        
        return $stats
    }
}

# ASCII visualization generator
class VisualizationGenerator {
    [string] GenerateBarChart([hashtable]$data, [string]$title, [int]$width = 50) {
        $output = @()
        $output += $title
        $output += "=" * $title.Length
        $output += ""
        
        if ($data.Count -eq 0) {
            $output += "No data available"
            return $output -join "`n"
        }
        
        # Find max value for scaling
        $maxValue = ($data.Values | Measure-Object -Maximum).Maximum
        if ($maxValue -eq 0) {
            $output += "No data to display"
            return $output -join "`n"
        }
        
        # Generate bars
        foreach ($key in ($data.Keys | Sort-Object { $data[$_] } -Descending)) {
            $value = $data[$key]
            $barLength = [Math]::Round(($value / $maxValue) * $width)
            $bar = "█" * $barLength
            $output += "$key : $bar $value"
        }
        
        return $output -join "`n"
    }
    
    [string] GeneratePieChart([hashtable]$data, [string]$title) {
        $output = @()
        $output += $title
        $output += "=" * $title.Length
        $output += ""
        
        if ($data.Count -eq 0) {
            $output += "No data available"
            return $output -join "`n"
        }
        
        # Calculate total and percentages
        $total = ($data.Values | Measure-Object -Sum).Sum
        if ($total -eq 0) {
            $output += "No data to display"
            return $output -join "`n"
        }
        
        # ASCII pie chart using different characters
        $pieChars = @("█", "▓", "▒", "░", "▄", "▀", "▌", "▐", "■", "□", "●", "○", "◆", "◇", "▲", "△")
        $charIndex = 0
        
        # Create legend and visual representation
        $sortedData = $data.GetEnumerator() | Sort-Object Value -Descending
        
        foreach ($item in $sortedData) {
            $percentage = [Math]::Round(($item.Value / $total) * 100, 1)
            $char = $pieChars[$charIndex % $pieChars.Length]
            $barLength = [Math]::Round($percentage / 2)  # Scale down for display
            $bar = $char * $barLength
            
            $output += "$($item.Key.PadRight(20)) $bar $($percentage)% ($($item.Value))"
            $charIndex++
        }
        
        $output += ""
        $output += "Total: $total items"
        
        return $output -join "`n"
    }
    
    [string] GenerateTimelineVisualization([hashtable]$dailySessions, [string]$title) {
        $output = @()
        $output += $title
        $output += "=" * $title.Length
        $output += ""
        
        if ($dailySessions.Count -eq 0) {
            $output += "No timeline data available"
            return $output -join "`n"
        }
        
        # Sort dates and create timeline
        $sortedDates = $dailySessions.Keys | Sort-Object
        $maxTracks = ($dailySessions.Values | ForEach-Object { $_.TrackCount } | Measure-Object -Maximum).Maximum
        
        if ($maxTracks -eq 0) {
            $output += "No activity data to display"
            return $output -join "`n"
        }
        
        # Create timeline visualization
        foreach ($dateKey in $sortedDates) {
            $session = $dailySessions[$dateKey]
            $date = [DateTime]::Parse($dateKey)
            $intensity = [Math]::Round(($session.TrackCount / $maxTracks) * 10)
            
            # Create intensity bar
            $intensityBar = switch ($intensity) {
                { $_ -eq 0 } { "░" }
                { $_ -le 2 } { "▒" }
                { $_ -le 5 } { "▓" }
                { $_ -le 8 } { "█" }
                default { "█" }
            }
            
            $intensityDisplay = $intensityBar * [Math]::Max(1, $intensity)
            $dateDisplay = $date.ToString("MM/dd")
            $trackCount = $session.TrackCount
            $playtimeHours = [Math]::Round($session.TotalPlaytime / (1000 * 60 * 60), 1)
            
            $output += "$dateDisplay : $intensityDisplay $trackCount tracks ($playtimeHours h)"
        }
        
        $output += ""
        $output += "Legend: ░ Light ▒ Moderate ▓ Heavy █ Intense"
        
        return $output -join "`n"
    }
    
    [string] GenerateHourlyPattern([hashtable]$hourlyData) {
        $output = @()
        $output += "Listening Activity by Hour"
        $output += "=========================="
        $output += ""
        
        $maxValue = ($hourlyData.Values | Measure-Object -Maximum).Maximum
        if ($maxValue -eq 0) {
            $output += "No hourly data available"
            return $output -join "`n"
        }
        
        # Create a more detailed hourly visualization
        for ($hour = 0; $hour -lt 24; $hour++) {
            $value = $hourlyData[$hour]
            $barLength = [Math]::Round(($value / $maxValue) * 30)
            
            # Use different characters for different intensities
            $char = switch ($value) {
                { $_ -eq 0 } { "░" }
                { $_ -le ($maxValue * 0.25) } { "▒" }
                { $_ -le ($maxValue * 0.5) } { "▓" }
                default { "█" }
            }
            
            $bar = $char * $barLength
            $hourStr = "{0:D2}:00" -f $hour
            $percentage = if ($maxValue -gt 0) { [Math]::Round(($value / $maxValue) * 100, 1) } else { 0 }
            
            $output += "$hourStr : $bar $value ($percentage%)"
        }
        
        return $output -join "`n"
    }
    
    [string] GenerateWeeklyPattern([hashtable]$weeklyData) {
        $output = @()
        $output += "Listening Activity by Day"
        $output += "========================="
        $output += ""
        
        $dayNames = @("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
        $maxValue = ($weeklyData.Values | Measure-Object -Maximum).Maximum
        
        if ($maxValue -eq 0) {
            $output += "No weekly data available"
            return $output -join "`n"
        }
        
        for ($day = 0; $day -lt 7; $day++) {
            $value = $weeklyData[$day]
            $barLength = [Math]::Round(($value / $maxValue) * 30)
            
            # Use different characters for different intensities
            $char = switch ($value) {
                { $_ -eq 0 } { "░" }
                { $_ -le ($maxValue * 0.25) } { "▒" }
                { $_ -le ($maxValue * 0.5) } { "▓" }
                default { "█" }
            }
            
            $bar = $char * $barLength
            $dayName = $dayNames[$day].PadRight(9)
            $percentage = if ($maxValue -gt 0) { [Math]::Round(($value / $maxValue) * 100, 1) } else { 0 }
            
            $output += "$dayName : $bar $value ($percentage%)"
        }
        
        return $output -join "`n"
    }
    
    [string] GenerateTopItemsChart([array]$items, [string]$title, [string]$itemType) {
        $output = @()
        $output += $title
        $output += "=" * $title.Length
        $output += ""
        
        if ($items.Count -eq 0) {
            $output += "No $itemType data available"
            return $output -join "`n"
        }
        
        $maxValue = ($items | ForEach-Object { $_.PlayCount } | Measure-Object -Maximum).Maximum
        if ($maxValue -eq 0) {
            $output += "No play count data to display"
            return $output -join "`n"
        }
        
        for ($i = 0; $i -lt [Math]::Min(10, $items.Count); $i++) {
            $item = $items[$i]
            $rank = $i + 1
            $barLength = [Math]::Round(($item.PlayCount / $maxValue) * 40)
            $bar = "█" * $barLength
            
            $name = if ($itemType -eq "tracks") {
                "$($item.Name) - $($item.Artist)"
            } else {
                $item.Name
            }
            
            # Truncate long names
            if ($name.Length -gt 35) {
                $name = $name.Substring(0, 32) + "..."
            }
            
            $output += "$rank. $($name.PadRight(35)) $bar $($item.PlayCount)"
        }
        
        return $output -join "`n"
    }
    
    [string] GenerateStreakVisualization([hashtable]$streakData) {
        $output = @()
        $output += "Listening Streaks"
        $output += "================"
        $output += ""
        
        if ($streakData.TotalActiveDays -eq 0) {
            $output += "No listening activity recorded"
            return $output -join "`n"
        }
        
        $currentStreak = $streakData.CurrentStreak
        $longestStreak = $streakData.LongestStreak
        $isActive = $streakData.IsStreakActive
        
        # Current streak visualization
        $streakBar = "█" * [Math]::Min($currentStreak, 50)
        $streakStatus = if ($isActive) { "🔥 ACTIVE" } else { "💔 BROKEN" }
        
        $output += "Current Streak: $currentStreak days $streakStatus"
        $output += "[$streakBar]"
        $output += ""
        
        # Longest streak
        $longestBar = "▓" * [Math]::Min($longestStreak, 50)
        $output += "Longest Streak: $longestStreak days"
        $output += "[$longestBar]"
        
        if ($streakData.StreakStartDate -and $streakData.StreakEndDate) {
            $startDate = $streakData.StreakStartDate.ToString("MM/dd/yyyy")
            $endDate = $streakData.StreakEndDate.ToString("MM/dd/yyyy")
            $output += "Period: $startDate - $endDate"
        }
        
        $output += ""
        $output += "Total Active Days: $($streakData.TotalActiveDays)"
        
        return $output -join "`n"
    }
}

# Main statistics engine
class StatisticsEngine {
    [DataCollector] $DataCollector
    [AnalyticsProcessor] $AnalyticsProcessor
    [VisualizationGenerator] $VisualizationGenerator
    [hashtable] $Configuration
    
    StatisticsEngine([hashtable]$config) {
        $this.Configuration = $config
        
        # Initialize components
        $dataDir = $config.ContainsKey('DataDirectory') ? $config.DataDirectory : (Join-Path $env:APPDATA "SpotifyCLI\Statistics")
        $this.DataCollector = [DataCollector]::new($dataDir)
        $this.AnalyticsProcessor = [AnalyticsProcessor]::new($this.DataCollector)
        $this.VisualizationGenerator = [VisualizationGenerator]::new()
        
        # Configure data collector
        if ($config.ContainsKey('TrackingEnabled')) {
            $this.DataCollector.IsEnabled = $config.TrackingEnabled
        }
        if ($config.ContainsKey('RetentionDays')) {
            $this.DataCollector.MaxRetentionDays = $config.RetentionDays
        }
    }
    
    [void] RecordPlayback([hashtable]$trackData) {
        $this.DataCollector.RecordPlayback($trackData, [DateTime]::UtcNow)
        return
    }
    
    [void] RecordSkip([string]$trackId, [int]$positionMs) {
        $this.DataCollector.RecordSkip($trackId, $positionMs)
        return
    }
    
    [ListeningStats] GetStats([string]$period) {
        return $this.AnalyticsProcessor.GenerateComprehensiveStats($period)
    }
    
    [string] GenerateReport([string]$period) {
        $stats = $this.GetStats($period)
        $streaks = $this.AnalyticsProcessor.CalculateListeningStreaks()
        $output = @()
        
        $output += "Spotify Listening Statistics - $period"
        $output += "=" * 40
        $output += ""
        
        # Summary
        $totalHours = [Math]::Round($stats.TotalPlaytime / (1000 * 60 * 60), 1)
        $output += "Summary:"
        $output += "  Total listening time: $totalHours hours"
        $output += "  Total tracks played: $($stats.TotalTracks)"
        $output += "  Unique artists: $($stats.UniqueArtists)"
        $output += "  Unique albums: $($stats.UniqueAlbums)"
        $output += "  Current streak: $($stats.CurrentStreak) days"
        $output += ""
        
        # Streak visualization
        $output += $this.VisualizationGenerator.GenerateStreakVisualization($streaks)
        $output += ""
        
        # Top tracks
        if ($stats.TopTracks.Tracks.Count -gt 0) {
            $output += $this.VisualizationGenerator.GenerateTopItemsChart($stats.TopTracks.Tracks, "Top Tracks", "tracks")
            $output += ""
        }
        
        # Top artists
        if ($stats.TopArtists.Artists.Count -gt 0) {
            $output += $this.VisualizationGenerator.GenerateTopItemsChart($stats.TopArtists.Artists, "Top Artists", "artists")
            $output += ""
        }
        
        # Genre distribution
        if ($stats.GenreDistribution.Distribution.Count -gt 0) {
            $genreData = @{}
            foreach ($genre in $stats.GenreDistribution.Distribution.Keys) {
                $genreData[$genre] = $stats.GenreDistribution.Distribution[$genre].Count
            }
            $output += $this.VisualizationGenerator.GeneratePieChart($genreData, "Genre Distribution")
            $output += ""
        }
        
        # Listening patterns
        $output += $this.VisualizationGenerator.GenerateHourlyPattern($stats.DailyPatterns)
        $output += ""
        $output += $this.VisualizationGenerator.GenerateWeeklyPattern($stats.WeeklyPatterns)
        
        return $output -join "`n"
    }
    
    [hashtable] ExportStats([string]$format, [string]$period, [hashtable]$filters = @{}) {
        return $this.AnalyticsProcessor.ExportData($format, $period, $filters)
    }
    
    [hashtable] ExportRawData([DateTime]$startDate, [DateTime]$endDate, [string]$format) {
        return $this.AnalyticsProcessor.ExportRawData($startDate, $endDate, $format)
    }
    
    [hashtable] BackupData([string]$backupPath = $null) {
        if (-not $backupPath) {
            $backupPath = Join-Path (Split-Path $this.DataCollector.DataDirectory -Parent) "Backups"
        }
        return $this.AnalyticsProcessor.BackupData($backupPath)
    }
    
    [hashtable] RestoreData([string]$backupFile) {
        return $this.AnalyticsProcessor.RestoreData($backupFile)
    }
    
    [hashtable] ExportData([string]$format, [string]$period, [hashtable]$filters = @{}) {
        $stats = $this.GetStats($period)
        $timestamp = [DateTime]::Now.ToString("yyyyMMdd_HHmmss")
        
        switch ($format.ToLower()) {
            "json" {
                # Create comprehensive JSON export
                $exportData = @{
                    ExportInfo = @{
                        Timestamp = [DateTime]::UtcNow
                        Period = $period
                        Filters = $filters
                        Version = "1.0"
                    }
                    Summary = @{
                        TotalPlaytime = $stats.TotalPlaytime
                        TotalTracks = $stats.TotalTracks
                        UniqueArtists = $stats.UniqueArtists
                        UniqueAlbums = $stats.UniqueAlbums
                        CurrentStreak = $stats.CurrentStreak
                    }
                    TopTracks = $stats.TopTracks
                    TopArtists = $stats.TopArtists
                    GenreDistribution = $stats.GenreDistribution
                    ListeningPatterns = @{
                        HourlyPattern = $stats.DailyPatterns
                        WeeklyPattern = $stats.WeeklyPatterns
                    }
                }
                
                return @{
                    Format = "json"
                    Data = $exportData | ConvertTo-Json -Depth 10
                    FileName = "spotify_stats_${period}_${timestamp}.json"
                    Success = $true
                }
            }
            "csv" {
                # Create detailed CSV export with multiple sheets worth of data
                $csvData = @()
                
                # Export tracks
                foreach ($track in $stats.TopTracks.Tracks) {
                    $csvData += [PSCustomObject]@{
                        Type = "Track"
                        Name = $track.Name
                        Artist = $track.Artist
                        Album = $track.Album
                        PlayCount = $track.PlayCount
                        TotalPlaytimeMs = $track.TotalPlaytime
                        TotalPlaytimeHours = [Math]::Round($track.TotalPlaytime / (1000 * 60 * 60), 2)
                        Period = $period
                        ExportDate = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
                
                # Export artists
                foreach ($artist in $stats.TopArtists.Artists) {
                    $csvData += [PSCustomObject]@{
                        Type = "Artist"
                        Name = $artist.Name
                        Artist = $artist.Name
                        Album = ""
                        PlayCount = $artist.PlayCount
                        TotalPlaytimeMs = $artist.TotalPlaytime
                        TotalPlaytimeHours = [Math]::Round($artist.TotalPlaytime / (1000 * 60 * 60), 2)
                        Period = $period
                        ExportDate = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
                
                # Export genre data
                foreach ($genre in $stats.GenreDistribution.Distribution.Keys) {
                    $genreData = $stats.GenreDistribution.Distribution[$genre]
                    $csvData += [PSCustomObject]@{
                        Type = "Genre"
                        Name = $genre
                        Artist = ""
                        Album = ""
                        PlayCount = $genreData.Count
                        TotalPlaytimeMs = $genreData.PlaytimeMs
                        TotalPlaytimeHours = $genreData.PlaytimeHours
                        Period = $period
                        ExportDate = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
                
                $csv = $csvData | ConvertTo-Csv -NoTypeInformation
                return @{
                    Format = "csv"
                    Data = $csv -join "`n"
                    FileName = "spotify_stats_${period}_${timestamp}.csv"
                    Success = $true
                }
            }
            default {
                return @{
                    Success = $false
                    Error = "Unsupported export format: $format. Supported formats: json, csv"
                }
            }
        }
    }
    
    [hashtable] ExportRawData([DateTime]$startDate, [DateTime]$endDate, [string]$format) {
        try {
            $events = $this.DataCollector.GetPlaybackHistory($startDate, $endDate)
            $timestamp = [DateTime]::Now.ToString("yyyyMMdd_HHmmss")
            
            switch ($format.ToLower()) {
                "json" {
                    $exportData = @{
                        ExportInfo = @{
                            Timestamp = [DateTime]::UtcNow
                            StartDate = $startDate
                            EndDate = $endDate
                            TotalEvents = $events.Count
                            Version = "1.0"
                        }
                        Events = $events
                    }
                    
                    return @{
                        Format = "json"
                        Data = $exportData | ConvertTo-Json -Depth 10
                        FileName = "spotify_raw_data_${timestamp}.json"
                        Success = $true
                    }
                }
                "csv" {
                    $csvData = @()
                    foreach ($event in $events) {
                        $csvData += [PSCustomObject]@{
                            TrackId = $event.TrackId
                            TrackName = $event.TrackName
                            ArtistName = $event.ArtistName
                            AlbumName = $event.AlbumName
                            Genres = ($event.Genres -join "; ")
                            Timestamp = $event.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
                            DurationMs = $event.DurationMs
                            PositionMs = $event.PositionMs
                            EventType = $event.EventType
                            DeviceType = $event.DeviceType
                            IsExplicit = $event.IsExplicit
                        }
                    }
                    
                    $csv = $csvData | ConvertTo-Csv -NoTypeInformation
                    return @{
                        Format = "csv"
                        Data = $csv -join "`n"
                        FileName = "spotify_raw_data_${timestamp}.csv"
                        Success = $true
                    }
                }
                default {
                    return @{
                        Success = $false
                        Error = "Unsupported export format: $format. Supported formats: json, csv"
                    }
                }
            }
        } catch {
            return @{
                Success = $false
                Error = "Failed to export raw data: $($_.Exception.Message)"
            }
        }
    }
    
    [hashtable] BackupData([string]$backupPath) {
        try {
            $timestamp = [DateTime]::Now.ToString("yyyyMMdd_HHmmss")
            $backupFileName = "spotify_backup_${timestamp}.json"
            $fullBackupPath = Join-Path $backupPath $backupFileName
            
            # Ensure backup directory exists
            if (-not (Test-Path $backupPath)) {
                New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
            }
            
            # Get all data
            $allEvents = $this.DataCollector.LoadEvents()
            $storageStats = $this.DataCollector.GetStorageStats()
            
            $backupData = @{
                BackupInfo = @{
                    Timestamp = [DateTime]::UtcNow
                    Version = "1.0"
                    OriginalFile = $this.DataCollector.DatabaseFile
                    EventCount = $allEvents.Count
                }
                StorageStats = $storageStats
                Events = $allEvents
            }
            
            $json = $backupData | ConvertTo-Json -Depth 10
            Set-Content -Path $fullBackupPath -Value $json -Encoding UTF8
            
            return @{
                Success = $true
                BackupFile = $fullBackupPath
                EventCount = $allEvents.Count
                BackupSizeMB = [Math]::Round((Get-Item $fullBackupPath).Length / 1MB, 2)
            }
        } catch {
            return @{
                Success = $false
                Error = "Failed to create backup: $($_.Exception.Message)"
            }
        }
    }
    
    [hashtable] RestoreData([string]$backupFile) {
        try {
            if (-not (Test-Path $backupFile)) {
                return @{
                    Success = $false
                    Error = "Backup file not found: $backupFile"
                }
            }
            
            # Load backup data
            $json = Get-Content -Path $backupFile -Raw -Encoding UTF8
            $backupData = $json | ConvertFrom-Json
            
            if (-not $backupData.Events) {
                return @{
                    Success = $false
                    Error = "Invalid backup file format: no events data found"
                }
            }
            
            # Create backup of current data before restore
            $currentBackup = $this.BackupData((Split-Path $this.DataCollector.DatabaseFile -Parent))
            
            # Restore events
            $restoredEvents = @()
            foreach ($eventData in $backupData.Events) {
                try {
                    $eventHash = @{}
                    $eventData.PSObject.Properties | ForEach-Object {
                        $eventHash[$_.Name] = $_.Value
                    }
                    # Convert timestamp string back to DateTime if needed
                    if ($eventHash.Timestamp -is [string]) {
                        $eventHash.Timestamp = [DateTime]::Parse($eventHash.Timestamp)
                    }
                    $restoredEvents += [PlaybackEvent]::new($eventHash)
                } catch {
                    Write-Warning "Failed to restore event: $($_.Exception.Message)"
                    continue
                }
            }
            
            # Save restored data
            $json = $restoredEvents | ConvertTo-Json -Depth 10
            Set-Content -Path $this.DataCollector.DatabaseFile -Value $json -Encoding UTF8
            
            return @{
                Success = $true
                RestoredEvents = $restoredEvents.Count
                BackupCreated = $currentBackup.BackupFile
                RestoreDate = [DateTime]::UtcNow
            }
        } catch {
            return @{
                Success = $false
                Error = "Failed to restore data: $($_.Exception.Message)"
            }
        }
    }
    
    [void] ClearData() {
        $this.DataCollector.ClearHistory()
        return
    }
    
    [hashtable] GetStorageInfo() {
        return $this.DataCollector.GetStorageStats()
    }
}

# Export classes and functions
# Note: PowerShell classes are automatically available when the module is imported
# We don't need to explicitly export them, but we can create helper functions

function New-StatisticsEngine {
    param([hashtable]$Configuration = @{})
    return [StatisticsEngine]::new($Configuration)
}

function New-DataCollector {
    param([string]$DataDirectory)
    return [DataCollector]::new($DataDirectory)
}

function New-AnalyticsProcessor {
    param([DataCollector]$DataCollector)
    return [AnalyticsProcessor]::new($DataCollector)
}

function New-VisualizationGenerator {
    return [VisualizationGenerator]::new()
}

Export-ModuleMember -Function @(
    'New-StatisticsEngine',
    'New-DataCollector', 
    'New-AnalyticsProcessor',
    'New-VisualizationGenerator'
)