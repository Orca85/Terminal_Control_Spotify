# Statistics Command Module for Spotify CLI
# This module provides the stats command functionality

function Get-SpotifyStats {
    <#
    .SYNOPSIS
    Display comprehensive listening statistics and analytics
    
    .DESCRIPTION
    Shows detailed statistics about your Spotify listening habits including top tracks, artists, 
    genres, listening patterns, and more. Integrates with the Statistics Engine to provide 
    ASCII visualizations and export functionality.
    
    .PARAMETER Period
    Time period for statistics (day, week, month, year)
    
    .PARAMETER Export
    Export format (json, csv) - saves data to file
    
    .PARAMETER View
    Specific view to display (summary, tracks, artists, genres, patterns, streaks)
    
    .PARAMETER Interactive
    Enable interactive mode for detailed exploration
    
    .EXAMPLE
    Get-SpotifyStats
    Show monthly statistics with all views
    
    .EXAMPLE
    Get-SpotifyStats -Period week -View tracks
    Show top tracks for the past week
    
    .EXAMPLE
    Get-SpotifyStats -Period month -Export json
    Export monthly statistics to JSON file
    
    .EXAMPLE
    stats day
    Quick alias to show daily statistics
    #>
    param(
        [ValidateSet("day", "week", "month", "year")]
        [string]$Period = "month",
        
        [ValidateSet("json", "csv")]
        [string]$Export,
        
        [ValidateSet("summary", "tracks", "artists", "genres", "patterns", "streaks", "all")]
        [string]$View = "all",
        
        [switch]$Interactive
    )
    
    try {
        # Import Statistics Engine if not already loaded
        $statsModulePath = Join-Path $PSScriptRoot "modules\Statistics\StatisticsEngine.psm1"
        if (Test-Path $statsModulePath) {
            Import-Module $statsModulePath -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "Statistics Engine not found" -ForegroundColor Red
            Write-Host "Please ensure the Statistics module is properly installed" -ForegroundColor Yellow
            return
        }
        
        # Initialize Statistics Engine
        $config = @{
            DataDirectory = Join-Path $env:APPDATA "SpotifyCLI\Statistics"
            TrackingEnabled = $true
            RetentionDays = 365
        }
        
        $statsEngine = [StatisticsEngine]::new($config)
        
        # Check if we have any data
        $storageInfo = $statsEngine.GetStorageInfo()
        if ($storageInfo.TotalEvents -eq 0) {
            Write-Host "No listening data available yet" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Statistics will be collected automatically as you use Spotify" -ForegroundColor Cyan
            Write-Host "Start playing music and check back later to see your stats!" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Data Collection Info:" -ForegroundColor Gray
            Write-Host "  Location: $($storageInfo.DatabaseFile)" -ForegroundColor White
            $statusText = if ($storageInfo.IsEnabled) { 'Enabled' } else { 'Disabled' }
            Write-Host "  Status: $statusText" -ForegroundColor White
            Write-Host "  Retention: $($storageInfo.RetentionDays) days" -ForegroundColor White
            return
        }
        
        # Handle export request
        if ($Export) {
            Write-Host "Exporting statistics..." -ForegroundColor Cyan
            $exportResult = $statsEngine.ExportData($Export, $Period, @{})
            
            if ($exportResult.Success) {
                $exportPath = Join-Path (Get-Location) $exportResult.FileName
                Set-Content -Path $exportPath -Value $exportResult.Data -Encoding UTF8
                
                Write-Host "Statistics exported successfully" -ForegroundColor Green
                Write-Host "File: $exportPath" -ForegroundColor White
                Write-Host "Format: $($exportResult.Format.ToUpper())" -ForegroundColor White
                
                # Show file size
                if (Test-Path $exportPath) {
                    $fileSize = [Math]::Round((Get-Item $exportPath).Length / 1KB, 1)
                    Write-Host "Size: $fileSize KB" -ForegroundColor White
                }
            } else {
                Write-Host "Export failed: $($exportResult.Error)" -ForegroundColor Red
            }
            return
        }
        
        # Generate and display statistics
        Write-Host "Spotify Listening Statistics" -ForegroundColor Cyan
        Write-Host "=" * 35 -ForegroundColor Cyan
        Write-Host ""
        
        # Show period and data info
        $periodDisplay = switch ($Period) {
            "day" { "Past 24 Hours" }
            "week" { "Past Week" }
            "month" { "Past Month" }
            "year" { "Past Year" }
        }
        
        Write-Host "Period: $periodDisplay" -ForegroundColor Yellow
        Write-Host "Total Events: $($storageInfo.TotalEvents)" -ForegroundColor Gray
        $oldestDate = if ($storageInfo.OldestEvent) { $storageInfo.OldestEvent.ToString('MM/dd/yyyy') } else { 'N/A' }
        $newestDate = if ($storageInfo.NewestEvent) { $storageInfo.NewestEvent.ToString('MM/dd/yyyy') } else { 'N/A' }
        Write-Host "Data Range: $oldestDate - $newestDate" -ForegroundColor Gray
        Write-Host ""
        
        # Get comprehensive stats
        $stats = $statsEngine.GetStats($Period)
        
        # Display based on view selection
        if ($View -eq "all" -or $View -eq "summary") {
            Show-StatsSummary -Stats $stats -Period $Period
        }
        
        if ($View -eq "all" -or $View -eq "tracks") {
            Show-StatsTopTracks -Stats $stats -StatsEngine $statsEngine
        }
        
        if ($View -eq "all" -or $View -eq "artists") {
            Show-StatsTopArtists -Stats $stats -StatsEngine $statsEngine
        }
        
        if ($View -eq "all" -or $View -eq "genres") {
            Show-StatsGenres -Stats $stats -StatsEngine $statsEngine
        }
        
        if ($View -eq "all" -or $View -eq "patterns") {
            Show-StatsPatterns -Stats $stats -StatsEngine $statsEngine
        }
        
        if ($View -eq "all" -or $View -eq "streaks") {
            Show-StatsStreaks -StatsEngine $statsEngine
        }
        
        # Show interactive options
        if ($Interactive) {
            Show-StatsInteractiveMenu -StatsEngine $statsEngine -Period $Period
        } else {
            Write-Host ""
            Write-Host "Use 'stats -Interactive' for detailed exploration" -ForegroundColor Cyan
            Write-Host "Use 'stats -Export json' to save data to file" -ForegroundColor Cyan
            Write-Host "Use 'stats -View tracks' to see only top tracks" -ForegroundColor Cyan
        }
        
    } catch {
        Write-Host "Statistics error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Try: Get-SpotifyStats -Period day" -ForegroundColor Yellow
    }
}

function Show-StatsSummary {
    param($Stats, $Period)
    
    $totalHours = [Math]::Round($Stats.TotalPlaytime / (1000 * 60 * 60), 1)
    $avgTracksPerDay = if ($Period -eq "day") { $Stats.TotalTracks } else {
        $days = switch ($Period) { "week" { 7 } "month" { 30 } "year" { 365 } }
        [Math]::Round($Stats.TotalTracks / $days, 1)
    }
    
    Write-Host "Summary" -ForegroundColor Yellow
    Write-Host "----------" -ForegroundColor Yellow
    Write-Host "Total listening time: $totalHours hours" -ForegroundColor White
    Write-Host "Total tracks played: $($Stats.TotalTracks)" -ForegroundColor White
    Write-Host "Unique artists: $($Stats.UniqueArtists)" -ForegroundColor White
    Write-Host "Unique albums: $($Stats.UniqueAlbums)" -ForegroundColor White
    Write-Host "Average tracks/day: $avgTracksPerDay" -ForegroundColor White
    Write-Host "Current streak: $($Stats.CurrentStreak) days" -ForegroundColor White
    Write-Host ""
}

function Show-StatsTopTracks {
    param($Stats, $StatsEngine)
    
    if ($Stats.TopTracks.Tracks.Count -gt 0) {
        Write-Host "Top Tracks" -ForegroundColor Yellow
        Write-Host "-------------" -ForegroundColor Yellow
        
        $visualization = $StatsEngine.VisualizationGenerator.GenerateTopItemsChart(
            $Stats.TopTracks.Tracks, "Top Tracks", "tracks"
        )
        Write-Host $visualization -ForegroundColor White
        Write-Host ""
    }
}

function Show-StatsTopArtists {
    param($Stats, $StatsEngine)
    
    if ($Stats.TopArtists.Artists.Count -gt 0) {
        Write-Host "Top Artists" -ForegroundColor Yellow
        Write-Host "--------------" -ForegroundColor Yellow
        
        $visualization = $StatsEngine.VisualizationGenerator.GenerateTopItemsChart(
            $Stats.TopArtists.Artists, "Top Artists", "artists"
        )
        Write-Host $visualization -ForegroundColor White
        Write-Host ""
    }
}

function Show-StatsGenres {
    param($Stats, $StatsEngine)
    
    if ($Stats.GenreDistribution.Distribution.Count -gt 0) {
        Write-Host "Genre Distribution" -ForegroundColor Yellow
        Write-Host "--------------------" -ForegroundColor Yellow
        
        $genreData = @{}
        foreach ($genre in $Stats.GenreDistribution.Distribution.Keys) {
            $genreData[$genre] = $Stats.GenreDistribution.Distribution[$genre].Count
        }
        
        $visualization = $StatsEngine.VisualizationGenerator.GeneratePieChart(
            $genreData, "Genre Distribution"
        )
        Write-Host $visualization -ForegroundColor White
        Write-Host ""
        
        # Show dominant genre info
        if ($Stats.GenreDistribution.DominantGenre) {
            Write-Host "Dominant Genre: $($Stats.GenreDistribution.DominantGenre) ($($Stats.GenreDistribution.DominantGenrePercentage)%)" -ForegroundColor Cyan
            Write-Host ""
        }
    }
}

function Show-StatsPatterns {
    param($Stats, $StatsEngine)
    
    Write-Host "Listening Patterns" -ForegroundColor Yellow
    Write-Host "--------------------" -ForegroundColor Yellow
    
    # Hourly pattern
    $hourlyViz = $StatsEngine.VisualizationGenerator.GenerateHourlyPattern($Stats.DailyPatterns)
    Write-Host $hourlyViz -ForegroundColor White
    Write-Host ""
    
    # Weekly pattern
    $weeklyViz = $StatsEngine.VisualizationGenerator.GenerateWeeklyPattern($Stats.WeeklyPatterns)
    Write-Host $weeklyViz -ForegroundColor White
    Write-Host ""
}

function Show-StatsStreaks {
    param($StatsEngine)
    
    $streaks = $StatsEngine.AnalyticsProcessor.CalculateListeningStreaks()
    
    Write-Host "Listening Streaks" -ForegroundColor Yellow
    Write-Host "-------------------" -ForegroundColor Yellow
    
    $streakViz = $StatsEngine.VisualizationGenerator.GenerateStreakVisualization($streaks)
    Write-Host $streakViz -ForegroundColor White
    Write-Host ""
}

function Show-StatsInteractiveMenu {
    param($StatsEngine, $Period)
    
    Write-Host ""
    Write-Host "Interactive Statistics Menu" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available commands:" -ForegroundColor Yellow
    Write-Host "  1. Export data (json/csv)" -ForegroundColor White
    Write-Host "  2. Change time period" -ForegroundColor White
    Write-Host "  3. View specific category" -ForegroundColor White
    Write-Host "  4. Storage information" -ForegroundColor White
    Write-Host "  5. Clear statistics data" -ForegroundColor White
    Write-Host "  q. Quit interactive mode" -ForegroundColor White
    Write-Host ""
    
    do {
        $choice = Read-Host "Select option (1-5, q)"
        
        switch ($choice.ToLower()) {
            "1" {
                $format = Read-Host "Export format (json/csv)"
                if ($format -in @("json", "csv")) {
                    Get-SpotifyStats -Period $Period -Export $format
                } else {
                    Write-Host "Invalid format. Use 'json' or 'csv'" -ForegroundColor Red
                }
            }
            "2" {
                $newPeriod = Read-Host "Time period (day/week/month/year)"
                if ($newPeriod -in @("day", "week", "month", "year")) {
                    Get-SpotifyStats -Period $newPeriod
                    return
                } else {
                    Write-Host "Invalid period. Use 'day', 'week', 'month', or 'year'" -ForegroundColor Red
                }
            }
            "3" {
                $view = Read-Host "View category (summary/tracks/artists/genres/patterns/streaks)"
                if ($view -in @("summary", "tracks", "artists", "genres", "patterns", "streaks")) {
                    Get-SpotifyStats -Period $Period -View $view
                } else {
                    Write-Host "Invalid view. Use 'summary', 'tracks', 'artists', 'genres', 'patterns', or 'streaks'" -ForegroundColor Red
                }
            }
            "4" {
                $storageInfo = $StatsEngine.GetStorageInfo()
                Write-Host ""
                Write-Host "Storage Information" -ForegroundColor Cyan
                Write-Host "---------------------" -ForegroundColor Cyan
                Write-Host "Database: $($storageInfo.DatabaseFile)" -ForegroundColor White
                Write-Host "Total Events: $($storageInfo.TotalEvents)" -ForegroundColor White
                Write-Host "File Size: $($storageInfo.FileSizeMB) MB" -ForegroundColor White
                $oldestEventText = if ($storageInfo.OldestEvent) { $storageInfo.OldestEvent.ToString('MM/dd/yyyy HH:mm') } else { 'N/A' }
                $newestEventText = if ($storageInfo.NewestEvent) { $storageInfo.NewestEvent.ToString('MM/dd/yyyy HH:mm') } else { 'N/A' }
                Write-Host "Oldest Event: $oldestEventText" -ForegroundColor White
                Write-Host "Newest Event: $newestEventText" -ForegroundColor White
                Write-Host "Retention: $($storageInfo.RetentionDays) days" -ForegroundColor White
                Write-Host "Enabled: $($storageInfo.IsEnabled)" -ForegroundColor White
                Write-Host ""
            }
            "5" {
                $confirm = Read-Host "Clear all statistics data? This cannot be undone! (yes/no)"
                if ($confirm.ToLower() -eq "yes") {
                    $StatsEngine.ClearData()
                    Write-Host "Statistics data cleared" -ForegroundColor Green
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            "q" {
                Write-Host "Exiting interactive mode" -ForegroundColor Yellow
                return
            }
            default {
                Write-Host "Invalid option. Please select 1-5 or 'q'" -ForegroundColor Red
            }
        }
        Write-Host ""
    } while ($true)
}

function stats {
    <#
    .SYNOPSIS
    Alias for Get-SpotifyStats - Display listening statistics
    
    .DESCRIPTION
    Quick alias to display Spotify listening statistics and analytics
    
    .PARAMETER Period
    Time period for statistics (day, week, month, year)
    
    .PARAMETER Export
    Export format (json, csv)
    
    .PARAMETER View
    Specific view to display
    
    .PARAMETER Interactive
    Enable interactive mode
    
    .EXAMPLE
    stats
    Show monthly statistics
    
    .EXAMPLE
    stats week
    Show weekly statistics
    
    .EXAMPLE
    stats month -Export json
    Export monthly statistics to JSON
    #>
    param(
        [Parameter(Position=0)]
        [ValidateSet("day", "week", "month", "year")]
        [string]$Period = "month",
        
        [ValidateSet("json", "csv")]
        [string]$Export,
        
        [ValidateSet("summary", "tracks", "artists", "genres", "patterns", "streaks", "all")]
        [string]$View = "all",
        
        [switch]$Interactive
    )
    
    if ($Export) {
        Get-SpotifyStats -Period $Period -Export $Export -View $View -Interactive:$Interactive
    } else {
        Get-SpotifyStats -Period $Period -View $View -Interactive:$Interactive
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-SpotifyStats',
    'stats',
    'Show-StatsSummary',
    'Show-StatsTopTracks',
    'Show-StatsTopArtists',
    'Show-StatsGenres',
    'Show-StatsPatterns',
    'Show-StatsStreaks',
    'Show-StatsInteractiveMenu'
)