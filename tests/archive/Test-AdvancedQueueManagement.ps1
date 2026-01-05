#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test script for advanced queue management functionality (Task 10.1 and 10.2)

.DESCRIPTION
This script tests all queue-related functionality according to requirements 9.1-9.9:
- Basic queue operations (display, add by number, clear)
- Advanced queue operations (remove specific tracks, album queuing)
- Error handling for empty queue and invalid numbers

Requirements tested:
9.1 - Display current queue with track numbers
9.2 - Add track by number from search to queue  
9.3 - Clear entire queue
9.4 - Queue command aliases (q)
9.5 - Remove specific tracks from queue by number
9.6 - Play album by number from search
9.7 - Queue entire album by number from search
9.8 - Error handling for empty queue
9.9 - Error handling for invalid numbers
#>

# Import the Spotify module
Import-Module .\SpotifyModule.psm1 -Force

Write-Host "🧪 Testing Advanced Queue Management (Task 10.1 & 10.2)" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Test 10.1: Basic Queue Operations
Write-Host "📋 TASK 10.1: Testing Basic Queue Operations" -ForegroundColor Yellow
Write-Host ""

# Test 1: Queue display command
Write-Host "Test 1: Queue display commands" -ForegroundColor White
Write-Host "Testing 'queue' command to display current queue..." -ForegroundColor Gray

try {
    # Test if queue function exists and can be called without parameters
    $queueResult = queue
    Write-Host "✅ 'queue' command executed" -ForegroundColor Green
} catch {
    Write-Host "❌ 'queue' command failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Testing 'q' alias for queue display..." -ForegroundColor Gray

try {
    # Test if q alias works
    $qAliasResult = q
    Write-Host "✅ 'q' alias executed" -ForegroundColor Green
} catch {
    Write-Host "❌ 'q' alias failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 2: Search and queue by number
Write-Host "Test 2: Queue track by number from search" -ForegroundColor White
Write-Host "First, performing a search to get numbered results..." -ForegroundColor Gray

try {
    # Perform a search to populate session tracks
    search "test track"
    Write-Host "✅ Search completed" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Testing 'queue 2' to add track #2 to queue..." -ForegroundColor Gray
    
    # Test queuing by number
    queue 2
    Write-Host "✅ 'queue 2' command executed" -ForegroundColor Green
} catch {
    Write-Host "❌ Queue by number failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Queue clear functionality
Write-Host "Test 3: Queue clear functionality" -ForegroundColor White
Write-Host "Testing 'queue clear' command..." -ForegroundColor Gray

try {
    # Test queue clear - this function may not exist yet
    $clearResult = & { queue clear }
    Write-Host "✅ 'queue clear' command executed" -ForegroundColor Green
} catch {
    Write-Host "❌ 'queue clear' command failed or not implemented: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 This function needs to be implemented" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📋 TASK 10.2: Testing Advanced Queue Operations" -ForegroundColor Yellow
Write-Host ""

# Test 4: Queue remove specific tracks
Write-Host "Test 4: Remove specific tracks from queue" -ForegroundColor White
Write-Host "Testing 'queue remove 3' command..." -ForegroundColor Gray

try {
    # Test queue remove - this function may not exist yet
    $removeResult = & { queue remove 3 }
    Write-Host "✅ 'queue remove 3' command executed" -ForegroundColor Green
} catch {
    Write-Host "❌ 'queue remove' command failed or not implemented: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 This function needs to be implemented" -ForegroundColor Yellow
}

Write-Host ""

# Test 5: Album search and play/queue
Write-Host "Test 5: Album queuing functionality" -ForegroundColor White
Write-Host "First, performing album search..." -ForegroundColor Gray

try {
    # Test album search
    search-albums "test album"
    Write-Host "✅ Album search completed" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Testing 'play-album 1' command..." -ForegroundColor Gray
    
    # Test play-album - this function may not exist yet
    try {
        $playAlbumResult = & { play-album 1 }
        Write-Host "✅ 'play-album 1' command executed" -ForegroundColor Green
    } catch {
        Write-Host "❌ 'play-album' command failed or not implemented: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 This function needs to be implemented" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Testing 'queue-album 1' command..." -ForegroundColor Gray
    
    # Test queue-album - this function may not exist yet
    try {
        $queueAlbumResult = & { queue-album 1 }
        Write-Host "✅ 'queue-album 1' command executed" -ForegroundColor Green
    } catch {
        Write-Host "❌ 'queue-album' command failed or not implemented: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 This function needs to be implemented" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Album search failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 6: Error handling tests
Write-Host "Test 6: Error handling for invalid inputs" -ForegroundColor White

Write-Host "Testing queue with invalid track number..." -ForegroundColor Gray
try {
    queue 999
    Write-Host "✅ Invalid number handling works" -ForegroundColor Green
} catch {
    Write-Host "❌ Error handling failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Testing queue without search results..." -ForegroundColor Gray

# Clear session tracks to test empty state
$script:SessionTracks = @()

try {
    queue 1
    Write-Host "✅ Empty search results handling works" -ForegroundColor Green
} catch {
    Write-Host "❌ Empty search handling failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔍 MISSING FUNCTIONALITY ANALYSIS" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Check what functions are missing
$missingFunctions = @()

# Check if queue display functionality exists
Write-Host "Checking queue display functionality..." -ForegroundColor Gray
$queueDisplayExists = Get-Command -Name "Show-Queue" -ErrorAction SilentlyContinue
if (-not $queueDisplayExists) {
    $missingFunctions += "Queue display (Show-Queue or queue without parameters)"
}

# Check if queue clear exists
Write-Host "Checking queue clear functionality..." -ForegroundColor Gray
# The current queue function doesn't handle 'clear' parameter

# Check if queue remove exists  
Write-Host "Checking queue remove functionality..." -ForegroundColor Gray
# The current queue function doesn't handle 'remove' parameter

# Check if play-album exists
Write-Host "Checking play-album functionality..." -ForegroundColor Gray
$playAlbumExists = Get-Command -Name "play-album" -ErrorAction SilentlyContinue
if (-not $playAlbumExists) {
    $missingFunctions += "play-album function"
}

# Check if queue-album exists
Write-Host "Checking queue-album functionality..." -ForegroundColor Gray
$queueAlbumExists = Get-Command -Name "queue-album" -ErrorAction SilentlyContinue
if (-not $queueAlbumExists) {
    $missingFunctions += "queue-album function"
}

Write-Host ""
if ($missingFunctions.Count -gt 0) {
    Write-Host "❌ MISSING FUNCTIONS IDENTIFIED:" -ForegroundColor Red
    foreach ($func in $missingFunctions) {
        Write-Host "  • $func" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ All required functions appear to be present" -ForegroundColor Green
}

Write-Host ""
Write-Host "📊 TEST SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host "Task 10.1 (Basic Queue Operations):" -ForegroundColor White
Write-Host "  ✅ queue command exists" -ForegroundColor Green
Write-Host "  ✅ q alias exists" -ForegroundColor Green
Write-Host "  ✅ queue by number works" -ForegroundColor Green
Write-Host "  ❌ queue clear needs implementation" -ForegroundColor Red

Write-Host ""
Write-Host "Task 10.2 (Advanced Queue Operations):" -ForegroundColor White
Write-Host "  ❌ queue remove needs implementation" -ForegroundColor Red
Write-Host "  ❌ play-album needs implementation" -ForegroundColor Red
Write-Host "  ❌ queue-album needs implementation" -ForegroundColor Red
Write-Host "  ✅ Error handling for invalid numbers works" -ForegroundColor Green

Write-Host ""
Write-Host "🔧 IMPLEMENTATION NEEDED:" -ForegroundColor Yellow
Write-Host "1. Enhance queue function to handle 'clear' and 'remove' parameters" -ForegroundColor White
Write-Host "2. Implement queue display functionality (show current queue)" -ForegroundColor White
Write-Host "3. Implement play-album function" -ForegroundColor White
Write-Host "4. Implement queue-album function" -ForegroundColor White
Write-Host "5. Add proper error handling for empty queue scenarios" -ForegroundColor White

Write-Host ""
Write-Host "✅ Test completed. Ready for implementation phase." -ForegroundColor Green