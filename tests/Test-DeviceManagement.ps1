#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test script for Spotify CLI device management functionality

.DESCRIPTION
Tests device listing, smart numbering, device information display, and device transfer functionality.
This script validates Requirements 6.1-6.7 from the Spotify CLI testing specification.

.PARAMETER TestType
Type of test to run: All, Listing, Transfer, Errors
#>

param(
    [ValidateSet("All", "Listing", "Transfer", "Errors")]
    [string]$TestType = "All"
)

# Import the Spotify module if available
if (Get-Module -ListAvailable -Name SpotifyModule -ErrorAction SilentlyContinue) {
    Import-Module SpotifyModule -Force
}

# Test configuration
$script:TestResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Details = @()
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = "",
        [string]$Requirement = ""
    )
    
    if ($Passed) {
        Write-Host "✅ PASS: $TestName" -ForegroundColor Green
        $script:TestResults.Passed++
    } else {
        Write-Host "❌ FAIL: $TestName" -ForegroundColor Red
        $script:TestResults.Failed++
    }
    
    if ($Details) {
        Write-Host "   $Details" -ForegroundColor Gray
    }
    
    if ($Requirement) {
        Write-Host "   Requirement: $Requirement" -ForegroundColor DarkGray
    }
    
    $script:TestResults.Details += @{
        Test = $TestName
        Passed = $Passed
        Details = $Details
        Requirement = $Requirement
        Timestamp = Get-Date
    }
    
    Write-Host ""
}

function Test-DeviceListingCommand {
    <#
    .SYNOPSIS
    Test the devices command functionality
    Requirements: 6.1, 6.2
    #>
    
    Write-Host "🔍 Testing Device Listing Commands..." -ForegroundColor Yellow
    Write-Host "Requirements 6.1-6.2: Device listing with smart numbers and information display" -ForegroundColor Gray
    Write-Host ""
    
    # Test 1: Check if devices command exists
    $devicesCommandExists = $false
    try {
        $devicesCommand = Get-Command devices -ErrorAction Stop
        $devicesCommandExists = $true
        Write-TestResult -TestName "devices command exists" -Passed $true -Details "Command found: $($devicesCommand.Source)" -Requirement "6.1"
    } catch {
        Write-TestResult -TestName "devices command exists" -Passed $false -Details "Command not found or not accessible" -Requirement "6.1"
    }
    
    if (-not $devicesCommandExists) {
        Write-Host "⚠️ Skipping device listing tests - devices command not available" -ForegroundColor Yellow
        return
    }
    
    # Test 2: Execute devices command and capture output
    Write-Host "📱 Testing devices command execution..." -ForegroundColor Cyan
    try {
        # Capture output using Start-Process to get all output streams
        $tempFile = [System.IO.Path]::GetTempFileName()
        $process = Start-Process -FilePath "pwsh" -ArgumentList "-Command", "devices" -RedirectStandardOutput $tempFile -Wait -PassThru -NoNewWindow
        $devicesOutput = Get-Content $tempFile -Raw
        Remove-Item $tempFile -ErrorAction SilentlyContinue
        
        # If that didn't work, try direct capture
        if ([string]::IsNullOrWhiteSpace($devicesOutput)) {
            $devicesOutput = & { devices } 2>&1 | Out-String
        }
        
        # Check for expected output patterns
        $hasDeviceHeader = $devicesOutput -match "Available Devices|📱.*Devices"
        $hasSmartNumbers = $devicesOutput -match "\d+\.\s"
        $hasDeviceInfo = $devicesOutput -match "(💻|📱|🔊|📺|🎵)"
        $hasDeviceNames = $devicesOutput -match "\w+.*\("
        $hasStatusInfo = $devicesOutput -match "(Active|Inactive)"
        $hasUsageTip = $devicesOutput -match "transfer.*\d+"
        
        Write-TestResult -TestName "devices command shows header" -Passed $hasDeviceHeader -Details "Output contains device listing header" -Requirement "6.1"
        Write-TestResult -TestName "devices command shows smart numbers" -Passed $hasSmartNumbers -Details "Output contains numbered device list (1., 2., etc.)" -Requirement "6.2"
        Write-TestResult -TestName "devices command shows device icons" -Passed $hasDeviceInfo -Details "Output contains device type icons" -Requirement "6.2"
        Write-TestResult -TestName "devices command shows device names" -Passed $hasDeviceNames -Details "Output contains device names and types" -Requirement "6.2"
        Write-TestResult -TestName "devices command shows status info" -Passed $hasStatusInfo -Details "Output shows active/inactive status" -Requirement "6.2"
        Write-TestResult -TestName "devices command shows usage tip" -Passed $hasUsageTip -Details "Output includes transfer command usage tip" -Requirement "6.2"
        
        # Display the actual output for manual verification
        Write-Host "📋 Actual devices command output:" -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor Cyan
        Write-Host $devicesOutput -ForegroundColor White
        Write-Host "================================" -ForegroundColor Cyan
        Write-Host ""
        
    } catch {
        Write-TestResult -TestName "devices command execution" -Passed $false -Details "Error executing devices command: $($_.Exception.Message)" -Requirement "6.1"
    }
    
    # Test 3: Check for no devices scenario
    Write-Host "🔍 Testing no devices scenario..." -ForegroundColor Cyan
    Write-Host "💡 This test requires manual verification - check if appropriate message is shown when no devices are available" -ForegroundColor Yellow
    
    # Test 4: Test device information completeness
    Write-Host "📊 Testing device information completeness..." -ForegroundColor Cyan
    if ($devicesOutput) {
        $hasVolumeInfo = $devicesOutput -match "Volume.*\d+%"
        $hasTypeInfo = $devicesOutput -match "\((computer|smartphone|speaker|tv|tablet|game_console)\)"
        
        Write-TestResult -TestName "devices shows volume information" -Passed $hasVolumeInfo -Details "Output includes volume percentage when available" -Requirement "6.2"
        Write-TestResult -TestName "devices shows device type" -Passed $hasTypeInfo -Details "Output includes device type information" -Requirement "6.2"
    }
}

function Test-DeviceTransferCommand {
    <#
    .SYNOPSIS
    Test device transfer functionality
    Requirements: 6.3, 6.4, 6.5
    #>
    
    Write-Host "🔄 Testing Device Transfer Commands..." -ForegroundColor Yellow
    Write-Host "Requirements 6.3-6.5: Device transfer by number and ID" -ForegroundColor Gray
    Write-Host ""
    
    # Test 1: Check if transfer command exists
    $transferCommandExists = $false
    try {
        $transferCommand = Get-Command transfer -ErrorAction Stop
        $transferCommandExists = $true
        Write-TestResult -TestName "transfer command exists" -Passed $true -Details "Command found: $($transferCommand.Source)" -Requirement "6.3"
    } catch {
        Write-TestResult -TestName "transfer command exists" -Passed $false -Details "Command not found or not accessible" -Requirement "6.3"
    }
    
    # Test 2: Check if tr alias exists
    $trAliasExists = $false
    try {
        $trCommand = Get-Command tr -ErrorAction Stop
        $trAliasExists = $true
        Write-TestResult -TestName "tr alias exists" -Passed $true -Details "Alias found: $($trCommand.Source)" -Requirement "6.5"
    } catch {
        Write-TestResult -TestName "tr alias exists" -Passed $false -Details "Alias not found or not accessible" -Requirement "6.5"
    }
    
    if (-not $transferCommandExists) {
        Write-Host "⚠️ Skipping transfer tests - transfer command not available" -ForegroundColor Yellow
        return
    }
    
    # Test 3: Test transfer command with no parameters
    Write-Host "📝 Testing transfer command usage..." -ForegroundColor Cyan
    try {
        $transferNoArgsOutput = transfer 2>&1 | Out-String
        $hasUsageMessage = $transferNoArgsOutput -match "Usage.*transfer"
        $hasDevicesReference = $transferNoArgsOutput -match "devices.*command"
        
        Write-TestResult -TestName "transfer shows usage when no parameters" -Passed $hasUsageMessage -Details "Shows proper usage message" -Requirement "6.3"
        Write-TestResult -TestName "transfer references devices command" -Passed $hasDevicesReference -Details "Suggests using devices command" -Requirement "6.3"
        
    } catch {
        Write-TestResult -TestName "transfer command usage test" -Passed $false -Details "Error testing transfer usage: $($_.Exception.Message)" -Requirement "6.3"
    }
    
    # Test 4: Test transfer with invalid device number
    Write-Host "🔢 Testing transfer with invalid device number..." -ForegroundColor Cyan
    try {
        $transferInvalidOutput = transfer 999 2>&1 | Out-String
        $hasErrorMessage = $transferInvalidOutput -match "(Invalid|not found|❌)"
        $suggestsDevicesCommand = $transferInvalidOutput -match "devices"
        
        Write-TestResult -TestName "transfer handles invalid device number" -Passed $hasErrorMessage -Details "Shows appropriate error for invalid device number" -Requirement "6.3"
        Write-TestResult -TestName "transfer suggests devices command on error" -Passed $suggestsDevicesCommand -Details "Suggests using devices command when invalid number provided" -Requirement "6.3"
        
    } catch {
        Write-TestResult -TestName "transfer invalid number test" -Passed $false -Details "Error testing invalid device number: $($_.Exception.Message)" -Requirement "6.3"
    }
    
    # Test 5: Test transfer with device ID format
    Write-Host "🆔 Testing transfer with device ID format..." -ForegroundColor Cyan
    Write-Host "💡 This test requires manual verification with actual device IDs" -ForegroundColor Yellow
    
    # Test 6: Test tr alias functionality
    if ($trAliasExists) {
        Write-Host "🔗 Testing tr alias functionality..." -ForegroundColor Cyan
        try {
            $trOutput = tr 2>&1 | Out-String
            $hasUsageMessage = $trOutput -match "Usage.*transfer"
            
            Write-TestResult -TestName "tr alias works like transfer command" -Passed $hasUsageMessage -Details "tr alias shows same usage as transfer" -Requirement "6.5"
            
        } catch {
            Write-TestResult -TestName "tr alias functionality" -Passed $false -Details "Error testing tr alias: $($_.Exception.Message)" -Requirement "6.5"
        }
    }
}

function Test-DeviceErrorScenarios {
    <#
    .SYNOPSIS
    Test device error scenarios and guidance
    Requirements: 6.6, 6.7
    #>
    
    Write-Host "⚠️ Testing Device Error Scenarios..." -ForegroundColor Yellow
    Write-Host "Requirements 6.6-6.7: Error handling and user guidance" -ForegroundColor Gray
    Write-Host ""
    
    # Test 1: Test devices command when no devices available
    Write-Host "📱 Testing no devices available scenario..." -ForegroundColor Cyan
    Write-Host "💡 Manual test: Ensure Spotify is closed on all devices, then run 'devices'" -ForegroundColor Yellow
    Write-Host "Expected: Should show helpful message about opening Spotify on a device" -ForegroundColor Gray
    
    # Test 2: Test transfer to non-existent device
    Write-Host "🔄 Testing transfer to non-existent device..." -ForegroundColor Cyan
    if (Get-Command transfer -ErrorAction SilentlyContinue) {
        try {
            $transferNonExistentOutput = transfer "non-existent-device-id" 2>&1 | Out-String
            $hasErrorMessage = $transferNonExistentOutput -match "(not found|Invalid|❌|Could not)"
            $hasHelpfulGuidance = $transferNonExistentOutput -match "(devices|available|online)"
            
            Write-TestResult -TestName "transfer shows error for non-existent device" -Passed $hasErrorMessage -Details "Shows appropriate error message" -Requirement "6.7"
            Write-TestResult -TestName "transfer provides helpful guidance" -Passed $hasHelpfulGuidance -Details "Provides guidance about device availability" -Requirement "6.7"
            
        } catch {
            Write-TestResult -TestName "transfer non-existent device test" -Passed $false -Details "Error testing non-existent device: $($_.Exception.Message)" -Requirement "6.7"
        }
    }
    
    # Test 3: Test authentication error handling
    Write-Host "🔐 Testing authentication error scenarios..." -ForegroundColor Cyan
    Write-Host "💡 Manual test: Test with expired/invalid tokens" -ForegroundColor Yellow
    Write-Host "Expected: Should show clear authentication error and re-authentication guidance" -ForegroundColor Gray
    
    # Test 4: Test network error handling
    Write-Host "🌐 Testing network error scenarios..." -ForegroundColor Cyan
    Write-Host "💡 Manual test: Test with network disconnected" -ForegroundColor Yellow
    Write-Host "Expected: Should show network-related error message" -ForegroundColor Gray
    
    # Test 5: Test Premium account requirement errors
    Write-Host "💎 Testing Premium account requirement scenarios..." -ForegroundColor Cyan
    Write-Host "💡 Manual test: Test device transfer with Free account" -ForegroundColor Yellow
    Write-Host "Expected: Should explain Premium requirement for device transfer" -ForegroundColor Gray
    
    # Test 6: Test device activation guidance
    Write-Host "📱 Testing device activation guidance..." -ForegroundColor Cyan
    Write-Host "💡 This should be tested when no active devices are available" -ForegroundColor Yellow
    Write-Host "Expected: Should provide clear steps to activate a device" -ForegroundColor Gray
    
    # Simulate some error scenarios that we can test programmatically
    Write-Host "🧪 Testing programmatic error scenarios..." -ForegroundColor Cyan
    
    # Test empty device list handling
    if (Get-Command devices -ErrorAction SilentlyContinue) {
        Write-Host "Testing devices command error handling..." -ForegroundColor Gray
        # This will depend on current Spotify state, but we can check the output format
        try {
            $devicesOutput = devices 2>&1 | Out-String
            $hasErrorHandling = $devicesOutput -match "(No devices|not found|❌)" -or $devicesOutput -match "Available Devices"
            
            Write-TestResult -TestName "devices command handles various states" -Passed $hasErrorHandling -Details "Command handles both success and error states appropriately" -Requirement "6.6"
            
        } catch {
            Write-TestResult -TestName "devices error handling test" -Passed $false -Details "Error testing devices error handling: $($_.Exception.Message)" -Requirement "6.6"
        }
    }
}

function Show-TestSummary {
    Write-Host ""
    Write-Host "📊 Test Summary" -ForegroundColor Cyan
    Write-Host "===============" -ForegroundColor Cyan
    Write-Host "✅ Passed: $($script:TestResults.Passed)" -ForegroundColor Green
    Write-Host "❌ Failed: $($script:TestResults.Failed)" -ForegroundColor Red
    Write-Host "⏭️ Skipped: $($script:TestResults.Skipped)" -ForegroundColor Yellow
    Write-Host ""
    
    $totalTests = $script:TestResults.Passed + $script:TestResults.Failed + $script:TestResults.Skipped
    if ($totalTests -gt 0) {
        $passRate = [Math]::Round(($script:TestResults.Passed / $totalTests) * 100, 1)
        Write-Host "📈 Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 80) { "Green" } elseif ($passRate -ge 60) { "Yellow" } else { "Red" })
    }
    
    if ($script:TestResults.Failed -gt 0) {
        Write-Host ""
        Write-Host "❌ Failed Tests:" -ForegroundColor Red
        $script:TestResults.Details | Where-Object { -not $_.Passed } | ForEach-Object {
            Write-Host "   • $($_.Test)" -ForegroundColor Red
            if ($_.Details) {
                Write-Host "     $($_.Details)" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host ""
    Write-Host "💡 Manual Testing Required:" -ForegroundColor Yellow
    Write-Host "• Test with no Spotify devices active" -ForegroundColor White
    Write-Host "• Test device transfer with actual devices" -ForegroundColor White
    Write-Host "• Test with Free vs Premium accounts" -ForegroundColor White
    Write-Host "• Test network connectivity issues" -ForegroundColor White
    Write-Host "• Test authentication expiration scenarios" -ForegroundColor White
}

# Main execution
Write-Host "🧪 Spotify CLI Device Management Test Suite" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in the right environment
if (-not (Test-Path "SpotifyModule.psm1") -and -not (Get-Module SpotifyModule -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️ Warning: SpotifyModule not found in current directory or loaded" -ForegroundColor Yellow
    Write-Host "Some tests may fail if the module is not properly installed" -ForegroundColor Gray
    Write-Host ""
}

# Run tests based on TestType parameter
switch ($TestType) {
    "All" {
        Test-DeviceListingCommand
        Test-DeviceTransferCommand
        Test-DeviceErrorScenarios
    }
    "Listing" {
        Test-DeviceListingCommand
    }
    "Transfer" {
        Test-DeviceTransferCommand
    }
    "Errors" {
        Test-DeviceErrorScenarios
    }
}

Show-TestSummary

Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Review failed tests and fix issues in the code" -ForegroundColor White
Write-Host "2. Run manual tests with actual Spotify devices" -ForegroundColor White
Write-Host "3. Test with different account types (Free vs Premium)" -ForegroundColor White
Write-Host "4. Verify error messages are helpful and actionable" -ForegroundColor White