#!/usr/bin/env bash
# Bootstrap-Skript für Tinnitus-Protokoll Flutter-App.
# Voraussetzung: Flutter SDK installiert (`brew install --cask flutter`).
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Fehler: 'flutter' nicht im PATH. Bitte installieren:"
  echo "  brew install --cask flutter"
  echo "  flutter doctor"
  exit 1
fi

echo "==> flutter --version"
flutter --version

echo "==> Android-Plattform-Scaffold via 'flutter create' ergänzen"
# Erzeugt android/ + ios/ + linux/... ohne existierende Files (pubspec, lib/) zu überschreiben.
flutter create \
  --project-name tinnitus_protocol \
  --org de.kochniss \
  --platforms=android \
  .

echo "==> flutter pub get"
flutter pub get

echo "==> Drift Code-Gen (build_runner)"
dart run build_runner build --delete-conflicting-outputs

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test

echo
echo "Fertig. App bauen mit:"
echo "  flutter build apk --debug"
echo "Oder auf Gerät/Emulator starten:"
echo "  flutter run"
