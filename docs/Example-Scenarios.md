# Spotify CLI Live Features - Example Scenarios

## Overview

This document provides practical examples and scenarios demonstrating how to use the Spotify CLI Live Features in real-world situations. Each scenario includes step-by-step instructions, expected outcomes, and tips for optimization.

## Scenario 1: Daily Music Monitoring Setup

**Use Case:** Set up a persistent music monitoring display for daily work sessions.

### Setup Steps

1. **Initialize the system:**

   ```powershell
   # Start PowerShell and navigate to Spotify CLI directory
   cd "C:\Path\To\SpotifyCLI"

   # Initialize live features
   Initialize-SpotifyLiveFeatures
   ```

2. **Configure for daily use:**

   ```powershell
   # Set up optimized configuration for all-day monitoring
   Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
       refreshInterval = 2000        # 2-second updates (battery friendly)
       displayMode = "compact"       # Less screen space
       performanceMode = $true       # Optimize for performance
       showTimestamp = $false        # Clean display
   }

   # Enable statistics tracking
   Set-SpotifyLiveFeaturesConfiguration -Section "statistics" -Settings @{
       trackingEnabled = $true
       backgroundCollection = $true
   }

   # Configure lyrics for occasional use
   Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
       cacheEnabled = $true
       preferredProvider = "genius"
   }
   ```

3. **Start monitoring:**
   ```powershell
   # Start live display in compact mode
   Start-SpotifyLiveDisplay -Mode compact
   ```

### Expected Outcome

- Clean, compact display showing current track
- Minimal CPU usage for all-day operation
- Statistics automatically collected in background
- Easy access to lyrics when needed

### Tips

- Use `Ctrl+C` to exit live mode when needed
- Check daily statistics with: `Get-SpotifyListeningStatistics -Period day`
- Restart live features if memory usage grows: `Stop-SpotifyLiveFeatures; Initialize-SpotifyLiveFeatures`

## Scenario 2: Windows Terminal Sidecar Workflow

**Use Case:** Keep music information visible while coding or working in terminal.

### Setup Steps

1. **Launch Windows Terminal:**

   ```powershell
   # Ensure you're running in Windows Terminal (not regular PowerShell)
   # Check environment variable
   $env:WT_SESSION  # Should return a value
   ```

2. **Test sidecar capabilities:**

   ```powershell
   # Verify Windows Terminal support
   Test-DisplayCapabilities
   ```

3. **Configure sidecar settings:**

   ```powershell
   Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
       sidecarPosition = "right"     # Position on right side
       sidecarWidth = 35             # 35% of terminal width
       autoHideSidecar = $false      # Keep visible always
       displayMode = "detailed"      # Full information
   }
   ```

4. **Start sidecar mode:**

   ```powershell
   # Initialize if not already done
   Initialize-SpotifyLiveFeatures

   # Start sidecar display
   spotify --sidecar
   ```

### Expected Outcome

- Split terminal with music info on the right
- Main terminal area available for work
- Continuous music monitoring without interruption
- Easy to resize or reposition as needed

### Workflow Integration

```powershell
# Example development workflow with sidecar
spotify --sidecar                    # Start music monitoring
cd "C:\Projects\MyProject"           # Navigate to project
code .                               # Open VS Code
npm run dev                          # Start development server

# Music info stays visible in sidecar while you work
# Use main terminal for development commands
```

## Scenario 3: Music Discovery and Analysis Session

**Use Case:** Explore new music while analyzing listening patterns and discovering lyrics.

### Setup Steps

1. **Prepare for discovery session:**

   ```powershell
   Initialize-SpotifyLiveFeatures

   # Configure for rich experience
   Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
       displayMode = "detailed"
       enableAnimations = $true
       showAlbumArt = $true
       refreshInterval = 1000
   }

   Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
       syncHighlighting = $true
       autoScroll = $true
       showTimestamps = $true
   }
   ```

2. **Start discovery workflow:**

   ```powershell
   # Start with live display
   Start-SpotifyLiveDisplay -Mode detailed
   ```

3. **In another terminal window, explore music:**

   ```powershell
   # Search for new music
   search "indie rock 2024"
   play 1

   # Get lyrics for the current track
   Get-SpotifyCurrentTrackLyrics

   # Show interactive lyrics viewer
   $lyrics = Get-SpotifyCurrentTrackLyrics
   if ($lyrics.Success) {
       Show-Lyrics $lyrics
   }
   ```

4. **Analyze listening patterns:**

   ```powershell
   # After listening session, check statistics
   Get-SpotifyListeningStatistics -Period day

   # Export data for further analysis
   $engine = New-StatisticsEngine
   $export = $engine.ExportData("json", "day")
   Set-Content -Path "today-listening.json" -Value $export.Data
   ```

### Expected Outcome

- Rich visual experience with detailed track information
- Synchronized lyrics for sing-along or analysis
- Comprehensive statistics about discovery session
- Exportable data for further analysis

## Scenario 4: Focused Listening Session

**Use Case:** Dedicated music listening with lyrics focus and minimal distractions.

### Setup Steps

1. **Configure for focused listening:**

   ```powershell
   Initialize-SpotifyLiveFeatures

   # Minimal display configuration
   Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
       displayMode = "minimal"
       refreshInterval = 3000        # Less frequent updates
       enableAnimations = $false     # No distractions
   }

   # Optimize lyrics for reading
   Set-SpotifyLiveFeaturesConfiguration -Section "lyrics" -Settings @{
       syncHighlighting = $true
       autoScroll = $true
       displayHeight = 25            # More lines visible
       showTimestamps = $false       # Clean reading experience
   }
   ```

2. **Start focused session:**

   ```powershell
   # Start minimal live display
   Start-SpotifyLiveDisplay -Mode minimal
   ```

3. **In separate window, focus on lyrics:**

   ```powershell
   # Get and display lyrics interactively
   $lyrics = Get-SpotifyCurrentTrackLyrics
   if ($lyrics.Success) {
       Show-Lyrics $lyrics
   }

   # Use interactive controls:
   # - Arrow keys to scroll
   # - / to search within lyrics
   # - T to toggle timestamps
   # - Esc to exit
   ```

### Expected Outcome

- Minimal visual distractions
- Focus on lyrics and music content
- Smooth synchronized highlighting
- Comfortable reading experience

## Scenario 5: Performance Monitoring and Optimization

**Use Case:** Monitor system performance while using live features and optimize settings.

### Setup Steps

1. **Start with performance monitoring:**

   ```powershell
   # Create performance monitoring function
   function Monitor-SpotifyPerformance {
       param([int]$Minutes = 10)

       $endTime = (Get-Date).AddMinutes($Minutes)
       $measurements = @()

       Write-Host "Starting $Minutes minute performance monitoring..." -ForegroundColor Cyan

       while ((Get-Date) -lt $endTime) {
           $memory = [System.GC]::GetTotalMemory($false) / 1MB
           $process = Get-Process -Name "pwsh" | Sort-Object WorkingSet -Descending | Select-Object -First 1
           $processMemory = $process.WorkingSet / 1MB
           $cpu = $process.CPU

           $measurement = @{
               Timestamp = Get-Date
               MemoryMB = [Math]::Round($memory, 2)
               ProcessMemoryMB = [Math]::Round($processMemory, 2)
               CPU = $cpu
           }

           $measurements += $measurement

           Write-Host "$(Get-Date -Format 'HH:mm:ss') - Memory: $($measurement.MemoryMB)MB, Process: $($measurement.ProcessMemoryMB)MB" -ForegroundColor Green

           Start-Sleep -Seconds 30
       }

       return $measurements
   }
   ```

2. **Initialize and start monitoring:**

   ```powershell
   Initialize-SpotifyLiveFeatures

   # Start performance monitoring in background
   $monitorJob = Start-Job -ScriptBlock ${function:Monitor-SpotifyPerformance} -ArgumentList 10

   # Start live features
   Start-SpotifyLiveDisplay -Mode detailed
   ```

3. **Analyze performance:**

   ```powershell
   # After monitoring period, get results
   $results = Receive-Job -Job $monitorJob -Wait
   Remove-Job $monitorJob

   # Analyze results
   $avgMemory = ($results | Measure-Object -Property MemoryMB -Average).Average
   $maxMemory = ($results | Measure-Object -Property MemoryMB -Maximum).Maximum
   $avgProcessMemory = ($results | Measure-Object -Property ProcessMemoryMB -Average).Average

   Write-Host "Performance Summary:" -ForegroundColor Cyan
   Write-Host "Average Memory: $([Math]::Round($avgMemory, 2))MB" -ForegroundColor White
   Write-Host "Peak Memory: $([Math]::Round($maxMemory, 2))MB" -ForegroundColor White
   Write-Host "Average Process Memory: $([Math]::Round($avgProcessMemory, 2))MB" -ForegroundColor White
   ```

4. **Optimize based on results:**

   ```powershell
   # If memory usage is high, optimize
   if ($maxMemory -gt 100) {
       Write-Host "High memory usage detected. Applying optimizations..." -ForegroundColor Yellow

       Set-SpotifyLiveFeaturesConfiguration -Section "liveDisplay" -Settings @{
           refreshInterval = 3000
           performanceMode = $true
           enableAnimations = $false
       }

       Set-SpotifyLiveFeaturesConfiguration -Section "backgroundProcessing" -Settings @{
           memoryThresholdMB = 75
           batchSize = 5
       }

       # Restart with optimized settings
       Stop-SpotifyLiveFeatures
       Initialize-SpotifyLiveFeatures
   }
   ```

### Expected Outcome

- Detailed performance metrics
- Identification of resource usage patterns
- Automatic optimization recommendations
- Improved system performance

## Scenario 6: Multi-User Environment Setup

**Use Case:** Configure live features for shared computer or multiple user profiles.

### Setup Steps

1. **Create user-specific configuration:**

   ```powershell
   # Create user-specific config directory
   $userConfigDir = "$env:APPDATA\SpotifyCLI\LiveFeatures\Profiles\$env:USERNAME"
   New-Item -ItemType Directory -Path $userConfigDir -Force

   # Create user-specific settings
   $userConfig = @{
       liveDisplay = @{
           refreshInterval = 1500
           displayMode = "compact"
           colors = @{
               playing = "Blue"      # User's preferred color
               track = "White"
               artist = "Gray"
           }
       }
       statistics = @{
           trackingEnabled = $true
           dataDirectory = "$env:APPDATA\SpotifyCLI\Statistics\$env:USERNAME"
       }
       lyrics = @{
           cacheDirectory = "$env:APPDATA\SpotifyCLI\Lyrics\$env:USERNAME"
           preferredProvider = "genius"
       }
   }

   # Save user configuration
   $userConfig | ConvertTo-Json -Depth 10 | Set-Content "$userConfigDir\config.json"
   ```

2. **Create profile loading function:**

   ```powershell
   function Load-SpotifyUserProfile {
       param([string]$Username = $env:USERNAME)

       $profilePath = "$env:APPDATA\SpotifyCLI\LiveFeatures\Profiles\$Username\config.json"

       if (Test-Path $profilePath) {
           $config = Get-Content $profilePath | ConvertFrom-Json

           # Apply configuration
           foreach ($section in $config.PSObject.Properties.Name) {
               $settings = @{}
               $config.$section.PSObject.Properties | ForEach-Object {
                   $settings[$_.Name] = $_.Value
               }
               Set-SpotifyLiveFeaturesConfiguration -Section $section -Settings $settings
           }

           Write-Host "Loaded profile for user: $Username" -ForegroundColor Green
       } else {
           Write-Host "No profile found for user: $Username" -ForegroundColor Yellow
       }
   }
   ```

3. **Initialize with user profile:**

   ```powershell
   # Load user-specific settings
   Load-SpotifyUserProfile

   # Initialize live features
   Initialize-SpotifyLiveFeatures

   # Start with user's preferred settings
   Start-SpotifyLiveDisplay
   ```

### Expected Outcome

- Personalized settings for each user
- Separate data storage per user
- Easy profile switching
- Preserved user preferences

## Scenario 7: Automated Statistics Reporting

**Use Case:** Generate and email weekly music statistics reports.

### Setup Steps

1. **Create reporting function:**

   ```powershell
   function Generate-WeeklyMusicReport {
       param(
           [string]$OutputPath = "C:\Reports",
           [string]$EmailTo = "",
           [switch]$SendEmail
       )

       # Ensure output directory exists
       New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

       # Generate statistics
       $weeklyStats = Get-SpotifyListeningStatistics -Period week
       $timestamp = Get-Date -Format "yyyy-MM-dd"

       # Create report file
       $reportFile = Join-Path $OutputPath "Spotify-Weekly-Report-$timestamp.txt"
       $weeklyStats | Set-Content $reportFile

       # Export data
       $engine = New-StatisticsEngine
       $jsonExport = $engine.ExportData("json", "week")
       $jsonFile = Join-Path $OutputPath "Spotify-Weekly-Data-$timestamp.json"
       Set-Content -Path $jsonFile -Value $jsonExport.Data

       $csvExport = $engine.ExportData("csv", "week")
       $csvFile = Join-Path $OutputPath "Spotify-Weekly-Data-$timestamp.csv"
       Set-Content -Path $csvFile -Value $csvExport.Data

       Write-Host "Weekly report generated:" -ForegroundColor Green
       Write-Host "  Report: $reportFile" -ForegroundColor Gray
       Write-Host "  JSON Data: $jsonFile" -ForegroundColor Gray
       Write-Host "  CSV Data: $csvFile" -ForegroundColor Gray

       # Send email if requested
       if ($SendEmail -and $EmailTo) {
           Send-WeeklyReport -ReportFile $reportFile -JsonFile $jsonFile -CsvFile $csvFile -To $EmailTo
       }

       return @{
           ReportFile = $reportFile
           JsonFile = $jsonFile
           CsvFile = $csvFile
       }
   }

   function Send-WeeklyReport {
       param(
           [string]$ReportFile,
           [string]$JsonFile,
           [string]$CsvFile,
           [string]$To
       )

       # Email configuration (adjust for your email system)
       $smtpServer = "smtp.gmail.com"
       $smtpPort = 587
       $from = "your-email@gmail.com"
       $password = "your-app-password"  # Use app password for Gmail

       $subject = "Weekly Spotify Listening Report - $(Get-Date -Format 'yyyy-MM-dd')"
       $body = Get-Content $ReportFile -Raw

       try {
           $credential = New-Object System.Management.Automation.PSCredential($from, (ConvertTo-SecureString $password -AsPlainText -Force))

           Send-MailMessage -SmtpServer $smtpServer -Port $smtpPort -UseSsl -Credential $credential -From $from -To $To -Subject $subject -Body $body -Attachments $JsonFile, $CsvFile

           Write-Host "Weekly report emailed to: $To" -ForegroundColor Green
       } catch {
           Write-Host "Failed to send email: $($_.Exception.Message)" -ForegroundColor Red
       }
   }
   ```

2. **Set up automated scheduling:**

   ```powershell
   # Create scheduled task for weekly reports
   $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-Command `"cd 'C:\Path\To\SpotifyCLI'; Import-Module .\modules\SpotifyLiveFeatures.psm1; Initialize-SpotifyLiveFeatures; Generate-WeeklyMusicReport -SendEmail -EmailTo 'your-email@example.com'`""

   $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "9:00AM"

   $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

   Register-ScheduledTask -TaskName "SpotifyWeeklyReport" -Action $action -Trigger $trigger -Settings $settings -Description "Generate weekly Spotify listening report"
   ```

3. **Test the reporting system:**

   ```powershell
   # Initialize live features
   Initialize-SpotifyLiveFeatures

   # Generate test report
   $report = Generate-WeeklyMusicReport -OutputPath "C:\temp"

   # View the report
   Get-Content $report.ReportFile
   ```

### Expected Outcome

- Automated weekly statistics reports
- Multiple export formats (text, JSON, CSV)
- Optional email delivery
- Scheduled execution without manual intervention

## Scenario 8: Integration with External Tools

**Use Case:** Integrate Spotify live features with external monitoring and productivity tools.

### Setup Steps

1. **Create API endpoint for external access:**

   ```powershell
   # Simple HTTP server to expose Spotify data
   function Start-SpotifyApiServer {
       param([int]$Port = 8080)

       $listener = New-Object System.Net.HttpListener
       $listener.Prefixes.Add("http://localhost:$Port/")
       $listener.Start()

       Write-Host "Spotify API server started on port $Port" -ForegroundColor Green
       Write-Host "Available endpoints:" -ForegroundColor Cyan
       Write-Host "  GET /current-track" -ForegroundColor Gray
       Write-Host "  GET /statistics/day" -ForegroundColor Gray
       Write-Host "  GET /statistics/week" -ForegroundColor Gray
       Write-Host "  GET /lyrics" -ForegroundColor Gray

       try {
           while ($listener.IsListening) {
               $context = $listener.GetContext()
               $request = $context.Request
               $response = $context.Response

               $responseData = ""
               $statusCode = 200

               switch ($request.Url.AbsolutePath) {
                   "/current-track" {
                       try {
                           $manager = [SpotifyLiveFeaturesManager]::new()
                           $track = $manager.GetCurrentTrack()
                           $responseData = $track | ConvertTo-Json -Depth 10
                       } catch {
                           $statusCode = 500
                           $responseData = @{ error = $_.Exception.Message } | ConvertTo-Json
                       }
                   }
                   "/statistics/day" {
                       try {
                           $stats = Get-SpotifyListeningStatistics -Period day
                           $responseData = $stats | ConvertTo-Json -Depth 10
                       } catch {
                           $statusCode = 500
                           $responseData = @{ error = $_.Exception.Message } | ConvertTo-Json
                       }
                   }
                   "/statistics/week" {
                       try {
                           $stats = Get-SpotifyListeningStatistics -Period week
                           $responseData = $stats | ConvertTo-Json -Depth 10
                       } catch {
                           $statusCode = 500
                           $responseData = @{ error = $_.Exception.Message } | ConvertTo-Json
                       }
                   }
                   "/lyrics" {
                       try {
                           $lyrics = Get-SpotifyCurrentTrackLyrics
                           $responseData = $lyrics | ConvertTo-Json -Depth 10
                       } catch {
                           $statusCode = 500
                           $responseData = @{ error = $_.Exception.Message } | ConvertTo-Json
                       }
                   }
                   default {
                       $statusCode = 404
                       $responseData = @{ error = "Endpoint not found" } | ConvertTo-Json
                   }
               }

               $response.StatusCode = $statusCode
               $response.ContentType = "application/json"
               $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseData)
               $response.ContentLength64 = $buffer.Length
               $response.OutputStream.Write($buffer, 0, $buffer.Length)
               $response.OutputStream.Close()
           }
       } finally {
           $listener.Stop()
       }
   }
   ```

2. **Create webhook integration:**

   ```powershell
   function Send-SpotifyWebhook {
       param(
           [string]$WebhookUrl,
           [hashtable]$TrackData
       )

       $payload = @{
           text = "Now Playing: $($TrackData.name) by $($TrackData.artists[0].name)"
           attachments = @(
               @{
                   color = "good"
                   fields = @(
                       @{
                           title = "Track"
                           value = $TrackData.name
                           short = $true
                       }
                       @{
                           title = "Artist"
                           value = ($TrackData.artists | ForEach-Object { $_.name }) -join ", "
                           short = $true
                       }
                       @{
                           title = "Album"
                           value = $TrackData.album.name
                           short = $true
                       }
                       @{
                           title = "Duration"
                           value = "$([Math]::Round($TrackData.duration_ms / 60000, 1)) minutes"
                           short = $true
                       }
                   )
               }
           )
       }

       try {
           Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body ($payload | ConvertTo-Json -Depth 10) -ContentType "application/json"
           Write-Host "Webhook sent successfully" -ForegroundColor Green
       } catch {
           Write-Host "Failed to send webhook: $($_.Exception.Message)" -ForegroundColor Red
       }
   }
   ```

3. **Start integrated monitoring:**

   ```powershell
   # Initialize live features
   Initialize-SpotifyLiveFeatures

   # Start API server in background
   $apiJob = Start-Job -ScriptBlock ${function:Start-SpotifyApiServer} -ArgumentList 8080

   # Start live display
   Start-SpotifyLiveDisplay -Mode detailed

   # Example: Send webhook when track changes
   $lastTrackId = ""
   while ($true) {
       try {
           $manager = [SpotifyLiveFeaturesManager]::new()
           $currentTrack = $manager.GetCurrentTrack()

           if ($currentTrack.Success -and $currentTrack.Data.item.id -ne $lastTrackId) {
               $lastTrackId = $currentTrack.Data.item.id

               # Send webhook notification (replace with your webhook URL)
               # Send-SpotifyWebhook -WebhookUrl "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" -TrackData $currentTrack.Data.item
           }
       } catch {
           Write-Host "Error in monitoring loop: $($_.Exception.Message)" -ForegroundColor Red
       }

       Start-Sleep -Seconds 10
   }
   ```

### Expected Outcome

- HTTP API for external tool integration
- Webhook notifications for track changes
- Real-time data access for other applications
- Seamless integration with productivity workflows

## Tips for All Scenarios

### General Best Practices

1. **Always initialize first:**

   ```powershell
   Initialize-SpotifyLiveFeatures
   ```

2. **Check system status regularly:**

   ```powershell
   Get-SpotifyLiveFeaturesStatus
   ```

3. **Use appropriate display modes:**

   - `detailed` for focused music sessions
   - `compact` for background monitoring
   - `minimal` for low-resource usage

4. **Monitor performance:**

   ```powershell
   # Check memory usage periodically
   $memory = [System.GC]::GetTotalMemory($false) / 1MB
   Write-Host "Memory usage: $([Math]::Round($memory, 2))MB"
   ```

5. **Clean shutdown:**
   ```powershell
   Stop-SpotifyLiveFeatures
   ```

### Troubleshooting Quick Fixes

```powershell
# If features stop working
Stop-SpotifyLiveFeatures
Initialize-SpotifyLiveFeatures

# If memory usage is high
[System.GC]::Collect()

# If configuration seems corrupted
Reset-SpotifyLiveFeaturesConfiguration

# If Spotify connection fails
.\spotifyCLI.ps1  # Re-authenticate
```

These scenarios demonstrate the flexibility and power of the Spotify CLI Live Features system. Adapt them to your specific needs and workflow requirements.
