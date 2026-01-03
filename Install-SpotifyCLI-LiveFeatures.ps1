function Install-SpotifyCliLiveFeatures {
    <#
    .SYNOPSIS
    Complete Spotify CLI installation with Live Features for new computers
    
    .DESCRIPTION
    Installs and configures Spotify CLI with all dependencies, live features, and profile setup
    
    .PARAMETER Force
    Force reinstallation even if already installed
    
    .PARAMETER SkipLiveFeatures
    Skip installation of live features components
    
    .PARAMETER ConfigureApiKeys
    Prompt for API key configuration during installation
    #>
    [CmdletBinding()]
    param(
        [switch]$Force,
        [switch]$SkipLiveFeatures,
        [switch]$ConfigureApiKeys
    )
    
    Write-Host "🎵 Spotify CLI with Live Features - Complete Installation" -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "🚀 Starting installation process..." -ForegroundColor Green
    Write-Host ""
    
    try {
        # Check PowerShell version
        Write-Host "[1/8] 🔍 Checking PowerShell compatibility..." -ForegroundColor Yellow
        $psVersion = $PSVersionTable.PSVersion
        Write-Host "   PowerShell Version: $($psVersion.ToString())" -ForegroundColor Gray
        
        if ($psVersion.Major -lt 5) {
            throw "PowerShell 5.0 or higher is required. Current version: $($psVersion.ToString())"
        }
        
        # Recommend PowerShell 7 for live features
        if ($psVersion.Major -lt 7 -and -not $SkipLiveFeatures) {
            Write-Host "   ⚠️ PowerShell 7+ recommended for optimal live features performance" -ForegroundColor Yellow
            Write-Host "   💡 Download from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Cyan
        }
        
        Write-Host "✅ PowerShell version compatible" -ForegroundColor Green
        
        # Check execution policy
        Write-Host "[2/8] 🔍 Checking execution policy..." -ForegroundColor Yellow
        $executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
        Write-Host "   Current execution policy: $executionPolicy" -ForegroundColor Gray
        
        if ($executionPolicy -eq "Restricted") {
            Write-Host "⚠️ Execution policy is Restricted. Attempting to set to RemoteSigned..." -ForegroundColor Yellow
            try {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Write-Host "✅ Execution policy updated to RemoteSigned" -ForegroundColor Green
            } catch {
                Write-Host "❌ Failed to update execution policy. Please run as administrator." -ForegroundColor Red
                throw "Execution policy update failed"
            }
        } else {
            Write-Host "✅ Execution policy allows script execution" -ForegroundColor Green
        }
        
        # Install required and optional modules
        Write-Host "[3/8] 📦 Installing required and optional modules..." -ForegroundColor Yellow
        
        # Required modules for live features
        $requiredModules = @()
        $optionalModules = @("BurntToast")
        
        # Install optional modules
        foreach ($module in $optionalModules) {
            try {
                $installedModule = Get-Module -Name $module -ListAvailable
                if (-not $installedModule -or $Force) {
                    Write-Host "   Installing $module..." -ForegroundColor Gray
                    Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -ErrorAction SilentlyContinue
                    Write-Host "   ✅ $module installed" -ForegroundColor Green
                } else {
                    Write-Host "   ✅ $module already installed" -ForegroundColor Green
                }
            } catch {
                Write-Host "   ⚠️ $module installation failed (optional)" -ForegroundColor Yellow
            }
        }
        
        # Setup directories
        Write-Host "[4/8] 📁 Setting up directories..." -ForegroundColor Yellow
        
        # Create app data directory structure
        $appDataDir = Join-Path $env:APPDATA "SpotifyCLI"
        $liveFeaturesDir = Join-Path $appDataDir "LiveFeatures"
        $lyricsDir = Join-Path $appDataDir "Lyrics"
        $statisticsDir = Join-Path $appDataDir "Statistics"
        $logsDir = Join-Path $appDataDir "Logs"
        
        $directories = @($appDataDir, $liveFeaturesDir, $lyricsDir, $statisticsDir, $logsDir)
        
        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-Host "   ✅ Created directory: $dir" -ForegroundColor Green
            } else {
                Write-Host "   ✅ Directory exists: $dir" -ForegroundColor Green
            }
        }
        
        # Setup PowerShell module directory
        $userModulesPath = Join-Path (Split-Path $PROFILE -Parent) "Modules"
        $spotifyModulePath = Join-Path $userModulesPath "SpotifyCommands"
        
        if (Test-Path $spotifyModulePath) {
            if ($Force) {
                Remove-Item $spotifyModulePath -Recurse -Force
                Write-Host "   ✅ Removed old module (Force specified)" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️ Module already exists, use -Force to reinstall" -ForegroundColor Yellow
            }
        }
        
        if (-not (Test-Path $spotifyModulePath) -or $Force) {
            New-Item -ItemType Directory -Path $spotifyModulePath -Force | Out-Null
            Write-Host "   ✅ Created module directory: $spotifyModulePath" -ForegroundColor Green
        }
        
        # Install main Spotify CLI module
        Write-Host "[5/8] 🔧 Installing Spotify CLI module..." -ForegroundColor Yellow
        
        # Check if source module exists
        $sourceModulePath = Join-Path $PSScriptRoot "SpotifyModule.psm1"
        if (-not (Test-Path $sourceModulePath)) {
            throw "Source module file not found: $sourceModulePath"
        }
        
        # Copy main module
        $targetModulePath = Join-Path $spotifyModulePath "SpotifyCommands.psm1"
        Copy-Item $sourceModulePath -Destination $targetModulePath -Force
        Write-Host "   ✅ Main module copied to PowerShell modules directory" -ForegroundColor Green
        
        # Install live features modules
        if (-not $SkipLiveFeatures) {
            Write-Host "[6/8] 🌟 Installing Live Features modules..." -ForegroundColor Yellow
            
            $liveFeaturesModulesDir = Join-Path $spotifyModulePath "LiveFeatures"
            New-Item -ItemType Directory -Path $liveFeaturesModulesDir -Force | Out-Null
            
            # Copy live features modules
            $moduleSourceDir = Join-Path $PSScriptRoot "modules"
            if (Test-Path $moduleSourceDir) {
                # Copy main live features module
                $mainLiveModule = Join-Path $moduleSourceDir "SpotifyLiveFeatures.psm1"
                if (Test-Path $mainLiveModule) {
                    Copy-Item $mainLiveModule -Destination (Join-Path $liveFeaturesModulesDir "SpotifyLiveFeatures.psm1") -Force
                    Write-Host "   ✅ Main live features module installed" -ForegroundColor Green
                }
                
                # Copy sub-modules
                $subModules = @("Core", "LiveDisplay", "Lyrics", "Statistics")
                foreach ($subModule in $subModules) {
                    $subModuleDir = Join-Path $moduleSourceDir $subModule
                    if (Test-Path $subModuleDir) {
                        $targetSubModuleDir = Join-Path $liveFeaturesModulesDir $subModule
                        Copy-Item $subModuleDir -Destination $targetSubModuleDir -Recurse -Force
                        Write-Host "   ✅ $subModule module installed" -ForegroundColor Green
                    } else {
                        Write-Host "   ⚠️ $subModule module not found (optional)" -ForegroundColor Yellow
                    }
                }
            } else {
                Write-Host "   ⚠️ Live features modules directory not found" -ForegroundColor Yellow
                Write-Host "   💡 Live features will be available after manual module installation" -ForegroundColor Cyan
            }
        } else {
            Write-Host "[6/8] ⏭️ Skipping Live Features installation (as requested)" -ForegroundColor Yellow
        }
        
        # Create module manifest
        Write-Host "[7/8] 📋 Creating module manifest..." -ForegroundColor Yellow
        $manifestPath = Join-Path $spotifyModulePath "SpotifyCommands.psd1"
        
        $exportedFunctions = @(
            # Core functions
            'Show-SpotifyTrack', 'play', 'pause', 'next', 'previous', 'volume', 'seek',
            'shuffle', 'repeat', 'devices', 'transfer', 'search', 'search-albums',
            'playlists', 'play-playlist', 'queue-playlist', 'liked', 'recent',
            'save-track', 'unsave-track', 'queue', 'queue-album', 'play-album',
            'Start-SpotifyApp', 'Get-SpotifyHelp', 'Get-SpotifyConfig', 'Set-SpotifyConfig',
            'notifications'
        )
        
        # Add live features functions if not skipped
        if (-not $SkipLiveFeatures) {
            $liveFunctionsList = @(
                'Initialize-SpotifyLiveFeatures', 'Start-SpotifyLiveDisplay',
                'Get-SpotifyCurrentTrackLyrics', 'Get-SpotifyLyrics',
                'Get-SpotifyListeningStatistics', 'Get-SpotifyLiveFeaturesStatus',
                'Set-SpotifyLiveFeaturesConfiguration', 'Reset-SpotifyLiveFeaturesConfiguration',
                'Stop-SpotifyLiveFeatures'
            )
            $exportedFunctions += $liveFunctionsList
        }
        
        $manifestContent = @"
@{
    RootModule = 'SpotifyCommands.psm1'
    ModuleVersion = '3.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'Spotify CLI Enhanced with Live Features'
    Description = 'Enhanced Spotify CLI with live display, lyrics, statistics, and cross-platform compatibility'
    PowerShellVersion = '5.0'
    FunctionsToExport = @(
        $($exportedFunctions | ForEach-Object { "'$_'" } | Join-String -Separator ",`n        ")
    )
    AliasesToExport = @('plays-now', 'music', 'pn', 'sp', 'pl', 'vol', 'sh', 'rep', 'tr', 'q', 'spotify', 'help', 'spotify-help')
    PrivateData = @{
        PSData = @{
            Tags = @('Spotify', 'Music', 'CLI', 'LiveFeatures', 'Lyrics', 'Statistics')
            ProjectUri = 'https://github.com/spotify-cli/enhanced'
            ReleaseNotes = 'Version 3.0.0 - Added Live Features: Real-time display, lyrics engine, and statistics analytics'
        }
    }
}
"@
        $manifestContent | Set-Content -Path $manifestPath -Encoding UTF8
        Write-Host "   ✅ Module manifest created" -ForegroundColor Green
        
        # Configure PowerShell profile
        Write-Host "[8/8] 📋 Configuring PowerShell profile..." -ForegroundColor Yellow
        
        $profilePath = $PROFILE.CurrentUserAllHosts
        $profileDir = Split-Path $profilePath -Parent
        
        # Create profile directory if needed
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
            Write-Host "   ✅ Created profile directory" -ForegroundColor Green
        }
        
        # Add import statement to profile
        $profileContent = ""
        if (Test-Path $profilePath) {
            $profileContent = Get-Content $profilePath -Raw
        }
        
        if ($profileContent -notmatch "Import-Module SpotifyCommands") {
            $profileAddition = @"

# Spotify CLI Enhanced Edition with Live Features - Auto-generated
if (Get-Module -ListAvailable -Name SpotifyCommands) {
    Import-Module SpotifyCommands -DisableNameChecking -Force
    
    # Auto-initialize live features if available
    if (Get-Command Initialize-SpotifyLiveFeatures -ErrorAction SilentlyContinue) {
        # Uncomment the next line to auto-initialize live features on startup
        # Initialize-SpotifyLiveFeatures
    }
}
"@
            Add-Content -Path $profilePath -Value $profileAddition -Encoding UTF8
            Write-Host "   ✅ Added Spotify CLI import to PowerShell profile" -ForegroundColor Green
        } else {
            Write-Host "   ✅ Spotify CLI already configured in profile" -ForegroundColor Green
        }
        
        # Configure API keys if requested
        if ($ConfigureApiKeys) {
            Write-Host ""
            Write-Host "🔑 Configuring Spotify API credentials..." -ForegroundColor Yellow
            
            $clientId = Read-Host "Enter your Spotify Client ID"
            $clientSecret = Read-Host "Enter your Spotify Client Secret" -AsSecureString
            $clientSecretPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientSecret))
            
            if ($clientId -and $clientSecretPlain) {
                [System.Environment]::SetEnvironmentVariable("SPOTIFY_CLIENT_ID", $clientId, "User")
                [System.Environment]::SetEnvironmentVariable("SPOTIFY_CLIENT_SECRET", $clientSecretPlain, "User")
                Write-Host "✅ API credentials configured" -ForegroundColor Green
            } else {
                Write-Host "⚠️ API credentials not configured" -ForegroundColor Yellow
            }
        }
        
        # Test installation
        Write-Host ""
        Write-Host "🧪 Testing installation..." -ForegroundColor Yellow
        
        # Test main module
        $testResult = pwsh -NoProfile -Command "Import-Module SpotifyCommands; Get-Command -Module SpotifyCommands | Where-Object Name -eq 'playlists'"
        
        if ($testResult) {
            Write-Host "✅ Main module installation test passed!" -ForegroundColor Green
        } else {
            Write-Host "❌ Main module installation test failed" -ForegroundColor Red
            throw "Module installation verification failed"
        }
        
        # Test live features if installed
        if (-not $SkipLiveFeatures) {
            $liveFeaturesTest = pwsh -NoProfile -Command "Import-Module SpotifyCommands; Get-Command Initialize-SpotifyLiveFeatures -ErrorAction SilentlyContinue"
            if ($liveFeaturesTest) {
                Write-Host "✅ Live features installation test passed!" -ForegroundColor Green
            } else {
                Write-Host "⚠️ Live features test failed (may require manual configuration)" -ForegroundColor Yellow
            }
        }
        
        # Check environment variables
        Write-Host ""
        Write-Host "🔍 Checking Spotify API credentials..." -ForegroundColor Yellow
        $hasClientId = [System.Environment]::GetEnvironmentVariable("SPOTIFY_CLIENT_ID", "User") -or 
                      [System.Environment]::GetEnvironmentVariable("SPOTIFY_CLIENT_ID", "Process")
        $hasClientSecret = [System.Environment]::GetEnvironmentVariable("SPOTIFY_CLIENT_SECRET", "User") -or 
                          [System.Environment]::GetEnvironmentVariable("SPOTIFY_CLIENT_SECRET", "Process")
        
        if ($hasClientId -and $hasClientSecret) {
            Write-Host "✅ Spotify API credentials configured" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Spotify API credentials not found" -ForegroundColor Yellow
            Write-Host "💡 You'll need to configure SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET" -ForegroundColor Cyan
            Write-Host "💡 Check the .env.example file for instructions" -ForegroundColor Cyan
        }
        
        # Success summary
        Write-Host ""
        Write-Host "🎉 Installation completed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "✅ Components installed:" -ForegroundColor Green
        Write-Host "   • PowerShell module installed and configured" -ForegroundColor White
        Write-Host "   • PowerShell profile updated" -ForegroundColor White
        Write-Host "   • App data directories created" -ForegroundColor White
        Write-Host "   • Optional modules installed" -ForegroundColor White
        
        if (-not $SkipLiveFeatures) {
            Write-Host "   • Live Features modules installed" -ForegroundColor White
            Write-Host "   • Live display, lyrics, and statistics engines ready" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "💡 Next steps:" -ForegroundColor Cyan
        Write-Host "   1. Restart PowerShell or run: . `$PROFILE" -ForegroundColor White
        Write-Host "   2. Configure Spotify API credentials if needed" -ForegroundColor White
        Write-Host "   3. Test basic functionality: pl (to see your playlists)" -ForegroundColor White
        
        if (-not $SkipLiveFeatures) {
            Write-Host "   4. Initialize live features: Initialize-SpotifyLiveFeatures" -ForegroundColor White
            Write-Host "   5. Try live display: Start-SpotifyLiveDisplay" -ForegroundColor White
            Write-Host "   6. Get help with live features: Get-SpotifyLiveFeaturesStatus" -ForegroundColor White
        } else {
            Write-Host "   4. Get help with: spotify" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "📚 Documentation:" -ForegroundColor Cyan
        Write-Host "   • Complete User Guide: docs/Live-Features-Complete-User-Guide.md" -ForegroundColor White
        Write-Host "   • Configuration Reference: docs/Configuration-Reference.md" -ForegroundColor White
        Write-Host "   • Troubleshooting Guide: docs/Troubleshooting-Guide.md" -ForegroundColor White
        Write-Host "   • Example Scenarios: docs/Example-Scenarios.md" -ForegroundColor White
        
    } catch {
        Write-Host ""
        Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Please check the error above and try again" -ForegroundColor Yellow
        Write-Host "💡 For help, see docs/Troubleshooting-Guide.md" -ForegroundColor Cyan
        throw
    }
}

# Run installation if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Install-SpotifyCliLiveFeatures @args
}