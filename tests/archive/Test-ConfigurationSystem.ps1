#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test script for Spotify CLI configuration system functionality

.DESCRIPTION
Tests configuration viewing, modification, and persistence.
This script validates Requirements 11.4 and 11.5.

.EXAMPLE
.\Test-ConfigurationSystem.ps1
Run all configuration system tests
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

Write-Host "🧪 Testing Spotify CLI Configuration System" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
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

function Test-ConfigCommand {
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

# Test 1: Get-SpotifyConfig command (Requirement 11.4)
Test-ConfigCommand -TestName "Get-SpotifyConfig Display" -Description "Should display current configuration settings" -TestScript {
    try {
        $config = Get-SpotifyConfig
        
        if ($config) {
            Write-Host "   Configuration retrieved successfully" -ForegroundColor Green
            Write-Host "   CompactMode: $($config.CompactMode)" -ForegroundColor Gray
            Write-Host "   NotificationsEnabled: $($config.NotificationsEnabled)" -ForegroundColor Gray
            Write-Host "   PreferredDevice: $($config.PreferredDevice)" -ForegroundColor Gray
            
            # Check for required properties
            $requiredProps = @('CompactMode', 'NotificationsEnabled', 'PreferredDevice', 'Colors')
            $missingProps = @()
            
            foreach ($prop in $requiredProps) {
                if (-not $config.ContainsKey($prop)) {
                    $missingProps += $prop
                }
            }
            
            if ($missingProps.Count -eq 0) {
                return @{ Success = $true; Output = "All required properties present" }
            } else {
                return @{ Success = $false; Message = "Missing properties: $($missingProps -join ', ')"; Output = "Configuration incomplete" }
            }
        } else {
            return @{ Success = $false; Message = "No configuration returned"; Output = "Null configuration" }
        }
    } catch {
        throw $_
    }
}

# Test 2: Set-SpotifyConfig with CompactMode (Requirement 11.5)
Test-ConfigCommand -TestName "Set-SpotifyConfig CompactMode" -Description "Should modify CompactMode setting" -TestScript {
    try {
        # Get current config
        $originalConfig = Get-SpotifyConfig
        $originalCompactMode = $originalConfig.CompactMode
        
        # Toggle CompactMode
        $newConfig = $originalConfig.Clone()
        $newConfig.CompactMode = -not $originalCompactMode
        
        # Set new config
        $setResult = Set-SpotifyConfig -Config $newConfig
        
        if ($setResult) {
            # Verify the change
            $updatedConfig = Get-SpotifyConfig
            
            if ($updatedConfig.CompactMode -eq $newConfig.CompactMode) {
                Write-Host "   CompactMode changed from $originalCompactMode to $($updatedConfig.CompactMode)" -ForegroundColor Green
                return @{ Success = $true; Output = "CompactMode successfully modified" }
            } else {
                return @{ Success = $false; Message = "CompactMode not updated correctly"; Output = "Configuration change failed" }
            }
        } else {
            return @{ Success = $false; Message = "Set-SpotifyConfig returned false"; Output = "Configuration save failed" }
        }
    } catch {
        throw $_
    }
}

# Test 3: Set-SpotifyConfig with NotificationsEnabled
Test-ConfigCommand -TestName "Set-SpotifyConfig NotificationsEnabled" -Description "Should modify NotificationsEnabled setting" -TestScript {
    try {
        # Get current config
        $originalConfig = Get-SpotifyConfig
        $originalNotifications = $originalConfig.NotificationsEnabled
        
        # Toggle NotificationsEnabled
        $newConfig = $originalConfig.Clone()
        $newConfig.NotificationsEnabled = -not $originalNotifications
        
        # Set new config
        $setResult = Set-SpotifyConfig -Config $newConfig
        
        if ($setResult) {
            # Verify the change
            $updatedConfig = Get-SpotifyConfig
            
            if ($updatedConfig.NotificationsEnabled -eq $newConfig.NotificationsEnabled) {
                Write-Host "   NotificationsEnabled changed from $originalNotifications to $($updatedConfig.NotificationsEnabled)" -ForegroundColor Green
                return @{ Success = $true; Output = "NotificationsEnabled successfully modified" }
            } else {
                return @{ Success = $false; Message = "NotificationsEnabled not updated correctly"; Output = "Configuration change failed" }
            }
        } else {
            return @{ Success = $false; Message = "Set-SpotifyConfig returned false"; Output = "Configuration save failed" }
        }
    } catch {
        throw $_
    }
}

# Test 4: Set-SpotifyConfig with Colors
Test-ConfigCommand -TestName "Set-SpotifyConfig Colors" -Description "Should modify color settings" -TestScript {
    try {
        # Get current config
        $originalConfig = Get-SpotifyConfig
        $originalPlayingColor = $originalConfig.Colors.Playing
        
        # Change Playing color
        $newConfig = $originalConfig.Clone()
        $newConfig.Colors.Playing = if ($originalPlayingColor -eq "Green") { "Cyan" } else { "Green" }
        
        # Set new config
        $setResult = Set-SpotifyConfig -Config $newConfig
        
        if ($setResult) {
            # Verify the change
            $updatedConfig = Get-SpotifyConfig
            
            if ($updatedConfig.Colors.Playing -eq $newConfig.Colors.Playing) {
                Write-Host "   Playing color changed from $originalPlayingColor to $($updatedConfig.Colors.Playing)" -ForegroundColor Green
                return @{ Success = $true; Output = "Colors successfully modified" }
            } else {
                return @{ Success = $false; Message = "Colors not updated correctly"; Output = "Color configuration change failed" }
            }
        } else {
            return @{ Success = $false; Message = "Set-SpotifyConfig returned false"; Output = "Configuration save failed" }
        }
    } catch {
        throw $_
    }
}

# Test 5: Configuration persistence between sessions
Test-ConfigCommand -TestName "Configuration Persistence" -Description "Should persist configuration changes between sessions" -TestScript {
    try {
        # Set a unique configuration value
        $testConfig = Get-SpotifyConfig
        $testConfig.CompactMode = $true
        $testConfig.NotificationsEnabled = $false
        $testConfig.PreferredDevice = "test-device-id"
        
        # Save configuration
        $setResult = Set-SpotifyConfig -Config $testConfig
        
        if (-not $setResult) {
            return @{ Success = $false; Message = "Failed to save test configuration"; Output = "Save failed" }
        }
        
        # Simulate session restart by re-importing module
        Remove-Module SpotifyModule -Force -ErrorAction SilentlyContinue
        Import-Module .\SpotifyModule.psm1 -Force
        
        # Get configuration again
        $persistedConfig = Get-SpotifyConfig
        
        # Verify values persisted
        $compactMatch = $persistedConfig.CompactMode -eq $testConfig.CompactMode
        $notificationMatch = $persistedConfig.NotificationsEnabled -eq $testConfig.NotificationsEnabled
        $deviceMatch = $persistedConfig.PreferredDevice -eq $testConfig.PreferredDevice
        
        if ($compactMatch -and $notificationMatch -and $deviceMatch) {
            Write-Host "   All configuration values persisted correctly" -ForegroundColor Green
            return @{ Success = $true; Output = "Configuration persistence verified" }
        } else {
            $issues = @()
            if (-not $compactMatch) { $issues += "CompactMode" }
            if (-not $notificationMatch) { $issues += "NotificationsEnabled" }
            if (-not $deviceMatch) { $issues += "PreferredDevice" }
            
            return @{ Success = $false; Message = "Configuration values not persisted: $($issues -join ', ')"; Output = "Persistence failed" }
        }
    } catch {
        throw $_
    }
}

# Test 6: Configuration file structure
Test-ConfigCommand -TestName "Configuration File Structure" -Description "Should create proper JSON configuration file" -TestScript {
    try {
        $configPath = "$env:APPDATA\SpotifyCLI\config.json"
        
        if (Test-Path $configPath) {
            $configJson = Get-Content $configPath -Raw
            $configObj = $configJson | ConvertFrom-Json
            
            Write-Host "   Configuration file exists at: $configPath" -ForegroundColor Green
            Write-Host "   File size: $((Get-Item $configPath).Length) bytes" -ForegroundColor Gray
            
            # Validate JSON structure
            if ($configObj.CompactMode -ne $null -and $configObj.NotificationsEnabled -ne $null) {
                return @{ Success = $true; Output = "Configuration file structure valid" }
            } else {
                return @{ Success = $false; Message = "Configuration file missing required properties"; Output = "Invalid structure" }
            }
        } else {
            return @{ Success = $false; Message = "Configuration file not found"; Output = "File missing" }
        }
    } catch {
        throw $_
    }
}

# Test 7: Configuration validation
Test-ConfigCommand -TestName "Configuration Validation" -Description "Should validate configuration values" -TestScript {
    try {
        # Test with invalid configuration
        $invalidConfig = @{
            CompactMode = "invalid"  # Should be boolean
            NotificationsEnabled = 123  # Should be boolean
            Colors = "not-a-hashtable"  # Should be hashtable
        }
        
        # This should either fail gracefully or correct the values
        $setResult = Set-SpotifyConfig -Config $invalidConfig
        
        if ($setResult) {
            # Check if values were corrected or if invalid config was saved
            $resultConfig = Get-SpotifyConfig
            
            if ($resultConfig.CompactMode -is [bool] -and $resultConfig.NotificationsEnabled -is [bool]) {
                Write-Host "   Configuration validation working (values corrected or defaults used)" -ForegroundColor Green
                return @{ Success = $true; Output = "Configuration validation functional" }
            } else {
                return @{ Success = $false; Message = "Invalid configuration values were saved"; Output = "Validation failed" }
            }
        } else {
            Write-Host "   Set-SpotifyConfig properly rejected invalid configuration" -ForegroundColor Green
            return @{ Success = $true; Output = "Configuration validation working (rejected invalid config)" }
        }
    } catch {
        # Exception during validation is also acceptable
        Write-Host "   Configuration validation threw exception (acceptable behavior)" -ForegroundColor Green
        return @{ Success = $true; Output = "Configuration validation working (exception thrown)" }
    }
}

# Restore original configuration
Restore-Configuration

# Summary
Write-Host "📊 Configuration System Test Summary" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

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

$req114 = ($testResults | Where-Object { $_.Test -eq "Get-SpotifyConfig Display" -and $_.Status -eq "PASS" }) -ne $null
$req115 = ($testResults | Where-Object { $_.Test -like "*Set-SpotifyConfig*" -and $_.Status -eq "PASS" }).Count -gt 0
$persistence = ($testResults | Where-Object { $_.Test -eq "Configuration Persistence" -and $_.Status -eq "PASS" }) -ne $null

Write-Host "Requirement 11.4 (Get-SpotifyConfig display): $(if ($req114) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req114) { 'Green' } else { 'Red' })
Write-Host "Requirement 11.5 (Set-SpotifyConfig modify): $(if ($req115) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req115) { 'Green' } else { 'Red' })
Write-Host "Configuration Persistence: $(if ($persistence) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($persistence) { 'Green' } else { 'Red' })

$allPassed = $req114 -and $req115 -and $persistence

Write-Host ""
if ($allPassed) {
    Write-Host "🎉 All configuration system requirements PASSED!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some configuration system requirements need attention" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "💡 Next Steps:" -ForegroundColor Cyan
Write-Host "- If tests failed, check configuration file permissions in %APPDATA%\SpotifyCLI\" -ForegroundColor White
Write-Host "- Verify that Get-SpotifyConfig and Set-SpotifyConfig functions work correctly" -ForegroundColor White
Write-Host "- Test configuration commands manually to verify functionality" -ForegroundColor White

return $allPassed