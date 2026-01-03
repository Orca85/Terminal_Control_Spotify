# Test script for Spotify Application Launcher (Task 3.1)
# Tests launching Spotify when not running, detection when already running, and different installation paths

param(
    [switch]$Verbose,
    [switch]$SkipLaunch
)

Write-Host "🧪 Testing Spotify Application Launcher" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Import the module to test
try {
    Import-Module .\SpotifyModule.psm1 -Force -ErrorAction Stop
    Write-Host "✅ SpotifyModule imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to import SpotifyModule: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 1: Check if Spotify is currently running
Write-Host "Test 1: Checking current Spotify process status" -ForegroundColor Yellow
$spotifyProcess = Get-Process -Name "Spotify" -ErrorAction SilentlyContinue
if ($spotifyProcess) {
    Write-Host "✅ Spotify is currently running (PID: $($spotifyProcess.Id))" -ForegroundColor Green
    $wasRunning = $true
} else {
    Write-Host "ℹ️ Spotify is not currently running" -ForegroundColor Cyan
    $wasRunning = $false
}
Write-Host ""

# Test 2: Check Spotify installation paths
Write-Host "Test 2: Checking Spotify installation paths" -ForegroundColor Yellow
$spotifyPaths = @(
    "$env:APPDATA\Spotify\Spotify.exe",
    "${env:ProgramFiles}\Spotify\Spotify.exe", 
    "${env:ProgramFiles(x86)}\Spotify\Spotify.exe"
)

$foundPaths = @()
foreach ($path in $spotifyPaths) {
    if (Test-Path $path) {
        Write-Host "✅ Found Spotify at: $path" -ForegroundColor Green
        $foundPaths += $path
    } else {
        Write-Host "❌ Not found: $path" -ForegroundColor Red
    }
}

if ($foundPaths.Count -eq 0) {
    Write-Host "⚠️ No desktop Spotify installation found in common paths" -ForegroundColor Yellow
    Write-Host "💡 Will test Windows Store version and protocol handlers" -ForegroundColor Cyan
} else {
    Write-Host "✅ Found $($foundPaths.Count) Spotify installation(s)" -ForegroundColor Green
}
Write-Host ""

# Test 3: Test the spotify command mapping
Write-Host "Test 3: Testing 'spotify' command mapping" -ForegroundColor Yellow
$spotifyCommand = Get-Command "spotify" -ErrorAction SilentlyContinue
if ($spotifyCommand) {
    Write-Host "✅ 'spotify' command is available" -ForegroundColor Green
    Write-Host "   Command Type: $($spotifyCommand.CommandType)" -ForegroundColor Gray
    Write-Host "   Source: $($spotifyCommand.Source)" -ForegroundColor Gray
    
    # Check what the spotify command actually does
    $spotifyFunction = Get-Content Function:\spotify -ErrorAction SilentlyContinue
    if ($spotifyFunction -like "*Show-SpotifyTrack*") {
        Write-Host "❌ ISSUE: 'spotify' command calls Show-SpotifyTrack instead of Start-SpotifyApp" -ForegroundColor Red
        Write-Host "   Expected: Should launch Spotify app" -ForegroundColor Yellow
        Write-Host "   Actual: Shows current track" -ForegroundColor Yellow
    } elseif ($spotifyFunction -like "*Start-SpotifyApp*") {
        Write-Host "✅ 'spotify' command correctly calls Start-SpotifyApp" -ForegroundColor Green
    } else {
        Write-Host "⚠️ 'spotify' command implementation unclear" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ 'spotify' command not found" -ForegroundColor Red
}
Write-Host ""

# Test 4: Test Start-SpotifyApp function availability
Write-Host "Test 4: Testing Start-SpotifyApp function" -ForegroundColor Yellow
$startSpotifyCommand = Get-Command "Start-SpotifyApp" -ErrorAction SilentlyContinue
if ($startSpotifyCommand) {
    Write-Host "✅ Start-SpotifyApp function is available" -ForegroundColor Green
} else {
    Write-Host "❌ Start-SpotifyApp function not found" -ForegroundColor Red
}
Write-Host ""

# Test 5: Test Spotify detection when already running (if it was running)
if ($wasRunning) {
    Write-Host "Test 5: Testing detection of already running Spotify" -ForegroundColor Yellow
    try {
        Write-Host "Calling Start-SpotifyApp..." -ForegroundColor Gray
        Start-SpotifyApp
        Write-Host "✅ Start-SpotifyApp handled already running Spotify correctly" -ForegroundColor Green
    } catch {
        Write-Host "❌ Start-SpotifyApp failed with already running Spotify: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test 6: Test launching Spotify when not running (only if not skipped and not already running)
if (-not $SkipLaunch -and -not $wasRunning) {
    Write-Host "Test 6: Testing Spotify launch when not running" -ForegroundColor Yellow
    Write-Host "⚠️ This will attempt to launch Spotify" -ForegroundColor Yellow
    
    $response = Read-Host "Continue with launch test? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        try {
            Write-Host "Calling Start-SpotifyApp..." -ForegroundColor Gray
            Start-SpotifyApp
            
            # Wait a moment and check if Spotify started
            Start-Sleep -Seconds 3
            $newSpotifyProcess = Get-Process -Name "Spotify" -ErrorAction SilentlyContinue
            if ($newSpotifyProcess) {
                Write-Host "✅ Spotify launched successfully (PID: $($newSpotifyProcess.Id))" -ForegroundColor Green
            } else {
                Write-Host "⚠️ Spotify may still be starting up or launch failed" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "❌ Start-SpotifyApp failed to launch Spotify: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "⏭️ Skipping launch test" -ForegroundColor Gray
    }
    Write-Host ""
}

# Test 7: Test Windows Store version detection
Write-Host "Test 7: Testing Windows Store version support" -ForegroundColor Yellow
try {
    # Test if spotify: protocol is registered
    $protocolTest = Start-Process "spotify:" -PassThru -WindowStyle Hidden -ErrorAction Stop
    if ($protocolTest) {
        $protocolTest.Kill()
        Write-Host "✅ Spotify protocol (spotify:) is registered" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Spotify protocol (spotify:) not available: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 8: Test error handling for missing Spotify
Write-Host "Test 8: Testing error handling (simulated)" -ForegroundColor Yellow
Write-Host "ℹ️ This would test behavior when Spotify is not installed" -ForegroundColor Cyan
Write-Host "   - Should provide clear error message" -ForegroundColor Gray
Write-Host "   - Should suggest installation from https://spotify.com" -ForegroundColor Gray
Write-Host "   - Should offer web player alternative" -ForegroundColor Gray
Write-Host ""

# Summary
Write-Host "🏁 Test Summary" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan

$issues = @()
if (-not $spotifyCommand) {
    $issues += "spotify command not available"
}
if ($spotifyFunction -like "*Show-SpotifyTrack*") {
    $issues += "spotify command mapped incorrectly (shows track instead of launching app)"
}
if (-not $startSpotifyCommand) {
    $issues += "Start-SpotifyApp function not available"
}
if ($foundPaths.Count -eq 0) {
    $issues += "No desktop Spotify installation detected"
}

if ($issues.Count -eq 0) {
    Write-Host "✅ All basic tests passed" -ForegroundColor Green
} else {
    Write-Host "❌ Issues found:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "   • $issue" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "💡 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Fix spotify command mapping to call Start-SpotifyApp" -ForegroundColor White
Write-Host "   2. Enhance error handling for missing installations" -ForegroundColor White
Write-Host "   3. Add better detection for Windows Store version" -ForegroundColor White
Write-Host "   4. Test with different installation scenarios" -ForegroundColor White