try {
    Import-Module 'C:\Users\tommy\Documents\PowerShell\Modules\SpotifyCommands\modules\Core\ApiClientManager.psm1' -Force -ErrorAction Stop
    Write-Host "✅ ApiClientManager loaded successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ Error loading ApiClientManager:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
