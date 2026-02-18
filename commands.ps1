Write-Host ""
Write-Host "  ALL COMMANDS - Terminal Control Spotify" -ForegroundColor Cyan
Write-Host "  =======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  PLAYBACK" -ForegroundColor Yellow
Write-Host "    /spotify [compact]          Show current track info" -ForegroundColor Gray
Write-Host "    /play                       Resume playback" -ForegroundColor Gray
Write-Host "    /play track <uri>           Play specific track" -ForegroundColor Gray
Write-Host "    /play album <uri>           Play specific album" -ForegroundColor Gray
Write-Host "    /play playlist <uri>        Play specific playlist" -ForegroundColor Gray
Write-Host "    /pause                      Pause playback" -ForegroundColor Gray
Write-Host "    /next                       Skip to next track" -ForegroundColor Gray
Write-Host "    /previous                   Go to previous track" -ForegroundColor Gray
Write-Host "    /seek <seconds>             Seek forward/backward" -ForegroundColor Gray
Write-Host "    /volume <0-100>             Set volume" -ForegroundColor Gray
Write-Host "    /shuffle <on|off>           Toggle shuffle" -ForegroundColor Gray
Write-Host "    /repeat <track|context|off> Set repeat mode" -ForegroundColor Gray
Write-Host ""
Write-Host "  LIBRARY" -ForegroundColor Yellow
Write-Host "    /search <query>             Search tracks, artists, albums" -ForegroundColor Gray
Write-Host "    /queue <uri>                Add track to queue" -ForegroundColor Gray
Write-Host "    /play-queue                 Show/manage play queue" -ForegroundColor Gray
Write-Host "    /playlists                  Show your playlists" -ForegroundColor Gray
Write-Host "    /liked                      Show liked songs" -ForegroundColor Gray
Write-Host "    /recent                     Recently played tracks" -ForegroundColor Gray
Write-Host "    /save                       Like current track" -ForegroundColor Gray
Write-Host "    /unsave                     Unlike current track" -ForegroundColor Gray
Write-Host ""
Write-Host "  DEVICES" -ForegroundColor Yellow
Write-Host "    /devices                    List Spotify Connect devices" -ForegroundColor Gray
Write-Host "    /transfer <id>              Transfer playback to device" -ForegroundColor Gray
Write-Host ""
Write-Host "  LIVE & DISPLAY" -ForegroundColor Yellow
Write-Host "    /live [mode]                Live display (detailed/compact/minimal)" -ForegroundColor Gray
Write-Host "    /sidecar [options]          Split window mode" -ForegroundColor Gray
Write-Host "    /lyrics [artist - title]    Show synced lyrics" -ForegroundColor Gray
Write-Host ""
Write-Host "  FUN" -ForegroundColor Yellow
Write-Host "    /quiz [rounds]              Multiple choice quiz (artist + song)" -ForegroundColor Gray
Write-Host "    /peak                       Track insights dashboard" -ForegroundColor Gray
Write-Host "    /setlist <artist>            Concert setlists + playlist" -ForegroundColor Gray
Write-Host ""
Write-Host "  SYSTEM" -ForegroundColor Yellow
Write-Host "    /config [key] [value]       View/modify configuration" -ForegroundColor Gray
Write-Host "    /config-live [command]      Live features configuration" -ForegroundColor Gray
Write-Host "    /history [N|clear]          Playback history" -ForegroundColor Gray
Write-Host "    /notifications <on|off>     Toggle notifications" -ForegroundColor Gray
Write-Host "    /auto-refresh <seconds|off> Auto-refresh display" -ForegroundColor Gray
Write-Host "    /help [command]             Help (detailed per command)" -ForegroundColor Gray
Write-Host "    /commands                   This list" -ForegroundColor Gray
Write-Host "    /quit                       Exit the CLI" -ForegroundColor Gray
Write-Host ""
Write-Host "  ALIASES" -ForegroundColor Yellow
Write-Host "    pn, plays-now = /spotify    pq = /play-queue    q = /quit" -ForegroundColor DarkGray
Write-Host ""
