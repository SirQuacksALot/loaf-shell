# Dock

Eigenes Verzeichnis analog zu `modules/island/` - beide sind reine
QML-State-Machines auf Basis derselben Morph-Basisklassen
(`MorphContainer`/`MorphItem`/`MorphContent`, jetzt in `modules/`, siehe
dortige Kommentare + `modules/island/README.md`) UND derselben
Aufteilung: Fenster/Zustand (`Dock.qml`), Verdrahtung (`DockShape.qml`),
einzelne Zustände als eigene `MorphItem`-Views (`views/`).

```
Dock.qml         Fenster + Zustand: Hover-Trigger unten, Auto-Hide (spiegelt IslandRoot.qml)
DockShape.qml       Verdrahtet MorphContainer (edge:"bottom") mit den Views (spiegelt IslandShape.qml)
views/
  PeekView.qml         Ruhezustand - schwarzer Sliver, angedockt          (fertig)
  AppsView.qml            Angepinnte + laufende Apps + AppLauncher-Icon      (fertig)
```

## Zwei Zustände statt vieler Views

Anders als die Insel (14 Views) hat der Dock nur zwei MorphItem-Zustände:

- **`PeekView.qml`** - winziger schwarzer Sliver, angedockt an der
  unteren Bildschirmkante (`floating: false`, `edge: "bottom"` in
  `DockShape.qml` sorgt dafür, dass die OBEREN statt unteren Ecken
  gerundet werden - genau spiegelverkehrt zur Insel, die oben angedockt
  ist). `dockedOffset` schiebt ihn zusätzlich ein Stück in die Kante
  rein, statt nur bündig damit abzuschließen (siehe MorphItem.qml).
- **`AppsView.qml`** - die volle Icon-Zeile, schwebt mit Abstand zur
  Kante (`floating: true`, Standard). `preferredWidth` ist reaktiv an
  `rowLayout.implicitWidth` gebunden statt fest codiert - reagiert auf
  die tatsächliche Anzahl angepinnter/laufender Apps, federt bei
  Änderungen (z.B. Anheften einer neuen App) genauso weich mit wie jeder
  andere Größenwechsel.

## Gruppen + Kontextmenü

`AppsView.qml` zeigt zwei sichtbar getrennte Gruppen (Trennlinie
dazwischen): angepinnte Apps zuerst (aus `Services.Windows.pinnedEntries`,
per Drag umsortierbar - siehe `Favorites.moveToIndex()`), dann laufende,
nicht angepinnte Apps (`unpinnedRunningEntries`). Rechtsklick auf eine
Kachel öffnet ein `PopupMenu.qml` (Anheften/Lösen, bei laufenden Apps
zusätzlich Schließen) - dieselbe Komponente wie im AppLauncher.

## Neue Funktion hinzufügen

Ein neuer Dock-Zustand (z.B. ein Kontextmenü-artiges Overlay) würde
genauso wie eine neue Insel-View funktionieren: eine weitere
`views/*.qml` mit `MorphItem` als Root-Element (`name` passend zu einem
neuen `target`-Wert), in `DockShape.qml` als `Views.MeinZustand {
dockRoot: shape.dockRoot }` eingehängt.
