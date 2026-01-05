# Lyrics Engine Module
# Provides lyrics fetching, caching, and display functionality for Spotify CLI

using namespace System.Management.Automation

# Base interface for lyrics providers
class ILyricsProvider {
    [hashtable] FetchLyrics([string]$artist, [string]$track) { throw [System.NotImplementedException]::new() }
    [bool] IsAvailable() { throw [System.NotImplementedException]::new() }
    [string] GetProviderName() { throw [System.NotImplementedException]::new() }
}

# Abstract base class for lyrics providers
class LyricsProviderBase : ILyricsProvider {
    [string] $ProviderName
    [hashtable] $Configuration = @{}
    [int] $TimeoutMs = 10000
    
    LyricsProviderBase([string]$name, [hashtable]$config) {
        $this.ProviderName = $name
        $this.Configuration = $config
        
        if ($config.ContainsKey('TimeoutMs')) {
            $this.TimeoutMs = $config.TimeoutMs
        }
    }
    
    [hashtable] FetchLyrics([string]$artist, [string]$track) {
        if ([string]::IsNullOrWhiteSpace($artist) -or [string]::IsNullOrWhiteSpace($track)) {
            throw [System.ArgumentException]::new("Artist and track name are required")
        }
        
        return $this.FetchLyricsInternal($artist, $track)
    }
    
    [hashtable] FetchLyricsInternal([string]$artist, [string]$track) {
        # Override in derived classes
        throw [System.NotImplementedException]::new()
    }
    
    [bool] IsAvailable() {
        # Override in derived classes for availability check
        return $true
    }
    
    [string] GetProviderName() {
        return $this.ProviderName
    }
    
    [string] SanitizeSearchTerm([string]$term) {
        # Remove special characters and normalize for search
        $sanitized = $term -replace '[^\w\s-]', ''
        $sanitized = $sanitized -replace '\s+', ' '
        return $sanitized.Trim()
    }
}

# Genius API lyrics provider
class GeniusLyricsProvider : LyricsProviderBase {
    [string] $ApiKey
    [string] $BaseUrl = "https://api.genius.com"
    
    GeniusLyricsProvider([hashtable]$config) : base("Genius", $config) {
        if ($config.ContainsKey('ApiKey')) {
            $this.ApiKey = $config.ApiKey
        }
    }
    
    [hashtable] FetchLyricsInternal([string]$artist, [string]$track) {
        if ([string]::IsNullOrWhiteSpace($this.ApiKey)) {
            throw [System.InvalidOperationException]::new("Genius API key not configured")
        }
        
        try {
            # Search for the song
            $searchQuery = "$($this.SanitizeSearchTerm($artist)) $($this.SanitizeSearchTerm($track))"
            $searchUrl = "$($this.BaseUrl)/search?q=$([System.Uri]::EscapeDataString($searchQuery))"
            
            $headers = @{
                'Authorization' = "Bearer $($this.ApiKey)"
                'User-Agent' = 'SpotifyCLI/1.0'
            }
            
            $searchResponse = Invoke-RestMethod -Uri $searchUrl -Headers $headers -TimeoutSec ($this.TimeoutMs / 1000)
            
            if (-not $searchResponse.response.hits -or $searchResponse.response.hits.Count -eq 0) {
                return @{
                    Success = $false
                    Error = "No lyrics found"
                    Provider = $this.ProviderName
                }
            }
            
            # Get the first hit (most relevant)
            $hit = $searchResponse.response.hits[0]
            $songUrl = $hit.result.url
            
            # Note: Genius doesn't provide lyrics directly via API
            # This would require web scraping which is against their ToS
            # Return metadata for now
            return @{
                Success = $true
                TrackId = "$artist-$track"
                FullText = "Lyrics available at: $songUrl"
                SyncedLines = @()
                Source = $this.ProviderName
                HasSyncedLyrics = $false
                Url = $songUrl
                CachedAt = [DateTime]::UtcNow
            }
        } catch {
            return @{
                Success = $false
                Error = $_.Exception.Message
                Provider = $this.ProviderName
            }
        }
    }
    
    [bool] IsAvailable() {
        return -not [string]::IsNullOrWhiteSpace($this.ApiKey)
    }
}

# LRCLIB.net API lyrics provider (Free, no API key required, supports synced lyrics!)
class LrclibProvider : LyricsProviderBase {
    [string] $BaseUrl = "https://lrclib.net/api"

    LrclibProvider([hashtable]$config) : base("LRCLIB", $config) {
    }

    [hashtable] FetchLyricsInternal([string]$artist, [string]$track) {
        try {
            # Search for track - LRCLIB uses search endpoint
            $artistEncoded = [System.Uri]::EscapeDataString($this.SanitizeSearchTerm($artist))
            $trackEncoded = [System.Uri]::EscapeDataString($this.SanitizeSearchTerm($track))
            $url = "$($this.BaseUrl)/search?track_name=$trackEncoded&artist_name=$artistEncoded"

            $response = Invoke-RestMethod -Uri $url -TimeoutSec ($this.TimeoutMs / 1000) -ErrorAction Stop

            if (-not $response -or $response.Count -eq 0) {
                return @{
                    Success = $false
                    Error = "No lyrics found"
                    Provider = $this.ProviderName
                }
            }

            # Take first match
            $result = $response[0]

            # Check if instrumental
            if ($result.instrumental) {
                return @{
                    Success = $false
                    Error = "Track is instrumental (no lyrics)"
                    Provider = $this.ProviderName
                }
            }

            # Get plain lyrics
            $plainLyrics = if ($result.plainLyrics) { $result.plainLyrics.Trim() } else { "" }
            $syncedLyrics = if ($result.syncedLyrics) { $result.syncedLyrics.Trim() } else { "" }

            if ([string]::IsNullOrWhiteSpace($plainLyrics) -and [string]::IsNullOrWhiteSpace($syncedLyrics)) {
                return @{
                    Success = $false
                    Error = "No lyrics available for this track"
                    Provider = $this.ProviderName
                }
            }

            # Parse synced lyrics if available (LRC format)
            $syncedLines = @()
            $hasSynced = $false

            if (-not [string]::IsNullOrWhiteSpace($syncedLyrics)) {
                $syncedLines = $this.ParseLrcFormat($syncedLyrics)
                $hasSynced = $syncedLines.Count -gt 0
            }

            return @{
                Success = $true
                TrackId = "$artist-$track"
                FullText = $plainLyrics
                SyncedLines = $syncedLines
                Source = $this.ProviderName
                HasSyncedLyrics = $hasSynced
                CachedAt = [DateTime]::UtcNow
            }
        } catch {
            $errorMessage = $_.Exception.Message

            # Handle common errors
            if ($_.Exception.Response.StatusCode -eq 404) {
                $errorMessage = "Lyrics not found in database"
            }

            return @{
                Success = $false
                Error = $errorMessage
                Provider = $this.ProviderName
            }
        }
    }

    [array] ParseLrcFormat([string]$lrcText) {
        # Parse LRC format: [mm:ss.xx] Lyrics text
        $lines = @()
        $lrcLines = $lrcText -split "`n"

        foreach ($line in $lrcLines) {
            if ($line -match '^\[(\d+):(\d+)\.(\d+)\]\s*(.*)$') {
                $minutes = [int]$matches[1]
                $seconds = [int]$matches[2]
                $centiseconds = [int]$matches[3]
                $text = $matches[4].Trim()

                $timestampMs = ($minutes * 60 * 1000) + ($seconds * 1000) + ($centiseconds * 10)

                $lines += @{
                    Timestamp = $timestampMs
                    Text = $text
                }
            }
        }

        return $lines
    }

    [bool] IsAvailable() {
        # Always available - no API key required
        return $true
    }
}

# Musixmatch API lyrics provider
class MusixmatchLyricsProvider : LyricsProviderBase {
    [string] $ApiKey
    [string] $BaseUrl = "https://api.musixmatch.com/ws/1.1"
    
    MusixmatchLyricsProvider([hashtable]$config) : base("Musixmatch", $config) {
        if ($config.ContainsKey('ApiKey')) {
            $this.ApiKey = $config.ApiKey
        }
    }
    
    [hashtable] FetchLyricsInternal([string]$artist, [string]$track) {
        if ([string]::IsNullOrWhiteSpace($this.ApiKey)) {
            throw [System.InvalidOperationException]::new("Musixmatch API key not configured")
        }
        
        try {
            # Search for the track
            $searchQuery = @{
                'apikey' = $this.ApiKey
                'q_artist' = $this.SanitizeSearchTerm($artist)
                'q_track' = $this.SanitizeSearchTerm($track)
                'page_size' = 1
                'page' = 1
                's_track_rating' = 'desc'
            }
            
            $searchParams = ($searchQuery.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Uri]::EscapeDataString($_.Value))" }) -join '&'
            $searchUrl = "$($this.BaseUrl)/track.search?$searchParams"
            
            $searchResponse = Invoke-RestMethod -Uri $searchUrl -TimeoutSec ($this.TimeoutMs / 1000)
            
            if ($searchResponse.message.header.status_code -ne 200 -or 
                -not $searchResponse.message.body.track_list -or 
                $searchResponse.message.body.track_list.Count -eq 0) {
                return @{
                    Success = $false
                    Error = "No track found"
                    Provider = $this.ProviderName
                }
            }
            
            $track_id = $searchResponse.message.body.track_list[0].track.track_id
            
            # Get lyrics for the track
            $lyricsParams = @{
                'apikey' = $this.ApiKey
                'track_id' = $track_id
            }
            
            $lyricsParamsStr = ($lyricsParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Uri]::EscapeDataString($_.Value))" }) -join '&'
            $lyricsUrl = "$($this.BaseUrl)/track.lyrics.get?$lyricsParamsStr"
            
            $lyricsResponse = Invoke-RestMethod -Uri $lyricsUrl -TimeoutSec ($this.TimeoutMs / 1000)
            
            if ($lyricsResponse.message.header.status_code -ne 200 -or 
                -not $lyricsResponse.message.body.lyrics) {
                return @{
                    Success = $false
                    Error = "No lyrics available"
                    Provider = $this.ProviderName
                }
            }
            
            $lyricsBody = $lyricsResponse.message.body.lyrics.lyrics_body
            
            # Try to get synced lyrics
            $syncedLyricsUrl = "$($this.BaseUrl)/track.subtitle.get?$lyricsParamsStr"
            $syncedLines = @()
            $hasSyncedLyrics = $false
            
            try {
                $syncedResponse = Invoke-RestMethod -Uri $syncedLyricsUrl -TimeoutSec ($this.TimeoutMs / 1000)
                if ($syncedResponse.message.header.status_code -eq 200 -and $syncedResponse.message.body.subtitle) {
                    $subtitleBody = $syncedResponse.message.body.subtitle.subtitle_body
                    if (-not [string]::IsNullOrWhiteSpace($subtitleBody)) {
                        $syncedLines = $this.ParseSubtitleFormat($subtitleBody)
                        $hasSyncedLyrics = $syncedLines.Count -gt 0
                    }
                }
            } catch {
                # Synced lyrics not available, continue with regular lyrics
            }
            
            return @{
                Success = $true
                TrackId = "$artist-$track"
                FullText = $lyricsBody
                SyncedLines = $syncedLines
                Source = $this.ProviderName
                HasSyncedLyrics = $hasSyncedLyrics
                CachedAt = [DateTime]::UtcNow
            }
        } catch {
            return @{
                Success = $false
                Error = $_.Exception.Message
                Provider = $this.ProviderName
            }
        }
    }
    
    [array] ParseSubtitleFormat([string]$subtitleText) {
        $lines = @()
        $subtitleLines = $subtitleText -split "`n"
        
        foreach ($line in $subtitleLines) {
            if ($line -match '^\[(\d{2}):(\d{2})\.(\d{2})\]\s*(.*)$') {
                $minutes = [int]$matches[1]
                $seconds = [int]$matches[2]
                $centiseconds = [int]$matches[3]
                $text = $matches[4].Trim()
                
                $timestampMs = ($minutes * 60 * 1000) + ($seconds * 1000) + ($centiseconds * 10)
                
                if (-not [string]::IsNullOrWhiteSpace($text)) {
                    $lines += @{
                        Timestamp = $timestampMs
                        Text = $text
                    }
                }
            }
        }
        
        return $lines
    }
    
    [bool] IsAvailable() {
        return -not [string]::IsNullOrWhiteSpace($this.ApiKey)
    }
}

# Mock lyrics provider for testing
class MockLyricsProvider : LyricsProviderBase {
    MockLyricsProvider([hashtable]$config) : base("Mock", $config) {
    }
    
    [hashtable] FetchLyricsInternal([string]$artist, [string]$track) {
        # Return mock lyrics for testing
        $mockLyrics = @"
[00:00.00] Mock lyrics for testing
[00:05.00] Artist: $artist
[00:10.00] Track: $track
[00:15.00] This is a sample lyric line
[00:20.00] Another line of lyrics
[00:25.00] End of mock lyrics
"@
        
        $syncedLines = @(
            @{ Timestamp = 0; Text = "Mock lyrics for testing" },
            @{ Timestamp = 5000; Text = "Artist: $artist" },
            @{ Timestamp = 10000; Text = "Track: $track" },
            @{ Timestamp = 15000; Text = "This is a sample lyric line" },
            @{ Timestamp = 20000; Text = "Another line of lyrics" },
            @{ Timestamp = 25000; Text = "End of mock lyrics" }
        )
        
        return @{
            Success = $true
            TrackId = "$artist-$track"
            FullText = $mockLyrics
            SyncedLines = $syncedLines
            Source = $this.ProviderName
            HasSyncedLyrics = $true
            CachedAt = [DateTime]::UtcNow
        }
    }
    
    [bool] IsAvailable() {
        return $true
    }
}

# Lyrics cache manager
class LyricsCache {
    [string] $CacheDirectory
    [int] $MaxAgeHours = 720  # 30 days
    [int] $MaxCacheSizeMB = 50
    [hashtable] $PerformanceStats = @{
        Hits = 0
        Misses = 0
        Stores = 0
        Cleanups = 0
        LastCleanup = $null
    }
    
    LyricsCache([string]$cacheDir) {
        $this.CacheDirectory = $cacheDir
        $this.EnsureCacheDirectory()
    }
    
    [void] EnsureCacheDirectory() {
        if (-not (Test-Path $this.CacheDirectory)) {
            New-Item -ItemType Directory -Path $this.CacheDirectory -Force | Out-Null
        }
    }
    
    [string] GetCacheKey([string]$trackId) {
        # Create a safe filename from track ID
        $safeKey = $trackId -replace '[^\w\-]', '_'
        return "$safeKey.json"
    }
    
    [string] GetCachePath([string]$trackId) {
        $cacheKey = $this.GetCacheKey($trackId)
        return Join-Path $this.CacheDirectory $cacheKey
    }
    
    [void] StoreLyrics([string]$trackId, [hashtable]$lyricsData) {
        try {
            $cachePath = $this.GetCachePath($trackId)
            $lyricsData.CachedAt = [DateTime]::UtcNow
            
            $json = $lyricsData | ConvertTo-Json -Depth 10
            Set-Content -Path $cachePath -Value $json -Encoding UTF8
            
            $this.PerformanceStats.Stores++
            
            # Check if cache size exceeds limit and cleanup if needed
            $this.CheckCacheSizeAndCleanup()
        } catch {
            Write-Warning "Failed to cache lyrics for $trackId : $($_.Exception.Message)"
        }
    }
    
    [hashtable] GetCachedLyrics([string]$trackId) {
        try {
            $cachePath = $this.GetCachePath($trackId)
            
            if (-not (Test-Path $cachePath)) {
                $this.PerformanceStats.Misses++
                return $null
            }
            
            $json = Get-Content -Path $cachePath -Raw -Encoding UTF8
            $lyricsData = $json | ConvertFrom-Json
            
            # Check if cache is still valid
            if ($this.IsCacheExpired($lyricsData.CachedAt)) {
                Remove-Item -Path $cachePath -Force -ErrorAction SilentlyContinue
                $this.PerformanceStats.Misses++
                return $null
            }
            
            # Convert back to hashtable
            $result = @{}
            $lyricsData.PSObject.Properties | ForEach-Object {
                $result[$_.Name] = $_.Value
            }
            
            $this.PerformanceStats.Hits++
            return $result
        } catch {
            Write-Warning "Failed to read cached lyrics for $trackId : $($_.Exception.Message)"
            $this.PerformanceStats.Misses++
            return $null
        }
    }
    
    [bool] HasCachedLyrics([string]$trackId) {
        $cached = $this.GetCachedLyrics($trackId)
        return $null -ne $cached
    }
    
    [bool] IsCacheExpired([DateTime]$cachedAt) {
        $age = [DateTime]::UtcNow - $cachedAt
        return $age.TotalHours -gt $this.MaxAgeHours
    }
    
    [void] CleanupOldEntries([int]$maxAgeHours) {
        try {
            $cutoffTime = [DateTime]::UtcNow.AddHours(-$maxAgeHours)
            $cacheFiles = Get-ChildItem -Path $this.CacheDirectory -Filter "*.json" -ErrorAction SilentlyContinue
            $cleanedCount = 0
            
            foreach ($file in $cacheFiles) {
                if ($file.LastWriteTime -lt $cutoffTime) {
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                    $cleanedCount++
                }
            }
            
            $this.PerformanceStats.Cleanups++
            $this.PerformanceStats.LastCleanup = [DateTime]::UtcNow
            
            if ($cleanedCount -gt 0) {
                Write-Verbose "Cleaned up $cleanedCount old cache entries"
            }
        } catch {
            Write-Warning "Failed to cleanup old cache entries: $($_.Exception.Message)"
        }
    }
    
    [void] ClearCache() {
        try {
            $cacheFiles = Get-ChildItem -Path $this.CacheDirectory -Filter "*.json" -ErrorAction SilentlyContinue
            foreach ($file in $cacheFiles) {
                Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Warning "Failed to clear cache: $($_.Exception.Message)"
        }
    }
    
    [void] CheckCacheSizeAndCleanup() {
        try {
            $cacheFiles = Get-ChildItem -Path $this.CacheDirectory -Filter "*.json" -ErrorAction SilentlyContinue
            $totalSize = ($cacheFiles | Measure-Object -Property Length -Sum).Sum
            $totalSizeMB = $totalSize / 1MB
            
            if ($totalSizeMB -gt $this.MaxCacheSizeMB) {
                # Remove oldest files first
                $sortedFiles = $cacheFiles | Sort-Object LastWriteTime
                $targetSize = $this.MaxCacheSizeMB * 0.8  # Clean to 80% of max size
                $currentSize = $totalSizeMB
                
                foreach ($file in $sortedFiles) {
                    if ($currentSize -le $targetSize) {
                        break
                    }
                    
                    $fileSizeMB = $file.Length / 1MB
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                    $currentSize -= $fileSizeMB
                }
                
                Write-Verbose "Cache size exceeded limit. Cleaned up to $([Math]::Round($currentSize, 2))MB"
            }
        } catch {
            Write-Warning "Failed to check cache size: $($_.Exception.Message)"
        }
    }
    
    [hashtable] GetCacheStats() {
        try {
            $cacheFiles = Get-ChildItem -Path $this.CacheDirectory -Filter "*.json" -ErrorAction SilentlyContinue
            $totalSize = ($cacheFiles | Measure-Object -Property Length -Sum).Sum
            $totalSizeMB = [Math]::Round($totalSize / 1MB, 2)
            
            $hitRate = 0
            $totalRequests = $this.PerformanceStats.Hits + $this.PerformanceStats.Misses
            if ($totalRequests -gt 0) {
                $hitRate = [Math]::Round(($this.PerformanceStats.Hits / $totalRequests) * 100, 2)
            }
            
            return @{
                TotalFiles = $cacheFiles.Count
                TotalSizeMB = $totalSizeMB
                MaxSizeMB = $this.MaxCacheSizeMB
                MaxAgeHours = $this.MaxAgeHours
                CacheDirectory = $this.CacheDirectory
                Performance = @{
                    Hits = $this.PerformanceStats.Hits
                    Misses = $this.PerformanceStats.Misses
                    Stores = $this.PerformanceStats.Stores
                    Cleanups = $this.PerformanceStats.Cleanups
                    HitRate = "$hitRate%"
                    LastCleanup = $this.PerformanceStats.LastCleanup
                }
            }
        } catch {
            return @{
                TotalFiles = 0
                TotalSizeMB = 0
                MaxSizeMB = $this.MaxCacheSizeMB
                MaxAgeHours = $this.MaxAgeHours
                CacheDirectory = $this.CacheDirectory
                Error = $_.Exception.Message
                Performance = $this.PerformanceStats
            }
        }
    }
}

# Unified lyrics interface for external consumers
class LyricsManager {
    [LyricsEngine] $Engine
    [hashtable] $Stats
    
    LyricsManager([hashtable]$config) {
        $this.Engine = [LyricsEngine]::new($config)
        $this.Stats = @{
            CacheHits = 0
            CacheMisses = 0
            ProviderRequests = @{}
            LastRequest = $null
        }
    }
    
    [hashtable] GetLyrics([string]$artist, [string]$track) {
        $this.Stats.LastRequest = [DateTime]::UtcNow
        
        $result = $this.Engine.GetLyrics($artist, $track)
        
        if ($result.ContainsKey('FromCache') -and $result.FromCache) {
            $this.Stats.CacheHits++
        } else {
            $this.Stats.CacheMisses++
            
            if ($result.ContainsKey('Source')) {
                $provider = $result.Source
                if (-not $this.Stats.ProviderRequests.ContainsKey($provider)) {
                    $this.Stats.ProviderRequests[$provider] = 0
                }
                $this.Stats.ProviderRequests[$provider]++
            }
        }
        
        return $result
    }
    
    [array] GetAvailableProviders() {
        $providers = @()
        foreach ($provider in $this.Engine.Providers) {
            $providers += @{
                Name = $provider.GetProviderName()
                Available = $provider.IsAvailable()
            }
        }
        return $providers
    }
    
    [hashtable] GetStats() {
        $engineStats = $this.Engine.GetCacheStats()
        return @{
            Cache = $engineStats
            Performance = $this.Stats
            Providers = $this.GetAvailableProviders()
        }
    }
    
    [void] ClearCache() {
        $this.Engine.ClearCache()
    }
    
    [void] CleanupCache([int]$maxAgeHours) {
        $this.Engine.CleanupCache($maxAgeHours)
    }
}

# Main lyrics engine
class LyricsEngine {
    [System.Collections.Generic.List[ILyricsProvider]] $Providers
    [LyricsCache] $Cache
    [hashtable] $Configuration
    
    LyricsEngine([hashtable]$config) {
        $this.Configuration = $config
        $this.Providers = [System.Collections.Generic.List[ILyricsProvider]]::new()
        
        # Initialize cache
        $cacheDir = if ($config.ContainsKey('CacheDirectory')) { $config.CacheDirectory } else { Join-Path $env:TEMP "SpotifyLyrics" }
        $this.Cache = [LyricsCache]::new($cacheDir)
        
        # Initialize providers
        $this.InitializeProviders()
    }
    
    [void] InitializeProviders() {
        # Add LRCLIB provider first (primary provider - free, no API key, supports synced lyrics!)
        $lrclibProvider = [LrclibProvider]::new(@{})
        $this.Providers.Add($lrclibProvider)

        # Add Genius provider if configured (fallback #1)
        if ($this.Configuration.ContainsKey('GeniusApiKey')) {
            $geniusProvider = [GeniusLyricsProvider]::new(@{
                ApiKey = $this.Configuration.GeniusApiKey
            })
            $this.Providers.Add($geniusProvider)
        }

        # Add Musixmatch provider if configured (fallback #2)
        if ($this.Configuration.ContainsKey('MusixmatchApiKey')) {
            $musixmatchProvider = [MusixmatchLyricsProvider]::new(@{
                ApiKey = $this.Configuration.MusixmatchApiKey
            })
            $this.Providers.Add($musixmatchProvider)
        }

        # Add mock provider for testing (lowest priority)
        $mockProvider = [MockLyricsProvider]::new(@{})
        $this.Providers.Add($mockProvider)
    }
    
    [hashtable] GetLyrics([string]$artist, [string]$track) {
        $trackId = "$artist-$track"
        
        # Try cache first
        $cached = $this.Cache.GetCachedLyrics($trackId)
        if ($cached) {
            $cached.FromCache = $true
            return $cached
        }
        
        # Try each provider
        foreach ($provider in $this.Providers) {
            if (-not $provider.IsAvailable()) {
                continue
            }
            
            try {
                $result = $provider.FetchLyrics($artist, $track)
                if ($result.Success) {
                    # Cache the result
                    $this.Cache.StoreLyrics($trackId, $result)
                    $result.FromCache = $false
                    return $result
                }
            } catch {
                Write-Warning "Provider $($provider.GetProviderName()) failed: $($_.Exception.Message)"
                continue
            }
        }
        
        # No lyrics found
        return @{
            Success = $false
            Error = "No lyrics found from any provider"
            TrackId = $trackId
        }
    }
    
    [hashtable] GetCacheStats() {
        return $this.Cache.GetCacheStats()
    }
    
    [void] ClearCache() {
        $this.Cache.ClearCache()
    }
    
    [void] CleanupCache([int]$maxAgeHours) {
        $this.Engine.CleanupCache($maxAgeHours)
    }
    
    [void] PerformMaintenance() {
        # Perform routine maintenance tasks
        $this.Engine.CleanupCache($this.Engine.Cache.MaxAgeHours)
        $this.Engine.Cache.CheckCacheSizeAndCleanup()
    }
}

# Scrollable lyrics display interface
class LyricsDisplay {
    [hashtable] $LyricsData
    [int] $CurrentLine = 0
    [int] $DisplayHeight = 20
    [int] $DisplayWidth = 80
    [bool] $ShowTimestamps = $true
    [bool] $HighlightCurrent = $true
    [string] $SearchTerm = ""
    [array] $SearchResults = @()
    [int] $CurrentSearchIndex = -1
    
    LyricsDisplay([hashtable]$lyricsData) {
        $this.LyricsData = $lyricsData
        $this.InitializeDisplay()
    }
    
    [void] InitializeDisplay() {
        # Use default dimensions - console access from classes can be problematic
        # These can be overridden by calling code if needed
        $this.DisplayWidth = 80
        $this.DisplayHeight = 20
    }
    
    [string] RenderDisplay([int]$currentPositionMs) {
        $output = [System.Text.StringBuilder]::new()
        
        # Header
        $title = "Lyrics: $($this.LyricsData.TrackId)"
        $header = $title.PadRight($this.DisplayWidth)
        $output.AppendLine("┌$('─' * $this.DisplayWidth)┐") | Out-Null
        $output.AppendLine("│$header│") | Out-Null
        $output.AppendLine("├$('─' * $this.DisplayWidth)┤") | Out-Null
        
        # Get lines to display
        $lines = $this.GetDisplayLines($currentPositionMs)
        
        # Display lines
        for ($i = 0; $i -lt $this.DisplayHeight; $i++) {
            if ($i -lt $lines.Count) {
                $line = $lines[$i]
                $output.AppendLine("│$($line.PadRight($this.DisplayWidth))│") | Out-Null
            } else {
                $output.AppendLine("│$(' ' * $this.DisplayWidth)│") | Out-Null
            }
        }
        
        # Footer with controls
        $output.AppendLine("├$('─' * $this.DisplayWidth)┤") | Out-Null
        $controls = "↑↓: Scroll | /: Search | Esc: Exit"
        if ($this.SearchTerm) {
            $controls = "Search: '$($this.SearchTerm)' | n: Next | N: Prev | Esc: Clear"
        }
        $output.AppendLine("│$($controls.PadRight($this.DisplayWidth))│") | Out-Null
        $output.AppendLine("└$('─' * $this.DisplayWidth)┘") | Out-Null
        
        return $output.ToString()
    }
    
    [array] GetDisplayLines([int]$currentPositionMs) {
        $lines = @()
        
        if ($this.LyricsData.HasSyncedLyrics -and $this.LyricsData.SyncedLines) {
            # Use synced lyrics
            $syncedLines = $this.LyricsData.SyncedLines
            $currentLineIndex = $this.FindCurrentLine($currentPositionMs, $syncedLines)
            
            # Calculate display range
            $startIndex = [Math]::Max(0, $this.CurrentLine)
            $endIndex = [Math]::Min($syncedLines.Count - 1, $startIndex + $this.DisplayHeight - 1)
            
            for ($i = $startIndex; $i -le $endIndex; $i++) {
                $line = $syncedLines[$i]
                $timestamp = $this.FormatTimestamp($line.Timestamp)
                $text = $line.Text
                
                # Highlight current line
                $prefix = "  "
                if ($this.HighlightCurrent -and $i -eq $currentLineIndex) {
                    $prefix = "► "
                    $text = "[$text]"  # Simple highlighting
                }
                
                # Add timestamp if enabled
                if ($this.ShowTimestamps) {
                    $displayLine = "$prefix$timestamp $text"
                } else {
                    $displayLine = "$prefix$text"
                }
                
                # Highlight search results
                if ($this.SearchTerm -and $text -match [regex]::Escape($this.SearchTerm)) {
                    $displayLine = $displayLine -replace [regex]::Escape($this.SearchTerm), "**$($this.SearchTerm)**"
                }
                
                $lines += $displayLine
            }
        } else {
            # Use plain text lyrics
            $textLines = $this.LyricsData.FullText -split "`n"
            $startIndex = [Math]::Max(0, $this.CurrentLine)
            $endIndex = [Math]::Min($textLines.Count - 1, $startIndex + $this.DisplayHeight - 1)
            
            for ($i = $startIndex; $i -le $endIndex; $i++) {
                $text = $textLines[$i].Trim()
                $displayLine = "  $text"
                
                # Highlight search results
                if ($this.SearchTerm -and $text -match [regex]::Escape($this.SearchTerm)) {
                    $displayLine = $displayLine -replace [regex]::Escape($this.SearchTerm), "**$($this.SearchTerm)**"
                }
                
                $lines += $displayLine
            }
        }
        
        return $lines
    }
    
    [int] FindCurrentLine([int]$currentPositionMs, [array]$syncedLines) {
        for ($i = $syncedLines.Count - 1; $i -ge 0; $i--) {
            if ($syncedLines[$i].Timestamp -le $currentPositionMs) {
                return $i
            }
        }
        return 0
    }
    
    [string] FormatTimestamp([int]$timestampMs) {
        $totalSeconds = [int][Math]::Floor($timestampMs / 1000)
        $minutes = [int][Math]::Floor($totalSeconds / 60)
        $seconds = [int]($totalSeconds % 60)
        return "{0:D2}:{1:D2}" -f $minutes, $seconds
    }
    
    [void] ScrollUp([int]$lines = 1) {
        $this.CurrentLine = [Math]::Max(0, $this.CurrentLine - $lines)
    }
    
    [void] ScrollDown([int]$lines = 1) {
        $maxLines = $this.GetMaxScrollPosition()
        $this.CurrentLine = [Math]::Min($maxLines, $this.CurrentLine + $lines)
    }
    
    [int] GetMaxScrollPosition() {
        if ($this.LyricsData.HasSyncedLyrics -and $this.LyricsData.SyncedLines) {
            return [Math]::Max(0, $this.LyricsData.SyncedLines.Count - $this.DisplayHeight)
        } else {
            $textLines = $this.LyricsData.FullText -split "`n"
            return [Math]::Max(0, $textLines.Count - $this.DisplayHeight)
        }
    }
    
    [void] Search([string]$term) {
        $this.SearchTerm = $term
        $this.SearchResults = @()
        $this.CurrentSearchIndex = -1
        
        if ([string]::IsNullOrWhiteSpace($term)) {
            return
        }
        
        if ($this.LyricsData.HasSyncedLyrics -and $this.LyricsData.SyncedLines) {
            for ($i = 0; $i -lt $this.LyricsData.SyncedLines.Count; $i++) {
                if ($this.LyricsData.SyncedLines[$i].Text -match [regex]::Escape($term)) {
                    $this.SearchResults += $i
                }
            }
        } else {
            $textLines = $this.LyricsData.FullText -split "`n"
            for ($i = 0; $i -lt $textLines.Count; $i++) {
                if ($textLines[$i] -match [regex]::Escape($term)) {
                    $this.SearchResults += $i
                }
            }
        }
    }
    
    [void] NextSearchResult() {
        if ($this.SearchResults.Count -eq 0) {
            return
        }
        
        $this.CurrentSearchIndex = ($this.CurrentSearchIndex + 1) % $this.SearchResults.Count
        $this.CurrentLine = $this.SearchResults[$this.CurrentSearchIndex]
    }
    
    [void] PreviousSearchResult() {
        if ($this.SearchResults.Count -eq 0) {
            return
        }
        
        $this.CurrentSearchIndex--
        if ($this.CurrentSearchIndex -lt 0) {
            $this.CurrentSearchIndex = $this.SearchResults.Count - 1
        }
        $this.CurrentLine = $this.SearchResults[$this.CurrentSearchIndex]
    }
    
    [void] ClearSearch() {
        $this.SearchTerm = ""
        $this.SearchResults = @()
        $this.CurrentSearchIndex = -1
    }
    
    [void] ToggleTimestamps() {
        $this.ShowTimestamps = -not $this.ShowTimestamps
    }
    
    [void] ToggleHighlighting() {
        $this.HighlightCurrent = -not $this.HighlightCurrent
    }
}

# Interactive lyrics viewer
class InteractiveLyricsViewer {
    [LyricsDisplay] $Display
    [bool] $IsRunning = $false
    [int] $CurrentPositionMs = 0
    [string] $InputBuffer = ""
    [bool] $SearchMode = $false
    [DateTime] $LastUpdate = [DateTime]::MinValue
    [ScriptBlock] $GetPlaybackPosition = $null
    [int] $ApiSyncIntervalMs = 5000  # Sync with API every 5 seconds
    [DateTime] $LastApiSync = [DateTime]::MinValue

    InteractiveLyricsViewer([hashtable]$lyricsData) {
        $this.Display = [LyricsDisplay]::new($lyricsData)
    }

    [void] SetPlaybackPositionGetter([ScriptBlock]$getter) {
        $this.GetPlaybackPosition = $getter
    }
    
    [void] Start([int]$initialPositionMs = 0) {
        $this.CurrentPositionMs = $initialPositionMs
        $this.IsRunning = $true
        
        try {
            # Hide cursor
            [Console]::CursorVisible = $false
            $this.MainLoop()
        } finally {
            # Restore cursor
            [Console]::CursorVisible = $true
            [Console]::Clear()
        }
    }
    
    [void] MainLoop() {
        $this.LastUpdate = [DateTime]::UtcNow
        $this.LastApiSync = [DateTime]::UtcNow

        while ($this.IsRunning) {
            try {
                # Update playback position
                $this.UpdatePlaybackPosition()

                # Clear screen and render
                [Console]::Clear()
                $output = $this.Display.RenderDisplay($this.CurrentPositionMs)
                Write-Host $output

                if ($this.SearchMode) {
                    Write-Host "Search: $($this.InputBuffer)_" -NoNewline
                }

                # Handle input
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    $this.HandleKeyPress($key)
                }

                Start-Sleep -Milliseconds 100
            } catch {
                # Handle any console access errors gracefully
                Write-Warning "Display error: $($_.Exception.Message)"
                Start-Sleep -Milliseconds 500
            }
        }
    }

    [void] UpdatePlaybackPosition() {
        $now = [DateTime]::UtcNow
        $timeSinceLastUpdate = ($now - $this.LastUpdate).TotalMilliseconds

        # Update position based on elapsed time (smooth playback simulation)
        $this.CurrentPositionMs += [int]$timeSinceLastUpdate
        $this.LastUpdate = $now

        # Sync with API periodically to correct drift
        $timeSinceApiSync = ($now - $this.LastApiSync).TotalMilliseconds
        if ($timeSinceApiSync -ge $this.ApiSyncIntervalMs -and $this.GetPlaybackPosition -ne $null) {
            try {
                $apiPosition = & $this.GetPlaybackPosition
                if ($apiPosition -ne $null) {
                    $this.CurrentPositionMs = $apiPosition
                    $this.LastApiSync = $now
                }
            } catch {
                # Silently ignore API errors, continue with time-based tracking
            }
        }
    }
    
    [void] HandleKeyPress([System.ConsoleKeyInfo]$key) {
        if ($this.SearchMode) {
            $this.HandleSearchInput($key)
            return
        }
        
        switch ($key.Key) {
            'UpArrow' { $this.Display.ScrollUp() }
            'DownArrow' { $this.Display.ScrollDown() }
            'PageUp' { $this.Display.ScrollUp(5) }
            'PageDown' { $this.Display.ScrollDown(5) }
            'Home' { $this.Display.CurrentLine = 0 }
            'End' { $this.Display.CurrentLine = $this.Display.GetMaxScrollPosition() }
            'T' { $this.Display.ToggleTimestamps() }
            'H' { $this.Display.ToggleHighlighting() }
            'Escape' { $this.IsRunning = $false }
            'Q' { $this.IsRunning = $false }
            default {
                if ($key.KeyChar -eq '/') {
                    $this.StartSearch()
                } elseif ($key.KeyChar -eq 'n') {
                    $this.Display.NextSearchResult()
                } elseif ($key.KeyChar -eq 'N') {
                    $this.Display.PreviousSearchResult()
                }
            }
        }
    }
    
    [void] HandleSearchInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            'Enter' {
                $this.Display.Search($this.InputBuffer)
                $this.SearchMode = $false
                if ($this.Display.SearchResults.Count -gt 0) {
                    $this.Display.NextSearchResult()
                }
            }
            'Escape' {
                $this.SearchMode = $false
                $this.InputBuffer = ""
                $this.Display.ClearSearch()
            }
            'Backspace' {
                if ($this.InputBuffer.Length -gt 0) {
                    $this.InputBuffer = $this.InputBuffer.Substring(0, $this.InputBuffer.Length - 1)
                }
            }
            default {
                if ($key.KeyChar -match '[a-zA-Z0-9\s]') {
                    $this.InputBuffer += $key.KeyChar
                }
            }
        }
    }
    
    [void] StartSearch() {
        $this.SearchMode = $true
        $this.InputBuffer = ""
    }
    
    [void] UpdatePosition([int]$positionMs) {
        $this.CurrentPositionMs = $positionMs
    }
}

# Public functions for external use
function New-LyricsManager {
    param(
        [hashtable]$Configuration = @{}
    )
    
    return [LyricsManager]::new($Configuration)
}

function Test-LyricsProviders {
    param(
        [hashtable]$Configuration = @{}
    )
    
    $manager = [LyricsManager]::new($Configuration)
    return $manager.GetAvailableProviders()
}

function Show-Lyrics {
    param(
        [Parameter(Mandatory)]
        [hashtable]$LyricsData,

        [int]$InitialPositionMs = 0,

        [ScriptBlock]$GetPlaybackPosition = $null
    )

    if (-not $LyricsData.Success) {
        Write-Error "Cannot display lyrics: $($LyricsData.Error)"
        return
    }

    $viewer = [InteractiveLyricsViewer]::new($LyricsData)
    if ($GetPlaybackPosition -ne $null) {
        $viewer.SetPlaybackPositionGetter($GetPlaybackPosition)
    }
    $viewer.Start($InitialPositionMs)
}

function Format-LyricsDisplay {
    param(
        [Parameter(Mandatory)]
        [hashtable]$LyricsData,
        
        [int]$CurrentPositionMs = 0,
        [int]$DisplayHeight = 10,
        [bool]$ShowTimestamps = $true
    )
    
    if (-not $LyricsData.Success) {
        return "No lyrics available: $($LyricsData.Error)"
    }
    
    $display = [LyricsDisplay]::new($LyricsData)
    $display.DisplayHeight = $DisplayHeight
    $display.ShowTimestamps = $ShowTimestamps
    
    return $display.RenderDisplay($CurrentPositionMs)
}

# Export classes and functions
Export-ModuleMember -Function @('New-LyricsManager', 'Test-LyricsProviders', 'Show-Lyrics', 'Format-LyricsDisplay') -Variable @()