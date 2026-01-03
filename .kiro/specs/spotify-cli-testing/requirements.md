# Spotify CLI Testing and Debugging Requirements

## Introduction

This specification defines comprehensive testing requirements for the Spotify CLI to ensure all core functionality works correctly. The current implementation has several broken features that need systematic testing and fixing.

## Requirements

### Requirement 1: Spotify Application Launch

**User Story:** As a user, I want to launch the Spotify application using the `spotify` command, so that I can start the Spotify app from the command line.

#### Acceptance Criteria

1. WHEN I run `spotify` command THEN the system SHALL launch the Spotify desktop application
2. WHEN Spotify is already running THEN the system SHALL confirm it's already active
3. WHEN Spotify is not installed THEN the system SHALL provide installation guidance
4. WHEN launch fails THEN the system SHALL try alternative methods (Windows Store version)
5. WHEN Spotify launches successfully THEN the system SHALL confirm successful launch

### Requirement 2: Authentication System Testing

**User Story:** As a developer, I want to verify that the Spotify authentication system works correctly, so that users can successfully connect to their Spotify accounts.

#### Acceptance Criteria

1. WHEN the CLI starts for the first time THEN the system SHALL prompt for Spotify authentication
2. WHEN authentication is successful THEN the system SHALL store valid tokens locally
3. WHEN tokens expire THEN the system SHALL automatically refresh them using the refresh token
4. WHEN refresh fails THEN the system SHALL prompt for re-authentication
5. WHEN .env file is missing or invalid THEN the system SHALL display clear error messages
6. WHEN authentication completes THEN the system SHALL confirm successful connection

### Requirement 3: Current Track Display Commands

**User Story:** As a user, I want to see current track information using multiple command aliases, so that I can check what's playing with my preferred command.

#### Acceptance Criteria

1. WHEN I run `plays-now` command THEN the system SHALL display detailed current track information
2. WHEN I run `music` command THEN the system SHALL display detailed current track information
3. WHEN I run `pn` command THEN the system SHALL display detailed current track information
4. WHEN I run `Show-SpotifyTrack` command THEN the system SHALL display detailed current track information
5. WHEN I run `sp` command THEN the system SHALL display detailed current track information (legacy)
6. WHEN no track is playing THEN the system SHALL display "No track currently playing"
7. WHEN track is a podcast episode THEN the system SHALL display episode-specific information

### Requirement 4: Core Playback Control Testing

**User Story:** As a user, I want all basic playback controls to work reliably, so that I can control my Spotify playback from the command line.

#### Acceptance Criteria

1. WHEN I run `play` command without parameters THEN the system SHALL resume playback
2. WHEN I run `play 1` command THEN the system SHALL play track #1 from last search results
3. WHEN I run `pause` command THEN the system SHALL pause playback (smart toggle)
4. WHEN I run `next` command THEN the system SHALL skip to next track
5. WHEN I run `previous` command THEN the system SHALL skip to previous track
6. WHEN Spotify app is not running THEN the system SHALL provide helpful guidance
7. WHEN no Premium account THEN the system SHALL explain limitations

### Requirement 5: Advanced Playback Controls Testing

**User Story:** As a user, I want advanced playback controls like volume, seek, shuffle, and repeat, so that I can fully control my music experience.

#### Acceptance Criteria

1. WHEN I run `volume 75` command THEN the system SHALL set volume to 75%
2. WHEN I run `vol 50` command THEN the system SHALL set volume to 50% (alias)
3. WHEN I run `seek 30` command THEN the system SHALL seek forward 30 seconds
4. WHEN I run `seek -15` command THEN the system SHALL seek backward 15 seconds
5. WHEN I run `shuffle on` command THEN the system SHALL enable shuffle mode
6. WHEN I run `shuffle off` command THEN the system SHALL disable shuffle mode
7. WHEN I run `repeat track` command THEN the system SHALL set repeat to track mode
8. WHEN I run `repeat context` command THEN the system SHALL set repeat to context mode
9. WHEN I run `repeat off` command THEN the system SHALL disable repeat

### Requirement 6: Device Management Testing

**User Story:** As a user, I want to see and control Spotify devices, so that I can manage where my music plays.

#### Acceptance Criteria

1. WHEN I run `devices` command THEN the system SHALL list all available Spotify Connect devices with smart numbers
2. WHEN devices are listed THEN each device SHALL show name, type, status, and volume
3. WHEN I run `transfer 1` command THEN playback SHALL transfer to device #1
4. WHEN I run `transfer <device_id>` command THEN playback SHALL transfer to the specified device
5. WHEN I run `tr 2` command THEN playback SHALL transfer to device #2 (alias)
6. WHEN no devices are available THEN the system SHALL display helpful guidance
7. WHEN device transfer fails THEN the system SHALL display clear error messages

### Requirement 7: Enhanced Search Functionality Testing

**User Story:** As a user, I want to search for music, albums, and podcasts with smart numbering, so that I can easily find and play content.

#### Acceptance Criteria

1. WHEN I run `search "bohemian rhapsody"` THEN the system SHALL return relevant tracks and episodes with smart numbers
2. WHEN I run `search-albums "pink floyd"` THEN the system SHALL return relevant albums only
3. WHEN search results are displayed THEN they SHALL be numbered for easy reference
4. WHEN I use `play 1` THEN the system SHALL play the selected item from last search
5. WHEN search includes podcast episodes THEN they SHALL be clearly marked with 🎙️
6. WHEN search returns no results THEN the system SHALL display appropriate message
7. WHEN search fails THEN the system SHALL display clear error messages
8. WHEN I press Enter after search THEN the system SHALL start interactive navigation mode

### Requirement 8: Playlist and Library Management Testing

**User Story:** As a user, I want to view and interact with my playlists and library, so that I can access my organized music collections.

#### Acceptance Criteria

1. WHEN I run `playlists` command THEN the system SHALL display my Spotify playlists with smart numbers
2. WHEN I run `pl` command THEN the system SHALL display my playlists (alias)
3. WHEN playlists are displayed THEN each SHALL show name, track count, and description
4. WHEN I run `play-playlist 1` THEN the system SHALL play playlist #1
5. WHEN I run `play-playlist 1 5` THEN the system SHALL play track #5 from playlist #1
6. WHEN I run `queue-playlist 2` THEN the system SHALL add entire playlist #2 to queue
7. WHEN I run `liked` command THEN the system SHALL show my liked songs
8. WHEN I run `recent` command THEN the system SHALL show recently played tracks
9. WHEN I run `save-track` command THEN the system SHALL save current track to library
10. WHEN I run `unsave-track` command THEN the system SHALL remove current track from library

### Requirement 9: Advanced Queue Management Testing

**User Story:** As a user, I want to manage my playback queue with smart numbers, so that I can control what plays next.

#### Acceptance Criteria

1. WHEN I run `queue` command THEN the system SHALL display current queue with track numbers
2. WHEN I run `q` command THEN the system SHALL display current queue (alias)
3. WHEN I run `queue 2` command THEN track #2 from last search SHALL be added to queue
4. WHEN I run `queue clear` command THEN the system SHALL clear entire queue
5. WHEN I run `queue remove 3` command THEN track #3 SHALL be removed from queue
6. WHEN I run `play-album 1` command THEN album #1 from last search SHALL be played
7. WHEN I run `queue-album 1` command THEN album #1 SHALL be added to queue
8. WHEN queue is empty THEN the system SHALL display appropriate message
9. WHEN queue operations fail THEN the system SHALL display clear error messages

### Requirement 7: Error Handling and User Guidance Testing

**User Story:** As a user, I want clear error messages and guidance when things go wrong, so that I can understand and fix issues.

#### Acceptance Criteria

1. WHEN API calls fail THEN the system SHALL display specific error messages
2. WHEN authentication fails THEN the system SHALL provide troubleshooting steps
3. WHEN Spotify Premium is required THEN the system SHALL explain limitations
4. WHEN no active device exists THEN the system SHALL guide user to activate one
5. WHEN rate limits are hit THEN the system SHALL handle gracefully with user feedback

### Requirement 10: Interactive Navigation Testing

**User Story:** As a user, I want to navigate search results and lists using arrow keys, so that I can have an enhanced interactive experience.

#### Acceptance Criteria

1. WHEN I press Enter after search results THEN the system SHALL start interactive navigation mode
2. WHEN in interactive mode AND I press ↑↓ arrows THEN the system SHALL navigate through items
3. WHEN in interactive mode AND I press Enter THEN the system SHALL play selected item
4. WHEN in interactive mode AND I press Space THEN the system SHALL add selected item to queue
5. WHEN in interactive mode AND I press 1-9 THEN the system SHALL jump to numbered item
6. WHEN in interactive mode AND I press Escape THEN the system SHALL exit interactive mode
7. WHEN in interactive mode THEN the system SHALL highlight selected item clearly

### Requirement 11: Configuration and Help System Testing

**User Story:** As a user, I want comprehensive help and configuration options, so that I can customize and understand the CLI.

#### Acceptance Criteria

1. WHEN I run `Get-SpotifyHelp` command THEN the system SHALL display comprehensive help
2. WHEN I run `help` command THEN the system SHALL display comprehensive help (alias)
3. WHEN I run `spotify-help` command THEN the system SHALL display help (short alias)
4. WHEN I run `Get-SpotifyConfig` command THEN the system SHALL display current configuration
5. WHEN I run `Set-SpotifyConfig @{CompactMode=$true}` THEN the system SHALL update configuration
6. WHEN I run `notifications on` command THEN the system SHALL enable notifications
7. WHEN I run `notifications off` command THEN the system SHALL disable notifications
8. WHEN I run `notifications test` command THEN the system SHALL test notification system

### Requirement 12: Alias Management Testing

**User Story:** As a user, I want to create and manage custom command aliases, so that I can personalize my CLI experience.

#### Acceptance Criteria

1. WHEN I run `Set-SpotifyAlias -Alias 'music' -Command 'Show-SpotifyTrack'` THEN the system SHALL create custom alias
2. WHEN I run `Get-SpotifyAliases` command THEN the system SHALL display all current aliases
3. WHEN I run `Remove-SpotifyAlias -Alias 'music'` THEN the system SHALL remove the specified alias
4. WHEN I run `Test-AliasConflicts` command THEN the system SHALL check for PowerShell command conflicts
5. WHEN alias conflicts with existing PowerShell command THEN the system SHALL prevent creation and warn user

### Requirement 13: Script Mode (Interactive CLI) Testing

**User Story:** As a user, I want to run the CLI in interactive script mode with `/` prefixed commands, so that I can have a dedicated CLI session.

#### Acceptance Criteria

1. WHEN I run `./spotifyCLI.ps1` THEN the system SHALL start interactive CLI mode
2. WHEN in script mode AND I type `/help` THEN the system SHALL show all available commands
3. WHEN in script mode AND I type `/spotify` THEN the system SHALL show current track
4. WHEN in script mode AND I type `/search "query"` THEN the system SHALL search for music
5. WHEN in script mode AND I type `/devices` THEN the system SHALL list devices
6. WHEN in script mode AND I type `/config` THEN the system SHALL manage settings
7. WHEN in script mode AND I type `/quit` THEN the system SHALL exit cleanly
8. WHEN in script mode AND I type invalid command THEN the system SHALL suggest alternatives

### Requirement 9: Configuration and Settings Testing

**User Story:** As a user, I want to configure the CLI behavior, so that it works according to my preferences.

#### Acceptance Criteria

1. WHEN I run `/config` THEN the system SHALL display current configuration
2. WHEN I modify settings THEN changes SHALL persist between sessions
3. WHEN configuration is corrupted THEN the system SHALL use defaults
4. WHEN I reset configuration THEN the system SHALL restore defaults

### Requirement 10: Global Installation and Module Testing

**User Story:** As a user, I want the CLI to work globally from any PowerShell session, so that I can use Spotify commands anywhere without navigating to the project folder.

#### Acceptance Criteria

1. WHEN I run `Install-SpotifyCliDependencies.ps1` THEN the system SHALL install the module globally
2. WHEN installation completes THEN the system SHALL confirm what was installed and where
3. WHEN installation completes THEN I SHALL be able to use `spotify`, `play`, `pause`, etc. from any PowerShell session
4. WHEN I open a new PowerShell window THEN all Spotify commands SHALL be available immediately
5. WHEN I run `Get-Module SpotifyCommands` THEN the module SHALL be listed as available
6. WHEN global commands fail THEN the system SHALL provide troubleshooting guidance

### Requirement 11: Installation Script Verification

**User Story:** As a user, I want confirmation that the installation script actually worked, so that I know the CLI is properly set up.

#### Acceptance Criteria

1. WHEN `Install-SpotifyCliDependencies.ps1` runs THEN it SHALL display what it's doing at each step
2. WHEN installation completes THEN it SHALL list all installed components and their locations
3. WHEN installation completes THEN it SHALL test that commands are working
4. WHEN installation fails THEN it SHALL clearly explain what went wrong and how to fix it
5. WHEN installation completes THEN it SHALL provide next steps for the user
6. WHEN dependencies are missing THEN it SHALL install them and confirm success

### Requirement 12: Uninstallation Script Verification

**User Story:** As a user, I want confirmation that the uninstallation script completely removed the CLI, so that I know my system is clean.

#### Acceptance Criteria

1. WHEN `Uninstall-SpotifyCli.ps1` runs THEN it SHALL display what it's removing at each step
2. WHEN uninstallation completes THEN it SHALL list all removed components
3. WHEN uninstallation completes THEN it SHALL verify that commands are no longer available
4. WHEN uninstallation completes THEN it SHALL confirm the system is clean
5. WHEN some components cannot be removed THEN it SHALL explain what remains and why
6. WHEN user data exists THEN it SHALL ask whether to keep or remove it

### Requirement 13: Integration Testing

**User Story:** As a developer, I want to verify that all components work together, so that the complete user experience is seamless.

#### Acceptance Criteria

1. WHEN I perform a complete workflow (install → auth → search → play → control) THEN all steps SHALL work together
2. WHEN I switch between different command types THEN state SHALL be maintained correctly
3. WHEN I use the CLI over extended periods THEN performance SHALL remain consistent
4. WHEN I restart PowerShell THEN global commands SHALL still work
5. WHEN I uninstall and reinstall THEN everything SHALL work the same way

## Testing Approach

### Manual Testing Requirements

For each requirement, we need to:

1. Test the happy path (everything works correctly)
2. Test error conditions (network issues, invalid input, etc.)
3. Test edge cases (empty results, long strings, special characters)
4. Verify error messages are helpful and actionable

### User Interaction Required

Since I cannot directly test Spotify API interactions, I will need to ask you to:

1. Run specific commands and report results
2. Verify authentication flows work correctly
3. Test with different Spotify account states (Premium vs Free)
4. Test with different device configurations
5. Confirm error messages are appropriate

### Success Criteria

All requirements must pass their acceptance criteria before the CLI can be considered fully functional and ready for users.
