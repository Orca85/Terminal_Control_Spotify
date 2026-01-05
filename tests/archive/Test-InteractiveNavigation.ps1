#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test interactive navigation functionality
#>

# Import the module
Import-Module .\SpotifyModule.psm1 -Force

Write-Host "🧪 Testing Interactive Navigation" -ForegroundColor Cyan
Write-Host ""

# Test terminal capabilities first
Write-Host "Checking terminal capabilities..." -ForegroundColor Gray
$capabilities = Get-TerminalCapabilities
Write-Host "Terminal Type: $($capabilities.TerminalType)" -ForegroundColor White
Write-Host "Supports Interactive Input: $($capabilities.SupportsInteractiveInput)" -ForegroundColor White
Write-Host "Supports Colors: $($capabilities.SupportsColors)" -ForegroundColor White

if (-not $capabilities.SupportsInteractiveInput) {
    Write-Host "❌ Interactive input not supported in this terminal" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Terminal supports interactive navigation" -ForegroundColor Green
Write-Host ""

# Test the interactive navigation function directly
Write-Host "Testing interactive navigation with mock data..." -ForegroundColor Gray

# Create some mock items for testing
$mockItems = @(
    @{ name = "Test Track 1"; artists = @(@{ name = "Artist 1" }); uri = "spotify:track:test1" },
    @{ name = "Test Track 2"; artists = @(@{ name = "Artist 2" }); uri = "spotify:track:test2" },
    @{ name = "Test Track 3"; artists = @(@{ name = "Artist 3" }); uri = "spotify:track:test3" }
)

Write-Host "Starting interactive mode in 3 seconds..." -ForegroundColor Yellow
Write-Host "Use ↑↓ arrows to navigate, Enter to select, Escape to exit" -ForegroundColor Gray
Start-Sleep -Seconds 3

try {
    Test-InteractiveNavigation
    Write-Host "✅ Interactive navigation test completed" -ForegroundColor Green
} catch {
    Write-Host "❌ Interactive navigation test failed: $($_.Exception.Message)" -ForegroundColor Red
}