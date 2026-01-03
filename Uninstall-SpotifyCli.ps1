function Uninstall-SpotifyCli {
    <#
    .SYNOPSIS
    Clean uninstallation script for Spotify CLI
    
    .DESCRIPTION
    Removes all Spotify CLI components cleanly as specified in Requirement 9.7.
    This includes modules, profile configurations, and optionally user data.
    
    .PARAMETER KeepUserData
    Preserve user data like tokens, configuration, and history
    
    .PARAMETER Force
    Skip confirmation prompts and force removal
    
    .PARAMETER WhatIf
    Show what would be removed without actually removing anything
    
    .EXAMPLE
    Uninstall-SpotifyCli
    
    .EXAMPLE
    Uninstall-SpotifyCli -KeepUserData -Force
    
    .EXAMPLE
    Uninstall-SpotifyCli -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$KeepUserData,
        [switch]$Force,
        [switch]$WhatIf
    )
    
    Write-Host "🗑️ Spotify CLI - Uninstallation" -ForegroundColor Cyan
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not $Force -and -not $WhatIf) {
        Write-Host "⚠️ This will remove Spotify CLI from your system." -ForegroundColor Yellow
        Write-Host ""
        $confirmation = Read-Host "Are you sure you want to continue? (y/N)"
        if ($confirmation -notmatch '^[Yy]') {
            Write-Host "❌ Uninstallation cancelled." -ForegroundColor Yellow
            return
        }
        Write-Host ""
    }
    
    $uninstallResults = @{
        Success = $true
        RemovedItems = @()
        Errors = @()
        KeptItems = @()
    }
    
    try {
        # 1. Remove module from PowerShell modules directory
        Write-Host "🔍 Locating Spotify CLI module..." -ForegroundColor Yellow
        
        $userModulesPath = Join-Path (Split-Path $PROFILE -Parent) "Modules"
        $spotifyModulePath = Join-Path $userModulesPath "SpotifyCommands"
        
        if (Test-Path $spotifyModulePath) {
            if ($WhatIf) {
                Write-Host "   Would remove: $spotifyModulePath" -ForegroundColor Gray
            } else {
                try {
                    Remove-Item -Path $spotifyModulePath -Recurse -Force
                    Write-Host "✅ Removed module directory: $spotifyModulePath" -ForegroundColor Green
                    $uninstallResults.RemovedItems += "Module directory"
                } catch {
                    $error = "Failed to remove module directory: $($_.Exception.Message)"
                    Write-Host "❌ $error" -ForegroundColor Red
                    $uninstallResults.Errors += $error
                    $uninstallResults.Success = $false
                }
            }
        } else {
            Write-Host "   Module directory not found (already removed or not installed)" -ForegroundColor Gray
        }
        
        # 2. Remove from PowerShell profile
        Write-Host "🔍 Checking PowerShell profile..." -ForegroundColor Yellow
        
        $profilePath = $PROFILE.CurrentUserAllHosts
        if (Test-Path $profilePath) {
            $profileContent = Get-Content $profilePath -Raw
            
            if ($profileContent -match "Import-Module SpotifyCommands" -or 
                $profileContent -match "Spotify CLI Enhanced Edition") {
                
                if ($WhatIf) {
                    Write-Host "   Would remove Spotify CLI entries from: $profilePath" -ForegroundColor Gray
                } else {
                    try {
                        # Remove Spotify CLI related lines
                        $lines = Get-Content $profilePath
                        $filteredLines = $lines | Where-Object {
                            $_ -notmatch "Import-Module SpotifyCommands" -and
                            $_ -notmatch "Spotify CLI Enhanced Edition" -and
                            $_ -notmatch "SpotifyCommands.*DisableNameChecking"
                        }
                        
                        # Remove empty lines that might be left behind
                        $cleanedLines = @()
                        $skipNextEmpty = $false
                        
                        for ($i = 0; $i -lt $filteredLines.Count; $i++) {
                            $line = $filteredLines[$i]
                            
                            if ([string]::IsNullOrWhiteSpace($line)) {
                                if (-not $skipNextEmpty) {
                                    $cleanedLines += $line
                                }
                                $skipNextEmpty = $false
                            } else {
                                $cleanedLines += $line
                                $skipNextEmpty = $false
                            }
                        }
                        
                        $cleanedLines | Set-Content -Path $profilePath -Encoding UTF8
                        Write-Host "✅ Removed Spotify CLI from PowerShell profile" -ForegroundColor Green
                        $uninstallResults.RemovedItems += "PowerShell profile entries"
                    } catch {
                        $error = "Failed to update PowerShell profile: $($_.Exception.Message)"
                        Write-Host "❌ $error" -ForegroundColor Red
                        $uninstallResults.Errors += $error
                    }
                }
            } else {
                Write-Host "   No Spotify CLI entries found in profile" -ForegroundColor Gray
            }
        } else {
            Write-Host "   PowerShell profile not found" -ForegroundColor Gray
        }
        
        # 3. Handle user data
        Write-Host "🔍 Checking user data..." -ForegroundColor Yellow
        
        $appDataDir = Join-Path $env:APPDATA "SpotifyCLI"
        if (Test-Path $appDataDir) {
            if ($KeepUserData) {
                Write-Host "   Keeping user data as requested: $appDataDir" -ForegroundColor Cyan
                $uninstallResults.KeptItems += "User data directory"
            } else {
                if ($WhatIf) {
                    Write-Host "   Would remove user data: $appDataDir" -ForegroundColor Gray
                } else {
                    try {
                        Remove-Item -Path $appDataDir -Recurse -Force
                        Write-Host "✅ Removed user data directory: $appDataDir" -ForegroundColor Green
                        $uninstallResults.RemovedItems += "User data directory"
                    } catch {
                        $error = "Failed to remove user data: $($_.Exception.Message)"
                        Write-Host "❌ $error" -ForegroundColor Red
                        $uninstallResults.Errors += $error
                    }
                }
            }
        } else {
            Write-Host "   No user data directory found" -ForegroundColor Gray
        }
        
        # 4. Remove environment variables (optional)
        Write-Host "🔍 Checking environment variables..." -ForegroundColor Yellow
        
        $envVars = @("SPOTIFY_CLIENT_ID", "SPOTIFY_CLIENT_SECRET")
        foreach ($var in $envVars) {
            $value = [System.Environment]::GetEnvironmentVariable($var, "User")
            if ($value) {
                if ($KeepUserData) {
                    Write-Host "   Keeping environment variable: $var" -ForegroundColor Cyan
                    $uninstallResults.KeptItems += "Environment variable: $var"
                } else {
                    if ($WhatIf) {
                        Write-Host "   Would remove environment variable: $var" -ForegroundColor Gray
                    } else {
                        try {
                            [System.Environment]::SetEnvironmentVariable($var, $null, "User")
                            Write-Host "✅ Removed environment variable: $var" -ForegroundColor Green
                            $uninstallResults.RemovedItems += "Environment variable: $var"
                        } catch {
                            $error = "Failed to remove environment variable $var`: $($_.Exception.Message)"
                            Write-Host "❌ $error" -ForegroundColor Red
                            $uninstallResults.Errors += $error
                        }
                    }
                }
            }
        }
        
        # 5. Remove optional dependencies (with confirmation)
        Write-Host "🔍 Checking optional dependencies..." -ForegroundColor Yellow
        
        $optionalModules = @("BurntToast")
        foreach ($module in $optionalModules) {
            $installedModule = Get-Module -Name $module -ListAvailable
            if ($installedModule) {
                if ($WhatIf) {
                    Write-Host "   Would ask about removing optional module: $module" -ForegroundColor Gray
                } else {
                    if (-not $Force) {
                        $removeModule = Read-Host "Remove optional module '$module'? (y/N)"
                        if ($removeModule -match '^[Yy]') {
                            try {
                                Uninstall-Module -Name $module -Force
                                Write-Host "✅ Removed optional module: $module" -ForegroundColor Green
                                $uninstallResults.RemovedItems += "Optional module: $module"
                            } catch {
                                $error = "Failed to remove module $module`: $($_.Exception.Message)"
                                Write-Host "❌ $error" -ForegroundColor Red
                                $uninstallResults.Errors += $error
                            }
                        } else {
                            Write-Host "   Keeping optional module: $module" -ForegroundColor Cyan
                            $uninstallResults.KeptItems += "Optional module: $module"
                        }
                    }
                }
            }
        }
        
        # Display summary
        Write-Host ""
        Write-Host "📋 Uninstallation Summary" -ForegroundColor Cyan
        Write-Host "=========================" -ForegroundColor Cyan
        
        if ($WhatIf) {
            Write-Host "🔍 What would be removed:" -ForegroundColor Yellow
            Write-Host "This was a dry run - no changes were made." -ForegroundColor Gray
        } else {
            if ($uninstallResults.RemovedItems.Count -gt 0) {
                Write-Host "✅ Removed items:" -ForegroundColor Green
                foreach ($item in $uninstallResults.RemovedItems) {
                    Write-Host "   • $item" -ForegroundColor White
                }
            }
            
            if ($uninstallResults.KeptItems.Count -gt 0) {
                Write-Host "📦 Kept items:" -ForegroundColor Cyan
                foreach ($item in $uninstallResults.KeptItems) {
                    Write-Host "   • $item" -ForegroundColor White
                }
            }
            
            if ($uninstallResults.Errors.Count -gt 0) {
                Write-Host "❌ Errors encountered:" -ForegroundColor Red
                foreach ($error in $uninstallResults.Errors) {
                    Write-Host "   • $error" -ForegroundColor Red
                }
                $uninstallResults.Success = $false
            }
            
            if ($uninstallResults.Success) {
                Write-Host ""
                Write-Host "🎉 Spotify CLI uninstalled successfully!" -ForegroundColor Green
                Write-Host "💡 You may need to restart PowerShell for changes to take effect." -ForegroundColor Cyan
            } else {
                Write-Host ""
                Write-Host "⚠️ Uninstallation completed with some errors." -ForegroundColor Yellow
                Write-Host "💡 You may need to manually remove some components." -ForegroundColor Cyan
            }
        }
        
    } catch {
        $uninstallResults.Success = $false
        $uninstallResults.Errors += $_.Exception.Message
        Write-Host "❌ Uninstallation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $uninstallResults
}

function Get-SpotifyCliTroubleshootingGuide {
    <#
    .SYNOPSIS
    Displays comprehensive troubleshooting guide for common Spotify CLI issues
    
    .DESCRIPTION
    Provides detailed error messages and troubleshooting steps for common issues
    as specified in Requirement 9.6
    
    .PARAMETER Issue
    Specific issue to get help with
    
    .EXAMPLE
    Get-SpotifyCliTroubleshootingGuide
    
    .EXAMPLE
    Get-SpotifyCliTroubleshootingGuide -Issue "authentication"
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("authentication", "installation", "permissions", "modules", "notifications", "playback", "general")]
        [string]$Issue
    )
    
    Write-Host "🔧 Spotify CLI - Troubleshooting Guide" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not $Issue) {
        Write-Host "📋 Common Issues and Solutions:" -ForegroundColor Yellow
        Write-Host ""
        
        Write-Host "1. Authentication Issues" -ForegroundColor Cyan
        Write-Host "   • 'Authentication required' messages" -ForegroundColor White
        Write-Host "   • 'Token expired' errors" -ForegroundColor White
        Write-Host "   • API permission errors" -ForegroundColor White
        Write-Host "   💡 Run: Get-SpotifyCliTroubleshootingGuide -Issue authentication" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "2. Installation Problems" -ForegroundColor Cyan
        Write-Host "   • Module not found errors" -ForegroundColor White
        Write-Host "   • Commands not available" -ForegroundColor White
        Write-Host "   • Profile configuration issues" -ForegroundColor White
        Write-Host "   💡 Run: Get-SpotifyCliTroubleshootingGuide -Issue installation" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "3. Permission Errors" -ForegroundColor Cyan
        Write-Host "   • Execution policy restrictions" -ForegroundColor White
        Write-Host "   • Module installation failures" -ForegroundColor White
        Write-Host "   • File access denied" -ForegroundColor White
        Write-Host "   💡 Run: Get-SpotifyCliTroubleshootingGuide -Issue permissions" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "4. Module Dependencies" -ForegroundColor Cyan
        Write-Host "   • Missing PowerShell modules" -ForegroundColor White
        Write-Host "   • Version compatibility issues" -ForegroundColor White
        Write-Host "   • Import failures" -ForegroundColor White
        Write-Host "   💡 Run: Get-SpotifyCliTroubleshootingGuide -Issue modules" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "5. Notification Issues" -ForegroundColor Cyan
        Write-Host "   • Toast notifications not working" -ForegroundColor White
        Write-Host "   • BurntToast module problems" -ForegroundColor White
        Write-Host "   • Cross-terminal compatibility" -ForegroundColor White
        Write-Host "   💡 Run: Get-SpotifyCliTroubleshootingGuide -Issue notifications" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "6. Playback Problems" -ForegroundColor Cyan
        Write-Host "   • No active device errors" -ForegroundColor White
        Write-Host "   • Spotify Premium required" -ForegroundColor White
        Write-Host "   • API rate limiting" -ForegroundColor White
        Write-Host "   💡 Run: Get-SpotifyCliTroubleshootingGuide -Issue playback" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "🆘 Quick Diagnostic Commands:" -ForegroundColor Green
        Write-Host "   • Test-SpotifyCliInstallation (comprehensive check)" -ForegroundColor White
        Write-Host "   • Get-SpotifyConfig (view current settings)" -ForegroundColor White
        Write-Host "   • Test-SpotifyAuth (check authentication)" -ForegroundColor White
        Write-Host ""
        
        return
    }
    
    switch ($Issue) {
        "authentication" {
            Write-Host "🔐 Authentication Issues" -ForegroundColor Cyan
            Write-Host "=======================" -ForegroundColor Cyan
            Write-Host ""
            
            Write-Host "Common Symptoms:" -ForegroundColor Yellow
            Write-Host "• 'Authentication required. Please run the main CLI script first'" -ForegroundColor Red
            Write-Host "• 'Token expired and no refresh token available'" -ForegroundColor Red
            Write-Host "• '401 Authentication Error: Your Spotify session has expired'" -ForegroundColor Red
            Write-Host ""
            
            Write-Host "Solutions:" -ForegroundColor Green
            Write-Host ""
            
            Write-Host "1. Check Environment Variables:" -ForegroundColor Cyan
            Write-Host "   [System.Environment]::GetEnvironmentVariable('SPOTIFY_CLIENT_ID', 'User')" -ForegroundColor Gray
            Write-Host "   [System.Environment]::GetEnvironmentVariable('SPOTIFY_CLIENT_SECRET', 'User')" -ForegroundColor Gray
            Write-Host "   💡 Both should return your Spotify app credentials" -ForegroundColor White
            Write-Host ""
            
            Write-Host "2. Re-authenticate:" -ForegroundColor Cyan
            Write-Host "   .\spotifyCLI.ps1" -ForegroundColor Gray
            Write-Host "   💡 This will open a browser for Spotify login" -ForegroundColor White
            Write-Host ""
            
            Write-Host "3. Check Spotify App Settings:" -ForegroundColor Cyan
            Write-Host "   • Go to https://developer.spotify.com/dashboard" -ForegroundColor White
            Write-Host "   • Verify redirect URI: http://127.0.0.1:8888/callback" -ForegroundColor White
            Write-Host "   • Ensure app is not in development mode restrictions" -ForegroundColor White
            Write-Host ""
            
            Write-Host "4. Clear Corrupted Tokens:" -ForegroundColor Cyan
            Write-Host "   Remove-Item `"$env:APPDATA\SpotifyCLI\tokens.json`" -Force" -ForegroundColor Gray
            Write-Host "   💡 Then re-authenticate using step 2" -ForegroundColor White
        }
        
        "installation" {
            Write-Host "📦 Installation Problems" -ForegroundColor Cyan
            Write-Host "=======================" -ForegroundColor Cyan
            Write-Host ""
            
            Write-Host "Common Symptoms:" -ForegroundColor Yellow
            Write-Host "• 'The term 'spotify-now' is not recognized'" -ForegroundColor Red
            Write-Host "• 'Module 'SpotifyCommands' not found'" -ForegroundColor Red
            Write-Host "• Commands work in one session but not after restart" -ForegroundColor Red
            Write-Host ""
            
            Write-Host "Solutions:" -ForegroundColor Green
            Write-Host ""
            
            Write-Host "1. Verify Module Installation:" -ForegroundColor Cyan
            Write-Host "   Get-Module -Name SpotifyCommands -ListAvailable" -ForegroundColor Gray
            Write-Host "   💡 Should show the module if properly installed" -ForegroundColor White
            Write-Host ""
            
            Write-Host "2. Reinstall Dependencies:" -ForegroundColor Cyan
            Write-Host "   Install-SpotifyCliDependencies -Force" -ForegroundColor Gray
            Write-Host "   💡 This will reconfigure everything" -ForegroundColor White
            Write-Host ""
            
            Write-Host "3. Manual Profile Check:" -ForegroundColor Cyan
            Write-Host "   Get-Content `$PROFILE.CurrentUserAllHosts" -ForegroundColor Gray
            Write-Host "   💡 Should contain 'Import-Module SpotifyCommands'" -ForegroundColor White
            Write-Host ""
            
            Write-Host "4. Force Profile Reload:" -ForegroundColor Cyan
            Write-Host "   . `$PROFILE" -ForegroundColor Gray
            Write-Host "   💡 Reloads profile in current session" -ForegroundColor White
        }
        
        "permissions" {
            Write-Host "🔒 Permission Errors" -ForegroundColor Cyan
            Write-Host "===================" -ForegroundColor Cyan
            Write-Host ""
            
            Write-Host "Common Symptoms:" -ForegroundColor Yellow
            Write-Host "• 'Execution policy does not allow this script to run'" -ForegroundColor Red
            Write-Host "• 'Access to the path is denied'" -ForegroundColor Red
            Write-Host "• 'Administrator rights required'" -ForegroundColor Red
            Write-Host ""
            
            Write-Host "Solutions:" -ForegroundColor Green
            Write-Host ""
            
            Write-Host "1. Check Execution Policy:" -ForegroundColor Cyan
            Write-Host "   Get-ExecutionPolicy -List" -ForegroundColor Gray
            Write-Host "   💡 CurrentUser should be RemoteSigned or Unrestricted" -ForegroundColor White
            Write-Host ""
            
            Write-Host "2. Fix Execution Policy:" -ForegroundColor Cyan
            Write-Host "   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
            Write-Host "   💡 Allows local scripts and signed remote scripts" -ForegroundColor White
            Write-Host ""
            
            Write-Host "3. Run as Administrator (if needed):" -ForegroundColor Cyan
            Write-Host "   • Right-click PowerShell → 'Run as Administrator'" -ForegroundColor White
            Write-Host "   • Only needed for system-wide installations" -ForegroundColor White
            Write-Host ""
            
            Write-Host "4. Alternative User-Only Installation:" -ForegroundColor Cyan
            Write-Host "   Install-SpotifyCliDependencies" -ForegroundColor Gray
            Write-Host "   💡 Installs to user profile only (no admin needed)" -ForegroundColor White
        }
        
        "modules" {
            Write-Host "📚 Module Dependencies" -ForegroundColor Cyan
            Write-Host "=====================" -ForegroundColor Cyan
            Write-Host ""
            
            Write-Host "Common Symptoms:" -ForegroundColor Yellow
            Write-Host "• 'Module BurntToast not found'" -ForegroundColor Red
            Write-Host "• 'The specified module was not loaded'" -ForegroundColor Red
            Write-Host "• Version compatibility warnings" -ForegroundColor Red
            Write-Host ""
            
            Write-Host "Solutions:" -ForegroundColor Green
            Write-Host ""
            
            Write-Host "1. Install Missing Modules:" -ForegroundColor Cyan
            Write-Host "   Install-Module -Name BurntToast -Scope CurrentUser" -ForegroundColor Gray
            Write-Host "   💡 Installs optional notification module" -ForegroundColor White
            Write-Host ""
            
            Write-Host "2. Update PowerShellGet:" -ForegroundColor Cyan
            Write-Host "   Install-Module -Name PowerShellGet -Force -Scope CurrentUser" -ForegroundColor Gray
            Write-Host "   💡 Fixes module installation issues" -ForegroundColor White
            Write-Host ""
            
            Write-Host "3. Check Module Versions:" -ForegroundColor Cyan
            Write-Host "   Get-Module -Name BurntToast -ListAvailable | Select-Object Version" -ForegroundColor Gray
            Write-Host "   💡 Should be version 0.8.0 or higher" -ForegroundColor White
            Write-Host ""
            
            Write-Host "4. Force Module Refresh:" -ForegroundColor Cyan
            Write-Host "   Remove-Module SpotifyCommands -Force; Import-Module SpotifyCommands -Force" -ForegroundColor Gray
            Write-Host "   💡 Reloads the module with fresh dependencies" -ForegroundColor White
        }
        
        "notifications" {
            Write-Host "🔔 Notification Issues" -ForegroundColor Cyan
            Write-Host "=====================" -ForegroundColor Cyan
            Write-Host ""
            
            Write-Host "Common Symptoms:" -ForegroundColor Yellow
            Write-Host "• Toast notifications not appearing" -ForegroundColor Red
            Write-Host "• 'BurntToast module failed to load'" -ForegroundColor Red
            Write-Host "• Notifications work in some terminals but not others" -ForegroundColor Red
            Write-Host ""
            
            Write-Host "Solutions:" -ForegroundColor Green
            Write-Host ""
            
            Write-Host "1. Test Notification System:" -ForegroundColor Cyan
            Write-Host "   notifications test" -ForegroundColor Gray
            Write-Host "   💡 Tests all notification methods" -ForegroundColor White
            Write-Host ""
            
            Write-Host "2. Install BurntToast:" -ForegroundColor Cyan
            Write-Host "   Install-Module -Name BurntToast -Scope CurrentUser -Force" -ForegroundColor Gray
            Write-Host "   💡 Required for Windows toast notifications" -ForegroundColor White
            Write-Host ""
            
            Write-Host "3. Check Windows Notifications:" -ForegroundColor Cyan
            Write-Host "   • Windows Settings → System → Notifications" -ForegroundColor White
            Write-Host "   • Ensure notifications are enabled for PowerShell" -ForegroundColor White
            Write-Host ""
            
            Write-Host "4. Fallback to Console:" -ForegroundColor Cyan
            Write-Host "   Set-SpotifyConfig @{NotificationsEnabled=`$false}" -ForegroundColor Gray
            Write-Host "   💡 Disables toast notifications, uses console output" -ForegroundColor White
        }
        
        "playback" {
            Write-Host "🎵 Playback Problems" -ForegroundColor Cyan
            Write-Host "===================" -ForegroundColor Cyan
            Write-Host ""
            
            Write-Host "Common Symptoms:" -ForegroundColor Yellow
            Write-Host "• 'No Active Device: Please start Spotify on any device first'" -ForegroundColor Red
            Write-Host "• 'Permission Error: This operation requires Spotify Premium'" -ForegroundColor Red
            Write-Host "• 'Rate Limit: Too many requests'" -ForegroundColor Red
            Write-Host ""
            
            Write-Host "Solutions:" -ForegroundColor Green
            Write-Host ""
            
            Write-Host "1. Start Spotify Application:" -ForegroundColor Cyan
            Write-Host "   spotify" -ForegroundColor Gray
            Write-Host "   💡 Launches Spotify desktop app" -ForegroundColor White
            Write-Host ""
            
            Write-Host "2. Check Available Devices:" -ForegroundColor Cyan
            Write-Host "   devices" -ForegroundColor Gray
            Write-Host "   💡 Shows all Spotify-connected devices" -ForegroundColor White
            Write-Host ""
            
            Write-Host "3. Transfer Playback:" -ForegroundColor Cyan
            Write-Host "   transfer 1" -ForegroundColor Gray
            Write-Host "   💡 Transfers to device #1 from devices list" -ForegroundColor White
            Write-Host ""
            
            Write-Host "4. Verify Spotify Premium:" -ForegroundColor Cyan
            Write-Host "   • Playback control requires Spotify Premium" -ForegroundColor White
            Write-Host "   • Free accounts can only view current track" -ForegroundColor White
            Write-Host ""
            
            Write-Host "5. Rate Limiting:" -ForegroundColor Cyan
            Write-Host "   • Wait 30-60 seconds between rapid API calls" -ForegroundColor White
            Write-Host "   • Avoid running multiple CLI instances simultaneously" -ForegroundColor White
        }
    }
    
    Write-Host ""
    Write-Host "🆘 Still Need Help?" -ForegroundColor Green
    Write-Host "==================" -ForegroundColor Green
    Write-Host ""
    Write-Host "1. Run comprehensive diagnostics:" -ForegroundColor Cyan
    Write-Host "   Test-SpotifyCliInstallation -Detailed" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Check the troubleshooting documentation:" -ForegroundColor Cyan
    Write-Host "   Get-Content TROUBLESHOOTING.md" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Reset to clean state:" -ForegroundColor Cyan
    Write-Host "   Uninstall-SpotifyCli; Install-SpotifyCliDependencies" -ForegroundColor Gray
    Write-Host ""
}

function Repair-SpotifyCliInstallation {
    <#
    .SYNOPSIS
    Attempts to repair common Spotify CLI installation issues
    
    .DESCRIPTION
    Implements installation failure recovery mechanisms as specified in Requirement 9.6
    
    .PARAMETER Force
    Force repair even if no issues are detected
    
    .EXAMPLE
    Repair-SpotifyCliInstallation
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )
    
    Write-Host "🔧 Spotify CLI - Installation Repair" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host ""
    
    $repairResults = @{
        Success = $true
        RepairedItems = @()
        Errors = @()
    }
    
    try {
        # Run diagnostics first
        Write-Host "🔍 Running diagnostics..." -ForegroundColor Yellow
        $diagnostics = Test-SpotifyCliInstallation -SkipSpotifyAppTest
        
        if ($diagnostics.OverallSuccess -and -not $Force) {
            Write-Host "✅ No issues detected. Installation appears to be working correctly." -ForegroundColor Green
            Write-Host "💡 Use -Force to repair anyway." -ForegroundColor Cyan
            return $repairResults
        }
        
        Write-Host "🔧 Attempting repairs..." -ForegroundColor Yellow
        Write-Host ""
        
        # Repair 1: Fix execution policy
        if ($diagnostics.Errors -match "execution policy") {
            Write-Host "   Fixing execution policy..." -ForegroundColor Cyan
            try {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Write-Host "   ✅ Execution policy repaired" -ForegroundColor Green
                $repairResults.RepairedItems += "Execution policy"
            } catch {
                $error = "Failed to fix execution policy: $($_.Exception.Message)"
                Write-Host "   ❌ $error" -ForegroundColor Red
                $repairResults.Errors += $error
            }
        }
        
        # Repair 2: Reinstall module
        if ($diagnostics.Errors -match "module" -or $diagnostics.Errors -match "SpotifyCommands") {
            Write-Host "   Reinstalling module..." -ForegroundColor Cyan
            try {
                $installResult = Install-SpotifyCliDependencies -Force
                if ($installResult.Success) {
                    Write-Host "   ✅ Module reinstalled" -ForegroundColor Green
                    $repairResults.RepairedItems += "Module installation"
                } else {
                    $repairResults.Errors += $installResult.Errors
                }
            } catch {
                $error = "Failed to reinstall module: $($_.Exception.Message)"
                Write-Host "   ❌ $error" -ForegroundColor Red
                $repairResults.Errors += $error
            }
        }
        
        # Repair 3: Fix profile configuration
        if ($diagnostics.Warnings -match "profile") {
            Write-Host "   Fixing PowerShell profile..." -ForegroundColor Cyan
            try {
                $profileResult = Set-SpotifyCliProfile
                if ($profileResult.Success) {
                    Write-Host "   ✅ PowerShell profile repaired" -ForegroundColor Green
                    $repairResults.RepairedItems += "PowerShell profile"
                } else {
                    $repairResults.Errors += $profileResult.Error
                }
            } catch {
                $error = "Failed to fix profile: $($_.Exception.Message)"
                Write-Host "   ❌ $error" -ForegroundColor Red
                $repairResults.Errors += $error
            }
        }
        
        # Repair 4: Install missing dependencies
        if ($diagnostics.Warnings -match "Dependencies") {
            Write-Host "   Installing missing dependencies..." -ForegroundColor Cyan
            try {
                Install-Module -Name BurntToast -Scope CurrentUser -Force -ErrorAction SilentlyContinue
                Write-Host "   ✅ Dependencies installed" -ForegroundColor Green
                $repairResults.RepairedItems += "Dependencies"
            } catch {
                Write-Host "   ⚠️ Some optional dependencies could not be installed" -ForegroundColor Yellow
            }
        }
        
        Write-Host ""
        Write-Host "📋 Repair Summary" -ForegroundColor Cyan
        Write-Host "=================" -ForegroundColor Cyan
        
        if ($repairResults.RepairedItems.Count -gt 0) {
            Write-Host "✅ Repaired items:" -ForegroundColor Green
            foreach ($item in $repairResults.RepairedItems) {
                Write-Host "   • $item" -ForegroundColor White
            }
        }
        
        if ($repairResults.Errors.Count -gt 0) {
            Write-Host "❌ Repair errors:" -ForegroundColor Red
            foreach ($error in $repairResults.Errors) {
                Write-Host "   • $error" -ForegroundColor Red
            }
            $repairResults.Success = $false
        }
        
        if ($repairResults.Success) {
            Write-Host ""
            Write-Host "🎉 Repair completed successfully!" -ForegroundColor Green
            Write-Host "💡 Restart PowerShell and run Test-SpotifyCliInstallation to verify." -ForegroundColor Cyan
        } else {
            Write-Host ""
            Write-Host "⚠️ Repair completed with some errors." -ForegroundColor Yellow
            Write-Host "💡 Run Get-SpotifyCliTroubleshootingGuide for more help." -ForegroundColor Cyan
        }
        
    } catch {
        $repairResults.Success = $false
        $repairResults.Errors += $_.Exception.Message
        Write-Host "❌ Repair failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $repairResults
}