
import Quickshell
import Quickshell.Wayland
import QtQuick

Item {
    id: root

    z: -3

    // ============================================================
    // MAIN STATE
    // ============================================================

    property bool revealed: false

    property int edgeTriggerSize: 8
    property int hideDelay: 2000
    property int failsafeDelay: 6000

    // Small transition buffer when moving:
    //
    // edge -> button
    // button -> menu
    // edge -> another edge
    //
    property int transitionDelay: 180

    // ============================================================
    // VISUAL BORDER SIZE
    //
    // These control the size of the decorative areas only.
    // They DO NOT control the mouse-sensitive area.
    // ============================================================

    property int topRevealHeight: 10
    property int bottomRevealHeight: 135
    property int sideRevealWidth: 65

    // ============================================================
    // HOVER / HOLD STATE
    // ============================================================

    // Compatibility state only. A menu being OPEN no longer holds
    // the bar open. Only physically hovering the menu does.
    property bool menuOpen: false
    property bool menuHovered: false

    // The real top and bottom bar windows write these directly from
    // their HoverHandlers in shell.qml.
    property bool topBarHovered: false
    property bool bottomBarHovered: false

    readonly property bool barHovered:
        root.topBarHovered ||
        root.bottomBarHovered

    // Optional permanent/manual hold.
    property bool holdOpen: false

    // IMPORTANT: shell.qml assigns the bar hover properties directly,
    // so these change handlers must restart/stop the hide logic.
    // Without this, the hide timer can fire while hovered, return, and
    // never get restarted when the mouse later leaves the bar.
    onTopBarHoveredChanged: {
        if (root.topBarHovered)
            root.reveal()
        else
            root.updateActivity()
    }

    onBottomBarHoveredChanged: {
        if (root.bottomBarHovered)
            root.reveal()
        else
            root.updateActivity()
    }

    onMenuHoveredChanged: {
        if (root.menuHovered)
            root.reveal()
        else
            root.updateActivity()
    }

    // ============================================================
    // BUTTON HOVER STATES
    //
    // These are set by the actual buttons.
    // ============================================================

    property bool powerButtonHovered: false
    property bool appsButtonHovered: false
    property bool tempButtonHovered: false

    readonly property bool buttonHovered:
        root.powerButtonHovered ||
        root.appsButtonHovered ||
        root.tempButtonHovered

    // ============================================================
    // FINAL KEEP-OPEN STATE
    //
    // IMPORTANT:
    // The invisible edge triggers do NOT hold the bar open.
    // A menu being OPEN does NOT hold it open either.
    //
    // The UI stays open only while the pointer is physically over:
    //   - the actual top/bottom bar
    //   - a registered button
    //   - a registered menu
    // or while holdOpen is manually enabled.
    // ============================================================

    readonly property bool shouldStayOpen:
        root.barHovered ||
        root.buttonHovered ||
        root.menuHovered ||
        root.holdOpen

    // ============================================================
    // COLORS
    // ============================================================

    property color deepBerry: "#51354D"
    property color deepPlum: "#6E4567"
    property color softPlum: "#8C5C7D"
    property color mauve: "#B47799"
    property color softPink: "#D995B5"
    property color blushPink: "#F1B9D0"
    property color palePink: "#F8D7E4"

    // ============================================================
    // BORDER SYMBOLS
    // ============================================================

    property string flowerA: "❀"
    property string flowerB: "✿"
    property string squiggle: "⌁"

    // ============================================================
    // CONTINUOUS HORIZONTAL PATTERN
    // ============================================================

    function horizontalPattern(count) {

        var result = ""

        for (var i = 0; i < count; i++) {

            if (i % 2 === 0)
                result += root.squiggle + "  " + root.flowerA + "  "
            else
                result += root.squiggle + "  " + root.flowerB + "  "
        }

        return result
    }

    // ============================================================
    // CONTINUOUS VERTICAL PATTERN
    // ============================================================

    function verticalPattern(count) {

        var result = ""

        for (var i = 0; i < count; i++) {

            if (i % 2 === 0)
                result += root.flowerA + "\n" +
                          root.squiggle + "\n"
            else
                result += root.flowerB + "\n" +
                          root.squiggle + "\n"
        }

        return result
    }

    // ============================================================
    // REVEAL
    // ============================================================

    function reveal() {

        root.revealed = true

        hideTimer.stop()
        transitionTimer.stop()

        // Safety net: if an exit event is ever lost, this gives the
        // revealed UI a hard ceiling instead of allowing a stale hover
        // flag to keep it visible forever.
        if (!root.holdOpen)
            failsafeTimer.restart()
    }

    // ============================================================
    // REVEAL FROM EDGE
    //
    // Edge triggers disappear immediately after they reveal the UI.
    // Because there is no edge-hover state anymore, start the normal
    // transition/hide sequence right away. Moving onto a real button
    // or opening a menu cancels these timers through reveal().
    // ============================================================

    function revealFromEdge() {

        root.revealed = true

        hideTimer.stop()
        transitionTimer.restart()

        if (!root.holdOpen)
            failsafeTimer.restart()
    }

    // ============================================================
    // REQUEST HIDE
    // ============================================================

    function requestHide() {

        if (!root.revealed)
            return

        if (root.shouldStayOpen) {
            hideTimer.stop()
            transitionTimer.stop()
            return
        }

        transitionTimer.restart()
    }

    // ============================================================
    // ACTUALLY HIDE
    // ============================================================

    function hideUI() {

        if (root.shouldStayOpen)
            return

        root.revealed = false

        hideTimer.stop()
        transitionTimer.stop()
        failsafeTimer.stop()
    }

    // ============================================================
    // FAILSAFE WATCHDOG CHECK
    //
    // This is a fallback only. It must NEVER close the UI while the
    // pointer is genuinely over the bar, a registered button, or a
    // registered menu.
    //
    // If the watchdog fires during real interaction, it simply starts
    // another watchdog period. If nothing is being used, it closes the
    // UI even if the normal hide path somehow failed to run.
    //
    // holdOpen remains a true manual override and disables the watchdog.
    // ============================================================

    function failsafeCheck() {

        if (!root.revealed) {
            failsafeTimer.stop()
            return
        }

        if (root.holdOpen) {
            failsafeTimer.stop()
            return
        }

        // Real interaction is still happening. Do NOT close.
        // Give it another full watchdog period instead.
        if (root.shouldStayOpen) {
            failsafeTimer.restart()
            return
        }

        // Nothing is actively holding the UI open. If the normal
        // transition/hide timers failed for any reason, close now.
        root.revealed = false

        hideTimer.stop()
        transitionTimer.stop()
        failsafeTimer.stop()
    }

    // ============================================================
    // ACTIVITY UPDATE
    // ============================================================

    function updateActivity() {

        // Something is actively being used.
        if (root.shouldStayOpen) {

            hideTimer.stop()
            transitionTimer.stop()

            return
        }

        // Nothing is being hovered/used anymore.
        if (root.revealed) {

            transitionTimer.restart()
        }
    }

    // ============================================================
    // BUTTON HOVER API
    //
    // Your actual buttons call this.
    // ============================================================

    function setButtonHovered(buttonName, hovered) {

        if (buttonName === "power") {

            root.powerButtonHovered = hovered
        }

        else if (buttonName === "apps") {

            root.appsButtonHovered = hovered
        }

        else if (buttonName === "temp") {

            root.tempButtonHovered = hovered
        }

        if (hovered) {

            root.reveal()

        } else {

            root.updateActivity()
        }
    }

    // ============================================================
    // MENU API
    //
    // setMenuOpen() is kept so existing buttons do not break, but an
    // open menu is NOT a keep-open condition anymore. Opening it may
    // reveal the UI once; after that, hover state decides whether the
    // bar stays visible.
    //
    // Every menu window should report its physical hover state with:
    //
    // edgeReveal.setMenuHovered(hovered)
    // ============================================================

    function setMenuOpen(open) {

        root.menuOpen = open

        if (open)
            root.reveal()
        else
            root.updateActivity()
    }

    function setMenuHovered(hovered) {

        root.menuHovered = hovered
    }

    // ============================================================
    // MANUAL HOLD API
    // ============================================================

    function setHoldOpen(open) {

        root.holdOpen = open

        if (open) {

            // Manual hold is the one state the failsafe must never
            // override.
            failsafeTimer.stop()
            root.reveal()
            failsafeTimer.stop()

        } else {

            if (root.revealed)
                failsafeTimer.restart()

            root.updateActivity()
        }
    }

    // ============================================================
    // FAILSAFE WATCHDOG
    //
    // The normal event-driven path still does all normal hiding.
    // This timer is only a backup for cases where the normal close path
    // fails to run. If anything is genuinely hovered, it restarts itself
    // instead of closing the UI.
    //
    // IMPORTANT: holdOpen is never overridden.
    // ============================================================

    Timer {
        id: failsafeTimer

        interval: root.failsafeDelay
        repeat: false

        onTriggered: root.failsafeCheck()
    }

    // ============================================================
    // MAIN HIDE TIMER
    // ============================================================

    Timer {
        id: hideTimer

        interval: root.hideDelay
        repeat: false

        onTriggered: {

            root.hideUI()
        }
    }

    // ============================================================
    // TRANSITION TIMER
    //
    // Prevents a tiny gap between edge/button/menu from
    // creating a visible flicker.
    // ============================================================

    Timer {
        id: transitionTimer

        interval: root.transitionDelay
        repeat: false

        onTriggered: {

            if (root.shouldStayOpen)
                return

            root.hideTimer.restart()
        }
    }

    // ============================================================
    // TOP EDGE
    //
    // Hidden-only trigger: it disappears as soon as it reveals the UI.
    // It stays on the Top layer the whole time it exists.
    // ============================================================

    PanelWindow {
        id: topTrigger

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: root.edgeTriggerSize
        visible: !root.revealed
        color: "transparent"

        exclusiveZone: 0
        focusable: false
        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onEntered: root.revealFromEdge()
        }
    }

    // ============================================================
    // BOTTOM EDGE
    // ============================================================

    PanelWindow {
        id: bottomTrigger

        anchors {
            bottom: true
            left: true
            right: true
        }

        implicitHeight: root.edgeTriggerSize
        visible: !root.revealed
        color: "transparent"

        exclusiveZone: 0
        focusable: false
        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onEntered: root.revealFromEdge()
        }
    }

    // ============================================================
    // LEFT EDGE
    // ============================================================

    PanelWindow {
        id: leftTrigger

        anchors {
            left: true
            top: true
            bottom: true
        }

        implicitWidth: root.edgeTriggerSize
        visible: !root.revealed
        color: "transparent"

        exclusiveZone: 0
        focusable: false
        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onEntered: root.revealFromEdge()
        }
    }

    // ============================================================
    // RIGHT EDGE
    // ============================================================

    PanelWindow {
        id: rightTrigger

        anchors {
            right: true
            top: true
            bottom: true
        }

        implicitWidth: root.edgeTriggerSize
        visible: !root.revealed
        color: "transparent"

        exclusiveZone: 0
        focusable: false
        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onEntered: root.revealFromEdge()
        }
    }

    // ============================================================
    // EDGE INPUT MODEL
    //
    // There is intentionally only ONE mouse-sensitive PanelWindow
    // per edge: topTrigger, bottomTrigger, leftTrigger, rightTrigger.
    //
    // Each trigger exists ONLY while the UI is hidden. As soon as an
    // edge reveals the UI, its trigger disappears completely. The
    // triggers never change layer and they do not own hover flags.
    //
    // While revealed, only real bar/button/menu hover or holdOpen can
    // keep the UI open. menuOpen by itself no longer counts.
    //
    // The decorative windows below remain visual-only and keep a zero
    // input mask, so they do not consume browser clicks.
    // ============================================================

    // ============================================================
    // TOP DECORATION
    //
    // VISUAL ONLY
    // ZERO INPUT
    // ============================================================

    PanelWindow {
        id: topDecoration

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: root.topRevealHeight

        visible: root.revealed

        color: "transparent"

        exclusiveZone: 0
        focusable: false

        WlrLayershell.layer: WlrLayer.Bottom

        mask: Region {
            width: 0
            height: 0
        }

        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            height: 3

            gradient: Gradient {

                GradientStop {
                    position: 0.0
                    color: root.deepBerry
                }

                GradientStop {
                    position: 0.20
                    color: root.softPlum
                }

                GradientStop {
                    position: 0.40
                    color: root.softPink
                }

                GradientStop {
                    position: 0.50
                    color: root.palePink
                }

                GradientStop {
                    position: 0.60
                    color: root.softPink
                }

                GradientStop {
                    position: 0.80
                    color: root.softPlum
                }

                GradientStop {
                    position: 1.0
                    color: root.deepBerry
                }
            }
        }

        // --------------------------------------------------------
        // CONTINUOUS FLOWER BORDER
        // --------------------------------------------------------

        Text {
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }

            width: parent.width

            text: root.horizontalPattern(
                Math.ceil(parent.width / 45) + 5
            )

            color: root.blushPink

            font.pixelSize: 17
            font.bold: true

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            style: Text.Outline
            styleColor: root.deepPlum

            elide: Text.ElideNone
        }
    }

    // ============================================================
    // BOTTOM DECORATION
    //
    // VISUAL ONLY
    // ZERO INPUT
    // ============================================================

    PanelWindow {
        id: bottomDecoration

        anchors {
            bottom: true
            left: true
            right: true
        }

        implicitHeight: root.bottomRevealHeight

        visible: root.revealed

        color: "transparent"

        exclusiveZone: 0
        focusable: false

        WlrLayershell.layer: WlrLayer.Bottom

        mask: Region {
            width: 0
            height: 0
        }

        Rectangle {
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }

            height: 3

            gradient: Gradient {

                GradientStop {
                    position: 0.0
                    color: root.deepBerry
                }

                GradientStop {
                    position: 0.20
                    color: root.softPlum
                }

                GradientStop {
                    position: 0.40
                    color: root.softPink
                }

                GradientStop {
                    position: 0.50
                    color: root.palePink
                }

                GradientStop {
                    position: 0.60
                    color: root.softPink
                }

                GradientStop {
                    position: 0.80
                    color: root.softPlum
                }

                GradientStop {
                    position: 1.0
                    color: root.deepBerry
                }
            }
        }

        // --------------------------------------------------------
        // CONTINUOUS FLOWER BORDER
        // --------------------------------------------------------

        Text {
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }

            width: parent.width

            text: root.horizontalPattern(
                Math.ceil(parent.width / 45) + 5
            )

            color: root.blushPink

            font.pixelSize: 18
            font.bold: true

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            style: Text.Outline
            styleColor: root.deepPlum

            elide: Text.ElideNone
        }
    }

    // ============================================================
    // LEFT DECORATION
    //
    // VISUAL ONLY
    // ZERO INPUT
    // ============================================================

    PanelWindow {
        id: leftDecoration

        anchors {
            left: true
            top: true
            bottom: true
        }

        implicitWidth: root.sideRevealWidth

        visible: root.revealed

        color: "transparent"

        exclusiveZone: 0
        focusable: false

        WlrLayershell.layer: WlrLayer.Bottom

        mask: Region {
            width: 0
            height: 0
        }

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }

            width: 3

            gradient: Gradient {

                GradientStop {
                    position: 0.0
                    color: root.deepBerry
                }

                GradientStop {
                    position: 0.30
                    color: root.softPlum
                }

                GradientStop {
                    position: 0.50
                    color: root.palePink
                }

                GradientStop {
                    position: 0.70
                    color: root.softPlum
                }

                GradientStop {
                    position: 1.0
                    color: root.deepBerry
                }
            }
        }

        // --------------------------------------------------------
        // CONTINUOUS VERTICAL FLOWER BORDER
        // --------------------------------------------------------

        Text {
            anchors {
                top: parent.top
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }

            width: parent.width

            text: root.verticalPattern(
                Math.ceil(parent.height / 30) + 5
            )

            color: root.blushPink

            font.pixelSize: 17
            font.bold: true

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            style: Text.Outline
            styleColor: root.deepPlum
        }
    }

    // ============================================================
    // RIGHT DECORATION
    //
    // VISUAL ONLY
    // ZERO INPUT
    // ============================================================

    PanelWindow {
        id: rightDecoration

        anchors {
            right: true
            top: true
            bottom: true
        }

        implicitWidth: root.sideRevealWidth

        visible: root.revealed

        color: "transparent"

        exclusiveZone: 0
        focusable: false

        WlrLayershell.layer: WlrLayer.Bottom

        mask: Region {
            width: 0
            height: 0
        }

        Rectangle {
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }

            width: 3

            gradient: Gradient {

                GradientStop {
                    position: 0.0
                    color: root.deepBerry
                }

                GradientStop {
                    position: 0.30
                    color: root.softPlum
                }

                GradientStop {
                    position: 0.50
                    color: root.palePink
                }

                GradientStop {
                    position: 0.70
                    color: root.softPlum
                }

                GradientStop {
                    position: 1.0
                    color: root.deepBerry
                }
            }
        }

        // --------------------------------------------------------
        // CONTINUOUS VERTICAL FLOWER BORDER
        // --------------------------------------------------------

        Text {
            anchors {
                top: parent.top
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }

            width: parent.width

            text: root.verticalPattern(
                Math.ceil(parent.height / 30) + 5
            )

            color: root.blushPink

            font.pixelSize: 17
            font.bold: true

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            style: Text.Outline
            styleColor: root.deepPlum
        }
    }
}