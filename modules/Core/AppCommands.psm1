# AppCommands Module
# Contains core application commands like starting the app and showing the current track.

function Start-SpotifyApp {
    <#
    .SYNOPSIS
    Launch the Spotify desktop application
    .DESCRIPTION
    Launches the Spotify desktop application using multiple detection methods.
    Supports both desktop app and web player launching with comprehensive error handling.
    .PARAMETER Web
    Open Spotify Web Player instead of desktop app
    .PARAMETER WaitForReady
    Wait for Spotify to become available after launching
    .PARAMETER Force
    Force launch even if Spotify is already running (opens new instance)
    .EXAMPLE
    Start-SpotifyApp
    Launches the Spotify desktop application
    .EXAMPLE
    Start-SpotifyApp -Web
    Opens Spotify Web Player in default browser
    .EXAMPLE
    Start-SpotifyApp -WaitForReady
    Launches Spotify and waits for it to become ready
    #>
    param(
        [switch]$Web,
        [switch]$WaitForReady,
        [switch]$Force
    )
    if ($Web) {
        Write-Host "🌐 Opening Spotify Web Player..." -ForegroundColor Cyan
        try {
            Start-Process "https://open.spotify.com" -ErrorAction Stop
            Write-Host "✅ Web player opened successfully" -ForegroundColor Green
            Write-Host "💡 Sign in to your Spotify account to start using the web player" -ForegroundColor Cyan
        } catch {
            Write-Host "❌ Failed to open web player: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "🔧 TROUBLESHOOTING:" -ForegroundColor Yellow
            Write-Host "• Try opening https://open.spotify.com manually in your browser" -ForegroundColor White
            Write-Host "• Check if your default browser is set correctly" -ForegroundColor White
            Write-Host "• Ensure you have an internet connection" -ForegroundColor White
        }
        return
    }
    Write-Host "🚀 Launching Spotify application..." -ForegroundColor Cyan
    # Check if Spotify is already running
    $spotifyProcesses = Get-Process -Name "Spotify" -ErrorAction SilentlyContinue
    if ($spotifyProcesses -and -not $Force) {
        $processCount = $spotifyProcesses.Count
        $mainProcess = $spotifyProcesses | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object -First 1
        if ($mainProcess) {
            Write-Host "✅ Spotify is already running and ready (PID: $($mainProcess.Id))" -ForegroundColor Green
            Write-Host "💡 Use 'Start-SpotifyApp -Force' to launch another instance" -ForegroundColor Cyan
        } else {
            Write-Host "✅ Spotify processes detected ($processCount running)" -ForegroundColor Green
            Write-Host "💡 Spotify may be starting up or running in background" -ForegroundColor Cyan
        }
        return
    }
    # Try multiple methods to launch Spotify
    $launched = $false
    $launchMethod = ""
    $launchPath = ""
    # Method 1: Try common installation paths for desktop app
    Write-Host "🔍 Checking for desktop Spotify installation..." -ForegroundColor Gray
    $spotifyPaths = @(
        @{ Path = "$env:APPDATA\Spotify\Spotify.exe"; Type = "User Installation" },
        @{ Path = "${env:ProgramFiles}\Spotify\Spotify.exe"; Type = "System Installation (64-bit)" },
        @{ Path = "${env:ProgramFiles(x86)}\Spotify\Spotify.exe"; Type = "System Installation (32-bit)" }
    )
    foreach ($pathInfo in $spotifyPaths) {
        $path = $pathInfo.Path
        $type = $pathInfo.Type
        if (Test-Path $path) {
            Write-Host "✅ Found Spotify: $type" -ForegroundColor Green
            try {
                Start-Process $path -ErrorAction Stop
                $launched = $true
                $launchMethod = "Desktop App ($type)"
                $launchPath = $path
                break
            } catch {
                Write-Host "⚠️ Failed to launch from $path : $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
    # Method 2: Try Windows Store version via protocol
    if (-not $launched) {
        Write-Host "🔍 Trying Windows Store version..." -ForegroundColor Gray
        try {
            # Test if protocol is available first
            $protocolTest = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey("spotify")
            if ($protocolTest) {
                $protocolTest.Close()
                Start-Process "spotify:" -ErrorAction Stop
                $launched = $true
                $launchMethod = "Windows Store App (Protocol)"
                Write-Host "✅ Launched via spotify: protocol" -ForegroundColor Green
            } else {
                Write-Host "ℹ️ Spotify protocol not registered" -ForegroundColor Gray
            }
        } catch {
            Write-Host "ℹ️ Windows Store version not available: $($_.Exception.Message)" -ForegroundColor Gray
        }
    }
    # Method 3: Try using COM Shell Application
    if (-not $launched) {
        Write-Host "🔍 Trying shell execute method..." -ForegroundColor Gray
        try {
            $shell = New-Object -ComObject Shell.Application -ErrorAction Stop
            $shell.ShellExecute("spotify:")
            $launched = $true
            $launchMethod = "Shell Execute (Protocol)"
            Write-Host "✅ Launched via shell execute" -ForegroundColor Green
        } catch {
            Write-Host "ℹ️ Shell execute method failed: $($_.Exception.Message)" -ForegroundColor Gray
        }
    }
    # Method 4: Try Windows Run dialog approach
    if (-not $launched) {
        Write-Host "🔍 Trying Windows Run approach..." -ForegroundColor Gray
        try {
            $wshell = New-Object -ComObject WScript.Shell -ErrorAction Stop
            $wshell.Run("spotify:", 1, $false)
            $launched = $true
            $launchMethod = "WScript Shell (Protocol)"
            Write-Host "✅ Launched via WScript shell" -ForegroundColor Green
        } catch {
            Write-Host "ℹ️ WScript shell method failed: $($_.Exception.Message)" -ForegroundColor Gray
        }
    }
    if (-not $launched) {
        Write-Host ""
        Write-Host "❌ Spotify could not be launched" -ForegroundColor Red
        Write-Host ""
        Write-Host "🔧 INSTALLATION REQUIRED:" -ForegroundColor Yellow
        Write-Host "Spotify is not installed on this system." -ForegroundColor White
        Write-Host ""
        Write-Host "📥 INSTALLATION OPTIONS:" -ForegroundColor Cyan
        Write-Host "1. Desktop App: https://www.spotify.com/download/" -ForegroundColor White
        Write-Host "2. Microsoft Store: ms-windows-store://pdp/?productid=9NCBCSZSJRSB" -ForegroundColor White
        Write-Host "3. Web Player: Use 'spotify -Web' or visit https://open.spotify.com" -ForegroundColor White
        Write-Host ""
        Write-Host "💡 QUICK ALTERNATIVES:" -ForegroundColor Green
        Write-Host "• Run: spotify -Web    (opens web player)" -ForegroundColor White
        Write-Host "• Run: Start-SpotifyApp -Web" -ForegroundColor White
        # Try to open installation page
        $response = Read-Host "Open Spotify download page in browser? (y/N)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            try {
                Start-Process "https://www.spotify.com/download/" -ErrorAction Stop
                Write-Host "✅ Download page opened in browser" -ForegroundColor Green
            } catch {
                Write-Host "❌ Could not open browser. Please visit: https://www.spotify.com/download/" -ForegroundColor Red
            }
        }
        return
    }
    Write-Host "✅ Spotify launched successfully using: $launchMethod" -ForegroundColor Green
    if ($launchPath) {
        Write-Host "📁 Path: $launchPath" -ForegroundColor Gray
    }
    # Wait for Spotify to become ready if requested
    if ($WaitForReady) {
        Write-Host ""
        Write-Host "⏳ Waiting for Spotify to become ready..." -ForegroundColor Yellow
        $timeout = 30 # seconds
        $elapsed = 0
        $ready = $false
        do {
            Start-Sleep -Seconds 1
            $elapsed++
            # Check for Spotify processes
            $spotifyProcess = Get-Process -Name "Spotify" -ErrorAction SilentlyContinue
            if ($spotifyProcess) {
                # Check if main window is available (indicates ready state)
                $mainWindow = $spotifyProcess | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object -First 1
                if ($mainWindow) {
                    $ready = $true
                    Write-Host "✅ Spotify is now active and ready (PID: $($mainWindow.Id))" -ForegroundColor Green
                    Write-Host "🎵 Window Title: $($mainWindow.MainWindowTitle)" -ForegroundColor Gray
                    break
                }
            }
            # Show progress every 5 seconds
            if ($elapsed % 5 -eq 0) {
                Write-Host "⏳ Still waiting... ($elapsed/$timeout seconds)" -ForegroundColor Yellow
            }
        } while ($elapsed -lt $timeout)
        if (-not $ready) {
            Write-Host "⚠️ Spotify launch timeout after $timeout seconds" -ForegroundColor Yellow
            Write-Host "💡 Spotify may still be starting up in the background" -ForegroundColor Cyan
            # Final check for any Spotify processes
            $anySpotifyProcess = Get-Process -Name "Spotify" -ErrorAction SilentlyContinue
            if ($anySpotifyProcess) {
                Write-Host "ℹ️ Spotify processes detected: $($anySpotifyProcess.Count)" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Host "💡 Use 'Start-SpotifyApp -WaitForReady' to wait for Spotify to fully load" -ForegroundColor Cyan
    }
}

function Show-SpotifyTrack {
    param([string]$Mode)
    try {
        $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
        if (-not $currentTrack) {
            Write-Host "No track currently playing" -ForegroundColor Yellow
            return
        }
        if (-not $currentTrack.item) {
            if ($currentTrack.currently_playing_type -eq "episode") {
                Write-Host "🎙️ Podcast episode is playing" -ForegroundColor Magenta
                Write-Host "   (Episode details not available from API)" -ForegroundColor Gray
            } else {
                Write-Host "No track currently playing" -ForegroundColor Yellow
            }
            return
        }
        $config = Get-SpotifyConfig
        $isCompact = ($Mode -eq "compact") -or $config.CompactMode
        $item = $currentTrack.item
        $isPlaying = $currentTrack.is_playing
        $progress = $currentTrack.progress_ms
        $duration = $item.duration_ms
        # Detect if this is a podcast episode
        $isPodcast = $item.type -eq "episode" -or ($currentTrack.currently_playing_type -eq "episode")
        if ($isCompact) {
            $playIcon = if ($isPlaying) { "▶️" } else { "⏸️" }
            $name = if ($item.name.Length -gt 25) { $item.name.Substring(0, 22) + "..." } else { $item.name }
            if ($isPodcast) {
                # Podcast episode compact display
                $showName = if ($item.show.name.Length -gt 20) { $item.show.name.Substring(0, 17) + "..." } else { $item.show.name }
                $progressBar = Show-ProgressBar -Current $progress -Total $duration -Width 15
                $timeInfo = "{0}/{1}" -f (Format-Time $progress), (Format-Time $duration)
                Write-Host "$playIcon $name" -ForegroundColor Cyan
                Write-Host "    🎙️ $showName | $progressBar $timeInfo" -ForegroundColor Magenta
            } else {
                # Music track compact display
                $artists = ($item.artists | ForEach-Object { $_.name }) -join ", "
                if ($artists.Length -gt 20) { $artists = $artists.Substring(0, 17) + "..." }
                $progressBar = Show-ProgressBar -Current $progress -Total $duration -Width 15
                $timeInfo = "{0}/{1}" -f (Format-Time $progress), (Format-Time $duration)
                Write-Host "$playIcon $name - $artists | $progressBar $timeInfo" -ForegroundColor Cyan
            }
        } else {
            if ($isPodcast) {
                # Enhanced detailed mode for podcast episodes
                Write-Host "🎙️ " -NoNewline -ForegroundColor Magenta
                Write-Host $item.name -ForegroundColor Cyan
                Write-Host "📻 " -NoNewline -ForegroundColor Yellow
                Write-Host $item.show.name -ForegroundColor Yellow
                # Show podcast description if available (truncated for readability)
                if ($item.description) {
                    $description = $item.description
                    if ($description.Length -gt 100) {
                        $description = $description.Substring(0, 97) + "..."
                    }
                    Write-Host "📝 " -NoNewline -ForegroundColor Gray
                    Write-Host $description -ForegroundColor Gray
                }
                # Show episode release date if available
                if ($item.release_date) {
                    try {
                        $releaseDate = [DateTime]::Parse($item.release_date)
                        Write-Host "📅 Released: $($releaseDate.ToString('MMM dd, yyyy'))" -ForegroundColor Gray
                    } catch {
                        Write-Host "📅 Released: $($item.release_date)" -ForegroundColor Gray
                    }
                }
                # Show episode language if available
                if ($item.language) {
                    Write-Host "🌐 Language: $($item.language.ToUpper())" -ForegroundColor Gray
                }
                # Show if episode is explicit
                if ($item.explicit) {
                    Write-Host "🔞 Explicit Content" -ForegroundColor Red
                }
                Write-Host ""  # New line after episode info
                # Progress bar for podcast episodes
                $progressBar = Show-ProgressBar -Current $progress -Total $duration
                Write-Host $progressBar -ForegroundColor Magenta
                $timeInfo = "{0} / {1}" -f (Format-Time $progress), (Format-Time $duration)
                $statusIcon = if ($isPlaying) { "▶️ Playing" } else { "⏸️ Paused" }
                Write-Host "⏱ $timeInfo $statusIcon" -ForegroundColor Gray
                # Show podcast show context
                Write-Host "💡 Podcast episode from '$($item.show.name)'" -ForegroundColor Cyan
            } else {
                # Music track detailed display
                Write-Host "🎵 " -NoNewline -ForegroundColor Cyan
                Write-Host $item.name -ForegroundColor Cyan
                Write-Host "👤 " -NoNewline -ForegroundColor Yellow
                Write-Host (($item.artists | ForEach-Object { $_.name }) -join ", ") -ForegroundColor Yellow
                Write-Host "📀 " -NoNewline -ForegroundColor Green
                Write-Host $item.album.name -ForegroundColor Green
                $progressBar = Show-ProgressBar -Current $progress -Total $duration
                Write-Host $progressBar -ForegroundColor Magenta
                $timeInfo = "{0} / {1}" -f (Format-Time $progress), (Format-Time $duration)
                $statusIcon = if ($isPlaying) { "▶️ Playing" } else { "⏸️ Paused" }
                Write-Host "⏱ $timeInfo $statusIcon" -ForegroundColor Gray
            }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message

        # Check error type based on message content
        if ($errorMessage -match "401|Unauthorized|AUTHENTICATION_ERROR") {
            Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
            Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
        elseif ($errorMessage -match "404|Not Found") {
            Write-Host "❌ Could not get current track." -ForegroundColor Red
            Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ An unexpected error occurred while getting the current track: $errorMessage" -ForegroundColor Red
        }
    }
}

function spotify-now {
    param([string]$Mode)
    Show-SpotifyTrack $Mode
}

function notifications {
    <#
    .SYNOPSIS
    Enable or disable Windows toast notifications for track changes
    .PARAMETER Arguments
    on / off / (empty = show status)
    .EXAMPLE
    notifications on
    notifications off
    notifications
    #>
    param([string]$Arguments)

    $config = Get-SpotifyConfig
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        $status = if ($config.NotificationsEnabled) { "enabled" } else { "disabled" }
        Write-Host "Notifications are currently $status" -ForegroundColor Cyan
        Write-Host "Usage: notifications <on|off>" -ForegroundColor Yellow
        return
    }

    $arg = $Arguments.ToLower().Trim()
    if ($arg -in @("on", "enable", "true")) {
        $config.NotificationsEnabled = $true
        if (Set-SpotifyConfig -Config $config) {
            Write-Host "Notifications enabled" -ForegroundColor Green
        }
    } elseif ($arg -in @("off", "disable", "false")) {
        $config.NotificationsEnabled = $false
        if (Set-SpotifyConfig -Config $config) {
            Write-Host "Notifications disabled" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Invalid argument. Use: notifications <on|off>" -ForegroundColor Red
    }
}

function Test-NotificationSupport {
    <#
    .SYNOPSIS
    Test whether Windows toast notifications are supported in this environment
    .EXAMPLE
    Test-NotificationSupport
    #>
    $result = [PSCustomObject]@{
        Supported = $false
        Method    = $null
        Reason    = $null
    }

    # Must be Windows
    if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
        $result.Reason = "Notifications require Windows"
        Write-Host "Notifications not supported: requires Windows" -ForegroundColor Yellow
        return $result
    }

    # Check for BurntToast module (preferred)
    if (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue) {
        $result.Supported = $true
        $result.Method    = "BurntToast"
        Write-Host "Notifications supported via BurntToast module" -ForegroundColor Green
        return $result
    }

    # Check for WinRT Windows.UI.Notifications (Windows 8+)
    try {
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $result.Supported = $true
        $result.Method    = "WinRT"
        Write-Host "Notifications supported via Windows Runtime (WinRT)" -ForegroundColor Green
        return $result
    } catch { }

    # Fallback: check OS version (Win 8+ = build 9200+)
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -ge 9200) {
        $result.Supported = $true
        $result.Method    = "Legacy"
        Write-Host "Notifications may be supported (Windows build $build)" -ForegroundColor Yellow
    } else {
        $result.Reason = "Windows build $build is too old (requires 9200+)"
        Write-Host "Notifications not supported on this Windows version" -ForegroundColor Red
    }
    return $result
}

function Test-SplitWindowSupport {
    <#
    .SYNOPSIS
    Check if the current terminal supports split-pane (sidecar) mode
    .DESCRIPTION
    Detects the terminal type and reports whether split-window mode is available
    for the Sidecar feature.
    .EXAMPLE
    Test-SplitWindowSupport
    #>
    $caps = Get-TerminalCapabilities
    Write-Host ""
    Write-Host "Terminal capabilities:" -ForegroundColor Cyan
    Write-Host "  Type:          $($caps.TerminalType)" -ForegroundColor White
    Write-Host "  ANSI support:  $(if ($caps.SupportsAnsi) { '✅ Yes' } else { '❌ No' })" -ForegroundColor $(if ($caps.SupportsAnsi) { 'Green' } else { 'Red' })
    Write-Host "  Split window:  $(if ($caps.SupportsSplitWindow) { '✅ Supported' } else { '❌ Not supported' })" -ForegroundColor $(if ($caps.SupportsSplitWindow) { 'Green' } else { 'Yellow' })
    Write-Host "  Interactive:   $(if ($caps.SupportsInteractiveInput) { '✅ Yes' } else { '❌ No' })" -ForegroundColor $(if ($caps.SupportsInteractiveInput) { 'Green' } else { 'Yellow' })
    if (-not $caps.SupportsSplitWindow) {
        Write-Host ""
        Write-Host "  Tip: Run inside Windows Terminal to enable sidecar mode." -ForegroundColor Gray
    }
    Write-Host ""
    return $caps.SupportsSplitWindow
}

function Get-SpotifyCliTroubleshootingGuide {
    <#
    .SYNOPSIS
    Display a troubleshooting guide for common Spotify CLI issues
    .PARAMETER Issue
    Category to show: Auth, API, Module, Playback, Lyrics, or All (default)
    .EXAMPLE
    Get-SpotifyCliTroubleshootingGuide
    Get-SpotifyCliTroubleshootingGuide -Issue Auth
    #>
    param(
        [ValidateSet("Auth", "API", "Module", "Playback", "Lyrics", "All")]
        [string]$Issue = "All"
    )

    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   Spotify CLI — Troubleshooting Guide                ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $showAll = $Issue -eq "All"

    if ($showAll -or $Issue -eq "Auth") {
        Write-Host "── Authentication ──────────────────────────────────────" -ForegroundColor Yellow
        Write-Host "❌ Problem: 'Not authenticated' or token errors" -ForegroundColor White
        Write-Host "🔧 Fix:     Run .\spotifyCLI.ps1 to trigger OAuth flow" -ForegroundColor Gray
        Write-Host "           Delete $env:APPDATA\SpotifyCLI\tokens.json and re-run" -ForegroundColor Gray
        Write-Host "           Verify SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET in .env" -ForegroundColor Gray
        Write-Host "✅ Check:   Test-SpotifyAuth" -ForegroundColor Green
        Write-Host ""
    }

    if ($showAll -or $Issue -eq "API") {
        Write-Host "── Spotify API ─────────────────────────────────────────" -ForegroundColor Yellow
        Write-Host "❌ Problem: 403 Forbidden / 'Premium required'" -ForegroundColor White
        Write-Host "🔧 Fix:     A Spotify Premium account is required for playback control" -ForegroundColor Gray
        Write-Host "❌ Problem: 404 / No active device" -ForegroundColor White
        Write-Host "🔧 Fix:     Open Spotify on any device and start playing something first" -ForegroundColor Gray
        Write-Host "           Run /devices to see available devices" -ForegroundColor Gray
        Write-Host "❌ Problem: 429 Too many requests" -ForegroundColor White
        Write-Host "🔧 Fix:     Wait 30 seconds. Avoid running multiple quiz rounds rapidly." -ForegroundColor Gray
        Write-Host ""
    }

    if ($showAll -or $Issue -eq "Module") {
        Write-Host "── Module Loading ──────────────────────────────────────" -ForegroundColor Yellow
        Write-Host "❌ Problem: 'Function not found' errors" -ForegroundColor White
        Write-Host "🔧 Fix:     Re-run the installer: .\Install-SpotifyCLI-Complete.ps1" -ForegroundColor Gray
        Write-Host "           Or repair: Repair-SpotifyCliInstallation" -ForegroundColor Gray
        Write-Host "❌ Problem: Module won't import" -ForegroundColor White
        Write-Host "🔧 Fix:     Check PowerShell version (requires 5.0+): `$PSVersionTable.PSVersion" -ForegroundColor Gray
        Write-Host "           Verify all .psm1 files exist: Install-SpotifyCliDependencies" -ForegroundColor Gray
        Write-Host ""
    }

    if ($showAll -or $Issue -eq "Playback") {
        Write-Host "── Playback ────────────────────────────────────────────" -ForegroundColor Yellow
        Write-Host "❌ Problem: Commands run but nothing happens" -ForegroundColor White
        Write-Host "🔧 Fix:     Open Spotify and start playing on a device first" -ForegroundColor Gray
        Write-Host "           Transfer playback: /transfer (pick a device number)" -ForegroundColor Gray
        Write-Host "❌ Problem: Quiz doesn't play audio" -ForegroundColor White
        Write-Host "🔧 Fix:     Spotify must be open and playing on an active device" -ForegroundColor Gray
        Write-Host "           Premium required for playback control via API" -ForegroundColor Gray
        Write-Host ""
    }

    if ($showAll -or $Issue -eq "Lyrics") {
        Write-Host "── Lyrics ──────────────────────────────────────────────" -ForegroundColor Yellow
        Write-Host "❌ Problem: Lyrics not showing / wrong lyrics" -ForegroundColor White
        Write-Host "🔧 Fix:     LRCLIB is the primary source (free, no key needed)" -ForegroundColor Gray
        Write-Host "           Add GENIUS_ACCESS_TOKEN to .env for fallback" -ForegroundColor Gray
        Write-Host "❌ Problem: Lyrics window doesn't open" -ForegroundColor White
        Write-Host "🔧 Fix:     Requires Windows (uses WinForms)" -ForegroundColor Gray
        Write-Host "           Check that pwsh.exe is in PATH" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "For more help: https://github.com/spotify-cli/enhanced" -ForegroundColor DarkGray
    Write-Host ""
}

Export-ModuleMember -Function @(
    'Start-SpotifyApp',
    'Show-SpotifyTrack',
    'spotify-now',
    'notifications',
    'Test-NotificationSupport',
    'Test-SplitWindowSupport',
    'Get-SpotifyCliTroubleshootingGuide'
)
