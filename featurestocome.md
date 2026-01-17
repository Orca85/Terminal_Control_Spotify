# Features To Come

Planerade funktioner och förbättringar för Spotify CLI.

---

## Automatisk låtbyte-detektion i Lyrics-fönster

**Status:** Planerad
**Prioritet:** Medium
**Komplexitet:** Låg

### Beskrivning

Lyrics-fönstret (`slw`) uppdaterar för närvarande bara positionen inom samma låt. När en ny låt börjar spela måste användaren manuellt stänga och öppna fönstret igen för att se nya lyrics.

### Nuvarande beteende

- Timer uppdaterar playback-position var 100ms
- Synkar position med Spotify API var 5:e sekund
- Highlightar rätt rad baserat på tidsstämplar
- Detekterar **INTE** när en ny låt börjar

### Önskad funktionalitet

Lyrics-fönstret ska automatiskt:
1. Detektera när en ny låt börjar spela
2. Hämta lyrics för den nya låten
3. Uppdatera fönstrets innehåll utan att användaren behöver göra något
4. Fortsätt med real-time highlighting som vanligt

### Teknisk implementation

**Fil att modifiera:** `modules\UI\LyricsFormDisplay.psm1`

**Ändringar i timer-loopen (rad 209-233):**
```powershell
$timer.Add_Tick({
    try {
        # Nuvarande kod för position-uppdatering...

        # NY KOD: Kolla om track har ändrats
        $timeSinceTrackCheck = ($now - $script:lastTrackCheck).TotalMilliseconds
        if ($timeSinceTrackCheck -ge 5000) {  # Kolla var 5:e sekund
            $currentPlayback = Invoke-SpotifyApi -Method GET -Path '/me/player'
            if ($currentPlayback -and $currentPlayback.item -and $currentPlayback.item.id) {
                $newTrackId = $currentPlayback.item.id

                if ($newTrackId -ne $script:currentTrackId) {
                    # Ny låt! Hämta nya lyrics
                    $newLyrics = Get-SpotifyLyrics

                    if ($newLyrics.Success) {
                        # Uppdatera fönster-titel
                        $form.Text = "🎤 Lyrics - $($newLyrics.Artist) - $($newLyrics.Track)"

                        # Återskapa label-lista med nya lyrics
                        # Ta bort gamla labels
                        $lyricsPanel.Controls.Clear()
                        $lineLabels.Clear()

                        # Skapa nya labels från $newLyrics
                        # ... (samma kod som vid första skapandet)

                        $script:currentTrackId = $newTrackId
                    }
                }
            }
            $script:lastTrackCheck = $now
        }
    } catch {
        # Error handling
    }
})
```

**Nödvändiga variabler att lägga till:**
- `$script:currentTrackId` - Spara nuvarande track ID
- `$script:lastTrackCheck` - Timestamp för senaste track-check

### Alternativ approach

**Option A: Återladda hela fönstret**
- Enklare implementation
- Stäng och öppna nytt fönster automatiskt
- Kan orsaka flicker

**Option B: Dynamisk uppdatering (rekommenderat)**
- Mjukare övergång
- Behåll fönster-position och storlek
- Bättre användarupplevelse

### Användarupplevelse

**Före:**
```powershell
slw                    # Öppna för låt 1
# Låt byter...
# [Måste manuellt stänga och öppna igen]
slw                    # Öppna för låt 2
```

**Efter:**
```powershell
slw                    # Öppna en gång
# Låt byter automatiskt...
# Fönstret uppdateras själv med nya lyrics!
# Ingen användarinteraktion krävs
```

### Potentiella problem

1. **API rate limiting** - Kolla track var 5:e sekund kan överskrida rate limits vid många öppna fönster
   - Lösning: Konfigurerbar check-interval (5-10 sekunder)

2. **Lyrics inte tillgängliga** - Vad händer om nya låten inte har lyrics?
   - Lösning: Visa meddelande "No lyrics available" istället för att stänga fönstret

3. **Performance** - Rekonstruera labels kan vara tungt
   - Lösning: Cacha lyrics och återanvänd om möjligt

### Estimerad tid

- Implementation: 1-2 timmar
- Testing: 30 minuter
- Dokumentation: 30 minuter

---

## Andra planerade features

(Lägg till fler features här när de kommer upp)
