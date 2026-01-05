#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test script mode advanced functionality for Spotify CLI

.DESCRIPTION
Tests the advanced interactive CLI mode functionality including:
- Search functionality (/search "query")
- Device management (/devices)
- Configuration management (/config)

This addresses requirements 13.4, 13.5, 13.6 from the testing specification.
#>

[CmdletBinding()]
param(
    [switch]$DetailedOutput,
    [switch]$SkipInteractive
)

# Test configuration
$TestResults = @()
$ErrorCount = 0

function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    $result = @{
        TestName = $TestName
        Passed = $Passed
        Details = $Details
        Timestamp = Get-Date
    }
    
    $script:TestResults += $result
    
    $status = if ($Passed) { "✅ PASS" } else { "❌ FAIL"; $script:ErrorCount++ }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "$status - $TestName" -ForegroundColor $color
    if ($Details) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

function Test-AdvancedCommands {
    Write-TestHeader "Task 13.2 - Advanced Script Mode Commands"
    
    $scriptContent = Get-Content ".\spotifyCLI.ps1" -Raw
    
    # Test search command
    $hasSearchCommand = $scriptContent -match '"/search".*Invoke-SearchCommand'
    Write-TestResult -TestName "Script processes /search command" -Passed $hasSearchCommand -Details "Search functionality routing"
    
    # Test devices command  
    $hasDevicesCommand = $scriptContent -match '"/devices".*Invoke-DevicesCommand'
    Write-TestResult -TestName "Script processes /devices command" -Passed $hasDevicesCommand -Details "Device management routing"
    
    # Test config command
    $hasConfigCommand = $scriptContent -match '"/config".*Invoke-ConfigCommand'
    Write-TestResult -TestName "Script processes /config command" -Passed $hasConfigCommand -Details "Configuration management routing"
    
    return ($hasSearchCommand -and $hasDevicesCommand -and $hasConfigCommand)
}

function Test-InteractiveCommands {
    Write-TestHeader "Task 13.2 - Interactive Command Testing"
    
    if ($SkipInteractive) {
        Write-Host "⏭️ Skipping interactive tests" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "`n📋 MANUAL TEST REQUIRED:" -ForegroundColor Yellow
    Write-Host "Please test these commands in the CLI:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Start CLI: .\spotifyCLI.ps1" -ForegroundColor Cyan
    Write-Host "2. Test: /search bohemian rhapsody" -ForegroundColor Cyan
    Write-Host "3. Test: /devices" -ForegroundColor Cyan  
    Write-Host "4. Test: /config" -ForegroundColor Cyan
    Write-Host "5. Verify all commands work properly" -ForegroundColor Cyan
    Write-Host ""
    
    $response = Read-Host "Did all advanced commands work? (y/n)"
    $passed = $response -match "^y"
    
    Write-TestResult -TestName "Advanced commands functionality" -Passed $passed -Details "Manual verification"
    
    return $passed
}

# Main execution
function Main {
    Write-Host "🧪 Spotify CLI Script Mode Testing - Task 13.2" -ForegroundColor Magenta
    Write-Host "Testing advanced script mode functionality" -ForegroundColor White
    
    $allPassed = $true
    $allPassed = (Test-AdvancedCommands) -and $allPassed
    
    if (-not $SkipInteractive) {
        $allPassed = (Test-InteractiveCommands) -and $allPassed
    }
    
    # Summary
    Write-TestHeader "Test Summary"
    Write-Host "Total Tests: $($TestResults.Count)" -ForegroundColor White
    Write-Host "Passed: $(($TestResults | Where-Object Passed).Count)" -ForegroundColor Green
    Write-Host "Failed: $ErrorCount" -ForegroundColor Red
    
    if ($ErrorCount -eq 0) {
        Write-Host "`nAll tests passed!" -ForegroundColor Green
    } else {
        Write-Host "`nSome tests failed." -ForegroundColor Yellow
    }
    
    return $allPassed
}

$success = Main
exit $(if ($success) { 0 } else { 1 })