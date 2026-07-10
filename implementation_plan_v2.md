# Circuit Breaker - Vollständige Spiel-Implementierung (v2)

## Architektur-Übersicht

```
main.tscn
├── Board (board.gd) - 6x4 Spielfeld
├── GameManager (game_manager.gd) - Spiel-Logik
├── UIManager (ui_manager.gd) - Bildschirm-Menüs
├── InputHandler (input_handler.gd) - Tastatur/Maus
└── ShopManager (shop_manager.gd) - Shop-System
```

## Phasen pro Runde
1. **BUILD** - Bauteile platzieren/entfernen (Drag & Drop + Tastatur)
2. **SEND** - Pakete losschicken (Enter drücken)
3. **RESULT** - Schaden anzeigen, Belohnung, Shop

## Implementierungs-Reihenfolge

### Phase 1: Wirtschaft & Fortschritt
- [ ] shop.gd - Shop-System (Kaufen, Verkaufen, Angebote)
- [ ] score_system.gd - Punkte, Geld, Highscore
- [ ] Tests für Shop & Score

### Phase 2: Interaktive Steuerung
- [ ] input_handler.gd - Tastatur-Befehle (place, remove, send, shop)
- [ ] Konsolen-UI für Spieler-Interaktion
- [ ] Tests für Input-Handler

### Phase 3: UI & Menüs
- [ ] ui_manager.gd - Homescreen, Spiel-Bildschirm, Game Over
- [ ] Visuelle Darstellung des Bretts (Kacheln)
- [ ] Drag & Drop für Bauteile

### Phase 4: Vollständiger Spiel-Loop
- [ ] Runden-Ablauf (Build → Send → Result → Shop)
- [ ] Schwierigkeits-Skalierung
- [ ] Game Over / Neustart

### Phase 5: Integration & Tests
- [ ] Alle Tests aktualisiert
- [ ] Kompletter Spieldurchlauf testbar