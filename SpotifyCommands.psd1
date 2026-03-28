@{
    RootModule = 'SpotifyCommands.psm1'
    ModuleVersion = '3.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'Spotify CLI Enhanced with Live Features'
    Description = 'Enhanced Spotify CLI with live display, lyrics, statistics, and cross-platform compatibility'
    PowerShellVersion = '5.0'
    NestedModules = @(
        'modules\SpotifyLiveFeatures.psm1',
        'modules\Core\ErrorHandling.psm1',
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
        'modules\Core\InstallationCommands.psm1'
    )
    FunctionsToExport = @(
        # Root module (SpotifyCommands.psm1)
        'Show-SpotifyTrack',
        'Get-SpotifyHelp',
        'Invoke-HelpCommand',
        'Get-SpotifyLyrics',
        'Show-AllSpotifyCommands',
        'Start-SpotifyCliInNewWindow',
        'Get-TerminalCapabilities',

        # AppCommands
        'Start-SpotifyApp',
        'spotify-now',
        'notifications',
        'Test-NotificationSupport',
        'Test-SplitWindowSupport',
        'Get-SpotifyCliTroubleshootingGuide',

        # PlaybackCommands
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

        # SearchCommands
        'search',
        'search-albums',

        # PlaylistQueueCommands
        'playlists',
        'play-playlist',
        'queue-playlist',
        'liked',
        'recent',
        'save-track',
        'unsave-track',
        'queue',
        'queue-album',
        'play-album',

        # LegacyApiClient
        'Invoke-SpotifyApi',
        'Test-SpotifyAuth',

        # StateManager
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

        # ApiClientManager
        'New-EnhancedSpotifyApiClient',
        'Get-SpotifyApiClientStats',
        'Clear-SpotifyApiClientCache',
        'Reset-SpotifyApiClientStats',

        # ErrorHandling
        'Invoke-WithErrorHandling',
        'Test-OfflineMode',
        'Test-FeatureEnabled',
        'Get-DegradationStatus',
        'Invoke-WithGracefulDegradation',

        # UIHelpers
        'Format-Time',
        'Show-ProgressBar',
        'Get-StatusColor',
        'Get-TrackColor',
        'Get-ArtistColor',
        'Get-AlbumColor',
        'Get-ProgressColor',

        # InteractiveMode
        'Start-InteractiveMode',
        'Show-InteractiveItems',

        # ConfigManager
        'Get-SpotifyConfig',
        'Set-SpotifyConfig',

        # LiveFeatures
        'Initialize-SpotifyLiveFeatures',
        'Start-SpotifyLiveDisplay',
        'Stop-SpotifyLiveDisplay',
        'Get-SpotifyCurrentTrackLyrics',
        'Get-SpotifyListeningStatistics',
        'Get-SpotifyLiveFeaturesStatus',
        'Set-SpotifyLiveFeaturesConfiguration',
        'Reset-SpotifyLiveFeaturesConfiguration',
        'Start-SpotifySidecar',

        # UI
        'Show-SpotifyForm',
        'Show-LyricsForm',
        'Show-PeakDashboard',

        # Quiz
        'Start-MusicQuiz',

        # Setlist
        'Invoke-SetlistCommand',

        # AliasManagement
        'Get-SpotifyAliases',
        'Remove-SpotifyAlias',
        'Test-AliasConflicts',

        # InstallationCommands
        'Install-SpotifyCliDependencies',
        'Repair-SpotifyCliInstallation',
        'Uninstall-SpotifyCli'
    )
    AliasesToExport = @('plays-now', 'music', 'pn', 'sp', 'pl', 'vol', 'sh', 'rep', 'tr', 'q', 'pq', 'spotify', 'help', 'spotify-help', 'slw', 'ShowLyrics', 'quiz', 'peak', 'setlist', 'commands')
    PrivateData = @{
        PSData = @{
            Tags = @('Spotify', 'Music', 'CLI', 'LiveFeatures', 'Lyrics', 'Statistics')
            ProjectUri = 'https://github.com/spotify-cli/enhanced'
            ReleaseNotes = 'Version 3.0.0 - Added Live Features: Real-time display, lyrics engine, and statistics analytics'
        }
    }
}
