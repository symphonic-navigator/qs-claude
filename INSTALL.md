# Installation

## Voraussetzungen

- Hyprland mit [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) Quickshell-Config
- chezmoi (für automatisches Re-Patching nach end-4 Updates)
- QtWebEngine (sollte mit Quickshell bereits installiert sein)

---

## Schritt 1 — Dateien deployen

Die QML-Dateien aus diesem Repo nach `~/.config/quickshell/ii/` kopieren:

```bash
# Zielverzeichnisse anlegen
mkdir -p ~/.config/quickshell/ii/modules/ii/bar/claude
mkdir -p ~/.config/quickshell/ii/modules/ii/bar/session
mkdir -p ~/.config/quickshell/ii/services_chris

# Dateien kopieren
cp -r modules/ii/bar/claude/ ~/.config/quickshell/ii/modules/ii/bar/
cp -r modules/ii/bar/session/ ~/.config/quickshell/ii/modules/ii/bar/
cp -r services_chris/ ~/.config/quickshell/ii/
```

### Via chezmoi tracken (empfohlen)

```bash
chezmoi add ~/.config/quickshell/ii/modules/ii/bar/claude/
chezmoi add ~/.config/quickshell/ii/modules/ii/bar/session/
chezmoi add ~/.config/quickshell/ii/services_chris/
```

---

## Schritt 2 — BarContent.qml patchen

Das Script in `scripts/run_after_patch.sh.tmpl` patcht end-4's `BarContent.qml`
idempotent — d.h. es kann beliebig oft laufen ohne Schaden anzurichten.

### Option A: In bestehendes chezmoi-Script integrieren

Den Inhalt von `scripts/run_after_patch.sh.tmpl` ans Ende deines bestehenden
`~/.local/share/chezmoi/scripts/run_after_99.sh.tmpl` anhängen.

### Option B: Als eigenes Script hinzufügen

```bash
cp scripts/run_after_patch.sh.tmpl ~/.local/share/chezmoi/scripts/run_after_98_claude.sh.tmpl
chmod +x ~/.local/share/chezmoi/scripts/run_after_98_claude.sh.tmpl
```

### Patch manuell ausführen (einmalig zum Testen)

```bash
bash scripts/run_after_patch.sh.tmpl
```

Erfolgreich wenn die Ausgabe endet mit:
```
✓ BarContent.qml patch applied successfully
```

---

## Schritt 3 — Quickshell neu laden

```bash
qs -c ii ipc call reload
```

In der Bar sollte jetzt ein `smart_toy` Icon (🤖) ganz rechts erscheinen.

---

## Schritt 4 — Einmalig einloggen

> **Wichtig:** Google SSO funktioniert in QtWebEngine **nicht** (blockiert seit 2021).
> Nur **Email + Passwort** verwenden!

1. In der Bar das **Schlüssel-Icon** (🔑) anklicken
2. Im Popup bei `claude.ai` mit Email + Passwort einloggen
3. Popup schließen — Cookies sind dauerhaft gespeichert unter
   `~/.local/share/quickshell/hyprbar_sessions/`

Ab sofort: Hover über das `smart_toy` Icon → Usage-Seite erscheint automatisch.

---

## Schritt 5 — SessionBrowser deaktivieren (optional)

Nach dem einmaligen Login kann das Schlüssel-Icon ausgeblendet werden.
In `config.json` ergänzen:

```json
{
  "bar": {
    "sessionBrowser": {
      "enable": false
    },
    "claudeUsage": {
      "enable": true
    }
  }
}
```

---

## Update-Verhalten

Wenn end-4 ein Update pusht und `BarContent.qml` überschrieben wird:

```bash
# end-4 update
cd ~/.config/quickshell && git pull

# chezmoi re-applyt → Patch wird automatisch neu angewendet
chezmoi apply
```

Der Patch erkennt ob er bereits angewendet wurde (`[CHRIS_PATCH]` Marker)
und überspringt ihn in dem Fall.

---

## Troubleshooting

### Icon erscheint nicht in der Bar

Prüfen ob der Patch erfolgreich war:
```bash
grep -n "ClaudeUsageBar" ~/.config/quickshell/ii/modules/ii/bar/BarContent.qml
```

Wenn keine Ausgabe: Patch nochmal manuell ausführen und Fehlermeldung lesen.

### Prozent-Zahlen erscheinen nicht im Icon

Das WebEngineScript liest die Werte aus dem DOM der Usage-Seite.
Wenn claude.ai ihr Markup ändert, muss die Heuristik in
`modules/ii/bar/claude/ClaudeUsagePopup.qml` (Abschnitt `extractScript`)
angepasst werden.

Zur Diagnose: Die Usage-Seite in einem normalen Browser öffnen, Developer Tools →
Console → prüfen welche CSS-Klassen die Prozent-Elemente haben.

### Popup-Position ist falsch

Die x-Position des Popups wird aus der Position des Bar-Icons berechnet.
In `ClaudeUsagePopup.qml` den `anchor.rect` Wert anpassen:

```qml
rect: Qt.rect(
    <x-offset>,            // manuell einstellen
    Appearance.sizes.barHeight,
    popup.width,
    popup.height
)
```

### Login-Cookies gehen verloren

Cookies liegen in `~/.local/share/quickshell/hyprbar_sessions/`.
Wenn dieses Verzeichnis gelöscht wird (z.B. durch `rm -rf`), muss
Schritt 4 wiederholt werden.
