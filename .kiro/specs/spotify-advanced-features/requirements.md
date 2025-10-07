# Requirements Document

## Introduction

This specification outlines advanced features and improvements for the Spotify CLI PowerShell module to enhance user experience, expand functionality, and improve cross-platform compatibility. The focus is on making the CLI more intuitive, feature-complete, and accessible across different environments while maintaining the existing simplicity and ease of use.

## Requirements

### Requirement 1: Global Toast Notifications

**User Story:** As a user, I want toast notifications to work consistently across all PowerShell environments (standalone PowerShell, PowerShell ISE, VS Code terminal, Kiro terminal, etc.), so that I always get visual feedback when tracks change regardless of where I'm using the CLI.

#### Acceptance Criteria

1. WHEN I use any Spotify command that changes tracks THEN the system SHALL display a toast notification in all supported PowerShell environments
2. WHEN I run the CLI in standalone PowerShell THEN toast notifications SHALL work identically to Kiro terminal
3. WHEN I run the CLI in PowerShell ISE or VS Code terminal THEN toast notifications SHALL still function properly
4. WHEN toast notifications fail THEN the system SHALL gracefully fallback to console notifications
5. WHEN I test notifications using `notifications test` THEN it SHALL work in any PowerShell environment

### Requirement 2: Playlist Playback with Smart Numbers

**User Story:** As a user, I want to browse and play my playlists using simple numbers instead of copying long URIs, so that I can quickly access my music collections without dealing with complex identifiers.

#### Acceptance Criteria

1. WHEN I run `playlists` THEN the system SHALL display my playlists with numbered references (1, 2, 3...)
2. WHEN I use `play-playlist 1` or similar command THEN the system SHALL start playing playlist #1 from the list
3. WHEN I use `queue-playlist 2` THEN the system SHALL add all tracks from playlist #2 to the current queue
4. WHEN playlists are displayed THEN each SHALL show playlist name, track count, and description if available
5. WHEN I reference a playlist number that doesn't exist THEN the system SHALL show an appropriate error message
6. WHEN I want to play a specific track from a playlist THEN the system SHALL support `play-playlist 1 5` to play track #5 from playlist #1
7. WHEN browsing playlists THEN I SHALL be able to use arrow keys to navigate up/down through the list
8. WHEN I press Enter on a highlighted playlist THEN it SHALL start playing that playlist
9. WHEN browsing playlists THEN I SHALL be able to type a number to quickly jump to that playlist

### Requirement 3: Album Playback with Intuitive Interface

**User Story:** As a user, I want to search for and play albums using an intuitive interface with numbered references, so that I can easily discover and play complete albums without complex commands.

#### Acceptance Criteria

1. WHEN I search for music THEN the results SHALL include albums with numbered references alongside tracks
2. WHEN I use `play-album 1` THEN the system SHALL start playing the first album from search results
3. WHEN I use `search-albums "artist name"` THEN the system SHALL show only album results with track counts
4. WHEN an album is playing THEN the system SHALL show album information in the current track display
5. WHEN I queue an album THEN the system SHALL add all album tracks to the queue in correct order
6. WHEN I browse albums THEN each SHALL display album name, artist, release year, and track count
7. WHEN browsing album search results THEN I SHALL be able to use arrow keys to navigate through the list
8. WHEN I press Enter on a highlighted album THEN it SHALL start playing that album
9. WHEN browsing albums THEN I SHALL be able to type a number to quickly select that album

### Requirement 4: Smart Pause/Resume Toggle

**User Story:** As a user, I want the pause command to intelligently toggle between pause and resume, so that I can use one simple command to control playback state without remembering separate commands.

#### Acceptance Criteria

1. WHEN music is currently playing AND I run `pause` THEN the system SHALL pause the music
2. WHEN music is currently paused AND I run `pause` THEN the system SHALL resume the music
3. WHEN no music is active AND I run `pause` THEN the system SHALL show an appropriate message
4. WHEN the pause/resume action succeeds THEN the system SHALL show clear feedback about the new state
5. WHEN I use `play` command THEN it SHALL always resume playback regardless of current state
6. WHEN I use dedicated `resume` command THEN it SHALL always attempt to resume playback

### Requirement 5: Spotify Application Launcher and Command Restructure

**User Story:** As a user, I want the `spotify` command to launch the Spotify application, and I want intuitive commands like `plays-now`, `music`, and `pn` to show what's currently playing, so that the commands are more logical and the main `spotify` command does what I expect it to do.

#### Acceptance Criteria

1. WHEN I run `spotify` THEN the system SHALL launch the Spotify desktop application if not running
2. WHEN I run `spotify` AND Spotify is already running THEN it SHALL show a message that Spotify is active and ready
3. WHEN I run `plays-now`, `music`, or `pn` THEN the system SHALL display the current track information (detailed view)
4. WHEN I run `spotify-now` THEN the system SHALL display current track in compact mode
5. WHEN Spotify is not installed THEN the `spotify` command SHALL provide helpful guidance on installation
6. WHEN the Spotify app launches THEN the system SHALL wait for it to become available before confirming success
7. WHEN launching fails THEN the system SHALL provide clear error messages and troubleshooting steps
8. WHEN I want to open Spotify Web Player THEN the system SHALL support `spotify --web` flag
9. WHEN aliases are updated THEN existing `sp` alias SHALL point to `plays-now` instead of the old command

### Requirement 6: Sidecar/Split Window Integration

**User Story:** As a user, I want the interactive spotifyCLI to open in a split window or sidecar when launched, so that I can use it alongside my main work without it taking over my entire terminal session.

#### Acceptance Criteria

1. WHEN I run `./spotifyCLI.ps1` THEN it SHALL detect if running in a supported terminal with split window capability
2. WHEN split window is supported THEN the CLI SHALL offer to open in a new pane/split
3. WHEN running in Windows Terminal THEN it SHALL use Windows Terminal's split pane functionality
4. WHEN running in VS Code terminal THEN it SHALL integrate with VS Code's terminal splitting
5. WHEN split window is not available THEN it SHALL run normally in the current terminal
6. WHEN the user prefers full window THEN there SHALL be an option to disable split window behavior

### Requirement 7: Podcast Support and Detection

**User Story:** As a user, I want the CLI to properly display and handle podcast content when I'm listening to podcasts on Spotify, so that I get appropriate information and controls for podcast episodes.

#### Acceptance Criteria

1. WHEN a podcast episode is currently playing THEN the display SHALL show podcast-specific information (episode title, show name, description)
2. WHEN displaying podcast progress THEN it SHALL show episode duration and current position appropriately
3. WHEN podcast episodes are in search results THEN they SHALL be clearly marked as podcasts with episode information
4. WHEN I use playback controls on podcasts THEN they SHALL work appropriately (seek, pause, resume)
5. WHEN I save a podcast episode THEN it SHALL be added to my saved episodes
6. WHEN browsing recent activity THEN podcast episodes SHALL be displayed with appropriate podcast icons and information

### Requirement 8: Cross-Terminal Compatibility

**User Story:** As a user, I want the Spotify CLI to work seamlessly across different terminal applications and PowerShell environments, so that I can use it regardless of my preferred development setup.

#### Acceptance Criteria

1. WHEN I use the CLI in Windows PowerShell 5.1 THEN all features SHALL work as expected
2. WHEN I use the CLI in PowerShell 7+ THEN all features SHALL work as expected
3. WHEN I use the CLI in Windows Terminal THEN all visual elements SHALL display correctly
4. WHEN I use the CLI in VS Code integrated terminal THEN all functionality SHALL be available
5. WHEN I use the CLI in PowerShell ISE THEN core functionality SHALL work (with graceful degradation for unsupported features)
6. WHEN I use the CLI in third-party terminals THEN it SHALL detect capabilities and adapt accordingly
7. WHEN terminal features are not available THEN the system SHALL provide appropriate fallbacks

### Requirement 9: Simplified Installation Process

**User Story:** As a user, I want the installation process to be as simple as possible with minimal manual steps, so that I can get started quickly without complex setup procedures.

#### Acceptance Criteria

1. WHEN I run the installation script THEN it SHALL automatically detect and install all required dependencies
2. WHEN dependencies are missing THEN the installer SHALL provide clear instructions or automatic installation options
3. WHEN I install the module THEN it SHALL automatically configure PowerShell profiles for global access
4. WHEN installation completes THEN it SHALL provide a simple verification test to confirm everything works
5. WHEN I'm a new user THEN the installer SHALL guide me through Spotify app setup with clear instructions
6. WHEN installation fails THEN it SHALL provide clear troubleshooting steps and common solutions
7. WHEN I want to uninstall THEN there SHALL be a simple uninstall script that removes all components cleanly

### Requirement 10: Interactive Navigation Interface

**User Story:** As a user, I want to navigate through search results, playlists, and albums using arrow keys and keyboard shortcuts, so that I can quickly browse and select content without typing long commands or numbers.

#### Acceptance Criteria

1. WHEN I run `search "query"` THEN I SHALL be able to enter an interactive mode with arrow key navigation
2. WHEN I use arrow keys in search results THEN the highlighted item SHALL be visually indicated
3. WHEN I press Enter on a highlighted track THEN it SHALL play that track immediately
4. WHEN I press Space on a highlighted track THEN it SHALL add that track to the queue
5. WHEN I press 'p' on a highlighted playlist THEN it SHALL play that playlist
6. WHEN I press 'a' on a highlighted album THEN it SHALL play that album
7. WHEN I press Escape or 'q' THEN it SHALL exit interactive mode and return to normal CLI
8. WHEN I type a number in interactive mode THEN it SHALL jump to that numbered item
9. WHEN I press 's' on a highlighted track THEN it SHALL save/unsave that track
10. WHEN interactive mode is active THEN it SHALL show keyboard shortcuts at the bottom of the screen

### Requirement 11: Updated Command Aliases and Structure

**User Story:** As a user, I want the command structure to be more intuitive with `spotify` launching the app and clear commands for showing current playback, so that the CLI feels more natural and logical to use.

#### Acceptance Criteria

1. WHEN the module loads THEN the following aliases SHALL be available:
   - `spotify` → Launch Spotify application
   - `plays-now` → Show current track (detailed)
   - `music` → Show current track (detailed)
   - `pn` → Show current track (detailed)
   - `sp` → Show current track (detailed, legacy compatibility)
2. WHEN I use any of the "show current track" aliases THEN they SHALL display identical detailed information
3. WHEN existing users upgrade THEN their current workflows SHALL continue to work with legacy aliases
4. WHEN I run `Get-SpotifyAliases` THEN it SHALL show the updated command structure clearly
5. WHEN I create custom aliases THEN they SHALL not conflict with the new command structure
6. WHEN the help system displays commands THEN it SHALL show the new primary commands while noting legacy alternatives

### Requirement 12: Enhanced Queue Management and Interaction

**User Story:** As a user, I want to easily add tracks to the queue using arrow keys or numbers, and I want to view the current queue with simple commands, so that I can manage my upcoming music without complex operations.

#### Acceptance Criteria

1. WHEN I'm in interactive mode (search, playlists, albums) AND I press Space on a highlighted item THEN it SHALL add that track to the queue
2. WHEN I'm in interactive mode AND I press 'q' on a highlighted track THEN it SHALL add that track to the queue
3. WHEN I use `queue 1`, `queue 2`, etc. from search results THEN it SHALL add those numbered tracks to the queue
4. WHEN I run `queue`, `que`, or `q` without parameters THEN it SHALL display the current playback queue
5. WHEN displaying the queue THEN it SHALL show track names, artists, and queue position with numbered references
6. WHEN the queue is displayed THEN it SHALL highlight the currently playing track
7. WHEN I use `queue clear` THEN it SHALL clear the entire playback queue
8. WHEN I use `queue remove 3` THEN it SHALL remove track #3 from the queue
9. WHEN I add a track to the queue THEN it SHALL show confirmation with track name and queue position
10. WHEN the queue is empty THEN the display SHALL show an appropriate "Queue is empty" message
