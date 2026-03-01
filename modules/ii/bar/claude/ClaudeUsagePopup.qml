pragma ComponentBehavior: Bound
import QtQuick
import QtWebEngine
import Quickshell
import qs.modules.common
import qs.services.chris

// Popup that shows claude.ai/settings/usage in an embedded browser.
// Appears below the bar icon on hover.
// Only reloads when data is stale (> 5 minutes old) — no background polling.
Item {
    id: root

    // Set by ClaudeUsageBar to control visibility
    property bool barVisible: false

    // The bar icon MouseArea — used to position the popup below it
    property var hoverTarget

    // Expose containsMouse so the bar can check if the mouse is inside
    property bool containsMouse: popupMouseArea.containsMouse

    // Script injected after page load to extract usage percentages from the DOM.
    // Calls window._claudeUsageCallback(session, weekly, models) with the results.
    //
    // NOTE: If claude.ai changes its DOM structure, update the selectors below.
    // To find the right selectors: open claude.ai/settings/usage in a browser,
    // inspect the usage percentage elements, and update the querySelector calls.
    readonly property string extractScript: `
        (function() {
            try {
                // Strategy: find all text nodes containing a "%" character
                // and look for usage-related context nearby.
                // The claude.ai usage page shows percentage bars with labels.

                let session = "";
                let weekly = "";
                let models = [];

                // Look for percentage values in progress bar labels or stat elements.
                // These selectors target the usage stat display on /settings/usage.
                // Adjust if claude.ai updates their markup.
                const allText = document.querySelectorAll('[class*="usage"], [class*="limit"], [class*="stat"], [class*="progress"]');

                // Fallback: scan all elements for percentage text
                const percentPattern = /(\d{1,3})%/;
                const candidates = [];

                document.querySelectorAll('*').forEach(el => {
                    if (el.children.length === 0) {  // leaf nodes only
                        const text = el.textContent.trim();
                        const match = percentPattern.exec(text);
                        if (match && text.length < 30) {
                            candidates.push({ el, text, pct: match[1] });
                        }
                    }
                });

                // Heuristic: group into model-specific usage values
                // The page typically shows usage per model (Sonnet, Opus, etc.)
                // and per time window (session, weekly).
                const modelNames = ['Sonnet', 'Opus', 'Haiku', 'Claude'];
                let usageValues = [];

                for (const c of candidates) {
                    // Walk up to find a label
                    let parent = c.el.parentElement;
                    let label = "";
                    for (let i = 0; i < 5 && parent; i++) {
                        const siblings = Array.from(parent.querySelectorAll('*'));
                        for (const sib of siblings) {
                            if (sib === c.el) continue;
                            const t = sib.textContent.trim();
                            if (modelNames.some(m => t.includes(m)) || t.includes('session') || t.includes('week')) {
                                label = t.substring(0, 20);
                                break;
                            }
                        }
                        if (label) break;
                        parent = parent.parentElement;
                    }

                    if (label) {
                        const isModel = modelNames.some(m => label.includes(m));
                        if (isModel) {
                            models.push(label.split(/\s+/)[0] + " " + c.pct + "%");
                        } else if (label.includes('session')) {
                            session = c.pct + "%";
                        } else if (label.includes('week')) {
                            weekly = c.pct + "%";
                        }
                    } else if (usageValues.length < 3) {
                        usageValues.push(c.pct + "%");
                    }
                }

                // Fallback: if we found raw percentages but no labels, use them
                if (session === "" && usageValues.length >= 1) session = usageValues[0];
                if (weekly === "" && usageValues.length >= 2) weekly = usageValues[1];

                window._claudeUsageCallback(session, weekly, models);
            } catch(e) {
                console.warn("ClaudeUsage extraction failed:", e);
                window._claudeUsageCallback("", "", []);
            }
        })();
    `

    PopupWindow {
        id: popup
        visible: root.barVisible

        width: 480
        height: 420

        anchor {
            window: root.hoverTarget?.QsWindow.window
            // Position: directly below the bar, horizontally centered on the icon.
            // rect.x = icon's x position within the bar window, centered on popup width.
            // rect.y = full bar height so popup appears just below.
            rect: Qt.rect(
                Math.max(0, (root.hoverTarget?.mapToItem(null, 0, 0).x ?? 0) + (root.hoverTarget?.width ?? 0) / 2 - popup.width / 2),
                Appearance.sizes.barHeight,
                popup.width,
                popup.height
            )
        }

        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colLayer0
            radius: Appearance.rounding.windowRounding

            // Track mouse so the bar knows not to close the popup
            MouseArea {
                id: popupMouseArea
                anchors.fill: parent
                hoverEnabled: true
                // Pass through clicks to the WebEngineView
                propagateComposedEvents: true
                onPressed: (mouse) => mouse.accepted = false
            }

            WebEngineView {
                id: webView
                anchors {
                    fill: parent
                    margins: 1
                }
                profile: BarBrowser.sharedProfile
                url: "https://claude.ai/settings/usage"

                // WebChannel callback so the injected JS can call back into QML
                userScripts: [
                    WebEngineScript {
                        id: callbackScript
                        name: "ClaudeUsageCallback"
                        injectionPoint: WebEngineScript.DocumentCreation
                        // Expose the callback function before the page loads
                        sourceCode: `
                            window._claudeUsageCallback = function(session, weekly, models) {
                                // This will be overridden by Qt's WebChannel or
                                // we read the result via runJavaScript return value.
                                // Storing on window so the extraction script can call it.
                                window._lastSession = session;
                                window._lastWeekly = weekly;
                                window._lastModels = models;
                            };
                        `
                    }
                ]

                onLoadingChanged: (loadRequest) => {
                    if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                        ClaudeUsage.markRefreshed()

                        // Inject extraction script and read back the results
                        webView.runJavaScript(root.extractScript, function(result) {
                            // After extraction script ran, read stored values
                            webView.runJavaScript(
                                "JSON.stringify([window._lastSession || '', window._lastWeekly || '', window._lastModels || []])",
                                function(json) {
                                    if (json) {
                                        try {
                                            const data = JSON.parse(json)
                                            ClaudeUsage.updateUsage(data[0], data[1], data[2])
                                        } catch(e) {
                                            console.warn("ClaudeUsage: JSON parse failed:", e)
                                        }
                                    }
                                }
                            )
                        })
                    }
                }
            }
        }
    }

    // Trigger reload logic whenever the popup becomes visible
    onBarVisibleChanged: {
        if (barVisible && ClaudeUsage.needsRefresh()) {
            webView.reload()
        }
    }
}
