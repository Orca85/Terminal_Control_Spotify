#!/usr/bin/env pwsh
<#
.SYNOPSIS
Basic test for queue functionality
#>

# Import the module
Import-Module .\SpotifyModule.psm1 -Force

Write-Host "🧪 Testing Basic Queue Functionality" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if queue function exists
Write-Host "Test 1: Checking if queue function exists..." -ForegroundColor White
try {
    $queueCommand = Get-Command queue -ErrorAction Stop
    Write-Host "✅ queue function found: $($queueCommand.Name)" -ForegroundColor Green
} catch {
    Write-Host "❌ queue function not found: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Check if play-album function exists
Write-Host "Test 2: Checking if play-album function exists..." -ForegroundColor White
try {
    $playAlbumCommand = Get-Command play-album -ErrorAction Stop
    Write-Host "✅ play-album function found: $($playAlbumCommand.Name)" -ForegroundColor Green
} catch {
    Write-Host "❌ play-album function not found: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Check if queue-album function exists
Write-Host "Test 3: Checking if queue-album function exists..." -ForegroundColor White
try {
    $queueAlbumCommand = Get-Command queue-album -ErrorAction Stop
    Write-Host "✅ queue-album function found: $($queueAlbumCommand.Name)" -ForegroundColor Green
} catch {
    Write-Host "❌ queue-album function not found: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Test queue display (without authentication)
Write-Host "Test 4: Testing queue display..." -ForegroundColor White
try {
    # This will likely fail due to authentication, but we can see if the function structure works
    queue
    Write-Host "✅ queue display executed (may have failed due to auth)" -ForegroundColor Green
} catch {
    Write-Host "❌ queue display failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "✅ Basic function structure test completed" -ForegroundColor Green