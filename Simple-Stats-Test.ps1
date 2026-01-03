# Simple test for stats command
try {
    # Source the module directly
    . .\SpotifyModule.psm1
    
    Write-Host "Testing stats command..." -ForegroundColor Cyan
    
    # Check if function exists
    if (Get-Command Get-SpotifyStats -ErrorAction SilentlyContinue) {
        Write-Host "✅ Get-SpotifyStats function found" -ForegroundColor Green
        
        # Test the command
        Get-SpotifyStats -Period day
        
    } else {
        Write-Host "❌ Get-SpotifyStats function not found" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}