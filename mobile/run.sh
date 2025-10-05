#!/usr/bin/env bash
set -e
API_URL=${API_URL:-http://10.0.2.2:5050} # emulator default
echo "==> Flutter with API_URL=$API_URL"
flutter pub get
flutter run --dart-define=API_URL=$API_URL
