# Hyprbar Claude Usage Widget — Playbook

## Übersicht

Ein Hyprland/Quickshell Bar-Widget das die claude.ai Usage-Seite
(`/settings/usage`) in einem eingebetteten QtWebEngine-Browser anzeigt.
Kein Scraping, kein automatisierter Zugriff — nur ein echter Browser,
der bei Bedarf eine Seite lädt.

### Komponenten

```
Part 1: SessionBrowser    — einmaliger Login, persistente Cookies
Part 2: ClaudeUsageBar    — Icon in der Statusbar + Popup on Hover
```

---

## Part 1: Session Browser

### Zweck

Ein eingebetteter Chromium-Browser mit einem **persistenten, benannten
Profil** (`hyprbar_sessions`). Einmal einloggen → Cookies bleiben für
immer → alle Widgets die dasselbe Profil verwenden teilen die Session.

### Google Login Problem

Google blockiert OAuth-Logins in eingebetteten WebViews seit 2021
(`disallowed_useragent`). Workaround: **Claude direkt mit
Email + Passwort einloggen**, nicht über Google SSO. Das funktioniert
in QtWebEngine problemlos.

Alternativ: Einmalig in Vivaldi einloggen und die Cookies manuell
exportieren/importieren — aber direkt Login ist einfacher.

### Wo in der Bar

Kleines Schlüssel-Icon (🔑 oder `key` Material Symbol) ganz rechts in
der Bar, neben dem SysTray. Nur sichtbar wenn du's brauchst, danach
kannst du es per Config ausblenden.

### Dateien

```
~/.config/quickshell/ii/services/BarBrowser.qml       ← Service/Profil
~/.config/quickshell/ii/modules/ii/bar/SessionBrowser.qml  ← Bar-Icon + Popup
```

### BarBrowser.qml (Service — Singleton)

```qml
pragma Singleton
import QtQuick
import QtWebEngine
import Quickshell

Singleton {
    id: root

    // Shared persistent profile — all widgets use this
    property WebEngineProfile sharedProfile: WebEngineProfile {
        storageName: "hyprbar_sessions"
        persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
        // Storage path: ~/.local/share/quickshell/hyprbar_sessions/
    }
}
```

### SessionBrowser.qml (Bar Widget)

```qml
import QtQuick
import QtQuick.Layouts
import QtWebEngine
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool popupVisible: false

    // Bar icon
    MaterialSymbol {
        text: "key"
        iconSize: Appearance.font.pixelSize.large
        color: Appearance.colors.colOnLayer1

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupVisible = !root.popupVisible
        }
    }

    // Login popup
    Loader {
        active: root.popupVisible
        sourceComponent: PopupWindow {
            // Position: unterhalb des Bar-Icons
            width: 900
            height: 650

            WebEngineView {
                anchors.fill: parent
                profile: BarBrowser.sharedProfile
                url: "https://claude.ai/login"
            }

            // Close button
            MaterialSymbol {
                text: "close"
                anchors { top: parent.top; right: parent.right; margins: 8 }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.popupVisible = false
                }
            }
        }
    }
}
```

### Einmalige Setup-Schritte

1. Widget in Bar einbinden (einmalig)
2. Auf das Schlüssel-Icon klicken → Popup öffnet sich
3. Bei claude.ai mit **Email + Passwort** einloggen (nicht Google!)
4. Popup schließen — Cookies sind persistent gespeichert
5. Fertig — ab sofort funktioniert das Usage-Widget automatisch

---

## Part 2: Claude Usage Bar Widget

### Verhalten

```
Hover auf Icon  →  Popup erscheint
                   ↓
                   Letztes Update < 5 Minuten?
                   → Seite einfach anzeigen (kein Reload)

                   Letztes Update > 5 Minuten?
                   → Seite neu laden

Popup nicht sichtbar  →  nichts passiert, kein Timer, kein Request
```

**Kein Polling im Hintergrund.** Die Seite wird nur aktualisiert
wenn das Popup tatsächlich offen ist und die Daten veraltet sind.
Das ist der entscheidende Unterschied zu automatisiertem Zugriff —
ein Mensch hat aktiv das Popup geöffnet.

### Bar-Icon Idee

```
🤖  33% / 17%
```

Claude-Symbol (custom SVG oder Material Symbol `smart_toy`) + die
beiden Prozentzahlen aus dem letzten gesehenen Stand. Beim ersten
Start: nur das Icon, keine Zahlen (noch nie geöffnet).

**Für die Prozentzahlen:** Diese kommen nicht aus dem DOM (kein
Scraping!) sondern werden manuell gesetzt wenn der User das Popup
öffnet und schaut — optional kann man via `WebEngineScript` die
Zahlen aus der geladenen Seite lesen und als Property setzen.
Das ist dann eine Designentscheidung die wir beim Implementieren
treffen.

### Dateien

```
~/.config/quickshell/ii/services/ClaudeUsage.qml           ← State
~/.config/quickshell/ii/modules/ii/bar/claude/ClaudeUsageBar.qml   ← Bar-Icon
~/.config/quickshell/ii/modules/ii/bar/claude/ClaudeUsagePopup.qml ← Popup
```

### ClaudeUsage.qml (Service — Singleton)

```qml
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Last time the page was loaded/refreshed
    property var lastRefresh: null

    // Cached display values (optional — for bar icon text)
    property string sessionPct: ""
    property string weeklyPct: ""

    // Returns true if refresh is needed
    function needsRefresh(): bool {
        if (lastRefresh === null) return true
        const age = (Date.now() - lastRefresh) / 1000 / 60  // minutes
        return age > 5
    }

    function markRefreshed() {
        root.lastRefresh = Date.now()
    }
}
```

### ClaudeUsageBar.qml (Bar-Icon)

```qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

MouseArea {
    id: root
    property bool popupVisible: false
    implicitWidth: rowLayout.implicitWidth + 10 * 2
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: true

    onEntered: root.popupVisible = true
    onExited: {
        // Small delay so mouse can move into popup
        hideTimer.start()
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

        StyledText {
            visible: ClaudeUsage.sessionPct !== ""
            text: ClaudeUsage.sessionPct !== ""
                  ? `${ClaudeUsage.sessionPct} / ${ClaudeUsage.weeklyPct}`
                  : ""
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
        }
    }

    ClaudeUsagePopup {
        id: usagePopup
        visible: root.popupVisible
        hoverTarget: root
    }
}
```

### ClaudeUsagePopup.qml (Popup)

```qml
pragma ComponentBehavior: Bound
import QtQuick
import QtWebEngine
import Quickshell
import qs.services
import qs.modules.common

// Popup window that appears below the bar icon
Item {
    id: root
    property var hoverTarget

    // The actual popup
    PopupWindow {
        id: popup
        anchor {
            window: root.hoverTarget?.QsWindow.window
            rect.x: // position under bar icon — calculated at impl time
            rect.y: Appearance.sizes.baseBarHeight
        }
        width: 480
        height: 420

        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colLayer0
            radius: Appearance.rounding.windowRounding

            WebEngineView {
                id: webView
                anchors {
                    fill: parent
                    margins: 1
                }
                profile: BarBrowser.sharedProfile
                url: "https://claude.ai/settings/usage"

                // On load complete: mark refresh time
                onLoadingChanged: (info) => {
                    if (info.status === WebEngineView.LoadSucceededStatus) {
                        ClaudeUsage.markRefreshed()
                        // Optional: inject script to read percentages
                        // and write to ClaudeUsage.sessionPct / .weeklyPct
                    }
                }
            }
        }
    }

    // Trigger refresh logic when popup becomes visible
    onVisibleChanged: {
        if (visible && ClaudeUsage.needsRefresh()) {
            webView.reload()
        }
    }
}
```

---

## BarContent.qml Einbindung

Im `rightSectionRowLayout`, neben dem Weather-Widget:

```qml
// After the weather Loader:
Loader {
    Layout.leftMargin: 4
    active: Config.options.bar.claudeUsage?.enable ?? true

    sourceComponent: BarGroup {
        ClaudeUsageBar {}
    }
}
```

Und weiter oben in BarContent.qml die Imports ergänzen:

```qml
import qs.modules.ii.bar.claude
```

---

## Verzeichnisstruktur (vollständig)

```
~/.config/quickshell/ii/
├── services/
│   ├── BarBrowser.qml          ← Part 1: Shared WebEngine Profile
│   └── ClaudeUsage.qml         ← Part 2: State (lastRefresh, Pcts)
└── modules/ii/bar/
    ├── BarContent.qml           ← bestehend — erweitern
    ├── session/
    │   └── SessionBrowser.qml  ← Part 1: Login-Browser Bar-Widget
    └── claude/
        ├── ClaudeUsageBar.qml  ← Part 2: Bar-Icon
        └── ClaudeUsagePopup.qml ← Part 2: Popup mit WebEngineView
```

---

## Config-Option (optional)

In `config.json` / `Config.qml` ergänzen:

```json
{
  "bar": {
    "claudeUsage": {
      "enable": true,
      "refreshIntervalMinutes": 5
    }
  }
}
```

---

## Designentscheidungen — getroffen ✅

1. **Prozentzahlen im Bar-Icon:** ✅ **Ja, via `WebEngineScript`** DOM auslesen
   und im Icon anzeigen. TOS-konform weil: Werte werden **nur aktualisiert wenn
   der User das Popup sowieso aufruft** — nie im Hintergrund, nie ohne
   User-Interaktion.

2. **Popup-Position:** Orientiert an den bestehenden Widgets (z.B. `ResourcesPopup`
   / `WeatherPopup`) — direkt unterhalb des Bar-Icons, abgerundete Box mit
   Schatten, gleicher Stil wie der Rest der Bar.

3. **Max Plan — getrennte Anzeige:** ✅ Getrennte Anzeige von Sonnet/Opus (und
   ggf. weiteren Modellen). Die Anzahl der Prozentwerte ist variabel: es können
   2 oder 3 Werte sein je nach Plan. Bar-Icon zeigt initial **"hover to load"**
   bis das Popup das erste Mal geöffnet wurde.

4. **Zwei Accounts (privat/firma):** ✅ Kein Problem — getrennte Geräte,
   getrennte `hyprbar_sessions` Profile, jedes mit dem jeweiligen Account.

5. **SessionBrowser dauerhaft ausblenden:** ✅ Per Config-Option deaktivierbar
   nach dem einmaligen Login.

---

## TOS-Konformität

- ✅ Echter eingebetteter Browser, kein Script/Bot
- ✅ Manuell ausgelöst (Hover = User-Interaktion)
- ✅ Kein automatischer Hintergrund-Polling
- ✅ Kein DOM-Scraping (Seite wird nur angezeigt)
- ✅ Eigene Session, eigene Cookies, eigener Account
- ✅ Funktionell identisch mit einem Browser-Bookmark

---

## Part 3: chezmoi-Integration — update-sicherer BarContent.qml Patch

### Das Problem

end-4's `BarContent.qml` liegt in `~/.config/quickshell/ii/` — ein git-verwaltetes
Repo das sich automatisch updated. Direkte Edits gehen beim nächsten `git pull` verloren.

### Die Lösung: chezmoi `run_after` Hook mit git-Patch

Chezmoi führt nach jedem `chezmoi apply` die `run_after_*.sh.tmpl` Scripts aus.
Dort patchen wir `BarContent.qml` mit einem robusten Sed-Replace — idempotent,
d.h. läuft mehrfach ohne Schaden.

### Strategie: Anchor-basierter Inject

Wir suchen eine **stabile Zeile** in `BarContent.qml` die end-4 sehr wahrscheinlich
nie ändert — der Weather-Loader ist ein guter Anker, weil er selbst schon ein
optionales Feature ist und eine klare Struktur hat.

**Inject-Position:** Direkt nach dem Weather `Loader` Block, vor dem
schließenden `}` des `rightSectionRowLayout`.

```
// Vorher (original):
            // Weather
            Loader {
                Layout.leftMargin: 4
                active: Config.options.bar.weather.enable
                sourceComponent: BarGroup {
                    WeatherBar {}
                }
            }
        }   ← hier endet rightSectionRowLayout
    }
}

// Nachher (gepatcht):
            // Weather
            Loader { ... }

            // [CHRIS_PATCH] Claude Usage Widget
            Loader {
                Layout.leftMargin: 4
                active: Config.options.bar.claudeUsage?.enable ?? true
                sourceComponent: BarGroup {
                    ClaudeUsageBar {}
                }
            }
        }
    }
}
```

### chezmoi Script Update

In `~/.local/share/chezmoi/scripts/run_after_99.sh.tmpl` ergänzen:

```bash
#! /bin/bash

pypr reload || true

# ─── Patch end-4 BarContent.qml with our Claude Usage widget ───────────────

BARCONTENT="$HOME/.config/quickshell/ii/modules/ii/bar/BarContent.qml"
MARKER="[CHRIS_PATCH]"

if [[ -f "$BARCONTENT" ]]; then
    if grep -q "$MARKER" "$BARCONTENT"; then
        echo "BarContent.qml: patch already applied, skipping"
    else
        echo "BarContent.qml: applying Claude Usage patch..."

        # We inject before the closing brace of rightSectionRowLayout.
        # Anchor: the line after WeatherBar {}'s closing brace + one more }
        # Strategy: find "WeatherBar {}" and insert after the next two closing braces.
        python3 - "$BARCONTENT" << 'PYTHON'
import sys, re

path = sys.argv[1]
with open(path, "r") as f:
    content = f.read()

# The patch to inject — indentation matches BarContent.qml style (12 spaces)
patch = """
            // [CHRIS_PATCH] Claude Usage Widget — auto-injected by chezmoi
            Loader {
                Layout.leftMargin: 4
                active: Config.options.bar.claudeUsage?.enable ?? true

                sourceComponent: BarGroup {
                    ClaudeUsageBar {}
                }
            }"""

# Anchor: inject after the Weather Loader block's closing brace.
# We look for the exact pattern: WeatherBar {} followed by closing braces.
anchor = re.compile(
    r'(// Weather\s+Loader\s*\{[^}]*?WeatherBar\s*\{\}\s*\}\s*\})',
    re.DOTALL
)

match = anchor.search(content)
if match:
    insert_pos = match.end()
    new_content = content[:insert_pos] + "\n" + patch + content[insert_pos:]
    with open(path, "w") as f:
        f.write(new_content)
    print("  ✓ Patch applied successfully")
else:
    print("  ✗ Anchor not found — end-4 may have changed BarContent.qml structure")
    print("    Check and update the patch anchor in run_after_99.sh.tmpl")
    exit(1)
PYTHON

    fi
else
    echo "BarContent.qml not found at $BARCONTENT — skipping patch"
fi

# ─── Reload Quickshell if running ──────────────────────────────────────────
if pgrep -x qs > /dev/null; then
    echo "Reloading Quickshell..."
    qs -c ii ipc call reload 2>/dev/null || true
fi
```

### Wie das in der Praxis funktioniert

```
chezmoi apply
    → run_after_99.sh läuft
    → prüft ob [CHRIS_PATCH] bereits in BarContent.qml
    → wenn nein: Python-Snippet patcht die Datei
    → wenn ja: überspringt (idempotent)
    → Quickshell reload
```

```
end-4 git pull (neues Update)
    → BarContent.qml wird überschrieben → Patch weg
    → nächstes chezmoi apply → Patch wird neu angewendet
```

**Was ist wenn end-4 die Struktur ändert?**
Das Python-Script gibt einen klaren Fehler aus mit Hinweis was zu tun ist.
Du musst nur den Anchor-Pattern in `run_after_99.sh.tmpl` anpassen.
Das ist deutlich weniger Arbeit als ein git-Merge-Conflict.

### Import in BarContent.qml

Der Patch fügt `ClaudeUsageBar {}` ein — aber der Import fehlt noch.
Den müssen wir ebenfalls patchen. Zweiter Patch-Block im selben Script,
direkt nach dem ersten:

```python
# Patch 2: Add import for our Claude module
import_patch = "import qs.modules.ii.bar.claude\n"
import_anchor = "import qs.modules.ii.bar.weather\n"

if import_patch not in content:
    new_content = new_content.replace(import_anchor, import_anchor + import_patch)
    print("  ✓ Import patch applied")
```

### Dateistruktur in deinen dotfiles (chezmoi repo)

```
~/.local/share/chezmoi/
├── scripts/
│   └── run_after_99.sh.tmpl    ← erweitern (wie oben)
└── dot_config/
    └── quickshell/              ← NEU: deine eigenen QML-Dateien
        └── ii/
            └── modules/
                └── ii/
                    └── bar/
                        └── claude/               ← deine Widget-Dateien
                            ├── ClaudeUsageBar.qml
                            └── ClaudeUsagePopup.qml
                        └── session/
                            └── SessionBrowser.qml
        └── services_chris/      ← eigene Services (anderer Name um Konflikte zu vermeiden)
            ├── BarBrowser.qml
            └── ClaudeUsage.qml
```

> **Warum `services_chris/` statt `services/`?**
> End-4 hat schon ein `services/` Verzeichnis mit eigenem `qmldir`.
> Eigene Services in einem separaten Ordner vermeidet Import-Konflikte.

### chezmoi: eigene QML-Dateien hinzufügen

```bash
# Einmalig: Verzeichnis-Struktur anlegen und tracken
mkdir -p ~/.config/quickshell/ii/modules/ii/bar/claude/
mkdir -p ~/.config/quickshell/ii/modules/ii/bar/session/

# Dateien zu chezmoi hinzufügen
chezmoi add ~/.config/quickshell/ii/modules/ii/bar/claude/ClaudeUsageBar.qml
chezmoi add ~/.config/quickshell/ii/modules/ii/bar/claude/ClaudeUsagePopup.qml
chezmoi add ~/.config/quickshell/ii/services_chris/BarBrowser.qml
chezmoi add ~/.config/quickshell/ii/services_chris/ClaudeUsage.qml
```

Diese Dateien werden von chezmoi verwaltet und sind damit update-safe —
end-4 würde diese Verzeichnisse nie anlegen, also nie überschreiben.

### `qmldir` für eigene Module

Damit Quickshell die eigenen Module findet, braucht jedes neue Verzeichnis
eine `qmldir` Datei:

```
# ~/.config/quickshell/ii/modules/ii/bar/claude/qmldir
module qs.modules.ii.bar.claude
ClaudeUsageBar 1.0 ClaudeUsageBar.qml
ClaudeUsagePopup 1.0 ClaudeUsagePopup.qml
```

```
# ~/.config/quickshell/ii/services_chris/qmldir
module qs.services.chris
BarBrowser 1.0 BarBrowser.qml
ClaudeUsage 1.0 ClaudeUsage.qml
```

Diese `qmldir` Dateien auch via chezmoi tracken:

```bash
chezmoi add ~/.config/quickshell/ii/modules/ii/bar/claude/qmldir
chezmoi add ~/.config/quickshell/ii/services_chris/qmldir
```

---

## Zusammenfassung: Vollständiger Setup-Prozess (einmalig)

```bash
# 1. Verzeichnisse anlegen
mkdir -p ~/.config/quickshell/ii/modules/ii/bar/{claude,session}
mkdir -p ~/.config/quickshell/ii/services_chris

# 2. QML-Dateien erstellen (Inhalt: siehe Part 1 + Part 2)
# ... ClaudeUsageBar.qml, ClaudeUsagePopup.qml, SessionBrowser.qml
# ... BarBrowser.qml, ClaudeUsage.qml
# ... qmldir files

# 3. Alle Dateien zu chezmoi hinzufügen
chezmoi add ~/.config/quickshell/ii/modules/ii/bar/claude/
chezmoi add ~/.config/quickshell/ii/modules/ii/bar/session/
chezmoi add ~/.config/quickshell/ii/services_chris/

# 4. run_after_99.sh.tmpl mit Patch-Script ergänzen
chezmoi edit ~/.local/share/chezmoi/scripts/run_after_99.sh.tmpl

# 5. Apply — patcht BarContent.qml + deployt QML-Dateien
chezmoi apply

# 6. Quickshell reload
qs -c ii ipc call reload

# 7. Session-Browser öffnen, bei claude.ai einloggen (Email/Passwort)
# 8. Session-Browser per Config deaktivieren
```
