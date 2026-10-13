# Environments, flavours and feature flags

Two Android product flavours, each with its own `ENV`:

| Flavour | applicationId | `--dart-define=ENV` | API host |
|---|---|---|---|
| `prod` | `com.loho.elimupepe` (unchanged) | `prod` | `https://elimupepe.loholearning.co.ke` |
| `staging` | `com.loho.elimupepe.staging` | `staging` | `https://staging.loholearning.co.ke` |

Both can be installed on one phone. The staging app is labelled "Elimu Pepe Staging".
The flavour and `ENV` must agree. A mismatch makes the app throw at start-up
(`AppConfig.resolve`), so a prod build can never talk to staging by a typo.

## Commands

```bash
# run
flutter run --flavor staging --dart-define=ENV=staging
flutter run --flavor prod    --dart-define=ENV=prod

# debug APK for testers (staging)
flutter build apk --debug --flavor staging --dart-define=ENV=staging
# -> build/app/outputs/flutter-apk/app-staging-debug.apk

# release (unchanged signing; see ANDROID_RELEASE_SIGNING.md)
flutter build apk       --release --flavor prod --dart-define=ENV=prod
flutter build appbundle --release --flavor prod --dart-define=ENV=prod
# -> build/app/outputs/flutter-apk/app-prod-release.apk
# -> build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

Because flavours exist, every `flutter run/build` needs `--flavor`, and release artefact
names now contain `prod` (for example `app-prod-release.apk`).

## Installing the staging build on a phone

1. Build the staging APK (command above) or take it from whoever built it.
2. USB: enable Developer options and USB debugging on the phone, then
   `adb install -r build/app/outputs/flutter-apk/app-staging-debug.apk`.
3. Without USB: copy the APK to the phone (Drive, WhatsApp, cable), open it in Files and allow
   "install unknown apps" for that app when asked.
4. It installs next to the production app. Log in with a staging account (staging is a copy of
   production data and uses the same logins).

## Firebase on staging

`com.loho.elimupepe.staging` is not registered in Firebase project `elimupepe-8acc4` yet.
`android/app/src/staging/google-services.json` is a copy of the production client with the
package name changed so the build completes, and the staging manifest and `lib/main.dart`
switch Crashlytics, Performance and Analytics collection off for staging.
When the staging app is registered, replace that JSON and remove the three
`*_collection_enabled` entries in `android/app/src/staging/AndroidManifest.xml` and the
`isStaging` check in `lib/main.dart`.

## Phase 2A (App API v1) feature flags: on for staging, off for prod

The server keeps every `/api/app/v1` path answering 404 until `APP_API_ENABLED` is turned on at
cut-over. Contracts: `docs/api/openapi.yaml`, tag "App API v1", on `origin/docs/api` (a6a0afaa).

| Flag | Effect when `true` |
|---|---|
| `A11Y_REMOTE_SYNC` | Accessibility settings sync through `GET/PUT /api/app/v1/me/accessibility` |
| `TOKEN_REFRESH` | `ServerRefresh` uses `POST /api/app/v1/auth/refresh` on 401 and ahead of expiry |
| `APP_API_V1_LOGIN` | Login uses `POST /api/app/v1/auth/{student,parent,teacher}/login` |
| `APP_API_V1` | All the flags above, plus `APP_CONFIG`. Default: `true` for the staging flavour, `false` for prod; `--dart-define=APP_API_V1=true\|false` overrides it |

Staging needs no extra define (`flutter run --flavor staging --dart-define=ENV=staging`). Prod stays off until the
production cut-over; to try it against prod anyway add `--dart-define=APP_API_V1=true`.
Turn the flags on together: the new login returns the 30 day access token and the refresh token
that the refresher needs, and the old login returns a 1 year token with no refresh token.

## Build requirements

Gradle 8.14 needs JDK 17 to 21. Android Studio's bundled JDK on this machine is 25, which Gradle
8.14 rejects ("Java/Gradle incompatibility"). Point Flutter at a JDK 17:
`flutter config --jdk-dir="<path to jdk-17>"`.
