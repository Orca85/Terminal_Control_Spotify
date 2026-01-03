# ToDo - Spotify CLI Projekt

Detta dokument sammanfattar projektets status, omedelbara åtgärder och framtida förbättringsmöjligheter. Mycket av detta är baserat på den utmärkta och detaljerade planen som redan finns i `improvments.md`.

---

## Tasks som bör prioriteras

Dessa är uppgifter som kan slutföras direkt, antingen för att slutföra påbörjat arbete eller för att städa upp i projektet.

- **Implementera befintliga `TODOs`:**
  - I `SpotifyModule.psm1` finns tre oimplementerade funktioner som överensstämmer med högprioriterade mål i `improvments.md`:
    - `TODO: Implement scrollable display` för sångtexter.
    - `TODO: Launch interactive menu` för statistik.
    - `TODO: Implement export functionality` för statistik.

- **Rensa gamla filer:**
  - Katalogen `backup-and-broken` innehåller gamla, trasiga och ersatta skript (`*BROKEN*`, `*.backup`). Dessa bör tas bort för att undvika förvirring och för att säkerställa att endast aktuell kod finns kvar i projektet.

---

## Teknisk skuld & Refaktorering

Baserat på en granskning av koden och i linje med "Tekniska Förbättringar" i `improvments.md`, bör följande punkter prioriteras för att förbättra kodkvaliteten och underhållbarheten.

- **Modularisera `SpotifyModule.psm1`:**
  - Denna fil är över 5000 rader lång och innehåller nästan all logik. Den bör delas upp i mindre, mer hanterbara moduler (t.ex. `TokenManager.psm1`, `ApiHelper.psm1`, `PlaybackCommands.psm1`). Detta kommer att göra koden lättare att underhålla och bygga vidare på.

- **Förbättra felhantering:**
  - Funktionen `Invoke-SpotifyApi` hanterar API-fel genom att skriva meddelanden direkt till konsolen. En bättre metod vore att låta funktionen kasta specifika undantag (exceptions) som anropande funktioner kan fånga (`try/catch`). Detta separerar API-logiken från användargränssnittet.

- **Refaktorera stora funktioner:**
  - Funktioner som `Start-SpotifyApp` och `Show-SpotifyTrack` är mycket stora och komplexa. De kan med fördel delas upp i mindre, privata hjälpfunktioner för att öka läsbarheten.

---

## Nya funktioner (Roadmap)

Filen `improvments.md` innehåller en detaljerad roadmap. Här är en sammanfattning av den första fasen:

- **Fas 1 - Kärnförbättringar:**
  1.  **Real-time Animation & Live Display**: Implementera `spotify --live` med kontinuerlig uppdatering, "Sidecar Mode" och CPU-optimering.
  2.  **Queue Management**: Full kontroll över uppspelningskön (`show-queue`, `queue-remove`, `queue-move`, `queue-save`).
  3.  **Listening Statistics**: Implementera den grundläggande funktionen för att samla in och visa lyssningsstatistik.
  4.  **Advanced Search**: Förbättra sökfunktionen med mer avancerad syntax (`genre:`, `year:`).
  5.  **Implementera "Quick Wins"**: Fokusera på de enkla förbättringarna listade i `improvments.md` för att snabbt leverera värde.

För en fullständig lista med över 18 föreslagna funktioner, se `improvments.md`.

---

## Dokumentation

Projektet är redan mycket väldokumenterat, men det finns en möjlighet att göra dokumentationen mer lättillgänglig.

- **Skapa ett centralt index:**
  - Det finns dussintals `.md`-filer i `docs/`, `summaries/` och `.kiro/`. Huvudfilen `README.md` skulle kunna uppdateras till att inkludera en innehållsförteckning som länkar till de viktigaste guiderna, designspecifikationerna och sammanfattningarna. Detta skulle ge en bättre överblick och göra det lättare att hitta relevant information.
- **Konsolidera `improvments.md` och `ToDo.md`:**
  - Överväg att slå ihop denna `ToDo.md`-fil med den mer detaljerade `improvments.md` för att ha en enda källa för framtida arbete.
