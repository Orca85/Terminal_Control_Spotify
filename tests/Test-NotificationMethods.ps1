#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test different notification methods to diagnose notification issues

.DESCRIPTION
Tests various notification methods to help identify why notifications might not be visible
#>

Write-Host "🧪 Testing Different Notification Methods" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Direct BurntToast
Write-Host "1. Testing Direct BurntToast (should show toast notification):" -ForegroundColor Yellow
try {
    Import-Module BurntToast -ErrorAction Stop
    New-BurntToastNotification -Text "BurntToast Test", "Detta är en direkt BurntToast notifikation" -Sound 'Default'
    Write-Host "   ✅ BurntToast command executed successfully" -ForegroundColor Green
    Write-Host "   💡 Check your Windows notification area (bottom right)" -ForegroundColor Cyan
} catch {
    Write-Host "   ❌ BurntToast failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Start-Sleep -Seconds 2

# Test 2: Windows Shell Popup
Write-Host "2. Testing Windows Shell Popup (should show popup dialog):" -ForegroundColor Yellow
try {
    $shell = New-Object -ComObject "Wscript.Shell"
    $result = $shell.Popup("Detta är en Windows Shell popup notifikation", 5, "Shell Popup Test", 64)
    Write-Host "   ✅ Shell popup executed successfully (Result: $result)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Shell popup failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Start-Sleep -Seconds 2

# Test 3: Spotify CLI notification function
Write-Host "3. Testing Spotify CLI notification function:" -ForegroundColor Yellow
try {
    Import-Module .\SpotifyModule.psm1 -Force
    Show-TrackNotification -Title "Spotify CLI Test" -Message "Detta är en Spotify CLI notifikation" -IsTest $true
    Write-Host "   ✅ Spotify CLI notification executed" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Spotify CLI notification failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Check Windows notification settings
Write-Host "4. Checking Windows notification settings:" -ForegroundColor Yellow
try {
    # Check if notifications are enabled in Windows
    $notificationSettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -ErrorAction SilentlyContinue
    if ($notificationSettings) {
        Write-Host "   Windows notifications enabled: $($notificationSettings.ToastEnabled)" -ForegroundColor Green
    } else {
        Write-Host "   Could not read Windows notification settings" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Could not check Windows notification settings: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Test 5: Check Focus Assist
Write-Host "5. Checking Focus Assist status:" -ForegroundColor Yellow
try {
    $focusAssist = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\*windows.data.notifications.quiethours*" -ErrorAction SilentlyContinue
    if ($focusAssist) {
        Write-Host "   Focus Assist may be active (could block notifications)" -ForegroundColor Yellow
    } else {
        Write-Host "   Focus Assist settings not found" -ForegroundColor Green
    }
} catch {
    Write-Host "   Could not check Focus Assist settings" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "💡 Troubleshooting Tips:" -ForegroundColor Cyan
Write-Host "• Check Windows Settings > System > Notifications & actions" -ForegroundColor White
Write-Host "• Make sure 'Get notifications from apps and other senders' is ON" -ForegroundColor White
Write-Host "• Check if Focus Assist is blocking notifications" -ForegroundColor White
Write-Host "• Look for notifications in the Action Center (Windows key + A)" -ForegroundColor White
Write-Host "• Some notifications may appear briefly and then disappear" -ForegroundColor White

Write-Host ""
Write-Host "🔧 If notifications still don't work:" -ForegroundColor Yellow
Write-Host "• Try running PowerShell as Administrator" -ForegroundColor White
Write-Host "• Check Windows Event Viewer for notification errors" -ForegroundColor White
Write-Host "• Restart Windows notification service: Get-Service | Where-Object {$_.Name -like '*notification*'}" -ForegroundColor White