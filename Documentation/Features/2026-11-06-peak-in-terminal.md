# Peak i terminalen

**Version:** v3.2.15 (2026-11-06)
**Berörda filer:** `modules/UI/PeakDashboard.psm1`, `SpotifyCLI.psd1`, `SpotifyCLI.psm1`
(`spcommands`), `modules/Core/AliasManagement.psm1`, `modules/Core/InstallationCommands.psm1`,
`Clear-SpotifyCliInstallation.ps1`, `README.md`

## Bakgrund

Peak visade låt- och artistinsikter bara i ett WinForms-fönster. Användaren arbetar i PowerShell
och ville se samma information direkt i terminalen.

## Kommandon

| Kommando | Alias | Gör |
|---|---|---|
| `Show-SpotifyPeak` | `peak` | Skriver ut insikterna en gång i terminalen |
| `Show-SpotifyPeak -Watch` | `peak -Watch` | Ritar om varannan sekund, med status (Playing/Paused) och popularitetsgraf för senaste 10 låtarna. Ctrl+C avslutar. |
| `Show-PeakDashboard` | `showpeak` | Fönstret (tidigare `peak`), uppdateras själv |
| `Get-SpotifyPeakInfo` | – | Returnerar datan som objekt, för egna skript |

Det interaktiva CLI:ts `/peak` öppnar fortfarande fönstret.

## Implementation

- **`Get-SpotifyPeakInfo [-ArtistData]`** anropar `/me/player` och `/artists/{id}` och returnerar ett
  `PSCustomObject`: `Uri`, `Track`, `Artists`, `IsPlaying`, `TrackPop`, `ArtistPop`, `Followers`,
  `Genres`, `DurationMs`, `Album`, `ReleaseDate`, `TrackNumber`, `TotalTracks`, `Explicit`,
  `ArtistData`. Returnerar `$null` när inget spelas. `-ArtistData` återanvänds om artisten är
  densamma, så `-Watch` gör bara ett artistanrop per artistbyte.
- **`Write-SpotifyPeakInfo`** (intern, exporteras inte) ritar layouten: staplar med `█`/`░`
  (30 tecken), följare formaterade som K/M, längd m:ss, album/utgivning, upp till fyra genrer
  (`n/a` om tomt), `EXPLICIT`-märke och historikgraf med `▁`–`█`.
- **`Show-SpotifyPeak -Watch`** loopar med `Clear-Host` + 2 s paus; historiken får en punkt per ny låt.
- Fönsterkoden körs i en egen `pwsh`-process (here-string) och har kvar sin egen hämtning; den är
  oförändrad.

## Verifiering

- `peak` mot riktig uppspelning gav samma värden som fönstret (popularitet 65/63, följare 566,6K,
  längd 2:46, album, utgivning, spårnummer, genrer).
- Testdata: explicit-märke, saknad artistdata (`---`), genrer och historikgraf renderas rätt i UTF-8.
- `peak -Watch` testat av användaren i riktig terminal: uppdateras och rensar skärmen rent.
- Inga parserfel; aliasen pekar rätt; aliaslistan matchar sessionen (25 alias); `spcommands` visar
  båda Peak-kommandona.
