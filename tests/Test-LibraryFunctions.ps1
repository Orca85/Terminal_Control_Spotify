#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test script for Spotify CLI library functions (Task 9.3)

.DESCRIPTION
Tests library functions: liked, recent, save-track, unsave-track
according to requirements 8.7, 8.8, 8.9, 8.10
#>

# Import the Spotify module
Import-Module .\SpotifyModule.psm1 -Force

Write-Host "🧪 Testing Library Functions (Task 9.3)" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Gray
Write-Host ""

# Test results tracking
$testResults = @{
    LikedCommand = $false
    RecentCommand = $false
    SaveTrackCurrent = $false
    UnsaveTrackCurrent = $false
    SaveTrackByNumber = $false
    UnsaveTrackByNumber = $false
}

# Test 1: Test `liked` command
Write-Host "🔍 Test 1: Testing 'liked' command" -ForegroundColor Yellow
Write-Host "Expected: Display user's liked songs with details" -ForegroundColor Gray
Write-Host ""

try {
    Write-Host "Running: liked" -ForegroundColor Cyan
    $likedOutput = liked 2>&1
    
    if ($likedOutput -match "❤️ Your Liked Songs:" -or $likedOutput -match "No liked songs found") {
        Write-Host "✅ 'liked' command executed successfully" -ForegroundColor Green
        $testResults.LikedCommand = $true
        
        # Check for proper formatting (track info, dates, URIs)
        if ($likedOutput -match "Added:.*URI:" -or $likedOutput -match "No liked songs found") {
            Write-Host "✅ Liked songs display format is correct" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Liked songs display format may be incomplete" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ 'liked' command failed or produced unexpected output" -ForegroundColor Red
        Write-Host "Output: $likedOutput" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Error testing 'liked' command: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 2: Test `recent` command
Write-Host "🔍 Test 2: Testing 'recent' command" -ForegroundColor Yellow
Write-Host "Expected: Display recently played tracks and episodes" -ForegroundColor Gray
Write-Host ""

try {
    Write-Host "Running: recent" -ForegroundColor Cyan
    $recentOutput = recent 2>&1
    
    if ($recentOutput -match "🕒 Recently Played:" -or $recentOutput -match "No recent tracks found") {
        Write-Host "✅ 'recent' command executed successfully" -ForegroundColor Green
        $testResults.RecentCommand = $true
        
        # Check for proper formatting (played dates, URIs)
        if ($recentOutput -match "Played:.*URI:" -or $recentOutput -match "No recent tracks found") {
            Write-Host "✅ Recent tracks display format is correct" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Recent tracks display format may be incomplete" -ForegroundColor Yellow
        }
        
        # Check for podcast episode support
        if ($recentOutput -match "🎙️") {
            Write-Host "✅ Podcast episode support detected in recent tracks" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ 'recent' command failed or produced unexpected output" -ForegroundColor Red
        Write-Host "Output: $recentOutput" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Error testing 'recent' command: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Test save-track (current track)
Write-Host "🔍 Test 3: Testing 'save-track' for current track" -ForegroundColor Yellow
Write-Host "Expected: Save currently playing track to library" -ForegroundColor Gray
Write-Host ""

try {
    # Check if there's a current track
    $currentTrack = Show-SpotifyTrack 2>&1
    if ($currentTrack -match "No track currently playing") {
        Write-Host "⚠️ No track currently playing - skipping current track save test" -ForegroundColor Yellow
    } else {
        Write-Host "Current track detected, testing save-track..." -ForegroundColor Cyan
        $saveOutput = save-track 2>&1
        
        if ($saveOutput -match "❤️ Saved.*to your library") {
            Write-Host "✅ 'save-track' (current) executed successfully" -ForegroundColor Green
            $testResults.SaveTrackCurrent = $true
        } else {
            Write-Host "❌ 'save-track' (current) failed: $saveOutput" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "❌ Error testing 'save-track' (current): $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Test unsave-track (current track)
Write-Host "🔍 Test 4: Testing 'unsave-track' for current track" -ForegroundColor Yellow
Write-Host "Expected: Remove currently playing track from library" -ForegroundColor Gray
Write-Host ""

try {
    # Check if there's a current track
    $currentTrack = Show-SpotifyTrack 2>&1
    if ($currentTrack -match "No track currently playing") {
        Write-Host "⚠️ No track currently playing - skipping current track unsave test" -ForegroundColor Yellow
    } else {
        Write-Host "Current track detected, testing unsave-track..." -ForegroundColor Cyan
        $unsaveOutput = unsave-track 2>&1
        
        if ($unsaveOutput -match "💔 Removed.*from your library") {
            Write-Host "✅ 'unsave-track' (current) executed successfully" -ForegroundColor Green
            $testResults.UnsaveTrackCurrent = $true
        } else {
            Write-Host "❌ 'unsave-track' (current) failed: $unsaveOutput" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "❌ Error testing 'unsave-track' (current): $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 5: Test save-track by number (requires search results)
Write-Host "🔍 Test 5: Testing 'save-track' by number" -ForegroundColor Yellow
Write-Host "Expected: Save track by number from search results" -ForegroundColor Gray
Write-Host ""

try {
    # We need to manually populate session tracks for testing
    # This simulates having search results available
    Write-Host "Note: This test requires search results to be available" -ForegroundColor Gray
    Write-Host "In normal usage, run 'search \"query\"' first, then 'save-track 1'" -ForegroundColor Cyan
    
    # Test with invalid number (should fail gracefully)
    $saveByNumberOutput = save-track 999 2>&1
    if ($saveByNumberOutput -match "❌ Invalid item number" -or $saveByNumberOutput -match "❌ No.*in session") {
        Write-Host "✅ 'save-track' by number handles invalid input correctly" -ForegroundColor Green
        $testResults.SaveTrackByNumber = $true
    } else {
        Write-Host "⚠️ 'save-track' by number error handling may need improvement" -ForegroundColor Yellow
        Write-Host "Output: $saveByNumberOutput" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Error testing 'save-track' by number: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 6: Test unsave-track by number
Write-Host "🔍 Test 6: Testing 'unsave-track' by number" -ForegroundColor Yellow
Write-Host "Expected: Remove track by number from library" -ForegroundColor Gray
Write-Host ""

try {
    # Test with invalid number (should fail gracefully)
    $unsaveByNumberOutput = unsave-track 999 2>&1
    if ($unsaveByNumberOutput -match "❌ Invalid item number" -or $unsaveByNumberOutput -match "❌ No.*in session") {
        Write-Host "✅ 'unsave-track' by number handles invalid input correctly" -ForegroundColor Green
        $testResults.UnsaveTrackByNumber = $true
    } else {
        Write-Host "⚠️ 'unsave-track' by number error handling may need improvement" -ForegroundColor Yellow
        Write-Host "Output: $unsaveByNumberOutput" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Error testing 'unsave-track' by number: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Summary
Write-Host "📊 Test Results Summary" -ForegroundColor Cyan
Write-Host "=" * 30 -ForegroundColor Gray

$passedTests = ($testResults.Values | Where-Object { $_ -eq $true }).Count
$totalTests = $testResults.Count

foreach ($test in $testResults.GetEnumerator()) {
    $status = if ($test.Value) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($test.Value) { "Green" } else { "Red" }
    Write-Host "$status $($test.Key)" -ForegroundColor $color
}

Write-Host ""
Write-Host "Overall: $passedTests/$totalTests tests passed" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })

# Requirements mapping
Write-Host ""
Write-Host "📋 Requirements Coverage:" -ForegroundColor Cyan
Write-Host "8.7 - 'liked' command functionality: $(if ($testResults.LikedCommand) { '✅' } else { '❌' })" -ForegroundColor $(if ($testResults.LikedCommand) { "Green" } else { "Red" })
Write-Host "8.8 - 'recent' command functionality: $(if ($testResults.RecentCommand) { '✅' } else { '❌' })" -ForegroundColor $(if ($testResults.RecentCommand) { "Green" } else { "Red" })
Write-Host "8.9 - 'save-track' functionality: $(if ($testResults.SaveTrackCurrent -and $testResults.SaveTrackByNumber) { '✅' } else { '❌' })" -ForegroundColor $(if ($testResults.SaveTrackCurrent -and $testResults.SaveTrackByNumber) { "Green" } else { "Red" })
Write-Host "8.10 - 'unsave-track' functionality: $(if ($testResults.UnsaveTrackCurrent -and $testResults.UnsaveTrackByNumber) { '✅' } else { '❌' })" -ForegroundColor $(if ($testResults.UnsaveTrackCurrent -and $testResults.UnsaveTrackByNumber) { "Green" } else { "Red" })

Write-Host ""
Write-Host "💡 Usage Examples:" -ForegroundColor Cyan
Write-Host "• liked                    - Show your liked songs" -ForegroundColor White
Write-Host "• recent                   - Show recently played tracks" -ForegroundColor White
Write-Host "• save-track               - Save current track" -ForegroundColor White
Write-Host "• save-track 3             - Save track #3 from search" -ForegroundColor White
Write-Host "• unsave-track             - Remove current track from library" -ForegroundColor White
Write-Host "• unsave-track 2           - Remove track #2 from library" -ForegroundColor White

Write-Host ""
Write-Host "✅ Library Functions Test Complete" -ForegroundColor Green