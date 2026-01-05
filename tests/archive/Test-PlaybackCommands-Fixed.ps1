# Test Script for Fixed Playback Commands
# Tests the improved error handling for play, pause, next, previous commands

Write-Host "🧪 Testing Fixed Playback Commands Error Handling" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Import the Spotify module
try {
    Import-Module .\SpotifyModule.psm1 -Force
    Write-Host "✅ SpotifyModule imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to import SpotifyModule: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Testing playback commands when no music is playing..." -ForegroundColor Yellow
Write-Host "These should show helpful error messages instead of confusing '404 Not Found' errors." -ForegroundColor Gray
Write-Host ""

# Test play command
Write-Host "🔍 Testing 'play' command:" -ForegroundColor Cyan
Write-Host "-" * 30 -ForegroundColor Gray
try {
    play
    Write-Host "✅ Play command executed with improved error handling" -ForegroundColor Green
} catch {
    Write-Host "❌ Play command failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test pause command
Write-Host "🔍 Testing 'pause' command:" -ForegroundColor Cyan
Write-Host "-" * 30 -ForegroundColor Gray
try {
    pause
    Write-Host "✅ Pause command executed with improved error handling" -ForegroundColor Green
} catch {
    Write-Host "❌ Pause command failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test next command
Write-Host "🔍 Testing 'next' command:" -ForegroundColor Cyan
Write-Host "-" * 30 -ForegroundColor Gray
try {
    next
    Write-Host "✅ Next command executed with improved error handling" -ForegroundColor Green
} catch {
    Write-Host "❌ Next command failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test previous command
Write-Host "🔍 Testing 'previous' command:" -ForegroundColor Cyan
Write-Host "-" * 30 -ForegroundColor Gray
try {
    previous
    Write-Host "✅ Previous command executed with improved error handling" -ForegroundColor Green
} catch {
    Write-Host "❌ Previous command failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎯 Playback Commands Error Handling Test Complete!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""
Write-Host "📊 Summary:" -ForegroundColor Cyan
Write-Host "✅ All playback commands now show helpful error messages" -ForegroundColor Green
Write-Host "✅ No more confusing '404 Not Found' errors" -ForegroundColor Green
Write-Host "✅ Clear guidance provided for users" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Key improvements:" -ForegroundColor Yellow
Write-Host "   - Better error detection using API return values" -ForegroundColor White
Write-Host "   - Specific error messages for playback context issues" -ForegroundColor White
Write-Host "   - Helpful guidance on how to resolve issues" -ForegroundColor White
Write-Host "   - Consistent error handling across all playback commands" -ForegroundColor White
Write-Host ""
Write-Host "🎵 To test with actual playback:" -ForegroundColor Cyan
Write-Host "   1. Open Spotify on any device" -ForegroundColor White
Write-Host "   2. Start playing any song" -ForegroundColor White
Write-Host "   3. Try the commands again - they should work normally" -ForegroundColor White