# Test Current Track Display Commands
# This script tests all aliases for showing current track information

param(
    [switch]$Verbose,
    [switch]$CompactMode
)

Write-Host "🧪 Testing Current Track Display Commands" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Import the module to ensure all functions and aliases are available
try {
    Import-Module .\SpotifyModule.psm1 -Force -ErrorAction Stop
    Write-Host "✅ SpotifyModule imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to import SpotifyModule: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test results storage
$TestResults = @{
    'Show-SpotifyTrack' = @{ Status = 'Not Tested'; Output = ''; Error = '' }
    'plays-now' = @{ Status = 'Not Tested'; Output = ''; Error = '' }
    'music' = @{ Status = 'Not Tested'; Output = ''; Error = '' }
    'pn' = @{ Status = 'Not Tested'; Output = ''; Error = '' }
    'sp' = @{ Status = 'Not Tested'; Output = ''; Error = '' }
    'spotify-now' = @{ Status = 'Not Tested'; Output = ''; Error = '' }
}

function Test-Command {
    param(
        [string]$CommandName,
        [string]$Mode = ""
    )
    
    Write-Host "🔍 Testing command: $CommandName" -ForegroundColor Yellow
    
    try {
        # Capture output and errors
        $output = ""
        $errorOutput = ""
        
        if ($Mode) {
            $output = & $CommandName $Mode 2>&1
        } else {
            $output = & $CommandName 2>&1
        }
        
        # Check if command executed without errors
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
            $TestResults[$CommandName].Status = 'Success'
            $TestResults[$CommandName].Output = $output -join "`n"
            Write-Host "  ✅ Command executed successfully" -ForegroundColor Green
            
            if ($Verbose) {
                Write-Host "  📄 Output:" -ForegroundColor Cyan
                $output | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
        } else {
            $TestResults[$CommandName].Status = 'Failed'
            $TestResults[$CommandName].Error = "Exit code: $LASTEXITCODE"
            Write-Host "  ❌ Command failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        }
    } catch {
        $TestResults[$CommandName].Status = 'Error'
        $TestResults[$CommandName].Error = $_.Exception.Message
        Write-Host "  ❌ Command error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

function Test-AliasExists {
    param([string]$AliasName)
    
    try {
        $alias = Get-Alias -Name $AliasName -ErrorAction Stop
        Write-Host "  ✅ Alias '$AliasName' exists and points to '$($alias.Definition)'" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  ❌ Alias '$AliasName' does not exist" -ForegroundColor Red
        return $false
    }
}

function Test-FunctionExists {
    param([string]$FunctionName)
    
    try {
        $function = Get-Command -Name $FunctionName -CommandType Function -ErrorAction Stop
        Write-Host "  ✅ Function '$FunctionName' exists" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  ❌ Function '$FunctionName' does not exist" -ForegroundColor Red
        return $false
    }
}

# Test 1: Check if all aliases and functions exist
Write-Host "📋 Phase 1: Checking Command Availability" -ForegroundColor Magenta
Write-Host "===========================================" -ForegroundColor Magenta

Write-Host "🔍 Checking main function:" -ForegroundColor Yellow
Test-FunctionExists -FunctionName "Show-SpotifyTrack"

Write-Host "🔍 Checking aliases:" -ForegroundColor Yellow
$aliasesExist = @{
    'plays-now' = Test-AliasExists -AliasName 'plays-now'
    'music' = Test-AliasExists -AliasName 'music'
    'pn' = Test-AliasExists -AliasName 'pn'
    'sp' = Test-AliasExists -AliasName 'sp'
}

Write-Host "🔍 Checking additional functions:" -ForegroundColor Yellow
Test-FunctionExists -FunctionName "spotify-now"

Write-Host ""

# Test 2: Test all commands with default mode
Write-Host "📋 Phase 2: Testing Commands (Default Mode)" -ForegroundColor Magenta
Write-Host "=============================================" -ForegroundColor Magenta

# Test main function
Test-Command -CommandName "Show-SpotifyTrack"

# Test aliases (only if they exist)
if ($aliasesExist['plays-now']) { Test-Command -CommandName "plays-now" }
if ($aliasesExist['music']) { Test-Command -CommandName "music" }
if ($aliasesExist['pn']) { Test-Command -CommandName "pn" }
if ($aliasesExist['sp']) { Test-Command -CommandName "sp" }

# Test additional function
Test-Command -CommandName "spotify-now"

# Test 3: Test compact mode if requested
if ($CompactMode) {
    Write-Host "📋 Phase 3: Testing Commands (Compact Mode)" -ForegroundColor Magenta
    Write-Host "=============================================" -ForegroundColor Magenta
    
    Test-Command -CommandName "Show-SpotifyTrack" -Mode "compact"
    if ($aliasesExist['plays-now']) { Test-Command -CommandName "plays-now" -Mode "compact" }
    if ($aliasesExist['music']) { Test-Command -CommandName "music" -Mode "compact" }
    if ($aliasesExist['pn']) { Test-Command -CommandName "pn" -Mode "compact" }
    if ($aliasesExist['sp']) { Test-Command -CommandName "sp" -Mode "compact" }
    Test-Command -CommandName "spotify-now" -Mode "compact"
}

# Test 4: Check for consistency in output
Write-Host "📋 Phase 4: Output Consistency Analysis" -ForegroundColor Magenta
Write-Host "=======================================" -ForegroundColor Magenta

$successfulCommands = $TestResults.GetEnumerator() | Where-Object { $_.Value.Status -eq 'Success' }
$outputs = $successfulCommands | ForEach-Object { $_.Value.Output }

if ($outputs.Count -gt 1) {
    $firstOutput = $outputs[0]
    $allSame = $true
    
    for ($i = 1; $i -lt $outputs.Count; $i++) {
        if ($outputs[$i] -ne $firstOutput) {
            $allSame = $false
            break
        }
    }
    
    if ($allSame) {
        Write-Host "✅ All commands produce identical output" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Commands produce different outputs" -ForegroundColor Yellow
        Write-Host "This may indicate inconsistencies in implementation" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Not enough successful commands to compare outputs" -ForegroundColor Yellow
}

Write-Host ""

# Summary Report
Write-Host "📊 Test Summary Report" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan

$totalTests = $TestResults.Count
$successfulTests = ($TestResults.GetEnumerator() | Where-Object { $_.Value.Status -eq 'Success' }).Count
$failedTests = ($TestResults.GetEnumerator() | Where-Object { $_.Value.Status -eq 'Failed' }).Count
$errorTests = ($TestResults.GetEnumerator() | Where-Object { $_.Value.Status -eq 'Error' }).Count

Write-Host "Total Commands Tested: $totalTests" -ForegroundColor White
Write-Host "Successful: $successfulTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor Red
Write-Host "Errors: $errorTests" -ForegroundColor Red

Write-Host ""
Write-Host "📋 Detailed Results:" -ForegroundColor Cyan

foreach ($result in $TestResults.GetEnumerator()) {
    $command = $result.Key
    $status = $result.Value.Status
    $error = $result.Value.Error
    
    switch ($status) {
        'Success' { 
            Write-Host "  ✅ $command" -ForegroundColor Green 
        }
        'Failed' { 
            Write-Host "  ❌ $command - $error" -ForegroundColor Red 
        }
        'Error' { 
            Write-Host "  ⚠️ $command - $error" -ForegroundColor Yellow 
        }
        'Not Tested' { 
            Write-Host "  ⏸️ $command - Not tested" -ForegroundColor Gray 
        }
    }
}

Write-Host ""

# Requirements validation
Write-Host "📋 Requirements Validation" -ForegroundColor Magenta
Write-Host "==========================" -ForegroundColor Magenta

$requirements = @{
    "3.1" = "plays-now command displays detailed current track information"
    "3.2" = "music command displays detailed current track information"
    "3.3" = "pn command displays detailed current track information"
    "3.4" = "Show-SpotifyTrack command displays detailed current track information"
    "3.5" = "sp command displays detailed current track information (legacy)"
}

foreach ($req in $requirements.GetEnumerator()) {
    $reqId = $req.Key
    $reqDesc = $req.Value
    
    # Map requirement to command
    $commandName = switch ($reqId) {
        "3.1" { "plays-now" }
        "3.2" { "music" }
        "3.3" { "pn" }
        "3.4" { "Show-SpotifyTrack" }
        "3.5" { "sp" }
    }
    
    if ($TestResults.ContainsKey($commandName) -and $TestResults[$commandName].Status -eq 'Success') {
        Write-Host "  ✅ Requirement $reqId`: $reqDesc" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Requirement $reqId`: $reqDesc" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🏁 Test Complete!" -ForegroundColor Cyan

# Return exit code based on results
if ($failedTests -gt 0 -or $errorTests -gt 0) {
    exit 1
} else {
    exit 0
}