# Simple test for Start-SpotifyApp
. .\SpotifyModule.psm1

Write-Host "Testing Start-SpotifyApp function..." -ForegroundColor Cyan
Get-Command Start-SpotifyApp -ErrorAction SilentlyContinue | Format-Table Name, CommandType, Source