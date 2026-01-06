# Plan: Fixa Syntax-fel i Spotify CLI Projekt

## Sammanfattning
Projektet har 23+ syntax-fel introducerade under refactoring-commits (be9eb57, 5596b00, 030cfea). Den gamla globalt installerade versionen (SpotifyCommands 3.0.0) fungerar fortfarande, men den nya modulariserade koden kan inte laddas på grund av:

1. **Circular class dependencies** i ErrorHandling.psm1
2. **Multiple generic catch blocks** (ogiltig PowerShell syntax)
3. **Missing type definitions** ([AuthenticationException] inte tillgänglig när den används)

## Kritiska Filer att Fixa

### Högsta Prioritet (Blockerar allt)
- `modules/Core/ErrorHandling.psm1` - Circular dependency mellan klasser
- `modules/Core/ApiClientManager.psm1` - Använder typer som inte är definierade

### Medelhög Prioritet (Blockerar kommandon)
- `modules/Core/AppCommands.psm1` - 1 instans av multiple catch blocks
- `modules/Core/PlaybackCommands.psm1` - 10 instanser av multiple catch blocks
- `modules/Core/PlaylistQueueCommands.psm1` - 4 instanser av multiple catch blocks
- `modules/Core/SearchCommands.psm1` - Behöver verifieras

## Detaljerad Fix-Plan

### Steg 1: Fixa ErrorHandling.psm1 (Kritiskt)

**Problem identifierat:**
- Rad 148: `ErrorHandler` class försöker använda `[GracefulDegradationManager]`
- Rad 497: `GracefulDegradationManager` är inte definierad förrän här
- PowerShell kan inte parse en class som refererar till en klass som ännu inte existerar

**Lösning:**
1. Flytta class-definitionen för `GracefulDegradationManager` (rad 497-600) till FÖRE `ErrorHandler` class (före rad 144)
2. Verifiera att alla klasser är definierade i rätt ordning:
   - Base exceptions först (SpotifyLiveFeatureException)
   - Derived exceptions (LiveDisplayException, LyricsException, etc.)
   - Utility classes (GracefulDegradationManager, ErrorContextBuilder)
   - Main classes (ErrorHandler)

**Påverkade rader:**
- ErrorHandling.psm1:144-148 (ErrorHandler class declaration)
- ErrorHandling.psm1:497-600 (GracefulDegradationManager definition)

---

### Steg 2: Fixa ApiClientManager.psm1 (Kritiskt)

**Problem identifierat:**
- Rad 860, 882, 1038, 1044, 1062, 1230, 1234: Använder `[AuthenticationException]`, `[RateLimitException]`, `[ApiClientException]`, `[ConfigurationException]`
- Dessa klasser är definierade i ErrorHandling.psm1
- Men när ApiClientManager.psm1 parsas är ErrorHandling.psm1 redan laddad (import-ordningen är korrekt)

**Problem:** Klasserna är inte tillgängliga i PowerShell namespace även om modulen är importerad.

**Lösning:**
1. Lägg till `using module` statement längst upp i ApiClientManager.psm1:
   ```powershell
   using module .\ErrorHandling.psm1
   ```

   ELLER

2. Byt ut alla typed exception throws till generic exceptions med error codes:
   ```powershell
   # Istället för:
   throw [AuthenticationException]::new("Token refresh failed")

   # Använd:
   throw [System.Exception]::new("AUTHENTICATION_ERROR: Token refresh failed")
   ```

**Rekommendation:** Använd lösning #1 (`using module`) eftersom det är mer type-safe och matchar design-intentionen.

**Påverkade rader:**
- ApiClientManager.psm1:1 (lägg till using statement)
- ApiClientManager.psm1:860, 882, 1038, 1044, 1062, 1230, 1234 (throw statements)

---

### Steg 3: Fixa Multiple Catch Blocks (Alla Command-moduler)

**Problem identifierat:**
PowerShell tillåter inte flera generic `catch { }` blocks. Syntaxen måste vara:
```powershell
# OGILTIGT:
catch { }  # Generic catch #1
catch { }  # Generic catch #2 - FEL!

# GILTIGT:
catch [SpecificException] { }
catch [AnotherException] { }
catch { }  # Generic catch MÅSTE vara sist
```

**Lösning (beslutad med användaren):**

**Consolidate till en catch block med if/elseif:**

```powershell
try {
    # kod
}
catch {
    $errorMessage = $_.Exception.Message

    # Check error type based on message content
    if ($errorMessage -match "401|Unauthorized") {
        Write-Host "🔐 Authentication Error: Your Spotify session has expired." -ForegroundColor Red
        Write-Host "💡 Solution: Run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
    }
    elseif ($errorMessage -match "404|Not Found") {
        Write-Host "❌ Could not find resource." -ForegroundColor Red
        Write-Host "💡 API Error: $errorMessage" -ForegroundColor Yellow
    }
    else {
        Write-Host "❌ An unexpected error occurred: $errorMessage" -ForegroundColor Red
    }
}
```

**Fördelar:**
- Enklare att implementera
- Behöver inte känna till exakta exception-typer
- Behåller specifika felmeddelanden för användaren
- Mindre kod-duplication

**Filer att fixa:**

1. **AppCommands.psm1**
   - Rad 299-309: Show-SpotifyTrack function

2. **PlaybackCommands.psm1** (10 instanser)
   - Rad 125-137: pause function
   - Rad 156-168: next function
   - Rad 187-199: previous function
   - Rad 221-233: volume function
   - Rad 283-293: seek function
   - Rad 358-369: shuffle function
   - Rad 400-411: repeat function
   - Rad 465-477: transfer function
   - Rad 599-610: export-now-playing function
   - Rad 651-662: copy-track-link function

3. **PlaylistQueueCommands.psm1** (4 instanser)
   - Rad 181-192: Show-SpotifyQueue function
   - Rad 217-228: Clear-SpotifyQueue function
   - Rad 249-260: Remove-SpotifyQueueTrack function
   - Rad 312-328: Add-SpotifyQueueTrack function

---

### Steg 4: Verifiera Import-ordning i SpotifyModule.psm1

**Nuvarande ordning (rad 20-41):**
```powershell
try {
    Import-Module (Join-Path $PSScriptRoot "modules\Core\ErrorHandling.psm1") -Force -Global
    Import-Module (Join-Path $PSScriptRoot "modules\Core\ApiClientManager.psm1") -Force -Global
    # ... resten
}
catch {
    Write-Warning "Failed to load Core modules: $($_.Exception.Message)"
}
```

**Problem:** Generic catch döljer vilket modul som failade.

**Lösning:**
```powershell
$moduleLoadErrors = @()

# ErrorHandling first (required by others)
try {
    Import-Module (Join-Path $PSScriptRoot "modules\Core\ErrorHandling.psm1") -Force -Global -ErrorAction Stop
} catch {
    $moduleLoadErrors += "ErrorHandling: $($_.Exception.Message)"
}

# ApiClientManager (requires ErrorHandling)
try {
    Import-Module (Join-Path $PSScriptRoot "modules\Core\ApiClientManager.psm1") -Force -Global -ErrorAction Stop
} catch {
    $moduleLoadErrors += "ApiClientManager: $($_.Exception.Message)"
}

# ... continue for other modules

if ($moduleLoadErrors.Count -gt 0) {
    Write-Warning "Failed to load the following modules:"
    $moduleLoadErrors | ForEach-Object { Write-Warning "  - $_" }
}
```

**Påverkade rader:**
- SpotifyModule.psm1:20-41

---

### Steg 5: Test-plan

Efter alla fixes, testa i denna ordning:

1. **Test ErrorHandling.psm1 isolerat:**
   ```powershell
   Import-Module .\modules\Core\ErrorHandling.psm1 -Force -Verbose
   ```
   ✅ Förväntat: Inga parser errors

2. **Test ApiClientManager.psm1 isolerat:**
   ```powershell
   Import-Module .\modules\Core\ApiClientManager.psm1 -Force -Verbose
   ```
   ✅ Förväntat: Inga "Unable to find type" errors

3. **Test varje Command-modul:**
   ```powershell
   Import-Module .\modules\Core\AppCommands.psm1 -Force -Verbose
   Import-Module .\modules\Core\PlaybackCommands.psm1 -Force -Verbose
   Import-Module .\modules\Core\PlaylistQueueCommands.psm1 -Force -Verbose
   ```
   ✅ Förväntat: Inga "Catch block must be the last" errors

4. **Test SpotifyModule.psm1:**
   ```powershell
   Import-Module .\SpotifyModule.psm1 -Force -Verbose
   ```
   ✅ Förväntat: Alla moduler laddas utan errors

5. **Test funktionalitet:**
   ```powershell
   search "test"
   Show-SpotifyTrack
   pause
   ```
   ✅ Förväntat: Kommandon fungerar korrekt

---

## Sammanfattning av Ändringar

| Fil | Antal ändringar | Typ av fix |
|-----|-----------------|------------|
| ErrorHandling.psm1 | 1 | Flytta class definition före användning |
| ApiClientManager.psm1 | 1 | Lägg till `using module` statement |
| AppCommands.psm1 | 1 | Consolidate catch blocks |
| PlaybackCommands.psm1 | 10 | Consolidate catch blocks |
| PlaylistQueueCommands.psm1 | 4 | Consolidate catch blocks |
| SpotifyModule.psm1 | 1 | Förbättra error handling i imports |
| **TOTALT** | **18 ändringar** | **3 typer av fixes** |

## Estimerad Komplexitet

- **ErrorHandling.psm1 fix:** 🟡 Medium (flytta class, verifiera dependencies)
- **ApiClientManager.psm1 fix:** 🟢 Enkel (lägg till en rad)
- **Catch blocks fix:** 🟢 Enkel (repetitiv ändring)
- **SpotifyModule.psm1 fix:** 🟢 Enkel (förbättra logging)

**Total tid:** ~30-45 minuter för alla fixes + testing

## Risker och Mitigering

**Risk 1:** Flytta GracefulDegradationManager kan bryta andra dependencies
- **Mitigering:** Gör en textual search efter alla referenser till klassen först

**Risk 2:** `using module` kan inte fungera med relativ path
- **Mitigering:** Testa först, fallback till absolut path eller ta bort typed exceptions

**Risk 3:** Consoliderade catch blocks kan missa specifika error-typer
- **Mitigering:** Logga alla errors och verifiera att rätt meddelanden visas

## Nästa Steg Efter Fixes

1. Ta bort gamla globala SpotifyCommands 3.0.0:
   ```powershell
   Remove-Module SpotifyCommands -Force
   Remove-Item "C:\Users\tommy\Documents\PowerShell\Modules\SpotifyCommands" -Recurse -Force
   ```

2. Kör installation av nya versionen:
   ```powershell
   .\Install-SpotifyCLI-LiveFeatures.ps1
   ```

3. Verifiera att nya versionen används:
   ```powershell
   Get-Module SpotifyCommands | Select-Object Version, ModuleBase
   ```
