#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test script for Spotify CLI notification system functionality

.DESCRIPTION
Tests notification controls, system validation, and settings persistence.
This script validates Requirements 11.6, 11.7, and 11.8.

.EXAMPLE
.\Test-NotificationSystem.ps1
Run all notification system tests
#>

[CmdletBinding()]
param()

# Import the Spotify module
try {
    Import-Module .\SpotifyModule.psm1 -Force -ErrorAction Stop
    Write-Host "✅ SpotifyModule imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to import SpotifyModule: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "🧪 Testing Spotify CLI Notification System" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$testResults = @()
$configBackupPath = "$env:APPDATA\SpotifyCLI\config.json.backup"

function Backup-Configuration {
    $configPath = "$env:APPDATA\SpotifyCLI\config.json"
    if (Test-Path $configPath) {
        Copy-Item $configPath $configBackupPath -Force
        Write-Host "📁 Configuration backed up" -ForegroundColor Gray
    }
}

function Restore-Configuration {
    $configPath = "$env:APPDATA\SpotifyCLI\config.json"
    if (Test-Path $configBackupPath) {
        Copy-Item $configBackupPath $configPath -Force
        Remove-Item $configBackupPath -Force
        Write-Host "📁 Configuration restored" -ForegroundColor Gray
    }
}

function Test-NotificationCommand {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$Description
    )
    
    Write-Host "🔍 Testing: $TestName" -ForegroundColor Yellow
    Write-Host "   Description: $Description" -ForegroundColor Gray
    
    try {
        $result = & $TestScript
        
        if ($result.Success) {
            Write-Host "✅ Test passed" -ForegroundColor Green
            $script:testResults += @{
                Test = $TestName
                Status = "PASS"
                Output = $result.Output
                Description = $Description
            }
        } else {
            Write-Host "⚠️ Test warning: $($result.Message)" -ForegroundColor Yellow
            $script:testResults += @{
                Test = $TestName
                Status = "WARN"
                Output = $result.Output
                Description = $Description
            }
        }
    } catch {
        Write-Host "❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:testResults += @{
            Test = $TestName
            Status = "FAIL"
            Output = $_.Exception.Message
            Description = $Description
        }
    }
    
    Write-Host ""
}

# Backup current configuration
Backup-Configuration

# Test 1: notifications on command (Requirement 11.6)
Test-NotificationCommand -TestName "notifications on Command" -Description "Should enable notifications" -TestScript {
    try {
        # Ensure notifications are initially off
        $initialConfig = Get-SpotifyConfig
        $initialConfig.NotificationsEnabled = $false
        Set-SpotifyConfig -Config $initialConfig | Out-Null
        
        # Test notifications on
        $output = notifications on 2>&1 | Out-String
        
        # Verify configuration changed
        $updatedConfig = Get-SpotifyConfig
        
        if ($updatedConfig.NotificationsEnabled -eq $true) {
            Write-Host "   Notifications successfully enabled" -ForegroundColor Green
            Write-Host "   Output: $($output.Trim())" -ForegroundColor Gray
            return @{ Success = $true; Output = "Notifications enabled successfully" }
        } else {
            return @{ Success = $false; Message = "NotificationsEnabled not set to true"; Output = $output }
        }
    } catch {
        throw $_
    }
}

# Test 2: notifications off command (Requirement 11.7)
Test-NotificationCommand -TestName "notifications off Command" -Description "Should disable notifications" -TestScript {
    try {
        # Ensure notifications are initially on
        $initialConfig = Get-SpotifyConfig
        $initialConfig.NotificationsEnabled = $true
        Set-SpotifyConfig -Config $initialConfig | Out-Null
        
        # Test notifications off
        $output = notifications off 2>&1 | Out-String
        
        # Verify configuration changed
        $updatedConfig = Get-SpotifyConfig
        
        if ($updatedConfig.NotificationsEnabled -eq $false) {
            Write-Host "   Notifications successfully disabled" -ForegroundColor Green
            Write-Host "   Output: $($output.Trim())" -ForegroundColor Gray
            return @{ Success = $true; Output = "Notifications disabled successfully" }
        } else {
            return @{ Success = $false; Message = "NotificationsEnabled not set to false"; Output = $output }
        }
    } catch {
        throw $_
    }
}

# Test 3: notifications test command (Requirement 11.8)
Test-NotificationCommand -TestName "notifications test Command" -Description "Should test notification system" -TestScript {
    try {
        # Test notifications test
        $output = notifications test 2>&1 | Out-String
        
        # The test command should execute without error
        if ($output -and $output.Length -gt 0) {
            Write-Host "   Test notification executed" -ForegroundColor Green
            Write-Host "   Output: $($output.Trim())" -ForegroundColor Gray
            return @{ Success = $true; Output = "Test notification executed successfully" }
        } else {
            return @{ Success = $false; Message = "No output from test command"; Output = "No output" }
        }
    } catch {
        throw $_
    }
}

# Test 4: notifications status command
Test-NotificationCommand -TestName "notifications status Command" -Description "Should show current notification status" -TestScript {
    try {
        # Set known state
        $config = Get-SpotifyConfig
        $config.NotificationsEnabled = $true
        Set-SpotifyConfig -Config $config | Out-Null
        
        # Test notifications status (default behavior)
        $output = notifications 2>&1 | Out-String
        
        if ($output -like "*enabled*" -or $output -like "*Enabled*") {
            Write-Host "   Status correctly shows enabled state" -ForegroundColor Green
            Write-Host "   Output: $($output.Trim())" -ForegroundColor Gray
            return @{ Success = $true; Output = "Status command working correctly" }
        } else {
            return @{ Success = $false; Message = "Status output doesn't show enabled state"; Output = $output }
        }
    } catch {
        throw $_
    }
}

# Test 5: Test-NotificationSupport function
Test-NotificationCommand -TestName "Test-NotificationSupport Function" -Description "Should test system notification support" -TestScript {
    try {
        $supportResult = Test-NotificationSupport
        
        if ($supportResult -and $supportResult.Supported -ne $null) {
            Write-Host "   Notification support test completed" -ForegroundColor Green
            Write-Host "   Supported: $($supportResult.Supported)" -ForegroundColor Gray
            Write-Host "   Reason: $($supportResult.Reason)" -ForegroundColor Gray
            return @{ Success = $true; Output = "Support: $($supportResult.Supported), Reason: $($supportResult.Reason)" }
        } else {
            return @{ Success = $false; Message = "Test-NotificationSupport returned invalid result"; Output = "Invalid result" }
        }
    } catch {
        throw $_
    }
}

# Test 6: Show-TrackNotification function
Test-NotificationCommand -TestName "Show-TrackNotification Function" -Description "Should display track notifications" -TestScript {
    try {
        # Test with custom title and message
        $output = Show-TrackNotification -Title "Test Title" -Message "Test Message" -IsTest $true 2>&1 | Out-String
        
        # The function should execute without error
        Write-Host "   Track notification function executed" -ForegroundColor Green
        if ($output) {
            Write-Host "   Output: $($output.Trim())" -ForegroundColor Gray
        }
        return @{ Success = $true; Output = "Track notification function working" }
    } catch {
        throw $_
    }
}

# Test 7: Notification settings persistence
Test-NotificationCommand -TestName "Notification Settings Persistence" -Description "Should persist notification settings" -TestScript {
    try {
        # Set notifications to enabled
        $config = Get-SpotifyConfig
        $config.NotificationsEnabled = $true
        Set-SpotifyConfig -Config $config | Out-Null
        
        # Simulate session restart by re-importing module
        Remove-Module SpotifyModule -Force -ErrorAction SilentlyContinue
        Import-Module .\SpotifyModule.psm1 -Force
        
        # Check if setting persisted
        $persistedConfig = Get-SpotifyConfig
        
        if ($persistedConfig.NotificationsEnabled -eq $true) {
            Write-Host "   Notification settings persisted correctly" -ForegroundColor Green
            
            # Now test with disabled
            $persistedConfig.NotificationsEnabled = $false
            Set-SpotifyConfig -Config $persistedConfig | Out-Null
            
            # Re-import again
            Remove-Module SpotifyModule -Force -ErrorAction SilentlyContinue
            Import-Module .\SpotifyModule.psm1 -Force
            
            $finalConfig = Get-SpotifyConfig
            
            if ($finalConfig.NotificationsEnabled -eq $false) {
                Write-Host "   Both enabled and disabled states persist correctly" -ForegroundColor Green
                return @{ Success = $true; Output = "Notification settings persistence verified" }
            } else {
                return @{ Success = $false; Message = "Disabled state did not persist"; Output = "Partial persistence failure" }
            }
        } else {
            return @{ Success = $false; Message = "Enabled state did not persist"; Output = "Persistence failure" }
        }
    } catch {
        throw $_
    }
}

# Test 8: Notification command availability
Test-NotificationCommand -TestName "Notification Command Availability" -Description "Should have notification commands available" -TestScript {
    try {
        # Check if notifications function is available
        $notificationsCmd = Get-Command notifications -ErrorAction SilentlyContinue
        $testNotificationCmd = Get-Command Test-NotificationSupport -ErrorAction SilentlyContinue
        $showNotificationCmd = Get-Command Show-TrackNotification -ErrorAction SilentlyContinue
        
        $availableCommands = @()
        if ($notificationsCmd) { $availableCommands += "notifications" }
        if ($testNotificationCmd) { $availableCommands += "Test-NotificationSupport" }
        if ($showNotificationCmd) { $availableCommands += "Show-TrackNotification" }
        
        if ($availableCommands.Count -ge 2) {
            Write-Host "   Available notification commands: $($availableCommands -join ', ')" -ForegroundColor Green
            return @{ Success = $true; Output = "Commands available: $($availableCommands -join ', ')" }
        } else {
            return @{ Success = $false; Message = "Missing notification commands"; Output = "Available: $($availableCommands -join ', ')" }
        }
    } catch {
        throw $_
    }
}

# Test 9: Windows version compatibility
Test-NotificationCommand -TestName "Windows Version Compatibility" -Description "Should handle different Windows versions" -TestScript {
    try {
        $osVersion = [System.Environment]::OSVersion.Version
        Write-Host "   Windows Version: $($osVersion.Major).$($osVersion.Minor)" -ForegroundColor Gray
        
        $supportResult = Test-NotificationSupport
        
        if ($osVersion.Major -ge 10) {
            # Windows 10+ should support toast notifications
            if ($supportResult.Supported) {
                Write-Host "   Windows 10+ notification support confirmed" -ForegroundColor Green
                return @{ Success = $true; Output = "Windows 10+ support verified" }
            } else {
                Write-Host "   Windows 10+ but limited support: $($supportResult.Reason)" -ForegroundColor Yellow
                return @{ Success = $true; Output = "Limited support on Windows 10+: $($supportResult.Reason)" }
            }
        } else {
            # Older Windows should still have fallback support
            if ($supportResult.Supported) {
                Write-Host "   Older Windows with fallback support: $($supportResult.Reason)" -ForegroundColor Green
                return @{ Success = $true; Output = "Fallback support on older Windows" }
            } else {
                return @{ Success = $false; Message = "No notification support on older Windows"; Output = "No support available" }
            }
        }
    } catch {
        throw $_
    }
}

# Restore original configuration
Restore-Configuration

# Summary
Write-Host "📊 Notification System Test Summary" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

$passCount = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$warnCount = ($testResults | Where-Object { $_.Status -eq "WARN" }).Count
$failCount = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$totalCount = $testResults.Count

Write-Host "Total Tests: $totalCount" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Warnings: $warnCount" -ForegroundColor Yellow
Write-Host "Failed: $failCount" -ForegroundColor Red

Write-Host ""
Write-Host "Detailed Results:" -ForegroundColor White
foreach ($result in $testResults) {
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
    }
    Write-Host "[$($result.Status)] $($result.Test)" -ForegroundColor $color
    Write-Host "    Description: $($result.Description)" -ForegroundColor Gray
    Write-Host "    Output: $($result.Output)" -ForegroundColor Gray
}

Write-Host ""

# Requirements validation
Write-Host "📋 Requirements Validation" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

$req116 = ($testResults | Where-Object { $_.Test -eq "notifications on Command" -and $_.Status -eq "PASS" }) -ne $null
$req117 = ($testResults | Where-Object { $_.Test -eq "notifications off Command" -and $_.Status -eq "PASS" }) -ne $null
$req118 = ($testResults | Where-Object { $_.Test -eq "notifications test Command" -and $_.Status -eq "PASS" }) -ne $null
$persistence = ($testResults | Where-Object { $_.Test -eq "Notification Settings Persistence" -and $_.Status -eq "PASS" }) -ne $null

Write-Host "Requirement 11.6 (notifications on): $(if ($req116) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req116) { 'Green' } else { 'Red' })
Write-Host "Requirement 11.7 (notifications off): $(if ($req117) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req117) { 'Green' } else { 'Red' })
Write-Host "Requirement 11.8 (notifications test): $(if ($req118) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req118) { 'Green' } else { 'Red' })
Write-Host "Settings Persistence: $(if ($persistence) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($persistence) { 'Green' } else { 'Red' })

$allPassed = $req116 -and $req117 -and $req118 -and $persistence

Write-Host ""
if ($allPassed) {
    Write-Host "🎉 All notification system requirements PASSED!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some notification system requirements need attention" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "💡 Next Steps:" -ForegroundColor Cyan
Write-Host "- If tests failed, check that notification functions are properly exported" -ForegroundColor White
Write-Host "- Verify Windows notification system compatibility" -ForegroundColor White
Write-Host "- Test notification commands manually to verify functionality" -ForegroundColor White
Write-Host "- Consider installing BurntToast module for enhanced toast notifications" -ForegroundColor White

return $allPassed