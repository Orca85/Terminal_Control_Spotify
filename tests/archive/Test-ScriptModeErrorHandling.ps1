# Test script mode error handling functionality
param([switch]$SkipInteractive)

$TestResults = @()
$ErrorCount = 0

function Write-TestResult {
    param([string]$TestName, [bool]$Passed, [string]$Details = "")
    
    $script:TestResults += @{TestName = $TestName; Passed = $Passed; Details = $Details}
    
    $status = if ($Passed) { "PASS" } else { "FAIL"; $script:ErrorCount++ }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "$status - $TestName" -ForegroundColor $color
    if ($Details) { Write-Host "    $Details" -ForegroundColor Gray }
}

Write-Host "Testing Script Mode Error Handling - Task 13.3" -ForegroundColor Magenta

$scriptContent = Get-Content ".\spotifyCLI.ps1" -Raw

# Test quit command
$hasQuitCommand = $scriptContent -match '"/quit".*exit'
Write-TestResult -TestName "Script processes /quit command" -Passed $hasQuitCommand -Details "Clean exit functionality"

# Test exit command
$hasExitCommand = $scriptContent -match '"/exit".*exit'
Write-TestResult -TestName "Script processes /exit command" -Passed $hasExitCommand -Details "Alternative exit command"

# Test q command
$hasQCommand = $scriptContent -match '"/q".*exit'
Write-TestResult -TestName "Script processes /q command" -Passed $hasQCommand -Details "Short exit command"

# Test unknown command handling
$hasUnknownHandling = $scriptContent -match 'Show-UnknownCommand'
Write-TestResult -TestName "Script handles unknown commands" -Passed $hasUnknownHandling -Details "Error handling for invalid commands"

# Test Show-UnknownCommand function exists
$hasUnknownFunction = $scriptContent -match 'function Show-UnknownCommand'
Write-TestResult -TestName "Show-UnknownCommand function exists" -Passed $hasUnknownFunction -Details "Unknown command handler implementation"

# Test command consistency (both with and without slash)
$hasConsistentCommands = ($scriptContent -match '"spotify".*Show-CurrentTrack') -and ($scriptContent -match '"/spotify".*Show-CurrentTrack')
Write-TestResult -TestName "Commands work with and without slash" -Passed $hasConsistentCommands -Details "Consistent command behavior"

if (-not $SkipInteractive) {
    Write-Host "`nMANUAL TEST REQUIRED:" -ForegroundColor Yellow
    Write-Host "Please test these scenarios in the CLI:" -ForegroundColor White
    Write-Host "1. Start CLI: .\spotifyCLI.ps1" -ForegroundColor Cyan
    Write-Host "2. Test invalid command: /invalidcommand" -ForegroundColor Cyan
    Write-Host "3. Verify error message and suggestions" -ForegroundColor Cyan
    Write-Host "4. Test /quit to exit cleanly" -ForegroundColor Cyan
    Write-Host "5. Verify consistent behavior between global and script commands" -ForegroundColor Cyan
    
    $response = Read-Host "Did error handling work correctly? (y/n)"
    $manualPassed = $response -match "^y"
    Write-TestResult -TestName "Manual error handling verification" -Passed $manualPassed -Details "Interactive error testing"
}

Write-Host "`nTest Summary:" -ForegroundColor Cyan
Write-Host "Total Tests: $($TestResults.Count)" -ForegroundColor White
Write-Host "Passed: $(($TestResults | Where-Object Passed).Count)" -ForegroundColor Green
Write-Host "Failed: $ErrorCount" -ForegroundColor Red

if ($ErrorCount -eq 0) {
    Write-Host "All tests passed!" -ForegroundColor Green
} else {
    Write-Host "Some tests failed." -ForegroundColor Yellow
}

exit $(if ($ErrorCount -eq 0) { 0 } else { 1 })