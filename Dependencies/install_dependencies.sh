#!/bin/bash

# Überprüfen, ob das Skript mit sudo ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript mit sudo aus."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPENDENCIES_FILE="$SCRIPT_DIR/dependencies.txt"

# Prüfen, ob die Abhängigkeiten-Datei existiert
if [ ! -f "$DEPENDENCIES_FILE" ]; then
  echo "❌ Fehler: Die Datei 'dependencies.txt' wurde nicht gefunden!"
  exit 1
fi

echo "📦 Installiere Abhängigkeiten aus '$DEPENDENCIES_FILE'..."

# Jede Zeile der Datei lesen und das Paket installieren
while IFS= read -r package || [ -n "$package" ]; do
  if [ -n "$package" ] && [[ ! "$package" =~ ^# ]]; then
    echo "🔄 Installiere $package..."
    apt-get install -y "$package" || { echo "❌ Fehler beim Installieren von $package"; exit 1; }
  fi
done < "$DEPENDENCIES_FILE"

echo "✅ Alle Abhängigkeiten wurden erfolgreich installiert!"