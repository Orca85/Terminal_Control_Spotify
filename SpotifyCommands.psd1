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
        'modules\Core\SetlistCommands.psm1'
    )
    FunctionsToExport = @(
        'Show-SpotifyTrack',
        'play',
        'pause',
        'next',
        'previous',
        'volume',
        'seek',
        'shuffle',
        'repeat',
        'devices',
        'transfer',
        'search',
        'search-albums',
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
        'Start-SpotifyApp',
        'Get-SpotifyHelp',
        'Get-SpotifyConfig',
        'Set-SpotifyConfig',
        'notifications',
        'Initialize-SpotifyLiveFeatures',
        'Start-SpotifyLiveDisplay',
        'Get-SpotifyCurrentTrackLyrics',
        'Get-SpotifyLyrics',
        'Get-SpotifyListeningStatistics',
        'Get-SpotifyLiveFeaturesStatus',
        'Set-SpotifyLiveFeaturesConfiguration',
        'Reset-SpotifyLiveFeaturesConfiguration',
        'Stop-SpotifyLiveFeatures',
        'Start-MusicQuiz',
        'Show-PeakDashboard',
        'Invoke-SetlistCommand'
    )
    AliasesToExport = @('plays-now', 'music', 'pn', 'sp', 'pl', 'vol', 'sh', 'rep', 'tr', 'q', 'pq', 'spotify', 'help', 'spotify-help', 'slw', 'ShowLyrics', 'quiz', 'peak', 'setlist')
    PrivateData = @{
        PSData = @{
            Tags = @('Spotify', 'Music', 'CLI', 'LiveFeatures', 'Lyrics', 'Statistics')
            ProjectUri = 'https://github.com/spotify-cli/enhanced'
            ReleaseNotes = 'Version 3.0.0 - Added Live Features: Real-time display, lyrics engine, and statistics analytics'
        }
    }
}
