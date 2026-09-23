import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../components"
import "../../services/messaging"
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: messagingWindow

    // ============================================================
    // WAYLAND STACKING
    // ============================================================

    WlrLayershell.layer: WlrLayer.Overlay

    // ============================================================
    // BACKEND
    // ============================================================

    SessionAdapter {
        id: sessionAdapter
    }

    Process {
        id: discordShowProcess
    }

    Process {
        id: discordHideProcess

        command: ["swaymsg", "[app_id=\"vesktop\"] move scratchpad"]
    }

    Process {
        id: discordSnapProcess
    }

    Timer {
        id: discordSnapDelay

        interval: 180
        repeat: false

        onTriggered: {
            messagingWindow.syncDiscordGeometry();
        }
    }

    function syncDiscordGeometry() {
        if (!menuOpen || !discordSelected)
            return;

        // Vesktop is already a scratchpad/floating window.
        // Do NOT run "floating enable": Sway rejects it while the
        // scratchpad container is hidden.
        discordSnapProcess.exec([
            "bash",
            "-lc",
            "swaymsg '[app_id=\"vesktop\"] border none'; " +
            "swaymsg '[app_id=\"vesktop\"] resize set width "
                + messagingWindow.discordWidth
                + " px height "
                + messagingWindow.discordHeight
                + " px'; " +
            "swaymsg '[app_id=\"vesktop\"] move absolute position "
                + messagingWindow.discordX
                + " px "
                + messagingWindow.discordY
                + " px'; " +
            "swaymsg '[app_id=\"vesktop\"] focus'"
        ]);
    }

    function showDiscord() {
        if (!menuOpen || !discordSelected)
            return;

        if (discordHideProcess.running)
            discordHideProcess.running = false;

        if (discordShowProcess.running)
            discordShowProcess.running = false;

        // First make sure Vesktop exists. If it already exists, move it
        // to the scratchpad first so "scratchpad show" has a known state.
        // Then show it. Geometry is applied by discordSnapDelay only
        // after Sway has had time to map the visible scratchpad window.
        discordShowProcess.exec([
            "bash",
            "-lc",
            "if ! swaymsg -t get_tree | grep -q '\"app_id\": \"vesktop\"'; then " +
                "setsid -f flatpak run dev.vencord.Vesktop >/dev/null 2>&1; " +
                "for i in $(seq 1 100); do " +
                    "swaymsg -t get_tree | grep -q '\"app_id\": \"vesktop\"' && break; " +
                    "sleep 0.1; " +
                "done; " +
            "fi; " +
            "swaymsg '[app_id=\"vesktop\"] move scratchpad'; " +
            "swaymsg '[app_id=\"vesktop\"] scratchpad show'"
        ]);

        discordSnapDelay.restart();
    }

    function hideDiscord() {
        discordSnapDelay.stop();

        if (discordShowProcess.running)
            discordShowProcess.running = false;

        if (discordSnapProcess.running)
            discordSnapProcess.running = false;

        if (discordHideProcess.running)
            discordHideProcess.running = false;

        discordHideProcess.running = true;
    }

    // ============================================================
    // WINDOW STATE
    // ============================================================

    property bool menuOpen: false

    property int focusZone: 0

    readonly property int appZone: 0
    readonly property int contactZone: 1
    readonly property int chatZone: 2

    // selectedIndex is only the selector highlight / keyboard cursor.
    // activeAppIndex is the app that is actually open.
    property int activeAppIndex: 0

    readonly property bool discordSelected: activeAppIndex === 1

    // ============================================================
    // GEOMETRY
    // ============================================================

    implicitWidth: 1210
    implicitHeight: 1355

    // ============================================================
    // POSITION
    // ============================================================

    anchors {
        top: false
        bottom: true
        right: true
        left: false
    }

    margins {
        top: 0
        bottom: 80
        right: 10
        left: 0
    }

    exclusiveZone: 0

    color: "transparent"
    surfaceFormat.opaque: false

    // ============================================================
    // CRASH WORKAROUND
    //
    // Keep the PanelWindow alive permanently.
    // Do NOT change this back to visible: menuOpen.
    // ============================================================

    visible: true

    focusable: menuOpen && !discordSelected

    mask: Region {
        x: 0
        y: 0

        width: messagingWindow.menuOpen
            ? (messagingWindow.discordSelected
                ? messagingWindow.appSelectorWidth
                : messagingWindow.width)
            : 0

        height: messagingWindow.menuOpen
            ? messagingWindow.height
            : 0
    }

    // ============================================================
    // COLUMN WIDTHS
    // ============================================================

    property int appSelectorWidth: 110
    property int contactListWidth: 200

    // ============================================================
    // DISCORD GEOMETRY
    // ============================================================

    // The invisible Discord slot represents the exact area to the
    // right of AppSelector.
    property int discordGap: 0

    // Global top-left of MessagingW.
    // shell.qml owns this window's screen position.
    // Read the active PanelWindow anchors/margins instead of assuming
    // the component's fallback bottom/right placement.
    readonly property int panelGlobalX:
        messagingWindow.screen
        ? (messagingWindow.anchors.right
            ? messagingWindow.screen.x
              + messagingWindow.screen.width
              - messagingWindow.margins.right
              - messagingWindow.width
            : messagingWindow.screen.x
              + messagingWindow.margins.left)
        : 0

    readonly property int panelGlobalY:
        messagingWindow.screen
        ? (messagingWindow.anchors.top
            ? messagingWindow.screen.y
              + messagingWindow.margins.top
            : messagingWindow.screen.y
              + messagingWindow.screen.height
              - messagingWindow.margins.bottom
              - messagingWindow.height)
        : 0

    // Translate the local Discord slot into Sway coordinates.
    readonly property int discordX:
        Math.round(
            messagingWindow.panelGlobalX
            + discordSlot.x
        )

    readonly property int discordY:
        Math.round(
            messagingWindow.panelGlobalY
            + discordSlot.y
        )

    readonly property int discordWidth:
        Math.max(
            1,
            Math.round(discordSlot.width)
        )

    readonly property int discordHeight:
        Math.max(
            1,
            Math.round(discordSlot.height)
        )

    onDiscordXChanged:
        Qt.callLater(syncDiscordGeometry)

    onDiscordYChanged:
        Qt.callLater(syncDiscordGeometry)

    onDiscordWidthChanged:
        Qt.callLater(syncDiscordGeometry)

    onDiscordHeightChanged:
        Qt.callLater(syncDiscordGeometry)

    // ============================================================
    // HELPERS
    // ============================================================

    function focusAppSelector() {
        focusZone = appZone;

        appSelector.keyboardActive = true;

        keyboardFocus.forceActiveFocus();
    }

    function focusContacts() {
        if (contactList.conversations.length === 0)
            return;

        focusZone = contactZone;

        contactList.keyboardActive = true;

        contactList.ensureValidIndex();

        keyboardFocus.forceActiveFocus();
    }

    function focusComposer() {
        if (!contactList.selectedConversation)
            return;

        focusZone = chatZone;

        chatFeed.focusMessageInput();
    }

    function activateApp(index) {
        activeAppIndex = index;
        contactList.clearSelection();

        if (index === 1) {
            showDiscord();
            return;
        }

        hideDiscord();

        if (index === 0 && contactList.conversations.length > 0)
            focusContacts();
    }

    function acceptSelectedApp() {
        activateApp(appSelector.selectedIndex);
    }

    function activateCurrentContact() {
        if (!contactList.activateCurrent())
            return;

        focusComposer();
    }

    function returnToContacts() {
        if (contactList.conversations.length === 0) {
            focusAppSelector();
            return;
        }

        focusZone = contactZone;

        contactList.keyboardActive = true;

        contactList.ensureValidIndex();

        keyboardFocus.forceActiveFocus();
    }

    // ============================================================
    // DISCORD SLOT
    // ============================================================

    // This is NOT visible.
    //
    // It behaves like a normal QML panel occupying everything
    // immediately to the right of AppSelector.
    //
    // IMPORTANT:
    // It is outside messagingContent so it does not collapse when
    // messagingContent becomes only 110 px wide for Discord mode.
    Item {
        id: discordSlot

        x:
            messagingWindow.appSelectorWidth
            + messagingWindow.discordGap

        y: 0

        width:
            Math.max(
                1,
                messagingWindow.width - x
            )

        height:
            messagingWindow.height

        visible: false
    }

    // ============================================================
    // VISUAL CONTENT
    // ============================================================

    Item {
        id: messagingContent

        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }

        width:
            messagingWindow.discordSelected
            ? messagingWindow.appSelectorWidth
            : parent.width

        visible: messagingWindow.menuOpen

        // ========================================================
        // BACKGROUND
        // ========================================================

        Rectangle {
            id: messagingBackground

            anchors.fill: parent

            color: Colors.black
            opacity: 0.20

            radius: 0

            z: -100
        }

        // ========================================================
        // KEYBOARD CONTROLLER
        // ========================================================

        Item {
            id: keyboardFocus

            anchors.fill: parent

            focus:
                messagingWindow.menuOpen
                && messagingWindow.focusZone !== messagingWindow.chatZone

            z: 0

            Keys.onPressed: function (event) {
                if (!messagingWindow.menuOpen)
                    return;

                // ================================================
                // APP SELECTOR
                // ================================================

                if (messagingWindow.focusZone === messagingWindow.appZone) {
                    if (event.key === Qt.Key_Up) {
                        appSelector.keyboardActive = true;

                        if (appSelector.selectedIndex > 0) {
                            appSelector.selectedIndex--;
                        } else {
                            appSelector.selectedIndex =
                                appSelector.messagingApps.length - 1;
                        }

                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Down) {
                        appSelector.keyboardActive = true;

                        if (
                            appSelector.selectedIndex
                            < appSelector.messagingApps.length - 1
                        ) {
                            appSelector.selectedIndex++;
                        } else {
                            appSelector.selectedIndex = 0;
                        }

                        event.accepted = true;
                        return;
                    }

                    if (
                        event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter
                    ) {
                        messagingWindow.acceptSelectedApp();

                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Right) {
                        messagingWindow.acceptSelectedApp();

                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Escape) {
                        messagingWindow.menuOpen = false;

                        event.accepted = true;
                        return;
                    }
                }

                // ================================================
                // CONTACT LIST
                // ================================================

                if (
                    messagingWindow.focusZone
                    === messagingWindow.contactZone
                ) {
                    if (event.key === Qt.Key_Up) {
                        contactList.keyboardActive = true;

                        contactList.moveSelection(-1);

                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Down) {
                        contactList.keyboardActive = true;

                        contactList.moveSelection(1);

                        event.accepted = true;
                        return;
                    }

                    if (
                        event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter
                    ) {
                        messagingWindow.activateCurrentContact();

                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Right) {
                        messagingWindow.activateCurrentContact();

                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Left) {
                        messagingWindow.focusAppSelector();

                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Escape) {
                        messagingWindow.focusAppSelector();

                        event.accepted = true;
                        return;
                    }
                }
            }
        }

        // ========================================================
        // APP SELECTOR
        // ========================================================

        AppSelector {
            id: appSelector

            width: messagingWindow.appSelectorWidth
            height: parent.height

            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }

            z: 3

            onSelectedIndexChanged: {
                // Hover / keyboard movement only changes the highlight.
                if (
                    messagingWindow.focusZone
                    === messagingWindow.appZone
                    && !messagingWindow.discordSelected
                ) {
                    keyboardFocus.forceActiveFocus();
                }
            }

            // The AppSelector's OWN MouseArea emits this only
            // on a real click.
            onAppActivated: function (index) {
                messagingWindow.activateApp(index);
            }
        }

        // ========================================================
        // CONTACT LIST
        // ========================================================

        ContactList {
            id: contactList

            width: messagingWindow.contactListWidth
            height: parent.height

            visible: !messagingWindow.discordSelected

            anchors {
                left: appSelector.right
                top: parent.top
                bottom: parent.bottom
            }

            z: 2

            keyboardFocused:
                messagingWindow.focusZone
                === messagingWindow.contactZone

            // ----------------------------------------------------
            // ACTIVE BACKEND CONTACTS
            // ----------------------------------------------------

            conversations:
                messagingWindow.activeAppIndex === 0
                ? sessionAdapter.conversations
                : []

            // ----------------------------------------------------
            // CONVERSATION CHANGE
            // ----------------------------------------------------

            onSelectedConversationChanged: {
                if (
                    messagingWindow.activeAppIndex === 0
                    && selectedConversation
                ) {
                    sessionAdapter.loadMessages(
                        selectedConversation.id
                    );
                }
            }

            // ----------------------------------------------------
            // MOUSE CLICK
            // ----------------------------------------------------

            onContactClicked: {
                messagingWindow.focusZone =
                    messagingWindow.contactZone;

                contactList.keyboardActive = false;

                keyboardFocus.forceActiveFocus();
            }
        }

        // ========================================================
        // CHAT FEED
        // ========================================================

        ChatFeed {
            id: chatFeed

            visible: !messagingWindow.discordSelected

            anchors {
                left: contactList.right
                top: parent.top
                right: parent.right
                bottom: parent.bottom
            }

            z: 1

            // ----------------------------------------------------
            // ACTIVE CONVERSATION
            // ----------------------------------------------------

            conversation:
                messagingWindow.activeAppIndex === 0
                ? contactList.selectedConversation
                : null

            // ----------------------------------------------------
            // MESSAGES
            // ----------------------------------------------------

            messages:
                messagingWindow.activeAppIndex === 0
                ? sessionAdapter.messages
                : []

            // ----------------------------------------------------
            // LOADING
            // ----------------------------------------------------

            loading:
                messagingWindow.activeAppIndex === 0
                ? sessionAdapter.messagesLoading
                : false

            // ----------------------------------------------------
            // LOAD ERROR
            // ----------------------------------------------------

            error:
                messagingWindow.activeAppIndex === 0
                ? sessionAdapter.messagesError
                : ""

            // ----------------------------------------------------
            // SENDING
            // ----------------------------------------------------

            sending:
                messagingWindow.activeAppIndex === 0
                ? sessionAdapter.sending
                : false

            // ----------------------------------------------------
            // SEND ERROR
            // ----------------------------------------------------

            sendError:
                messagingWindow.activeAppIndex === 0
                ? sessionAdapter.sendError
                : ""

            // ----------------------------------------------------
            // SEND SUCCESS
            // ----------------------------------------------------

            sendSuccessSerial:
                messagingWindow.activeAppIndex === 0
                ? sessionAdapter.sendSuccessSerial
                : 0

            // ----------------------------------------------------
            // SEND MESSAGE
            // ----------------------------------------------------

            onSendRequested: function (
                conversationId,
                text
            ) {
                if (messagingWindow.activeAppIndex === 0) {
                    sessionAdapter.sendMessage(
                        conversationId,
                        text
                    );
                }
            }

            // ----------------------------------------------------
            // LEFT / ESCAPE FROM CHAT
            // ----------------------------------------------------

            onComposerEscapeRequested: {
                messagingWindow.returnToContacts();
            }
        }
    }

    // ============================================================
    // OPEN / CLOSE
    // ============================================================

    onMenuOpenChanged: {
        if (menuOpen) {
            // The BAR Sessions button opens the menu on Sessions.
            activeAppIndex = 0;
            appSelector.selectedIndex = 0;

            messagingWindow.hideDiscord();

            focusZone = appZone;
            appSelector.keyboardActive = true;

            Qt.callLater(function () {
                keyboardFocus.forceActiveFocus();
            });
        } else {
            messagingWindow.hideDiscord();

            activeAppIndex = 0;
            focusZone = appZone;
            keyboardFocus.focus = false;
        }
    }
}
