#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test script for Spotify CLI playlist management functionality (Task 9.1)

.DESCRIPTION
Tests playlist listing, smart numbering, and playlist playback functionality
according to requirements 8.1, 8.2, 8.3, 8.4, 8.5

.NOTES
This script tests:
- `playlists` and `pl` commands
- Smart numbering and playlist information display  
- `play-playlist 1` and `play-playlist 1 5` functionality
#>

param(
    [switch]$Verbose,
    [switch]$Interactive
)

# Import the Spotify module
Import-Module .\SpotifyModule.psm1 -Force

Write-Host "🧪 Testing Playlist Management (Task 9.1)" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Gray
Write-Host ""

# Test results tracking
$testResults = @{
    PlaylistsCommand = $false
    PlAlias = $false
    SmartNumbering = $false
    PlaylistInfo = $false
    PlayPlaylistBasic = $false
    PlayPlaylistSpecific = $false
}

# Test 1: Test `playlists` command
Write-Host "🔍 Test 1: Testing 'playlists' command" -ForegroundColor Yellow
Write-Host "Expected: Display user's playlists with smart numbers" -ForegroundColor Gray
Write-Host ""

try {
    Write-Host "Running: playlists" -ForegroundColor Cyan
    $playlistsOutput = playlists 2>&1
    
    if ($playlistsOutput -match "📚 Your Playlists:" -or $playlistsOutput -match "No playlists found") {
        Write-Host "✅ 'playlists' command executed successfully" -ForegroundColor Green
        $testResults.PlaylistsCommand = $true
        
        # Check for smart numbering (look for numbered items)
        if ($playlistsOutput -match "^\s*\d+\.\s+") {
            Write-Host "✅ Smart numbering detected in playlist display" -ForegroundColor Green
            $testResults.SmartNumbering = $true
        } else {
            Write-Host "⚠️ Smart numbering not detected (may be no playlists)" -ForegroundColor Yellow
        }
        
        # Check for playlist information (tracks count, owner)
        if ($playlistsOutput -match "tracks.*by" -or $playlistsOutput -match "No playlists found") {
            Write-Host "✅ Playlist information display working" -ForegroundColor Green
            $testResults.PlaylistInfo = $true
        } else {
            Write-Host "⚠️ Playlist information display may be incomplete" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ 'playlists' command failed or produced unexpected output" -ForegroundColor Red
        Write-Host "Output: $playlistsOutput" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Error testing 'playlists' command: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 2: Test `pl` alias
Write-Host "🔍 Test 2: Testing 'pl' alias" -ForegroundColor Yellow
Write-Host "Expected: Same output as 'playlists' command" -ForegroundColor Gray
Write-Host ""

try {
    Write-Host "Running: pl" -ForegroundColor Cyan
    $plOutput = pl 2>&1
    
    if ($plOutput -match "📚 Your Playlists:" -or $plOutput -match "No playlists found") {
        Write-Host "✅ 'pl' alias executed successfully" -ForegroundColor Green
        $testResults.PlAlias = $true
    } else {
        Write-Host "❌ 'pl' alias failed or produced unexpected output" -ForegroundColor Red
        Write-Host "Output: $plOutput" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Error testing 'pl' alias: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Test play-playlist function (check if it exists)
Write-Host "🔍 Test 3: Testing 'play-playlist' function availability" -ForegroundColor Yellow
Write-Host "Expected: Function should exist and be callable" -ForegroundColor Gray
Write-Host ""

$playPlaylistExists = Get-Command -Name "play-playlist" -ErrorAction SilentlyContinue
if ($playPlaylistExists) {
    Write-Host "✅ 'play-playlist' function found" -ForegroundColor Green
    
    # Test basic playlist playback (if user confirms they have playlists)
    if ($Interactive) {
        $hasPlaylists = Read-Host "Do you have playlists available to test with? (y/N)"
        if ($hasPlaylists -eq 'y' -or $hasPlaylists -eq 'Y') {
            Write-Host ""
            Write-Host "Testing: play-playlist 1" -ForegroundColor Cyan
            try {
                play-playlist 1
                Write-Host "✅ 'play-playlist 1' executed (check Spotify for playback)" -ForegroundColor Green
                $testResults.PlayPlaylistBasic = $true
            } catch {
                Write-Host "❌ Error with 'play-playlist 1': $($_.Exception.Message)" -ForegroundColor Red
            }
            
            Write-Host ""
            Write-Host "Testing: play-playlist 1 5" -ForegroundColor Cyan
            try {
                play-playlist 1 5
                Write-Host "✅ 'play-playlist 1 5' executed (check Spotify for specific track)" -ForegroundColor Green
                $testResults.PlayPlaylistSpecific = $true
            } catch {
                Write-Host "❌ Error with 'play-playlist 1 5': $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "⚠️ Skipping playlist playback tests (no playlists available)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "ℹ️ Run with -Interactive to test playlist playback" -ForegroundColor Cyan
    }
} else {
    Write-Host "❌ 'play-playlist' function not found - needs to be implemented" -ForegroundColor Red
    Write-Host "💡 This function should accept playlist number and optional track number" -ForegroundColor Yellow
}

Write-Host ""

# Test 4: Check session playlist storage
Write-Host "🔍 Test 4: Testing session playlist storage" -ForegroundColor Yellow
Write-Host "Expected: Playlists should be stored in session for smart numbering" -ForegroundColor Gray
Write-Host ""

try {
    # Run playlists command to populate session storage
    playlists | Out-Null
    
    # Check if session playlists are populated (this requires access to script scope)
    $sessionPlaylistsExist = $false
    try {
        # Try to access the session variable (may not work due to scope)
        if (Get-Variable -Name "SessionPlaylists" -Scope Script -ErrorAction SilentlyContinue) {
            $sessionPlaylistsExist = $true
        }
    } catch {
        # Can't directly access, but that's expected
    }
    
    if ($sessionPlaylistsExist) {
        Write-Host "✅ Session playlist storage appears to be working" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Cannot verify session playlist storage (scope limitations)" -ForegroundColor Yellow
        Write-Host "💡 This should be verified by checking if playlist numbers work consistently" -ForegroundColor Cyan
    }
} catch {
    Write-Host "❌ Error testing session playlist storage: $($_.Exception.Message)" -ForegroundColor Red
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
Write-Host "8.1 - Playlist display with smart numbers: $(if ($testResults.PlaylistsCommand -and $testResults.SmartNumbering) { '✅' } else { '❌' })" -ForegroundColor $(if ($testResults.PlaylistsCommand -and $testResults.SmartNumbering) { "Green" } else { "Red" })
Write-Host "8.2 - Playlist information display: $(if ($testResults.PlaylistInfo) { '✅' } else { '❌' })" -ForegroundColor $(if ($testResults.PlaylistInfo) { "Green" } else { "Red" })
Write-Host "8.3 - 'pl' alias functionality: $(if ($testResults.PlAlias) { '✅' } else { '❌' })" -ForegroundColor $(if ($testResults.PlAlias) { "Green" } else { "Red" })
Write-Host "8.4 - 'play-playlist 1' functionality: $(if ($testResults.PlayPlaylistBasic) { '✅' } else { '❌' })" -ForegroundColor $(if ($testResults.PlayPlaylistBasic) { "Green" } else { "Red" })
Write-Host "8.5 - 'play-playlist 1 5' functionality: $(if ($testResults.PlayPlaylistSpecific) { '✅' } else { '❌' })" -ForegroundColor $(if ($testResults.PlayPlaylistSpecific) { "Green" } else { "Red" })

Write-Host ""

# Recommendations
if (-not $playPlaylistExists) {
    Write-Host "🔧 REQUIRED FIXES:" -ForegroundColor Yellow
    Write-Host "1. Implement 'play-playlist' function in SpotifyModule.psm1" -ForegroundColor White
    Write-Host "2. Function should accept playlist number and optional track number" -ForegroundColor White
    Write-Host "3. Should use session playlist storage for smart numbering" -ForegroundColor White
    Write-Host "4. Add function to module exports" -ForegroundColor White
}

if ($Verbose) {
    Write-Host ""
    Write-Host "🔍 Detailed Information:" -ForegroundColor Cyan
    Write-Host "- Playlists command uses Spotify API: /me/playlists" -ForegroundColor Gray
    Write-Host "- Smart numbering should use script:SessionPlaylists array" -ForegroundColor Gray
    Write-Host "- Playlist playback should use /me/player/play endpoint" -ForegroundColor Gray
    Write-Host "- Track-specific playback needs playlist tracks API call" -ForegroundColor Gray
}

Write-Host ""
Write-Host "✅ Playlist Management Test Complete" -ForegroundColor Green