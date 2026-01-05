#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test the interactive Space key functionality
#>

Write-Host "🧪 Testing Interactive Space Key Functionality" -ForegroundColor Cyan
Write-Host ""

Write-Host "Instructions for manual testing:" -ForegroundColor Yellow
Write-Host "1. Run: Import-Module .\SpotifyModule.psm1 -Force" -ForegroundColor White
Write-Host "2. Run: search 'your favorite song'" -ForegroundColor White
Write-Host "3. Press Enter to enter interactive mode" -ForegroundColor White
Write-Host "4. Use ↑↓ to navigate to a song" -ForegroundColor White
Write-Host "5. Press Space to add to queue" -ForegroundColor White
Write-Host "6. Press Escape to exit interactive mode" -ForegroundColor White
Write-Host "7. Run: queue" -ForegroundColor White
Write-Host "8. Look for your song at the end of the queue list" -ForegroundColor White

Write-Host ""
Write-Host "Expected behavior:" -ForegroundColor Green
Write-Host "✅ Space key should show: '➕ Adding item X to queue...'" -ForegroundColor White
Write-Host "✅ Then show: '✅ Added to queue'" -ForegroundColor White
Write-Host "✅ Then show: '🎵 Added: [Song Name] by [Artist]'" -ForegroundColor White
Write-Host "✅ The song should appear in the queue when you run 'queue'" -ForegroundColor White

Write-Host ""
Write-Host "If you see 'API Error' instead:" -ForegroundColor Red
Write-Host "❌ Check that you have Spotify Premium" -ForegroundColor White
Write-Host "❌ Check that Spotify is running on an active device" -ForegroundColor White
Write-Host "❌ Check that you're authenticated (run .\spotifyCLI.ps1)" -ForegroundColor White

Write-Host ""
Write-Host "Note: Songs are added to the END of the queue, so if you have a long queue," -ForegroundColor Yellow
Write-Host "you might need to scroll down in the queue display to see your added song." -ForegroundColor Yellow