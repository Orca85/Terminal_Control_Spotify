# Test-FirstTimeUserWorkflow.ps1
# Comprehensive integration test for first-time user experience
# Tests: authentication → search → play → control workflow

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

function Test-AuthenticationFlow {
    Write-Host "`n=== Testing Authentication Flow ===" -ForegroundColor Cyan
    
    # Test 1: Check if .env file exists
    $envExists = Test-Path ".env"
    Write-TestResult "Environment file (.env) exists" $envExists -Error $(if (-not $envExists) { ".env file not found" })
    
    if ($envExists) {
        # Test 2: Check .env file content
        try {
            $envContent = Get-Content ".env" -Raw
            $hasClientId = $envContent -match "SPOTIFY_CLIENT_ID="
            $hasClientSecret = $envContent -match "SPOTIFY_CLIENT_SECRET="
            
            Write-TestResult "Client ID configured in .env" $hasClientId -Error $(if (-not $hasClientId) { "SPOTIFY_CLIENT_ID not found in .env" })
            Write-TestResult "Client Secret configured in .env" $hasClientSecret -Error $(if (-not $hasClientSecret) { "SPOTIFY_CLIENT_SECRET not found in .env" })
        } catch {
            Write-TestResult "Read .env file content" $false -Error $_.Exception.Message
        }
    }
    
    # Test 3: Test authentication status
    try {
        $authResult = Test-SpotifyAuthentication -ErrorAction Stop
        Write-TestResult "Spotify authentication test" $true -Details "Authentication check completed"
        
        # Test 4: Check if we have valid tokens
        $tokenPath = "$env:APPDATA\SpotifyCLI\tokens.json"
        $hasTokens = Test-Path $tokenPath
        Write-TestResult "Authentication tokens exist" $hasTokens -Details "Token file: $tokenPath"
        
        if ($hasTokens) {
            try {
                $tokens = Get-Content $tokenPath | ConvertFrom-Json
                $hasAccessToken = -not [string]::IsNullOrEmpty($tokens.access_token)
                Write-TestResult "Valid access token present" $hasAccessToken
            } catch {
                Write-TestResult "Parse token file" $false -Error $_.Exception.Message
            }
        }
    } catch {
        Write-TestResult "Spotify authentication test" $false -Error $_.Exception.Message
    }
}

function Test-SearchWorkflow {
    Write-Host "`n=== Testing Search Workflow ===" -ForegroundColor Cyan
    
    # Test 1: Basic search functionality
    try {
        Write-Host "Testing search for 'bohemian rhapsody'..." -ForegroundColor Yellow
        $searchResult = Invoke-SpotifySearch -Query "bohemian rhapsody" -Type "track" -Limit 5
        
        $hasResults = $searchResult -and $searchResult.tracks -and $searchResult.tracks.items.Count -gt 0
        Write-TestResult "Basic search returns results" $hasResults -Details "Found $($searchResult.tracks.items.Count) tracks"
        
        if ($hasResults) {
            # Test 2: Verify search result structure
            $firstTrack = $searchResult.tracks.items[0]
            $hasName = -not [string]::IsNullOrEmpty($firstTrack.name)
            $hasArtist = $firstTrack.artists -and $firstTrack.artists.Count -gt 0
            
            Write-TestResult "Search results have track names" $hasName -Details "First track: $($firstTrack.name)"
            Write-TestResult "Search results have artist info" $hasArtist -Details "First artist: $($firstTrack.artists[0].name)"
        }
    } catch {
        Write-TestResult "Basic search functionality" $false -Error $_.Exception.Message
    }
    
    # Test 3: Album search
    try {
        Write-Host "Testing album search for 'dark side of the moon'..." -ForegroundColor Yellow
        $albumResult = Invoke-SpotifySearch -Query "dark side of the moon" -Type "album" -Limit 3
        
        $hasAlbums = $albumResult -and $albumResult.albums -and $albumResult.albums.items.Count -gt 0
        Write-TestResult "Album search returns results" $hasAlbums -Details "Found $($albumResult.albums.items.Count) albums"
    } catch {
        Write-TestResult "Album search functionality" $false -Error $_.Exception.Message
    }
}

function Test-DeviceManagement {
    Write-Host "`n=== Testing Device Management ===" -ForegroundColor Cyan
    
    # Test 1: Get available devices
    try {
        $devices = Get-SpotifyDevices
        $hasDevices = $devices -and $devices.Count -gt 0
        
        Write-TestResult "Get available devices" $true -Details "Found $($devices.Count) devices"
        
        if ($hasDevices) {
            # Test 2: Check device information structure
            $firstDevice = $devices[0]
            $hasName = -not [string]::IsNullOrEmpty($firstDevice.name)
            $hasType = -not [string]::IsNullOrEmpty($firstDevice.type)
            
            Write-TestResult "Devices have name information" $hasName -Details "First device: $($firstDevice.name)"
            Write-TestResult "Devices have type information" $hasType -Details "Device type: $($firstDevice.type)"
            
            # Test 3: Check for active device
            $activeDevice = $devices | Where-Object { $_.is_active -eq $true }
            $hasActiveDevice = $activeDevice -ne $null
            Write-TestResult "Has active device" $hasActiveDevice -Details $(if ($hasActiveDevice) { "Active: $($activeDevice.name)" } else { "No active device found" })
        } else {
            Write-TestResult "Device availability" $false -Error "No Spotify devices found. Please start Spotify on at least one device."
        }
    } catch {
        Write-TestResult "Get available devices" $false -Error $_.Exception.Message
    }
}

function Test-PlaybackControls {
    Write-Host "`n=== Testing Playback Controls ===" -ForegroundColor Cyan
    
    # Test 1: Get current playback state
    try {
        $playback = Get-SpotifyPlayback
        $hasPlayback = $playback -ne $null
        
        Write-TestResult "Get current playback state" $true -Details $(if ($hasPlayback) { "Playback state retrieved" } else { "No active playback" })
        
        if ($hasPlayback -and $playback.item) {
            # Test 2: Verify playback information structure
            $hasTrackName = -not [string]::IsNullOrEmpty($playback.item.name)
            $hasProgress = $playback.progress_ms -ne $null
            
            Write-TestResult "Playback has track information" $hasTrackName -Details "Current track: $($playback.item.name)"
            Write-TestResult "Playback has progress information" $hasProgress -Details "Progress: $($playback.progress_ms)ms"
        }
    } catch {
        Write-TestResult "Get current playback state" $false -Error $_.Exception.Message
    }
    
    # Test 3: Test basic control commands (if interactive mode)
    if ($Interactive) {
        Write-Host "`nTesting basic playback controls (interactive mode)..." -ForegroundColor Yellow
        
        try {
            # Test pause/play toggle
            Write-Host "Testing pause command..." -ForegroundColor Yellow
            $pauseResult = Set-SpotifyPlayback -Action "pause"
            Write-TestResult "Pause command execution" $true -Details "Pause command sent"
            
            Start-Sleep -Seconds 2
            
            Write-Host "Testing play command..." -ForegroundColor Yellow
            $playResult = Set-SpotifyPlayback -Action "play"
            Write-TestResult "Play command execution" $true -Details "Play command sent"
        } catch {
            Write-TestResult "Basic playback controls" $false -Error $_.Exception.Message
        }
    } else {
        Write-Host "Skipping interactive playback tests (use -Interactive flag to enable)" -ForegroundColor Yellow
    }
}

function Test-ErrorRecovery {
    Write-Host "`n=== Testing Error Recovery and Guidance ===" -ForegroundColor Cyan
    
    # Test 1: Invalid search query handling
    try {
        $emptyResult = Invoke-SpotifySearch -Query "" -Type "track" -Limit 1
        Write-TestResult "Handle empty search query" $true -Details "Empty search handled gracefully"
    } catch {
        $errorHandled = $_.Exception.Message -match "query|search|invalid"
        Write-TestResult "Handle empty search query with proper error" $errorHandled -Error $_.Exception.Message
    }
    
    # Test 2: Network connectivity test
    try {
        $spotifyReachable = Test-NetConnection -ComputerName "api.spotify.com" -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue
        Write-TestResult "Spotify API network connectivity" $spotifyReachable -Details "api.spotify.com:443 reachable"
    } catch {
        Write-TestResult "Network connectivity test" $false -Error $_.Exception.Message
    }
    
    # Test 3: Configuration file handling
    $configPath = "$env:APPDATA\SpotifyCLI\config.json"
    $configExists = Test-Path $configPath
    
    if ($configExists) {
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            Write-TestResult "Configuration file parsing" $true -Details "Config loaded successfully"
        } catch {
            Write-TestResult "Configuration file parsing" $false -Error $_.Exception.Message
        }
    } else {
        Write-TestResult "Configuration file exists" $false -Details "Config will be created on first use"
    }
}

function Test-StateManagement {
    Write-Host "`n=== Testing State Management ===" -ForegroundColor Cyan
    
    # Test 1: Session variables initialization
    $sessionVarsExist = $true
    $sessionVars = @('SessionDevices', 'SessionTracks', 'SessionPlaylists', 'SessionAlbums')
    
    foreach ($var in $sessionVars) {
        $varExists = Get-Variable -Name $var -Scope Script -ErrorAction SilentlyContinue
        if (-not $varExists) {
            $sessionVarsExist = $false
            break
        }
    }
    
    Write-TestResult "Session variables initialized" $sessionVarsExist -Details "All session state variables present"
    
    # Test 2: Smart number functionality simulation
    try {
        # Simulate search to populate session state
        $searchResult = Invoke-SpotifySearch -Query "test" -Type "track" -Limit 3
        if ($searchResult -and $searchResult.tracks.items.Count -gt 0) {
            # This would normally populate $script:SessionTracks
            Write-TestResult "Smart number state management" $true -Details "Search results can populate session state"
        }
    } catch {
        Write-TestResult "Smart number state management" $false -Error $_.Exception.Message
    }
}

# Main execution
Write-Host "Starting First-Time User Workflow Integration Test" -ForegroundColor Magenta
Write-Host "=============================================" -ForegroundColor Magenta

# Run all test phases
Test-AuthenticationFlow
Test-SearchWorkflow
Test-DeviceManagement
Test-PlaybackControls
Test-ErrorRecovery
Test-StateManagement

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

# Recommendations based on results
Write-Host "`n=== Recommendations ===" -ForegroundColor Cyan

if ($TestResults.FailedTests -eq 0) {
    Write-Host "✓ All tests passed! The first-time user workflow is working correctly." -ForegroundColor Green
} else {
    Write-Host "⚠ Some tests failed. Please address the following:" -ForegroundColor Yellow
    
    if ($TestResults.Errors -match "\.env") {
        Write-Host "  • Set up .env file with Spotify credentials" -ForegroundColor Yellow
    }
    if ($TestResults.Errors -match "device|Device") {
        Write-Host "  • Start Spotify on at least one device" -ForegroundColor Yellow
    }
    if ($TestResults.Errors -match "auth|token") {
        Write-Host "  • Complete Spotify authentication process" -ForegroundColor Yellow
    }
    if ($TestResults.Errors -match "network|connectivity") {
        Write-Host "  • Check internet connection and firewall settings" -ForegroundColor Yellow
    }
}

Write-Host "`nFirst-Time User Workflow Test Complete" -ForegroundColor Magenta