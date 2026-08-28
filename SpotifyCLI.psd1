@{
    RootModule = 'SpotifyCLI.psm1'
    ModuleVersion = '3.2.7'
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
    AliasesToExport = @('plays-now', 'music', 'pn', 'sp', 'pl', 'vol', 'sh', 'rep', 'tr', 'q', 'pq', 'spotify', 'help', 'spotify-help', 'slw', 'ShowLyrics', 'quiz', 'peak', 'setlist', 'commands', 'stats', 'live', 'live-music', 'ss', 'ShowSpotify')
    PrivateData = @{
        PSData = @{
            Tags = @('Spotify', 'Music', 'CLI', 'Audio', 'Player', 'Terminal', 'PowerShell', 'NowPlaying', 'Playback', 'Lyrics', 'LiveDisplay', 'Statistics', 'Quiz', 'Setlist', 'PSModule')
            ProjectUri = 'https://github.com/Orca85/terminal_control_spotify'
            LicenseUri = 'https://github.com/Orca85/terminal_control_spotify/blob/main/LICENSE'
            ReleaseNotes = @'
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
