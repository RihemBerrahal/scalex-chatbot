# Scalex Chatbot (Flutter + Node)

Modern bilingual (EN/AR) chat app with multiple LLM providers (HF Router / Ollama), model switcher, per-conversation history, and AI-generated summaries.

## Folder Structure
mobile/ # Flutter app (UI, i18n, chat)
server/ # Node/Express API + SQLite

## Prerequisites
- Flutter SDK (3.x)
- Node.js 18+ (or 20+)
- Android Studio / Xcode for emulator/simulator

## Quick Start (one command)
```bash
./run.sh

Backend starts on http://0.0.0.0:5050

Mobile launches with --dart-define=API_URL=http://<your-ip>:5050