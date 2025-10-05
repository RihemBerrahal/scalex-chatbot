#!/usr/bin/env bash
set -e

# --- CONFIG ---
API_PORT=${API_PORT:-5050}
HOST_IP=${HOST_IP:-192.168.100.114}      # your LAN IP
API_URL="http://$HOST_IP:$API_PORT"

echo "==> Starting backend on $API_URL and Flutter with API_URL dart-define"

# --- Start backend ---
( cd server && npm install && \
  if [ -f ".env" ]; then echo "Using server/.env"; else cp .env.example .env || true; fi && \
  npm run dev ) &

# --- Start mobile ---
cd mobile
flutter pub get
flutter run --dart-define=API_URL=$API_URL
