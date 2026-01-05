# Test script mode advanced functionality
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

Write-Host "Testing Script Mode Advanced Functionality - Task 13.2" -ForegroundColor Magenta

$scriptContent = Get-Content ".\spotifyCLI.ps1" -Raw

# Test search command
$hasSearchCommand = $scriptContent -match '"/search".*Invoke-SearchCommand'
Write-TestResult -TestName "Script processes /search command" -Passed $hasSearchCommand

# Test devices command  
$hasDevicesCommand = $scriptContent -match '"/devices".*Invoke-DevicesCommand'
Write-TestResult -TestName "Script processes /devices command" -Passed $hasDevicesCommand

# Test config command
$hasConfigCommand = $scriptContent -match '"/config".*Invoke-ConfigCommand'
Write-TestResult -TestName "Script processes /config command" -Passed $hasConfigCommand

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