# Release Tag Policy

Diese Policy definiert, wie Release-Tags in diesem Repository erstellt und geschützt werden.

## Ziel

- Eindeutige, unveränderliche Release-Tags
- Konsistente Versionierung nach Semantic Versioning
- Schutz vor versehentlichem Überschreiben oder Löschen

## Tag-Namensschema

Erlaubte Release-Tags:

- `vMAJOR.MINOR.PATCH` (Beispiel: `v3.1.0`)

Erlaubte Pre-Release-Tags:

- `vMAJOR.MINOR.PATCH-rc.N` (Beispiel: `v3.2.0-rc.1`)
- `vMAJOR.MINOR.PATCH-beta.N` (Beispiel: `v3.2.0-beta.1`)
- `vMAJOR.MINOR.PATCH-alpha.N` (Beispiel: `v3.2.0-alpha.1`)

Nicht verwenden:

- Tags ohne `v` Prefix (Beispiel: `3.1.0`)
- Unscharfe Tags wie `latest`, `stable`, `final`

## Branch-Zuordnung

- `v3.*` Tags werden auf Commits der Branch `V3` gesetzt
- `v2.*` Tags werden auf Commits der Branch `V2-LEGACY` gesetzt
- `main` ist Entwicklungs-Branch und bekommt keine stabilen Release-Tags

## Release Ablauf (Kurz)

1. Stabilen Stand auf `V3` (oder `V2-LEGACY`) sicherstellen.
2. Tag erstellen:

```bash
git checkout V3
git pull
git tag -a v3.1.0 -m "Release v3.1.0"
git push origin v3.1.0
```

3. GitHub Release aus dem Tag erstellen.
4. Release Notes und Release Post verlinken.
