# API Client Manager Module
# Provides enhanced Spotify API client with rate limiting, caching, and error handling

using namespace System.Management.Automation

# Error handling classes will be loaded by the main module

# Rate limiter class with enhanced exponential backoff
class RateLimiter {
    [int] $MaxRequestsPerMinute
    [System.Collections.Generic.Queue[DateTime]] $RequestTimes
    [System.Threading.Mutex] $Mutex
    [int] $BackoffMultiplier = 2
    [int] $MaxBackoffSeconds = 300
    [int] $BaseBackoffMs = 1000
    [hashtable] $BackoffHistory = @{}
    
    RateLimiter([int]$maxRequestsPerMinute) {
        $this.MaxRequestsPerMinute = $maxRequestsPerMinute
        $this.RequestTimes = [System.Collections.Generic.Queue[DateTime]]::new()
        $this.Mutex = [System.Threading.Mutex]::new()
    }
    
    [bool] CanMakeRequest() {
        $this.Mutex.WaitOne() | Out-Null
        
        try {
            $now = [DateTime]::UtcNow
            $oneMinuteAgo = $now.AddMinutes(-1)
            
            # Remove old requests
            while ($this.RequestTimes.Count -gt 0 -and $this.RequestTimes.Peek() -lt $oneMinuteAgo) {
                $this.RequestTimes.Dequeue() | Out-Null
            }
            
            return $this.RequestTimes.Count -lt $this.MaxRequestsPerMinute
        } finally {
            $this.Mutex.ReleaseMutex()
        }
    }
    
    [void] RecordRequest() {
        $this.Mutex.WaitOne() | Out-Null
        
        try {
            $this.RequestTimes.Enqueue([DateTime]::UtcNow)
        } finally {
            $this.Mutex.ReleaseMutex()
        }
    }
    
    [int] GetWaitTimeMs() {
        $this.Mutex.WaitOne() | Out-Null
        
        try {
            if ($this.RequestTimes.Count -eq 0) {
                return 0
            }
            
            $oldestRequest = $this.RequestTimes.Peek()
            $waitUntil = $oldestRequest.AddMinutes(1)
            $waitTime = $waitUntil - [DateTime]::UtcNow
            
            return [Math]::Max(0, [int]$waitTime.TotalMilliseconds)
        } finally {
            $this.Mutex.ReleaseMutex()
        }
    }
    
    [int] GetExponentialBackoffDelay([string]$endpoint, [int]$attempt) {
        $key = "backoff_$endpoint"
        
        # Calculate exponential backoff with jitter
        $baseDelay = $this.BaseBackoffMs * [Math]::Pow($this.BackoffMultiplier, $attempt - 1)
        $maxDelay = $this.MaxBackoffSeconds * 1000
        $delay = [Math]::Min($baseDelay, $maxDelay)
        
        # Add jitter (±25% randomization)
        $jitter = $delay * 0.25
        $randomJitter = (Get-Random -Minimum (-$jitter) -Maximum $jitter)
        $finalDelay = [Math]::Max(0, $delay + $randomJitter)
        
        # Store backoff history
        $this.BackoffHistory[$key] = @{
            LastAttempt = [DateTime]::UtcNow
            Attempt = $attempt
            Delay = $finalDelay
        }
        
        return [int]$finalDelay
    }
    
    [void] ResetBackoff([string]$endpoint) {
        $key = "backoff_$endpoint"
        if ($this.BackoffHistory.ContainsKey($key)) {
            $this.BackoffHistory.Remove($key)
        }
    }
    
    [hashtable] GetStats() {
        $this.Mutex.WaitOne() | Out-Null
        
        try {
            $now = [DateTime]::UtcNow
            $oneMinuteAgo = $now.AddMinutes(-1)
            
            # Count recent requests
            $recentRequests = 0
            foreach ($requestTime in $this.RequestTimes) {
                if ($requestTime -gt $oneMinuteAgo) {
                    $recentRequests++
                }
            }
            
            return @{
                MaxRequestsPerMinute = $this.MaxRequestsPerMinute
                RecentRequests = $recentRequests
                RemainingRequests = $this.MaxRequestsPerMinute - $recentRequests
                WaitTimeMs = $this.GetWaitTimeMs()
            }
        } finally {
            $this.Mutex.ReleaseMutex()
        }
    }
}

# Cache entry class for enhanced metadata
class CacheEntry {
    [object] $Data
    [DateTime] $CreatedAt
    [DateTime] $LastAccessedAt
    [DateTime] $ExpiresAt
    [int] $AccessCount
    [string] $CacheType
    [hashtable] $Metadata
    [int] $Priority
    
    CacheEntry([object]$data, [int]$cacheDurationMs, [string]$cacheType = "api", [int]$priority = 0) {
        $this.Data = $data
        $this.CreatedAt = [DateTime]::UtcNow
        $this.LastAccessedAt = [DateTime]::UtcNow
        $this.ExpiresAt = [DateTime]::UtcNow.AddMilliseconds($cacheDurationMs)
        $this.AccessCount = 1
        $this.CacheType = $cacheType
        $this.Metadata = @{}
        $this.Priority = $priority
    }
    
    [void] UpdateAccess() {
        $this.LastAccessedAt = [DateTime]::UtcNow
        $this.AccessCount++
    }
    
    [bool] IsExpired() {
        return [DateTime]::UtcNow -gt $this.ExpiresAt
    }
    
    [void] ExtendExpiry([int]$additionalMs) {
        $this.ExpiresAt = $this.ExpiresAt.AddMilliseconds($additionalMs)
    }
}

# Enhanced cache manager class with persistent storage
class CacheManager {
    [hashtable] $Cache = @{}
    [int] $DefaultCacheDurationMs
    [int] $MaxCacheSize
    [System.Threading.ReaderWriterLockSlim] $Lock
    [string] $PersistentCacheDir
    [bool] $PersistentCacheEnabled
    [hashtable] $CacheTypeSettings = @{}
    [System.Timers.Timer] $CleanupTimer
    
    CacheManager([int]$defaultCacheDurationMs, [int]$maxCacheSize, [string]$persistentCacheDir = "", [bool]$persistentCacheEnabled = $false) {
        $this.DefaultCacheDurationMs = $defaultCacheDurationMs
        $this.MaxCacheSize = $maxCacheSize
        $this.Lock = [System.Threading.ReaderWriterLockSlim]::new()
        $this.PersistentCacheDir = $persistentCacheDir
        $this.PersistentCacheEnabled = $persistentCacheEnabled
        
        # Initialize cache type settings
        $this.InitializeCacheTypeSettings()
        
        # Create persistent cache directory if needed
        if ($this.PersistentCacheEnabled -and -not [string]::IsNullOrWhiteSpace($this.PersistentCacheDir)) {
            if (-not (Test-Path $this.PersistentCacheDir)) {
                New-Item -ItemType Directory -Path $this.PersistentCacheDir -Force | Out-Null
            }
        }
        
        # Start cleanup timer (runs every 5 minutes)
        $this.CleanupTimer = [System.Timers.Timer]::new(300000)
        $this.CleanupTimer.AutoReset = $true
        $this.CleanupTimer.add_Elapsed({ $this.PerformCleanup() })
        $this.CleanupTimer.Start()
        
        # Load persistent cache if enabled
        if ($this.PersistentCacheEnabled) {
            $this.LoadPersistentCache()
        }
    }
    
    [void] InitializeCacheTypeSettings() {
        $this.CacheTypeSettings = @{
            "api" = @{
                CacheDurationMs = $this.DefaultCacheDurationMs
                PersistToDisk = $false
                Priority = 1
            }
            "lyrics" = @{
                CacheDurationMs = 2592000000  # 30 days
                PersistToDisk = $true
                Priority = 3
            }
            "statistics" = @{
                CacheDurationMs = 86400000    # 24 hours
                PersistToDisk = $true
                Priority = 2
            }
            "track_info" = @{
                CacheDurationMs = 3600000     # 1 hour
                PersistToDisk = $false
                Priority = 1
            }
        }
    }
    
    [string] GenerateCacheKey([string]$method, [string]$path, [hashtable]$query, [string]$cacheType = "api") {
        $keyParts = @($cacheType, $method, $path)
        
        if ($query -and $query.Count -gt 0) {
            $sortedQuery = $query.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }
            $keyParts += ($sortedQuery -join "&")
        }
        
        return $keyParts -join "|"
    }
    
    [string] GenerateSimpleCacheKey([string]$identifier, [string]$cacheType) {
        return "$cacheType|$identifier"
    }
    
    [bool] TryGetCachedResponse([string]$cacheKey, [ref]$cachedResponse) {
        $this.Lock.EnterReadLock()
        
        try {
            if (-not $this.Cache.ContainsKey($cacheKey)) {
                # Try loading from persistent cache
                if ($this.PersistentCacheEnabled) {
                    $this.Lock.ExitReadLock()
                    $loaded = $this.LoadFromPersistentCache($cacheKey)
                    $this.Lock.EnterReadLock()
                    
                    if ($loaded -and $this.Cache.ContainsKey($cacheKey)) {
                        # Successfully loaded from disk, continue with normal flow
                    } else {
                        return $false
                    }
                } else {
                    return $false
                }
            }
            
            $entry = $this.Cache[$cacheKey]
            
            if ($entry.IsExpired()) {
                # Cache expired, remove it
                $this.Lock.ExitReadLock()
                $this.Lock.EnterWriteLock()
                
                try {
                    $this.Cache.Remove($cacheKey)
                    if ($this.PersistentCacheEnabled -and $entry.CacheType -in @("lyrics", "statistics")) {
                        $this.RemoveFromPersistentCache($cacheKey)
                    }
                } finally {
                    $this.Lock.ExitWriteLock()
                    $this.Lock.EnterReadLock()
                }
                
                return $false
            }
            
            # Update access information
            $entry.UpdateAccess()
            $cachedResponse.Value = $entry.Data
            return $true
        } finally {
            $this.Lock.ExitReadLock()
        }
    }
    
    [void] CacheResponse([string]$cacheKey, $response, [string]$cacheType = "api", [int]$customDurationMs = 0) {
        $this.Lock.EnterWriteLock()
        
        try {
            # Check cache size and evict entries if necessary
            if ($this.Cache.Count -ge $this.MaxCacheSize) {
                $this.EvictLRUEntries(10) # Remove 10 least recently used entries
            }
            
            # Determine cache duration
            $cacheDurationMs = if ($customDurationMs -gt 0) {
                $customDurationMs
            } elseif ($this.CacheTypeSettings.ContainsKey($cacheType)) {
                $this.CacheTypeSettings[$cacheType].CacheDurationMs
            } else {
                $this.DefaultCacheDurationMs
            }
            
            # Determine priority
            $priority = if ($this.CacheTypeSettings.ContainsKey($cacheType)) {
                $this.CacheTypeSettings[$cacheType].Priority
            } else {
                1
            }
            
            # Create cache entry
            $entry = [CacheEntry]::new($response, $cacheDurationMs, $cacheType, $priority)
            $this.Cache[$cacheKey] = $entry
            
            # Save to persistent cache if applicable
            if ($this.PersistentCacheEnabled -and $this.CacheTypeSettings.ContainsKey($cacheType) -and $this.CacheTypeSettings[$cacheType].PersistToDisk) {
                $this.SaveToPersistentCache($cacheKey, $entry)
            }
        } finally {
            $this.Lock.ExitWriteLock()
        }
    }
    
    [void] EvictLRUEntries([int]$count) {
        # Sort by last accessed time and priority, remove least recently used entries with lowest priority
        $sortedEntries = $this.Cache.GetEnumerator() | 
            Sort-Object { $_.Value.Priority }, { $_.Value.LastAccessedAt } | 
            Select-Object -First $count
        
        foreach ($entry in $sortedEntries) {
            $cacheEntry = $entry.Value
            $this.Cache.Remove($entry.Key)
            
            # Remove from persistent cache if applicable
            if ($this.PersistentCacheEnabled -and $cacheEntry.CacheType -in @("lyrics", "statistics")) {
                $this.RemoveFromPersistentCache($entry.Key)
            }
        }
    }
    
    [void] SaveToPersistentCache([string]$cacheKey, [CacheEntry]$entry) {
        if (-not $this.PersistentCacheEnabled -or [string]::IsNullOrWhiteSpace($this.PersistentCacheDir)) {
            return
        }
        
        try {
            $fileName = [System.Web.HttpUtility]::UrlEncode($cacheKey) + ".json"
            $filePath = Join-Path $this.PersistentCacheDir $fileName
            
            $persistentData = @{
                Data = $entry.Data
                CreatedAt = $entry.CreatedAt.ToString("o")
                ExpiresAt = $entry.ExpiresAt.ToString("o")
                CacheType = $entry.CacheType
                Metadata = $entry.Metadata
                Priority = $entry.Priority
            }
            
            $json = $persistentData | ConvertTo-Json -Depth 10 -Compress
            [System.IO.File]::WriteAllText($filePath, $json, [System.Text.Encoding]::UTF8)
        } catch {
            Write-Warning "Failed to save cache entry to disk: $($_.Exception.Message)"
        }
    }
    
    [bool] LoadFromPersistentCache([string]$cacheKey) {
        if (-not $this.PersistentCacheEnabled -or [string]::IsNullOrWhiteSpace($this.PersistentCacheDir)) {
            return $false
        }
        
        try {
            $fileName = [System.Web.HttpUtility]::UrlEncode($cacheKey) + ".json"
            $filePath = Join-Path $this.PersistentCacheDir $fileName
            
            if (-not (Test-Path $filePath)) {
                return $false
            }
            
            $json = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
            $persistentData = $json | ConvertFrom-Json
            
            # Check if expired
            $expiresAt = [DateTime]::Parse($persistentData.ExpiresAt)
            if ([DateTime]::UtcNow -gt $expiresAt) {
                # Remove expired file
                Remove-Item $filePath -Force -ErrorAction SilentlyContinue
                return $false
            }
            
            # Recreate cache entry
            $createdAt = [DateTime]::Parse($persistentData.CreatedAt)
            $remainingMs = ($expiresAt - [DateTime]::UtcNow).TotalMilliseconds
            
            $entry = [CacheEntry]::new($persistentData.Data, [int]$remainingMs, $persistentData.CacheType, $persistentData.Priority)
            $entry.CreatedAt = $createdAt
            $entry.ExpiresAt = $expiresAt
            $entry.Metadata = $persistentData.Metadata
            
            # Add to memory cache
            $this.Lock.EnterWriteLock()
            try {
                $this.Cache[$cacheKey] = $entry
            } finally {
                $this.Lock.ExitWriteLock()
            }
            
            return $true
        } catch {
            Write-Warning "Failed to load cache entry from disk: $($_.Exception.Message)"
            return $false
        }
    }
    
    [void] LoadPersistentCache() {
        if (-not $this.PersistentCacheEnabled -or [string]::IsNullOrWhiteSpace($this.PersistentCacheDir) -or -not (Test-Path $this.PersistentCacheDir)) {
            return
        }
        
        try {
            $cacheFiles = Get-ChildItem -Path $this.PersistentCacheDir -Filter "*.json" -ErrorAction SilentlyContinue
            $loadedCount = 0
            
            foreach ($file in $cacheFiles) {
                try {
                    $cacheKey = [System.Web.HttpUtility]::UrlDecode($file.BaseName)
                    if ($this.LoadFromPersistentCache($cacheKey)) {
                        $loadedCount++
                    }
                } catch {
                    # Remove corrupted cache file
                    Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                }
            }
            
            Write-Verbose "Loaded $loadedCount cache entries from persistent storage"
        } catch {
            Write-Warning "Failed to load persistent cache: $($_.Exception.Message)"
        }
    }
    
    [void] RemoveFromPersistentCache([string]$cacheKey) {
        if (-not $this.PersistentCacheEnabled -or [string]::IsNullOrWhiteSpace($this.PersistentCacheDir)) {
            return
        }
        
        try {
            $fileName = [System.Web.HttpUtility]::UrlEncode($cacheKey) + ".json"
            $filePath = Join-Path $this.PersistentCacheDir $fileName
            
            if (Test-Path $filePath) {
                Remove-Item $filePath -Force
            }
        } catch {
            Write-Warning "Failed to remove cache entry from disk: $($_.Exception.Message)"
        }
    }
    
    [void] PerformCleanup() {
        $this.Lock.EnterWriteLock()
        
        try {
            $expiredKeys = @()
            
            # Find expired entries
            foreach ($kvp in $this.Cache.GetEnumerator()) {
                if ($kvp.Value.IsExpired()) {
                    $expiredKeys += $kvp.Key
                }
            }
            
            # Remove expired entries
            foreach ($key in $expiredKeys) {
                $entry = $this.Cache[$key]
                $this.Cache.Remove($key)
                
                # Remove from persistent cache if applicable
                if ($this.PersistentCacheEnabled -and $entry.CacheType -in @("lyrics", "statistics")) {
                    $this.RemoveFromPersistentCache($key)
                }
            }
            
            Write-Verbose "Cache cleanup removed $($expiredKeys.Count) expired entries"
        } finally {
            $this.Lock.ExitWriteLock()
        }
    }
    
    [void] ClearCache([string]$cacheType = "") {
        $this.Lock.EnterWriteLock()
        
        try {
            if ([string]::IsNullOrWhiteSpace($cacheType)) {
                # Clear all cache
                foreach ($kvp in $this.Cache.GetEnumerator()) {
                    $entry = $kvp.Value
                    if ($this.PersistentCacheEnabled -and $entry.CacheType -in @("lyrics", "statistics")) {
                        $this.RemoveFromPersistentCache($kvp.Key)
                    }
                }
                $this.Cache.Clear()
            } else {
                # Clear specific cache type
                $keysToRemove = @()
                foreach ($kvp in $this.Cache.GetEnumerator()) {
                    if ($kvp.Value.CacheType -eq $cacheType) {
                        $keysToRemove += $kvp.Key
                    }
                }
                
                foreach ($key in $keysToRemove) {
                    $entry = $this.Cache[$key]
                    $this.Cache.Remove($key)
                    
                    if ($this.PersistentCacheEnabled -and $entry.CacheType -in @("lyrics", "statistics")) {
                        $this.RemoveFromPersistentCache($key)
                    }
                }
            }
        } finally {
            $this.Lock.ExitWriteLock()
        }
    }
    
    [void] InvalidateCache([string]$pattern) {
        $this.Lock.EnterWriteLock()
        
        try {
            $keysToRemove = @()
            
            foreach ($key in $this.Cache.Keys) {
                if ($key -like $pattern) {
                    $keysToRemove += $key
                }
            }
            
            foreach ($key in $keysToRemove) {
                $entry = $this.Cache[$key]
                $this.Cache.Remove($key)
                
                if ($this.PersistentCacheEnabled -and $entry.CacheType -in @("lyrics", "statistics")) {
                    $this.RemoveFromPersistentCache($key)
                }
            }
            
            Write-Verbose "Invalidated $($keysToRemove.Count) cache entries matching pattern: $pattern"
        } finally {
            $this.Lock.ExitWriteLock()
        }
    }
    
    [void] InvalidateCacheByTrack([string]$trackId) {
        $patterns = @(
            "*track*$trackId*",
            "*lyrics*$trackId*",
            "*statistics*$trackId*"
        )
        
        foreach ($pattern in $patterns) {
            $this.InvalidateCache($pattern)
        }
    }
    
    [hashtable] GetCacheStats() {
        $this.Lock.EnterReadLock()
        
        try {
            $now = [DateTime]::UtcNow
            $totalEntries = $this.Cache.Count
            $expiredEntries = 0
            $statsByType = @{}
            $totalAccessCount = 0
            $oldestEntry = $null
            $newestEntry = $null
            
            foreach ($kvp in $this.Cache.GetEnumerator()) {
                $entry = $kvp.Value
                
                if ($entry.IsExpired()) {
                    $expiredEntries++
                }
                
                # Stats by type
                if (-not $statsByType.ContainsKey($entry.CacheType)) {
                    $statsByType[$entry.CacheType] = @{
                        Count = 0
                        TotalAccessCount = 0
                        ExpiredCount = 0
                    }
                }
                
                $statsByType[$entry.CacheType].Count++
                $statsByType[$entry.CacheType].TotalAccessCount += $entry.AccessCount
                
                if ($entry.IsExpired()) {
                    $statsByType[$entry.CacheType].ExpiredCount++
                }
                
                $totalAccessCount += $entry.AccessCount
                
                # Track oldest and newest entries
                if ($oldestEntry -eq $null -or $entry.CreatedAt -lt $oldestEntry.CreatedAt) {
                    $oldestEntry = $entry
                }
                
                if ($newestEntry -eq $null -or $entry.CreatedAt -gt $newestEntry.CreatedAt) {
                    $newestEntry = $entry
                }
            }
            
            return @{
                TotalEntries = $totalEntries
                ExpiredEntries = $expiredEntries
                ValidEntries = $totalEntries - $expiredEntries
                MaxCacheSize = $this.MaxCacheSize
                CacheDurationMs = $this.DefaultCacheDurationMs
                PersistentCacheEnabled = $this.PersistentCacheEnabled
                PersistentCacheDir = $this.PersistentCacheDir
                StatsByType = $statsByType
                TotalAccessCount = $totalAccessCount
                AverageAccessCount = if ($totalEntries -gt 0) { [Math]::Round($totalAccessCount / $totalEntries, 2) } else { 0 }
                OldestEntryAge = if ($oldestEntry) { ($now - $oldestEntry.CreatedAt).TotalMinutes } else { 0 }
                NewestEntryAge = if ($newestEntry) { ($now - $newestEntry.CreatedAt).TotalMinutes } else { 0 }
            }
        } finally {
            $this.Lock.ExitReadLock()
        }
    }
    
    [void] Dispose() {
        if ($this.CleanupTimer) {
            $this.CleanupTimer.Stop()
            $this.CleanupTimer.Dispose()
        }
        
        if ($this.Lock) {
            $this.Lock.Dispose()
        }
    }
}

# Request queue item class
class QueuedRequest {
    [string] $Id
    [string] $Method
    [string] $Path
    [hashtable] $Query
    [object] $Body
    [DateTime] $QueuedAt
    [int] $Priority
    [System.Management.Automation.PowerShell] $Callback
    
    QueuedRequest([string]$method, [string]$path, [hashtable]$query, $body, [int]$priority = 0) {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.Method = $method
        $this.Path = $path
        $this.Query = $query
        $this.Body = $body
        $this.QueuedAt = [DateTime]::UtcNow
        $this.Priority = $priority
    }
}

# Connection pool manager
class ConnectionPoolManager {
    [int] $MaxConnections
    [int] $ConnectionTimeoutMs
    [System.Collections.Concurrent.ConcurrentQueue[System.Net.Http.HttpClient]] $AvailableConnections
    [System.Collections.Generic.HashSet[System.Net.Http.HttpClient]] $ActiveConnections
    [System.Threading.SemaphoreSlim] $ConnectionSemaphore
    [object] $Lock = [object]::new()
    
    ConnectionPoolManager([int]$maxConnections, [int]$connectionTimeoutMs) {
        $this.MaxConnections = $maxConnections
        $this.ConnectionTimeoutMs = $connectionTimeoutMs
        $this.AvailableConnections = [System.Collections.Concurrent.ConcurrentQueue[System.Net.Http.HttpClient]]::new()
        $this.ActiveConnections = [System.Collections.Generic.HashSet[System.Net.Http.HttpClient]]::new()
        $this.ConnectionSemaphore = [System.Threading.SemaphoreSlim]::new($maxConnections, $maxConnections)
        
        # Pre-create connections
        for ($i = 0; $i -lt $maxConnections; $i++) {
            $client = $this.CreateHttpClient()
            $this.AvailableConnections.Enqueue($client)
        }
    }
    
    [System.Net.Http.HttpClient] CreateHttpClient() {
        $client = [System.Net.Http.HttpClient]::new()
        $client.Timeout = [TimeSpan]::FromMilliseconds($this.ConnectionTimeoutMs)
        $client.DefaultRequestHeaders.Add("User-Agent", "SpotifyCLI-Enhanced/1.0")
        return $client
    }
    
    [System.Net.Http.HttpClient] AcquireConnection() {
        $this.ConnectionSemaphore.Wait()
        
        $client = $null
        if (-not $this.AvailableConnections.TryDequeue([ref]$client)) {
            # Create new connection if pool is empty (shouldn't happen with semaphore)
            $client = $this.CreateHttpClient()
        }
        
        lock ($this.Lock) {
            $this.ActiveConnections.Add($client) | Out-Null
        }
        
        return $client
    }
    
    [void] ReleaseConnection([System.Net.Http.HttpClient]$client) {
        if ($client -eq $null) { return }
        
        lock ($this.Lock) {
            if ($this.ActiveConnections.Contains($client)) {
                $this.ActiveConnections.Remove($client) | Out-Null
                $this.AvailableConnections.Enqueue($client)
                $this.ConnectionSemaphore.Release()
            }
        }
    }
    
    [hashtable] GetPoolStats() {
        lock ($this.Lock) {
            return @{
                MaxConnections = $this.MaxConnections
                ActiveConnections = $this.ActiveConnections.Count
                AvailableConnections = $this.AvailableConnections.Count
                ConnectionTimeoutMs = $this.ConnectionTimeoutMs
            }
        }
    }
    
    [void] Dispose() {
        # Dispose all connections
        $client = $null
        while ($this.AvailableConnections.TryDequeue([ref]$client)) {
            $client.Dispose()
        }
        
        lock ($this.Lock) {
            foreach ($client in $this.ActiveConnections) {
                $client.Dispose()
            }
            $this.ActiveConnections.Clear()
        }
        
        $this.ConnectionSemaphore.Dispose()
    }
}

# Enhanced API client class
class EnhancedSpotifyApiClient {
    [string] $ClientId
    [string] $ClientSecret
    [string] $AccessToken
    [string] $RefreshToken
    [DateTime] $TokenExpiry
    [string] $ApiBase = "https://api.spotify.com/v1"
    [int] $TimeoutMs
    [RateLimiter] $RateLimiter
    [CacheManager] $CacheManager
    [ErrorHandler] $ErrorHandler
    [ConnectionPoolManager] $ConnectionPool
    [bool] $CacheEnabled
    [bool] $QueueingEnabled
    [System.Collections.Concurrent.ConcurrentQueue[QueuedRequest]] $RequestQueue
    [System.Threading.CancellationTokenSource] $QueueCancellationToken
    [System.Threading.Tasks.Task] $QueueProcessorTask
    [hashtable] $RequestStats = @{
        TotalRequests = 0
        CacheHits = 0
        CacheMisses = 0
        RateLimitHits = 0
        Errors = 0
        QueuedRequests = 0
        ProcessedRequests = 0
    }
    
    EnhancedSpotifyApiClient([hashtable]$config) {
        $this.ClientId = $config.ClientId
        $this.ClientSecret = $config.ClientSecret
        $this.TimeoutMs = $config.ContainsKey('TimeoutMs') ? $config.TimeoutMs : 10000
        $this.CacheEnabled = $config.ContainsKey('CacheEnabled') ? $config.CacheEnabled : $true
        $this.QueueingEnabled = $config.ContainsKey('QueueingEnabled') ? $config.QueueingEnabled : $false
        
        # Initialize rate limiter
        $maxRequestsPerMinute = $config.ContainsKey('MaxRequestsPerMinute') ? $config.MaxRequestsPerMinute : 60
        $this.RateLimiter = [RateLimiter]::new($maxRequestsPerMinute)
        
        # Initialize cache manager
        $cacheDurationMs = $config.ContainsKey('CacheDurationMs') ? $config.CacheDurationMs : 60000
        $maxCacheSize = $config.ContainsKey('MaxCacheSize') ? $config.MaxCacheSize : 1000
        $persistentCacheDir = $config.ContainsKey('PersistentCacheDir') ? $config.PersistentCacheDir : (Join-Path $env:APPDATA "SpotifyCLI\Cache")
        $persistentCacheEnabled = $config.ContainsKey('PersistentCacheEnabled') ? $config.PersistentCacheEnabled : $true
        $this.CacheManager = [CacheManager]::new($cacheDurationMs, $maxCacheSize, $persistentCacheDir, $persistentCacheEnabled)
        
        # Initialize connection pool
        $maxConnections = $config.ContainsKey('MaxConnections') ? $config.MaxConnections : 5
        $this.ConnectionPool = [ConnectionPoolManager]::new($maxConnections, $this.TimeoutMs)
        
        # Initialize error handler
        $this.ErrorHandler = [ErrorHandler]::new()
        
        # Initialize request queue if enabled
        if ($this.QueueingEnabled) {
            $this.RequestQueue = [System.Collections.Concurrent.ConcurrentQueue[QueuedRequest]]::new()
            $this.QueueCancellationToken = [System.Threading.CancellationTokenSource]::new()
            $this.StartQueueProcessor()
        }
        
        # Load existing tokens
        $this.LoadTokens()
    }
    
    [void] LoadTokens() {
        # This would integrate with the existing token storage system
        # For now, we'll use a placeholder implementation
        try {
            $tokenFile = Join-Path $env:APPDATA "SpotifyCLI\tokens.json"
            if (Test-Path $tokenFile) {
                $json = Get-Content -Path $tokenFile -Raw -Encoding UTF8
                $tokens = $json | ConvertFrom-Json
                
                $this.AccessToken = $tokens.access_token
                $this.RefreshToken = $tokens.refresh_token
                
                if ($tokens.obtained_at -and $tokens.expires_in) {
                    $obtainedAt = [DateTimeOffset]::FromUnixTimeSeconds($tokens.obtained_at).DateTime
                    $this.TokenExpiry = $obtainedAt.AddSeconds($tokens.expires_in)
                }
            }
        } catch {
            Write-Warning "Failed to load tokens: $($_.Exception.Message)"
        }
    }
    
    [bool] IsTokenValid() {
        return -not [string]::IsNullOrWhiteSpace($this.AccessToken) -and 
               $this.TokenExpiry -gt [DateTime]::UtcNow.AddMinutes(5)
    }
    
    [void] RefreshTokenIfNeeded() {
        if ($this.IsTokenValid()) {
            return
        }
        
        if ([string]::IsNullOrWhiteSpace($this.RefreshToken)) {
            throw [AuthenticationException]::new("No refresh token available. Re-authentication required.")
        }
        
        try {
            $body = @{
                grant_type = "refresh_token"
                refresh_token = $this.RefreshToken
                client_id = $this.ClientId
                client_secret = $this.ClientSecret
            }
            
            $response = Invoke-RestMethod -Method Post -Uri "https://accounts.spotify.com/api/token" -Body $body -TimeoutSec ($this.TimeoutMs / 1000)
            
            $this.AccessToken = $response.access_token
            if ($response.refresh_token) {
                $this.RefreshToken = $response.refresh_token
            }
            $this.TokenExpiry = [DateTime]::UtcNow.AddSeconds($response.expires_in)
            
            # Save updated tokens (would integrate with existing token storage)
            Write-Verbose "Token refreshed successfully"
        } catch {
            throw [AuthenticationException]::new("Token refresh failed: $($_.Exception.Message)")
        }
    }
    
    [void] StartQueueProcessor() {
        $this.QueueProcessorTask = [System.Threading.Tasks.Task]::Run({
            while (-not $this.QueueCancellationToken.Token.IsCancellationRequested) {
                try {
                    $request = $null
                    if ($this.RequestQueue.TryDequeue([ref]$request)) {
                        $this.ProcessQueuedRequest($request)
                        $this.RequestStats.ProcessedRequests++
                    } else {
                        Start-Sleep -Milliseconds 100
                    }
                } catch {
                    Write-Warning "Queue processor error: $($_.Exception.Message)"
                    Start-Sleep -Milliseconds 1000
                }
            }
        })
    }
    
    [void] ProcessQueuedRequest([QueuedRequest]$request) {
        try {
            $response = $this.MakeRequestInternal($request.Method, $request.Path, $request.Query, $request.Body)
            
            if ($request.Callback) {
                $request.Callback.AddScript({ param($response) return $response }).Invoke($response)
            }
        } catch {
            if ($request.Callback) {
                $request.Callback.AddScript({ param($error) throw $error }).Invoke($_)
            }
        }
    }
    
    [object] MakeRequest([string]$method, [string]$path, [hashtable]$query, $body) {
        if ($this.QueueingEnabled -and $method -ne "GET") {
            # Queue non-GET requests for background processing
            $request = [QueuedRequest]::new($method, $path, $query, $body)
            $this.RequestQueue.Enqueue($request)
            $this.RequestStats.QueuedRequests++
            return $null # Async operation
        }
        
        return $this.MakeRequestInternal($method, $path, $query, $body)
    }
    
    [object] MakeRequestInternal([string]$method, [string]$path, [hashtable]$query, $body) {
        $this.RequestStats.TotalRequests++
        $attempt = 1
        $maxAttempts = 3
        
        while ($attempt -le $maxAttempts) {
            try {
                # Check cache first (only for GET requests)
                if ($method -eq "GET" -and $this.CacheEnabled) {
                    $cacheType = $this.DetermineCacheType($path)
                    $cacheKey = $this.CacheManager.GenerateCacheKey($method, $path, $query, $cacheType)
                    $cachedResponse = $null
                    
                    if ($this.CacheManager.TryGetCachedResponse($cacheKey, [ref]$cachedResponse)) {
                        $this.RequestStats.CacheHits++
                        return $cachedResponse
                    }
                    
                    $this.RequestStats.CacheMisses++
                }
                
                # Check rate limit
                if (-not $this.RateLimiter.CanMakeRequest()) {
                    $waitTime = $this.RateLimiter.GetWaitTimeMs()
                    $this.RequestStats.RateLimitHits++
                    
                    if ($waitTime -gt 0) {
                        Start-Sleep -Milliseconds $waitTime
                    }
                }
                
                # Ensure token is valid
                $this.RefreshTokenIfNeeded()
                
                # Build URI
                $uri = "$($this.ApiBase)$path"
                if ($query -and $query.Count -gt 0) {
                    $queryString = ($query.GetEnumerator() | ForEach-Object {
                        "$($_.Key)=$([System.Uri]::EscapeDataString($_.Value))"
                    }) -join "&"
                    $uri += "?$queryString"
                }
                
                # Prepare headers
                $headers = @{
                    'Authorization' = "Bearer $($this.AccessToken)"
                    'Content-Type' = 'application/json'
                }
                
                # Record the request
                $this.RateLimiter.RecordRequest()
                
                # Make the request using connection pool
                $httpClient = $this.ConnectionPool.AcquireConnection()
                
                try {
                    # Make the request
                    $response = if ($body) {
                        Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body ($body | ConvertTo-Json -Depth 10) -TimeoutSec ($this.TimeoutMs / 1000)
                    } else {
                        Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -TimeoutSec ($this.TimeoutMs / 1000)
                    }
                    
                    # Cache the response (only for GET requests)
                    if ($method -eq "GET" -and $this.CacheEnabled) {
                        $cacheType = $this.DetermineCacheType($path)
                        $cacheKey = $this.CacheManager.GenerateCacheKey($method, $path, $query, $cacheType)
                        $this.CacheManager.CacheResponse($cacheKey, $response, $cacheType)
                    }
                    
                    # Reset backoff on success
                    $this.RateLimiter.ResetBackoff($path)
                    
                    return $response
                } finally {
                    $this.ConnectionPool.ReleaseConnection($httpClient)
                }
                
            } catch [System.Net.WebException] {
                $this.RequestStats.Errors++
                
                $statusCode = 0
                $responseBody = ""
                
                if ($_.Exception.Response) {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                    
                    try {
                        $stream = $_.Exception.Response.GetResponseStream()
                        $reader = [System.IO.StreamReader]::new($stream)
                        $responseBody = $reader.ReadToEnd()
                    } catch {
                        $responseBody = "Unable to read response body"
                    }
                }
                
                # Handle retryable errors with exponential backoff
                if ($statusCode -in @(429, 500, 502, 503, 504) -and $attempt -lt $maxAttempts) {
                    $backoffDelay = $this.RateLimiter.GetExponentialBackoffDelay($path, $attempt)
                    Write-Verbose "Request failed with status $statusCode. Retrying in $backoffDelay ms (attempt $($attempt + 1)/$maxAttempts)"
                    Start-Sleep -Milliseconds $backoffDelay
                    $attempt++
                    continue
                }
                
                # Create appropriate exception based on status code
                switch ($statusCode) {
                    401 { throw [AuthenticationException]::new("Authentication failed") }
                    429 { 
                        $retryAfter = 60 # Default retry after 60 seconds
                        if ($_.Exception.Response.Headers["Retry-After"]) {
                            $retryAfter = [int]$_.Exception.Response.Headers["Retry-After"]
                        }
                        throw [RateLimitException]::new($retryAfter)
                    }
                    default { 
                        throw [ApiClientException]::new("API request failed: $($_.Exception.Message)", $statusCode, $responseBody)
                    }
                }
            } catch {
                $this.RequestStats.Errors++
                
                # Handle retryable network errors
                if ($attempt -lt $maxAttempts) {
                    $backoffDelay = $this.RateLimiter.GetExponentialBackoffDelay($path, $attempt)
                    Write-Verbose "Request failed with network error. Retrying in $backoffDelay ms (attempt $($attempt + 1)/$maxAttempts)"
                    Start-Sleep -Milliseconds $backoffDelay
                    $attempt++
                    continue
                }
                
                throw [ApiClientException]::new("Request failed: $($_.Exception.Message)")
            }
        }
        
        throw [ApiClientException]::new("Maximum retry attempts exceeded")
    }
    
    [object] Get([string]$path, [hashtable]$query = @{}) {
        return $this.MakeRequest("GET", $path, $query, $null)
    }
    
    [object] Post([string]$path, $body, [hashtable]$query = @{}) {
        return $this.MakeRequest("POST", $path, $query, $body)
    }
    
    [object] Put([string]$path, $body, [hashtable]$query = @{}) {
        return $this.MakeRequest("PUT", $path, $query, $body)
    }
    
    [object] Delete([string]$path, [hashtable]$query = @{}) {
        return $this.MakeRequest("DELETE", $path, $query, $null)
    }
    
    [hashtable] GetStats() {
        $rateLimiterStats = $this.RateLimiter.GetStats()
        $cacheStats = $this.CacheManager.GetCacheStats()
        $connectionPoolStats = $this.ConnectionPool.GetPoolStats()
        
        $stats = @{
            Requests = $this.RequestStats.Clone()
            RateLimit = $rateLimiterStats
            Cache = $cacheStats
            ConnectionPool = $connectionPoolStats
            TokenExpiry = $this.TokenExpiry
            IsTokenValid = $this.IsTokenValid()
        }
        
        if ($this.QueueingEnabled) {
            $stats.Queue = @{
                QueueSize = $this.RequestQueue.Count
                QueueingEnabled = $this.QueueingEnabled
                ProcessorRunning = $this.QueueProcessorTask -and -not $this.QueueProcessorTask.IsCompleted
            }
        }
        
        return $stats
    }
    
    [void] ClearCache() {
        $this.CacheManager.ClearCache()
    }
    
    [void] ResetStats() {
        $this.RequestStats = @{
            TotalRequests = 0
            CacheHits = 0
            CacheMisses = 0
            RateLimitHits = 0
            Errors = 0
            QueuedRequests = 0
            ProcessedRequests = 0
        }
    }
    
    [void] StopQueueProcessor() {
        if ($this.QueueCancellationToken) {
            $this.QueueCancellationToken.Cancel()
        }
        
        if ($this.QueueProcessorTask) {
            try {
                $this.QueueProcessorTask.Wait(5000) # Wait up to 5 seconds
            } catch {
                Write-Warning "Queue processor did not stop gracefully"
            }
        }
    }
    
    [string] DetermineCacheType([string]$path) {
        if ($path -like "*track*") {
            return "track_info"
        } elseif ($path -like "*lyrics*" -or $path -like "*genius*" -or $path -like "*musixmatch*") {
            return "lyrics"
        } elseif ($path -like "*stats*" -or $path -like "*analytics*" -or $path -like "*top*" -or $path -like "*recently-played*") {
            return "statistics"
        } else {
            return "api"
        }
    }
    
    [void] CacheLyrics([string]$trackId, [string]$artist, [string]$title, $lyricsData) {
        $cacheKey = $this.CacheManager.GenerateSimpleCacheKey("$trackId|$artist|$title", "lyrics")
        $this.CacheManager.CacheResponse($cacheKey, $lyricsData, "lyrics")
    }
    
    [object] GetCachedLyrics([string]$trackId, [string]$artist, [string]$title) {
        $cacheKey = $this.CacheManager.GenerateSimpleCacheKey("$trackId|$artist|$title", "lyrics")
        $cachedResponse = $null
        
        if ($this.CacheManager.TryGetCachedResponse($cacheKey, [ref]$cachedResponse)) {
            return $cachedResponse
        }
        
        return $null
    }
    
    [void] CacheStatistics([string]$userId, [string]$period, $statisticsData) {
        $cacheKey = $this.CacheManager.GenerateSimpleCacheKey("$userId|$period", "statistics")
        $this.CacheManager.CacheResponse($cacheKey, $statisticsData, "statistics")
    }
    
    [object] GetCachedStatistics([string]$userId, [string]$period) {
        $cacheKey = $this.CacheManager.GenerateSimpleCacheKey("$userId|$period", "statistics")
        $cachedResponse = $null
        
        if ($this.CacheManager.TryGetCachedResponse($cacheKey, [ref]$cachedResponse)) {
            return $cachedResponse
        }
        
        return $null
    }
    
    [void] InvalidateTrackCache([string]$trackId) {
        $this.CacheManager.InvalidateCacheByTrack($trackId)
    }
    
    [void] Dispose() {
        $this.StopQueueProcessor()
        
        if ($this.ConnectionPool) {
            $this.ConnectionPool.Dispose()
        }
        
        if ($this.CacheManager) {
            $this.CacheManager.Dispose()
        }
        
        if ($this.QueueCancellationToken) {
            $this.QueueCancellationToken.Dispose()
        }
    }
}

# API Client Manager factory
class ApiClientManager {
    static [EnhancedSpotifyApiClient] CreateClient([hashtable]$config) {
        # Set default values
        $defaultConfig = @{
            ClientId = $env:SPOTIFY_CLIENT_ID
            ClientSecret = $env:SPOTIFY_CLIENT_SECRET
            TimeoutMs = 10000
            MaxRequestsPerMinute = 60
            CacheEnabled = $true
            CacheDurationMs = 60000
            MaxCacheSize = 1000
            MaxConnections = 5
            QueueingEnabled = $false
            PersistentCacheEnabled = $true
            PersistentCacheDir = (Join-Path $env:APPDATA "SpotifyCLI\Cache")
        }
        
        # Merge with provided config
        foreach ($key in $config.Keys) {
            $defaultConfig[$key] = $config[$key]
        }
        
        # Validate required settings
        if ([string]::IsNullOrWhiteSpace($defaultConfig.ClientId)) {
            throw [ConfigurationException]::new("Spotify Client ID not configured")
        }
        
        if ([string]::IsNullOrWhiteSpace($defaultConfig.ClientSecret)) {
            throw [ConfigurationException]::new("Spotify Client Secret not configured")
        }
        
        return [EnhancedSpotifyApiClient]::new($defaultConfig)
    }
    
    static [EnhancedSpotifyApiClient] CreateDefaultClient() {
        return [ApiClientManager]::CreateClient(@{})
    }
}

# Helper functions for backward compatibility
function New-EnhancedSpotifyApiClient {
    param(
        [hashtable]$Configuration = @{}
    )
    
    return [ApiClientManager]::CreateClient($Configuration)
}

function Get-SpotifyApiClientStats {
    param(
        [Parameter(Mandatory)]
        [EnhancedSpotifyApiClient]$Client
    )
    
    return $Client.GetStats()
}

function Clear-SpotifyApiClientCache {
    param(
        [Parameter(Mandatory)]
        [EnhancedSpotifyApiClient]$Client
    )
    
    $Client.ClearCache()
}

function Reset-SpotifyApiClientStats {
    param(
        [Parameter(Mandatory)]
        [EnhancedSpotifyApiClient]$Client
    )
    
    $Client.ResetStats()
}

function Set-SpotifyApiClientCacheType {
    param(
        [Parameter(Mandatory)]
        [EnhancedSpotifyApiClient]$Client,
        
        [Parameter(Mandatory)]
        [string]$CacheType,
        
        [int]$CacheDurationMs,
        
        [bool]$PersistToDisk,
        
        [int]$Priority = 1
    )
    
    $settings = @{
        Priority = $Priority
    }
    
    if ($CacheDurationMs -gt 0) {
        $settings.CacheDurationMs = $CacheDurationMs
    }
    
    if ($PSBoundParameters.ContainsKey('PersistToDisk')) {
        $settings.PersistToDisk = $PersistToDisk
    }
    
    $Client.CacheManager.CacheTypeSettings[$CacheType] = $settings
}

function Get-SpotifyApiClientCacheStats {
    param(
        [Parameter(Mandatory)]
        [EnhancedSpotifyApiClient]$Client,
        
        [string]$CacheType = ""
    )
    
    $stats = $Client.CacheManager.GetCacheStats()
    
    if (-not [string]::IsNullOrWhiteSpace($CacheType) -and $stats.StatsByType.ContainsKey($CacheType)) {
        return $stats.StatsByType[$CacheType]
    }
    
    return $stats
}

function Clear-SpotifyApiClientCacheByType {
    param(
        [Parameter(Mandatory)]
        [EnhancedSpotifyApiClient]$Client,
        
        [string]$CacheType = ""
    )
    
    $Client.CacheManager.ClearCache($CacheType)
}

function Invoke-SpotifyApiClientCacheCleanup {
    param(
        [Parameter(Mandatory)]
        [EnhancedSpotifyApiClient]$Client
    )
    
    $Client.CacheManager.PerformCleanup()
}

# Export functions and classes
Export-ModuleMember -Function @(
    'New-EnhancedSpotifyApiClient',
    'Get-SpotifyApiClientStats',
    'Clear-SpotifyApiClientCache',
    'Reset-SpotifyApiClientStats',
    'Set-SpotifyApiClientCacheType',
    'Get-SpotifyApiClientCacheStats',
    'Clear-SpotifyApiClientCacheByType',
    'Invoke-SpotifyApiClientCacheCleanup'
) -Variable @()