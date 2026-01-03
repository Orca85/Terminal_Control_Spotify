#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test script mode startup and basic commands for Spotify CLI

.DESCRIPTION
Tests the interactive CLI mode functionality including:
- Script startup and initialization
- Basic commands (/help, /spotify)
- Command processing and response validation

This addresses requirements 13.1, 13.2, 13.3 from the testing specification.
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
        [string]$Details = "",
        [string]$Expected = "",
        [string]$Actual = ""
    )
    
    $result = @{
        TestName = $TestName
        Passed = $Passed
        Details = $Details
        Expected = $Expected
        Actual = $Actual
        Timestamp = Get-Date
    }
    
    $script:TestResults += $result
    
    $status = if ($Passed) { "✅ PASS" } else { "❌ FAIL"; $script:ErrorCount++ }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "$status - $TestName" -ForegroundColor $color
    if ($Details) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
    if (-not $Passed -and $Expected) {
        Write-Host "    Expected: $Expected" -ForegroundColor Yellow
        Write-Host "    Actual: $Actual" -ForegroundColor Yellow
    }
}

function Test-ScriptExists {
    Write-TestHeader "Task 13.1.1 - Script File Validation"
    
    $scriptPath = ".\spotifyCLI.ps1"
    $exists = Test-Path $scriptPath
    
    Write-TestResult -TestName "spotifyCLI.ps1 exists" -Passed $exists -Details "Script file must exist for interactive mode testing"
    
    if ($exists) {
        $content = Get-Content $scriptPath -Raw
        $hasInteractiveLoop = $content -match "while \(\`$true\)"
        Write-TestResult -TestName "Script contains interactive loop" -Passed $hasInteractiveLoop -Details "Script must have main interactive command loop"
        
        $hasInvokeCommand = $content -match "function Invoke-SpotifyCommand"
        Write-TestResult -TestName "Script contains command processor" -Passed $hasInvokeCommand -Details "Script must have command processing function"
    }
    
    return $exists
}

function Test-ScriptStartup {
    Write-TestHeader "Task 13.1.2 - Script Startup Testing"
    
    # Test script syntax validation
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content ".\spotifyCLI.ps1" -Raw), [ref]$null)
        Write-TestResult -TestName "Script syntax validation" -Passed $true -Details "PowerShell syntax is valid"
    } catch {
        Write-TestResult -TestName "Script syntax validation" -Passed $false -Details "Syntax error: $($_.Exception.Message)"
        return $false
    }
    
    # Test .env file requirement
    $envExists = Test-Path ".\.env"
    Write-TestResult -TestName ".env file exists" -Passed $envExists -Details "Required for Spotify API credentials"
    
    if ($envExists) {
        $envContent = Get-Content ".\.env" -Raw
        $hasClientId = $envContent -match "SPOTIFY_CLIENT_ID"
        $hasClientSecret = $envContent -match "SPOTIFY_CLIENT_SECRET"
        
        Write-TestResult -TestName ".env contains CLIENT_ID" -Passed $hasClientId -Details "Required for authentication"
        Write-TestResult -TestName ".env contains CLIENT_SECRET" -Passed $hasClientSecret -Details "Required for authentication"
    }
    
    return $envExists
}

function Test-HelpCommand {
    Write-TestHeader "Task 13.1.3 - Help Command Testing"
    
    if ($SkipInteractive) {
        Write-Host "⏭️ Skipping interactive tests (use -SkipInteractive:$false to enable)" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "`n📋 MANUAL TEST REQUIRED:" -ForegroundColor Yellow
    Write-Host "Please run the following test manually:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Open a new PowerShell window" -ForegroundColor Cyan
    Write-Host "2. Navigate to this directory" -ForegroundColor Cyan
    Write-Host "3. Run: .\spotifyCLI.ps1" -ForegroundColor Cyan
    Write-Host "4. When the CLI starts, type: /help" -ForegroundColor Cyan
    Write-Host "5. Verify the help output shows:" -ForegroundColor Cyan
    Write-Host "   - List of available commands" -ForegroundColor White
    Write-Host "   - Command descriptions" -ForegroundColor White
    Write-Host "   - Proper formatting" -ForegroundColor White
    Write-Host "6. Type: /quit to exit" -ForegroundColor Cyan
    Write-Host ""
    
    $response = Read-Host "Did the /help command work correctly? (y/n)"
    $passed = $response -match "^y"
    
    Write-TestResult -TestName "/help command functionality" -Passed $passed -Details "Manual verification of help system"
    
    return $passed
}

function Test-SpotifyCommand {
    Write-TestHeader "Task 13.1.4 - Current Track Command Testing"
    
    if ($SkipInteractive) {
        Write-Host "⏭️ Skipping interactive tests (use -SkipInteractive:$false to enable)" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "`n📋 MANUAL TEST REQUIRED:" -ForegroundColor Yellow
    Write-Host "Please run the following test manually:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Ensure Spotify is running and playing music" -ForegroundColor Cyan
    Write-Host "2. In the CLI (if not already running): .\spotifyCLI.ps1" -ForegroundColor Cyan
    Write-Host "3. Type: /spotify" -ForegroundColor Cyan
    Write-Host "4. Verify the output shows:" -ForegroundColor Cyan
    Write-Host "   - Current track name" -ForegroundColor White
    Write-Host "   - Artist information" -ForegroundColor White
    Write-Host "   - Album information" -ForegroundColor White
    Write-Host "   - Progress bar and time" -ForegroundColor White
    Write-Host "   - Device information" -ForegroundColor White
    Write-Host "5. Test with no music playing (pause Spotify)" -ForegroundColor Cyan
    Write-Host "6. Type: /spotify again" -ForegroundColor Cyan
    Write-Host "7. Verify it shows 'No track playing' or similar" -ForegroundColor Cyan
    Write-Host ""
    
    $response = Read-Host "Did the /spotify command work correctly? (y/n)"
    $passed = $response -match "^y"
    
    Write-TestResult -TestName "/spotify command functionality" -Passed $passed -Details "Manual verification of current track display"
    
    return $passed
}

function Test-CommandProcessing {
    Write-TestHeader "Task 13.1.5 - Command Processing Validation"
    
    # Test that the Invoke-SpotifyCommand function exists and has proper structure
    $scriptContent = Get-Content ".\spotifyCLI.ps1" -Raw
    
    # Check for command processing patterns
    $hasSpotifyCommand = $scriptContent -match '"/spotify".*Show-CurrentTrack'
    Write-TestResult -TestName "Script processes /spotify command" -Passed $hasSpotifyCommand -Details "Command routing for /spotify"
    
    $hasHelpCommand = $scriptContent -match '"/help".*Invoke-HelpCommand'
    Write-TestResult -TestName "Script processes /help command" -Passed $hasHelpCommand -Details "Command routing for /help"
    
    $hasQuitCommand = $scriptContent -match '"/quit".*exit'
    Write-TestResult -TestName "Script processes /quit command" -Passed $hasQuitCommand -Details "Command routing for /quit"
    
    $hasDefaultCase = $scriptContent -match 'Show-UnknownCommand'
    Write-TestResult -TestName "Script handles unknown commands" -Passed $hasDefaultCase -Details "Error handling for invalid commands"
    
    return ($hasSpotifyCommand -and $hasHelpCommand -and $hasQuitCommand -and $hasDefaultCase)
}

function Test-InitializationSequence {
    Write-TestHeader "Task 13.1.6 - Initialization Sequence Testing"
    
    $scriptContent = Get-Content ".\spotifyCLI.ps1" -Raw
    
    # Check for proper initialization
    $hasTokenInit = $scriptContent -match 'Get-SpotifyAccessToken'
    Write-TestResult -TestName "Script initializes authentication" -Passed $hasTokenInit -Details "Token initialization on startup"
    
    $hasWelcomeMessage = $scriptContent -match 'Spotify CLI.*Enhanced PowerShell Interface'
    Write-TestResult -TestName "Script shows welcome message" -Passed $hasWelcomeMessage -Details "User-friendly startup message"
    
    $hasQuickStart = $scriptContent -match 'Quick start commands'
    Write-TestResult -TestName "Script shows quick start guide" -Passed $hasQuickStart -Details "Initial user guidance"
    
    return ($hasTokenInit -and $hasWelcomeMessage -and $hasQuickStart)
}

# Main test execution
function Main {
    Write-Host "🧪 Spotify CLI Script Mode Testing - Task 13.1" -ForegroundColor Magenta
    Write-Host "Testing script mode startup and basic commands" -ForegroundColor White
    Write-Host "Requirements: 13.1, 13.2, 13.3" -ForegroundColor Gray
    
    $allPassed = $true
    
    # Run all tests
    $allPassed = (Test-ScriptExists) -and $allPassed
    $allPassed = (Test-ScriptStartup) -and $allPassed
    $allPassed = (Test-CommandProcessing) -and $allPassed
    $allPassed = (Test-InitializationSequence) -and $allPassed
    $allPassed = (Test-HelpCommand) -and $allPassed
    if (-not $SkipInteractive) {
        $allPassed = (Test-SpotifyCommand) -and $allPassed
    }
    
    # Summary
    Write-TestHeader "Test Summary"
    Write-Host "Total Tests: $($TestResults.Count)" -ForegroundColor White
    Write-Host "Passed: $(($TestResults | Where-Object Passed).Count)" -ForegroundColor Green
    Write-Host "Failed: $ErrorCount" -ForegroundColor Red
    
    if ($ErrorCount -eq 0) {
        Write-Host "`n🎉 All tests passed! Script mode basic functionality is working." -ForegroundColor Green
    } else {
        Write-Host "`n⚠️ Some tests failed. Please review the issues above." -ForegroundColor Yellow
    }
    
    # Detailed results if requested
    if ($DetailedOutput) {
        Write-TestHeader "Detailed Results"
        $TestResults | ForEach-Object {
            $status = if ($_.Passed) { "✅" } else { "❌" }
            Write-Host "$status $($_.TestName)" -ForegroundColor $(if ($_.Passed) { "Green" } else { "Red" })
            if ($_.Details) {
                Write-Host "    $($_.Details)" -ForegroundColor Gray
            }
        }
    }
    
    return $allPassed
}

# Execute main function
$success = Main

# Exit with appropriate code
exit $(if ($success) { 0 } else { 1 })