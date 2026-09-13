# Hudoori (حضوري) — BioTime Web Dashboard

Hudoori is a Flutter web app for HR and operations teams. It provides a dashboard, employees management, attendance insights, and payroll-related workflows backed by the BioTime sync service.

**Live web (GitHub Pages):** https://ibrahim-atef.github.io/biotime_web_dashboard/

## Tech stack

- Flutter (Web)
- BLoC (`flutter_bloc`)
- Routing (`go_router`)
- Charts (`fl_chart`)
- Backend: Node/TypeScript service in `../biotime_backend` (JSON-RPC over HTTP)

## API configuration

The API base URL is configured via Dart defines and resolved at runtime in:

- `lib/core/config/api_config.dart`

### Production (Hudoori Multi)

- Frontend: `https://hr.hudoori.code-solution.org`
- API: `https://hr-api.hudoori.code-solution.org`
- Health: `https://hr-api.hudoori.code-solution.org/api/health`

Do **not** use single-company Hudoori domains (`hudoori.code-solution.org`, `apihodouri…`).

### Local development

When running on `localhost`, the app pins the API to the local backend automatically:

- Local backend: `http://localhost:3000` (run `npm run dev` in `../biotime_backend`)

## Getting started (local)

```bash
cd biotime_all_apps/biotime_app
flutter pub get
flutter run -d chrome --web-port=8900
```

## Build & deploy (GitHub Pages)

This repository includes a GitHub Actions workflow that builds the Flutter web bundle and deploys it to GitHub Pages:

- Workflow: `.github/workflows/deploy-web.yml`
- Trigger: push to `main` / `master` (or manual `workflow_dispatch`)

During the build, the workflow sets:

- `--dart-define=BIOTIME_API_URL="<url>"`
- `--dart-define=BIOTIME_PIN_LOCALHOST=false`

## Notes

- The login screen does not expose the API URL; it is controlled by build-time configuration.
- If charts or attendance look incorrect, ensure the backend has completed BioTime sync and attendance generation.

## Mobile app (iOS & Android)

This repository **is** the `biotime_app` Flutter project and is the single source of truth for **both** the web dashboard and the iOS/Android app (one codebase, three targets). The `biotime_app` copies inside the `jouma/` and `V19/` repos are stale — do not build from them.

**Scope:** on mobile (`!kIsWeb`) the app is **employee self-service only** — HR-management (`/hr/*`) and platform-admin (`/admin/*`) screens are hidden from the nav and blocked in the router; the full set remains on the web dashboard. Gating lives in `lib/features/shell/shell_nav.dart` and `lib/core/router/app_router.dart`.

### TODO
- [ ] Build & release **Android** (needs Android SDK) and **iOS** (needs macOS + Xcode) from this repo.
- [ ] Point the mobile release pipeline at this repo.
- [ ] Retire the stale `jouma/biotime_app` and `V19/biotime_app` copies. **CAUTION:** those live inside Odoo repos and `jouma` main auto-deploys to Odoo.sh prod — do it as a separate, reviewed change on those repos, never as part of a Hudoori push.

### Build — Android (Linux/Windows/macOS)
1. Install the Android command-line tools; via `sdkmanager` install `platform-tools`, `platforms;android-34`, `build-tools`.
2. `export ANDROID_HOME=<sdk-path>` then `flutter doctor --android-licenses` (accept).
3. `flutter pub get`
4. Release: `flutter build apk --release` (APK) or `flutter build appbundle` (`.aab` for Google Play). Release signing needs a keystore (`android/key.properties` + `keystore.jks`); debug builds do not.

### Build — iOS (macOS + Xcode only; cannot build on Linux/WSL)
1. Install Xcode + command-line tools and CocoaPods (`sudo gem install cocoapods`).
2. `flutter pub get` then `cd ios && pod install`.
3. Open `ios/Runner.xcworkspace` → Runner → Signing & Capabilities → select your Apple Developer team. Bundle id: `com.codesolutioneg.biotimeApp`.
4. `flutter build ipa --release` (→ `build/ios/ipa/`) or Xcode → Product → Archive → distribute to TestFlight / App Store. Requires a paid Apple Developer account.
