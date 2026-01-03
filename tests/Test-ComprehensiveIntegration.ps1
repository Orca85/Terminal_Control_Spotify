# Test-ComprehensiveIntegration.ps1
# Master integration test runner for all Spotify CLI functionality
# Combines first-time user, power user, and cross-platform compatibility tests

param(
    [switch]$Interactive = $false,
    [switch]$Verbose = $false,
    [switch]$SkipFirstTime = $false,
    [switch]$SkipPowerUser = $false,
    [switch]$SkipCrossPlatform = $false
)

# Overall test results tracking
$OverallResults = @{
    TestSuites = @()
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    StartTime = Get-Date
}

function Write-Header {
    param([string]$Title)
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 60 -ForegroundColor Magenta
    Write-Host $Title -ForegroundColor Magenta
    Write-Host "=" * 60 -ForegroundColor Magenta
}

function Write-SubHeader {
    param([string]$Title)
    
    Write-Host "`n$Title" -ForegroundColor Cyan
    Write-Host "-" * $Title.Length -ForegroundColor Cyan
}

function Run-TestSuite {
    param(
        [string]$SuiteName,
        [string]$ScriptPath,
        [hashtable]$Parameters = @{}
    )
    
    Write-SubHeader "Running $SuiteName"
    
    $suiteResult = @{
        Name = $SuiteName
        StartTime = Get-Date
        Success = $false
        Output = ""
        Error = ""
    }
    
    try {
        # Build parameter string
        $paramString = ""
        foreach ($param in $Parameters.GetEnumerator()) {
            if ($param.Value -eq $true) {
                $paramString += " -$($param.Key)"
            } elseif ($param.Value -ne $false) {
                $paramString += " -$($param.Key) '$($param.Value)'"
            }
        }
        
        Write-Host "Executing: .\$ScriptPath$paramString" -ForegroundColor Gray
        
        # Execute the test script
        $output = & ".\$ScriptPath" @Parameters 2>&1
        
        # Parse results from output
        $outputString = $output | Out-String
        $suiteResult.Output = $outputString
        
        # Look for success indicators in output
        if ($outputString -match "Success Rate: (\d+\.?\d*)%") {
            $successRate = [double]$matches[1]
            $suiteResult.Success = $successRate -ge 70  # Consider 70%+ as passing
            
            # Extract test counts
            if ($outputString -match "Total Tests: (\d+)") {
                $totalTests = [int]$matches[1]
                $OverallResults.TotalTests += $totalTests
            }
            if ($outputString -match "Passed: (\d+)") {
                $passedTests = [int]$matches[1]
                $OverallResults.PassedTests += $passedTests
            }
            if ($outputString -match "Failed: (\d+)") {
                $failedTests = [int]$matches[1]
                $OverallResults.FailedTests += $failedTests
            }
            
            Write-Host "✓ $SuiteName completed with $successRate% success rate" -ForegroundColor Green
        } else {
            $suiteResult.Success = $false
            Write-Host "✗ $SuiteName failed to complete properly" -ForegroundColor Red
        }
        
    } catch {
        $suiteResult.Success = $false
        $suiteResult.Error = $_.Exception.Message
        Write-Host "✗ $SuiteName failed with error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $suiteResult.EndTime = Get-Date
    $suiteResult.Duration = $suiteResult.EndTime - $suiteResult.StartTime
    
    $OverallResults.TestSuites += $suiteResult
    
    return $suiteResult
}

# Main execution
Write-Header "Spotify CLI Comprehensive Integration Test Suite"

Write-Host "Test Configuration:" -ForegroundColor White
Write-Host "  Interactive Mode: $Interactive" -ForegroundColor Gray
Write-Host "  Verbose Output: $Verbose" -ForegroundColor Gray
Write-Host "  Skip First-Time: $SkipFirstTime" -ForegroundColor Gray
Write-Host "  Skip Power User: $SkipPowerUser" -ForegroundColor Gray
Write-Host "  Skip Cross-Platform: $SkipCrossPlatform" -ForegroundColor Gray

# Verify test scripts exist
$testScripts = @(
    @{Name = "First-Time User Workflow"; Path = "Test-FirstTimeUserWorkflow.ps1"; Skip = $SkipFirstTime},
    @{Name = "Power User Workflows"; Path = "Test-PowerUserWorkflows.ps1"; Skip = $SkipPowerUser},
    @{Name = "Cross-Platform Compatibility"; Path = "Test-CrossPlatformCompatibility.ps1"; Skip = $SkipCrossPlatform}
)

Write-SubHeader "Verifying Test Scripts"
$allScriptsExist = $true
foreach ($script in $testScripts) {
    if (-not $script.Skip) {
        $exists = Test-Path $script.Path
        if ($exists) {
            Write-Host "✓ $($script.Path) found" -ForegroundColor Green
        } else {
            Write-Host "✗ $($script.Path) not found" -ForegroundColor Red
            $allScriptsExist = $false
        }
    } else {
        Write-Host "⊘ $($script.Path) skipped" -ForegroundColor Yellow
    }
}

if (-not $allScriptsExist) {
    Write-Host "`nError: Missing required test scripts. Cannot proceed." -ForegroundColor Red
    exit 1
}

# Run test suites
Write-Header "Executing Test Suites"

$testParams = @{
    Interactive = $Interactive
    Verbose = $Verbose
}

# Test Suite 1: First-Time User Workflow
if (-not $SkipFirstTime) {
    $firstTimeResult = Run-TestSuite -SuiteName "First-Time User Workflow" -ScriptPath "Test-FirstTimeUserWorkflow.ps1" -Parameters $testParams
}

# Test Suite 2: Power User Workflows  
if (-not $SkipPowerUser) {
    $powerUserResult = Run-TestSuite -SuiteName "Power User Workflows" -ScriptPath "Test-PowerUserWorkflows.ps1" -Parameters $testParams
}

# Test Suite 3: Cross-Platform Compatibility
if (-not $SkipCrossPlatform) {
    $crossPlatformParams = @{Verbose = $Verbose}  # Cross-platform test doesn't use Interactive
    $crossPlatformResult = Run-TestSuite -SuiteName "Cross-Platform Compatibility" -ScriptPath "Test-CrossPlatformCompatibility.ps1" -Parameters $crossPlatformParams
}

# Calculate overall results
$OverallResults.EndTime = Get-Date
$OverallResults.Duration = $OverallResults.EndTime - $OverallResults.StartTime

# Display comprehensive results
Write-Header "Comprehensive Integration Test Results"

Write-Host "`n=== Test Suite Summary ===" -ForegroundColor Cyan
foreach ($suite in $OverallResults.TestSuites) {
    $status = if ($suite.Success) { "✓ PASSED" } else { "✗ FAILED" }
    $statusColor = if ($suite.Success) { "Green" } else { "Red" }
    $duration = "{0:mm\:ss}" -f $suite.Duration
    
    Write-Host "$status - $($suite.Name) ($duration)" -ForegroundColor $statusColor
    
    if (-not $suite.Success -and $suite.Error) {
        Write-Host "    Error: $($suite.Error)" -ForegroundColor Red
    }
}

Write-Host "`n=== Overall Statistics ===" -ForegroundColor Cyan
Write-Host "Total Test Suites: $($OverallResults.TestSuites.Count)" -ForegroundColor White
$passedSuites = ($OverallResults.TestSuites | Where-Object { $_.Success }).Count
$failedSuites = $OverallResults.TestSuites.Count - $passedSuites
Write-Host "Passed Suites: $passedSuites" -ForegroundColor Green
Write-Host "Failed Suites: $failedSuites" -ForegroundColor Red

Write-Host "`nTotal Individual Tests: $($OverallResults.TotalTests)" -ForegroundColor White
Write-Host "Passed Tests: $($OverallResults.PassedTests)" -ForegroundColor Green
Write-Host "Failed Tests: $($OverallResults.FailedTests)" -ForegroundColor Red

if ($OverallResults.TotalTests -gt 0) {
    $overallSuccessRate = [math]::Round(($OverallResults.PassedTests / $OverallResults.TotalTests) * 100, 1)
    Write-Host "Overall Success Rate: $overallSuccessRate%" -ForegroundColor $(if ($overallSuccessRate -ge 80) { "Green" } elseif ($overallSuccessRate -ge 60) { "Yellow" } else { "Red" })
}

$totalDuration = "{0:mm\:ss}" -f $OverallResults.Duration
Write-Host "Total Execution Time: $totalDuration" -ForegroundColor White

# Integration assessment
Write-Host "`n=== Integration Assessment ===" -ForegroundColor Cyan

$allSuitesPassed = $failedSuites -eq 0
$highSuccessRate = $OverallResults.TotalTests -gt 0 -and ($OverallResults.PassedTests / $OverallResults.TotalTests) -ge 0.8

if ($allSuitesPassed -and $highSuccessRate) {
    Write-Host "🎉 EXCELLENT: All integration tests passed successfully!" -ForegroundColor Green
    Write-Host "   The Spotify CLI is ready for production use." -ForegroundColor Green
    Write-Host "   All user workflows, advanced features, and cross-platform compatibility verified." -ForegroundColor Green
} elseif ($passedSuites -ge ($OverallResults.TestSuites.Count * 0.7)) {
    Write-Host "⚠️  GOOD: Most integration tests passed." -ForegroundColor Yellow
    Write-Host "   The Spotify CLI is functional but may have some issues." -ForegroundColor Yellow
    Write-Host "   Review failed tests and address critical issues before deployment." -ForegroundColor Yellow
} else {
    Write-Host "❌ NEEDS WORK: Multiple integration test failures detected." -ForegroundColor Red
    Write-Host "   The Spotify CLI requires significant fixes before deployment." -ForegroundColor Red
    Write-Host "   Address all critical failures before proceeding." -ForegroundColor Red
}

# Specific recommendations
Write-Host "`n=== Recommendations ===" -ForegroundColor Cyan

if ($failedSuites -gt 0) {
    Write-Host "Failed Test Suites Require Attention:" -ForegroundColor Yellow
    
    foreach ($suite in $OverallResults.TestSuites | Where-Object { -not $_.Success }) {
        Write-Host "  • $($suite.Name): Review detailed output for specific issues" -ForegroundColor Yellow
    }
}

# Environment-specific recommendations
if ($OverallResults.TestSuites | Where-Object { $_.Name -eq "Cross-Platform Compatibility" -and -not $_.Success }) {
    Write-Host "`nCross-Platform Issues Detected:" -ForegroundColor Yellow
    Write-Host "  • Verify PowerShell version compatibility" -ForegroundColor Gray
    Write-Host "  • Check terminal and console support" -ForegroundColor Gray
    Write-Host "  • Ensure network connectivity to Spotify APIs" -ForegroundColor Gray
}

if ($OverallResults.TestSuites | Where-Object { $_.Name -eq "First-Time User Workflow" -and -not $_.Success }) {
    Write-Host "`nFirst-Time User Experience Issues:" -ForegroundColor Yellow
    Write-Host "  • Verify authentication setup and .env configuration" -ForegroundColor Gray
    Write-Host "  • Check basic functionality and error handling" -ForegroundColor Gray
    Write-Host "  • Ensure clear user guidance and setup instructions" -ForegroundColor Gray
}

if ($OverallResults.TestSuites | Where-Object { $_.Name -eq "Power User Workflows" -and -not $_.Success }) {
    Write-Host "`nPower User Feature Issues:" -ForegroundColor Yellow
    Write-Host "  • Review advanced features like smart numbers and aliases" -ForegroundColor Gray
    Write-Host "  • Check interactive navigation and customization options" -ForegroundColor Gray
    Write-Host "  • Verify efficiency workflows and shortcuts" -ForegroundColor Gray
}

# Next steps
Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan

if ($allSuitesPassed) {
    Write-Host "✅ Integration testing complete - CLI is ready for deployment" -ForegroundColor Green
    Write-Host "✅ Consider running periodic regression tests" -ForegroundColor Green
    Write-Host "✅ Update documentation to reflect tested functionality" -ForegroundColor Green
} else {
    Write-Host "🔧 Address failed test cases before deployment" -ForegroundColor Yellow
    Write-Host "🔧 Re-run specific test suites after fixes" -ForegroundColor Yellow
    Write-Host "🔧 Consider implementing additional error handling" -ForegroundColor Yellow
}

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Magenta
Write-Host "Comprehensive Integration Testing Complete" -ForegroundColor Magenta
Write-Host "=" * 60 -ForegroundColor Magenta

# Return exit code based on results
if ($allSuitesPassed) {
    exit 0
} else {
    exit 1
}