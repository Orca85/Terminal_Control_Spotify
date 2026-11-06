@{
    RootModule = 'SpotifyCLI.psm1'
    ModuleVersion = '3.2.15'
    GUID = 'c7f3a1b2-d4e5-4f60-9abc-12de34567890'
    Author = 'Orca85'
    CompanyName = 'Orca'
    Copyright = '(c) 2026 Orca85. All rights reserved.'
    Description = 'Full-featured Spotify terminal client for PowerShell. Control playback, search, playlists, devices, queue, and more — plus Live Display, synchronized lyrics, music quiz, setlist lookup, and statistics analytics. Requires Spotify Premium and a Spotify Developer App.'
    PowerShellVersion = '5.1'
    NestedModules = @(
        'modules\SpotifyLiveFeatures.psm1',
        'modules\Core\ErrorHandling.psm1',
        'modules\Core\AuthenticationManager.psm1',
        'modules\Core\ApiClientManager.psm1',
        'modules\Core\LegacyApiClient.psm1',
        'modules\Core\StateManager.psm1',
        'modules\Core\LegacyConfigManager.psm1',
        'modules\Core\UIHelpers.psm1',
        'modules\Core\InteractiveMode.psm1',
        'modules\UI\SpotifyFormDisplay.psm1',
        'modules\Core\AppCommands.psm1',
        'modules\Core\PlaybackCommands.psm1',
        'modules\Core\SearchCommands.psm1',
        'modules\Core\PlaylistQueueCommands.psm1',
        'modules\Quiz\QuizCommands.psm1',
        'modules\UI\PeakDashboard.psm1',
        'modules\Core\SetlistCommands.psm1',
        'modules\Core\AliasManagement.psm1',
        'modules\Core\InstallationCommands.psm1',
        'modules\Core\FavoriteCommands.psm1',
        'modules\Core\CliLoop.psm1'
    )
    FunctionsToExport = @(
        'Show-SpotifyTrack',
        'Get-SpotifyHelp',
        'Invoke-HelpCommand',
        'Get-SpotifyLyrics',
        'Show-AllSpotifyCommands',
        'Start-SpotifyCliInNewWindow',
        'Get-TerminalCapabilities',

        'Start-SpotifyApp',
        'spotify-now',
        'notifications',
        'Test-NotificationSupport',
        'Test-SplitWindowSupport',
        'Get-SpotifyCliTroubleshootingGuide',

        'play',
        'pause',
        'next',
        'previous',
        'volume',
        'volume-low',
        'volume-medium',
        'volume-high',
        'seek',
        'skip-forward',
        'skip-back',
        'replay',
        'shuffle',
        'repeat',
        'devices',
        'transfer',
        'copy-track-link',
        'export-now-playing',

        'search',
        'search-albums',

        'playlists',
        'play-playlist',
        'queue-playlist',
        'play-queue',
        'liked',
        'recent',
        'save-track',
        'unsave-track',
        'queue',
        'queue-album',
        'play-album',

        'Invoke-SpotifyApi',
        'Test-SpotifyAuth',

        'Get-SessionTracks',
        'Set-SessionTracks',
        'Clear-SessionTracks',
        'Get-SessionDevices',
        'Set-SessionDevices',
        'Get-SessionAlbums',
        'Set-SessionAlbums',
        'Get-SessionPlaylists',
        'Set-SessionPlaylists',
        'Get-SessionQueue',
        'Set-SessionQueue',
        'Get-LastListContext',
        'Set-LastListContext',

        'New-EnhancedSpotifyApiClient',
        'Get-SpotifyApiClientStats',
        'Clear-SpotifyApiClientCache',
        'Reset-SpotifyApiClientStats',

        'Invoke-WithErrorHandling',
        'Test-OfflineMode',
        'Test-FeatureEnabled',
        'Get-DegradationStatus',
        'Invoke-WithGracefulDegradation',

        'Format-Time',
        'Show-ProgressBar',
        'Get-StatusColor',
        'Get-TrackColor',
        'Get-ArtistColor',
        'Get-AlbumColor',
        'Get-ProgressColor',

        'Start-InteractiveMode',
        'Show-InteractiveItems',

        'Get-SpotifyConfig',
        'Set-SpotifyConfig',

        'Initialize-SpotifyLiveFeatures',
        'Start-SpotifyLiveDisplay',
        'Stop-SpotifyLiveDisplay',
        'Get-SpotifyCurrentTrackLyrics',
        'Get-SpotifyListeningStatistics',
        'Get-SpotifyLiveFeaturesStatus',
        'Set-SpotifyLiveFeaturesConfiguration',
        'Reset-SpotifyLiveFeaturesConfiguration',
        'Start-SpotifySidecar',

        'Show-SpotifyForm',
        'Show-LyricsForm',
        'Show-SpotifyLyricsForm',
        'Show-PeakDashboard',
        'Show-SpotifyPeak',
        'Get-SpotifyPeakInfo',

        'Start-MusicQuiz',

        'Invoke-SetlistCommand',

        'Get-SpotifyAliases',
        'Remove-SpotifyAlias',
        'Test-AliasConflicts',

        'Install-SpotifyCliDependencies',
        'Repair-SpotifyCliInstallation',
        'Uninstall-SpotifyCli',

        'Invoke-FavoriteCommand',
        'fav',

        'Start-SpotifyCLI',
        'Invoke-SpotifyCommand',
        'Initialize-SpotifyCredentials',
        'Get-SpotifyAccessToken',
        'Start-SpotifyAuth',
        'Get-StoredTokens',
        'Set-StoredTokens',
        'Initialize-TokenStore'
    )
    AliasesToExport = @('plays-now', 'music', 'pn', 'sp', 'pl', 'vol', 'mix', 'rep', 'swap', 'q', 'pq', 'spotify', 'spotify-help', 'slw', 'ShowLyrics', 'quiz', 'peak', 'showpeak', 'setlist', 'spcommands', 'stats', 'live', 'live-music', 'ss', 'ShowSpotify')
    PrivateData = @{
        PSData = @{
            Tags = @('Spotify', 'Music', 'CLI', 'Audio', 'Player', 'Terminal', 'PowerShell', 'NowPlaying', 'Playback', 'Lyrics', 'LiveDisplay', 'Statistics', 'Quiz', 'Setlist', 'PSModule')
            ProjectUri = 'https://github.com/Orca85/terminal_control_spotify'
            LicenseUri = 'https://github.com/Orca85/terminal_control_spotify/blob/main/LICENSE'
            ReleaseNotes = @'
v3.2.15
- feat: `peak` now prints track insights (popularity, followers, duration, album, genres) in the
  terminal; `peak -Watch` keeps it updated with a popularity graph for recent tracks. The window
  moved to `showpeak`. New Get-SpotifyPeakInfo returns the same data as an object.

v3.2.14
- feat: `spcommands` is now the main help, written for PowerShell: every shell command grouped by
  category, without `/`, with its aliases (read from the live session). `spcommands <command>` shows
  detailed help. `spotify-help` points to the same help. The interactive CLI keeps its own /help
  and /commands lists.

v3.2.13
- fix: `spcommands` now lists every alias (built from the live session instead of a hand-written
  line that only showed three and listed `q` as quit).
- fix: Get-SpotifyAliases/Test-AliasConflicts alias map now matches the module (added `stats`,
  `live`, `live-music`).
- fix: `spotify` now launches the Spotify app (Start-SpotifyApp) as documented, instead of showing
  help. Use `spotify-help` for help.

v3.2.12
- fix: renamed generic aliases that hijacked other tools' commands: `commands` -> `spcommands`
  (broke `scoop update`), `sh` -> `mix`, `tr` -> `swap`. The module no longer overrides
  PowerShell's built-in `help` (use `spotify-help`/`spotify`). Installer no longer uses AllScope.

v3.2.11
- fix: credentials are now also read from a fixed %APPDATA%\SpotifyCLI\.env and saved there once
  found in the current-directory .env or typed at the prompt, so `play`/`next` run from any folder
  no longer ask for SPOTIFY_CLIENT_ID/SECRET in every new session (regression from v3.2.10).

v3.2.10
- fix: Get-SpotifyAccessToken now self-heals missing credentials (calls Initialize-SpotifyCredentials
  when $script:ClientId/$script:ClientSecret are unset), so bare aliases like `next`/`play` used
  outside Start-SpotifyCLI no longer fail with "Credentials not set" once the stored token expires.

v3.0.0
- Live Display: real-time now-playing with progress bar (detailed/compact/minimal modes)
- Synchronized lyrics via LRCLIB (LRC format, 100ms sync) with Genius/Musixmatch fallback
- Music Quiz: multiple-choice artist + song quiz from your listening history
- Setlist lookup: fetch concert setlists from setlist.fm and build a Spotify playlist
- Peak Dashboard: WinForms analytics window with listening statistics
- WinForms Now-Playing window: always-on-top floating display with playback controls
- Sidecar mode: split-pane launch in Windows Terminal / VS Code
- Interactive arrow-key navigation for search, playlists, and queue
- Multi-level caching and graceful offline degradation
- 100+ functions and aliases for full Spotify control
'@
        }
    }
}
