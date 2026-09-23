# Quickshell Power Menu — Updated

This is the current working version of the Quickshell power menu.

```qml
import Quickshell
import QtQuick
import Quickshell.Io
import "components"
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    property bool menuOpen: false
    property bool confirmShutdown: false
    property bool confirmReboot: false
    property int clickCount: 0
    property int pressCount: 0

    Process {
        id: lockProcess
        command: ["swaylock"]
    }

    Process {
        id: logoutProcess
        command: ["swaymsg", "exit"]
    }

    Process {
        id: rebootProcess
        command: ["systemctl", "reboot"]
    }

    Process {
        id: shutdownProcess
        command: ["systemctl", "poweroff"]
    }

    anchors {
        top: false
        bottom: true
        right: true
        left: false
    }

    margins {
        top: 00
        bottom: 10
        right: 10
        left: 00
    }

    implicitWidth: 220
    implicitHeight: 290

    color: "transparent"

    Item {
        id: powerArea
        width: 220
        height: 290
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Rectangle {
            id: powerButton
            radius: width / 100
            width: 50
            height: 50
            z: 1
            x: 155
            y: 230

            color: powerMouse.pressed ? Colors.magenta
                 : powerMouse.containsMouse ? Colors.black
                 : Colors.black

            Text {
                anchors.centerIn: parent
                text: "⏻"
                font.pixelSize: 35
                color: powerMouse.pressed ? Colors.cyan
                     : powerMouse.containsMouse ? Colors.cyan
                     : Colors.white
            }

            MouseArea {
                id: powerMouse
                width: parent.width
                height: parent.height
                hoverEnabled: true

                onEntered: console.log("Mouse entered button")
                onExited: console.log("Mouse left button")

                onPressed: pressCount++

                onClicked: {
                    clickCount++
                    menuOpen = !menuOpen
                    console.log("Menu open:", menuOpen)
                }
            }
        }

        DropShadow {
            source: powerButton
            anchors.centerIn: powerButton
            width: powerButton.width
            height: powerButton.height
            opacity: 0.3
            horizontalOffset: 0
            verticalOffset: 0
            radius: 19
            samples: 17
            z: 1
            color: Colors.cyan
            transparentBorder: true
        }

        RectangularShadow {
            anchors.fill: powerButton
            width: powerButton.width
            height: powerButton.height
            opacity: 0.5
            spread: 1
            z: -1
            color: Colors.cyan
        }
    }

    Rectangle {
        id: powerMenu
        width: 150
        height: 200
        z: 1
        color: Colors.black
        x: 35
        y: 20
        visible: menuOpen

        Column {
            id: menuItems
            width: parent.width

            // Hide the normal menu while either confirmation screen is active.
            visible: !confirmShutdown && !confirmReboot

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 15
            spacing: 7

            Text {
                text: "POWER MENU"
                color: Colors.cyan
                font.pixelSize: 20
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: parent.width - 20
                height: 2
                color: Colors.cyan
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                id: lockButton
                width: parent.width
                height: 30
                color: lockMouse.pressed ? Colors.magenta
                     : lockMouse.containsMouse ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Lock"
                    anchors.centerIn: parent
                    color: lockMouse.pressed ? Colors.black
                         : lockMouse.containsMouse ? Colors.orange
                         : Colors.cyan
                    font.pixelSize: 20
                }

                MouseArea {
                    id: lockMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Lock clicked!")
                        menuOpen = false
                        lockProcess.running = true
                    }
                }
            }

            Rectangle {
                id: logoutButton
                width: parent.width
                height: 30
                color: logoutMouse.pressed ? Colors.magenta
                     : logoutMouse.containsMouse ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Logout"
                    anchors.centerIn: parent
                    color: logoutMouse.pressed ? Colors.black
                         : logoutMouse.containsMouse ? Colors.orange
                         : Colors.cyan
                    font.pixelSize: 20
                }

                MouseArea {
                    id: logoutMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Logout clicked!")
                        logoutProcess.running = true
                    }
                }
            }

            Rectangle {
                id: rebootButton
                width: parent.width
                height: 30
                color: rebootMouse.pressed ? Colors.magenta
                     : rebootMouse.containsMouse ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Reboot"
                    anchors.centerIn: parent
                    color: rebootMouse.pressed ? Colors.black
                         : rebootMouse.containsMouse ? Colors.orange
                         : Colors.cyan
                    font.pixelSize: 20
                }

                MouseArea {
                    id: rebootMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Reboot clicked!")
                        confirmReboot = true
                    }
                }
            }

            Rectangle {
                id: shutdownButton
                width: parent.width
                height: 30
                color: shutdownMouse.pressed ? Colors.red
                     : shutdownMouse.containsMouse ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Shutdown"
                    anchors.centerIn: parent
                    color: shutdownMouse.pressed ? Colors.black
                         : shutdownMouse.containsMouse ? Colors.orange
                         : Colors.cyan
                    font.pixelSize: 20
                }

                MouseArea {
                    id: shutdownMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Shutdown clicked!")
                        confirmShutdown = true
                    }
                }
            }
        }

        DropShadow {
            id: powerMenuGlow
            source: powerMenu
            anchors.fill: powerMenu
            width: powerMenu.width
            height: powerMenu.height
            horizontalOffset: 0
            verticalOffset: 0
            radius: 15
            samples: 41
            z: -1
            color: Colors.cyan
            visible: menuOpen
            opacity: menuOpen ? 0.5 : 0
            transparentBorder: true
        }

        RectangularShadow {
            anchors.centerIn: powerMenu
            width: powerMenu.width
            height: powerMenu.height
            spread: 3
            z: -3
            visible: menuOpen
            opacity: menuOpen ? 0.7 : 0
            color: Colors.cyan
        }
    }

    Column {
        id: shutdownConfirm
        width: parent.width
        visible: confirmShutdown
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 25
        spacing: 20

        Text {
            text: "SHUTDOWN?"
            color: Colors.red
            font.pixelSize: 22
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            id: cancelshutdownButton
            width: parent.width
            height: 30
            color: cancelshutdownMouse.pressed ? Colors.magenta
                 : cancelshutdownMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "Cancel"
                color: cancelshutdownMouse.pressed ? Colors.black
                     : cancelshutdownMouse.containsMouse ? Colors.orange
                     : Colors.cyan
                font.pixelSize: 22
                anchors.centerIn: parent

                MouseArea {
                    id: cancelshutdownMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Shutdown cancelled!")
                        confirmShutdown = false
                    }
                }
            }
        }

        Rectangle {
            id: confirmshutdownButton
            width: parent.width
            height: 30
            color: confirmshutdownMouse.pressed ? Colors.red
                 : confirmshutdownMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "CONFIRM!"
                color: confirmshutdownMouse.pressed ? Colors.black
                     : confirmshutdownMouse.containsMouse ? Colors.orange
                     : Colors.cyan
                font.pixelSize: 20
                anchors.centerIn: parent

                MouseArea {
                    id: confirmshutdownMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Shutdown confirmed!")
                        shutdownProcess.running = true
                    }
                }
            }
        }
    }

    Column {
        id: rebootConfirm
        width: parent.width
        visible: confirmReboot
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 25
        spacing: 20

        Text {
            text: "REBOOT?"
            color: Colors.red
            font.pixelSize: 22
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            id: cancelrebootButton
            width: parent.width
            height: 30
            color: cancelrebootMouse.pressed ? Colors.magenta
                 : cancelrebootMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "Cancel"
                color: cancelrebootMouse.pressed ? Colors.black
                     : cancelrebootMouse.containsMouse ? Colors.orange
                     : Colors.cyan
                font.pixelSize: 22
                anchors.centerIn: parent

                MouseArea {
                    id: cancelrebootMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Reboot cancelled!")
                        confirmReboot = false
                    }
                }
            }
        }

        Rectangle {
            id: confirmrebootButton
            width: parent.width
            height: 30
            color: confirmrebootMouse.pressed ? Colors.red
                 : confirmrebootMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "CONFIRM!"
                color: confirmrebootMouse.pressed ? Colors.black
                     : confirmrebootMouse.containsMouse ? Colors.orange
                     : Colors.cyan
                font.pixelSize: 20
                anchors.centerIn: parent

                MouseArea {
                    id: confirmrebootMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Reboot confirmed!")
                        rebootProcess.running = true
                    }
                }
            }
        }
    }
}
```

## Current behavior

- Power button is independently positioned at `x: 155, y: 230`.
- Power menu is independently positioned at `x: 35, y: 20`.
- Clicking the power button toggles `menuOpen`.
- Lock closes the menu and runs `swaylock`.
- Logout runs `swaymsg exit`.
- Reboot opens the reboot confirmation screen.
- Shutdown opens the shutdown confirmation screen.
- Cancel buttons return to the normal menu.
- Confirmation buttons run the corresponding `systemctl` command.
- The normal menu correctly hides while either confirmation screen is active.
- The menu and power button retain their cyan glow effects.

## Important correction

The normal menu visibility must use the exact property name:

```qml
visible: !confirmShutdown && !confirmReboot
```

Do **not** use:

```qml
visible: !confirmShutdown && !confrimReboot
```

`confrimReboot` is a typo; the declared property is `confirmReboot`.
