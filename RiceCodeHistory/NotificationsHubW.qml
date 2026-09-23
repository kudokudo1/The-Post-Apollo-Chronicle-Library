import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services.notifications
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: root

    property bool menuOpen: false

    // ===== QUICK CONFIG =========================================
    // Main panel geometry. These preserve your current placement.
    property int panelWidth: 520
    property int panelTopMargin: 0
    property int panelBottomMargin: 5
    property int panelLeftMargin: 0
    property int panelRightMargin: 5
    property int frameInset: 8

    // Main purple/black glass.
    property real backgroundOpacity: 0.60

    // Card opacity compensation:
    // old stack = 0.20 background + 0.88 card = ~0.904 effective alpha
    // new background = 0.60, so a 0.76 card keeps roughly the same result.
    property real cardFillOpacity: 0.76

    property int headerHeight: 62
    property int historyTopGap: 10
    property int historyBottomGap: 12

    property int controlBayHeight: 220
    property int controlBaySideMargin: 10
    property int controlBayBottomMargin: 10
    property real controlBayOpacity: 0.60

    property int cardHeight: 116
    property int cardSpacing: 10
    property int cardGlowGutter: 24
    property int cardContentMargin: 10

    property real textGlowOpacity: 0.60
    property real frameGlowOpacity: 0.60
    property real cardGlowOpacity: 0.60

    property int textGlowRadius: 14
    property int textGlowSamples: 15
    property int cardGlowRadius: 22
    property int cardGlowSamples: 41

    property int hubTitleFontSize: 20
    property int storedCountFontSize: 14
    property int appNameFontSize: 14
    property int notificationTitleFontSize: 15
    property int notificationMessageFontSize: 12
    property int notificationMetaFontSize: 10

    property int appIconSize: 36
    property int appIconInnerMargin: 3

    property int scrollBarAreaWidth: 14
    property int scrollTrackWidth: 2
    property int scrollThumbWidth: 5
    property int scrollThumbMinHeight: 34

    // ===== APP-WIDE CARD STATE ==================================
    // Temporary frontend state. Keyed per app so every card from the
    // same source updates together. Backend/persistence can own this later.
    property var appStates: ({})

    // ===== WINDOW ===============================================
    implicitWidth: root.panelWidth

    anchors {
        top: true
        bottom: true
        left: false
        right: true
    }

    margins {
        top: root.panelTopMargin
        bottom: root.panelBottomMargin
        left: root.panelLeftMargin
        right: root.panelRightMargin
    }

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"
    surfaceFormat.opaque: false

    // Keep the PanelWindow mapped permanently to avoid the second-open crash.
    visible: true

    // Closed = invisible + click-through.
    mask: Region {
        x: 0
        y: 0
        width: root.menuOpen ? root.width : 0
        height: root.menuOpen ? root.height : 0
    }

    // ===== LOCAL VISUAL TYPE: GLOW TEXT =========================
    component GlowText: Item {
        id: glowText

        property string text: ""
        property color textColor: Colors.cyan
        property color glowColor: textColor
        property int pixelSize: 14
        property real glowOpacity: root.textGlowOpacity
        property real glowRadius: root.textGlowRadius
        property int glowSamples: root.textGlowSamples
        property int elideMode: Text.ElideNone

        GohuText {
            id: glowLabel
            anchors.fill: parent
            text: glowText.text
            font.pixelSize: glowText.pixelSize
            color: glowText.textColor
            elide: glowText.elideMode
            verticalAlignment: Text.AlignVCenter
        }

        DropShadow {
            anchors.fill: glowLabel
            source: glowLabel
            horizontalOffset: 0
            verticalOffset: 0
            radius: glowText.glowRadius
            samples: glowText.glowSamples
            color: glowText.glowColor
            opacity: glowText.glowOpacity
            transparentBorder: true
        }
    }

    // ===== LOCAL VISUAL TYPE: MINI BUTTON =======================
    component MiniButton: Rectangle {
        id: miniButton

        property string label: ""
        property bool active: false
        property color activeColor: Colors.orange
        property int labelPixelSize: 11

        signal triggered()

        readonly property bool hovered: buttonMouse.containsMouse
        readonly property bool pressed: buttonMouse.pressed
        readonly property color stateColor:
            pressed ? Colors.magenta
            : hovered ? Colors.orange
            : active ? activeColor
            : Colors.cyan

        color: pressed ? Colors.magenta : hovered ? Colors.yellow : Colors.dark
        border.width: 1
        border.color: stateColor

        GohuText {
            id: miniButtonText
            anchors.centerIn: parent
            text: miniButton.label
            font.pixelSize: miniButton.labelPixelSize
            color: miniButton.pressed ? Colors.black : miniButton.stateColor
        }

        DropShadow {
            anchors.fill: miniButtonText
            source: miniButtonText
            horizontalOffset: 0
            verticalOffset: 0
            radius: 12
            samples: 15
            color: miniButton.stateColor
            opacity: miniButton.pressed ? 1.0 : 0.60
            transparentBorder: true
        }

        DropShadow {
            anchors.fill: miniButton
            source: miniButton
            horizontalOffset: 0
            verticalOffset: 0
            radius: 10
            samples: 21
            color: miniButton.stateColor
            opacity:
                miniButton.pressed ? 0.55
                : miniButton.hovered ? 0.40
                : miniButton.active ? 0.28
                : 0.10
            z: -1
            transparentBorder: true
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: miniButton.triggered()
        }
    }

    // ===== FUNCTIONS ============================================
    function open() {
        menuOpen = true;
    }

    function close() {
        menuOpen = false;
    }

    function toggle() {
        menuOpen = !menuOpen;
    }

    function appKeyFor(sourceId, source) {
        var sourceIdText = String(sourceId || "").trim().toLowerCase();
        var sourceText = String(source || "").trim().toLowerCase();

        if (sourceIdText !== "")
            return sourceIdText;
        if (sourceText !== "")
            return sourceText;
        return "unknown";
    }

    function stateForApp(appKey) {
        var current = root.appStates[appKey];
        if (current !== undefined)
            return current;

        return {
            favorite: false,
            snoozed: false,
            dnd: false
        };
    }

    function setAppFlag(appKey, flagName, enabled) {
        var nextStates = ({});

        for (var existingKey in root.appStates)
            nextStates[existingKey] = root.appStates[existingKey];

        var current = root.stateForApp(appKey);
        var nextState = {
            favorite: current.favorite === true,
            snoozed: current.snoozed === true,
            dnd: current.dnd === true
        };

        nextState[flagName] = enabled === true;
        nextStates[appKey] = nextState;

        // Replace the whole object so every card from this app updates together.
        root.appStates = nextStates;
    }

    function toggleAppFlag(appKey, flagName) {
        var current = root.stateForApp(appKey);
        root.setAppFlag(appKey, flagName, current[flagName] !== true);
    }

    function resolveAppIcon(appIcon, sourceId) {
        var icon = String(appIcon || "");

        if (icon === "")
            icon = String(sourceId || "");
        if (icon === "")
            return "";

        if (icon.indexOf("/") === 0
                || icon.indexOf("file:") === 0
                || icon.indexOf("image:") === 0
                || icon.indexOf("data:") === 0)
            return icon;

        return Quickshell.iconPath(icon, true);
    }

    // Dismiss is per-notification; favorite/snooze/DND are app-wide.
    function dismissNotification(historyIndex) {
        if (historyIndex < 0
                || historyIndex >= NotificationsService.notifications.count)
            return;

        var entry = NotificationsService.notifications.get(historyIndex);
        var eventId = String(entry.id || "");

        NotificationsService.notifications.remove(historyIndex);

        if (eventId !== "") {
            for (var i = NotificationsService.activeNotifications.count - 1;
                    i >= 0;
                    i--) {
                var active = NotificationsService.activeNotifications.get(i);
                if (String(active.id || "") === eventId)
                    NotificationsService.activeNotifications.remove(i);
            }
        }

        NotificationsService.scheduleHistorySave();
    }

    // ===== HUB CONTENT ==========================================
    Item {
        id: hubContent
        anchors.fill: parent
        opacity: root.menuOpen ? 1.0 : 0.0

        // Heavy effects added later should bind running/enabled to root.menuOpen.

        // ===== PURPLE GLASS =====================================
        Rectangle {
            id: background
            anchors.fill: parent
            anchors.margins: root.frameInset
            color: Colors.black
            opacity: root.backgroundOpacity
        }

        // ===== ACTIVE OUTER FRAME GLOW ==========================
        Rectangle {
            id: frameGlowSource
            anchors.fill: parent
            anchors.margins: root.frameInset
            color: "transparent"
            border.width: 2
            border.color: Colors.orange
            z: -2
        }

        DropShadow {
            anchors.fill: frameGlowSource
            source: frameGlowSource
            horizontalOffset: 0
            verticalOffset: 0
            radius: 18
            samples: 37
            color: Colors.orange
            opacity: root.frameGlowOpacity
            z: -3
            transparentBorder: true
        }

        // ===== MAIN FRAME =======================================
        Rectangle {
            id: frame
            anchors.fill: parent
            anchors.margins: root.frameInset
            color: "transparent"
            border.width: 2
            border.color: Colors.orange

            // ===== HEADER =======================================
            Rectangle {
                id: header
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: root.headerHeight
                color: "transparent"
                border.width: 1
                border.color: Colors.cyan

                GlowText {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    anchors.leftMargin: 18
                    width: 270
                    height: 30
                    text: "NOTIFICATION HUB"
                    pixelSize: root.hubTitleFontSize
                    textColor: Colors.magenta
                    glowColor: Colors.magenta
                }

                GlowText {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    anchors.rightMargin: 18
                    width: 120
                    height: 24
                    text: NotificationsService.notifications.count + " STORED"
                    pixelSize: root.storedCountFontSize
                    textColor: Colors.cyan
                    glowColor: Colors.cyan
                    elideMode: Text.ElideRight
                }

                // Header divider is CYAN.
                Rectangle {
                    id: headerLine
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 1
                    color: Colors.cyan
                }

                DropShadow {
                    anchors.fill: headerLine
                    source: headerLine
                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 14
                    samples: 15
                    color: Colors.cyan
                    opacity: 0.60
                    transparentBorder: true
                }
            }

            // ===== CONTROL BAY ==================================
            Rectangle {
                id: controlBay
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                anchors.bottomMargin: root.controlBayBottomMargin
                anchors.leftMargin: root.controlBaySideMargin
                anchors.rightMargin: root.controlBaySideMargin
                height: root.controlBayHeight
                color: "transparent"
                border.width: 1
                border.color: Colors.cyan

                Rectangle {
                    anchors.fill: parent
                    color: Colors.dark
                    opacity: root.controlBayOpacity
                    z: -2
                }

                Rectangle {
                    id: controlBayTopLine
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: 1
                    color: Colors.cyan
                }

                DropShadow {
                    anchors.fill: controlBayTopLine
                    source: controlBayTopLine
                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 14
                    samples: 15
                    color: Colors.cyan
                    opacity: 0.60
                    transparentBorder: true
                }

                GlowText {
                    anchors {
                        top: parent.top
                        left: parent.left
                    }
                    anchors.topMargin: 14
                    anchors.leftMargin: 16
                    width: 180
                    height: 24
                    text: "CONTROL BAY"
                    pixelSize: 14
                    textColor: Colors.magenta
                    glowColor: Colors.magenta
                }

                GlowText {
                    anchors {
                        top: parent.top
                        right: parent.right
                    }
                    anchors.topMargin: 14
                    anchors.rightMargin: 16
                    width: 240
                    height: 24
                    text:
                        "HISTORY: "
                        + (NotificationsService.historyEnabled ? "ON" : "OFF")
                        + "  //  "
                        + NotificationsService.historyStatus.toUpperCase()
                    pixelSize: 10
                    textColor: Colors.cyan
                    glowColor: Colors.cyan
                    elideMode: Text.ElideRight
                }

                // Empty structured deck for future sliders / filters / routing.
                Rectangle {
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                    }
                    anchors.topMargin: 48
                    anchors.bottomMargin: 12
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    color: "transparent"
                    border.width: 1
                    border.color: Colors.cyan
                    opacity: 0.18
                }
            }

            // ===== HISTORY AREA =================================
            Item {
                id: historyArea
                anchors {
                    top: header.bottom
                    bottom: controlBay.top
                    left: parent.left
                    right: parent.right
                    topMargin: root.historyTopGap
                    bottomMargin: root.historyBottomGap
                    leftMargin: 10
                    rightMargin: 10
                }

                // ===== LIST =====================================
                ListView {
                    id: historyList
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left
                        right: scrollBarArea.left
                    }
                    spacing: root.cardSpacing
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: NotificationsService.notifications

                    header: Item {
                        width: 1
                        height: 12
                    }

                    footer: Item {
                        width: 1
                        height: 12
                    }

                    delegate: Item {
                        id: notificationEntry

                        required property int index
                        required property string source
                        required property string sourceId
                        required property string title
                        required property string message
                        required property string appIcon
                        required property string category
                        required property string severity

                        readonly property string appKey:
                            root.appKeyFor(notificationEntry.sourceId, notificationEntry.source)

                        readonly property var sharedAppState:
                            root.stateForApp(notificationEntry.appKey)

                        readonly property string categoryName:
                            notificationEntry.category.toLowerCase()

                        readonly property string severityName:
                            notificationEntry.severity.toLowerCase()

                        readonly property color notificationColor: {
                            if (severityName === "emergency"
                                    || severityName === "critical"
                                    || categoryName === "emergency")
                                return Colors.red;

                            if (categoryName === "social"
                                    || categoryName === "friend"
                                    || categoryName === "friends"
                                    || categoryName === "message"
                                    || categoryName === "communication"
                                    || categoryName === "audio"
                                    || categoryName === "voice"
                                    || categoryName === "media"
                                    || categoryName === "fullscreen")
                                return Colors.green;

                            if (severityName === "important"
                                    || categoryName === "important")
                                return Colors.magenta;

                            if (severityName === "warning")
                                return Colors.orange;

                            return Colors.cyan;
                        }

                        readonly property color sourceColor: {
                            if (severityName === "emergency"
                                    || severityName === "critical"
                                    || categoryName === "emergency")
                                return Colors.red;

                            if (categoryName === "social"
                                    || categoryName === "friend"
                                    || categoryName === "friends"
                                    || categoryName === "message"
                                    || categoryName === "communication"
                                    || categoryName === "audio"
                                    || categoryName === "voice"
                                    || categoryName === "media"
                                    || categoryName === "fullscreen")
                                return Colors.green;

                            return Colors.magenta;
                        }

                        readonly property url resolvedAppIcon:
                            root.resolveAppIcon(notificationEntry.appIcon, notificationEntry.sourceId)

                        width: historyList.width
                        height: root.cardHeight

                        // ===== SOFT CARD GLOW SOURCE ============
                        Rectangle {
                            id: cardGlowSource
                            anchors {
                                top: parent.top
                                bottom: parent.bottom
                                left: parent.left
                                right: parent.right
                                leftMargin: root.cardGlowGutter
                                rightMargin: root.cardGlowGutter
                            }
                            color: "transparent"
                            border.width: 1
                            border.color: notificationEntry.notificationColor
                            z: -3
                        }

                        DropShadow {
                            anchors.fill: cardGlowSource
                            source: cardGlowSource
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: root.cardGlowRadius
                            samples: root.cardGlowSamples
                            color: notificationEntry.notificationColor
                            opacity: root.cardGlowOpacity
                            z: -4
                            transparentBorder: true
                        }

                        // ===== CARD ==============================
                        Rectangle {
                            id: card
                            anchors {
                                top: parent.top
                                bottom: parent.bottom
                                left: parent.left
                                right: parent.right
                                leftMargin: root.cardGlowGutter
                                rightMargin: root.cardGlowGutter
                            }
                            color: "transparent"
                            border.width: 1
                            border.color: notificationEntry.notificationColor

                            // Only the fill gets alpha. Text/icons stay full opacity.
                            Rectangle {
                                anchors.fill: parent
                                color: Colors.black
                                opacity: root.cardFillOpacity
                                z: -2
                            }

                            // Small diagnostic accent rail.
                            Rectangle {
                                id: accentRail
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: parent.left
                                    topMargin: 8
                                    bottomMargin: 8
                                    leftMargin: 6
                                }
                                width: 2
                                color: notificationEntry.notificationColor
                            }

                            DropShadow {
                                anchors.fill: accentRail
                                source: accentRail
                                horizontalOffset: 0
                                verticalOffset: 0
                                radius: 10
                                samples: 15
                                color: notificationEntry.notificationColor
                                opacity: 0.45
                                transparentBorder: true
                            }

                            // ===== FAVORITE ======================
                            MiniButton {
                                id: favoriteButton
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                }
                                anchors.topMargin: root.cardContentMargin
                                anchors.leftMargin: root.cardContentMargin + 6
                                width: 28
                                height: 28
                                active: notificationEntry.sharedAppState.favorite === true
                                activeColor: Colors.magenta
                                label: active ? "✦" : "✧"
                                labelPixelSize: 17

                                onTriggered: {
                                    root.toggleAppFlag(notificationEntry.appKey, "favorite");
                                }
                            }

                            // ===== APP ICON ======================
                            Rectangle {
                                id: appIconBox
                                anchors {
                                    top: parent.top
                                    left: favoriteButton.right
                                }
                                anchors.topMargin: root.cardContentMargin
                                anchors.leftMargin: 7
                                width: root.appIconSize
                                height: root.appIconSize
                                color: Colors.dark
                                border.width: 1
                                border.color: notificationEntry.sourceColor

                                Image {
                                    id: appIconImage
                                    anchors.fill: parent
                                    anchors.margins: root.appIconInnerMargin
                                    source: notificationEntry.resolvedAppIcon
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                // One icon only: real app icon if ready, fallback otherwise.
                                GohuText {
                                    anchors.centerIn: parent
                                    visible: appIconImage.status !== Image.Ready
                                    text: "-⋆♱⋆-"
                                    font.pixelSize: 9
                                    color: notificationEntry.sourceColor
                                }
                            }

                            // ===== APP NAME ======================
                            GlowText {
                                id: appName
                                anchors {
                                    top: parent.top
                                    left: appIconBox.right
                                    right: appControls.left
                                }
                                anchors.topMargin: root.cardContentMargin
                                anchors.leftMargin: 9
                                anchors.rightMargin: 9
                                height: 20
                                text: notificationEntry.source
                                pixelSize: root.appNameFontSize
                                textColor: notificationEntry.sourceColor
                                glowColor: notificationEntry.sourceColor
                                elideMode: Text.ElideRight
                            }

                            // ===== CATEGORY ======================
                            GlowText {
                                anchors {
                                    top: appName.bottom
                                    left: appIconBox.right
                                    right: appControls.left
                                }
                                anchors.leftMargin: 9
                                anchors.rightMargin: 9
                                height: 15
                                text:
                                    notificationEntry.category.toUpperCase()
                                    + "  //  "
                                    + notificationEntry.severity.toUpperCase()
                                pixelSize: root.notificationMetaFontSize
                                textColor: notificationEntry.notificationColor
                                glowColor: notificationEntry.notificationColor
                                elideMode: Text.ElideRight
                            }

                            // ===== CARD CONTROLS =================
                            // ZZ + DND are app-wide. X dismisses only this event.
                            Row {
                                id: appControls
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                }
                                anchors.topMargin: root.cardContentMargin
                                anchors.rightMargin: root.cardContentMargin
                                spacing: 5

                                MiniButton {
                                    width: 32
                                    height: 28
                                    label: "ZZ"
                                    active: notificationEntry.sharedAppState.snoozed === true
                                    activeColor: Colors.orange

                                    onTriggered: {
                                        root.toggleAppFlag(notificationEntry.appKey, "snoozed");
                                    }
                                }

                                MiniButton {
                                    width: 38
                                    height: 28
                                    label: "DND"
                                    labelPixelSize: 9
                                    active: notificationEntry.sharedAppState.dnd === true
                                    activeColor: Colors.orange

                                    onTriggered: {
                                        root.toggleAppFlag(notificationEntry.appKey, "dnd");
                                    }
                                }

                                MiniButton {
                                    width: 28
                                    height: 28
                                    label: "×"
                                    labelPixelSize: 17
                                    active: false

                                    onTriggered: {
                                        root.dismissNotification(notificationEntry.index);
                                    }
                                }
                            }

                            // ===== NOTIFICATION TITLE ============
                            GlowText {
                                id: notificationTitle
                                anchors {
                                    top: appIconBox.bottom
                                    left: parent.left
                                    right: parent.right
                                }
                                anchors.topMargin: 7
                                anchors.leftMargin: root.cardContentMargin + 8
                                anchors.rightMargin: root.cardContentMargin
                                height: 20
                                text: notificationEntry.title
                                pixelSize: root.notificationTitleFontSize
                                textColor: notificationEntry.notificationColor
                                glowColor: notificationEntry.notificationColor
                                elideMode: Text.ElideRight
                            }

                            // ===== MESSAGE =======================
                            GlowText {
                                anchors {
                                    top: notificationTitle.bottom
                                    left: parent.left
                                    right: parent.right
                                }
                                anchors.topMargin: 2
                                anchors.leftMargin: root.cardContentMargin + 8
                                anchors.rightMargin: root.cardContentMargin
                                height: 19
                                text: notificationEntry.message
                                pixelSize: root.notificationMessageFontSize
                                textColor: Colors.white
                                // White always glows cyan.
                                glowColor: Colors.cyan
                                elideMode: Text.ElideRight
                            }
                        }
                    }
                }

                // ===== CUSTOM SCROLL BAR ========================
                Item {
                    id: scrollBarArea
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right
                    }
                    width: root.scrollBarAreaWidth
                    visible: historyList.contentHeight > historyList.height + 1

                    function scrollTo(localY) {
                        var scrollable = Math.max(0, historyList.contentHeight - historyList.height);
                        if (scrollable <= 0)
                            return;

                        var available = Math.max(1, scrollTrack.height - scrollThumb.height);
                        var target = localY - (scrollThumb.height / 2);
                        var fraction = Math.max(0, Math.min(1, target / available));
                        historyList.contentY = fraction * scrollable;
                    }

                    Rectangle {
                        id: scrollTrack
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                        }
                        width: root.scrollTrackWidth
                        color: Colors.cyan
                        opacity: 0.45
                    }

                    Rectangle {
                        id: scrollThumb
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.scrollThumbWidth
                        height:
                            Math.max(
                                root.scrollThumbMinHeight,
                                scrollTrack.height
                                * Math.min(
                                    1,
                                    historyList.height
                                    / Math.max(1, historyList.contentHeight)
                                )
                            )
                        y: {
                            var scrollable = Math.max(0, historyList.contentHeight - historyList.height);
                            var available = Math.max(0, scrollTrack.height - scrollThumb.height);
                            if (scrollable <= 0)
                                return 0;
                            var fraction = Math.max(0, Math.min(1, historyList.contentY / scrollable));
                            return fraction * available;
                        }
                        color: Colors.magenta
                    }

                    DropShadow {
                        anchors.fill: scrollThumb
                        source: scrollThumb
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 12
                        samples: 21
                        color: Colors.magenta
                        opacity: 0.60
                        transparentBorder: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        onPressed: function (mouse) {
                            scrollBarArea.scrollTo(mouse.y);
                        }

                        onPositionChanged: function (mouse) {
                            if (pressed)
                                scrollBarArea.scrollTo(mouse.y);
                        }
                    }
                }
            }
        }
    }
}
