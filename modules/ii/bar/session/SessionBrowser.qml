pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtWebEngine
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services.chris

// One-time login browser. Shows a key icon in the bar.
// Click → popup with claude.ai/login opens.
// After logging in with Email+Password (NOT Google SSO!), close the popup.
// Cookies are persisted in the shared profile → all widgets share the session.
//
// You can disable this widget via config after the initial login:
//   Config.options.bar.sessionBrowser.enable = false
Item {
    id: root
    implicitWidth: keyIcon.implicitWidth + 8
    implicitHeight: Appearance.sizes.barHeight

    property bool popupVisible: false

    MaterialSymbol {
        id: keyIcon
        anchors.centerIn: parent
        text: "key"
        iconSize: Appearance.font.pixelSize.large
        color: Appearance.colors.colOnLayer1

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupVisible = !root.popupVisible
        }
    }

    // Login popup — only created when needed
    Loader {
        id: popupLoader
        active: root.popupVisible

        sourceComponent: PopupWindow {
            id: loginPopup
            visible: root.popupVisible
            width: 900
            height: 650

            anchor {
                window: root.QsWindow.window
                rect: Qt.rect(0, Appearance.sizes.barHeight, width, height)
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colLayer0

                WebEngineView {
                    anchors.fill: parent
                    profile: BarBrowser.sharedProfile
                    url: "https://claude.ai/login"
                }

                // Close button
                MaterialSymbol {
                    text: "close"
                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: 8
                    }
                    color: Appearance.colors.colOnLayer1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.popupVisible = false
                    }
                }
            }
        }
    }
}
