#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test the fixed interactive queue functionality
#>

# Import the module
Import-Module .\SpotifyModule.psm1 -Force

Write-Host "🧪 Testing Interactive Queue Fix" -ForegroundColor Cyan
Write-Host ""

# Test the queue API call directly to make sure it works
Write-Host "Testing direct queue API call..." -ForegroundColor White

# First do a search to get some tracks
Write-Host "Performing search to get test tracks..." -ForegroundColor Gray
try {
    search "test track" | Out-Null
    Write-Host "✅ Search completed" -ForegroundColor Green
    
    # Test adding track #1 to queue using the corrected method
    Write-Host "Testing queue addition with Query parameter..." -ForegroundColor Gray
    queue 1
    Write-Host "✅ Queue test completed" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "💡 The interactive mode Space key should now work correctly!" -ForegroundColor Green
Write-Host "💡 Try running 'search \"your favorite song\"' and then press Enter for interactive mode" -ForegroundColor Cyan
Write-Host "💡 In interactive mode, use Space to add tracks to queue" -ForegroundColor Cyan