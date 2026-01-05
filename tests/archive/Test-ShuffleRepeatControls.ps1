# Test Shuffle and Repeat Controls
# This script tests all shuffle and repeat functionality for Spotify CLI

Write-Host "🧪 Testing Shuffle and Repeat Controls" -ForegroundColor Cyan
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

Write-Host ""

# Test 1: Shuffle Function Existence
Write-Host "🔍 Test 1: Checking shuffle function..." -ForegroundColor Yellow
$shuffleFunction = Get-Command shuffle -ErrorAction SilentlyContinue
if ($shuffleFunction) {
    Write-Host "✅ 'shuffle' function exists" -ForegroundColor Green
} else {
    Write-Host "❌ 'shuffle' function not found" -ForegroundColor Red
}

# Test 2: Shuffle Alias (sh) Function Existence
Write-Host "🔍 Test 2: Checking shuffle alias..." -ForegroundColor Yellow
$shAlias = Get-Alias sh -ErrorAction SilentlyContinue
if ($shAlias) {
    Write-Host "✅ 'sh' alias exists and points to: $($shAlias.Definition)" -ForegroundColor Green
} else {
    Write-Host "❌ 'sh' alias not found" -ForegroundColor Red
}

# Test 3: Repeat Function Existence
Write-Host "🔍 Test 3: Checking repeat function..." -ForegroundColor Yellow
$repeatFunction = Get-Command repeat -ErrorAction SilentlyContinue
if ($repeatFunction) {
    Write-Host "✅ 'repeat' function exists" -ForegroundColor Green
} else {
    Write-Host "❌ 'repeat' function not found" -ForegroundColor Red
}

# Test 4: Repeat Alias (rep) Function Existence
Write-Host "🔍 Test 4: Checking repeat alias..." -ForegroundColor Yellow
$repAlias = Get-Alias rep -ErrorAction SilentlyContinue
if ($repAlias) {
    Write-Host "✅ 'rep' alias exists and points to: $($repAlias.Definition)" -ForegroundColor Green
} else {
    Write-Host "❌ 'rep' alias not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "📋 MANUAL TESTING REQUIRED" -ForegroundColor Magenta
Write-Host "The following tests require user interaction and a Spotify Premium account:" -ForegroundColor White
Write-Host ""

# Shuffle Tests
Write-Host "🔀 SHUFFLE CONTROL TESTS:" -ForegroundColor Cyan
Write-Host "1. Test shuffle on - Should enable shuffle mode" -ForegroundColor White
Write-Host "2. Test shuffle off - Should disable shuffle mode" -ForegroundColor White
Write-Host "3. Test shuffle toggle - Should toggle current shuffle state" -ForegroundColor White
Write-Host "4. Test sh on - Should enable shuffle (using alias)" -ForegroundColor White
Write-Host "5. Test sh off - Should disable shuffle (using alias)" -ForegroundColor White
Write-Host ""

# Repeat Tests
Write-Host "🔁 REPEAT CONTROL TESTS:" -ForegroundColor Cyan
Write-Host "1. Test repeat track - Should repeat current track" -ForegroundColor White
Write-Host "2. Test repeat context - Should repeat playlist/album" -ForegroundColor White
Write-Host "3. Test repeat off - Should disable repeat" -ForegroundColor White
Write-Host "4. Test rep track - Should repeat track (using alias)" -ForegroundColor White
Write-Host "5. Test rep context - Should repeat context (using alias)" -ForegroundColor White
Write-Host "6. Test rep off - Should disable repeat (using alias)" -ForegroundColor White
Write-Host ""

Write-Host "🎯 INTERACTIVE TESTING MENU" -ForegroundColor Green
Write-Host "Choose a test to run:" -ForegroundColor White
Write-Host "1. Test shuffle on" -ForegroundColor Gray
Write-Host "2. Test shuffle off" -ForegroundColor Gray
Write-Host "3. Test shuffle toggle" -ForegroundColor Gray
Write-Host "4. Test sh on (alias)" -ForegroundColor Gray
Write-Host "5. Test sh off (alias)" -ForegroundColor Gray
Write-Host "6. Test repeat track" -ForegroundColor Gray
Write-Host "7. Test repeat context" -ForegroundColor Gray
Write-Host "8. Test repeat off" -ForegroundColor Gray
Write-Host "9. Test rep track (alias)" -ForegroundColor Gray
Write-Host "10. Test rep context (alias)" -ForegroundColor Gray
Write-Host "11. Test rep off (alias)" -ForegroundColor Gray
Write-Host "12. Test all shuffle controls" -ForegroundColor Gray
Write-Host "13. Test all repeat controls" -ForegroundColor Gray
Write-Host "14. Exit" -ForegroundColor Gray
Write-Host ""

do {
    $choice = Read-Host "Enter your choice (1-14)"
    
    switch ($choice) {
        "1" {
            Write-Host ""
            Write-Host "🔀 Testing: shuffle on" -ForegroundColor Cyan
            try {
                shuffle on
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "2" {
            Write-Host ""
            Write-Host "➡️ Testing: shuffle off" -ForegroundColor Cyan
            try {
                shuffle off
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "3" {
            Write-Host ""
            Write-Host "🔄 Testing: shuffle toggle" -ForegroundColor Cyan
            try {
                shuffle toggle
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "4" {
            Write-Host ""
            Write-Host "🔀 Testing: sh on (alias)" -ForegroundColor Cyan
            try {
                sh on
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "5" {
            Write-Host ""
            Write-Host "➡️ Testing: sh off (alias)" -ForegroundColor Cyan
            try {
                sh off
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "6" {
            Write-Host ""
            Write-Host "🔂 Testing: repeat track" -ForegroundColor Cyan
            try {
                repeat track
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "7" {
            Write-Host ""
            Write-Host "🔁 Testing: repeat context" -ForegroundColor Cyan
            try {
                repeat context
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "8" {
            Write-Host ""
            Write-Host "➡️ Testing: repeat off" -ForegroundColor Cyan
            try {
                repeat off
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "9" {
            Write-Host ""
            Write-Host "🔂 Testing: rep track (alias)" -ForegroundColor Cyan
            try {
                rep track
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "10" {
            Write-Host ""
            Write-Host "🔁 Testing: rep context (alias)" -ForegroundColor Cyan
            try {
                rep context
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "11" {
            Write-Host ""
            Write-Host "➡️ Testing: rep off (alias)" -ForegroundColor Cyan
            try {
                rep off
                Write-Host "✅ Command executed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        "12" {
            Write-Host ""
            Write-Host "🔀 Testing all shuffle controls..." -ForegroundColor Cyan
            
            $shuffleTests = @(
                @{ Command = "shuffle on"; Description = "Enable shuffle" },
                @{ Command = "shuffle off"; Description = "Disable shuffle" },
                @{ Command = "sh on"; Description = "Enable shuffle (alias)" },
                @{ Command = "sh off"; Description = "Disable shuffle (alias)" },
                @{ Command = "shuffle toggle"; Description = "Toggle shuffle state" }
            )
            
            foreach ($test in $shuffleTests) {
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
        
        "13" {
            Write-Host ""
            Write-Host "🔁 Testing all repeat controls..." -ForegroundColor Cyan
            
            $repeatTests = @(
                @{ Command = "repeat track"; Description = "Repeat current track" },
                @{ Command = "repeat context"; Description = "Repeat playlist/album" },
                @{ Command = "repeat off"; Description = "Disable repeat" },
                @{ Command = "rep track"; Description = "Repeat track (alias)" },
                @{ Command = "rep context"; Description = "Repeat context (alias)" },
                @{ Command = "rep off"; Description = "Disable repeat (alias)" }
            )
            
            foreach ($test in $repeatTests) {
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
        
        "14" {
            Write-Host "Exiting test script..." -ForegroundColor Gray
            break
        }
        
        default {
            Write-Host "Invalid choice. Please enter 1-14." -ForegroundColor Red
        }
    }
} while ($choice -ne "14")

Write-Host ""
Write-Host "🏁 Shuffle and Repeat Control Testing Complete" -ForegroundColor Green
Write-Host ""
Write-Host "📝 REQUIREMENTS VERIFICATION:" -ForegroundColor Cyan
Write-Host "Requirements 5.5-5.9 should be verified by manual testing:" -ForegroundColor White
Write-Host "✓ 5.5: shuffle on/off commands control shuffle mode" -ForegroundColor Gray
Write-Host "✓ 5.6: sh alias works for shuffle commands" -ForegroundColor Gray
Write-Host "✓ 5.7: repeat track/context/off commands control repeat mode" -ForegroundColor Gray
Write-Host "✓ 5.8: rep alias works for repeat commands" -ForegroundColor Gray
Write-Host "✓ 5.9: State changes are applied correctly to Spotify" -ForegroundColor Gray
Write-Host ""
Write-Host "💡 Note: These tests require:" -ForegroundColor Yellow
Write-Host "• Active Spotify authentication" -ForegroundColor White
Write-Host "• Spotify Premium account (for playback control)" -ForegroundColor White
Write-Host "• Active playback on a Spotify device" -ForegroundColor White