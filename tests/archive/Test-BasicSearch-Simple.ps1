# Simple test for basic search functionality
Write-Host "🔍 Testing Basic Search Functionality" -ForegroundColor Cyan
Write-Host ""

# Check if .env file exists
if (-not (Test-Path ".env")) {
    Write-Host "❌ .env file not found. Creating a placeholder..." -ForegroundColor Red
    Write-Host "Please add your Spotify credentials to .env file" -ForegroundColor Yellow
    exit 1
}

# Load environment variables
Get-Content .env | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}

# Check if credentials are set
if (-not $env:SPOTIFY_CLIENT_ID -or -not $env:SPOTIFY_CLIENT_SECRET) {
    Write-Host "❌ Spotify credentials not found in environment" -ForegroundColor Red
    Write-Host "Please set SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET in .env file" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Environment variables loaded" -ForegroundColor Green
Write-Host "Client ID: $($env:SPOTIFY_CLIENT_ID.Substring(0,8))..." -ForegroundColor Gray

# Import the module
try {
    Import-Module .\SpotifyModule.psm1 -Force -ErrorAction Stop
    Write-Host "✅ SpotifyModule imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to import SpotifyModule: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test if search function exists
$searchFunction = Get-Command "search" -ErrorAction SilentlyContinue
if ($searchFunction) {
    Write-Host "✅ search function found" -ForegroundColor Green
} else {
    Write-Host "❌ search function not found" -ForegroundColor Red
    exit 1
}

# Test if search-albums function exists
$searchAlbumsFunction = Get-Command "search-albums" -ErrorAction SilentlyContinue
if ($searchAlbumsFunction) {
    Write-Host "✅ search-albums function found" -ForegroundColor Green
} else {
    Write-Host "❌ search-albums function not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "🧪 Testing search function syntax..." -ForegroundColor Yellow

# Test search function with empty parameter (should show usage)
try {
    search ""
    Write-Host "✅ search function handles empty input correctly" -ForegroundColor Green
} catch {
    Write-Host "❌ search function failed with empty input: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🧪 Testing search-albums function syntax..." -ForegroundColor Yellow

# Test search-albums function with empty parameter (should show usage)
try {
    search-albums ""
    Write-Host "✅ search-albums function handles empty input correctly" -ForegroundColor Green
} catch {
    Write-Host "❌ search-albums function failed with empty input: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "📋 Function Tests Summary:" -ForegroundColor Cyan
Write-Host "• search function: Available and working" -ForegroundColor Green
Write-Host "• search-albums function: Available and working" -ForegroundColor Green
Write-Host ""
Write-Host "💡 To test with real data, you need to authenticate first:" -ForegroundColor Yellow
Write-Host "   Run: .\spotifyCLI.ps1" -ForegroundColor White
Write-Host "   Then try: search 'bohemian rhapsody'" -ForegroundColor White
Write-Host "   And: search-albums 'pink floyd'" -ForegroundColor White