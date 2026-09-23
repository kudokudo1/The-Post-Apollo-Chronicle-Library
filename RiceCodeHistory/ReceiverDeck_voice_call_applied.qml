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

    // Lift the lower hardware slightly into the faceplate instead of hugging the bottom edge.
    property real controlLift: 12

    // Subtle grain amount for molded-plastic faces.
    property real grainStrength: 0.12

    // ========================================================
    // PLASTIC GRAIN OVERLAY
    // ========================================================

    component PlasticGrain: Canvas {
        property real density: 0.075
        property real strength: root.grainStrength
        property color lightColor: "#FFFFFF"
        property color darkColor: "#000000"

        anchors.fill: parent
        opacity: strength
        visible: opacity > 0
        antialiasing: false

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onDensityChanged: requestPaint()
        onStrengthChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var step = 3
            for (var y = 1; y < height - 1; y += step) {
                for (var x = 1; x < width - 1; x += step) {
                    var seed = ((x * 73856093) ^ (y * 19349663)) >>> 0
                    var r = (seed % 1000) / 1000.0

                    if (r < density) {
                        var bright = ((seed >> 5) & 1) === 1
                        ctx.fillStyle = bright ? lightColor : darkColor
                        ctx.globalAlpha = 0.38 + (((seed >> 10) % 35) / 100.0)

                        var px = x + (seed % 2)
                        var py = y + ((seed >> 2) % 2)
                        ctx.fillRect(px, py, 1, 1)

                        if (((seed >> 7) % 11) === 0)
                            ctx.fillRect(px + 1, py, 1, 1)
                    }
                }
            }

            ctx.globalAlpha = 1.0
        }
    }

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
                clip: true

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

                PlasticGrain {
                    anchors.fill: parent
                    anchors.margins: 2
                    strength: 0.11
                    density: 0.075
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
                    clip: true

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

                    PlasticGrain {
                        anchors.fill: parent
                        anchors.margins: 2
                        strength: 0.10
                        density: 0.075
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
                    clip: true

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

                    PlasticGrain {
                        anchors.fill: parent
                        anchors.margins: 2
                        strength: 0.10
                        density: 0.075
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

                PlasticGrain {
                    anchors.fill: parent
                    anchors.margins: 2
                    strength: 0.07
                    density: 0.06
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
        clip: true

        PlasticGrain {
            anchors.fill: parent
            anchors.margins: 2
            strength: 0.045
            density: 0.05
        }

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
    // Strong recessed VFD cavity with diagonal corner faces.
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

        color: "#100316"
        z: 4

        border {
            width: 1
            color: "#3A1E44"
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowOpacity: 0.72
            shadowBlur: 0.24
            shadowVerticalOffset: 3
        }

        // Deeper diagonal recess. The dark walls are strongest on the
        // top/left; the bottom/right catch a faint reflected edge.
        Canvas {
            anchors.fill: parent
            z: 0

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var w = width
                var h = height
                var o = 4
                var i = 17

                ctx.fillStyle = "#06010A"
                ctx.beginPath()
                ctx.moveTo(o, o)
                ctx.lineTo(w - o, o)
                ctx.lineTo(w - i, i)
                ctx.lineTo(i, i)
                ctx.closePath()
                ctx.fill()

                ctx.fillStyle = "#020003"
                ctx.beginPath()
                ctx.moveTo(o, o)
                ctx.lineTo(i, i)
                ctx.lineTo(i, h - i)
                ctx.lineTo(o, h - o)
                ctx.closePath()
                ctx.fill()

                ctx.fillStyle = "#40254A"
                ctx.beginPath()
                ctx.moveTo(w - o, o)
                ctx.lineTo(w - i, i)
                ctx.lineTo(w - i, h - i)
                ctx.lineTo(w - o, h - o)
                ctx.closePath()
                ctx.fill()

                ctx.fillStyle = "#32193B"
                ctx.beginPath()
                ctx.moveTo(o, h - o)
                ctx.lineTo(i, h - i)
                ctx.lineTo(w - i, h - i)
                ctx.lineTo(w - o, h - o)
                ctx.closePath()
                ctx.fill()
            }
        }

        Rectangle {
            id: displayDock

            anchors.fill: parent
            anchors.margins: 14

            color: "#020005"
            z: 1

            border {
                width: 1
                color: root.orange
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                color: "#040108"

                border {
                    width: 1
                    color: "#16071D"
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    leftMargin: 2
                    topMargin: 5
                    bottomMargin: 9
                }
                width: 2
                color: "#020003"
                opacity: 0.75
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: 6
                    rightMargin: 9
                    topMargin: 2
                }
                height: 1
                color: "#4B2B57"
                opacity: 0.55
            }

            Rectangle {
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                    rightMargin: 2
                    topMargin: 9
                    bottomMargin: 6
                }
                width: 1
                color: "#7A6880"
                opacity: 0.18
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: 9
                    rightMargin: 5
                    bottomMargin: 2
                }
                height: 1
                color: "#7A6880"
                opacity: 0.16
            }

            Column {
                z: 2

                anchors {
                    left: parent.left
                    top: parent.top
                    leftMargin: 12
                    topMargin: 7
                }

                spacing: 1

                Row {
                    spacing: 12

                    Text {
                        text: "SESSION"
                        color: root.cyan
                        font.family: root.pixelFont
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        text: "03"
                        color: root.orange
                        font.family: root.pixelFont
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Item { width: 24; height: 1 }

                    Text {
                        text: "TAB"
                        color: root.cyan
                        font.family: root.pixelFont
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        text: "02"
                        color: root.orange
                        font.family: root.pixelFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                Row {
                    spacing: 12

                    Text {
                        text: "MODE"
                        color: root.cyan
                        font.family: root.pixelFont
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        text: "NORMAL"
                        color: root.orange
                        font.family: root.pixelFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                Row {
                    spacing: 12

                    Text {
                        text: "CONTROL"
                        color: root.cyan
                        font.family: root.pixelFont
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        text: "PANE"
                        color: root.orange
                        font.family: root.pixelFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                Row {
                    spacing: 12

                    Text {
                        text: "SOURCE"
                        color: root.cyan
                        font.family: root.pixelFont
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        text: "ZELLIJ"
                        color: root.orange
                        font.family: root.pixelFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
            }

            Column {
                z: 2

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 10
                }

                spacing: 8

                Row {
                    spacing: 6

                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: root.orange
                    }

                    Text {
                        text: "PANE"
                        color: root.orange

                        font {
                            family: root.pixelFont
                            pixelSize: 10
                            bold: true
                        }
                    }
                }

                Row {
                    spacing: 6

                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: root.green
                    }

                    Text {
                        text: "ZELLIJ"
                        color: root.green

                        font {
                            family: root.pixelFont
                            pixelSize: 10
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

            rightMargin: 58
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
                clip: true

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

                PlasticGrain {
                    anchors.fill: parent
                    anchors.margins: 2
                    strength: 0.11
                    density: 0.075
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
            rightMargin: 6
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
            clip: true

            border {
                width: 1
                color: "#48354F"
            }

            layer.enabled: true

            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowOpacity: 0.68
                shadowBlur: 0.28
                shadowVerticalOffset: 5
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

                height: 5

                color: "#735F7D"
                opacity: 0.88
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

                height: 7

                color: "#08010C"
                opacity: 0.92
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

            PlasticGrain {
                anchors.fill: parent
                anchors.margins: 2
                strength: 0.13
                density: 0.08
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
    // Physical seam between the upper equipment bay and lower fascia.
    // ========================================================

    Rectangle {
        id: deckDivider

        anchors {
            left: parent.left
            right: parent.right
            top: mediaDock.bottom
            topMargin: 0
        }

        height: 12
        color: "#050107"
        z: 6

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 5
                rightMargin: 5
            }

            height: 2
            color: "#321A3B"
            opacity: 0.78
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 2
                rightMargin: 2
            }

            height: 5
            color: "#020003"
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 7
                rightMargin: 7
            }

            height: 2
            color: "#3A1D45"
            opacity: 0.58
        }
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
        // RAISED LOWER PLASTIC FASCIA
        // ====================================================

        // Main front shell. Deliberately lighter than the upper bay so the
        // lower section reads as a separate piece of molded plastic.
        Rectangle {
            anchors.fill: parent
            color: "#1B0825"
            z: 0
            clip: true

            border {
                width: 1
                color: "#3A1C45"
            }

            PlasticGrain {
                anchors.fill: parent
                anchors.margins: 1
                strength: 0.075
                density: 0.065
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowOpacity: 0.42
                shadowBlur: 0.18
                shadowVerticalOffset: 3
            }
        }

        // Raised face plane.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            color: "#1F0A2A"
            z: 0
            clip: true

            border {
                width: 1
                color: "#2D1436"
            }

            PlasticGrain {
                anchors.fill: parent
                anchors.margins: 1
                strength: 0.11
                density: 0.07
            }
        }

        // Shallow trapezoid top face. This is the actual forward projection
        // of the lower receiver, rather than just a highlight line.
        Canvas {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 4
                rightMargin: 4
                topMargin: 2
            }

            height: 18
            z: 1

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width
                var h = height

                ctx.fillStyle = "#281131"
                ctx.beginPath()
                ctx.moveTo(2, 0)
                ctx.lineTo(w - 2, 0)
                ctx.lineTo(w - 10, h)
                ctx.lineTo(10, h)
                ctx.closePath()
                ctx.fill()

                ctx.fillStyle = "#3A2144"
                ctx.beginPath()
                ctx.moveTo(2, 0)
                ctx.lineTo(18, 0)
                ctx.lineTo(24, h)
                ctx.lineTo(10, h)
                ctx.closePath()
                ctx.fill()

                ctx.fillStyle = "#0A020E"
                ctx.beginPath()
                ctx.moveTo(w - 18, 0)
                ctx.lineTo(w - 2, 0)
                ctx.lineTo(w - 10, h)
                ctx.lineTo(w - 24, h)
                ctx.closePath()
                ctx.fill()
            }
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 14
                rightMargin: 14
                topMargin: 16
            }
            height: 2
            color: "#64406D"
            opacity: 0.38
            z: 1
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 7
                rightMargin: 7
                topMargin: 18
            }
            height: 3
            color: "#08010B"
            opacity: 0.90
            z: 1
        }

        // Side returns reinforce the molded-plastic frame.
        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                leftMargin: 4
                topMargin: 5
                bottomMargin: 5
            }

            width: 3
            color: "#30163A"
            opacity: 0.72
            z: 1
        }

        Rectangle {
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                rightMargin: 4
                topMargin: 5
                bottomMargin: 5
            }

            width: 3
            color: "#08010B"
            opacity: 0.88
            z: 1
        }

        // Bottom return/shadow.
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 5
                rightMargin: 5
                bottomMargin: 4
            }

            height: 11
            color: "#060108"
            opacity: 0.90
            z: 1
        }

        // ====================================================
        // POWER
        // ====================================================

        Rectangle {
            id: powerDock

            z: 3

            anchors {
                left: parent.left
                bottom: parent.bottom

                leftMargin: 14
                bottomMargin: 8 + root.controlLift
            }

            width: 94

            height: Math.min(108, lowerDeck.height - (8 + root.controlLift))

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
                    clip: true

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

                    PlasticGrain {
                        anchors.fill: parent
                        anchors.margins: 2
                        strength: 0.12
                        density: 0.075
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

            z: 3

            anchors {
                right: parent.right
                bottom: parent.bottom

                rightMargin: 14
                bottomMargin: 8 + root.controlLift
            }

            width: 130
            height: Math.min(110, lowerDeck.height - (8 + root.controlLift))

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

            z: 3

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

                VerticalRockerSwitch {
                    uiScale: root.controlScale
                }
                VerticalRockerSwitch {
                    uiScale: root.controlScale
                }
            }
        }

        // ====================================================
        // BUTTON AREA
        // ====================================================

        Item {
            id: buttonArea

            z: 3

            anchors {
                left: powerDock.right
                right: switchesDock.left
                bottom: parent.bottom

                leftMargin: 18
                rightMargin: 18
                bottomMargin: 8 + root.controlLift
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

                    leftMargin: 42 * root.controlScale
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

                    horizontalCenterOffset: -275 * root.controlScale
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

                    horizontalCenterOffset: 275 * root.controlScale
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
