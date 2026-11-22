#!/usr/bin/env bash
# Genera le cartelle android/ios (non salvate nel repo) e applica le modifiche native.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --project-name scout_lab --org dev.scoutlab --platforms=android,ios . >/dev/null
rm -f test/widget_test.dart

python3 tool/patch_android.py

flutter pub get
dart run flutter_launcher_icons
