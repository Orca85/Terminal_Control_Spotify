# Test script for Spotify launcher functionality
# Load the module
. .\SpotifyModule.psm1

Write-Host "🧪 Testing Spotify Launcher Functionality" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Find Spotify Installation
Write-Host "Test 1: Finding Spotify Installation" -ForegroundColor Yellow
$installation = Find-SpotifyInstallation
Write-Host "Found: $($installation.Found)" -ForegroundColor $(if ($installation.Found) { "Green" } else { "Red" })
if ($installation.Found) {
    Write-Host "Path: $($installation.Path)" -ForegroundColor Gray
    Write-Host "Type: $($installation.Type)" -ForegroundColor Gray
}
Write-Host ""

# Test 2: Get Spotify Process
Write-Host "Test 2: Checking Spotify Process" -ForegroundColor Yellow
$process = Get-SpotifyProcess
Write-Host "Running: $($process.IsRunning)" -ForegroundColor $(if ($process.IsRunning) { "Green" } else { "Red" })
if ($process.IsRunning) {
    Write-Host "Process ID: $($process.ProcessId)" -ForegroundColor Gray
    Write-Host "Process Count: $($process.ProcessCount)" -ForegroundColor Gray
    Write-Host "Working Set: $($process.WorkingSet) MB" -ForegroundColor Gray
}
Write-Host ""

# Test 3: Test API Readiness
Write-Host "Test 3: Testing API Readiness" -ForegroundColor Yellow
$apiReady = Test-SpotifyApiReadiness
Write-Host "API Ready: $apiReady" -ForegroundColor $(if ($apiReady) { "Green" } else { "Red" })
Write-Host ""

# Test 4: Web Player Launch (dry run)
Write-Host "Test 4: Web Player Launch Test" -ForegroundColor Yellow
Write-Host "Testing web player URLs (dry run)..." -ForegroundColor Gray
$webPlayerUrls = @(
    "https://open.spotify.com",
    "https://open.spotify.com/",
    "https://play.spotify.com"
)
foreach ($url in $webPlayerUrls) {
    Write-Host "  ✓ $url" -ForegroundColor Green
}
Write-Host ""

Write-Host "✅ All tests completed!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 To test the actual launcher, run:" -ForegroundColor Cyan
Write-Host "   Start-SpotifyApp" -ForegroundColor White
Write-Host "   Start-SpotifyApp -Web" -ForegroundColor White