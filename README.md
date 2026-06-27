# Tinnitus-Protokoll

Lokale Android-App (Flutter) zum täglichen Protokollieren von Tinnitus-Symptomen.

## Features

- Eintrag erfassen: Lautstärke, Belastung, Schlafqualität (jeweils 1–10) + Freitext-Notizen
- Verlaufs-Charts (letzte 30 Tage) + Durchschnittswerte
- Export als CSV oder JSON (via Share-Sheet)
- Dark Mode folgt System
- Daten ausschließlich lokal (SQLite via [Drift](https://pub.dev/packages/drift))

## Stack

Flutter 3 / Dart 3, Riverpod, Drift, fl_chart, share_plus, intl.

## Setup

```bash
./setup.sh
```

Das Skript ergänzt die Android-Plattform-Dateien (`flutter create`),
zieht Dependencies, generiert den Drift-Code, analysiert und testet.

Voraussetzung:

```bash
brew install --cask flutter
flutter doctor
```

## Build & Run

```bash
flutter build apk --debug          # APK
flutter run                        # Emulator/Gerät
```

## Projektstruktur

Siehe [`plan.md`](./plan.md).
