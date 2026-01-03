# Performance Optimizer Module for Live Display
# Implements differential screen updates, frame rate limiting, and memory optimization

using namespace System.Management.Automation
using namespace System.Text
using namespace System.Collections.Generic

# Differential screen update manager
class DifferentialScreenUpdater {
    [hashtable] $LastScreenState = @{}
    [StringBuilder] $UpdateBuffer
    [int] $ScreenWidth = 80
    [int] $ScreenHeight = 24
    [hashtable] $DirtyRegions = @{}
    [bool] $FullRedrawRequired = $true
    [int] $UpdateCount = 0
    [DateTime] $LastFullRedraw = [DateTime]::MinValue
    [int] $FullRedrawInterval = 30000  # Force full redraw every 30 seconds
    
    DifferentialScreenUpdater() {
        $this.UpdateBuffer = [StringBuilder]::new()
        $this.DetectScreenSize()
    }
    
    [void] DetectScreenSize() {
        try {
            $this.ScreenWidth = $Host.UI.RawUI.WindowSize.Width
            $this.ScreenHeight = $Host.UI.RawUI.WindowSize.Height
        } catch {
            # Use defaults if detection fails
            $this.ScreenWidth = 80
            $this.ScreenHeight = 24
        }
    }
    
    [bool] HasContentChanged([hashtable]$newContent) {
        if ($this.FullRedrawRequired) {
            return $true
        }
        
        # Check if screen size changed
        $this.DetectScreenSize()
        if ($this.LastScreenState.ContainsKey('ScreenWidth') -and 
            ($this.LastScreenState.ScreenWidth -ne $this.ScreenWidth -or 
             $this.LastScreenState.ScreenHeight -ne $this.ScreenHeight)) {
            $this.FullRedrawRequired = $true
            return $true
        }
        
        # Check for content changes
        $keyFields = @('track_id', 'track_name', 'artist_name', 'album_name', 'is_playing', 'progress_ms', 'duration_ms')
        
        foreach ($field in $keyFields) {
            $oldValue = $this.LastScreenState.ContainsKey($field) ? $this.LastScreenState[$field] : $null
            $newValue = $newContent.ContainsKey($field) ? $newContent[$field] : $null
            
            if ($field -eq 'progress_ms') {
                # Only update progress if change is significant (> 2 seconds) to reduce flicker
                if ($oldValue -and $newValue) {
                    $diff = [Math]::Abs($newValue - $oldValue)
                    if ($diff -gt 2000) {
                        $this.DirtyRegions['progress'] = $true
                        return $true
                    }
                } elseif ($oldValue -ne $newValue) {
                    $this.DirtyRegions['progress'] = $true
                    return $true
                }
            } else {
                if ($oldValue -ne $newValue) {
                    $this.DirtyRegions[$field] = $true
                    return $true
                }
            }
        }
        
        # Force full redraw periodically to prevent display corruption
        $timeSinceLastFullRedraw = [DateTime]::UtcNow - $this.LastFullRedraw
        if ($timeSinceLastFullRedraw.TotalMilliseconds -gt $this.FullRedrawInterval) {
            $this.FullRedrawRequired = $true
            return $true
        }
        
        return $false
    }
    
    [string] GenerateDifferentialUpdate([hashtable]$newContent) {
        $this.UpdateBuffer.Clear()
        
        if ($this.FullRedrawRequired) {
            # Full screen update
            $this.UpdateBuffer.Append([AnsiCodes]::ClearScreen) | Out-Null
            $this.UpdateBuffer.Append([AnsiCodes]::CursorHome) | Out-Null
            $this.GenerateFullDisplay($newContent)
            $this.FullRedrawRequired = $false
            $this.LastFullRedraw = [DateTime]::UtcNow
        } else {
            # Partial updates for dirty regions
            $this.GeneratePartialUpdates($newContent)
        }
        
        # Update last screen state
        $this.LastScreenState = $newContent.Clone()
        $this.LastScreenState['ScreenWidth'] = $this.ScreenWidth
        $this.LastScreenState['ScreenHeight'] = $this.ScreenHeight
        $this.UpdateCount++
        
        # Clear dirty regions
        $this.DirtyRegions.Clear()
        
        return $this.UpdateBuffer.ToString()
    }
    
    [void] GenerateFullDisplay([hashtable]$content) {
        # Header
        $this.UpdateBuffer.AppendLine("╔══════════════════════════════════════════════════════════════════════════════╗") | Out-Null
        $this.UpdateBuffer.AppendLine("║                              Spotify Live Display                           ║") | Out-Null
        $this.UpdateBuffer.AppendLine("╠══════════════════════════════════════════════════════════════════════════════╣") | Out-Null
        
        # Track information
        $this.AppendTrackInfo($content)
        
        # Progress bar
        $this.AppendProgressBar($content)
        
        # Footer
        $this.UpdateBuffer.AppendLine("╚══════════════════════════════════════════════════════════════════════════════╝") | Out-Null
    }
    
    [void] GeneratePartialUpdates([hashtable]$content) {
        # Update only changed regions
        if ($this.DirtyRegions.ContainsKey('track_name') -or 
            $this.DirtyRegions.ContainsKey('artist_name') -or 
            $this.DirtyRegions.ContainsKey('album_name') -or 
            $this.DirtyRegions.ContainsKey('is_playing')) {
            
            # Move to track info area and update
            $this.UpdateBuffer.Append([AnsiCodes]::MoveCursor(4, 1)) | Out-Null
            $this.AppendTrackInfo($content)
        }
        
        if ($this.DirtyRegions.ContainsKey('progress')) {
            # Move to progress bar area and update
            $this.UpdateBuffer.Append([AnsiCodes]::MoveCursor(8, 1)) | Out-Null
            $this.AppendProgressBar($content)
        }
    }
    
    [void] AppendTrackInfo([hashtable]$content) {
        $isPlaying = $content.ContainsKey('is_playing') ? $content.is_playing : $false
        $statusIcon = if ($isPlaying) { "▶" } else { "⏸" }
        
        # Track name
        $trackName = $content.ContainsKey('track_name') ? $content.track_name : "Unknown Track"
        if ($trackName.Length -gt 70) { $trackName = $trackName.Substring(0, 67) + "..." }
        $this.UpdateBuffer.AppendLine("║ $statusIcon $($trackName.PadRight(72)) ║") | Out-Null
        
        # Artist
        $artistName = $content.ContainsKey('artist_name') ? $content.artist_name : "Unknown Artist"
        if ($artistName.Length -gt 70) { $artistName = $artistName.Substring(0, 67) + "..." }
        $this.UpdateBuffer.AppendLine("║ 👤 $($artistName.PadRight(72)) ║") | Out-Null
        
        # Album
        $albumName = $content.ContainsKey('album_name') ? $content.album_name : "Unknown Album"
        if ($albumName.Length -gt 70) { $albumName = $albumName.Substring(0, 67) + "..." }
        $this.UpdateBuffer.AppendLine("║ 📀 $($albumName.PadRight(72)) ║") | Out-Null
    }
    
    [void] AppendProgressBar([hashtable]$content) {
        if ($content.ContainsKey('duration_ms') -and $content.duration_ms -gt 0) {
            $progress = $content.ContainsKey('progress_ms') ? $content.progress_ms : 0
            $percentage = [Math]::Round(($progress / $content.duration_ms) * 100)
            
            $barWidth = 60
            $filled = [Math]::Floor(($percentage / 100) * $barWidth)
            $empty = $barWidth - $filled
            
            $progressBar = ("█" * $filled) + ("░" * $empty)
            $this.UpdateBuffer.AppendLine("║ [$progressBar] $($percentage.ToString().PadLeft(3))% ║") | Out-Null
            
            $currentTime = $this.FormatDuration($progress)
            $totalTime = $this.FormatDuration($content.duration_ms)
            $timeDisplay = "$currentTime / $totalTime"
            $this.UpdateBuffer.AppendLine("║ $($timeDisplay.PadRight(76)) ║") | Out-Null
        } else {
            $this.UpdateBuffer.AppendLine("║ No playback information available                                            ║") | Out-Null
            $this.UpdateBuffer.AppendLine("║                                                                              ║") | Out-Null
        }
    }
    
    [string] FormatDuration([int]$milliseconds) {
        $totalSeconds = [Math]::Floor($milliseconds / 1000)
        $minutes = [Math]::Floor($totalSeconds / 60)
        $seconds = $totalSeconds % 60
        return "{0}:{1:D2}" -f $minutes, $seconds
    }
    
    [void] ForceFullRedraw() {
        $this.FullRedrawRequired = $true
    }
    
    [hashtable] GetStats() {
        return @{
            UpdateCount = $this.UpdateCount
            LastFullRedraw = $this.LastFullRedraw
            ScreenSize = @{ Width = $this.ScreenWidth; Height = $this.ScreenHeight }
            DirtyRegions = $this.DirtyRegions.Keys -join ", "
        }
    }
}

# Frame rate limiter with adaptive refresh intervals
class FrameRateLimiter {
    [int] $TargetFPS = 2  # 2 FPS for live display (500ms intervals)
    [int] $MinRefreshInterval = 500   # Minimum 500ms
    [int] $MaxRefreshInterval = 5000  # Maximum 5 seconds
    [DateTime] $LastFrameTime = [DateTime]::MinValue
    [Queue[DateTime]] $FrameHistory
    [int] $FrameHistorySize = 10
    [bool] $AdaptiveMode = $true
    [int] $CurrentRefreshInterval
    [int] $ConsecutiveSkippedFrames = 0
    [int] $MaxSkippedFrames = 3
    
    FrameRateLimiter([int]$targetFPS = 2, [bool]$adaptiveMode = $true) {
        $this.TargetFPS = $targetFPS
        $this.AdaptiveMode = $adaptiveMode
        $this.CurrentRefreshInterval = [Math]::Max($this.MinRefreshInterval, 1000 / $this.TargetFPS)
        $this.FrameHistory = [Queue[DateTime]]::new()
    }
    
    [bool] ShouldRender() {
        $now = [DateTime]::UtcNow
        $timeSinceLastFrame = $now - $this.LastFrameTime
        
        if ($timeSinceLastFrame.TotalMilliseconds -ge $this.CurrentRefreshInterval) {
            $this.RecordFrame($now)
            $this.ConsecutiveSkippedFrames = 0
            
            if ($this.AdaptiveMode) {
                $this.AdjustRefreshInterval()
            }
            
            return $true
        }
        
        $this.ConsecutiveSkippedFrames++
        return $false
    }
    
    [void] RecordFrame([DateTime]$frameTime) {
        $this.LastFrameTime = $frameTime
        $this.FrameHistory.Enqueue($frameTime)
        
        # Keep frame history size manageable
        while ($this.FrameHistory.Count -gt $this.FrameHistorySize) {
            $this.FrameHistory.Dequeue() | Out-Null
        }
    }
    
    [void] AdjustRefreshInterval() {
        if ($this.FrameHistory.Count -lt 3) {
            return
        }
        
        # Calculate actual FPS from recent frames
        $frames = $this.FrameHistory.ToArray()
        $timeSpan = $frames[-1] - $frames[0]
        $actualFPS = ($frames.Length - 1) / $timeSpan.TotalSeconds
        
        # Adjust refresh interval based on performance
        if ($actualFPS -lt ($this.TargetFPS * 0.8)) {
            # Running slower than target, increase interval
            $this.CurrentRefreshInterval = [Math]::Min($this.MaxRefreshInterval, $this.CurrentRefreshInterval * 1.2)
        } elseif ($actualFPS -gt ($this.TargetFPS * 1.2)) {
            # Running faster than target, decrease interval
            $this.CurrentRefreshInterval = [Math]::Max($this.MinRefreshInterval, $this.CurrentRefreshInterval * 0.8)
        }
    }
    
    [int] GetWaitTime() {
        $now = [DateTime]::UtcNow
        $timeSinceLastFrame = $now - $this.LastFrameTime
        $waitTime = $this.CurrentRefreshInterval - $timeSinceLastFrame.TotalMilliseconds
        return [Math]::Max(0, [int]$waitTime)
    }
    
    [double] GetCurrentFPS() {
        if ($this.FrameHistory.Count -lt 2) {
            return 0
        }
        
        $frames = $this.FrameHistory.ToArray()
        $timeSpan = $frames[-1] - $frames[0]
        return ($frames.Length - 1) / $timeSpan.TotalSeconds
    }
    
    [hashtable] GetStats() {
        return @{
            TargetFPS = $this.TargetFPS
            CurrentFPS = $this.GetCurrentFPS()
            CurrentRefreshInterval = $this.CurrentRefreshInterval
            ConsecutiveSkippedFrames = $this.ConsecutiveSkippedFrames
            AdaptiveMode = $this.AdaptiveMode
            FrameHistoryCount = $this.FrameHistory.Count
        }
    }
    
    [void] SetTargetFPS([int]$fps) {
        $this.TargetFPS = [Math]::Max(1, [Math]::Min(10, $fps))
        $this.CurrentRefreshInterval = [Math]::Max($this.MinRefreshInterval, 1000 / $this.TargetFPS)
    }
}

# Memory optimizer for long-running live sessions
class MemoryOptimizer {
    [int] $MaxMemoryUsageMB = 100
    [DateTime] $LastCleanup = [DateTime]::UtcNow
    [int] $CleanupIntervalMs = 60000  # Cleanup every minute
    [hashtable] $MemoryStats = @{}
    [System.GC] $GarbageCollector
    [int] $ForceGCThresholdMB = 80
    [Queue[hashtable]] $MemoryHistory
    [int] $MemoryHistorySize = 20
    
    MemoryOptimizer([int]$maxMemoryUsageMB = 100) {
        $this.MaxMemoryUsageMB = $maxMemoryUsageMB
        $this.MemoryHistory = [Queue[hashtable]]::new()
        $this.UpdateMemoryStats()
    }
    
    [void] UpdateMemoryStats() {
        try {
            $process = Get-Process -Id $PID
            $workingSetMB = [Math]::Round($process.WorkingSet64 / 1MB, 2)
            $privateMemoryMB = [Math]::Round($process.PrivateMemorySize64 / 1MB, 2)
            
            $this.MemoryStats = @{
                WorkingSetMB = $workingSetMB
                PrivateMemoryMB = $privateMemoryMB
                Timestamp = [DateTime]::UtcNow
                GCTotalMemoryMB = [Math]::Round([GC]::GetTotalMemory($false) / 1MB, 2)
            }
            
            # Add to history
            $this.MemoryHistory.Enqueue($this.MemoryStats.Clone())
            while ($this.MemoryHistory.Count -gt $this.MemoryHistorySize) {
                $this.MemoryHistory.Dequeue() | Out-Null
            }
            
        } catch {
            Write-Warning "Failed to update memory stats: $($_.Exception.Message)"
        }
    }
    
    [bool] ShouldPerformCleanup() {
        $this.UpdateMemoryStats()
        
        $timeSinceLastCleanup = [DateTime]::UtcNow - $this.LastCleanup
        $memoryPressure = $this.MemoryStats.WorkingSetMB -gt $this.MaxMemoryUsageMB
        $timeForScheduledCleanup = $timeSinceLastCleanup.TotalMilliseconds -gt $this.CleanupIntervalMs
        
        return $memoryPressure -or $timeForScheduledCleanup
    }
    
    [void] PerformCleanup() {
        try {
            $beforeMemory = $this.MemoryStats.WorkingSetMB
            
            # Force garbage collection if memory usage is high
            if ($this.MemoryStats.WorkingSetMB -gt $this.ForceGCThresholdMB) {
                [GC]::Collect()
                [GC]::WaitForPendingFinalizers()
                [GC]::Collect()
            }
            
            # Update memory stats after cleanup
            $this.UpdateMemoryStats()
            $afterMemory = $this.MemoryStats.WorkingSetMB
            
            $this.LastCleanup = [DateTime]::UtcNow
            
            Write-Verbose "Memory cleanup completed. Before: $beforeMemory MB, After: $afterMemory MB"
            
        } catch {
            Write-Warning "Error during memory cleanup: $($_.Exception.Message)"
        }
    }
    
    [hashtable] GetMemoryTrend() {
        if ($this.MemoryHistory.Count -lt 2) {
            return @{ Trend = "Unknown"; Change = 0 }
        }
        
        $history = $this.MemoryHistory.ToArray()
        $oldest = $history[0]
        $newest = $history[-1]
        
        $change = $newest.WorkingSetMB - $oldest.WorkingSetMB
        $trend = if ($change -gt 5) { "Increasing" } elseif ($change -lt -5) { "Decreasing" } else { "Stable" }
        
        return @{
            Trend = $trend
            Change = [Math]::Round($change, 2)
            TimeSpan = $newest.Timestamp - $oldest.Timestamp
        }
    }
    
    [hashtable] GetStats() {
        $this.UpdateMemoryStats()
        $trend = $this.GetMemoryTrend()
        
        return @{
            Current = $this.MemoryStats
            MaxMemoryUsageMB = $this.MaxMemoryUsageMB
            LastCleanup = $this.LastCleanup
            Trend = $trend
            HistoryCount = $this.MemoryHistory.Count
        }
    }
    
    [bool] IsMemoryUsageHealthy() {
        $this.UpdateMemoryStats()
        return $this.MemoryStats.WorkingSetMB -lt ($this.MaxMemoryUsageMB * 0.9)
    }
}

# Optimized Console Renderer with performance enhancements
class OptimizedConsoleRenderer : ConsoleRenderer {
    [DifferentialScreenUpdater] $ScreenUpdater
    [FrameRateLimiter] $FrameLimiter
    [MemoryOptimizer] $MemoryOptimizer
    [bool] $PerformanceMode = $true
    [hashtable] $PerformanceStats = @{}
    [DateTime] $LastStatsUpdate = [DateTime]::UtcNow
    
    OptimizedConsoleRenderer([bool]$performanceMode = $true) : base() {
        $this.PerformanceMode = $performanceMode
        
        if ($this.PerformanceMode) {
            $this.ScreenUpdater = [DifferentialScreenUpdater]::new()
            $this.FrameLimiter = [FrameRateLimiter]::new(2, $true)  # 2 FPS with adaptive mode
            $this.MemoryOptimizer = [MemoryOptimizer]::new(100)     # 100MB limit
        }
    }
    
    [void] UpdateTrackInfo([hashtable]$trackData) {
        if (-not $this.PerformanceMode) {
            # Fall back to base implementation
            ([ConsoleRenderer]$this).UpdateTrackInfo($trackData)
            return
        }
        
        # Check if we should render this frame
        if (-not $this.FrameLimiter.ShouldRender()) {
            return
        }
        
        # Prepare content for differential update
        $content = $this.PrepareContentForUpdate($trackData)
        
        # Check if content has changed
        if (-not $this.ScreenUpdater.HasContentChanged($content)) {
            return
        }
        
        # Generate and apply differential update
        $updateString = $this.ScreenUpdater.GenerateDifferentialUpdate($content)
        
        if (-not [string]::IsNullOrEmpty($updateString)) {
            [Console]::Write($updateString)
        }
        
        # Perform memory cleanup if needed
        if ($this.MemoryOptimizer.ShouldPerformCleanup()) {
            $this.MemoryOptimizer.PerformCleanup()
        }
        
        # Update performance stats periodically
        $this.UpdatePerformanceStats()
    }
    
    [hashtable] PrepareContentForUpdate([hashtable]$trackData) {
        $content = @{}
        
        if ($trackData) {
            $content['track_id'] = $trackData.ContainsKey('id') ? $trackData.id : ""
            $content['track_name'] = $trackData.ContainsKey('name') ? $trackData.name : "Unknown Track"
            $content['is_playing'] = $trackData.ContainsKey('is_playing') ? $trackData.is_playing : $false
            $content['progress_ms'] = $trackData.ContainsKey('progress_ms') ? $trackData.progress_ms : 0
            $content['duration_ms'] = $trackData.ContainsKey('duration_ms') ? $trackData.duration_ms : 0
            
            # Handle artists
            if ($trackData.ContainsKey('artists') -and $trackData.artists) {
                $content['artist_name'] = if ($trackData.artists -is [array]) {
                    ($trackData.artists | ForEach-Object { if ($_ -is [hashtable]) { $_.name } else { $_ } }) -join ", "
                } else {
                    $trackData.artists
                }
            } else {
                $content['artist_name'] = "Unknown Artist"
            }
            
            # Handle album
            if ($trackData.ContainsKey('album') -and $trackData.album) {
                $content['album_name'] = if ($trackData.album -is [hashtable]) { $trackData.album.name } else { $trackData.album }
            } else {
                $content['album_name'] = "Unknown Album"
            }
        }
        
        return $content
    }
    
    [void] UpdatePerformanceStats() {
        $now = [DateTime]::UtcNow
        if (($now - $this.LastStatsUpdate).TotalSeconds -lt 5) {
            return  # Update stats only every 5 seconds
        }
        
        $this.PerformanceStats = @{
            FrameRate = $this.FrameLimiter.GetStats()
            Memory = $this.MemoryOptimizer.GetStats()
            ScreenUpdater = $this.ScreenUpdater.GetStats()
            LastUpdate = $now
        }
        
        $this.LastStatsUpdate = $now
    }
    
    [hashtable] GetPerformanceStats() {
        $this.UpdatePerformanceStats()
        return $this.PerformanceStats
    }
    
    [void] SetPerformanceMode([bool]$enabled) {
        $this.PerformanceMode = $enabled
        
        if ($enabled -and (-not $this.ScreenUpdater -or -not $this.FrameLimiter -or -not $this.MemoryOptimizer)) {
            $this.ScreenUpdater = [DifferentialScreenUpdater]::new()
            $this.FrameLimiter = [FrameRateLimiter]::new(2, $true)
            $this.MemoryOptimizer = [MemoryOptimizer]::new(100)
        }
    }
    
    [void] SetTargetFPS([int]$fps) {
        if ($this.FrameLimiter) {
            $this.FrameLimiter.SetTargetFPS($fps)
        }
    }
    
    [void] ForceFullRedraw() {
        if ($this.ScreenUpdater) {
            $this.ScreenUpdater.ForceFullRedraw()
        }
    }
    
    [void] CleanupAndExit() {
        # Perform final cleanup
        if ($this.MemoryOptimizer) {
            $this.MemoryOptimizer.PerformCleanup()
        }
        
        # Call base cleanup
        ([ConsoleRenderer]$this).CleanupAndExit()
    }
}

# Export classes and functions
Export-ModuleMember -Function @() -Variable @()