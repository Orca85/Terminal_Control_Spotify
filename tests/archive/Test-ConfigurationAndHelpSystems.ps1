#!/usr/bin/env pwsh
<#
.SYNOPSIS
Comprehensive test runner for Spotify CLI configuration and help systems

.DESCRIPTION
Executes all tests for Task 11: Test and fix configuration and help systems
This includes all sub-tasks:
- 11.1 Test help system
- 11.2 Test configuration system  
- 11.3 Test notification controls

.EXAMPLE
.\Test-ConfigurationAndHelpSystems.ps1
Run all configuration and help system tests
#>

[CmdletBinding()]
param()

Write-Host "🎯 Spotify CLI Configuration and Help Systems Test Suite" -ForegroundColor Magenta
Write-Host "========================================================" -ForegroundColor Magenta
Write-Host ""

$overallResults = @()
$startTime = Get-Date

# Test 1: Help System (Task 11.1)
Write-Host "🔧 Running Task 11.1: Help System Tests" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Cyan

try {
    $helpResult = .\Test-HelpSystem.ps1
    $overallResults += @{
        Task = "11.1 Help System"
        Status = if ($helpResult) { "PASS" } else { "FAIL" }
        Details = "Help system functionality test"
    }
    Write-Host "Task 11.1 Result: $(if ($helpResult) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($helpResult) { 'Green' } else { 'Red' })
} catch {
    Write-Host "❌ Task 11.1 Failed: $($_.Exception.Message)" -ForegroundColor Red
    $overallResults += @{
        Task = "11.1 Help System"
        Status = "FAIL"
        Details = "Exception: $($_.Exception.Message)"
    }
}

Write-Host ""

# Test 2: Configuration System (Task 11.2)
Write-Host "🔧 Running Task 11.2: Configuration System Tests" -ForegroundColor Cyan
Write-Host "------------------------------------------------" -ForegroundColor Cyan

try {
    $configResult = .\Test-ConfigurationSystem.ps1
    $overallResults += @{
        Task = "11.2 Configuration System"
        Status = if ($configResult) { "PASS" } else { "FAIL" }
        Details = "Configuration system functionality test"
    }
    Write-Host "Task 11.2 Result: $(if ($configResult) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($configResult) { 'Green' } else { 'Red' })
} catch {
    Write-Host "❌ Task 11.2 Failed: $($_.Exception.Message)" -ForegroundColor Red
    $overallResults += @{
        Task = "11.2 Configuration System"
        Status = "FAIL"
        Details = "Exception: $($_.Exception.Message)"
    }
}

Write-Host ""

# Test 3: Notification System (Task 11.3)
Write-Host "🔧 Running Task 11.3: Notification System Tests" -ForegroundColor Cyan
Write-Host "-----------------------------------------------" -ForegroundColor Cyan

try {
    $notificationResult = .\Test-NotificationSystem.ps1
    $overallResults += @{
        Task = "11.3 Notification System"
        Status = if ($notificationResult) { "PASS" } else { "FAIL" }
        Details = "Notification system functionality test"
    }
    Write-Host "Task 11.3 Result: $(if ($notificationResult) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($notificationResult) { 'Green' } else { 'Red' })
} catch {
    Write-Host "❌ Task 11.3 Failed: $($_.Exception.Message)" -ForegroundColor Red
    $overallResults += @{
        Task = "11.3 Notification System"
        Status = "FAIL"
        Details = "Exception: $($_.Exception.Message)"
    }
}

Write-Host ""

# Overall Summary
$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host "📊 Overall Test Suite Summary" -ForegroundColor Magenta
Write-Host "=============================" -ForegroundColor Magenta

$passCount = ($overallResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($overallResults | Where-Object { $_.Status -eq "FAIL" }).Count
$totalCount = $overallResults.Count

Write-Host "Execution Time: $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor White
Write-Host "Total Tasks: $totalCount" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red

Write-Host ""
Write-Host "Task Results:" -ForegroundColor White
foreach ($result in $overallResults) {
    $color = if ($result.Status -eq "PASS") { "Green" } else { "Red" }
    $icon = if ($result.Status -eq "PASS") { "✅" } else { "❌" }
    Write-Host "$icon $($result.Task): $($result.Status)" -ForegroundColor $color
    Write-Host "   $($result.Details)" -ForegroundColor Gray
}

Write-Host ""

# Requirements mapping
Write-Host "📋 Requirements Coverage" -ForegroundColor Magenta
Write-Host "========================" -ForegroundColor Magenta

$req111 = ($overallResults | Where-Object { $_.Task -eq "11.1 Help System" -and $_.Status -eq "PASS" }) -ne $null
$req112 = $req111  # Same test covers both help command and alias
$req113 = $req111  # Same test covers spotify-help alias
$req114 = ($overallResults | Where-Object { $_.Task -eq "11.2 Configuration System" -and $_.Status -eq "PASS" }) -ne $null
$req115 = $req114  # Same test covers both get and set config
$req116 = ($overallResults | Where-Object { $_.Task -eq "11.3 Notification System" -and $_.Status -eq "PASS" }) -ne $null
$req117 = $req116  # Same test covers notifications on/off
$req118 = $req116  # Same test covers notifications test

Write-Host "Requirement 11.1 (Get-SpotifyHelp command): $(if ($req111) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req111) { 'Green' } else { 'Red' })
Write-Host "Requirement 11.2 (help alias): $(if ($req112) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req112) { 'Green' } else { 'Red' })
Write-Host "Requirement 11.3 (spotify-help alias): $(if ($req113) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req113) { 'Green' } else { 'Red' })
Write-Host "Requirement 11.4 (Get-SpotifyConfig display): $(if ($req114) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req114) { 'Green' } else { 'Red' })
Write-Host "Requirement 11.5 (Set-SpotifyConfig modify): $(if ($req115) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req115) { 'Green' } else { 'Red' })
Write-Host "Requirement 11.6 (notifications on): $(if ($req116) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req116) { 'Green' } else { 'Red' })
Write-Host "Requirement 11.7 (notifications off): $(if ($req117) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req117) { 'Green' } else { 'Red' })
Write-Host "Requirement 11.8 (notifications test): $(if ($req118) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($req118) { 'Green' } else { 'Red' })

$allRequirementsPassed = $req111 -and $req112 -and $req113 -and $req114 -and $req115 -and $req116 -and $req117 -and $req118

Write-Host ""

if ($allRequirementsPassed) {
    Write-Host "🎉 ALL REQUIREMENTS PASSED!" -ForegroundColor Green
    Write-Host "Task 11: Test and fix configuration and help systems - COMPLETE" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some requirements need attention" -ForegroundColor Yellow
    Write-Host "Task 11: Test and fix configuration and help systems - NEEDS WORK" -ForegroundColor Yellow
}

Write-Host ""

# Recommendations
Write-Host "💡 Recommendations" -ForegroundColor Magenta
Write-Host "==================" -ForegroundColor Magenta

if (-not $req111) {
    Write-Host "• Fix help system: Ensure Get-SpotifyHelp and aliases are properly exported" -ForegroundColor Yellow
}

if (-not $req114) {
    Write-Host "• Fix configuration system: Verify Get-SpotifyConfig and Set-SpotifyConfig functions" -ForegroundColor Yellow
}

if (-not $req116) {
    Write-Host "• Fix notification system: Check notifications command and Test-NotificationSupport" -ForegroundColor Yellow
}

if ($allRequirementsPassed) {
    Write-Host "• All systems working correctly! Ready for user testing." -ForegroundColor Green
    Write-Host "• Consider running manual tests to verify user experience." -ForegroundColor Green
}

Write-Host ""
Write-Host "📁 Test Files Created:" -ForegroundColor Cyan
Write-Host "• Test-HelpSystem.ps1 - Help system tests" -ForegroundColor White
Write-Host "• Test-ConfigurationSystem.ps1 - Configuration system tests" -ForegroundColor White  
Write-Host "• Test-NotificationSystem.ps1 - Notification system tests" -ForegroundColor White
Write-Host "• Test-ConfigurationAndHelpSystems.ps1 - This comprehensive test runner" -ForegroundColor White

Write-Host ""
Write-Host "🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Review any failed tests and fix underlying issues" -ForegroundColor White
Write-Host "2. Run individual test scripts for detailed debugging if needed" -ForegroundColor White
Write-Host "3. Test commands manually to verify user experience" -ForegroundColor White
Write-Host "4. Update task status to completed when all tests pass" -ForegroundColor White

return $allRequirementsPassed