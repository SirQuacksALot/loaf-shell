import QtQuick
import ".."

// Eigene, bewusst kleine Verantwortung, getrennt von MorphItem (das nur
// noch "bin ich der gerade aktive Zustand, ja/nein" regelt) und
// MorphContainer (das nur die Fläche selbst morpht): MorphContent lässt
// seine direkten Kinder EINZELN, zeitversetzt reinpoppen, statt alle auf
// einmal - ohne das würde entweder MorphItem oder MorphContainer diese
// Choreographie zusätzlich übernehmen müssen und überladen.
//
// Wird automatisch von MorphItem verwendet (default property alias, siehe
// dort) - eine View muss also NICHTS zusätzlich tun, um gestaffelte
// Kinder zu bekommen. Erwartung: GENAU EIN direktes Kind, üblicherweise
// die RowLayout/ColumnLayout, die eine View als ihren Inhalt anlegt -
// gestaffelt werden dann DEREN Kinder (die einzelnen Icons/Texte).
Item {
    id: root

    property bool revealed: false
    property int enterDuration: Config.contentEnterDuration
    property int staggerDelay: Config.contentStaggerDelay   // Verzögerung zwischen aufeinanderfolgenden Kindern

    // false: Kinder bleiben unangetastet bei ihrer normalen Opacity/Scale
    // (kein Pop-in) - siehe MorphItem.staggerContent für den Grund.
    property bool enabled: true

    // false: nur Opacity fadet rein, Scale bleibt unangetastet bei 1 - für
    // Views mit asynchron ladenden Bildern (IconImage), bei denen die
    // Scale-Feder + Start-bei-0-Kombination beobachtbare Aussetzer
    // verursachte (siehe MorphItem.staggerContent). Wirkt nur, wenn
    // `enabled` true ist.
    property bool staggerScale: true

    property var _anims: []

    // Vorlage für die Animation EINES Kindes: erst warten (staffeln),
    // dann Opacity (+ optional Scale) reinpoppen. Wird pro Kind dynamisch
    // instanziiert (siehe onRevealedChanged), weil die Anzahl der Kinder
    // je View unterschiedlich ist - eine statisch deklarierte Transition
    // kann das nicht.
    Component {
        id: popAnimation
        SequentialAnimation {
            id: anim
            property Item target
            property int delay: 0

            PauseAnimation { duration: anim.delay }
            ParallelAnimation {
                NumberAnimation { target: anim.target; property: "opacity"; to: 1; duration: root.enterDuration; easing.type: Easing.OutCubic }
                // Kein "enabled: animateScale" - SpringAnimation nimmt das
                // hier nicht als zuweisbare Property an ("Cannot assign to
                // non-existent property"). Unnötig ohnehin: wenn
                // staggerScale false ist, wird scale nie auf 0.85 gesetzt
                // (siehe onRevealedChanged), die Animation läuft dann nur
                // "1 -> 1" - ein No-Op ohne sichtbaren Effekt.
                SpringAnimation { target: anim.target; property: "scale"; to: 1; spring: Config.contentSpring.spring; damping: Config.contentSpring.damping; mass: Config.contentSpring.mass; epsilon: Config.contentSpring.epsilon }
            }
            // Entfernt sich SELBST aus root._anims, BEVOR es sich zerstört.
            // Wichtig: ohne das würde _anims beim nächsten Öffnen dieser
            // View (siehe _clearPending) noch auf dieses längst fertige,
            // zerstörte Objekt zeigen - der Zugriff darauf wirft eine
            // Exception, die die GESAMTE onRevealedChanged-Funktion
            // abbricht, NOCH BEVOR die neue Stagger-Sequenz starten kann.
            // Genau das war der Bug: erstes Öffnen einer View klappte
            // immer (nichts zum Aufräumen da), jedes weitere Mal nicht
            // mehr (Aufräumen wirft, Rest der Funktion läuft nie).
            onFinished: {
                root._anims = root._anims.filter(a => a !== anim)
                anim.destroy()
            }
        }
    }

    function _clearPending() {
        for (const a of root._anims) {
            if (a) { a.stop(); a.destroy() }
        }
        root._anims = []
    }

    // Die eigentlichen, zu staffelnden Elemente sind NICHT root.children
    // selbst (das ist nur die eine Layout-Wrapper-Instanz, die eine View
    // anlegt), sondern deren Kinder - siehe Kommentar oben.
    function _staggerTargets() {
        if (root.children.length === 0) return []
        return root.children[0].children
    }

    onRevealedChanged: {
        root._clearPending()
        if (!root.revealed) return
        if (!root.enabled) return

        const kids = root._staggerTargets()
        const started = []
        for (let i = 0; i < kids.length; i++) {
            const child = kids[i]
            child.opacity = 0
            if (root.staggerScale) child.scale = 0.85
            const anim = popAnimation.createObject(root, { target: child, delay: i * root.staggerDelay })
            anim.start()
            started.push(anim)
        }
        root._anims = started
    }
}
