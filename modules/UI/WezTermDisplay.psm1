# WezTermDisplay Module
# Optional WezTerm add-on: a live now-playing pane with album cover in a dark Orca theme.
# Nothing here runs unless Start-SpotifyWezTerm is called. Existing live display and
# Start-SpotifySidecar (Windows Terminal) are not touched.
#
# This file is ASCII-only on purpose (no BOM, must also parse in Windows PowerShell 5.1);
# special glyphs are built with [char] codes.

$script:WezPaneTitle  = 'SpotifyCLI Live'
$script:WezStateFile  = Join-Path $(if ($env:APPDATA) { $env:APPDATA } else { [IO.Path]::GetTempPath() }) 'SpotifyCLI\wezterm-pane.json'
$script:WezCoverDir   = Join-Path $(if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { [IO.Path]::GetTempPath() }) 'SpotifyCLI\covers'
$script:WezCoverLimit = 200

# --- WezTerm helpers ---

function Get-WezTermCliPath {
    if ($env:WEZTERM_EXECUTABLE_DIR) {
        $candidate = Join-Path $env:WEZTERM_EXECUTABLE_DIR 'wezterm.exe'
        if (Test-Path $candidate) { return $candidate }
    }
    $cmd = Get-Command wezterm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}

function Test-WezTermSession {
    return ($env:TERM_PROGRAM -eq 'WezTerm')
}

function Get-SpotifyWezTermPane {
    # Returns the registered live view ({ pane_id, pid, process_started_ticks }) if its process is
    # still alive. WezTerm reports the pane title as the process name and pane ids restart with
    # WezTerm, so the view is identified by process id + start time instead.
    if (-not (Test-Path $script:WezStateFile)) { return $null }
    try {
        $state = Get-Content -Path $script:WezStateFile -Raw | ConvertFrom-Json
        $proc = Get-Process -Id ([int]$state.pid) -ErrorAction Stop
        # Ticks, not an ISO string: ConvertFrom-Json turns date-looking strings into DateTime.
        if ([string]$proc.StartTime.ToUniversalTime().Ticks -eq [string]$state.process_started_ticks) { return $state }
    } catch { }
    return $null
}

function Set-SpotifyWezTermPaneState {
    # Called by the view process itself when it was started by the launcher.
    try {
        $stateDir = Split-Path $script:WezStateFile -Parent
        if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
        $self = Get-Process -Id $PID
        @{ pane_id = [int]$env:WEZTERM_PANE; pid = $PID; process_started_ticks = [string]$self.StartTime.ToUniversalTime().Ticks } |
            ConvertTo-Json | Set-Content -Path $script:WezStateFile -Encoding UTF8
    } catch { }
}

function Clear-SpotifyWezTermPaneState {
    # Removes the registration, but only if it belongs to this process.
    try {
        if (Test-Path $script:WezStateFile) {
            $state = Get-Content -Path $script:WezStateFile -Raw | ConvertFrom-Json
            if ([int]$state.pid -eq $PID) { Remove-Item $script:WezStateFile -Force -ErrorAction SilentlyContinue }
        }
    } catch { }
}

# --- Cover cache ---

function Get-SpotifyCoverPath {
    # Downloads a cover once and reuses the cached file afterwards. Returns $null on failure.
    param([string]$Url)
    if (-not $Url) { return $null }
    $id = ($Url.TrimEnd('/') -split '/')[-1] -replace '[^A-Za-z0-9_-]', ''
    if (-not $id) { return $null }
    $path = Join-Path $script:WezCoverDir "$id.jpg"
    if ((Test-Path $path) -and (Get-Item $path).Length -gt 0) { return $path }
    $tmp = "$path.part"
    try {
        if (-not (Test-Path $script:WezCoverDir)) { New-Item -ItemType Directory -Path $script:WezCoverDir -Force | Out-Null }
        $oldProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try { Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing -TimeoutSec 10 | Out-Null }
        finally { $ProgressPreference = $oldProgress }
        Move-Item -Path $tmp -Destination $path -Force
        return $path
    } catch {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        return $null
    }
}

function Clear-SpotifyCoverCacheOverflow {
    # Keeps the newest $script:WezCoverLimit covers. Only touches *.jpg/*.part in our own cache folder.
    try {
        if (-not (Test-Path $script:WezCoverDir)) { return }
        Get-ChildItem -Path $script:WezCoverDir -Filter '*.part' -File | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $script:WezCoverDir -Filter '*.jpg' -File |
            Sort-Object LastWriteTime -Descending |
            Select-Object -Skip $script:WezCoverLimit |
            Remove-Item -Force -ErrorAction SilentlyContinue
    } catch { }
}

# --- The view (runs inside the pane) ---

function Invoke-SpotifyWezTermView {
    param([int]$PollSeconds = 3, [switch]$NoImage)

    if (-not $Host.UI.SupportsVirtualTerminal) {
        Write-Host 'This terminal does not support ANSI colours. Use Start-SpotifyLiveDisplay instead.' -ForegroundColor Yellow
        return
    }

    $esc = [char]27
    $bel = [char]7
    $rgb = { param($hex, $layer) "$esc[$layer;2;{0};{1};{2}m" -f [Convert]::ToInt32($hex.Substring(0, 2), 16), [Convert]::ToInt32($hex.Substring(2, 2), 16), [Convert]::ToInt32($hex.Substring(4, 2), 16) }
    # Orca theme: deep sea black, gold details
    $bg      = & $rgb '0B0E14' 48
    $panelBg = & $rgb '151A24' 48
    $gold    = & $rgb 'D4AF37' 38
    $goldDim = & $rgb '8C7424' 38
    $white   = & $rgb 'F2EFE6' 38
    $muted   = & $rgb '8A8F98' 38
    $faint   = & $rgb '3A3F4B' 38
    $red     = & $rgb 'C8553D' 38
    $bold = "$esc[1m"; $noBold = "$esc[22m"

    $gDot = [string][char]0x00B7; $gEllipsis = [string][char]0x2026
    $gBarOn = [string][char]0x2501; $gBarOff = [string][char]0x2500; $gKnob = [string][char]0x25CF
    $gPlay = [string][char]0x25B6; $gPause = [string][char]0x2016; $gNote = [string][char]0x266A

    $fit = {
        param([string]$text, [int]$width)
        if ($width -le 0) { return '' }
        if ($null -eq $text) { $text = '' }
        if ($text.Length -gt $width) { $text = $text.Substring(0, [Math]::Max(0, $width - 1)) + $gEllipsis }
        return $text.PadRight($width)
    }
    $time = {
        param([double]$ms)
        $t = [TimeSpan]::FromMilliseconds([Math]::Max(0, $ms))
        '{0}:{1:D2}' -f [int][Math]::Floor($t.TotalMinutes), $t.Seconds
    }

    $imagesWanted = (-not $NoImage) -and (Test-WezTermSession)
    $pollMs = [Math]::Max(1, $PollSeconds) * 1000

    # First request happens before the screen is taken over, so a credential/login prompt
    # from the existing auth code stays readable.
    $player = $null; $apiError = $null
    try { $player = Invoke-SpotifyApi -Method GET -Path '/me/player' -Query @{ additional_types = 'track,episode' } }
    catch { $apiError = $_.Exception.Message }
    $pollClock = [Diagnostics.Stopwatch]::StartNew()
    $nextPollMs = $pollMs

    Clear-SpotifyCoverCacheOverflow

    $oldTitle = $null
    try { $oldTitle = $Host.UI.RawUI.WindowTitle; $Host.UI.RawUI.WindowTitle = $script:WezPaneTitle } catch { }
    $keysOk = $true
    $oldCtrlC = $false
    try { $oldCtrlC = [Console]::TreatControlCAsInput; [Console]::TreatControlCAsInput = $true } catch { $keysOk = $false }
    # Write straight to the console as UTF-8. $Host.UI.Write drops colour sequences in some
    # sessions (PowerShell 7 output rendering), which would lose the theme.
    $oldEncoding = $null
    try { $oldEncoding = [Console]::OutputEncoding; [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }
    $oldCursor = $true
    try { $oldCursor = [Console]::CursorVisible } catch { }

    $lineCache = @{}
    $coverPath = $null; $coverUrl = $null; $coverFailedAt = $null
    $shownCover = '<none>'
    $lastSize = ''
    $forcePoll = $false
    $endPollDone = $false
    $blankToggle = $false
    $rehideCursor = $false

    try {
        [Console]::Out.Write("$esc[?1049h$esc[?25l")
        try { [Console]::CursorVisible = $false } catch { }
        while ($true) {
            # --- keys ---
            $quit = $false
            if ($keysOk) {
                try {
                    while ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        if ($key.Key -eq 'Q' -or $key.Key -eq 'Escape' -or ($key.Key -eq 'C' -and ($key.Modifiers -band [ConsoleModifiers]::Control))) { $quit = $true }
                        elseif ($key.Key -eq 'R') { $forcePoll = $true; $lastSize = '' }
                    }
                } catch { $keysOk = $false }
            }
            if ($quit) { break }

            # --- poll Spotify (throttled) ---
            if ($forcePoll -or $pollClock.ElapsedMilliseconds -ge $nextPollMs) {
                $forcePoll = $false
                try {
                    $player = Invoke-SpotifyApi -Method GET -Path '/me/player' -Query @{ additional_types = 'track,episode' }
                    $apiError = $null
                    $nextPollMs = if ($player -and $player.item) { $pollMs } else { [Math]::Max($pollMs, 10000) }
                } catch {
                    $apiError = $_.Exception.Message
                    $nextPollMs = if ($apiError -match '429') { 30000 } else { 15000 }
                }
                $pollClock.Restart()
                $endPollDone = $false
            }

            # --- derive what to show ---
            $item = if ($player) { $player.item } else { $null }
            $title = ''; $artist = ''; $album = ''; $newCoverUrl = $null
            $durationMs = 0; $progressMs = 0; $isPlaying = $false
            if ($item) {
                $title = [string]$item.name
                if ($item.artists) { $artist = ($item.artists | ForEach-Object { $_.name }) -join ', ' }
                elseif ($item.show) { $artist = [string]$item.show.name }
                if ($item.album) {
                    $album = [string]$item.album.name
                    if ($item.album.release_date) { $album += "  $gDot  " + ([string]$item.album.release_date).Substring(0, 4) }
                } elseif ($item.show) { $album = [string]$item.show.publisher }
                $images = if ($item.album -and $item.album.images) { $item.album.images } else { $item.images }
                if ($images) { $newCoverUrl = [string](@($images | Sort-Object width -Descending)[0].url) }
                $durationMs = [double]$item.duration_ms
                $isPlaying = [bool]$player.is_playing
                $progressMs = [double]$player.progress_ms
                if ($isPlaying) { $progressMs += $pollClock.ElapsedMilliseconds }
                if ($durationMs -gt 0 -and $progressMs -ge $durationMs) {
                    $progressMs = $durationMs
                    # Track should have ended: ask once, a little early, instead of waiting for the next poll.
                    if ($isPlaying -and -not $endPollDone -and $pollClock.ElapsedMilliseconds -ge 1000) { $forcePoll = $true; $endPollDone = $true }
                }
            }

            # --- cover (cached on disk, fetched only when the URL changes) ---
            if ($newCoverUrl -ne $coverUrl) {
                $coverUrl = $newCoverUrl; $coverPath = $null; $coverFailedAt = $null
                if ($imagesWanted -and $coverUrl) {
                    $coverPath = Get-SpotifyCoverPath -Url $coverUrl
                    if (-not $coverPath) { $coverFailedAt = [DateTime]::UtcNow }
                }
            } elseif ($imagesWanted -and $coverUrl -and -not $coverPath -and $coverFailedAt -and ([DateTime]::UtcNow - $coverFailedAt).TotalSeconds -ge 60) {
                $coverPath = Get-SpotifyCoverPath -Url $coverUrl
                $coverFailedAt = if ($coverPath) { $null } else { [DateTime]::UtcNow }
            }

            # --- layout ---
            $w = [Console]::WindowWidth; $h = [Console]::WindowHeight
            $size = "$w,$h"
            $full = $size -ne $lastSize
            $lastSize = $size

            $showArt = $imagesWanted -and $w -ge 24 -and $h -ge 12
            $artX = 0; $artY = 0; $artW = 0; $artH = 0
            if ($showArt -and $h -ge 22) {
                # stacked: cover on top, text below
                $colW = [Math]::Min($w - 4, 64); $colX = [int][Math]::Floor(($w - $colW) / 2)
                $artW = [Math]::Min($colW, 2 * ($h - 12)); $artW -= $artW % 2; $artH = [int]($artW / 2)
                $artX = $colX + [int][Math]::Floor(($colW - $artW) / 2); $artY = 2
                $textX = $colX; $textW = $colW; $textY = $artY + $artH + 1
            } elseif ($showArt) {
                # side by side: cover left, text right
                $artH = $h - 4; $artW = [Math]::Min(2 * $artH, [int][Math]::Floor($w / 2) - 2); $artW -= $artW % 2; $artH = [int]($artW / 2)
                $artX = 2; $artY = 2
                $textX = $artX + $artW + 3; $textW = $w - $textX - 2; $textY = 2
                if ($textW -lt 16 -or $artW -lt 8) { $showArt = $false }
            }
            if (-not $showArt) {
                $artW = 0; $artH = 0
                $textW = [Math]::Min([Math]::Max(1, $w - 4), 64); $textX = [int][Math]::Floor(($w - $textW) / 2); $textY = 2
            }

            $out = New-Object System.Text.StringBuilder
            if ($full) {
                $lineCache = @{}; $shownCover = '<none>'
                $blank = ' ' * $w
                for ($y = 1; $y -le $h; $y++) { [void]$out.Append("$esc[$y;1H$bg$blank") }
            }

            # --- cover / placeholder ---
            $coverKey = if (-not $showArt) { '<off>' } elseif ($coverPath) { $coverPath } else { '<placeholder>' }
            if ($coverKey -ne $shownCover) {
                $shownCover = $coverKey
                if ($showArt) {
                    # Windows passes the image escape through ConPTY, which only forwards cells it
                    # sees change. Blank cells are painted with alternating space / no-break space
                    # (both invisible) so the repaint really reaches WezTerm and erases the old cover.
                    $blankToggle = -not $blankToggle
                    $blank = if ($blankToggle) { [string][char]0x00A0 } else { ' ' }
                    $boxLine = $blank * $artW
                    for ($y = 0; $y -lt $artH; $y++) { [void]$out.Append("$esc[$($artY + $y + 1);$($artX + 1)H$panelBg$boxLine") }
                    $drawn = $false
                    if ($coverPath) {
                        try {
                            $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($coverPath))
                            # ConPTY forwards the cursor position before a passed-through escape only
                            # while the cursor is visible (verified on WezTerm 20240203 / Windows 11),
                            # so it is shown just for the image and hidden again right after.
                            [void]$out.Append("$esc[?25h$esc[$($artY + 1);$($artX + 1)H$esc]1337;File=inline=1;width=$artW;height=$artH;preserveAspectRatio=1;doNotMoveCursor=1:$b64$bel")
                            $drawn = $true
                            $rehideCursor = $true
                        } catch { }
                    }
                    if (-not $drawn) {
                        $noteX = $artX + [int][Math]::Floor($artW / 2); $noteY = $artY + [int][Math]::Floor($artH / 2)
                        [void]$out.Append("$esc[$($noteY + 1);$($noteX + 1)H$panelBg$gold$gNote")
                    }
                }
            }

            # --- text rows (only rewritten when they change) ---
            $rows = @{}
            $header = 'ORCA  ' + $gDot + '  NOW PLAYING'
            $rows[0] = "$goldDim" + (& $fit $header ($w - 4))
            if (-not $item) {
                $rows[$textY]     = "$bold$white" + (& $fit 'Nothing playing' $textW) + $noBold
                $rows[$textY + 1] = "$muted" + (& $fit 'Play something in Spotify.' $textW)
                for ($i = 2; $i -le 7; $i++) { $rows[$textY + $i] = ' ' * $textW }
            } else {
                $ratio = if ($durationMs -gt 0) { [Math]::Min(1, $progressMs / $durationMs) } else { 0 }
                $barW = [Math]::Max(4, $textW)
                $on = [int][Math]::Floor($ratio * ($barW - 1))
                $bar = "$gold" + ($gBarOn * $on) + "$white$gKnob" + "$faint" + ($gBarOff * ($barW - 1 - $on))
                $left = (& $time $progressMs) + ' / ' + (& $time $durationMs)
                $state = if ($isPlaying) { "$gPlay PLAYING" } else { "$gPause PAUSED" }
                $gap = [Math]::Max(1, $textW - $left.Length - $state.Length)
                $stateColor = if ($isPlaying) { $gold } else { $muted }
                $extras = @()
                if ($player.device -and $player.device.name) { $extras += [string]$player.device.name }
                if ($player.shuffle_state) { $extras += 'shuffle' }
                if ($player.repeat_state -and $player.repeat_state -ne 'off') { $extras += "repeat $($player.repeat_state)" }

                $rows[$textY]     = "$bold$white" + (& $fit $title $textW) + $noBold
                $rows[$textY + 1] = "$gold" + (& $fit $artist $textW)
                $rows[$textY + 2] = "$muted" + (& $fit $album $textW)
                $rows[$textY + 3] = ' ' * $textW
                $rows[$textY + 4] = $bar
                $rows[$textY + 5] = "$white$left" + (' ' * $gap) + "$stateColor$state"
                $rows[$textY + 6] = ' ' * $textW
                $rows[$textY + 7] = "$muted" + (& $fit ($extras -join "  $gDot  ") $textW)
            }
            if ($apiError) { $rows[$h - 1] = "$red" + (& $fit "Spotify: $apiError" ($w - 4)) }
            else { $rows[$h - 1] = "$faint" + (& $fit "q quit  $gDot  r refresh" ($w - 4)) }

            foreach ($y in @($rows.Keys)) {
                if ($y -lt 0 -or $y -ge $h) { continue }
                $edge = ($y -eq 0 -or $y -eq ($h - 1))
                $x = if ($edge) { 2 } else { $textX }
                $line = "$esc[$($y + 1);$($x + 1)H$bg$($rows[$y])"
                if ($lineCache[$y] -ne $line) { $lineCache[$y] = $line; [void]$out.Append($line) }
            }

            if ($out.Length -gt 0) { [Console]::Out.Write($out.ToString()); [Console]::Out.Flush() }
            if ($rehideCursor) {
                # A hide in the same write as the image is lost; ConPTY only forwards a cursor
                # state change it sees between two of its render passes.
                $rehideCursor = $false
                Start-Sleep -Milliseconds 60
                [Console]::Out.Write("$esc[?25h"); [Console]::Out.Flush()
                Start-Sleep -Milliseconds 60
                [Console]::Out.Write("$esc[?25l"); [Console]::Out.Flush()
            }
            Start-Sleep -Milliseconds 200
        }
    } finally {
        [Console]::Out.Write("$esc[0m$esc[?25h$esc[?1049l")
        try { [Console]::CursorVisible = $oldCursor } catch { }
        if ($null -ne $oldEncoding) { try { [Console]::OutputEncoding = $oldEncoding } catch { } }
        if ($keysOk) { try { [Console]::TreatControlCAsInput = $oldCtrlC } catch { } }
        if ($null -ne $oldTitle) { try { $Host.UI.RawUI.WindowTitle = $oldTitle } catch { } }
        Clear-SpotifyWezTermPaneState
    }
}

# --- Public commands ---

function Start-SpotifyWezTerm {
    <#
    .SYNOPSIS
    Live now-playing view with album cover in a separate WezTerm pane (alias: live-wez)
    .DESCRIPTION
    Optional WezTerm add-on. Splits the current WezTerm pane and shows album cover, title, artist,
    album, playback state and a progress bar in a dark Orca theme. Your shell stays usable in the
    original pane. Outside WezTerm (Windows Terminal, plain PowerShell) the same view runs as text
    in the current window.

    The view only reads from Spotify, so stopping it never affects the music.
    Stop it with q, Esc or Ctrl+C in the pane, or Stop-SpotifyWezTerm from any shell.
    .PARAMETER Position
    Where the new pane goes: right (default), left, down, up
    .PARAMETER Size
    Pane size in percent of the current pane (default 35)
    .PARAMETER PollSeconds
    Seconds between Spotify requests (default 3). The progress bar moves every second regardless.
    .PARAMETER NoImage
    Text only, no album cover
    .PARAMETER InPlace
    Run the view in the current pane instead of opening a new one
    .EXAMPLE
    Start-SpotifyWezTerm
    .EXAMPLE
    Start-SpotifyWezTerm -Position down -Size 30
    .EXAMPLE
    Start-SpotifyWezTerm -InPlace -NoImage
    #>
    param(
        [ValidateSet('right', 'left', 'down', 'up')]
        [string]$Position = 'right',
        [ValidateRange(10, 80)]
        [int]$Size = 35,
        [ValidateRange(1, 60)]
        [int]$PollSeconds = 3,
        [switch]$NoImage,
        [switch]$InPlace,
        # Internal: set by the launcher so the pane registers itself for Stop-SpotifyWezTerm.
        [Parameter(DontShow)]
        [switch]$Managed
    )

    $wez = Get-WezTermCliPath
    if ($InPlace -or -not (Test-WezTermSession) -or -not $env:WEZTERM_PANE -or -not $wez) {
        if ($Managed -and $env:WEZTERM_PANE) { Set-SpotifyWezTermPaneState }
        if (-not $InPlace) {
            Write-Host 'WezTerm not detected - showing the text view here. Press q to stop.' -ForegroundColor Yellow
            Start-Sleep -Milliseconds 1200
        }
        try { Invoke-SpotifyWezTermView -PollSeconds $PollSeconds -NoImage:$NoImage }
        finally { Clear-SpotifyWezTermPaneState }
        return
    }

    $existing = Get-SpotifyWezTermPane
    if ($existing) {
        Write-Host "The WezTerm live view is already running (pane $($existing.pane_id)). Stop it with Stop-SpotifyWezTerm." -ForegroundColor Yellow
        return
    }

    $manifest = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'SpotifyCLI.psd1'
    $viewArgs = "-InPlace -Managed -PollSeconds $PollSeconds"
    if ($NoImage) { $viewArgs += ' -NoImage' }
    $inner = "try { Import-Module '$($manifest -replace "'", "''")' -WarningAction SilentlyContinue -ErrorAction Stop; Start-SpotifyWezTerm $viewArgs } " +
             "catch { Write-Host `$_ -ForegroundColor Red; [void](Read-Host 'Press Enter to close') }"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($inner))
    $shell = (Get-Process -Id $PID).Path
    $direction = @{ right = '--right'; left = '--left'; down = '--bottom'; up = '--top' }[$Position]

    $result = & $wez cli split-pane --pane-id $env:WEZTERM_PANE $direction --percent $Size -- $shell -NoLogo -NoProfile -EncodedCommand $encoded 2>&1
    $paneId = 0
    if ($LASTEXITCODE -ne 0 -or -not [int]::TryParse(("$result").Trim(), [ref]$paneId)) {
        Write-Host "Could not open a WezTerm pane: $result" -ForegroundColor Red
        Write-Host 'Run Start-SpotifyWezTerm -InPlace to show the view in this pane instead.' -ForegroundColor Yellow
        return
    }

    # Give the keyboard back to the pane the command was typed in.
    & $wez cli activate-pane --pane-id $env:WEZTERM_PANE 2>$null | Out-Null

    # The pane registers itself once the module is loaded there; wait briefly for that.
    $registered = $null
    for ($i = 0; $i -lt 40 -and -not $registered; $i++) {
        Start-Sleep -Milliseconds 200
        $candidate = Get-SpotifyWezTermPane
        if ($candidate -and [int]$candidate.pane_id -eq $paneId) { $registered = $candidate }
    }
    if ($registered) {
        Write-Host "WezTerm live view started in pane $paneId ($Position, $Size%)." -ForegroundColor Green
        Write-Host 'Stop it with Stop-SpotifyWezTerm, or press q in the pane. The music keeps playing.' -ForegroundColor DarkGray
    } else {
        Write-Host "Pane $paneId was opened, but the live view has not reported in. Check the pane for an error message." -ForegroundColor Yellow
    }
}

function Stop-SpotifyWezTerm {
    <#
    .SYNOPSIS
    Close the WezTerm live view pane started by Start-SpotifyWezTerm
    .DESCRIPTION
    Closes only the live view pane. Your shell and the music are left alone.
    .EXAMPLE
    Stop-SpotifyWezTerm
    #>
    $pane = Get-SpotifyWezTermPane
    if (-not $pane) {
        if (Test-Path $script:WezStateFile) { Remove-Item $script:WezStateFile -Force -ErrorAction SilentlyContinue }
        Write-Host 'No WezTerm live view is running.' -ForegroundColor Yellow
        return
    }
    $wez = Get-WezTermCliPath
    $closed = $false
    if ($wez) {
        & $wez cli kill-pane --pane-id $pane.pane_id 2>$null | Out-Null
        $closed = ($LASTEXITCODE -eq 0)
    }
    if ($closed) {
        # Killing the pane ends the view process before it can clean up after itself.
        Remove-Item $script:WezStateFile -Force -ErrorAction SilentlyContinue
        Write-Host "WezTerm live view stopped (pane $($pane.pane_id))." -ForegroundColor Green
    } else {
        Write-Host "Could not close pane $($pane.pane_id). Press q in the pane instead." -ForegroundColor Red
    }
}

Set-Alias -Name live-wez -Value Start-SpotifyWezTerm -ErrorAction SilentlyContinue

Export-ModuleMember -Function @('Start-SpotifyWezTerm', 'Stop-SpotifyWezTerm') -Alias @('live-wez')
