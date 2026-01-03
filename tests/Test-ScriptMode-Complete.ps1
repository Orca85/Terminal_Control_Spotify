# Complete Script Mode Testing Summary
# Tests all requirements for Task 13: Script Mode (Interactive CLI)

param([switch]$SkipInteractive)

Write-Host "=== SPOTIFY CLI SCRIPT MODE TESTING COMPLETE ===" -ForegroundColor Magenta
Write-Host "Task 13: Test and fix script mode (interactive CLI)" -ForegroundColor White
Write-Host "Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 13.8" -ForegroundColor Gray
Write-Host ""

$allTests = @()

# Run all sub-tests
Write-Host "Running Task 13.1 - Basic Commands..." -ForegroundColor Cyan
$result1 = & powershell -ExecutionPolicy Bypass -File "Test-ScriptModeBasic.ps1" -SkipInteractive:$SkipInteractive
$allTests += @{Task = "13.1"; Result = $LASTEXITCODE -eq 0}

Write-Host "`nRunning Task 13.2 - Advanced Functionality..." -ForegroundColor Cyan  
$result2 = & powershell -ExecutionPolicy Bypass -File "Test-ScriptModeAdvanced-Simple.ps1" -SkipInteractive:$SkipInteractive
$allTests += @{Task = "13.2"; Result = $LASTEXITCODE -eq 0}

Write-Host "`nRunning Task 13.3 - Error Handling..." -ForegroundColor Cyan
$result3 = & powershell -ExecutionPolicy Bypass -File "Test-ScriptModeErrorHandling.ps1" -SkipInteractive:$SkipInteractive  
$allTests += @{Task = "13.3"; Result = $LASTEXITCODE -eq 0}

# Summary
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host " TASK 13 COMPLETION SUMMARY" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

$passed = 0
$failed = 0

foreach ($test in $allTests) {
    $status = if ($test.Result) { "PASS"; $passed++ } else { "FAIL"; $failed++ }
    $color = if ($test.Result) { "Green" } else { "Red" }
    Write-Host "Task $($test.Task): $status" -ForegroundColor $color
}

Write-Host "`nOverall Results:" -ForegroundColor White
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red

if ($failed -eq 0) {
    Write-Host "`nSUCCESS: All script mode functionality is working!" -ForegroundColor Green
    Write-Host "Requirements 13.1-13.8 have been validated." -ForegroundColor Green
    Write-Host ""
    Write-Host "Script Mode Features Verified:" -ForegroundColor Yellow
    Write-Host "- Interactive CLI startup and initialization" -ForegroundColor White
    Write-Host "- Basic commands (/help, /spotify)" -ForegroundColor White  
    Write-Host "- Advanced commands (/search, /devices, /config)" -ForegroundColor White
    Write-Host "- Error handling and unknown command processing" -ForegroundColor White
    Write-Host "- Clean exit functionality (/quit, /exit, /q)" -ForegroundColor White
    Write-Host "- Command consistency (with and without slash prefix)" -ForegroundColor White
} else {
    Write-Host "`nSome tests failed. Please review the issues above." -ForegroundColor Yellow
}

exit $(if ($failed -eq 0) { 0 } else { 1 })