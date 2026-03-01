pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Last time the page was loaded/refreshed (ms since epoch, or null)
    property var lastRefresh: null

    // Cached display values extracted from the usage page via WebEngineScript.
    // Format: "33%" — empty string means "not yet loaded".
    // The exact property names depend on the plan:
    //   Max plan:  modelUsages is a list, e.g. ["Sonnet: 33%", "Opus: 17%"]
    //   Pro plan:  sessionPct + weeklyPct
    property string sessionPct: ""
    property string weeklyPct: ""
    property var modelUsages: []   // list of strings for Max plan display

    // How many minutes before we force a reload
    readonly property int refreshIntervalMinutes: 5

    // Returns true if the page data is stale and a reload is needed
    function needsRefresh(): bool {
        if (lastRefresh === null) return true
        const ageMinutes = (Date.now() - lastRefresh) / 60000
        return ageMinutes > refreshIntervalMinutes
    }

    function markRefreshed() {
        root.lastRefresh = Date.now()
    }

    // Called from WebEngineScript when percentages are extracted from the DOM
    function updateUsage(session, weekly, models) {
        root.sessionPct = session ?? ""
        root.weeklyPct = weekly ?? ""
        root.modelUsages = models ?? []
    }
}
