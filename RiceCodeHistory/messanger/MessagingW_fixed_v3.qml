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

        command: ["bash", "-lc", "if ! swaymsg -t get_tree | grep -q '\"app_id\": \"vesktop\"'; then " + "setsid -f flatpak run dev.vencord.Vesktop >/dev/null 2>&1; " + "for i in $(seq 1 100); do " + "swaymsg -t get_tree | grep -q '\"app_id\": \"vesktop\"' && break; " + "sleep 0.1; " + "done; " + "fi; " + "swaymsg '[app_id=\"vesktop\"] move workspace current'; " + "swaymsg '[app_id=\"vesktop\"] floating enable'; " + "swaymsg '[app_id=\"vesktop\"] border none'; " + "swaymsg '[app_id=\"vesktop\"] resize set width 1100 px height 1355 px'; " + "swaymsg '[app_id=\"vesktop\"] move absolute position 1450 px 5 px'; " + "swaymsg '[app_id=\"vesktop\"] focus'"]
    }

    Process {
        id: discordHideProcess

        command: ["swaymsg", "[app_id=\"vesktop\"] move scratchpad"]
    }

    function showDiscord() {
        if (!menuOpen || !discordSelected)
            return;

        if (discordHideProcess.running)
            discordHideProcess.running = false;

        if (discordShowProcess.running)
            discordShowProcess.running = false;

        discordShowProcess.running = true;
    }

    function hideDiscord() {
        if (discordShowProcess.running)
            discordShowProcess.running = false;

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

    readonly property bool discordSelected: appSelector.selectedIndex === 1

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

        width: messagingWindow.menuOpen ? (messagingWindow.discordSelected ? messagingWindow.appSelectorWidth : messagingWindow.width) : 0

        height: messagingWindow.menuOpen ? messagingWindow.height : 0
    }

    // ============================================================
    // COLUMN WIDTHS
    // ============================================================

    property int appSelectorWidth: 110
    property int contactListWidth: 200

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

    function acceptSelectedApp() {
        if (contactList.conversations.length > 0) {
            focusContacts();
        }
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
    // VISUAL CONTENT
    // ============================================================

    Item {
        id: messagingContent

        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }

        width: messagingWindow.discordSelected ? messagingWindow.appSelectorWidth : parent.width

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

            focus: messagingWindow.menuOpen && messagingWindow.focusZone !== messagingWindow.chatZone

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
                            appSelector.selectedIndex = appSelector.messagingApps.length - 1;
                        }

                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Down) {
                        appSelector.keyboardActive = true;

                        if (appSelector.selectedIndex < appSelector.messagingApps.length - 1) {
                            appSelector.selectedIndex++;
                        } else {
                            appSelector.selectedIndex = 0;
                        }

                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
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

                if (messagingWindow.focusZone === messagingWindow.contactZone) {
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

                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
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
                contactList.clearSelection();

                if (messagingWindow.menuOpen) {
                    if (messagingWindow.discordSelected)
                        messagingWindow.showDiscord();
                    else
                        messagingWindow.hideDiscord();
                }

                if (messagingWindow.focusZone === messagingWindow.appZone && !messagingWindow.discordSelected) {
                    keyboardFocus.forceActiveFocus();
                }
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

            keyboardFocused: messagingWindow.focusZone === messagingWindow.contactZone

            // ----------------------------------------------------
            // ACTIVE BACKEND CONTACTS
            // ----------------------------------------------------

            conversations: appSelector.selectedIndex === 0 ? sessionAdapter.conversations : []

            // ----------------------------------------------------
            // CONVERSATION CHANGE
            // ----------------------------------------------------

            onSelectedConversationChanged: {
                if (appSelector.selectedIndex === 0 && selectedConversation) {
                    sessionAdapter.loadMessages(selectedConversation.id);
                }
            }

            // ----------------------------------------------------
            // MOUSE CLICK
            // ----------------------------------------------------

            onContactClicked: {
                messagingWindow.focusZone = messagingWindow.contactZone;

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

            conversation: appSelector.selectedIndex === 0 ? contactList.selectedConversation : null

            // ----------------------------------------------------
            // MESSAGES
            // ----------------------------------------------------

            messages: appSelector.selectedIndex === 0 ? sessionAdapter.messages : []

            // ----------------------------------------------------
            // LOADING
            // ----------------------------------------------------

            loading: appSelector.selectedIndex === 0 ? sessionAdapter.messagesLoading : false

            // ----------------------------------------------------
            // LOAD ERROR
            // ----------------------------------------------------

            error: appSelector.selectedIndex === 0 ? sessionAdapter.messagesError : ""

            // ----------------------------------------------------
            // SENDING
            // ----------------------------------------------------

            sending: appSelector.selectedIndex === 0 ? sessionAdapter.sending : false

            // ----------------------------------------------------
            // SEND ERROR
            // ----------------------------------------------------

            sendError: appSelector.selectedIndex === 0 ? sessionAdapter.sendError : ""

            // ----------------------------------------------------
            // SEND SUCCESS
            // ----------------------------------------------------

            sendSuccessSerial: appSelector.selectedIndex === 0 ? sessionAdapter.sendSuccessSerial : 0

            // ----------------------------------------------------
            // SEND MESSAGE
            // ----------------------------------------------------

            onSendRequested: function (conversationId, text) {
                if (appSelector.selectedIndex === 0) {
                    sessionAdapter.sendMessage(conversationId, text);
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
            // The BAR Sessions button only opens the messaging window.
            // Always start on the Sessions page; do not restore Discord here.
            if (appSelector.selectedIndex !== 0)
                appSelector.selectedIndex = 0;

            messagingWindow.hideDiscord();

            focusZone = appZone;
            appSelector.keyboardActive = true;

            Qt.callLater(function () {
                keyboardFocus.forceActiveFocus();
            });
        } else {
            messagingWindow.hideDiscord();

            focusZone = appZone;
            keyboardFocus.focus = false;
        }
    }
}
