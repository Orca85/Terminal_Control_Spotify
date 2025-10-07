#!/usr/bin/env pwsh
# Test script for interactive mode integration

# Import the module
Import-Module .\SpotifyModule.psm1 -Force

Write-Host "🧪 Testing Interactive Mode Integration" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if interactive mode functions exist
Write-Host "Test 1: Checking if interactive mode functions exist..." -ForegroundColor Yellow

$functions = @(
    'Enter-InteractiveMode',
    'Start-InteractiveSearch', 
    'Start-InteractivePlaylistBrowser',
    'Start-InteractiveAlbumBrowser',
    'Show-NumberedList'
)

foreach ($func in $functions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "✅ $func exists" -ForegroundColor Green
    } else {
        Write-Host "❌ $func missing" -ForegroundColor Red
    }
}

Write-Host ""

# Test 2: Check if enhanced functions support Interactive parameter
Write-Host "Test 2: Checking Interactive parameter support..." -ForegroundColor Yellow

$enhancedFunctions = @(
    @{ Name = 'search'; Params = @('Query', 'Interactive') },
    @{ Name = 'Show-Playlists'; Params = @('Limit', 'Interactive') },
    @{ Name = 'playlists'; Params = @('Interactive') },
    @{ Name = 'Search-Albums'; Params = @('Query', 'Limit', 'Interactive') },
    @{ Name = 'Show-Albums'; Params = @('Interactive') },
    @{ Name = 'albums'; Params = @('Interactive') }
)

foreach ($funcInfo in $enhancedFunctions) {
    $cmd = Get-Command $funcInfo.Name -ErrorAction SilentlyContinue
    if ($cmd) {
        $hasInteractive = $cmd.Parameters.ContainsKey('Interactive')
        if ($hasInteractive) {
            Write-Host "✅ $($funcInfo.Name) supports -Interactive parameter" -ForegroundColor Green
        } else {
            Write-Host "❌ $($funcInfo.Name) missing -Interactive parameter" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ $($funcInfo.Name) function not found" -ForegroundColor Red
    }
}

Write-Host ""

# Test 3: Check if InteractiveMode class exists and has required methods
Write-Host "Test 3: Checking InteractiveMode class..." -ForegroundColor Yellow

try {
    $interactiveMode = [InteractiveMode]::new()
    Write-Host "✅ InteractiveMode class can be instantiated" -ForegroundColor Green
    
    # Check required methods
    $requiredMethods = @(
        'EnterMode',
        'HandleKeyPress', 
        'NavigateUp',
        'NavigateDown',
        'SelectItem',
        'QueueItem',
        'UpdateDisplay',
        'ExitMode'
    )
    
    $classMethods = $interactiveMode.GetType().GetMethods() | Where-Object { $_.DeclaringType.Name -eq 'InteractiveMode' } | ForEach-Object { $_.Name }
    
    foreach ($method in $requiredMethods) {
        if ($method -in $classMethods) {
            Write-Host "✅ InteractiveMode.$method method exists" -ForegroundColor Green
        } else {
            Write-Host "❌ InteractiveMode.$method method missing" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "❌ InteractiveMode class error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Check terminal capabilities function
Write-Host "Test 4: Checking terminal capabilities..." -ForegroundColor Yellow

try {
    $capabilities = Get-TerminalCapabilities
    Write-Host "✅ Get-TerminalCapabilities works" -ForegroundColor Green
    Write-Host "   Terminal Type: $($capabilities.TerminalType)" -ForegroundColor Gray
    Write-Host "   Supports Interactive Input: $($capabilities.SupportsInteractiveInput)" -ForegroundColor Gray
    Write-Host "   Supports Colors: $($capabilities.SupportsColors)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Get-TerminalCapabilities error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 5: Test help system includes interactive mode information
Write-Host "Test 5: Checking help system for interactive mode info..." -ForegroundColor Yellow

try {
    # Redirect help output to null and capture in variable
    $helpOutput = & { Get-SpotifyHelp *>&1 } | Out-String
    
    if ($helpOutput -like "*INTERACTIVE MODE:*") {
        Write-Host "✅ Help system includes interactive mode section" -ForegroundColor Green
    } else {
        Write-Host "❌ Help system missing interactive mode section" -ForegroundColor Red
        Write-Host "   (Help output length: $($helpOutput.Length) chars)" -ForegroundColor Gray
    }
    
    if ($helpOutput -like "*-Interactive*") {
        Write-Host "✅ Help system mentions -Interactive parameter" -ForegroundColor Green
    } else {
        Write-Host "❌ Help system missing -Interactive parameter info" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Help system test error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🏁 Interactive Mode Integration Test Complete" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 To test interactive mode manually:" -ForegroundColor Yellow
Write-Host "   1. Ensure you have valid Spotify credentials" -ForegroundColor Gray
Write-Host "   2. Run: search 'test' -Interactive" -ForegroundColor Gray
Write-Host "   3. Run: playlists -Interactive" -ForegroundColor Gray
Write-Host "   4. Run: Search-Albums 'test' -Interactive" -ForegroundColor Gray