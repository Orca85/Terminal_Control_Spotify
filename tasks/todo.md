# Todo: Implementera 9 saknade funktioner + fixes

## Bakgrund
Installationsscriptet rapporterar "Functions Missing: 17". Orsaker:
- 3 funktioner har fel namn i README
- 2 funktioner finns men exporteras inte i psd1
- 9 funktioner saknar helt implementation
- 1 bug: sidecar startup anropar `Start-SpotifyCliInSidecar` som inte existerar

---

## Fas 1 — Snabbfixar ✅

- [x] **README.md** — Rätta 3 namnfel
- [x] **SpotifyCommands.psd1** — Lägg till `Start-SpotifyCliInNewWindow` + `Get-TerminalCapabilities`
- [x] **spotifyCLI.ps1** — Fixa sidecar startup-bug

---

## Fas 2 — Lägg till i befintliga moduler ✅

- [x] **modules/Core/LegacyApiClient.psm1** — `Test-SpotifyAuth`
- [x] **modules/Core/AppCommands.psm1** — `Test-SplitWindowSupport`, `Get-SpotifyCliTroubleshootingGuide`

---

## Fas 3 — Skapa nya moduler ✅

- [x] **modules/Core/AliasManagement.psm1** — `Get-SpotifyAliases`, `Remove-SpotifyAlias`, `Test-AliasConflicts`
- [x] **modules/Core/InstallationCommands.psm1** — `Install-SpotifyCliDependencies`, `Repair-SpotifyCliInstallation`, `Uninstall-SpotifyCli`

---

## Fas 4 — Uppdatera manifest ✅

- [x] **SpotifyCommands.psd1** — +2 NestedModules, +11 FunctionsToExport

---

## Verifiering

- [ ] Kör `.\Install-SpotifyCLI-Complete.ps1` → "Functions Missing: 0"
- [ ] `Import-Module .\SpotifyCommands.psd1 -Force` → inga fel
- [ ] `Test-SpotifyAuth` → visar token-status
- [ ] `Test-SplitWindowSupport` → detekterar Windows Terminal korrekt
- [ ] `Get-SpotifyAliases` → listar alla alias
- [ ] `Test-AliasConflicts` → hittar/rapporterar konflikter
- [ ] `Get-SpotifyCliTroubleshootingGuide` → visar guide
- [ ] `Uninstall-SpotifyCli -WhatIf` → visar vad som skulle raderas
