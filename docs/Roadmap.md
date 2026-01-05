# Projekt-roadmap: Spotify CLI

Detta dokument beskriver den föreslagna utvecklingsplanen i faser, från tekniska förbättringar till nya funktioner och distribution.

---

### **Fas 0: Teknisk grund och refaktorering (Rekommenderad start)**
Denna fas fokuserar på att förbättra kodkvaliteten och underhållbarheten, vilket kommer att påskynda utvecklingen av nya funktioner.

- [ ] **Städa upp projektet:**
  - [ ] Ta bort alla gamla och trasiga skript från `backup-and-broken`-katalogen.
- [ ] **Modularisera `SpotifyModule.psm1`:**
  - [ ] Dela upp den massiva `SpotifyModule.psm1` i mindre, funktionsspecifika moduler (t.ex. `ApiHelper.psm1`, `PlaybackCommands.psm1`, `TokenManager.psm1`).
- [ ] **Förbättra felhantering:**
  - [ ] Refaktorera `Invoke-SpotifyApi` för att kasta specifika undantag istället för att skriva direkt till konsolen.

---

### **Fas 1: Kärnförbättringar (1-2 månader)**
Fokus på att implementera de mest efterfrågade funktionerna som ger omedelbart värde.

- [ ] **Real-time Animation & Live Display**: Implementera `spotify --live` med kontinuerlig uppdatering och "Sidecar Mode".
- [ ] **Grundläggande köhantering**: Slutför funktioner för att visa och modifiera uppspelningskön.
- [ ] **Grundläggande statistik**: Implementera insamling och visning av lyssningsstatistik.
- [ ] **Avancerad sökning**: Förbättra sökfunktionen med mer specifik syntax (genre, år, etc.).
- [ ] **Implementera "Quick Wins"**: Genomför de enkla och snabba förbättringarna från `improvments.md`.

---

### **Fas 2: "Power User"-funktioner (2-3 månader)**
Utöka verktyget med mer avancerade och kraftfulla funktioner.

- [ ] **Textvisning (Lyrics Display)**: Integrera med Genius/Musixmatch för att visa sångtexter, inklusive synkroniserad "karaoke"-vy.
- [ ] **Komplett spellistehantering**: Bygg ut med kommandon för att skapa, radera, sortera och hantera spellistor.
- [ ] **Smarta spellistor**: Skapa funktioner för att automatiskt generera spellistor baserat på humör eller liknande låtar.
- [ ] **Avancerade notifikationer**: Integrera med Discord Rich Presence, Slack och Last.fm.

---

### **Fas 3: Avancerade system och finesser (3-4 månader)**
Bygg ut ekosystemet runt CLI-verktyget.

- [ ] **Schemaläggning & Automation**: Implementera sleep-timer, väckarklocka och Pomodoro-integration.
- [ ] **Avancerade ljudkontroller**: Lägg till stöd för Equalizer (EQ) och crossfade.
- [ ] **TUI-läge (Terminal User Interface)**: Skapa ett fullständigt grafiskt gränssnitt i terminalen som ett alternativ till kommandon.
- [ ] **Testning & Dokumentation**: Skriv omfattande enhets- och integrationstester och förbättra den tekniska dokumentationen.

---

### **Fas 4: Polering och distribution (1-2 månader)**
Fokus på att göra verktyget robust, lätt att installera och använda.

- [ ] **Stöd för pakethanterare**: Publicera på PowerShell Gallery, Chocolatey, Scoop och/eller WinGet.
- [ ] **System för auto-uppdatering**: Lägg till en funktion för att enkelt kunna söka efter och installera uppdateringar.
- [ ] **Prestandaoptimering**: Implementera caching och andra tekniker för att göra verktyget snabbare och mer responsivt.
- [ ] **Slutgiltig testning**: Genomför omfattande tester av alla funktioner för att säkerställa stabilitet.
