


import Quickshellimport Quickshell.Wayland
import QtQuick

Item {
    id: root

    // ============================================================
    // STATE
    // ============================================================

    property bool revealed: false

    property int edgeTriggerSize: 30
    property int hideDelay: 2000

    property int topRevealHeight: 55
    property int bottomRevealHeight: 135
    property int sideRevealWidth: 65

    property bool topHovered: false
    property bool bottomHovered: false
    property bool leftHovered: false
    property bool rightHovered: false

    readonly property bool borderHovered: topHovered || bottomHovered || leftHovered || rightHovered

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
    // HOVER CONTROL
    // ============================================================

    function updateHoverState() {
        if (borderHovered) {
            hideTimer.stop();
        } else {
            hideTimer.restart();
        }
    }

    // Edge triggers reveal the UI.
    function reveal() {
        hideTimer.stop();
        revealed = true;
    }

    function hideUI() {
        if (borderHovered)
            return;

        revealed = false;
    }

    Timer {
        id: hideTimer
        interval: root.hideDelay
        repeat: false

        onTriggered: root.hideUI()
    }

    // ============================================================
    // HIDE TIMER
    // ============================================================

    Timer {
        id: hideTime

        interval: root.hideDelay
        repeat: false

        onTriggered: {
            root.hideUI();
        }
    }

    // ============================================================
    // TOP EDGE TRIGGER
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

            onEntered: {
                root.reveal();
            }
        }
    }

    // ============================================================
    // BOTTOM EDGE TRIGGER
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

            onEntered: {
                root.reveal();
            }
        }
    }

    // ============================================================
    // LEFT EDGE TRIGGER
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

            onEntered: {
                root.reveal();
            }
        }
    }

    // ============================================================
    // RIGHT EDGE TRIGGER
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

            onEntered: {
                root.reveal();
            }
        }
    }

    // ============================================================
    // TOP HOVER ZONE
    //
    // This is NOT the decoration.
    // It is a very thin invisible hover area.
    // ============================================================

    PanelWindow {
        id: topHoverZone

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 30

        visible: root.revealed

        color: "transparent"

        exclusiveZone: 0
        focusable: false

        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent

            hoverEnabled: true

            onEntered: {
                root.topHovered = true;
                root.updateHoverState();
            }

            onExited: {
                root.topHovered = false;
                root.updateHoverState();
            }
        }
    }

    // ============================================================
    // BOTTOM HOVER ZONE
    // ============================================================

    PanelWindow {
        id: bottomHoverZone

        anchors {
            bottom: true
            left: true
            right: true
        }

        implicitHeight: 30

        visible: root.revealed

        color: "transparent"

        exclusiveZone: 0
        focusable: false

        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent

            hoverEnabled: true

            onEntered: {
                root.bottomHovered = true;
                root.updateHoverState();
            }

            onExited: {
                root.bottomHovered = false;
                root.updateHoverState();
            }
        }
    }

    // ============================================================
    // LEFT HOVER ZONE
    // ============================================================

    PanelWindow {
        id: leftHoverZone

        anchors {
            left: true
            top: true
            bottom: true
        }

        implicitWidth: 30

        visible: root.revealed

        color: "transparent"

        exclusiveZone: 0
        focusable: false

        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent

            hoverEnabled: true

            onEntered: {
                root.leftHovered = true;
                root.updateHoverState();
            }

            onExited: {
                root.leftHovered = false;
                root.updateHoverState();
            }
        }
    }

    // ============================================================
    // RIGHT HOVER ZONE
    // ============================================================

    PanelWindow {
        id: rightHoverZone

        anchors {
            right: true
            top: true
            bottom: true
        }

        implicitWidth: 30

        visible: root.revealed

        color: "transparent"

        exclusiveZone: 0
        focusable: false

        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent

            hoverEnabled: true

            onEntered: {
                root.rightHovered = true;
                root.updateHoverState();
            }

            onExited: {
                root.rightHovered = false;
                root.updateHoverState();
            }
        }
    }

    // ============================================================
    // TOP DECORATION
    // CLICK-THROUGH
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

        Text {
            anchors {
                top: parent.top
                topMargin: 7
                horizontalCenter: parent.horizontalCenter
            }

            text: "⌁  ❀  ⌁  ✿  ⌁  ❀  ⌁"

            color: root.blushPink

            font.pixelSize: 18
            font.bold: true

            style: Text.Outline
            styleColor: root.deepPlum
        }
    }

    // ============================================================
    // BOTTOM DECORATION
    // CLICK-THROUGH
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

        Text {
            anchors {
                bottom: parent.bottom
                bottomMargin: 12
                horizontalCenter: parent.horizontalCenter
            }

            text: "⌁  ❀  ⌁  ✿  ⌁  ❀  ⌁"

            color: root.blushPink

            font.pixelSize: 19
            font.bold: true

            style: Text.Outline
            styleColor: root.deepPlum
        }
    }

    // ============================================================
    // LEFT DECORATION
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

        Text {
            anchors.centerIn: parent

            text: "❀\n⌁\n✿\n⌁\n❀"

            color: root.blushPink

            font.pixelSize: 18
            font.bold: true

            horizontalAlignment: Text.AlignHCenter

            style: Text.Outline
            styleColor: root.deepPlum
        }
    }

    // ============================================================
    // RIGHT DECORATION
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

        Text {
            anchors.centerIn: parent

            text: "❀\n⌁\n✿\n⌁\n❀"

            color: root.blushPink

            font.pixelSize: 18
            font.bold: true

            horizontalAlignment: Text.AlignHCenter

            style: Text.Outline
            styleColor: root.deepPlum
        }
    }
}