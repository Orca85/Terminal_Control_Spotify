Import-Module SpotifyCommands -Force

Write-Host "✅ Module loaded with NestedModules approach" -ForegroundColor Green
Write-Host ""

$funcs = Get-Command -Module SpotifyCommands -CommandType Function
$aliases = Get-Command -Module SpotifyCommands -CommandType Alias

Write-Host "Functions: $($funcs.Count)" -ForegroundColor Cyan
Write-Host "Aliases: $($aliases.Count)" -ForegroundColor Cyan
Write-Host ""

Write-Host "Testing key aliases:" -ForegroundColor Yellow
$testAliases = @('pl', 'pn', 'slw', 'help', 'sp')
foreach ($alias in $testAliases) {
    $aliasObj = Get-Alias $alias -ErrorAction SilentlyContinue
    if ($aliasObj) {
        Write-Host "  ✅ $alias -> $($aliasObj.Definition)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $alias NOT FOUND" -ForegroundColor Red
    }
}
