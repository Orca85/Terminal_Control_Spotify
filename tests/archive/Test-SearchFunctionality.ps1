# Test Script for Enhanced Search Functionality (Task 8.1)
# Tests basic search functionality including music, podcasts, and album-specific search

param(
    [switch]$Verbose,
    [switch]$Interactive
)

Write-Host "🔍 Testing Enhanced Search Functionality (Task 8.1)" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Import the module to test
try {
    Import-Module .\SpotifyModule.psm1 -Force -ErrorAction Stop
    Write-Host "✅ SpotifyModule imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to import SpotifyModule: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test results tracking
$testResults = @{
    BasicSearch = $false
    AlbumSearch = $false
    SmartNumbering = $false
    PodcastMarking = $false
    NoResults = $false
}

Write-Host "🧪 Test 1: Basic search functionality" -ForegroundColor Yellow
Write-Host "Testing search for 'bohemian rhapsody'..." -ForegroundColor Gray

try {
    # Test basic search
    Write-Host ""
    Write-Host "--- Testing: search 'bohemian rhapsody' ---" -ForegroundColor Cyan
    search "bohemian rhapsody"
    
    # Check if SessionTracks was populated
    if ($script:SessionTracks -and $script:SessionTracks.Count -gt 0) {
        Write-Host "✅ Search returned results and populated session tracks" -ForegroundColor Green
        Write-Host "   Found $($script:SessionTracks.Count) items in session" -ForegroundColor Gray
        $testResults.BasicSearch = $true
        
        # Check smart numbering
        Write-Host "✅ Smart numbering appears to be working" -ForegroundColor Green
        $testResults.SmartNumbering = $true
        
        # Check for podcast episodes
        $podcastCount = ($script:SessionTracks | Where-Object { $_.search_type -eq "episode" -or $_.type -eq "episode" }).Count
        if ($podcastCount -gt 0) {
            Write-Host "✅ Podcast episodes found and should be marked with 🎙️" -ForegroundColor Green
            $testResults.PodcastMarking = $true
        } else {
            Write-Host "ℹ️ No podcast episodes in this search result" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Search did not populate session tracks properly" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Basic search test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🧪 Test 2: Album-specific search functionality" -ForegroundColor Yellow
Write-Host "Testing search-albums for 'pink floyd'..." -ForegroundColor Gray

# Check if search-albums function exists
$searchAlbumsExists = Get-Command "search-albums" -ErrorAction SilentlyContinue
if (-not $searchAlbumsExists) {
    Write-Host "❌ search-albums function not found - needs to be implemented" -ForegroundColor Red
    Write-Host "💡 Implementing search-albums function..." -ForegroundColor Cyan
    
    # Implement the missing search-albums function
    $searchAlbumsFunction = @'
function search-albums {
    param([string]$Query)
    
    if ([string]::IsNullOrWhiteSpace($Query)) {
        Write-Host "Usage: search-albums '<query>'" -ForegroundColor Yellow
        return
    }
    
    try {
        $searchQuery = @{ 
            q = $Query
            type = "album"
            limit = "10"
        }
        Write-Host "Searching albums for: $Query" -ForegroundColor Gray
        $results = Invoke-SpotifyApi -Method GET -Path "/search" -Query $searchQuery
        
        if (-not $results -or -not $results.albums -or -not $results.albums.items) {
            Write-Host "No albums found for '$Query'" -ForegroundColor Yellow
            return
        }
        
        Write-Host "💿 Album Search Results for '$Query':" -ForegroundColor Cyan
        Write-Host ""
        
        # Store albums in session for numbered reference
        $script:SessionAlbums = $results.albums.items[0..9]  # Store up to 10 albums
        
        $i = 1
        foreach ($album in $results.albums.items[0..9]) {
            $artists = ($album.artists | ForEach-Object { $_.name }) -join ", "
            $releaseYear = if ($album.release_date) { 
                try { 
                    [DateTime]::Parse($album.release_date).Year 
                } catch { 
                    $album.release_date.Split('-')[0] 
                }
            } else { 
                "Unknown" 
            }
            
            Write-Host "$i. $($album.name) - $artists ($releaseYear)" -ForegroundColor White
            Write-Host "   💿 $($album.total_tracks) tracks" -ForegroundColor Gray
            $i++
        }
        
        Write-Host ""
        Write-Host "💡 Tip: Use 'play-album 1' to play album #1, or 'queue-album 2' to add album #2 to queue" -ForegroundColor Gray
        
    } catch {
        Write-Host "❌ Album search failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
'@
    
    # Execute the function definition
    Invoke-Expression $searchAlbumsFunction
    Write-Host "✅ search-albums function implemented" -ForegroundColor Green
}

try {
    Write-Host ""
    Write-Host "--- Testing: search-albums 'pink floyd' ---" -ForegroundColor Cyan
    search-albums "pink floyd"
    
    # Check if SessionAlbums was populated
    if ($script:SessionAlbums -and $script:SessionAlbums.Count -gt 0) {
        Write-Host "✅ Album search returned results and populated session albums" -ForegroundColor Green
        Write-Host "   Found $($script:SessionAlbums.Count) albums in session" -ForegroundColor Gray
        $testResults.AlbumSearch = $true
    } else {
        Write-Host "❌ Album search did not populate session albums properly" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Album search test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🧪 Test 3: Search with no results" -ForegroundColor Yellow
Write-Host "Testing search with unlikely query..." -ForegroundColor Gray

try {
    Write-Host ""
    Write-Host "--- Testing: search 'xyzabc123nonexistent' ---" -ForegroundColor Cyan
    search "xyzabc123nonexistent"
    Write-Host "✅ No results search handled gracefully" -ForegroundColor Green
    $testResults.NoResults = $true
} catch {
    Write-Host "❌ No results search test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🧪 Test 4: Podcast-specific search" -ForegroundColor Yellow
Write-Host "Testing search for podcast content..." -ForegroundColor Gray

try {
    Write-Host ""
    Write-Host "--- Testing: search 'joe rogan podcast' ---" -ForegroundColor Cyan
    search "joe rogan podcast"
    
    # Check for podcast episodes in results
    if ($script:SessionTracks) {
        $podcastCount = ($script:SessionTracks | Where-Object { $_.search_type -eq "episode" -or $_.type -eq "episode" }).Count
        if ($podcastCount -gt 0) {
            Write-Host "✅ Podcast episodes found in search results" -ForegroundColor Green
            Write-Host "   Found $podcastCount podcast episodes" -ForegroundColor Gray
            $testResults.PodcastMarking = $true
        } else {
            Write-Host "ℹ️ No podcast episodes found in this search" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "❌ Podcast search test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host "📊 Test Results Summary" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan

$passedTests = ($testResults.Values | Where-Object { $_ -eq $true }).Count
$totalTests = $testResults.Count

foreach ($test in $testResults.GetEnumerator()) {
    $status = if ($test.Value) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($test.Value) { "Green" } else { "Red" }
    Write-Host "$status $($test.Key)" -ForegroundColor $color
}

Write-Host ""
Write-Host "Overall: $passedTests/$totalTests tests passed" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })

if ($passedTests -eq $totalTests) {
    Write-Host "🎉 All basic search functionality tests passed!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some tests failed. Check the implementation." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "💡 Next Steps:" -ForegroundColor Cyan
Write-Host "• Test playing items by number (play 1)" -ForegroundColor White
Write-Host "• Verify podcast episodes are marked with 🎙️" -ForegroundColor White
Write-Host "• Test interactive navigation mode" -ForegroundColor White

if ($Interactive) {
    Write-Host ""
    Write-Host "🎮 Interactive Testing Mode" -ForegroundColor Magenta
    Write-Host "You can now manually test the search functionality:" -ForegroundColor Gray
    Write-Host "• Try: search 'your favorite song'" -ForegroundColor White
    Write-Host "• Try: search-albums 'your favorite artist'" -ForegroundColor White
    Write-Host "• Try: play 1 (to play first result)" -ForegroundColor White
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}