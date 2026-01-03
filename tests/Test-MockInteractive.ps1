# Quick test of mock interactive navigation
Import-Module .\SpotifyModule.psm1 -Force

Write-Host "🧪 Testing Mock Interactive Navigation" -ForegroundColor Cyan
Write-Host "This will test the interactive mode with mock data" -ForegroundColor Gray
Write-Host "Press Escape to exit when the interactive mode starts" -ForegroundColor Yellow
Write-Host ""

# Test the mock interactive navigation
Test-InteractiveNavigation