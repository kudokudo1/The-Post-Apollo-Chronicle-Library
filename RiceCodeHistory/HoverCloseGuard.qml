import QtQuick

Item {
    id: root

    // Drop this INSIDE a popup/menu window and fill that window.
    // HoverHandler does not consume mouse clicks; it only observes hover.
    anchors.fill: parent
    z: 999999

    // The PanelWindow / Window / popup to close.
    required property var targetWindow

    // The same EdgeInvisi instance passed to the button/menu.
    // Optional, but recommended so the bar's menu state is released too.
    property var edgeController: null

    // Small grace period for crossing tiny gaps or lag spikes.
    property int closeDelay: 800

    // Turn the helper off for a window that should remain persistent.
    property bool enabled: true

    // Optional menu-specific cleanup. If supplied, this runs instead of
    // the generic close() / visible=false fallback.
    property var closeAction: null

    readonly property bool pointerInside: hover.hovered

    function armClose() {
        if (!root.enabled)
            return

        if (!root.targetWindow)
            return

        if (!root.targetWindow.visible)
            return

        if (root.pointerInside)
            return

        closeTimer.restart()
    }

    function cancelClose() {
        closeTimer.stop()
    }

    function closeTarget() {
        // Re-check at the exact moment the timer fires. If the pointer
        // came back into the window, do nothing.
        if (!root.enabled || root.pointerInside)
            return

        if (!root.targetWindow || !root.targetWindow.visible)
            return

        // Release the controller FIRST so the bar can return to its
        // normal transition + hide path.
        if (root.edgeController) {
            root.edgeController.setMenuHovered(false)
            root.edgeController.setMenuOpen(false)
        }

        // Close ONLY this popup/menu. Never force-hide the bar.
        // A menu can provide closeAction when it has its own local open
        // boolean that also needs to be reset.
        if (root.closeAction) {
            root.closeAction()
            return
        }

        // Generic Window / PanelWindow path. close() is preferred because
        // it does not directly overwrite a visible binding.
        if (typeof root.targetWindow.close === "function") {
            root.targetWindow.close()
            return
        }

        root.targetWindow.visible = false
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) {
                root.cancelClose()

                if (root.edgeController) {
                    root.edgeController.setMenuHovered(true)
                    root.edgeController.setMenuOpen(true)
                }
            } else {
                if (root.edgeController)
                    root.edgeController.setMenuHovered(false)

                root.armClose()
            }
        }
    }

    Timer {
        id: closeTimer

        interval: root.closeDelay
        repeat: false

        onTriggered: root.closeTarget()
    }

    // If the menu becomes visible while the pointer is not already in it,
    // start the grace period immediately. Entering the window cancels it.
    Connections {
        target: root.targetWindow
        ignoreUnknownSignals: true

        function onVisibleChanged() {
            if (!root.targetWindow)
                return

            if (root.targetWindow.visible) {
                if (root.edgeController)
                    root.edgeController.setMenuOpen(true)

                root.armClose()
            } else {
                root.cancelClose()

                if (root.edgeController) {
                    root.edgeController.setMenuHovered(false)
                    root.edgeController.setMenuOpen(false)
                }
            }
        }
    }
}
