pragma Singleton
import QtQuick
import QtWebEngine
import Quickshell

Singleton {
    id: root

    // Shared persistent profile — all widgets use this
    // Storage path: ~/.local/share/quickshell/hyprbar_sessions/
    property WebEngineProfile sharedProfile: WebEngineProfile {
        storageName: "hyprbar_sessions"
        persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
    }
}
