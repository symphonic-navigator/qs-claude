pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services.chris

// Bar icon for the Claude Usage widget.
// Hover → shows ClaudeUsagePopup with the usage page.
// Once the popup has loaded data, the percentages appear next to the icon.
MouseArea {
    id: root
    implicitWidth: rowLayout.implicitWidth + 10 * 2
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: true

    property bool popupVisible: false

    onEntered: {
        root.popupVisible = true
        hideTimer.stop()
    }

    onExited: {
        // Small delay so the mouse can travel into the popup without it closing
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 300
        onTriggered: {
            if (!usagePopup.containsMouse)
                root.popupVisible = false
        }
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 6

        MaterialSymbol {
            text: "smart_toy"
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnLayer1
        }

        // Shows percentages once data has been loaded at least once.
        // Max plan: shows all model usages (e.g. "Sonnet 33% · Opus 17%")
        // Pro plan: shows "session / weekly" (e.g. "33% / 17%")
        StyledText {
            visible: text !== ""
            text: {
                if (ClaudeUsage.modelUsages.length > 0) {
                    return ClaudeUsage.modelUsages.join(" · ")
                } else if (ClaudeUsage.sessionPct !== "") {
                    return ClaudeUsage.sessionPct + " / " + ClaudeUsage.weeklyPct
                }
                return ""
            }
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
        }
    }

    ClaudeUsagePopup {
        id: usagePopup
        barVisible: root.popupVisible
        hoverTarget: root

        onContainsMouseChanged: {
            if (!usagePopup.containsMouse && !root.containsMouse)
                root.popupVisible = false
        }
    }
}
