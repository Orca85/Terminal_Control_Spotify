# Alias utan krockar och `spcommands` som huvudhjälp

**Versioner:** v3.2.12, v3.2.13, v3.2.14 (2026-11-06)
**Berörda filer:** `SpotifyCLI.psm1`, `SpotifyCLI.psd1`, `modules/Core/AliasManagement.psm1`,
`modules/Core/LegacyConfigManager.psm1`, `modules/Core/InstallationCommands.psm1`,
`Install-SpotifyCLI-Complete.ps1`, `Clear-SpotifyCliInstallation.ps1`, `README.md`

## Bakgrund

`scoop update` slutade fungera. Orsaken var SpotifyCLI-aliaset `commands`: i PowerShell går alias
före funktioner, så Scoops interna funktion `commands` kördes aldrig – i stället visades
`Show-AllSpotifyCommands`. Bekräftat genom att ta bort aliaset (`Remove-Item Alias:commands`), varpå
`scoop update` gick igenom. Fler generiska alias hade samma risk.

## Implementation

### Omdöpta och borttagna alias (v3.2.12)

| Tidigare | Nu | Mål | Varför |
|---|---|---|---|
| `commands` | `spcommands` | hjälpen | kapade Scoops `commands` |
| `sh` | `mix` | `shuffle` | skuggade Git Bash `sh.exe` |
| `tr` | `swap` | `transfer` | skuggade `tr.exe` (`switch` gick inte – reserverat nyckelord) |
| `help` | borttaget | – | skrev över PowerShells inbyggda `help` |
| `sp` | oförändrat | `Show-SpotifyTrack` | användarens val; låg risk |

- `Install-SpotifyCLI-Complete.ps1` sätter inte längre alias med `-Option AllScope` (det gjorde att
  aliasen trängde in även i andra moduler).
- Avinstallations- och rensningslistorna innehåller både gamla och nya namn, så äldre installationer städas.
- `pause` krockar med PowerShell 7:s inbyggda `Pause` men behålls (vanligt kommando, låg risk).
  Installation kräver därför `Install-Module SpotifyCLI -Scope CurrentUser -AllowClobber`.

### `spotify` startar appen (v3.2.13)
`spotify` var dokumenterat (README, installer, `LegacyConfigManager`) som `Start-SpotifyApp` men
pekade i modulen på hjälpen. Nu pekar det överallt på `Start-SpotifyApp`.

### Aliaslistan i `AliasManagement.psm1` (v3.2.13)
`$script:KnownSpotifyAliases` (används av `Get-SpotifyAliases`, `Remove-SpotifyAlias`,
`Test-AliasConflicts`) är synkad med modulen: `stats`, `live`, `live-music` tillagda, `spotify` rättad.
Listan ska hållas i takt med `AliasesToExport` + det globala `sp`.

### `spcommands` – hjälp för PowerShell (v3.2.14)
Användaren kör kommandona direkt i PowerShell, inte i det interaktiva CLI:t. `Get-SpotifyHelp`
(alias `spcommands` och `spotify-help`) visar därför:

- Kategorier: NOW PLAYING, PLAYBACK, SEARCH & LIBRARY, QUEUE, DEVICES, STATS & FUN, SETTINGS.
- Kommandon utan `/`, med argument och kort beskrivning (handskrivet i en `[ordered]`-tabell).
- Aliaskolumnen (grön) läses från sessionen: alla alias vars mål är ett kommando modulen exporterar.
  Den kan därför inte bli inaktuell. Poster vars kommando inte finns hoppas över.
- `spcommands <kommando>` → `Get-Help <kommando> -Detailed`.

Nytt kommando ⇒ lägg till en rad i `Get-SpotifyHelp` (`SpotifyCLI.psm1`); aliasen följer med automatiskt.

Det interaktiva CLI:t är oförändrat: `/help` använder `Invoke-HelpCommand` och `/commands`
använder `Show-AllSpotifyCommands`, båda med sina `/`-listor.

## Lärdomar

- **Gamla installerade versioner autoladdas.** Efter namnbytet låg 3.2.11 kvar bredvid 3.2.12, och
  när `commands` skrevs laddade PowerShell den gamla versionen. Samma sak hände med den äldsta
  modulen `SpotifyCommands` 3.1.0 (tidigare modulnamn), som inte installerats via PowerShellGet.
  Efter alias-namnbyten: kontrollera `Get-Module -ListAvailable SpotifyCLI, SpotifyCommands` och ta
  bort äldre versioner (`Uninstall-Module` respektive `Remove-Item` för manuellt kopierade mappar).
- **Testa lokalt före publicering** med `spdev` (i användarens profil), som kör
  `Import-Module <projekt>\SpotifyCLI.psd1 -Force -Global`.

## Verifiering

Alla steg verifierade i `pwsh -NoProfile` med modulen laddad från projektmappen:
- Nya alias pekar rätt; `commands`, `sh`, `tr` finns inte; `help` är PowerShells egen.
- En egen funktion `commands` (som Scoops) anropas korrekt när modulen är laddad; `scoop update`
  fungerar för användaren.
- `Get-SpotifyAliases` matchar sessionen exakt; `Test-AliasConflicts` hittar inga konflikter.
- `spcommands` täcker alla exporterade kortkommandon utom `spotify-now` (dubblett av
  `Show-SpotifyTrack`); `volume-medium`/`-high` ingår i raden `volume-low|medium|high`.
- Inga parserfel; `Test-ModuleManifest` OK.
