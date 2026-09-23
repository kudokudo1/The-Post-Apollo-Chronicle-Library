import QtQuick
import Quickshell
import "../components"
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: appControlWindow

    // ============================================================
    // STATE
    // ============================================================

    property bool menuOpen: false

    property int selectedModeIndex: 0
    property int selectedResultIndex: 0

    property bool keyboardActive: false
    property bool detailFocused: false

    // ============================================================
    // MODE DATA
    // ============================================================

    property var modes: [
        {
            name: "APPS",
            symbol: "-⋆♱⋆-"
        },
        {
            name: "RUN",
            symbol: ">_"
        },
        {
            name: "WINDOWS",
            symbol: "🃁🂡🂱🃑"
        },
        {
            name: "KILL",
            symbol: "( -_•)︻デ═一"
        }
    ]

    // Temporary Phase 1 placeholder content.
    property var placeholderResults: [
        {
            label: "OPTION 01"
        },
        {
            label: "OPTION 02"
        },
        {
            label: "OPTION 03"
        },
        {
            label: "OPTION 04"
        },
        {
            label: "OPTION 05"
        }
    ]

    // ============================================================
    // REAL APPLICATION MODEL
    // ============================================================

    ScriptModel {
        id: filteredApps

        values: {
            const query = searchInput.text.trim().toLowerCase();

            const apps = [...DesktopEntries.applications.values];

            const filtered = apps.filter(function(entry) {
                if (query.length === 0)
                    return true;

                const haystack = (
                    (entry.name || "") + " " +
                    (entry.genericName || "") + " " +
                    (entry.comment || "") + " " +
                    (entry.keywords || "")
                ).toLowerCase();

                return haystack.indexOf(query) !== -1;
            });

            filtered.sort(function(a, b) {
                return (a.name || "").localeCompare(b.name || "");
            });

            return filtered;
        }
    }

    function resultCount() {
        return selectedModeIndex === 0
            ? filteredApps.values.length
            : placeholderResults.length;
    }

    function selectedResult() {
        if (selectedResultIndex < 0 ||
            selectedResultIndex >= resultCount())
            return null;

        return selectedModeIndex === 0
            ? filteredApps.values[selectedResultIndex]
            : placeholderResults[selectedResultIndex];
    }

    function resetResultSelection() {
        selectedResultIndex = resultCount() > 0 ? 0 : -1;

        if (selectedResultIndex >= 0)
            resultList.positionViewAtIndex(
                selectedResultIndex,
                ListView.Beginning
            );
    }

    // ============================================================
    // WINDOW
    // ============================================================

    implicitWidth: 800
    implicitHeight: 650

    color: "transparent"

    surfaceFormat.opaque: false

    focusable: true
    visible: menuOpen

    // ============================================================
    // BACKGROUND
    // ============================================================

    Rectangle {
        id: background

        anchors.fill: parent

        color: Colors.black
        opacity: 0.96
    }

    // ============================================================
    // MODE RAIL
    // ============================================================

    Rectangle {
        id: modeRail

        width: 100

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        color: Colors.dark

        Column {
            id: modeColumn

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            anchors.topMargin: 20

            spacing: 8

            Repeater {
                model: appControlWindow.modes

                Rectangle {
                    id: modeButton

                    property bool isSelected: index === appControlWindow.selectedModeIndex

                    property bool isHovered: !appControlWindow.keyboardActive && modeMouse.containsMouse

                    property bool isPressed: modeMouse.pressed

                    width: parent.width
                    height: 55

                    color: modeButton.isPressed ? Colors.magenta : modeButton.isHovered ? Colors.yellow : modeButton.isSelected ? Colors.yellow : Colors.dark

                    Column {
                        anchors.centerIn: parent

                        spacing: 2

                        GohuText {
                            anchors.horizontalCenter: parent.horizontalCenter

                            text: modelData.symbol

                            font.pixelSize: 17

                            color: modeButton.isPressed ? Colors.black : modeButton.isHovered ? Colors.orange : modeButton.isSelected ? Colors.orange : Colors.cyan
                        }

                        GohuText {
                            anchors.horizontalCenter: parent.horizontalCenter

                            text: modelData.name

                            font.pixelSize: 11

                            color: modeButton.isPressed ? Colors.black : modeButton.isHovered ? Colors.orange : modeButton.isSelected ? Colors.orange : Colors.white
                        }
                    }

                    MouseArea {
                        id: modeMouse

                        anchors.fill: parent

                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                        }

                        onClicked: {
                            appControlWindow.selectedModeIndex = index;
                            appControlWindow.detailFocused = false;
                            appControlWindow.resetResultSelection();

                            searchInput.forceActiveFocus();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 3
                        z: -1

                        opacity: modeButton.isSelected || modeButton.isHovered ? 0.5 : 0.0

                        color: Colors.orange
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 10
                        z: 1

                        opacity: modeButton.isSelected || modeButton.isHovered ? 0.09 : 0.0

                        color: Colors.orange
                    }
                }
            }
        }
    }

    // ============================================================
    // SEARCH / RESULTS PANE
    // ============================================================

    Rectangle {
        id: resultsPane

        width: 310

        anchors.left: modeRail.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        color: Colors.black

        // ========================================================
        // SEARCH HEADER
        // ========================================================

        Rectangle {
            id: searchHeader

            width: parent.width
            height: 80

            anchors.top: parent.top

            color: Colors.dark

            Column {
                anchors.fill: parent

                anchors.leftMargin: 15
                anchors.rightMargin: 15
                anchors.topMargin: 12
                anchors.bottomMargin: 10

                spacing: 8

                GohuText {
                    text: appControlWindow.modes[appControlWindow.selectedModeIndex].name

                    font.pixelSize: 19

                    color: appControlWindow.selectedModeIndex === 3 ? Colors.red : Colors.cyan
                }

                TextInput {
                    id: searchInput

                    width: parent.width

                    font.family: "GohuFont 11 Nerd Font Mono"
                    font.pixelSize: 18

                    color: Colors.magenta

                    selectionColor: Colors.yellow
                    selectedTextColor: Colors.black

                    cursorVisible: activeFocus

                    clip: true

                    Keys.onPressed: function (event) {
                        appControlWindow.handleKey(event);
                    }

                    onTextChanged: {
                        if (appControlWindow.selectedModeIndex === 0)
                            appControlWindow.resetResultSelection();
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                height: 2

                color: appControlWindow.selectedModeIndex === 3 ? Colors.red : Colors.cyan
            }
        }

        // ========================================================
        // RESULTS
        // ========================================================

        ListView {
            id: resultList

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchHeader.bottom
            anchors.bottom: parent.bottom

            clip: true

            model: appControlWindow.selectedModeIndex === 0
                   ? filteredApps
                   : appControlWindow.placeholderResults

            currentIndex: appControlWindow.selectedResultIndex

            delegate: Rectangle {
                id: resultButton

                required property int index
                required property var modelData

                property bool isSelected: index === appControlWindow.selectedResultIndex

                property bool isHovered: !appControlWindow.keyboardActive && resultMouse.containsMouse

                property bool isPressed: resultMouse.pressed

                width: resultList.width
                height: 42

                color: resultButton.isPressed ? Colors.magenta : resultButton.isHovered ? Colors.yellow : resultButton.isSelected ? Colors.yellow : Colors.black

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14

                    spacing: 9

                    Image {
                        width: 22
                        height: 22

                        visible:
                            appControlWindow.selectedModeIndex === 0 &&
                            source.toString().length > 0

                        source:
                            appControlWindow.selectedModeIndex === 0
                            ? Quickshell.iconPath(modelData.icon, true)
                            : ""

                        fillMode: Image.PreserveAspectFit
                        smooth: false
                    }

                    GohuText {
                        anchors.verticalCenter: parent.verticalCenter

                        text:
                            appControlWindow.selectedModeIndex === 0
                            ? modelData.name
                            : modelData.label

                        font.pixelSize: 17

                        color: resultButton.isPressed ? Colors.black : resultButton.isHovered ? Colors.orange : resultButton.isSelected ? Colors.orange : Colors.cyan
                    }
                }

                MouseArea {
                    id: resultMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    onEntered: {
                        appControlWindow.keyboardActive = false;
                        appControlWindow.selectedResultIndex = index;
                    }

                    onClicked: {
                        appControlWindow.selectedResultIndex = index;
                        appControlWindow.activateSelectedResult();
                    }
                }

                RectangularShadow {
                    anchors.fill: parent

                    spread: 3
                    z: -1

                    opacity: resultButton.isSelected || resultButton.isHovered ? 0.45 : 0.0

                    color: appControlWindow.selectedModeIndex === 3 ? Colors.red : Colors.orange
                }
            }
        }
    }

    // ============================================================
    // DETAIL / CONTROL PANE
    // ============================================================

    Rectangle {
        id: detailPane

        anchors.left: resultsPane.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        color: Colors.black

        border.width: 1

        border.color: appControlWindow.detailFocused ? Colors.orange : Colors.cyan

        Column {
            anchors.fill: parent

            anchors.margins: 25

            spacing: 18

            GohuText {
                text: "APPLICATION CONTROL"

                font.pixelSize: 20

                color: Colors.cyan
            }

            Rectangle {
                width: parent.width
                height: 2

                color: Colors.cyan
            }

            GohuText {
                property var currentResult: appControlWindow.selectedResult()

                text:
                    currentResult
                    ? (appControlWindow.selectedModeIndex === 0
                       ? currentResult.name
                       : currentResult.label)
                    : "NO SELECTION"

                font.pixelSize: 22

                color: Colors.orange
            }

            GohuText {
                property var currentResult: appControlWindow.selectedResult()

                text:
                    appControlWindow.selectedModeIndex === 0 &&
                    currentResult
                    ? (currentResult.genericName || currentResult.comment || "APPLICATION")
                    : "Phase 1 placeholder"

                font.pixelSize: 15

                color: Colors.white

                opacity: 0.65
            }

            GohuText {
                property var currentResult: appControlWindow.selectedResult()

                width: parent.width

                text:
                    appControlWindow.selectedModeIndex === 0 &&
                    currentResult
                    ? currentResult.comment
                    : ""

                visible: text.length > 0

                wrapMode: Text.Wrap

                font.pixelSize: 14

                color: Colors.white

                opacity: 0.5
            }

            GohuText {
                text: appControlWindow.detailFocused ? "DETAIL MODE ACTIVE" : "RIGHT → DETAILS"

                font.pixelSize: 15

                color: appControlWindow.detailFocused ? Colors.orange : Colors.cyan
            }
        }
    }

    // ============================================================
    // KEYBOARD
    // ============================================================

    function handleKey(event) {
        keyboardActive = true;

        if (event.key === Qt.Key_Escape) {
            if (detailFocused) {
                detailFocused = false;
            } else {
                menuOpen = false;
            }

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Tab) {
            if (event.modifiers & Qt.ShiftModifier) {
                selectedModeIndex--;

                if (selectedModeIndex < 0)
                    selectedModeIndex = modes.length - 1;
            } else {
                selectedModeIndex++;

                if (selectedModeIndex >= modes.length)
                    selectedModeIndex = 0;
            }

            detailFocused = false;
            resetResultSelection();

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Up) {
            const count = resultCount();

            if (count === 0)
                return;

            selectedResultIndex--;

            if (selectedResultIndex < 0)
                selectedResultIndex = count - 1;

            resultList.positionViewAtIndex(selectedResultIndex, ListView.Contain);

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Down) {
            const count = resultCount();

            if (count === 0)
                return;

            selectedResultIndex++;

            if (selectedResultIndex >= count)
                selectedResultIndex = 0;

            resultList.positionViewAtIndex(selectedResultIndex, ListView.Contain);

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Right) {
            detailFocused = true;

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Left) {
            if (detailFocused) {
                detailFocused = false;
                searchInput.forceActiveFocus();
            }

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activateSelectedResult();

            event.accepted = true;
            return;
        }
    }

    // ============================================================
    // PLACEHOLDER ACTIVATION
    // ============================================================

    function activateSelectedResult() {
        const result = selectedResult();

        if (!result)
            return;

        if (selectedModeIndex === 0) {
            console.log("AppControl: launching", result.name);
            result.execute();
            menuOpen = false;
            return;
        }

        console.log(
            "AppControl:",
            modes[selectedModeIndex].name,
            result.label
        );
    }

    // ============================================================
    // OPEN / FOCUS
    // ============================================================

    onMenuOpenChanged: {
        if (menuOpen) {
            detailFocused = false;
            keyboardActive = false;
            resetResultSelection();

            searchInput.forceActiveFocus();
        }
    }
}
