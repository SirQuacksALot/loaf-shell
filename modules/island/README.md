# Dynamic Island

Struktur, angelehnt an [Tide Island](https://github.com/enhaoswen/Tide-island), aber
als reine QML-State-Machine statt eigener C++/Qt6-App – fügt sich in die
bestehenden `services/`-Singletons und den `modules/`-Aufbau dieses Configs ein.

Die drei Morph-Basisklassen (MorphContainer/MorphItem/MorphContent) sind
NICHT mehr hier, sondern eine Ebene höher in `modules/` - Dock.qml/
AppsView.qml (siehe dortiges DockShape.qml) morphen genauso zwischen
Peek-Sliver und voller UI und nutzen dieselbe Feder-Choreographie, das war
also kein Insel-exklusives Problem mehr. Siehe deren Kommentare für die
Basisklassen-Doku; hier nur noch, was WIRKLICH insel-spezifisch ist.

```
IslandRoot.qml       Fenster + Zustand: WOHIN will die Insel (effectiveTarget) + Hover-Stufen
IslandShape.qml         Verdrahtet MorphContainer (modules/) + alle Views (MorphItems) miteinander
ActionButton.qml        Kleiner runder Icon-Button (Close, Playback, Toggle-Glocken, ...)
MenuButton.qml           Größerer Icon-ODER-Text-Button (Control-Center-Toggles, Power-Menü, ...)
ThemedSlider.qml         Einheitlich gestylter Slider (dicker Balken, Griff = Unterbrechung der Linie)
Toggle.qml               An/Aus-Schalter (WifiView/BluetoothView)
Divider.qml              Dünne Trennlinie zwischen zwei Bereichen einer View (Control Center, InfoView)
ViewHeader.qml           Kopf für jede View außer InfoView/NotifyView: Akku+Verbindung links, Schließen rechts
ListCard.qml             Einheitliche Listen-Zeile (44px, rund, transparent -> surface bei Hover, optional fitContent für umbrechenden Text) - WLAN/Bluetooth/Zwischenablage/Notifications
widgets/                Wiederverwendbare Bausteine für Views (KEINE eigenen MorphItems)
  MediaWidget.qml         Cover+Titel/Artist "auf einen Blick", tippen -> MusicView
  CalendarWidget.qml      Uhrzeit + Wochenstreifen zentriert auf heute
  BatteryIndicator.qml    Live-Ladestand als Balken statt fixer Icon-Stufen (GNOME-Mockup)
  GithubHeatmap.qml       Contribution-Heatmap fürs Control Center (Whisker-Mockup), Username klickbar editierbar
  RoundedCover.qml        Rundes Vorschaubild + Fallback-Icon (Notification-Cover in InfoView)
views/
  PeekView.qml           Ruhezustand - ein MorphItem ohne Inhalt              (fertig)
  DefaultView.qml         Nur die Uhr - 1. Hover-Stufe                        (fertig)
  InfoView.qml              Erweiterte Info - 2. Hover-Stufe, inkl. Notification-Liste (fertig)
  NotifyView.qml              Notification-Transformation                        (fertig)
  ControlCenterView.qml           Toggles + Slider + Shortcuts zu weiteren Views      (fertig)
  WifiView.qml                      WLAN An/Aus-Toggle, erreichbar über Control Center (fertig, ausbaubar)
  BluetoothView.qml                   Bluetooth An/Aus-Toggle, dito                      (fertig, ausbaubar)
  PowerMenuView.qml                 Sperren/Abmelden/Neustart/Herunterfahren           (fertig)
  AudioSourceView.qml                 Standard-Ausgabe/-Eingabe wählen (Pipewire)        (fertig)
  TimerView.qml                           Timer/Stopwatch/Pomodoro                          (Stub)
  WorkspacesView.qml                        Hyprland-Workspace-Übersicht                      (Stub)
  GithubView.qml                              GitHub-Contribution-Heatmap                      (Stub)
```

Jede Stub-View hat einen konkreten Umsetzungsvorschlag als Kommentar am
Dateianfang (welches Quickshell-Modul/CLI-Tool sich anbietet, wie man es am
Muster der bestehenden Services orientiert einbaut).

## Zwei Hover-Stufen + Auto-Reset

Seit Kurzem gibt es zwei getrennte Hover-Ebenen (`IslandRoot.qml`):

1. **Trigger-Zone** (dünner Streifen am oberen Bildschirmrand, `triggerZone`)
   hovern -> Insel klappt auf `viewMode` auf (meist "default" = nur die Uhr).
2. **Die sichtbare Pille selbst** (`islandWindow`/`contentHovered`) hovern,
   während `viewMode === "default"` ist -> eskaliert automatisch zu `"info"`
   (`onContentHoveredChanged` in `IslandRoot.qml`). Nur EIN Zeilen-Trigger,
   kein Extra-Code in `DefaultView.qml` nötig.

Zusätzlich: eine manuell geöffnete View (Music, Control Center, Power-Menü,
...) blieb bisher für immer offen, bis man aufs "x" tippt. Jetzt läuft
`idleResetTimer` (Standard: 60s) mit - läuft nur, wenn WEDER Trigger- noch
Content-Zone gehovert wird, und setzt `viewMode` dann zurück auf `"default"`.
Läuft komplett unabhängig von `hideTimer` (der nur "peek" vs. sichtbar
regelt, viel kürzer) und wird bei jedem Hover neu gestartet.

## Angedockt vs. schwebend ("Notch" vs. "Island")

Nur im Ruhezustand ("peek") soll die Insel wie eine echte Notch aussehen:
bündig mit der Bildschirmkante (`y: 0`), oben eckig
(`topLeftRadius`/`topRightRadius: 0`). Sobald sie aktiv wird (jeder andere
Zustand), soll sie sich sichtbar davon LÖSEN: nach unten rausfahren
(`y: floatingGap`) UND dabei rundum abgerundet werden - eine eigenständig
schwebende Pille statt einer dauerhaft in die Kante eingelassenen Form.
Beides ist Teil desselben Morphs (`Behavior on y` mit derselben Feder wie
Breite/Höhe, `Behavior on topLeftRadius/topRightRadius` als kurze
Überblendung) - fühlt sich dadurch wie "erst rausfahren, dann schweben" an,
nicht wie zwei unabhängige Zustände.

Gesteuert über `MorphItem.floating` (Standard: `true`) - nur `PeekView`
setzt es auf `false`. `_tryActivate()` in `MorphContainer.qml` wartet jetzt
zusätzlich auf `yAnim`, nicht nur auf Breite/Höhe - der Inhalt der neuen
View erscheint also erst, wenn die Insel WIRKLICH fertig rausgefahren ist.

Genauso ist auch das Aussehen der Fläche (`cornerRadius`, `surfaceColor`,
`borderColor`) pro MorphItem überschreibbar, mit Theme-Werten als Standard
(siehe MorphItem.qml). `PeekView` nutzt das für einen eigenen, dunkleren
"Notch"-Look (schwarz, stärker gerundet, kleiner) - alle anderen Views
bleiben beim normalen Theme.

**Wichtig zur Rundung:** Qt kappt jeden angeforderten Radius automatisch
auf die Hälfte der kleineren Kantenlänge (wie CSS `border-radius`) - bei
einer 90×16px-Fläche ist z.B. `cornerRadius: 500` optisch identisch zu
`cornerRadius: 8`, weil beide auf `16/2=8` gekappt werden. Für sichtbar
mehr Rundung hilft nur eine größere Fläche, nicht ein größerer Radius-Wert.

(Technischer Hintergrund, falls man auf die Idee kommt, die Insel könnte
buchstäblich "hinter" die Bildschirmkante ragen: ein `PanelWindow` ist eine
Wayland-Surface mit fester Pixelgröße, da gibt es über die Kante hinaus
schlicht keine Pixel mehr zu zeichnen. Der Notch-Look im Ruhezustand ist
reine Formsprache - keine Lücke zum Rand + flacher oberer Abschluss statt
rundum abgerundet -, keine tatsächliche Überlappung mit dem Bildschirmrand.)

## Die drei Basisklassen

Leben jetzt in `modules/` (nicht mehr hier) - Dock.qml nutzt sie über
`DockShape.qml` genauso (`edge: "bottom"` statt `"top"`, siehe dortiger
Kommentar in `MorphContainer.qml` zur Verallgemeinerung). Drei
Ableitungsklassen, jede mit GENAU einer Verantwortung (bewusst nicht
zwei – der Versuch, Staggering mit in `MorphItem` reinzupacken, hätte
entweder das oder `MorphContainer` überladen):

- **`MorphContainer.qml`** – **ist die sichtbare Fläche selbst**: ein
  einziges `Rectangle` (Radius/Rand/Hintergrund aus Theme), das seine
  Breite/Höhe live animiert und dabei WÄHREND DES GESAMTEN Übergangs
  durchgehend sichtbar bleibt (kein Verschwinden dazwischen!). Hält eine
  Menge von `MorphItem`-Kindern (in einem internen Content-Layer) und
  entscheidet, **wann** welches aktiviert/deaktiviert wird (der
  "Informationsaustausch": welches Item wird von was in was gemorpht) und
  liest `preferredWidth`/`preferredHeight` vom jeweils aktiven Item, um
  sich selbst passend zu resizen.
- **`MorphItem.qml`** – EIN einzelner Zustand: nur noch "bin ich gerade
  aktiv, ja/nein" plus die Maße, die die Fläche annehmen soll. Jede View
  "erbt" davon (hat `MorphItem { ... }` als Root-Element ihrer Datei).
  Kein eigenes Rectangle, keine Reveal-Choreographie mehr - beides wandert
  eine Ebene weiter (Fläche → `MorphContainer`, Kinder-Reveal →
  `MorphContent`). **"peek" ist nichts Besonderes** – einfach ein
  `MorphItem` ohne eigenen Inhalt (`views/PeekView.qml`); die Fläche selbst
  (aus `MorphContainer`) ist ja bereits da, es gibt nur nichts draufzulegen.
- **`MorphContent.qml`** – lässt die Kinder EINES Inhalts-Blocks (typischerweise
  die RowLayout/ColumnLayout, die eine View als Inhalt anlegt) einzeln,
  zeitversetzt reinpoppen (Opacity + Scale-Feder pro Kind, siehe
  `staggerDelay`), statt alle auf einmal. Wird von `MorphItem` automatisch
  verwendet (`default property alias`) - eine View muss dafür nichts
  Zusätzliches tun, das gestaffelte Reveal kommt "geschenkt" einfach
  dadurch, dass sie `MorphItem` als Root-Element nutzt.

  Fallstrick beim dynamischen Erzeugen dieser Pop-Animationen
  (`popAnimation.createObject(...)` pro Kind, da die Kinderanzahl je View
  variiert): jede zerstört sich nach Abschluss selbst (`onFinished:
  anim.destroy()`), damit sie nicht ewig rumliegen. Beim NÄCHSTEN Öffnen
  derselben View räumt `_clearPending()` alles aus `_anims` auf, das noch
  läuft - stand darin aber noch eine Referenz auf eine bereits
  selbstzerstörte Animation (weil die sich nicht selbst aus `_anims`
  ausgetragen hatte), warf der Zugriff eine Exception und brach die
  GESAMTE `onRevealedChanged`-Funktion ab, bevor die neue Stagger-Sequenz
  starten konnte. Symptom: erstes Öffnen einer View staffelt sauber, jedes
  weitere Öffnen poppt den Inhalt nur noch als Block. Fix: jede
  Pop-Animation trägt sich in ihrem eigenen `onFinished` zuerst aus
  `_anims` aus, bevor sie sich zerstört - `_anims` enthält dadurch nie eine
  tote Referenz.

Wichtig: erst gab es eine Version, bei der JEDES `MorphItem` sein eigenes
Rectangle gezeichnet hat (übereinandergestapelt, per Opacity umgeschaltet).
Das sah während der Resize-Phase aus wie "Fläche verschwindet komplett,
irgendwann taucht eine neue an derselben Stelle auf" – kein echtes
Flächen-Resizing, eher zwei Fades mit totem Zwischenraum. Jetzt gibt es nur
noch EIN Rectangle (in `MorphContainer`), das nie verschwindet.

`IslandShape.qml` ist die eigentliche Nutzung davon: ein `MorphContainer`,
befüllt mit allen Views (`Views.PeekView { ... }`, `Views.MusicView { ... }`, ...).
`IslandRoot.qml` selbst weiß gar nichts mehr über Animation – nur, wohin die
Insel gerade will (`effectiveTarget`, siehe unten).

## Buttons: entweder Icon oder Text, nie beides

Zwei wiederverwendbare Button-Typen, statt in jeder View wieder ein loses
`LucideIcon`/`Text` + `TapHandler` zusammenzustecken. Beide folgen derselben
Regel: **entweder Icon oder Text, niemals beides gleichzeitig** – ein Button
ist entweder eine reine Aktion (Icon reicht) oder ein beschrifteter Zustand
(Text reicht), nicht beides vermischt.

- **`ActionButton.qml`** – klein, rund, IMMER nur ein Icon. Für sofortige,
  folgenlose Aktionen: Close-Buttons, Playback-Controls, Mute-Toggle,
  Notification-Glocke (inkl. optionalem `badgeCount`). Hintergrund
  (`showBackground`, Standard `true`) lässt sich pro Instanz abschalten für
  einen minimaleren, freistehenden Look (z.B. Playback-Nebenaktionen wie
  skip-back/skip-forward neben einem hervorgehobenen Play/Pause).
- **`MenuButton.qml`** – größer, entweder Icon- ODER Text-Modus
  (`showLabel`, Standard `false` = Icon). Für Aktionen mit mehr Gewicht:
  Control-Center-Toggles, Power-Menü-Aktionen, View-Shortcuts. Welcher der
  beiden Modi aktiv ist, darf sich zur Laufzeit ändern – `PowerMenuView.qml`
  nutzt das, um bestätigungspflichtige Aktionen (Abmelden, Neustart,
  Herunterfahren) beim ersten Tap kurz auf den Text "Sicher?" umzuschalten
  (`active`/`activeColor: Theme.colors.error`), statt einen eigenen
  Confirm-Dialog zu bauen. Für einen reinen Text-Link ohne Kachel-Optik
  `showBackground: false` setzen (siehe "Alle löschen" in `InfoView.qml`).

Beide teilen sich `active`/`available`/`tapped()` als gemeinsames
Vokabular (aktiver Zustand, deaktiviert/ausgegraut, Tap-Signal) – neue
Buttons sollten sich an eines der beiden Muster halten statt ein drittes
Ad-hoc-Pattern einzuführen.

## Ablauf eines Wechsels (3 Phasen)

Jede Änderung von `MorphContainer.target` läuft dreistufig ab:

1. **leave** – alle nicht mehr passenden `MorphItem`s werden deaktiviert
   (`active = false`) → blenden über ihre EIGENE Transition aus
2. **resize** – die Fläche (`MorphContainer` selbst) morpht live auf die
   `preferredWidth`/`preferredHeight` des neuen Ziel-Items, dabei
   DURCHGEHEND sichtbar (Radius/Hintergrund/Rand bleiben die ganze Zeit da
   – nur der Inhalt ist gerade weg)
3. **enter** – das neue Ziel-Item wird erst aktiviert, wenn Phase 1 UND 2
   TATSÄCHLICH abgeschlossen sind (nicht nur "vermutlich nach X ms" – siehe
   unten), dann wird es sofort sichtbar (kein eigener Fade mehr) - und
   `MorphContent` lässt seine Kinder (die einzelnen Icons/Texte)
   nacheinander, zeitversetzt reinpoppen statt alle auf einmal.

## Warum States/Transitions statt einer handgestrickten Animation?

Ein früherer Anlauf hat das über eine einzelne `SequentialAnimation` mit
`ScriptAction` + manuellem `restart()` gelöst. Das brach bei schnellem
Hovern (Zielwechsel mitten in der laufenden Animation) zuverlässig: der
`ScriptAction`-Seiteneffekt (der umschaltet, welche View gerade "dran" ist)
wurde je nach Abbruchzeitpunkt mal ausgeführt und mal nicht – Größe,
Sichtbarkeit und Inhalt liefen dauerhaft auseinander ("Fläche groß, aber kein
Inhalt").

Jetzt läuft alles über Primitive, die genau dafür gebaut sind, beliebig oft
mitten in der Animation unterbrochen zu werden, ohne in einen inkonsistenten
Zwischenzustand zu geraten:

- `MorphItem` nutzt QtQuick **`states`/`transitions`** fürs eigene Ein-/
  Ausblenden – das ist deren Kernkompetenz (benannte, jederzeit sicher
  unterbrechbare Zustandswechsel).
- `MorphContainer` nutzt eine **`Behavior`** für die Größe (dieselbe
  Interruption-Sicherheit, nur für eine kontinuierliche Zahl statt einen
  benannten Zustand) und einen **`Timer` mit `restart()`** fürs Timing (ein
  Timer kennt nur "läuft" oder "ausgelöst", nie einen halb ausgeführten
  Zwischenschritt).

Phase 3 (aktivieren) wartet dabei NICHT auf eine geschätzte Dauer, sondern
auf zwei echte Signale: `leaveTimer` ist abgelaufen UND die
`SpringAnimation`s für Breite/Höhe melden per `running`-Änderung, dass sie
wirklich fertig eingeschwungen sind (`_tryActivate()` in
`MorphContainer.qml`). Der Inhalt der neuen View erscheint also garantiert
erst, wenn die Fläche wirklich da ist – egal wie oft man mitten in der
Animation nochmal umschaltet.

## Bewegungssprache: Federn statt Easing-Kurven

Fläche (`MorphContainer`, Breite/Höhe) UND Content-Pop (`MorphItem`, Scale
beim Erscheinen) laufen über `SpringAnimation` statt über feste
Easing-Kurven wie `Easing.OutExpo`/`Easing.OutBack`. Eine Easing-Kurve
braucht eine feste Dauer, die für JEDEN Sprung gleich abläuft, egal wie groß
er ist – bei Breite/Höhe, die sich oft unterschiedlich stark ändern (z.B.
Breite kaum, Höhe stark), sieht das leicht auseinanderlaufend/mechanisch
aus. Eine Feder reagiert stattdessen auf die tatsächliche Distanz und wirkt
dadurch wie EIN zusammenhängendes physisches Morphen statt wie mehrere
unabhängige Kurven, die zufällig gleichzeitig laufen.

- `spring` = wie "straff" die Feder ist (höher = schneller/direkter)
- `damping` = wie schnell das Nachschwingen abklingt (höher = ruhiger,
  niedriger = mehr Wackeln/Bounce)

Der Content-Pop (`Config.contentSpring`, `spring: 8, damping: 0.65`) ist
bewusst strammer als die Fläche selbst (`Config.surfaceSpring`,
`spring: 5, damping: 0.6`) – der Inhalt soll spürbar "ankommen", während
die Fläche das größere, ruhigere Element bleibt. Alle Timing-Werte der drei
Morph-Basisklassen (Federn UND feste Dauern wie `leaveDuration`) liegen
zentral in `Config.qml` (Repo-Root, analog zu `Theme.qml` für Farben/
Metrics) – dort auch gut zum selbst Austesten, ohne durch mehrere Dateien
suchen zu müssen. `epsilon` (Standard bei Qt: 0.25) ist bei der Fläche
bewusst auf `0.5` angehoben – die letzten Bruchteil-Pixel eines Feder-
Einschwingens brauchen unverhältnismäßig viele Frames und wirken dabei eher
wie Zittern als wie Bewegung; ein größeres Epsilon lässt die Feder etwas
früher "fertig" sein, ohne dass man den Unterschied sieht.

## Warum das Fenster NICHT einfach reaktiv mitwächst

Naheliegend wäre, `implicitHeight` des `PanelWindow` (in `IslandRoot.qml`)
direkt an `shape.height` zu binden, wie es früher auch war. Das Problem:
ein `PanelWindow` ist eine echte Wayland-Surface, kein normales QML-Item –
jede `implicitHeight`-Änderung löst dort ein natives Resize aus (Buffer neu
anfordern, Compositor-Roundtrip). Bei einer mit 60fps laufenden
`SpringAnimation` passiert das potenziell bei JEDEM Frame und war die
Hauptursache fürs Stottern.

Stattdessen: `MorphContainer` rechnet sich selbst `maxContentWidth`/
`maxContentHeight` aus (das Maximum über `preferredWidth`/`preferredHeight`
aller registrierten MorphItem-Kinder) – das ändert sich nur, wenn Views
hinzukommen/wegfallen, NIE während einer Animation. Das Fenster wird fix auf
diese Maße gesetzt (`implicitHeight: shape.maxContentHeight + 8`) und
bleibt danach die ganze Zeit konstant; nur die Pille (`shape`, ein
gewöhnliches QML-Item innerhalb des Fensters) ändert ihre Größe – reines,
günstiges Scenegraph-Rendering statt Surface-Resizes.

Der dadurch entstehende leere/transparente Rand um eine kleinere Pille
herum würde ohne Gegenmaßnahme trotzdem Mausklicks für alles darunter
schlucken (ein Wayland-Layer-Surface ist standardmäßig über seine GESAMTE
Fläche hinweg klickbar). Deshalb `mask: Region { item: shape }` auf dem
Fenster – begrenzt Ein-/Ausgabe (Hover, Klicks) exakt auf die aktuelle
Pillenfläche, live mitverfolgt. Nebeneffekt: das war vorher (als das
Fenster noch mit der Pille mitgewachsen ist) eigentlich auch schon nötig
gewesen - selbst der kleine "peek"-Sliver hat davor über die volle
Bildschirmbreite hinweg Klicks abgefangen, nicht nur unter der sichtbaren
Pille.

## Notification-Stapel in InfoView

Die Notification-Liste in `InfoView.qml` gruppiert nach App
(`Services.Notifications.groupedList`, Datenlogik bewusst im Service statt
in der View - siehe `services/Notifications.qml`), zeigt davon aber
bewusst NUR die oberste (= neueste) Karte je Gruppe - kein App-Name, keine
Kategorie-Anzeige, kein Expand/Collapse. Alles, was zusätzlich in der
Gruppe liegt, ist rein dekorativ als 1-2 blasse Kanten dahinter angedeutet
(gecappt auf 2, unabhängig von der tatsächlichen Anzahl - mehr wirkt nicht
mehr gestapelt, nur unübersichtlich). Man verwirft ("x") einfach
Notification für Notification - sobald die oberste weg ist, rückt die
nächstältere automatisch nach, weil sich die Gruppe live aus
`groupedList` neu berechnet.

Cover Art (z.B. der Absender-Avatar bei Discord, `notification.image`)
zeigt `widgets/RoundedCover.qml` links auf jeder Karte - dieselbe
Canvas-Clip-Technik wie das MPRIS-Cover in `MediaWidget.qml`, nur als
eigenständiges, parametrisiertes Widget statt duplizierter Fläche
(Fallback-Icon, falls keine Notification-Bildquelle vorhanden ist).

## Neue View hinzufügen

1. `views/MeinFeatureView.qml` anlegen, Root-Element:
   ```qml
   import ".."
   import "../../.."
   import "../../../services" as Services

   MorphItem {
       id: view
       name: "meinfeature"
       preferredWidth: 400
       preferredHeight: 120
       required property var islandRoot

       ColumnLayout {
           anchors.fill: parent
           anchors.margins: 16
           spacing: 14

           ViewHeader { islandRoot: view.islandRoot }
           // eigener Inhalt hier rein
       }
   }
   ```
   `ViewHeader` (Akku+Verbindung links, Schließen rechts) ist der Kopf
   JEDER View außer InfoView (eigene erweiterte Zeile) und NotifyView
   (kein Header) - view-spezifische Kontrollen (Toggle, ein Leeren-Button,
   ...) gehören NICHT in den Header, sondern in eine eigene Zeile direkt
   darunter (siehe WifiView.qml/ClipboardView.qml).
2. In `IslandShape.qml` eine Zeile `Views.MeinFeatureView { islandRoot: shape.islandRoot }`
   einhängen.
3. Irgendwo einen Trigger bauen, der `islandRoot.openView("meinfeature")` aufruft –
   z.B. eine weitere Zeile im `shortcuts`-Model in `ControlCenterView.qml`.

Größe und Animation müssen dafür nirgends sonst angefasst werden – das
übernimmt `MorphItem`/`MorphContainer`/`MorphContent` automatisch. Einzige
Konvention, damit `MorphContent` weiß, was es staffeln soll: eine View legt
GENAU EINEN direkten Inhalts-Container an (meist eine RowLayout/ColumnLayout)
- dessen Kinder werden dann einzeln reingepoppt.

## Neuer Service

Services (`../../services/*.qml`) sind austauschbare Singletons – neue einfach
nach dem Muster von z.B. `Bluetooth.qml` oder `Mpris.qml` anlegen (`pragma
Singleton`, kein `qmldir` nötig) und aus jeder View per
`import "../../../services" as Services"` verwenden.
