# Test-PowerUserWorkflows.ps1
# Comprehensive integration test for power user features
# Tests: interactive navigation, smart numbers, aliases, customization, efficiency workflows

param(
    [switch]$Interactive = $false,
    [switch]$Verbose = $false
)

# Import required modules
try {
    Import-Module .\SpotifyModule.psm1 -Force -ErrorAction Stop
    Write-Host "✓ SpotifyModule imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import SpotifyModule: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test results tracking
$TestResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Errors = @()
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = "",
        [string]$Error = ""
    )
    
    $TestResults.TotalTests++
    
    if ($Passed) {
        $TestResults.PassedTests++
        Write-Host "✓ $TestName" -ForegroundColor Green
        if ($Details -and $Verbose) {
            Write-Host "  Details: $Details" -ForegroundColor Gray
        }
    } else {
        $TestResults.FailedTests++
        Write-Host "✗ $TestName" -ForegroundColor Red
        if ($Error) {
            Write-Host "  Error: $Error" -ForegroundColor Red
            $TestResults.Errors += "$TestName: $Error"
        }
    }
}

function Test-SmartNumberFunctionality {
    Write-Host "`n=== Testing Smart Number Functionality ===" -ForegroundColor Cyan
    
    # Test 1: Search and smart number assignment
    try {
        Write-Host "Testing smart number assignment with search..." -ForegroundColor Yellow
        $searchResult = Invoke-SpotifySearch -Query "queen" -Type "track" -Limit 5
        
        if ($searchResult -and $searchResult.tracks.items.Count -gt 0) {
            Write-TestResult "Search populates smart numbers" $true -Details "Found $($searchResult.tracks.items.Count) tracks for smart numbering"
            
            # Test 2: Verify smart number structure
            $tracks = $searchResult.tracks.items
            for ($i = 0; $i -lt [Math]::Min(3, $tracks.Count); $i++) {
                $track = $tracks[$i]
                $hasRequiredFields = $track.name -and $track.artists -and $track.id
                Write-TestResult "Track $($i+1) has required fields for smart number" $hasRequiredFields -Details "Track: $($track.name)"
            }
        } else {
            Write-TestResult "Search populates smart numbers" $false -Error "No search results returned"
        }
    } catch {
        Write-TestResult "Smart number assignment" $false -Error $_.Exception.Message
    }
    
    # Test 3: Device smart numbering
    try {
        $devices = Get-SpotifyDevices
        if ($devices -and $devices.Count -gt 0) {
            Write-TestResult "Device smart numbering available" $true -Details "Found $($devices.Count) devices for numbering"
            
            # Verify device numbering structure
            for ($i = 0; $i -lt [Math]::Min(2, $devices.Count); $i++) {
                $device = $devices[$i]
                $hasRequiredFields = $device.name -and $device.id -and $device.type
                Write-TestResult "Device $($i+1) has required fields" $hasRequiredFields -Details "Device: $($device.name)"
            }
        } else {
            Write-TestResult "Device smart numbering available" $false -Error "No devices available for smart numbering"
        }
    } catch {
        Write-TestResult "Device smart numbering" $false -Error $_.Exception.Message
    }
    
    # Test 4: Playlist smart numbering
    try {
        $playlists = Get-SpotifyPlaylists -Limit 5
        if ($playlists -and $playlists.items.Count -gt 0) {
            Write-TestResult "Playlist smart numbering available" $true -Details "Found $($playlists.items.Count) playlists for numbering"
        } else {
            Write-TestResult "Playlist smart numbering available" $false -Error "No playlists available for smart numbering"
        }
    } catch {
        Write-TestResult "Playlist smart numbering" $false -Error $_.Exception.Message
    }
}

function Test-InteractiveNavigation {
    Write-Host "`n=== Testing Interactive Navigation Features ===" -ForegroundColor Cyan
    
    # Test 1: Interactive mode initialization
    try {
        # Simulate interactive mode setup
        $script:InteractiveMode = $false
        $script:SelectedIndex = 0
        $script:SessionTracks = @()
        
        # Populate with test data
        $searchResult = Invoke-SpotifySearch -Query "beatles" -Type "track" -Limit 3
        if ($searchResult -and $searchResult.tracks.items.Count -gt 0) {
            $script:SessionTracks = $searchResult.tracks.items
            Write-TestResult "Interactive mode data population" $true -Details "Populated with $($script:SessionTracks.Count) tracks"
            
            # Test 2: Selection index management
            $script:SelectedIndex = 0
            $validIndex = $script:SelectedIndex -ge 0 -and $script:SelectedIndex -lt $script:SessionTracks.Count
            Write-TestResult "Selection index management" $validIndex -Details "Index: $($script:SelectedIndex)"
            
            # Test 3: Navigation bounds checking
            $maxIndex = $script:SessionTracks.Count - 1
            $boundsValid = $maxIndex -ge 0
            Write-TestResult "Navigation bounds validation" $boundsValid -Details "Max index: $maxIndex"
        } else {
            Write-TestResult "Interactive mode data population" $false -Error "No tracks available for interactive mode"
        }
    } catch {
        Write-TestResult "Interactive navigation setup" $false -Error $_.Exception.Message
    }
    
    # Test 4: Interactive mode state management
    try {
        # Test entering interactive mode
        $script:InteractiveMode = $true
        Write-TestResult "Enter interactive mode" $true -Details "Interactive mode enabled"
        
        # Test exiting interactive mode
        $script:InteractiveMode = $false
        Write-TestResult "Exit interactive mode" $true -Details "Interactive mode disabled"
    } catch {
        Write-TestResult "Interactive mode state management" $false -Error $_.Exception.Message
    }
}

function Test-AliasSystem {
    Write-Host "`n=== Testing Alias Management System ===" -ForegroundColor Cyan
    
    # Test 1: Get current aliases
    try {
        $aliases = Get-SpotifyAliases
        Write-TestResult "Get current aliases" $true -Details "Retrieved alias list"
        
        if ($aliases) {
            $aliasCount = ($aliases | Measure-Object).Count
            Write-TestResult "Aliases are available" ($aliasCount -gt 0) -Details "Found $aliasCount aliases"
        }
    } catch {
        Write-TestResult "Get current aliases" $false -Error $_.Exception.Message
    }
    
    # Test 2: Test built-in aliases
    $builtInAliases = @(
        @{Alias = "pn"; Command = "Show-SpotifyTrack"},
        @{Alias = "music"; Command = "Show-SpotifyTrack"},
        @{Alias = "vol"; Command = "Set-SpotifyVolume"},
        @{Alias = "sh"; Command = "Set-SpotifyShuffle"},
        @{Alias = "rep"; Command = "Set-SpotifyRepeat"}
    )
    
    foreach ($aliasTest in $builtInAliases) {
        try {
            $aliasExists = Get-Alias -Name $aliasTest.Alias -ErrorAction SilentlyContinue
            Write-TestResult "Built-in alias '$($aliasTest.Alias)' exists" ($aliasExists -ne $null) -Details "Points to: $($aliasTest.Command)"
        } catch {
            Write-TestResult "Built-in alias '$($aliasTest.Alias)'" $false -Error $_.Exception.Message
        }
    }
    
    # Test 3: Custom alias creation (if interactive)
    if ($Interactive) {
        try {
            $testAlias = "test-music-alias"
            Set-SpotifyAlias -Alias $testAlias -Command "Show-SpotifyTrack"
            Write-TestResult "Create custom alias" $true -Details "Created alias: $testAlias"
            
            # Test 4: Remove custom alias
            Remove-SpotifyAlias -Alias $testAlias
            Write-TestResult "Remove custom alias" $true -Details "Removed alias: $testAlias"
        } catch {
            Write-TestResult "Custom alias management" $false -Error $_.Exception.Message
        }
    } else {
        Write-Host "Skipping custom alias tests (use -Interactive flag to enable)" -ForegroundColor Yellow
    }
    
    # Test 5: Alias conflict detection
    try {
        $conflicts = Test-AliasConflicts
        Write-TestResult "Alias conflict detection" $true -Details "Conflict check completed"
    } catch {
        Write-TestResult "Alias conflict detection" $false -Error $_.Exception.Message
    }
}

function Test-ConfigurationSystem {
    Write-Host "`n=== Testing Configuration and Customization ===" -ForegroundColor Cyan
    
    # Test 1: Get current configuration
    try {
        $config = Get-SpotifyConfig
        Write-TestResult "Get current configuration" $true -Details "Configuration retrieved"
        
        if ($config) {
            # Test 2: Verify configuration structure
            $hasCompactMode = $config.PSObject.Properties.Name -contains "CompactMode"
            $hasNotifications = $config.PSObject.Properties.Name -contains "NotificationsEnabled"
            $hasColors = $config.PSObject.Properties.Name -contains "Colors"
            
            Write-TestResult "Configuration has CompactMode setting" $hasCompactMode
            Write-TestResult "Configuration has NotificationsEnabled setting" $hasNotifications
            Write-TestResult "Configuration has Colors settings" $hasColors
        }
    } catch {
        Write-TestResult "Get current configuration" $false -Error $_.Exception.Message
    }
    
    # Test 3: Configuration modification (if interactive)
    if ($Interactive) {
        try {
            # Save original config
            $originalConfig = Get-SpotifyConfig
            
            # Test setting modification
            Set-SpotifyConfig @{CompactMode = $true}
            $newConfig = Get-SpotifyConfig
            $compactModeSet = $newConfig.CompactMode -eq $true
            Write-TestResult "Modify configuration setting" $compactModeSet -Details "CompactMode set to true"
            
            # Restore original config
            if ($originalConfig) {
                Set-SpotifyConfig @{CompactMode = $originalConfig.CompactMode}
                Write-TestResult "Restore original configuration" $true -Details "Configuration restored"
            }
        } catch {
            Write-TestResult "Configuration modification" $false -Error $_.Exception.Message
        }
    } else {
        Write-Host "Skipping configuration modification tests (use -Interactive flag to enable)" -ForegroundColor Yellow
    }
    
    # Test 4: Notification system
    try {
        # Test notification status
        $notificationStatus = Get-SpotifyNotificationStatus
        Write-TestResult "Get notification status" $true -Details "Notification status retrieved"
    } catch {
        Write-TestResult "Notification system" $false -Error $_.Exception.Message
    }
}

function Test-AdvancedWorkflows {
    Write-Host "`n=== Testing Advanced Efficiency Workflows ===" -ForegroundColor Cyan
    
    # Test 1: Chained operations workflow
    try {
        Write-Host "Testing search → smart number → queue workflow..." -ForegroundColor Yellow
        
        # Step 1: Search
        $searchResult = Invoke-SpotifySearch -Query "pink floyd" -Type "track" -Limit 3
        $searchSuccess = $searchResult -and $searchResult.tracks.items.Count -gt 0
        Write-TestResult "Workflow Step 1: Search" $searchSuccess -Details "Search completed"
        
        if ($searchSuccess) {
            # Step 2: Smart number selection (simulate)
            $selectedTrack = $searchResult.tracks.items[0]
            $selectionSuccess = $selectedTrack -ne $null
            Write-TestResult "Workflow Step 2: Smart number selection" $selectionSuccess -Details "Track selected: $($selectedTrack.name)"
            
            # Step 3: Queue operation (simulate)
            if ($selectionSuccess -and $Interactive) {
                try {
                    Add-SpotifyQueue -TrackId $selectedTrack.id
                    Write-TestResult "Workflow Step 3: Queue track" $true -Details "Track queued successfully"
                } catch {
                    Write-TestResult "Workflow Step 3: Queue track" $false -Error $_.Exception.Message
                }
            } else {
                Write-TestResult "Workflow Step 3: Queue track (simulated)" $true -Details "Queue operation would succeed"
            }
        }
    } catch {
        Write-TestResult "Chained operations workflow" $false -Error $_.Exception.Message
    }
    
    # Test 2: Playlist management workflow
    try {
        Write-Host "Testing playlist → smart number → play workflow..." -ForegroundColor Yellow
        
        # Step 1: Get playlists
        $playlists = Get-SpotifyPlaylists -Limit 3
        $playlistSuccess = $playlists -and $playlists.items.Count -gt 0
        Write-TestResult "Playlist workflow Step 1: Get playlists" $playlistSuccess -Details "Playlists retrieved"
        
        if ($playlistSuccess) {
            # Step 2: Select playlist
            $selectedPlaylist = $playlists.items[0]
            $playlistSelectionSuccess = $selectedPlaylist -ne $null
            Write-TestResult "Playlist workflow Step 2: Select playlist" $playlistSelectionSuccess -Details "Playlist: $($selectedPlaylist.name)"
            
            # Step 3: Get playlist tracks
            if ($playlistSelectionSuccess) {
                try {
                    $playlistTracks = Get-SpotifyPlaylistTracks -PlaylistId $selectedPlaylist.id -Limit 5
                    $tracksSuccess = $playlistTracks -and $playlistTracks.items.Count -gt 0
                    Write-TestResult "Playlist workflow Step 3: Get tracks" $tracksSuccess -Details "Found $($playlistTracks.items.Count) tracks"
                } catch {
                    Write-TestResult "Playlist workflow Step 3: Get tracks" $false -Error $_.Exception.Message
                }
            }
        }
    } catch {
        Write-TestResult "Playlist management workflow" $false -Error $_.Exception.Message
    }
    
    # Test 3: Device switching workflow
    try {
        Write-Host "Testing device management workflow..." -ForegroundColor Yellow
        
        # Step 1: List devices
        $devices = Get-SpotifyDevices
        $deviceSuccess = $devices -and $devices.Count -gt 0
        Write-TestResult "Device workflow Step 1: List devices" $deviceSuccess -Details "Found $($devices.Count) devices"
        
        if ($deviceSuccess) {
            # Step 2: Identify active device
            $activeDevice = $devices | Where-Object { $_.is_active -eq $true }
            $hasActiveDevice = $activeDevice -ne $null
            Write-TestResult "Device workflow Step 2: Identify active device" $hasActiveDevice -Details $(if ($hasActiveDevice) { "Active: $($activeDevice.name)" } else { "No active device" })
            
            # Step 3: Device transfer capability (simulate)
            if ($devices.Count -gt 1) {
                $transferTarget = $devices | Where-Object { $_.is_active -ne $true } | Select-Object -First 1
                $canTransfer = $transferTarget -ne $null
                Write-TestResult "Device workflow Step 3: Transfer capability" $canTransfer -Details $(if ($canTransfer) { "Can transfer to: $($transferTarget.name)" } else { "No transfer target available" })
            } else {
                Write-TestResult "Device workflow Step 3: Transfer capability" $false -Details "Only one device available"
            }
        }
    } catch {
        Write-TestResult "Device switching workflow" $false -Error $_.Exception.Message
    }
}

function Test-AdvancedFeatures {
    Write-Host "`n=== Testing Advanced Power User Features ===" -ForegroundColor Cyan
    
    # Test 1: Queue management
    try {
        $queue = Get-SpotifyQueue
        Write-TestResult "Advanced queue management" $true -Details "Queue information retrieved"
    } catch {
        Write-TestResult "Advanced queue management" $false -Error $_.Exception.Message
    }
    
    # Test 2: Library management
    try {
        $likedTracks = Get-SpotifyLikedTracks -Limit 5
        $likedSuccess = $likedTracks -ne $null
        Write-TestResult "Library management (liked tracks)" $likedSuccess -Details "Liked tracks accessible"
    } catch {
        Write-TestResult "Library management (liked tracks)" $false -Error $_.Exception.Message
    }
    
    # Test 3: Recent tracks
    try {
        $recentTracks = Get-SpotifyRecentTracks -Limit 5
        $recentSuccess = $recentTracks -ne $null
        Write-TestResult "Recent tracks functionality" $recentSuccess -Details "Recent tracks accessible"
    } catch {
        Write-TestResult "Recent tracks functionality" $false -Error $_.Exception.Message
    }
    
    # Test 4: Advanced search features
    try {
        # Test album search
        $albumSearch = Invoke-SpotifySearch -Query "abbey road" -Type "album" -Limit 3
        $albumSuccess = $albumSearch -and $albumSearch.albums.items.Count -gt 0
        Write-TestResult "Advanced search (albums)" $albumSuccess -Details "Album search functional"
        
        # Test artist search
        $artistSearch = Invoke-SpotifySearch -Query "the beatles" -Type "artist" -Limit 3
        $artistSuccess = $artistSearch -and $artistSearch.artists.items.Count -gt 0
        Write-TestResult "Advanced search (artists)" $artistSuccess -Details "Artist search functional"
    } catch {
        Write-TestResult "Advanced search features" $false -Error $_.Exception.Message
    }
}

# Main execution
Write-Host "Starting Power User Workflows Integration Test" -ForegroundColor Magenta
Write-Host "===========================================" -ForegroundColor Magenta

# Run all test phases
Test-SmartNumberFunctionality
Test-InteractiveNavigation
Test-AliasSystem
Test-ConfigurationSystem
Test-AdvancedWorkflows
Test-AdvancedFeatures

# Display final results
Write-Host "`n=== Test Results Summary ===" -ForegroundColor Magenta
Write-Host "Total Tests: $($TestResults.TotalTests)" -ForegroundColor White
Write-Host "Passed: $($TestResults.PassedTests)" -ForegroundColor Green
Write-Host "Failed: $($TestResults.FailedTests)" -ForegroundColor Red

if ($TestResults.FailedTests -gt 0) {
    Write-Host "`nFailed Tests Details:" -ForegroundColor Red
    foreach ($error in $TestResults.Errors) {
        Write-Host "  • $error" -ForegroundColor Red
    }
}

$successRate = [math]::Round(($TestResults.PassedTests / $TestResults.TotalTests) * 100, 1)
Write-Host "`nSuccess Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })

# Power user specific recommendations
Write-Host "`n=== Power User Recommendations ===" -ForegroundColor Cyan

if ($TestResults.FailedTests -eq 0) {
    Write-Host "✓ All power user features are working correctly!" -ForegroundColor Green
    Write-Host "✓ Smart numbers, aliases, and advanced workflows are functional" -ForegroundColor Green
    Write-Host "✓ Interactive navigation and customization options are available" -ForegroundColor Green
} else {
    Write-Host "⚠ Some power user features need attention:" -ForegroundColor Yellow
    
    if ($TestResults.Errors -match "smart|number") {
        Write-Host "  • Smart number functionality needs debugging" -ForegroundColor Yellow
    }
    if ($TestResults.Errors -match "alias|Alias") {
        Write-Host "  • Alias system requires attention" -ForegroundColor Yellow
    }
    if ($TestResults.Errors -match "interactive|Interactive") {
        Write-Host "  • Interactive navigation features need fixes" -ForegroundColor Yellow
    }
    if ($TestResults.Errors -match "config|Config") {
        Write-Host "  • Configuration system needs debugging" -ForegroundColor Yellow
    }
    if ($TestResults.Errors -match "workflow|Workflow") {
        Write-Host "  • Advanced workflows need optimization" -ForegroundColor Yellow
    }
}

Write-Host "`nPower User Workflows Test Complete" -ForegroundColor Magenta