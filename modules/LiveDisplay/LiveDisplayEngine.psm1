# Live Display Engine Module
# Provides real-time display updates and terminal manipulation for Spotify CLI

using namespace System.Management.Automation
using namespace System.Text
using namespace System.Management.Automation.Runspaces

# ANSI Escape Codes and Console Utilities
class AnsiCodes {
    static [string] $Reset = "`e[0m"
    static [string] $Bold = "`e[1m"
    static [string] $Dim = "`e[2m"
    static [string] $Italic = "`e[3m"
    static [string] $Underline = "`e[4m"
    static [string] $Blink = "`e[5m"
    static [string] $Reverse = "`e[7m"
    static [string] $Strikethrough = "`e[9m"
    
    # Cursor movement
    static [string] $CursorHome = "`e[H"
    static [string] $CursorUp = "`e[A"
    static [string] $CursorDown = "`e[B"
    static [string] $CursorRight = "`e[C"
    static [string] $CursorLeft = "`e[D"
    static [string] $SaveCursor = "`e[s"
    static [string] $RestoreCursor = "`e[u"
    static [string] $HideCursor = "`e[?25l"
    static [string] $ShowCursor = "`e[?25h"
    
    # Screen manipulation
    static [string] $ClearScreen = "`e[2J"
    static [string] $ClearLine = "`e[2K"
    static [string] $ClearToEnd = "`e[0K"
    static [string] $ClearToStart = "`e[1K"
    
    # Colors
    static [hashtable] $Colors = @{
        Black = "`e[30m"; Red = "`e[31m"; Green = "`e[32m"; Yellow = "`e[33m"
        Blue = "`e[34m"; Magenta = "`e[35m"; Cyan = "`e[36m"; White = "`e[37m"
        BrightBlack = "`e[90m"; BrightRed = "`e[91m"; BrightGreen = "`e[92m"
        BrightYellow = "`e[93m"; BrightBlue = "`e[94m"; BrightMagenta = "`e[95m"
        BrightCyan = "`e[96m"; BrightWhite = "`e[97m"
    }
    
    static [hashtable] $BackgroundColors = @{
        Black = "`e[40m"; Red = "`e[41m"; Green = "`e[42m"; Yellow = "`e[43m"
        Blue = "`e[44m"; Magenta = "`e[45m"; Cyan = "`e[46m"; White = "`e[47m"
        BrightBlack = "`e[100m"; BrightRed = "`e[101m"; BrightGreen = "`e[102m"
        BrightYellow = "`e[103m"; BrightBlue = "`e[104m"; BrightMagenta = "`e[105m"
        BrightCyan = "`e[106m"; BrightWhite = "`e[107m"
    }
    
    static [string] MoveCursor([int]$row, [int]$col) {
        return "`e[$row;${col}H"
    }
    
    static [string] MoveCursorUp([int]$lines) {
        return "`e[${lines}A"
    }
    
    static [string] MoveCursorDown([int]$lines) {
        return "`e[${lines}B"
    }
    
    static [string] MoveCursorRight([int]$cols) {
        return "`e[${cols}C"
    }
    
    static [string] MoveCursorLeft([int]$cols) {
        return "`e[${cols}D"
    }
}

# Progress bar styles enumeration
enum ProgressBarStyle {
    Blocks
    Bars
    Dots
    Arrows
    Circles
}

# Console Renderer class with ANSI escape code support
class ConsoleRenderer {
    [bool] $AnsiSupported = $false
    [hashtable] $SavedCursorPosition = @{}
    [StringBuilder] $DisplayBuffer
    [int] $TerminalWidth = 80
    [int] $TerminalHeight = 24
    [ProgressBarStyle] $DefaultProgressStyle = [ProgressBarStyle]::Blocks
    
    # Progress bar character sets
    [hashtable] $ProgressChars = @{
        [ProgressBarStyle]::Blocks = @{ Filled = "█"; Empty = "░"; Partial = @("▏","▎","▍","▌","▋","▊","▉") }
        [ProgressBarStyle]::Bars = @{ Filled = "="; Empty = "-"; Partial = @() }
        [ProgressBarStyle]::Dots = @{ Filled = "●"; Empty = "○"; Partial = @() }
        [ProgressBarStyle]::Arrows = @{ Filled = "►"; Empty = "▷"; Partial = @() }
        [ProgressBarStyle]::Circles = @{ Filled = "⬤"; Empty = "⬜"; Partial = @() }
    }
    
    ConsoleRenderer() {
        $this.DisplayBuffer = [StringBuilder]::new()
        $this.DetectAnsiSupport()
        $this.DetectTerminalSize()
    }
    
    [void] DetectAnsiSupport() {
        try {
            # Test ANSI support by attempting to query cursor position
            $originalPos = $Host.UI.RawUI.CursorPosition
            [Console]::Write([AnsiCodes]::SaveCursor)
            [Console]::Write([AnsiCodes]::RestoreCursor)
            $this.AnsiSupported = $true
        } catch {
            $this.AnsiSupported = $false
        }
    }
    
    [void] DetectTerminalSize() {
        try {
            $this.TerminalWidth = $Host.UI.RawUI.WindowSize.Width
            $this.TerminalHeight = $Host.UI.RawUI.WindowSize.Height
        } catch {
            # Fallback to default values
            $this.TerminalWidth = 80
            $this.TerminalHeight = 24
        }
    }
    
    [void] InitializeLiveMode() {
        if ($this.AnsiSupported) {
            $this.DisplayBuffer.Append([AnsiCodes]::SaveCursor) | Out-Null
            $this.DisplayBuffer.Append([AnsiCodes]::HideCursor) | Out-Null
            $this.DisplayBuffer.Append([AnsiCodes]::ClearScreen) | Out-Null
            $this.DisplayBuffer.Append([AnsiCodes]::CursorHome) | Out-Null
        } else {
            Clear-Host
        }
        $this.FlushBuffer()
    }
    
    [void] CleanupAndExit() {
        if ($this.AnsiSupported) {
            $this.DisplayBuffer.Append([AnsiCodes]::ShowCursor) | Out-Null
            $this.DisplayBuffer.Append([AnsiCodes]::RestoreCursor) | Out-Null
            $this.DisplayBuffer.Append([AnsiCodes]::Reset) | Out-Null
        }
        $this.FlushBuffer()
    }
    
    [void] ClearScreen() {
        if ($this.AnsiSupported) {
            $this.DisplayBuffer.Append([AnsiCodes]::ClearScreen) | Out-Null
            $this.DisplayBuffer.Append([AnsiCodes]::CursorHome) | Out-Null
        } else {
            Clear-Host
        }
    }
    
    [void] MoveCursor([int]$row, [int]$col) {
        if ($this.AnsiSupported) {
            $this.DisplayBuffer.Append([AnsiCodes]::MoveCursor($row, $col)) | Out-Null
        }
    }
    
    [void] SaveCursorPosition() {
        if ($this.AnsiSupported) {
            $this.DisplayBuffer.Append([AnsiCodes]::SaveCursor) | Out-Null
        } else {
            try {
                $this.SavedCursorPosition = @{
                    X = $Host.UI.RawUI.CursorPosition.X
                    Y = $Host.UI.RawUI.CursorPosition.Y
                }
            } catch {
                # Ignore if cursor position cannot be saved
            }
        }
    }
    
    [void] RestoreCursorPosition() {
        if ($this.AnsiSupported) {
            $this.DisplayBuffer.Append([AnsiCodes]::RestoreCursor) | Out-Null
        } else {
            try {
                if ($this.SavedCursorPosition.Count -gt 0) {
                    $Host.UI.RawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new(
                        $this.SavedCursorPosition.X, $this.SavedCursorPosition.Y
                    )
                }
            } catch {
                # Ignore if cursor position cannot be restored
            }
        }
    }
    
    [void] WriteColoredText([string]$text, [string]$color, [string]$backgroundColor = "") {
        if ($this.AnsiSupported) {
            if ([AnsiCodes]::Colors.ContainsKey($color)) {
                $this.DisplayBuffer.Append([AnsiCodes]::Colors[$color]) | Out-Null
            }
            if ($backgroundColor -and [AnsiCodes]::BackgroundColors.ContainsKey($backgroundColor)) {
                $this.DisplayBuffer.Append([AnsiCodes]::BackgroundColors[$backgroundColor]) | Out-Null
            }
            $this.DisplayBuffer.Append($text) | Out-Null
            $this.DisplayBuffer.Append([AnsiCodes]::Reset) | Out-Null
        } else {
            $this.DisplayBuffer.Append($text) | Out-Null
        }
    }
    
    [void] WriteLine([string]$text = "") {
        $this.DisplayBuffer.AppendLine($text) | Out-Null
    }
    
    [void] Write([string]$text) {
        $this.DisplayBuffer.Append($text) | Out-Null
    }
    
    [string] CreateProgressBar([int]$current, [int]$total, [int]$width = 40, [ProgressBarStyle]$style = [ProgressBarStyle]::Blocks) {
        if ($total -le 0) { return "" }
        
        $percentage = [Math]::Min(100, [Math]::Max(0, ($current / $total) * 100))
        $filled = [Math]::Floor(($percentage / 100) * $width)
        $empty = $width - $filled
        
        $chars = $this.ProgressChars[$style]
        $filledChar = $chars.Filled
        $emptyChar = $chars.Empty
        
        # Handle partial characters for block style
        if ($style -eq [ProgressBarStyle]::Blocks -and $chars.Partial.Count -gt 0) {
            $remainder = (($percentage / 100) * $width) - $filled
            if ($remainder -gt 0 -and $empty -gt 0) {
                $partialIndex = [Math]::Floor($remainder * $chars.Partial.Count)
                if ($partialIndex -lt $chars.Partial.Count) {
                    $partialChar = $chars.Partial[$partialIndex]
                    return ($filledChar * $filled) + $partialChar + ($emptyChar * ($empty - 1))
                }
            }
        }
        
        return ($filledChar * $filled) + ($emptyChar * $empty)
    }
    
    [void] UpdateProgressBar([int]$current, [int]$total, [string]$trackName = "", [ProgressBarStyle]$style = [ProgressBarStyle]::Blocks) {
        $width = [Math]::Min(60, $this.TerminalWidth - 20)
        $progressBar = $this.CreateProgressBar($current, $total, $width, $style)
        $percentage = if ($total -gt 0) { [Math]::Round(($current / $total) * 100) } else { 0 }
        
        $currentTime = $this.FormatDuration($current)
        $totalTime = $this.FormatDuration($total)
        
        if ($trackName) {
            $this.WriteColoredText("♪ $trackName", "Cyan")
            $this.WriteLine()
        }
        
        $this.WriteColoredText("[$progressBar]", "Magenta")
        $this.Write(" $percentage%")
        $this.WriteLine()
        $this.WriteColoredText("$currentTime / $totalTime", "Gray")
        $this.WriteLine()
    }
    
    [void] UpdateTrackInfo([hashtable]$trackData) {
        if (-not $trackData -or -not $trackData.ContainsKey('name')) {
            $this.WriteColoredText("No track information available", "Yellow")
            $this.WriteLine()
            return
        }
        
        $isPlaying = $trackData.ContainsKey('is_playing') ? $trackData.is_playing : $false
        $statusIcon = if ($isPlaying) { "▶" } else { "⏸" }
        
        # Track status and name
        $this.WriteColoredText("$statusIcon Now Playing:", "Cyan")
        $this.WriteLine()
        $this.WriteColoredText("🎵 $($trackData.name)", "White")
        $this.WriteLine()
        
        # Artist information
        if ($trackData.ContainsKey('artists') -and $trackData.artists) {
            $artists = if ($trackData.artists -is [array]) {
                ($trackData.artists | ForEach-Object { if ($_ -is [hashtable]) { $_.name } else { $_ } }) -join ", "
            } else {
                $trackData.artists
            }
            $this.WriteColoredText("👤 $artists", "Yellow")
            $this.WriteLine()
        }
        
        # Album information
        if ($trackData.ContainsKey('album') -and $trackData.album) {
            $albumName = if ($trackData.album -is [hashtable]) { $trackData.album.name } else { $trackData.album }
            $this.WriteColoredText("📀 $albumName", "Green")
            $this.WriteLine()
        }
        
        # Progress bar
        if ($trackData.ContainsKey('duration_ms') -and $trackData.duration_ms -gt 0) {
            $progress = $trackData.ContainsKey('progress_ms') ? $trackData.progress_ms : 0
            $this.WriteLine()
            $this.UpdateProgressBar($progress, $trackData.duration_ms, "", $this.DefaultProgressStyle)
        }
    }
    
    [string] FormatDuration([int]$milliseconds) {
        $totalSeconds = [Math]::Floor($milliseconds / 1000)
        $minutes = [Math]::Floor($totalSeconds / 60)
        $seconds = $totalSeconds % 60
        return "{0}:{1:D2}" -f $minutes, $seconds
    }
    
    [void] SetDisplayMode([string]$mode) {
        switch ($mode.ToLower()) {
            "minimal" { $this.DefaultProgressStyle = [ProgressBarStyle]::Dots }
            "detailed" { $this.DefaultProgressStyle = [ProgressBarStyle]::Blocks }
            "compact" { $this.DefaultProgressStyle = [ProgressBarStyle]::Bars }
            default { $this.DefaultProgressStyle = [ProgressBarStyle]::Blocks }
        }
    }
    
    [void] FlushBuffer() {
        if ($this.DisplayBuffer.Length -gt 0) {
            [Console]::Write($this.DisplayBuffer.ToString())
            $this.DisplayBuffer.Clear()
        }
    }
    
    [void] ClearCurrentLine() {
        if ($this.AnsiSupported) {
            $this.DisplayBuffer.Append([AnsiCodes]::ClearLine) | Out-Null
        }
    }
    
    [hashtable] GetTerminalInfo() {
        return @{
            Width = $this.TerminalWidth
            Height = $this.TerminalHeight
            AnsiSupported = $this.AnsiSupported
            ProgressStyles = [Enum]::GetNames([ProgressBarStyle])
        }
    }
}

# Background Thread Manager for live updates
class BackgroundThreadManager {
    [Runspace] $UpdateRunspace
    [PowerShell] $UpdatePowerShell
    [System.Threading.CancellationTokenSource] $CancellationTokenSource
    [System.Threading.ManualResetEventSlim] $ShutdownEvent
    [bool] $IsRunning = $false
    [scriptblock] $UpdateCallback
    [int] $UpdateInterval = 1000
    [hashtable] $SharedData
    [System.Threading.Mutex] $DataMutex
    
    BackgroundThreadManager([scriptblock]$updateCallback, [int]$intervalMs = 1000) {
        $this.UpdateCallback = $updateCallback
        $this.UpdateInterval = $intervalMs
        $this.CancellationTokenSource = [System.Threading.CancellationTokenSource]::new()
        $this.ShutdownEvent = [System.Threading.ManualResetEventSlim]::new($false)
        $this.SharedData = @{}
        $this.DataMutex = [System.Threading.Mutex]::new()
    }
    
    [void] Start() {
        if ($this.IsRunning) {
            return
        }
        
        try {
            # Create a new runspace for background updates
            $this.UpdateRunspace = [RunspaceFactory]::CreateRunspace()
            $this.UpdateRunspace.Open()
            
            # Create PowerShell instance
            $this.UpdatePowerShell = [PowerShell]::Create()
            $this.UpdatePowerShell.Runspace = $this.UpdateRunspace
            
            # Set up the background update script
            $updateScript = {
                param(
                    [scriptblock]$Callback,
                    [int]$Interval,
                    [System.Threading.CancellationToken]$CancellationToken,
                    [System.Threading.ManualResetEventSlim]$ShutdownEvent,
                    [hashtable]$SharedData,
                    [System.Threading.Mutex]$DataMutex
                )
                
                try {
                    while (-not $CancellationToken.IsCancellationRequested) {
                        try {
                            # Execute the update callback
                            $result = & $Callback
                            
                            # Update shared data thread-safely
                            if ($result -and $DataMutex.WaitOne(100)) {
                                try {
                                    $SharedData.Clear()
                                    if ($result -is [hashtable]) {
                                        foreach ($key in $result.Keys) {
                                            $SharedData[$key] = $result[$key]
                                        }
                                    }
                                } finally {
                                    $DataMutex.ReleaseMutex()
                                }
                            }
                            
                            # Wait for the specified interval or cancellation
                            if (-not $CancellationToken.WaitHandle.WaitOne($Interval)) {
                                # Continue if not cancelled
                            }
                        } catch {
                            # Log error but continue running
                            Write-Warning "Background update error: $($_.Exception.Message)"
                            Start-Sleep -Milliseconds 1000
                        }
                    }
                } finally {
                    $ShutdownEvent.Set()
                }
            }
            
            # Add parameters and start the background script
            $this.UpdatePowerShell.AddScript($updateScript) | Out-Null
            $this.UpdatePowerShell.AddParameter("Callback", $this.UpdateCallback) | Out-Null
            $this.UpdatePowerShell.AddParameter("Interval", $this.UpdateInterval) | Out-Null
            $this.UpdatePowerShell.AddParameter("CancellationToken", $this.CancellationTokenSource.Token) | Out-Null
            $this.UpdatePowerShell.AddParameter("ShutdownEvent", $this.ShutdownEvent) | Out-Null
            $this.UpdatePowerShell.AddParameter("SharedData", $this.SharedData) | Out-Null
            $this.UpdatePowerShell.AddParameter("DataMutex", $this.DataMutex) | Out-Null
            
            # Start the background execution
            $this.UpdatePowerShell.BeginInvoke() | Out-Null
            $this.IsRunning = $true
            
        } catch {
            $this.Cleanup()
            throw "Failed to start background thread: $($_.Exception.Message)"
        }
    }
    
    [void] Stop() {
        if (-not $this.IsRunning) {
            return
        }
        
        try {
            # Signal cancellation
            $this.CancellationTokenSource.Cancel()
            
            # Wait for shutdown with timeout
            if (-not $this.ShutdownEvent.Wait(5000)) {
                Write-Warning "Background thread did not shut down gracefully within timeout"
            }
            
            $this.IsRunning = $false
        } catch {
            Write-Warning "Error stopping background thread: $($_.Exception.Message)"
        } finally {
            $this.Cleanup()
        }
    }
    
    [hashtable] GetSharedData() {
        $result = @{}
        
        if ($this.DataMutex.WaitOne(100)) {
            try {
                foreach ($key in $this.SharedData.Keys) {
                    $result[$key] = $this.SharedData[$key]
                }
            } finally {
                $this.DataMutex.ReleaseMutex()
            }
        }
        
        return $result
    }
    
    [void] SetSharedData([hashtable]$data) {
        if ($this.DataMutex.WaitOne(100)) {
            try {
                $this.SharedData.Clear()
                foreach ($key in $data.Keys) {
                    $this.SharedData[$key] = $data[$key]
                }
            } finally {
                $this.DataMutex.ReleaseMutex()
            }
        }
    }
    
    [bool] IsHealthy() {
        return $this.IsRunning -and 
               $this.UpdatePowerShell -and 
               $this.UpdatePowerShell.InvocationStateInfo.State -eq [PSInvocationState]::Running
    }
    
    [void] Cleanup() {
        try {
            if ($this.UpdatePowerShell) {
                if ($this.UpdatePowerShell.InvocationStateInfo.State -eq [PSInvocationState]::Running) {
                    $this.UpdatePowerShell.Stop()
                }
                $this.UpdatePowerShell.Dispose()
                $this.UpdatePowerShell = $null
            }
            
            if ($this.UpdateRunspace) {
                $this.UpdateRunspace.Close()
                $this.UpdateRunspace.Dispose()
                $this.UpdateRunspace = $null
            }
            
            if ($this.CancellationTokenSource) {
                $this.CancellationTokenSource.Dispose()
                $this.CancellationTokenSource = $null
            }
            
            if ($this.ShutdownEvent) {
                $this.ShutdownEvent.Dispose()
                $this.ShutdownEvent = $null
            }
            
            if ($this.DataMutex) {
                $this.DataMutex.Dispose()
                $this.DataMutex = $null
            }
        } catch {
            Write-Warning "Error during cleanup: $($_.Exception.Message)"
        }
    }
}

# Ctrl+C Handler for graceful shutdown
class GracefulShutdownHandler {
    [BackgroundThreadManager] $ThreadManager
    [ConsoleRenderer] $Renderer
    [bool] $ShutdownRequested = $false
    [System.ConsoleCancelEventHandler] $CancelHandler
    
    GracefulShutdownHandler([BackgroundThreadManager]$threadManager, [ConsoleRenderer]$renderer) {
        $this.ThreadManager = $threadManager
        $this.Renderer = $renderer
        
        # Create the cancel event handler
        $this.CancelHandler = {
            param($sender, $e)
            
            # Prevent immediate termination
            $e.Cancel = $true
            
            # Set shutdown flag
            $this.ShutdownRequested = $true
            
            # Initiate graceful shutdown
            $this.InitiateShutdown()
        }.GetNewClosure()
    }
    
    [void] Register() {
        try {
            [Console]::CancelKeyPress += $this.CancelHandler
        } catch {
            Write-Warning "Could not register Ctrl+C handler: $($_.Exception.Message)"
        }
    }
    
    [void] Unregister() {
        try {
            if ($this.CancelHandler) {
                [Console]::CancelKeyPress -= $this.CancelHandler
            }
        } catch {
            Write-Warning "Could not unregister Ctrl+C handler: $($_.Exception.Message)"
        }
    }
    
    [void] InitiateShutdown() {
        if ($this.ShutdownRequested) {
            return
        }
        
        $this.ShutdownRequested = $true
        
        try {
            # Show shutdown message
            if ($this.Renderer) {
                $this.Renderer.WriteLine()
                $this.Renderer.WriteColoredText("Shutting down gracefully...", "Yellow")
                $this.Renderer.WriteLine()
                $this.Renderer.FlushBuffer()
            }
            
            # Stop background thread
            if ($this.ThreadManager) {
                $this.ThreadManager.Stop()
            }
            
            # Cleanup renderer
            if ($this.Renderer) {
                $this.Renderer.CleanupAndExit()
            }
            
        } catch {
            Write-Warning "Error during graceful shutdown: $($_.Exception.Message)"
        } finally {
            $this.Unregister()
        }
    }
    
    [bool] ShouldExit() {
        return $this.ShutdownRequested
    }
}

# Windows Terminal Integration Module
class WindowsTerminalIntegrator {
    [bool] $IsWindowsTerminal = $false
    [string] $TerminalExecutable = "wt.exe"
    [hashtable] $SidecarConfig = @{}
    [string] $SidecarPaneId = ""
    [bool] $SidecarActive = $false
    
    WindowsTerminalIntegrator() {
        $this.DetectWindowsTerminal()
    }
    
    [void] DetectWindowsTerminal() {
        try {
            # Check if running in Windows Terminal by examining environment variables
            $wtSession = $env:WT_SESSION
            $wtProfile = $env:WT_PROFILE_ID
            
            if ($wtSession -or $wtProfile) {
                $this.IsWindowsTerminal = $true
                return
            }
            
            # Alternative detection: check parent process
            $parentProcess = Get-WmiObject Win32_Process -Filter "ProcessId=$PID" | 
                            ForEach-Object { Get-Process -Id $_.ParentProcessId -ErrorAction SilentlyContinue }
            
            if ($parentProcess -and $parentProcess.ProcessName -eq "WindowsTerminal") {
                $this.IsWindowsTerminal = $true
                return
            }
            
            # Check if wt.exe is available
            $wtPath = Get-Command "wt.exe" -ErrorAction SilentlyContinue
            if ($wtPath) {
                $this.IsWindowsTerminal = $true
            }
            
        } catch {
            $this.IsWindowsTerminal = $false
        }
    }
    
    [bool] IsSupported() {
        return $this.IsWindowsTerminal
    }
    
    [hashtable] GetCapabilities() {
        return @{
            IsWindowsTerminal = $this.IsWindowsTerminal
            SupportsSplitPane = $this.IsWindowsTerminal
            SupportsTabManagement = $this.IsWindowsTerminal
            TerminalExecutable = $this.TerminalExecutable
        }
    }
    
    [bool] CreateSidecarPane([string]$position = "right", [int]$size = 40) {
        if (-not $this.IsWindowsTerminal) {
            Write-Warning "Windows Terminal not detected. Sidecar mode not available."
            return $false
        }
        
        try {
            $sizeParam = if ($position -in @("left", "right")) { "--size", $size } else { "--size", $size }
            $splitDirection = switch ($position.ToLower()) {
                "right" { "--horizontal" }
                "left" { "--horizontal" }
                "bottom" { "--vertical" }
                "top" { "--vertical" }
                default { "--horizontal" }
            }
            
            # Create new pane with PowerShell
            $wtArgs = @(
                "split-pane",
                $splitDirection,
                $sizeParam,
                "--profile", "PowerShell",
                "--commandline", "powershell.exe -NoExit -Command `"Write-Host 'Spotify Live Display - Sidecar Mode' -ForegroundColor Cyan`""
            )
            
            $process = Start-Process -FilePath $this.TerminalExecutable -ArgumentList $wtArgs -PassThru -WindowStyle Hidden
            
            if ($process) {
                $this.SidecarActive = $true
                $this.SidecarConfig = @{
                    Position = $position
                    Size = $size
                    ProcessId = $process.Id
                }
                
                # Wait a moment for pane to be created
                Start-Sleep -Milliseconds 500
                return $true
            }
            
        } catch {
            Write-Warning "Failed to create sidecar pane: $($_.Exception.Message)"
            return $false
        }
        
        return $false
    }
    
    [void] SendToSidecar([string]$content) {
        if (-not $this.SidecarActive) {
            return
        }
        
        try {
            # Use wt.exe to send content to the active pane
            # Note: This is a simplified approach. In practice, you might need more sophisticated
            # inter-process communication or use Windows Terminal's command palette features
            
            $escapedContent = $content -replace '"', '\"'
            $command = "Write-Host `"$escapedContent`""
            
            $wtArgs = @(
                "send-text",
                "--pane-id", "1",  # Assuming sidecar is pane 1
                $command
            )
            
            Start-Process -FilePath $this.TerminalExecutable -ArgumentList $wtArgs -WindowStyle Hidden -Wait
            
        } catch {
            Write-Warning "Failed to send content to sidecar: $($_.Exception.Message)"
        }
    }
    
    [void] UpdateSidecarContent([hashtable]$trackData) {
        if (-not $this.SidecarActive -or -not $trackData) {
            return
        }
        
        try {
            # Build sidecar display content
            $content = $this.BuildSidecarDisplay($trackData)
            
            # Clear and update sidecar
            $this.SendToSidecar("Clear-Host")
            $this.SendToSidecar($content)
            
        } catch {
            Write-Warning "Failed to update sidecar content: $($_.Exception.Message)"
        }
    }
    
    [string] BuildSidecarDisplay([hashtable]$trackData) {
        $sb = [System.Text.StringBuilder]::new()
        
        # Header
        $sb.AppendLine("╔══════════════════════════════════════╗") | Out-Null
        $sb.AppendLine("║          Spotify Live Display       ║") | Out-Null
        $sb.AppendLine("╠══════════════════════════════════════╣") | Out-Null
        
        # Track info
        if ($trackData.ContainsKey('name')) {
            $trackName = $trackData.name
            if ($trackName.Length -gt 34) {
                $trackName = $trackName.Substring(0, 31) + "..."
            }
            $sb.AppendLine("║ 🎵 $($trackName.PadRight(32)) ║") | Out-Null
        }
        
        if ($trackData.ContainsKey('artists')) {
            $artists = if ($trackData.artists -is [array]) {
                ($trackData.artists | ForEach-Object { if ($_ -is [hashtable]) { $_.name } else { $_ } }) -join ", "
            } else {
                $trackData.artists
            }
            
            if ($artists.Length -gt 34) {
                $artists = $artists.Substring(0, 31) + "..."
            }
            $sb.AppendLine("║ 👤 $($artists.PadRight(32)) ║") | Out-Null
        }
        
        if ($trackData.ContainsKey('album')) {
            $album = if ($trackData.album -is [hashtable]) { $trackData.album.name } else { $trackData.album }
            if ($album.Length -gt 34) {
                $album = $album.Substring(0, 31) + "..."
            }
            $sb.AppendLine("║ 📀 $($album.PadRight(32)) ║") | Out-Null
        }
        
        # Progress bar
        if ($trackData.ContainsKey('duration_ms') -and $trackData.duration_ms -gt 0) {
            $progress = $trackData.ContainsKey('progress_ms') ? $trackData.progress_ms : 0
            $percentage = [Math]::Round(($progress / $trackData.duration_ms) * 100)
            
            $barWidth = 30
            $filled = [Math]::Floor(($percentage / 100) * $barWidth)
            $empty = $barWidth - $filled
            
            $progressBar = ("█" * $filled) + ("░" * $empty)
            $sb.AppendLine("║ [$progressBar] ║") | Out-Null
            
            $currentTime = $this.FormatDuration($progress)
            $totalTime = $this.FormatDuration($trackData.duration_ms)
            $timeDisplay = "$currentTime / $totalTime ($percentage%)"
            $sb.AppendLine("║ $($timeDisplay.PadRight(36)) ║") | Out-Null
        }
        
        # Status
        $isPlaying = $trackData.ContainsKey('is_playing') ? $trackData.is_playing : $false
        $status = if ($isPlaying) { "▶ Playing" } else { "⏸ Paused" }
        $sb.AppendLine("║ $($status.PadRight(36)) ║") | Out-Null
        
        # Footer
        $sb.AppendLine("╚══════════════════════════════════════╝") | Out-Null
        
        return $sb.ToString()
    }
    
    [string] FormatDuration([int]$milliseconds) {
        $totalSeconds = [Math]::Floor($milliseconds / 1000)
        $minutes = [Math]::Floor($totalSeconds / 60)
        $seconds = $totalSeconds % 60
        return "{0}:{1:D2}" -f $minutes, $seconds
    }
    
    [void] CloseSidecar() {
        if (-not $this.SidecarActive) {
            return
        }
        
        try {
            # Close the sidecar pane
            $wtArgs = @("close-pane", "--pane-id", "1")
            Start-Process -FilePath $this.TerminalExecutable -ArgumentList $wtArgs -WindowStyle Hidden -Wait
            
            $this.SidecarActive = $false
            $this.SidecarConfig = @{}
            
        } catch {
            Write-Warning "Failed to close sidecar pane: $($_.Exception.Message)"
        }
    }
    
    [hashtable] GetSidecarStatus() {
        return @{
            Active = $this.SidecarActive
            Configuration = $this.SidecarConfig
            IsSupported = $this.IsWindowsTerminal
        }
    }
}

# Sidecar Display Engine for Windows Terminal
class SidecarDisplayEngine : LiveDisplayEngineBase {
    [WindowsTerminalIntegrator] $TerminalIntegrator
    [hashtable] $SidecarConfig = @{}
    [string] $Position = "right"
    [int] $Size = 40
    
    SidecarDisplayEngine([hashtable]$config) : base($config) {
        if ($config.ContainsKey('Position')) {
            $this.Position = $config.Position
        }
        if ($config.ContainsKey('Size')) {
            $this.Size = $config.Size
        }
        
        $this.TerminalIntegrator = [WindowsTerminalIntegrator]::new()
    }
    
    [void] ValidateConfiguration() {
        $validPositions = @("left", "right", "top", "bottom")
        if ($this.Position -notin $validPositions) {
            throw [System.ArgumentException]::new("Position must be one of: $($validPositions -join ', ')")
        }
        
        if ($this.Size -lt 20 -or $this.Size -gt 80) {
            throw [System.ArgumentException]::new("Size must be between 20 and 80")
        }
    }
    
    [void] InitializeDisplay() {
        if (-not $this.TerminalIntegrator.IsSupported()) {
            throw [System.NotSupportedException]::new("Windows Terminal not detected. Sidecar mode requires Windows Terminal.")
        }
        
        $success = $this.TerminalIntegrator.CreateSidecarPane($this.Position, $this.Size)
        if (-not $success) {
            throw [System.InvalidOperationException]::new("Failed to create sidecar pane")
        }
    }
    
    [void] UpdateDisplay([hashtable]$data) {
        if ($data -and $data.ContainsKey('track')) {
            $trackData = $data.track.Clone()
            
            # Add playback state information
            if ($data.ContainsKey('is_playing')) {
                $trackData['is_playing'] = $data.is_playing
            }
            if ($data.ContainsKey('progress_ms')) {
                $trackData['progress_ms'] = $data.progress_ms
            }
            
            $this.TerminalIntegrator.UpdateSidecarContent($trackData)
        }
    }
    
    [void] CleanupDisplay() {
        $this.TerminalIntegrator.CloseSidecar()
    }
    
    [bool] IsSupported() {
        return $this.TerminalIntegrator.IsSupported()
    }
    
    [hashtable] GetCapabilities() {
        return $this.TerminalIntegrator.GetCapabilities()
    }
    
    [hashtable] GetSidecarStatus() {
        return $this.TerminalIntegrator.GetSidecarStatus()
    }
}

# Base interface for all display engines
class IDisplayEngine {
    [void] Initialize() { throw [System.NotImplementedException]::new() }
    [void] Update([hashtable]$data) { throw [System.NotImplementedException]::new() }
    [void] Cleanup() { throw [System.NotImplementedException]::new() }
    [bool] IsSupported() { throw [System.NotImplementedException]::new() }
}

# Abstract base class for live display implementations
class LiveDisplayEngineBase : IDisplayEngine {
    [bool] $IsInitialized = $false
    [hashtable] $Configuration = @{}
    [BackgroundThreadManager] $ThreadManager
    [GracefulShutdownHandler] $ShutdownHandler
    [scriptblock] $DataFetchCallback
    
    LiveDisplayEngineBase([hashtable]$config) {
        $this.Configuration = $config
    }
    
    [void] Initialize() {
        if ($this.IsInitialized) {
            return
        }
        
        $this.ValidateConfiguration()
        $this.InitializeDisplay()
        $this.SetupBackgroundUpdates()
        $this.IsInitialized = $true
    }
    
    [void] ValidateConfiguration() {
        # Override in derived classes for specific validation
    }
    
    [void] InitializeDisplay() {
        # Override in derived classes for specific initialization
    }
    
    [void] SetupBackgroundUpdates() {
        if ($this.DataFetchCallback) {
            $refreshInterval = $this.Configuration.ContainsKey('RefreshInterval') ? $this.Configuration.RefreshInterval : 1000
            $this.ThreadManager = [BackgroundThreadManager]::new($this.DataFetchCallback, $refreshInterval)
        }
    }
    
    [void] StartLiveMode([scriptblock]$dataCallback) {
        if (-not $this.IsInitialized) {
            $this.Initialize()
        }
        
        $this.DataFetchCallback = $dataCallback
        
        if (-not $this.ThreadManager) {
            $this.SetupBackgroundUpdates()
        }
        
        if ($this.ThreadManager) {
            # Set up graceful shutdown handling
            $renderer = $this.GetRenderer()
            if ($renderer) {
                $this.ShutdownHandler = [GracefulShutdownHandler]::new($this.ThreadManager, $renderer)
                $this.ShutdownHandler.Register()
            }
            
            # Start background updates
            $this.ThreadManager.Start()
            
            # Main display loop
            $this.RunDisplayLoop()
        }
    }
    
    [void] RunDisplayLoop() {
        while ($this.ThreadManager -and $this.ThreadManager.IsHealthy()) {
            # Check for shutdown request
            if ($this.ShutdownHandler -and $this.ShutdownHandler.ShouldExit()) {
                break
            }
            
            # Get updated data from background thread
            $data = $this.ThreadManager.GetSharedData()
            
            # Update display if data is available
            if ($data -and $data.Count -gt 0) {
                try {
                    $this.UpdateDisplay($data)
                } catch {
                    Write-Warning "Display update error: $($_.Exception.Message)"
                }
            }
            
            # Brief sleep to prevent excessive CPU usage
            Start-Sleep -Milliseconds 100
        }
    }
    
    [ConsoleRenderer] GetRenderer() {
        # Override in derived classes to return the renderer instance
        return $null
    }
    
    [void] Update([hashtable]$data) {
        if (-not $this.IsInitialized) {
            throw [System.InvalidOperationException]::new("Engine not initialized")
        }
        
        $this.UpdateDisplay($data)
    }
    
    [void] UpdateDisplay([hashtable]$data) {
        # Override in derived classes for specific update logic
    }
    
    [void] Cleanup() {
        try {
            # Unregister shutdown handler
            if ($this.ShutdownHandler) {
                $this.ShutdownHandler.Unregister()
                $this.ShutdownHandler = $null
            }
            
            # Stop background thread
            if ($this.ThreadManager) {
                $this.ThreadManager.Stop()
                $this.ThreadManager = $null
            }
            
            # Cleanup display
            $this.CleanupDisplay()
            
        } catch {
            Write-Warning "Error during cleanup: $($_.Exception.Message)"
        } finally {
            $this.IsInitialized = $false
        }
    }
    
    [void] CleanupDisplay() {
        # Override in derived classes for specific cleanup
    }
    
    [bool] IsSupported() {
        # Override in derived classes for capability detection
        return $true
    }
}

# Console-based live display engine using ConsoleRenderer
class ConsoleDisplayEngine : LiveDisplayEngineBase {
    [int] $RefreshInterval = 1000
    [ConsoleRenderer] $Renderer
    [hashtable] $LastDisplayData = @{}
    [string] $DisplayMode = "detailed"
    [bool] $PerformanceMode = $true
    
    ConsoleDisplayEngine([hashtable]$config) : base($config) {
        if ($config.ContainsKey('RefreshInterval')) {
            $this.RefreshInterval = $config.RefreshInterval
        }
        if ($config.ContainsKey('DisplayMode')) {
            $this.DisplayMode = $config.DisplayMode
        }
        if ($config.ContainsKey('PerformanceMode')) {
            $this.PerformanceMode = $config.PerformanceMode
        }
        
        # Use optimized renderer if performance mode is enabled
        if ($this.PerformanceMode) {
            # Load the performance optimizer module
            $performanceModulePath = Join-Path $PSScriptRoot "PerformanceOptimizer.psm1"
            if (Test-Path $performanceModulePath) {
                . $performanceModulePath
                $this.Renderer = [OptimizedConsoleRenderer]::new($true)
            } else {
                Write-Warning "Performance optimizer module not found. Using standard renderer."
                $this.Renderer = [ConsoleRenderer]::new()
            }
        } else {
            $this.Renderer = [ConsoleRenderer]::new()
        }
    }
    
    [void] ValidateConfiguration() {
        if ($this.RefreshInterval -lt 500 -or $this.RefreshInterval -gt 5000) {
            throw [System.ArgumentException]::new("RefreshInterval must be between 500 and 5000 milliseconds")
        }
        
        $validModes = @("minimal", "detailed", "compact")
        if ($this.DisplayMode -notin $validModes) {
            throw [System.ArgumentException]::new("DisplayMode must be one of: $($validModes -join ', ')")
        }
    }
    
    [void] InitializeDisplay() {
        $this.Renderer.SetDisplayMode($this.DisplayMode)
        $this.Renderer.InitializeLiveMode()
    }
    
    [ConsoleRenderer] GetRenderer() {
        return $this.Renderer
    }
    
    [void] UpdateDisplay([hashtable]$data) {
        # Only update if data has changed to reduce flicker
        $dataChanged = $this.HasDataChanged($data)
        
        if ($dataChanged) {
            # Clear screen and move to home position
            $this.Renderer.ClearScreen()
            
            # Render track information
            if ($data -and $data.ContainsKey('track')) {
                $trackData = $data.track.Clone()
                
                # Add playback state information
                if ($data.ContainsKey('is_playing')) {
                    $trackData['is_playing'] = $data.is_playing
                }
                if ($data.ContainsKey('progress_ms')) {
                    $trackData['progress_ms'] = $data.progress_ms
                }
                
                $this.Renderer.UpdateTrackInfo($trackData)
            } else {
                $this.Renderer.WriteColoredText("No track information available", "Yellow")
                $this.Renderer.WriteLine()
            }
            
            # Add timestamp for debugging
            if ($this.DisplayMode -eq "detailed") {
                $this.Renderer.WriteLine()
                $this.Renderer.WriteColoredText("Last updated: $(Get-Date -Format 'HH:mm:ss')", "Gray")
                $this.Renderer.WriteLine()
            }
            
            # Flush the display buffer
            $this.Renderer.FlushBuffer()
            $this.LastDisplayData = if ($data) { $data.Clone() } else { @{} }
        }
    }
    
    [bool] HasDataChanged([hashtable]$newData) {
        if (-not $this.LastDisplayData -or $this.LastDisplayData.Count -eq 0) {
            return $true
        }
        
        if (-not $newData -or $newData.Count -eq 0) {
            return $true
        }
        
        # Check key fields for changes
        $keyFields = @('track', 'is_playing', 'progress_ms')
        
        foreach ($field in $keyFields) {
            $oldValue = $this.LastDisplayData.ContainsKey($field) ? $this.LastDisplayData[$field] : $null
            $newValue = $newData.ContainsKey($field) ? $newData[$field] : $null
            
            if ($field -eq 'track') {
                # For track data, check if track ID changed
                $oldId = if ($oldValue -and $oldValue.ContainsKey('id')) { $oldValue.id } else { $null }
                $newId = if ($newValue -and $newValue.ContainsKey('id')) { $newValue.id } else { $null }
                
                if ($oldId -ne $newId) {
                    return $true
                }
            } elseif ($field -eq 'progress_ms') {
                # For progress, only update if change is significant (> 1 second)
                if ($oldValue -and $newValue) {
                    $diff = [Math]::Abs($newValue - $oldValue)
                    if ($diff -gt 1000) {
                        return $true
                    }
                } elseif ($oldValue -ne $newValue) {
                    return $true
                }
            } else {
                if ($oldValue -ne $newValue) {
                    return $true
                }
            }
        }
        
        return $false
    }
    
    [void] CleanupDisplay() {
        $this.Renderer.CleanupAndExit()
    }
    
    [bool] IsSupported() {
        return $true  # Console display is always supported
    }
    
    [hashtable] GetDisplayInfo() {
        $info = $this.Renderer.GetTerminalInfo()
        
        # Add performance stats if using optimized renderer
        if ($this.PerformanceMode -and $this.Renderer -is [OptimizedConsoleRenderer]) {
            $info['PerformanceStats'] = $this.Renderer.GetPerformanceStats()
        }
        
        return $info
    }
    
    [void] SetProgressBarStyle([ProgressBarStyle]$style) {
        $this.Renderer.DefaultProgressStyle = $style
    }
    
    [void] SetPerformanceMode([bool]$enabled) {
        $this.PerformanceMode = $enabled
        
        if ($this.Renderer -is [OptimizedConsoleRenderer]) {
            $this.Renderer.SetPerformanceMode($enabled)
        }
    }
    
    [void] SetTargetFPS([int]$fps) {
        if ($this.Renderer -is [OptimizedConsoleRenderer]) {
            $this.Renderer.SetTargetFPS($fps)
        }
    }
    
    [hashtable] GetPerformanceStats() {
        if ($this.Renderer -is [OptimizedConsoleRenderer]) {
            return $this.Renderer.GetPerformanceStats()
        }
        return @{}
    }
}

# Factory function to create display engines
function New-LiveDisplayEngine {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Console", "Sidecar")]
        [string]$Type,
        
        [hashtable]$Configuration = @{}
    )
    
    switch ($Type) {
        "Console" {
            return [ConsoleDisplayEngine]::new($Configuration)
        }
        "Sidecar" {
            return [SidecarDisplayEngine]::new($Configuration)
        }
        default {
            throw [System.ArgumentException]::new("Unknown display engine type: $Type")
        }
    }
}

# Utility function to test display capabilities
function Test-DisplayCapabilities {
    $console = [ConsoleDisplayEngine]::new(@{})
    $sidecar = [SidecarDisplayEngine]::new(@{})
    
    return @{
        Console = @{
            Supported = $console.IsSupported()
            Info = $console.GetDisplayInfo()
        }
        Sidecar = @{
            Supported = $sidecar.IsSupported()
            Capabilities = $sidecar.GetCapabilities()
        }
        WindowsTerminal = [WindowsTerminalIntegrator]::new().GetCapabilities()
    }
}

# Export classes and functions
Export-ModuleMember -Function @(
    'New-LiveDisplayEngine',
    'Test-DisplayCapabilities'
) -Variable @()