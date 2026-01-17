Import-Module SpotifyCommands -Force

Write-Host "🎵 Spotify CLI - Komplett Installation Verifierad" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ Tillgängliga Alias:" -ForegroundColor Green
$spotifyAliases = @('pl', 'pn', 'sp', 'help', 'vol', 'sh', 'rep', 'tr', 'q', 'slw', 'spotify', 'music', 'plays-now', 'spotify-help', 'ShowLyrics')

foreach ($alias in $spotifyAliases) {
    $aliasObj = Get-Alias $alias -ErrorAction SilentlyContinue
    if ($aliasObj) {
        Write-Host "  $alias -> $($aliasObj.Definition)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "📊 Totalt antal funktioner: $((Get-Command -Module SpotifyCommands -CommandType Function | Measure-Object).Count)" -ForegroundColor Cyan
