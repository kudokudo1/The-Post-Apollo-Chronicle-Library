import QtQuick
import QtQuick.Effects

Rectangle {
    id: root

    color: "#1B0623"

    // ========================================================
    // PALETTE
    // ========================================================

    property color dock: "#14041C"
    property color dockInner: "#0C0211"

    property color topSection: "#12041A"
    property color topSectionInner: "#0E0315"

    property color dividerDark: topSection
    property color panelBorder: "#2A1434"

    property color cyan: "#55CFCA"
    property color cyanDim: "#1E6D6A"
    property color orange: "#ED981A"
    property color offwhite: "#DCF3FA"
    property color red: "#D16041"
    property color green: "#00F782"

    property color plastic: "#19171F"
    property color plasticEdge: "#3D3746"
    property color plasticHighlight: "#5E5867"

    property string pixelFont: "GohuFont 11 Nerd Font Mono"

    // Scale only the physical button/switch controls when the deck gets smaller.
    // Power, MODE dial, and the top receiver geometry stay at their normal size.
    property real controlScale: Math.max(0.55, Math.min(1.0, width / 1180, height / 220))

    // ========================================================
    // PHYSICAL BUTTON
    // ========================================================

    component DeckButton: Item {
        id: buttonRoot

        required property string buttonText
        property real uiScale: root.controlScale

        width: 84 * uiScale
        height: 62 * uiScale

        Item {
            width: 84
            height: 62
            scale: buttonRoot.uiScale
            transformOrigin: Item.TopLeft

            Rectangle {
                anchors.fill: parent

                color: "#07010A"

                border {
                    width: 1
                    color: "#281B2E"
                }
            }

            Rectangle {
                x: 5
                y: 5

                width: parent.width - 10
                height: 50

                color: root.plastic

                border {
                    width: 1
                    color: root.plasticEdge
                }

                layer.enabled: true

                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowOpacity: 0.70
                    shadowBlur: 0.25
                    shadowVerticalOffset: 4
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top

                        leftMargin: 4
                        rightMargin: 4
                        topMargin: 3
                    }

                    height: 3

                    color: root.plasticHighlight
                    opacity: 0.65
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom

                        leftMargin: 4
                        rightMargin: 4
                        bottomMargin: 3
                    }

                    height: 5

                    color: "#070609"
                }

                Text {
                    anchors.centerIn: parent

                    text: buttonRoot.buttonText
                    color: root.offwhite

                    font {
                        family: root.pixelFont
                        pixelSize: 10
                        bold: true
                    }
                }
            }
        }
    }

    // ========================================================
    // VERTICAL ROCKER
    // ========================================================

    component VerticalRockerSwitch: Item {
        id: rocker

        property bool topActive: true
        property real uiScale: root.controlScale

        width: 44 * uiScale
        height: 88 * uiScale

        Item {
            width: 44
            height: 88
            scale: rocker.uiScale
            transformOrigin: Item.TopLeft

            Rectangle {
                anchors.centerIn: parent

                width: 36
                height: 76

                color: "#07010A"

                border {
                    width: 1
                    color: "#281D30"
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 3
                    }

                    height: 31
                    color: rocker.topActive ? root.plastic : "#09060B"

                    border {
                        width: 1
                        color: root.plasticEdge
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 3
                            rightMargin: 3
                            topMargin: 2
                        }

                        height: 2
                        color: root.plasticHighlight
                        opacity: rocker.topActive ? 0.65 : 0.18
                    }
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: 3
                    }

                    height: 31
                    color: rocker.topActive ? "#09060B" : root.plastic

                    border {
                        width: 1
                        color: root.plasticEdge
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 3
                            rightMargin: 3
                            topMargin: 2
                        }

                        height: 2
                        color: root.plasticHighlight
                        opacity: rocker.topActive ? 0.18 : 0.65
                    }
                }
            }
        }
    }

    // ========================================================
    // MODE DIAL
    // ========================================================

    component ModeDial: Item {
        id: dialRoot

        width: 112
        height: 110

        Text {
            anchors {
                left: parent.left
                top: parent.top

                leftMargin: 7
                topMargin: 8
            }

            text: "MODE"
            color: root.offwhite

            font {
                family: root.pixelFont
                pixelSize: 9
                bold: true
            }
        }

        Item {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top

                topMargin: 20
            }

            width: 88
            height: 88

            // =================================================
            // RECESSED OUTER RING
            // =================================================

            Rectangle {
                anchors.centerIn: parent

                width: 88
                height: 88
                radius: 44

                color: "#07010A"

                border {
                    width: 2
                    color: "#332238"
                }
            }

            // =================================================
            // MAIN RAISED DIAL BODY
            // =================================================

            Rectangle {
                id: modeBody

                anchors.centerIn: parent

                width: 78
                height: 78
                radius: 39

                color: root.plastic

                border {
                    width: 1
                    color: root.plasticEdge
                }

                // =================================================
                // CYAN NUMBER DIVIDER
                // =================================================

                Rectangle {
                    anchors.centerIn: parent

                    width: 64
                    height: 64
                    radius: 32

                    color: "transparent"

                    border {
                        width: 2
                        color: root.cyan
                    }
                }

                // =================================================
                // CHANNEL / MODE LETTERS
                // =================================================

                Repeater {
                    model: ["N", "P", "T", "R", "M", "S"]

                    Text {
                        required property int index
                        required property var modelData

                        text: modelData

                        color: index === 0 ? root.orange : root.cyan

                        font {
                            family: root.pixelFont
                            pixelSize: 7
                        }

                        property real a: (Math.PI * 2 * index / 6) - Math.PI / 2

                        property real r: 25

                        x: modeBody.width / 2 + Math.cos(a) * r - width / 2

                        y: modeBody.height / 2 + Math.sin(a) * r - height / 2
                    }
                }

                // =================================================
                // CONICAL INNER SHOULDER
                //
                // Concentric raised circles make the knob rise
                // toward the handle instead of reading flat.
                // =================================================

                Rectangle {
                    anchors.centerIn: parent

                    width: 46
                    height: 46
                    radius: 23

                    color: "#211D26"

                    border {
                        width: 1
                        color: "#4B4451"
                    }

                    layer.enabled: true

                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowOpacity: 0.55
                        shadowBlur: 0.20
                        shadowVerticalOffset: 3
                    }
                }

                Rectangle {
                    anchors.centerIn: parent

                    width: 32
                    height: 32
                    radius: 16

                    color: "#29242E"

                    border {
                        width: 1
                        color: "#5D5563"
                    }

                    // tiny top highlight on center rise
                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top

                            leftMargin: 7
                            rightMargin: 7
                            topMargin: 4
                        }

                        height: 2
                        radius: 1

                        color: "#817A87"
                        opacity: 0.60
                    }
                }

                // =================================================
                // WIDER WHITE CENTER HUB
                // =================================================

                Rectangle {
                    anchors.centerIn: parent

                    width: 14
                    height: 14
                    radius: 7

                    color: root.offwhite

                    border {
                        width: 1
                        color: "#A0B2B7"
                    }

                    layer.enabled: true

                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowOpacity: 0.55
                        shadowBlur: 0.15
                        shadowVerticalOffset: 2
                    }
                }

                // =================================================
                // THICKER FULL-DIAMETER HANDLE
                //
                // Handler remains ABOVE the white center circle.
                // =================================================

                Item {
                    anchors.centerIn: parent

                    width: 66
                    height: 9

                    transformOrigin: Item.Center
                    rotation: -90

                    // underside gives handle visible thickness
                    Rectangle {
                        x: 2
                        y: 4

                        width: 62
                        height: 5

                        radius: 0

                        color: "#8F9BA0"
                    }

                    // main handle
                    Rectangle {
                        x: 2
                        y: 1

                        width: 62
                        height: 6

                        radius: 0

                        color: root.offwhite

                        border {
                            width: 1
                            color: "#B8C8CC"
                        }
                    }

                    // orange true-selection indicator
                    Rectangle {
                        x: 55
                        y: 1

                        width: 6
                        height: 6

                        radius: 0

                        color: root.orange
                    }
                }
            }
        }
    }

    // ========================================================
    // TOP RECEIVER BACKGROUND
    // ========================================================

    Rectangle {
        id: upperBackground

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        height: deckDivider.y

        color: root.topSection

        z: 0
    }

    // ========================================================
    // TOP EDGE
    // ========================================================

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        height: 2

        color: root.cyan

        z: 10
    }

    // ========================================================
    // SMALL RIGHT INFORMATION PANEL
    //
    // Left edge remains where it was.
    // Width grows to the RIGHT so its outside edge lines up
    // with the MODE dial dock's 14px right margin.
    // ========================================================

    Rectangle {
        id: cornerPanel

        anchors {
            right: parent.right
            top: parent.top

            rightMargin: 14
            topMargin: 18
        }

        // Old:
        // width 152 + rightMargin 28
        //
        // New:
        // width 166 + rightMargin 14
        //
        // So the LEFT EDGE stays in the same place.
        width: 166
        height: 106

        color: root.topSection

        z: 5

        border {
            width: 1
            color: root.panelBorder
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 7

            color: "#100317"

            border {
                width: 1
                color: "#26102F"
            }
        }

        Text {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top

                leftMargin: 15
                rightMargin: 12
                topMargin: 17
            }

            text: "A BETTER\n" + "COMMAND LINE\n" + "EXPERIENCE"

            color: root.offwhite

            font {
                family: root.pixelFont
                pixelSize: 11
                bold: true
            }

            lineHeight: 1.15
        }
    }

    // ========================================================
    // DISPLAY
    // ========================================================

    Rectangle {
        id: displayBezel

        anchors {
            right: cornerPanel.left
            top: cornerPanel.top

            rightMargin: 12
        }

        width: Math.min(785, parent.width * 0.405)

        height: 106

        color: "#07010B"

        z: 4

        border {
            width: 2
            color: "#25102E"
        }

        layer.enabled: true

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowOpacity: 0.75
            shadowBlur: 0.25
            shadowVerticalOffset: 3
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top

                leftMargin: 5
                rightMargin: 5
                topMargin: 5
            }

            height: 7

            color: "#020005"
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom

                leftMargin: 5
                rightMargin: 5
                bottomMargin: 5
            }

            height: 5

            color: "#24112D"
            opacity: 0.60
        }

        Rectangle {
            id: displayDock

            anchors.fill: parent
            anchors.margins: 9

            color: "#050109"

            border {
                width: 1
                color: root.orange
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3

                color: "#030106"

                border {
                    width: 1
                    color: "#16071D"
                }
            }

            Column {
                anchors {
                    left: parent.left
                    top: parent.top
                    leftMargin: 12
                    topMargin: 9
                }

                spacing: 2

                Row {
                    spacing: 12

                    Text {
                        text: "SESSION"
                        color: root.cyan
                        font.family: root.pixelFont
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: "03"
                        color: root.orange
                        font.family: root.pixelFont
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Item { width: 28; height: 1 }

                    Text {
                        text: "TAB"
                        color: root.cyan
                        font.family: root.pixelFont
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: "02"
                        color: root.orange
                        font.family: root.pixelFont
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                Row {
                    spacing: 12

                    Text {
                        text: "MODE"
                        color: root.cyan
                        font.family: root.pixelFont
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: "NORMAL"
                        color: root.orange
                        font.family: root.pixelFont
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                Row {
                    spacing: 12

                    Text {
                        text: "CONTROL"
                        color: root.cyan
                        font.family: root.pixelFont
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: "PANE"
                        color: root.orange
                        font.family: root.pixelFont
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                Row {
                    spacing: 12

                    Text {
                        text: "SOURCE"
                        color: root.cyan
                        font.family: root.pixelFont
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: "ZELLIJ"
                        color: root.orange
                        font.family: root.pixelFont
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
            }

            Column {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter

                    rightMargin: 14
                }

                spacing: 10

                Row {
                    spacing: 7

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4

                        color: root.orange
                    }

                    Text {
                        text: "PANE"
                        color: root.orange

                        font {
                            family: root.pixelFont
                            pixelSize: 11
                            bold: true
                        }
                    }
                }

                Row {
                    spacing: 7

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4

                        color: root.green
                    }

                    Text {
                        text: "ZELLIJ"
                        color: root.green

                        font {
                            family: root.pixelFont
                            pixelSize: 11
                            bold: true
                        }
                    }
                }
            }
        }
    }

    // ========================================================
    // EJECT
    //
    // Another 12px LEFT.
    // ========================================================

    Item {
        id: ejectControl

        anchors {
            right: displayBezel.left
            top: displayBezel.top

            rightMargin: 46
            topMargin: -2
        }

        width: 66
        height: 80

        z: 5

        Text {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top

                topMargin: 7
            }

            text: "EJECT"
            color: root.offwhite

            font {
                family: root.pixelFont
                pixelSize: 8
                bold: true
            }
        }

        Rectangle {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top

                topMargin: 21
            }

            width: 50
            height: 46

            color: "#07010A"

            border {
                width: 1
                color: "#281B2E"
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 5

                color: root.plastic

                border {
                    width: 1
                    color: root.plasticEdge
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top

                        leftMargin: 3
                        rightMargin: 3
                        topMargin: 2
                    }

                    height: 3

                    color: root.plasticHighlight
                    opacity: 0.65
                }

                Text {
                    anchors.centerIn: parent

                    text: "⏏"
                    color: root.offwhite

                    font {
                        family: root.pixelFont
                        pixelSize: 16
                        bold: true
                    }
                }
            }
        }
    }

    // ========================================================
    // DVD FRONT PANEL
    // ========================================================

    Rectangle {
        id: mediaDock

        anchors {
            left: parent.left
            right: ejectControl.left
            top: displayBezel.top

            leftMargin: 36
            rightMargin: 20
        }

        height: 106

        color: "#180723"

        border {
            width: 2
            color: root.panelBorder
        }

        z: 4

        Rectangle {
            anchors.fill: parent
            anchors.margins: 5

            color: "#150520"

            border {
                width: 1
                color: "#34203E"
            }
        }

        Rectangle {
            id: dvdFace

            anchors.fill: parent
            anchors.margins: 11

            color: "#23102E"

            border {
                width: 1
                color: "#48354F"
            }

            layer.enabled: true

            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowOpacity: 0.60
                shadowBlur: 0.30
                shadowVerticalOffset: 4
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top

                    leftMargin: 3
                    rightMargin: 3
                    topMargin: 3
                }

                height: 4

                color: "#56455F"
                opacity: 0.85
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom

                    leftMargin: 3
                    rightMargin: 3
                    bottomMargin: 3
                }

                height: 6

                color: "#0A030E"
                opacity: 0.85
            }

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom

                    leftMargin: 12
                    topMargin: 6
                    bottomMargin: 6
                }

                width: 2

                color: root.dividerDark
            }

            Rectangle {
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom

                    rightMargin: 12
                    topMargin: 6
                    bottomMargin: 6
                }

                width: 2

                color: root.dividerDark
            }

            Row {
                anchors {
                    left: parent.left
                    top: parent.top

                    leftMargin: 24
                    topMargin: 8
                }

                spacing: 8

                Text {
                    text: "✦"
                    color: root.orange

                    font {
                        family: root.pixelFont
                        pixelSize: 31
                        bold: true
                    }
                }

                Text {
                    text: "✦"
                    color: root.cyan

                    font {
                        family: root.pixelFont
                        pixelSize: 31
                        bold: true
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    text: "A Post-Apollo//Experience"
                    color: root.offwhite

                    font {
                        family: root.pixelFont
                        pixelSize: 22
                        bold: true
                    }
                }
            }

            // moved UP so it no longer collides with DVD / TERMINAL
            Text {
                anchors {
                    left: parent.left
                    top: parent.top

                    leftMargin: 28
                    topMargin: 42
                }

                text: "DIGITAL VIDEO / DATA DECK"
                color: root.cyan

                font {
                    family: root.pixelFont
                    pixelSize: 13
                    bold: true
                }
            }

            Text {
                anchors {
                    left: parent.left
                    bottom: parent.bottom

                    leftMargin: 28
                    bottomMargin: 10
                }

                text: "DVD / TERMINAL"
                color: root.offwhite

                font {
                    family: root.pixelFont
                    pixelSize: 11
                    bold: true
                }
            }
        }
    }

    // ========================================================
    // SOLID MIDDLE DIVIDER
    // ========================================================

    Rectangle {
        id: deckDivider

        anchors {
            left: parent.left
            right: parent.right
            top: mediaDock.bottom

            topMargin: 0
        }

        height: 11

        color: root.topSection

        z: 6
    }

    // ========================================================
    // LOWER RECEIVER
    // ========================================================

    Item {
        id: lowerDeck

        anchors {
            left: parent.left
            right: parent.right
            top: deckDivider.bottom
            bottom: parent.bottom
        }

        z: 2

        // ====================================================
        // POWER
        // ====================================================

        Rectangle {
            id: powerDock

            anchors {
                left: parent.left
                bottom: parent.bottom

                leftMargin: 14
                bottomMargin: 8
            }

            width: 94

            height: Math.min(108, lowerDeck.height - 12)

            color: root.dock

            border {
                width: 1
                color: root.cyan
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6

                color: root.dockInner

                border {
                    width: 1
                    color: root.orange
                }
            }

            Text {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top

                    topMargin: 9
                }

                text: "POWER"
                color: root.offwhite

                font {
                    family: root.pixelFont
                    pixelSize: 9
                    bold: true
                }
            }

            Rectangle {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom

                    bottomMargin: 8
                }

                width: 58
                height: 74

                color: "#07010A"

                border {
                    width: 1
                    color: "#4D202A"
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5

                    color: root.plastic

                    border {
                        width: 2
                        color: root.red
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top

                            leftMargin: 5
                            rightMargin: 5
                            topMargin: 3
                        }

                        height: 4

                        color: "#6C454E"
                    }

                    Text {
                        anchors.centerIn: parent

                        text: "⏻"
                        color: root.red

                        font {
                            family: root.pixelFont
                            pixelSize: 25
                            bold: true
                        }
                    }
                }
            }
        }

        // ====================================================
        // MODE DIAL
        // ====================================================

        Rectangle {
            id: modeDock

            anchors {
                right: parent.right
                bottom: parent.bottom

                rightMargin: 14
                bottomMargin: 8
            }

            width: 130
            height: 110

            color: root.dock

            border {
                width: 1
                color: root.cyan
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6

                color: root.dockInner

                border {
                    width: 1
                    color: root.orange
                }
            }

            ModeDial {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter

                    verticalCenterOffset: -6
                }

                scale: 0.88
            }
        }

        // ====================================================
        // SWITCH DOCK
        // ====================================================

        Rectangle {
            id: switchesDock

            anchors {
                right: modeDock.left
                verticalCenter: modeDock.verticalCenter

                rightMargin: 16
            }

            width: 110 * root.controlScale
            height: 90 * root.controlScale

            color: root.dock

            border {
                width: 1
                color: root.cyan
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 5

                color: root.dockInner

                border {
                    width: 1
                    color: root.dividerDark
                }
            }

            Row {
                anchors.centerIn: parent

                spacing: 8 * root.controlScale

                VerticalRockerSwitch { uiScale: root.controlScale }
                VerticalRockerSwitch { uiScale: root.controlScale }
            }
        }

        // ====================================================
        // BUTTON AREA
        // ====================================================

        Item {
            id: buttonArea

            anchors {
                left: powerDock.right
                right: switchesDock.left
                bottom: parent.bottom

                leftMargin: 18
                rightMargin: 18
                bottomMargin: 8
            }

            height: 82 * root.controlScale

            // =================================================
            // NEW / CLOSE
            // =================================================

            Rectangle {
                id: editDock

                anchors {
                    left: parent.left
                    bottom: parent.bottom

                    leftMargin: 18 * root.controlScale
                }

                width: 212 * root.controlScale
                height: 82 * root.controlScale

                color: root.dock

                border {
                    width: 1
                    color: root.cyan
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5

                    color: root.dockInner

                    border {
                        width: 1
                        color: root.dividerDark
                    }
                }

                Row {
                    anchors.centerIn: parent

                    spacing: 22 * root.controlScale

                    DeckButton {
                        uiScale: root.controlScale
                        buttonText: "NEW"
                    }

                    DeckButton {
                        uiScale: root.controlScale
                        buttonText: "CLOSE"
                    }
                }
            }

            // =================================================
            // FULL / FLOAT / RENAME
            // =================================================

            Rectangle {
                id: windowDock

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter

                    horizontalCenterOffset: -235 * root.controlScale
                }

                width: 322 * root.controlScale
                height: 82 * root.controlScale

                color: root.dock

                border {
                    width: 1
                    color: root.cyan
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5

                    color: root.dockInner

                    border {
                        width: 1
                        color: root.dividerDark
                    }
                }

                Row {
                    anchors.centerIn: parent

                    spacing: 12 * root.controlScale

                    DeckButton {
                        uiScale: root.controlScale
                        buttonText: "FULL"
                    }

                    DeckButton {
                        uiScale: root.controlScale
                        buttonText: "FLOAT"
                    }

                    DeckButton {
                        uiScale: root.controlScale
                        buttonText: "RENAME"
                    }
                }
            }

            // =================================================
            // PIN / FRAME / SYNC
            // =================================================

            Rectangle {
                id: utilityButtonDock

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter

                    horizontalCenterOffset: 235 * root.controlScale
                }

                width: 298 * root.controlScale
                height: 82 * root.controlScale

                color: root.dock

                border {
                    width: 1
                    color: root.cyan
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5

                    color: root.dockInner

                    border {
                        width: 1
                        color: root.dividerDark
                    }
                }

                Row {
                    anchors.centerIn: parent

                    spacing: 10 * root.controlScale

                    DeckButton {
                        uiScale: root.controlScale
                        buttonText: "PIN"
                    }

                    DeckButton {
                        uiScale: root.controlScale
                        buttonText: "FRAME"
                    }

                    DeckButton {
                        uiScale: root.controlScale
                        buttonText: "SYNC"
                    }
                }
            }

            // =================================================
            // OPTION
            // =================================================

            Rectangle {
                id: optionDock

                anchors {
                    right: parent.right
                    bottom: parent.bottom

                    rightMargin: 30 * root.controlScale
                }

                width: 104 * root.controlScale
                height: 82 * root.controlScale

                color: root.dock

                border {
                    width: 1
                    color: root.cyan
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5

                    color: root.dockInner

                    border {
                        width: 1
                        color: root.dividerDark
                    }
                }

                DeckButton {
                    anchors.centerIn: parent
                    uiScale: root.controlScale
                    buttonText: "OPTION"
                }
            }
        }
    }
}
