function Find-SpotifyInstallation {
    <#
    .SYNOPSIS
    Comprehensive Spotify installation detection for different install types
    .OUTPUTS
    Hashtable with Found (bool), Path (string), and Type (string) properties
    #>
    
    # Define all possible Spotify installation paths and methods
    $installationMethods = @(
        @{
            Name = "User AppData Install"
            Path = "$env:APPDATA\Spotify\Spotify.exe"
            Type = "Standard User Install"
        },
        @{
            Name = "System Program Files"
            Path = "${env:ProgramFiles}\Spotify\Spotify.exe"
            Type = "System-wide Install"
        }
    )
    
    # Check traditional installation paths
    foreach ($method in $installationMethods) {
        if (Test-Path $method.Path) {
            Write-Verbose "Found Spotify via $($method.Name): $($method.Path)"
            return @{
                Found = $true
                Path = $method.Path
                Type = $method.Type
            }
        }
    }
    
    return @{
        Found = $false
        Path = $null
        Type = $null
    }
}

# Test the function
Write-Host "Testing Find-SpotifyInstallation..." -ForegroundColor Cyan
$result = Find-SpotifyInstallation
Write-Host "Found: $($result.Found)" -ForegroundColor $(if ($result.Found) { "Green" } else { "Red" })
if ($result.Found) {
    Write-Host "Path: $($result.Path)" -ForegroundColor Gray
    Write-Host "Type: $($result.Type)" -ForegroundColor Gray
}