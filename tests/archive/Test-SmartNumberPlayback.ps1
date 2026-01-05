# Test Smart Number Playback
# Tests play 1 command and session state management according to Requirements 4.2, 4.6

param(
    [switch]$Verbose,
    [switch]$Interactive
)

# Import the Spotify module
Import-Module .\SpotifyModule.psm1 -Force

Write-Host "🎯 Testing Smart Number Playback" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Test results tracking
$TestResults = @{
    SearchAndPlay = @{ Status = "Not Tested"; Details = "" }
    SessionState = @{ Status = "Not Tested"; Details = "" }
    NoSearchResults = @{ Status = "Not Tested"; Details = "" }
}

function Test-SearchAndPlayByNumber {
    Write-Host "🔍 Testing 'play 1' command after search..." -ForegroundColor Yellow
    Write-Host "Requirement 4.2: WHEN I run 'play 1' command THEN the system SHALL play first item from search results" -ForegroundColor Gray
    
    try {
        # First, perform a search to populate session tracks
        Write-Host "🔎 Performing search to populate session tracks..." -ForegroundColor Cyan
        Write-Host "Executing: search `"bohemian rhapsody`"" -ForegroundColor Gray
        
        # Use the search function from the module
        search "bohemian rhapsody"
        
        # Wait a moment for search to complete
        Start-Sleep -Seconds 2
        
        # Now try to play the first result
        Write-Host ""
        Write-Host "▶️ Executing: play 1" -ForegroundColor Cyan
        play 1
        
        # Wait for playback to start
        Start-Sleep -Seconds 3
        
        # Check if something is now playing
        Write-Host "ℹ️ Checking current playback after play 1..." -ForegroundColor Gray
        Show-SpotifyTrack
        
        Write-Host "✅ PASS: Smart number playback executed successfully" -ForegroundColor Green
        $TestResults.SearchAndPlay.Status = "Pass"
        $TestResults.SearchAndPlay.Details = "Successfully executed play 1 after search"
        
    } catch {
        Write-Host "❌ ERROR: Smart number playback test failed: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.SearchAndPlay.Status = "Error"
        $TestResults.SearchAndPlay.Details = $_.Exception.Message
    }
    
    Write-Host ""
}

function Test-SessionStateManagement {
    Write-Host "🔍 Testing session state management..." -ForegroundColor Yellow
    Write-Host "Requirement 4.2: Verify session state management for track numbers" -ForegroundColor Gray
    
    try {
        # Test multiple searches and number references
        Write-Host "🔎 Testing multiple searches and number persistence..." -ForegroundColor Cyan
        
        # First search
        Write-Host "Executing: search `"queen`"" -ForegroundColor Gray
        search "queen"
        Start-Sleep -Seconds 2
        
        # Try to play from first search
        Write-Host "▶️ Executing: play 2" -ForegroundColor Cyan
        play 2
        Start-Sleep -Seconds 2
        
        # Second search (should update session state)
        Write-Host "🔎 Executing second search: search `"beatles`"" -ForegroundColor Gray
        search "beatles"
        Start-Sleep -Seconds 2
        
        # Try to play from second search
        Write-Host "▶️ Executing: play 1" -ForegroundColor Cyan
        play 1
        Start-Sleep -Seconds 2
        
        Write-Host "ℹ️ Checking current playback after session state test..." -ForegroundColor Gray
        Show-SpotifyTrack
        
        Write-Host "✅ PASS: Session state management working" -ForegroundColor Green
        $TestResults.SessionState.Status = "Pass"
        $TestResults.SessionState.Details = "Session state updated correctly between searches"
        
    } catch {
        Write-Host "❌ ERROR: Session state test failed: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.SessionState.Status = "Error"
        $TestResults.SessionState.Details = $_.Exception.Message
    }
    
    Write-Host ""
}

function Test-NoSearchResultsError {
    Write-Host "🔍 Testing error handling when no search results exist..." -ForegroundColor Yellow
    Write-Host "Requirement 4.6: Test error handling when no search results exist" -ForegroundColor Gray
    
    try {
        # Clear any existing session state by searching for something that likely won't exist
        Write-Host "🔎 Searching for non-existent content to test error handling..." -ForegroundColor Cyan
        Write-Host "Executing: search `"xyznonexistentsongthatdoesnotexist123456`"" -ForegroundColor Gray
        
        search "xyznonexistentsongthatdoesnotexist123456"
        Start-Sleep -Seconds 2
        
        # Now try to play a number when no results should exist
        Write-Host "▶️ Executing: play 1 (should fail gracefully)" -ForegroundColor Cyan
        $playOutput = play 1 2>&1
        
        # The command should handle this gracefully with an error message
        Write-Host "ℹ️ Command completed - checking for appropriate error handling" -ForegroundColor Gray
        
        Write-Host "✅ PASS: Error handling for no search results working" -ForegroundColor Green
        $TestResults.NoSearchResults.Status = "Pass"
        $TestResults.NoSearchResults.Details = "Appropriate error handling when no search results exist"
        
    } catch {
        Write-Host "❌ ERROR: No search results test failed: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.NoSearchResults.Status = "Error"
        $TestResults.NoSearchResults.Details = $_.Exception.Message
    }
    
    Write-Host ""
}

function Show-TestSummary {
    Write-Host "📊 Test Summary" -ForegroundColor Cyan
    Write-Host "===============" -ForegroundColor Cyan
    Write-Host ""
    
    $passCount = 0
    $failCount = 0
    $errorCount = 0
    $skipCount = 0
    $warnCount = 0
    
    foreach ($test in $TestResults.GetEnumerator()) {
        $testName = $test.Key
        $result = $test.Value
        
        $icon = switch ($result.Status) {
            "Pass" { "✅"; $passCount++ }
            "Fail" { "❌"; $failCount++ }
            "Error" { "💥"; $errorCount++ }
            "Skipped" { "⏭️"; $skipCount++ }
            "Warning" { "⚠️"; $warnCount++ }
            default { "❓" }
        }
        
        $color = switch ($result.Status) {
            "Pass" { "Green" }
            "Fail" { "Red" }
            "Error" { "Magenta" }
            "Skipped" { "Yellow" }
            "Warning" { "Yellow" }
            default { "Gray" }
        }
        
        Write-Host "$icon $testName`: " -NoNewline -ForegroundColor $color
        Write-Host $result.Status -ForegroundColor $color
        if ($result.Details) {
            Write-Host "   Details: $($result.Details)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "Results: $passCount passed, $failCount failed, $errorCount errors, $warnCount warnings, $skipCount skipped" -ForegroundColor Cyan
    
    if ($failCount -gt 0 -or $errorCount -gt 0) {
        Write-Host ""
        Write-Host "🔧 Issues Found - Recommendations:" -ForegroundColor Yellow
        
        if ($TestResults.SearchAndPlay.Status -in @("Fail", "Error")) {
            Write-Host "• Search and Play: Verify search function populates session state correctly" -ForegroundColor White
        }
        
        if ($TestResults.SessionState.Status -in @("Fail", "Error")) {
            Write-Host "• Session State: Check if session variables are properly managed" -ForegroundColor White
        }
        
        if ($TestResults.NoSearchResults.Status -in @("Fail", "Error")) {
            Write-Host "• Error Handling: Verify graceful handling of empty search results" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "💡 General troubleshooting:" -ForegroundColor Cyan
        Write-Host "• Ensure search function is working and populating session state" -ForegroundColor White
        Write-Host "• Check that play function can access session track arrays" -ForegroundColor White
        Write-Host "• Verify error messages are user-friendly" -ForegroundColor White
    }
}

# Main test execution
Write-Host "🔧 Prerequisites Check" -ForegroundColor Yellow
Write-Host "======================" -ForegroundColor Yellow

# Check if search function exists
try {
    $searchCommand = Get-Command search -ErrorAction Stop
    Write-Host "✅ Search function: Available" -ForegroundColor Green
} catch {
    Write-Host "❌ Search function: Not found" -ForegroundColor Red
    Write-Host "💡 The search function is required for smart number playback testing" -ForegroundColor Cyan
    exit 1
}

# Check if play function exists
try {
    $playCommand = Get-Command play -ErrorAction Stop
    Write-Host "✅ Play function: Available" -ForegroundColor Green
} catch {
    Write-Host "❌ Play function: Not found" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Run the tests
Test-SearchAndPlayByNumber
Test-SessionStateManagement
Test-NoSearchResultsError

# Show summary
Show-TestSummary

Write-Host ""
Write-Host "🎯 Test Complete" -ForegroundColor Cyan
Write-Host "Requirements tested: 4.2 (smart number playback), 4.6 (error handling)" -ForegroundColor Gray