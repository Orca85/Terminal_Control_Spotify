# Exempel på hur man implementerar lyrics med Genius API

function Get-LyricsFromGenius {
    param(
        [string]$Artist,
        [string]$Track
    )
    
    # Genius API kräver en API-nyckel (gratis att få)
    $geniusToken = $env:GENIUS_ACCESS_TOKEN
    
    if (-not $geniusToken) {
        Write-Host "❌ Genius API token saknas" -ForegroundColor Red
        Write-Host "💡 Sätt miljövariabel: `$env:GENIUS_ACCESS_TOKEN = 'din_token'" -ForegroundColor Yellow
        return $null
    }
    
    try {
        # Steg 1: Sök efter låten
        $searchQuery = "$Artist $Track"
        $searchUrl = "https://api.genius.com/search?q=$([System.Web.HttpUtility]::UrlEncode($searchQuery))"
        
        $headers = @{
            'Authorization' = "Bearer $geniusToken"
        }
        
        $searchResponse = Invoke-RestMethod -Uri $searchUrl -Headers $headers
        
        if ($searchResponse.response.hits.Count -eq 0) {
            Write-Host "❌ Ingen låt hittad på Genius" -ForegroundColor Red
            return $null
        }
        
        # Steg 2: Hämta lyrics URL
        $song = $searchResponse.response.hits[0].result
        $lyricsUrl = $song.url
        
        Write-Host "🎵 Hittade: $($song.full_title)" -ForegroundColor Green
        Write-Host "🔗 Lyrics URL: $lyricsUrl" -ForegroundColor Cyan
        
        # Steg 3: Scrapa lyrics från sidan (Genius API ger inte direkt lyrics)
        # Detta kräver web scraping vilket är mer komplext
        
        return @{
            Title = $song.title
            Artist = $song.primary_artist.name
            Url = $lyricsUrl
            Found = $true
        }
        
    } catch {
        Write-Host "❌ Fel vid hämtning från Genius: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Exempel på användning:
# $env:GENIUS_ACCESS_TOKEN = "din_genius_token_här"
# Get-LyricsFromGenius -Artist "Queen" -Track "Bohemian Rhapsody"