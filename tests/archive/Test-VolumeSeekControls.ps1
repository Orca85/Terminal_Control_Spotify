# Test Volume and Seek Controls
# This script tests all volume and seek functionality for Spotify CLI

Write-Host "🧪 Testing Volume and Seek Controls" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Import the module to test
try {
    Import-Module .\SpotifyModule.psm1 -Force -ErrorAction Stop
    Write-Host "✅ SpotifyModule imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to import SpotifyModule: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 1: Volume Control Function Existence
Write-Host "🔍 Test 1: Checking volume control function..." -ForegroundColor Yellow
$volumeFunction = Get-Command volume -ErrorAction SilentlyContinue
if ($volumeFunction) {
    Write-Host "✅ 'volume' function exists" -ForegroundColor Green
} else {
    Write-Host "❌ 'volume' function not found" -ForegroundColor Red
}

# Test 2: Volume Alias (vol) Function Existence
Write-Host "🔍 Test 2: Checking volume alias..." -ForegroundColor Yellow
$volAlias = Get-Alias vol -ErrorAction SilentlyContinue
if ($volAlias) {
    Write-Host "✅ 'vol' alias exists and points to: $($volAlias.Definition)" -ForegroundColor Green
} else {
    Write-Host "❌ 'vol' alias not found" -ForegroundColor Red
}

# Test 3: Seek Function Existence
Write-Host "🔍 Test 3: Checking seek function..." -ForegroundColor Yellow
$seekFunction = Get-Command seek -ErrorAction SilentlyContinue
if ($seekFunction) {
    Write-Host "✅ 'seek' function exists" -ForegroundColor Green
} else {
    Write-Host "❌ 'seek' function not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "📋 MANUAL TESTING REQUIRED" -ForegroundColor Magenta
Write-Host "The following tests require user interaction and a Spotify Premium account:" -ForegroundColor White
Write-Host ""

# Volume Tests
Write-Host "🔊 VOLUME CONTROL TESTS:" -ForegroundColor Cyan
Write-Host "1. Test volume 75 - Should set volume to 75%" -ForegroundColor White
Write-Host "2. Test vol 50 - Should set volume to 50% (using alias)" -ForegroundColor White
Write-Host "3. Test volume 0 - Should mute (set to 0%)" -ForegroundColor White
Write-Host "4. Test volume 100 - Should set to maximum volume" -ForegroundColor White
Write-Host "5. Test volume 150 - Should show error (invalid range)" -ForegroundColor White
Write-Host "6. Test volume -10 - Should show error (invalid range)" -ForegroundColor White
Write-Host ""

# Seek Tests
Write-Host "⏩ SEEK CONTROL TESTS:" -ForegroundColor Cyan
Write-Host "1. Test seek 30 - Should seek forward 30 seconds" -ForegroundColor White
Write-Host "2. Test seek -15 - Should seek backward 15 seconds" -ForegroundColor White
Write-Host "3. Test seek 0 - Should stay at current position" -ForegroundColor White
Write-Host "4. Test seek with no track playing - Should show error" -ForegroundColor White
Write-Host ""

Write-Host "🎯 INTERACTIVE TESTING MENU" -ForegroundColor Green
Write-Host "Choose a test to run:" -ForegroundColor White
Write-Host "1. Test volume 75" -ForegroundColor Gray
Write-Host "2. Test vol 50 (alias)" -ForegroundColor Gray
Write-Host "3. Test volume parameter validation" -ForegroundColor Gray
Write-Host "4. Test seek 30 (forward)" -ForegroundColor Gray
Write-Host "5. Test seek -15 (backward)" -ForegroundColor Gray
Write-Host "6. Test all volume controls" -ForegroundColor Gray
Write-Host "7. Test all seek controls" -ForegroundColor Gray
Write-Host "8. Exit" -ForegroundColor Gray
Write-Host ""

do {
    $choice = Read-Host "Enter your choice (1-8)"
    
    switch ($choice) {
        "1" {
            Write-Host ""
            Write-Host "🔊 Testing: volume 75" -ForegroundColor Cyan
            try {
                volume 75
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "2" {
            Write-Host ""
            Write-Host "🔊 Testing: vol 50 (alias)" -ForegroundColor Cyan
            try {
                vol 50
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "3" {
            Write-Host ""
            Write-Host "🔊 Testing volume parameter validation..." -ForegroundColor Cyan
            
            Write-Host "Testing volume 150 (should fail):" -ForegroundColor Yellow
            try {
                volume 150
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            Write-Host "Testing volume -10 (should fail):" -ForegroundColor Yellow
            try {
                volume -10
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            Write-Host "Testing volume 0 (should work):" -ForegroundColor Yellow
            try {
                volume 0
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            Write-Host "Testing volume 100 (should work):" -ForegroundColor Yellow
            try {
                volume 100
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "4" {
            Write-Host ""
            Write-Host "⏩ Testing: seek 30 (forward)" -ForegroundColor Cyan
            try {
                seek 30
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "5" {
            Write-Host ""
            Write-Host "⏪ Testing: seek -15 (backward)" -ForegroundColor Cyan
            try {
                seek -15
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "6" {
            Write-Host ""
            Write-Host "🔊 Testing all volume controls..." -ForegroundColor Cyan
            
            $volumeTests = @(
                @{ Command = "volume 25"; Description = "Set volume to 25%" },
                @{ Command = "vol 50"; Description = "Set volume to 50% (alias)" },
                @{ Command = "volume 75"; Description = "Set volume to 75%" },
                @{ Command = "volume 100"; Description = "Set volume to 100%" }
            )
            
            foreach ($test in $volumeTests) {
                Write-Host "Testing: $($test.Command) - $($test.Description)" -ForegroundColor Yellow
                try {
                    Invoke-Expression $test.Command
                    Write-Host "✅ Success" -ForegroundColor Green
                    Start-Sleep -Seconds 2  # Wait between tests
                } catch {
                    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                }
                Write-Host ""
            }
        }
        
        "7" {
            Write-Host ""
            Write-Host "⏩ Testing all seek controls..." -ForegroundColor Cyan
            
            $seekTests = @(
                @{ Command = "seek 10"; Description = "Seek forward 10 seconds" },
                @{ Command = "seek -5"; Description = "Seek backward 5 seconds" },
                @{ Command = "seek 30"; Description = "Seek forward 30 seconds" },
                @{ Command = "seek -15"; Description = "Seek backward 15 seconds" }
            )
            
            foreach ($test in $seekTests) {
                Write-Host "Testing: $($test.Command) - $($test.Description)" -ForegroundColor Yellow
                try {
                    Invoke-Expression $test.Command
                    Write-Host "✅ Success" -ForegroundColor Green
                    Start-Sleep -Seconds 2  # Wait between tests
                } catch {
                    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                }
                Write-Host ""
            }
        }
        
        "8" {
            Write-Host "Exiting test script..." -ForegroundColor Gray
            break
        }
        
        default {
            Write-Host "Invalid choice. Please enter 1-8." -ForegroundColor Red
        }
    }
} while ($choice -ne "8")

Write-Host ""
Write-Host "🏁 Volume and Seek Control Testing Complete" -ForegroundColor Green
Write-Host ""
Write-Host "📝 REQUIREMENTS VERIFICATION:" -ForegroundColor Cyan
Write-Host "Requirements 5.1-5.4 should be verified by manual testing:" -ForegroundColor White
Write-Host "✓ 5.1: volume 75 command sets volume to 75%" -ForegroundColor Gray
Write-Host "✓ 5.2: vol 50 command (alias) sets volume to 50%" -ForegroundColor Gray
Write-Host "✓ 5.3: seek 30 command seeks forward 30 seconds" -ForegroundColor Gray
Write-Host "✓ 5.4: seek -15 command seeks backward 15 seconds" -ForegroundColor Gray
Write-Host ""
Write-Host "💡 Note: These tests require:" -ForegroundColor Yellow
Write-Host "• Active Spotify authentication" -ForegroundColor White
Write-Host "• Spotify Premium account (for volume/seek control)" -ForegroundColor White
Write-Host "• Active playback on a Spotify device" -ForegroundColor White