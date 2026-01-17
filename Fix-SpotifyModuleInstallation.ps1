<#
.SYNOPSIS
Quick fix script for correcting existing Spotify CLI module installation

.DESCRIPTION
This script fixes the module structure issue where modules are installed under
"LiveFeatures" instead of "modules", and removes duplicate nested directories.

.EXAMPLE
.\Fix-SpotifyModuleInstallation.ps1
#>

Write-Host "🔧 Spotify CLI Module Installation Quick Fix" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Locate the installed module
    $userModulesPath = Join-Path (Split-Path $PROFILE -Parent) "Modules"
    $spotifyModulePath = Join-Path $userModulesPath "SpotifyCommands"

    if (-not (Test-Path $spotifyModulePath)) {
        Write-Host "❌ SpotifyCommands module not found at: $spotifyModulePath" -ForegroundColor Red
        Write-Host "💡 Please run Install-SpotifyCLI-LiveFeatures.ps1 first" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "✅ Found SpotifyCommands module at: $spotifyModulePath" -ForegroundColor Green
    Write-Host ""

    # Remove module from current session
    Write-Host "🔄 Removing module from current session..." -ForegroundColor Yellow
    Remove-Module SpotifyCommands -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Module removed from session" -ForegroundColor Green
    Write-Host ""

    # Check for incorrect "LiveFeatures" directory
    $liveFeaturesDir = Join-Path $spotifyModulePath "LiveFeatures"
    $correctModulesDir = Join-Path $spotifyModulePath "modules"

    if (Test-Path $liveFeaturesDir) {
        Write-Host "🔍 Found incorrect 'LiveFeatures' directory structure" -ForegroundColor Yellow

        # Create correct "modules" directory
        if (-not (Test-Path $correctModulesDir)) {
            New-Item -ItemType Directory -Path $correctModulesDir -Force | Out-Null
            Write-Host "✅ Created correct 'modules' directory" -ForegroundColor Green
        }

        # Get project source directory
        $projectDir = Split-Path $PSScriptRoot -Parent
        if ($PSScriptRoot -eq $null -or $PSScriptRoot -eq "") {
            $projectDir = "C:\Users\tommy\Documents\Projects\Terminal_Control_Spotify"
        }
        $sourceModulesDir = Join-Path $projectDir "modules"

        if (Test-Path $sourceModulesDir) {
            Write-Host "📦 Copying modules from source: $sourceModulesDir" -ForegroundColor Yellow

            # Copy SpotifyLiveFeatures.psm1
            $mainLiveModule = Join-Path $sourceModulesDir "SpotifyLiveFeatures.psm1"
            if (Test-Path $mainLiveModule) {
                Copy-Item $mainLiveModule -Destination (Join-Path $correctModulesDir "SpotifyLiveFeatures.psm1") -Force
                Write-Host "   ✅ Copied SpotifyLiveFeatures.psm1" -ForegroundColor Green
            }

            # Copy all sub-modules correctly (without duplication)
            $subModules = @("Core", "UI", "LiveDisplay", "Lyrics", "Statistics")
            foreach ($subModule in $subModules) {
                $subModuleSourceDir = Join-Path $sourceModulesDir $subModule
                if (Test-Path $subModuleSourceDir) {
                    $targetSubModuleDir = Join-Path $correctModulesDir $subModule

                    # Remove old directory if it exists
                    if (Test-Path $targetSubModuleDir) {
                        Remove-Item -Path $targetSubModuleDir -Recurse -Force
                    }

                    # Create target directory
                    New-Item -ItemType Directory -Path $targetSubModuleDir -Force | Out-Null

                    # Copy all files from source to target (not the directory itself)
                    Get-ChildItem -Path $subModuleSourceDir -Recurse -File | ForEach-Object {
                        $relativePath = $_.FullName.Substring($subModuleSourceDir.Length + 1)
                        $targetPath = Join-Path $targetSubModuleDir $relativePath
                        $targetDir = Split-Path $targetPath -Parent

                        if (-not (Test-Path $targetDir)) {
                            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                        }

                        Copy-Item $_.FullName -Destination $targetPath -Force
                    }

                    Write-Host "   ✅ Copied $subModule module" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "⚠️ Source modules directory not found at: $sourceModulesDir" -ForegroundColor Yellow
            Write-Host "💡 Attempting to fix structure from existing LiveFeatures directory..." -ForegroundColor Cyan

            # Fallback: Try to fix from existing LiveFeatures directory
            $liveFeaturesSources = @{
                "SpotifyLiveFeatures.psm1" = Join-Path $liveFeaturesDir "SpotifyLiveFeatures.psm1"
                "Core" = Join-Path $liveFeaturesDir "Core"
                "UI" = Join-Path $liveFeaturesDir "UI"
                "LiveDisplay" = Join-Path $liveFeaturesDir "LiveDisplay"
                "Lyrics" = Join-Path $liveFeaturesDir "Lyrics"
                "Statistics" = Join-Path $liveFeaturesDir "Statistics"
            }

            foreach ($item in $liveFeaturesSources.GetEnumerator()) {
                if (Test-Path $item.Value) {
                    $targetPath = Join-Path $correctModulesDir $item.Key

                    # Handle nested duplicates (Core\Core, etc.)
                    $sourcePath = $item.Value
                    if (Test-Path (Join-Path $sourcePath $item.Key)) {
                        $sourcePath = Join-Path $sourcePath $item.Key
                        Write-Host "   🔄 Unwrapping nested directory: $($item.Key)" -ForegroundColor Cyan
                    }

                    Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force
                    Write-Host "   ✅ Moved $($item.Key) to correct location" -ForegroundColor Green
                }
            }
        }

        # Remove the incorrect LiveFeatures directory
        Write-Host "🗑️ Removing incorrect 'LiveFeatures' directory..." -ForegroundColor Yellow
        Remove-Item -Path $liveFeaturesDir -Recurse -Force
        Write-Host "✅ Removed 'LiveFeatures' directory" -ForegroundColor Green

    } else {
        Write-Host "✅ Module structure is already correct" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "🎉 Module structure fix completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Restart PowerShell or run: . `$PROFILE" -ForegroundColor White
    Write-Host "   2. Test module loading: Import-Module SpotifyCommands -Force" -ForegroundColor White
    Write-Host "   3. Verify commands work: pl (to list playlists)" -ForegroundColor White
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "❌ Fix failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Please run Install-SpotifyCLI-LiveFeatures.ps1 with -Force flag" -ForegroundColor Yellow
    throw
}
