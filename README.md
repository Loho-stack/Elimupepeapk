# Elimu Pepe

Flutter Android app for secure learner access to ebooks and learner dashboard resources.

## Current Status

The app is no longer in the default Flutter starter state.

Implemented:
- Student login with token-based authentication
- Session validation and auth-gated splash routing
- Learner categories with API-driven content lists
- In-app WebView SSO flow using `GET /api/student/webview-token`
- Cloud ebook listing/download from PHP backend
- Local offline ebook storage and reading

## Tech Stack

- Flutter 3 / Dart 3
- Dio for API communication
- Flutter Secure Storage for token storage
- Sqflite for local metadata storage
- Pdfx for PDF viewing
- WebView Flutter for in-app content launch
- Firebase (Core, Firestore, Analytics)

## Firebase Analytics

- Screen views: tracked via `FirebaseAnalyticsObserver` for routes that have a `RouteSettings.name` (routes created with `AppPageTransitions.route()` now get an automatic name).
- Login events: `login_attempt`, `login_failed`, `login_terms_not_agreed`, `login_error`, plus the standard Firebase `login` event on success.

Android DebugView (optional):

```bash
adb shell setprop debug.firebase.analytics.app com.loho.elimupepe
```

## API Integration

Main learner API base:
- `https://elimupepe.loholearning.co.ke/api`

Authentication:
- `POST /v1/auth/login`
- `GET /v1/auth/me`
- `GET /v1/auth/logout`

Learner endpoints used by categories:
- `GET /student/courses`
- `GET /student/books`
- `GET /student/elibrary`
- `GET /student/labs`
- `GET /student/quizzes`
- `GET /student/games`
- `GET /student/leaderboard`
- `GET /student/questions`

WebView SSO:
- `GET /student/webview-token`
- Returns `webview_login_url` that is loaded inside app WebView

Ebook cloud API base:
- `https://api-ebooks.loholearning.co.ke`

## Project Structure

- `lib/screens/` UI screens (login, home, categories, reader, webview)
- `lib/services/` auth, learner API, cloud sync, storage, database services
- `lib/models/` data models and menu model

## Run Locally

1. Install dependencies:

```bash
flutter pub get
```

2. Run on device/emulator:

```bash
flutter run --flavor staging --dart-define=ENV=staging
```

The app has two Android flavours, `prod` and `staging`, which install side by side. Every
`flutter run` and `flutter build` needs `--flavor <name> --dart-define=ENV=<name>`; the flavour and
`ENV` must match or the app refuses to start. See [docs/ENVIRONMENTS.md](docs/ENVIRONMENTS.md) for
environments, feature flags for the Phase 2A API, the staging install steps and build requirements
(JDK 17 and about 4 GB of free memory for Gradle).

## Build APK

Release build (production):

```bash
flutter build apk --release --flavor prod --dart-define=ENV=prod
```

Output:
- `build/app/outputs/flutter-apk/app-prod-release.apk`

Staging debug build for testers:

```bash
flutter build apk --debug --flavor staging --dart-define=ENV=staging
```

Output:
- `build/app/outputs/flutter-apk/app-staging-debug.apk`

## Tests

```bash
flutter analyze
flutter test
```

`test/design/goldens/` holds golden images at 360x780 dp, generated on Windows. Regenerate with
`flutter test --update-goldens test/design/goldens_test.dart` after an intended visual change.

## Access Model

Only users created in backend can access content.

Required:
- valid login credentials
- learner/student role assignment on backend
- successful token issuance from login API
