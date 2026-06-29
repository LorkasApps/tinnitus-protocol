#!/usr/bin/env bash
# Bootstrap script for the Tinnitus Protocol Flutter app.
# Prerequisite: Flutter SDK installed (`brew install --cask flutter`).
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: 'flutter' is not in PATH. Install it with:"
  echo "  brew install --cask flutter"
  echo "  flutter doctor"
  exit 1
fi

echo "==> flutter --version"
flutter --version

echo "==> Generating Android platform scaffold via 'flutter create'"
# Adds android/ + ios/ + linux/... without overwriting existing files (pubspec, lib/).
flutter create \
  --project-name tinnitus_protocol \
  --org de.kochniss \
  --platforms=android \
  .

echo "==> flutter pub get"
flutter pub get

echo "==> Drift code generation (build_runner)"
dart run build_runner build --delete-conflicting-outputs

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test

echo
echo "Done. Build the app with:"
echo "  flutter build apk --debug"
echo "Or run on a device/emulator:"
echo "  flutter run"
