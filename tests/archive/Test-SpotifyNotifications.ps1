#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test Spotify CLI notifications with user feedback

.DESCRIPTION
Tests Spotify CLI notifications and provides clear feedback about what should happen
#>

Write-Host "🔔 Testing Spotify CLI Notifications" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Import module
Import-Module .\SpotifyModule.psm1 -Force

# Check current notification status
Write-Host "📋 Current notification status:" -ForegroundColor Yellow
notifications

Write-Host ""

# Enable notifications if not already enabled
Write-Host "🔧 Enabling notifications..." -ForegroundColor Yellow
notifications on

Write-Host ""

# Test notification with sound
Write-Host "🧪 Testing notification (with sound)..." -ForegroundColor Yellow
Write-Host "💡 You should see a Windows toast notification in the bottom-right corner" -ForegroundColor Cyan
Write-Host "💡 You should also hear a notification sound" -ForegroundColor Cyan
Write-Host ""

notifications test

Write-Host ""
Write-Host "❓ Did you see/hear the notification? (y/n): " -NoNewline -ForegroundColor Green
$response = Read-Host

if ($response -eq 'y' -or $response -eq 'Y') {
    Write-Host "✅ Great! Notifications are working correctly." -ForegroundColor Green
} else {
    Write-Host "⚠️ Notification might not be visible. Let's try alternative methods..." -ForegroundColor Yellow
    Write-Host ""
    
    # Try shell popup
    Write-Host "🔧 Testing Windows popup dialog..." -ForegroundColor Yellow
    Write-Host "💡 You should see a popup dialog box" -ForegroundColor Cyan
    
    try {
        $shell = New-Object -ComObject "Wscript.Shell"
        $result = $shell.Popup("Detta är en test-notifikation från Spotify CLI", 5, "Spotify CLI Test", 64)
        Write-Host "✅ Popup dialog displayed" -ForegroundColor Green
    } catch {
        Write-Host "❌ Popup dialog failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "🔧 Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Check Windows Settings > System > Notifications & actions" -ForegroundColor White
    Write-Host "2. Make sure 'Get notifications from apps and other senders' is ON" -ForegroundColor White
    Write-Host "3. Check if Focus Assist is blocking notifications (Windows key + U)" -ForegroundColor White
    Write-Host "4. Look in Action Center (Windows key + A) for missed notifications" -ForegroundColor White
    Write-Host "5. Try running PowerShell as Administrator" -ForegroundColor White
}

Write-Host ""
Write-Host "📊 Notification system summary:" -ForegroundColor Cyan
$support = Test-NotificationSupport
Write-Host "• System support: $($support.Reason)" -ForegroundColor White
Write-Host "• BurntToast module: $(if (Get-Module BurntToast -ListAvailable) { 'Available' } else { 'Not installed' })" -ForegroundColor White
Write-Host "• Windows version: $([System.Environment]::OSVersion.Version.Major).$([System.Environment]::OSVersion.Version.Minor)" -ForegroundColor White

Write-Host ""
Write-Host "💡 Notifications will appear when tracks change during Spotify playback" -ForegroundColor Cyan