# Android Release Signing

This project now supports proper Android release signing through `android/key.properties`.

## Why this matters

Android only allows an installed app to be updated by another APK or AAB signed with the same certificate.

If users already have your app installed and the new build is signed with a different key, Android rejects the update with errors like:

`App not installed as package conflicts with an existing package.`

## One-time setup

1. Create or restore the release keystore you intend to keep using for all future updates.
2. Place the keystore file somewhere under `android/`, for example:

`android/app/upload-keystore.jks`

3. Create `android/key.properties` with this content:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=app/upload-keystore.jks
```

## Create a new keystore

If you do not already have one, generate it with:

```bash
keytool -genkeypair -v \
  -keystore android/app/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

## Important

- If users already installed older APKs, you must sign updates with the same original keystore used for those APKs.
- If the previous installed app came from Google Play, updates should normally continue through Google Play.
- If the old keystore is lost, existing sideloaded installs usually cannot be updated in place and may require uninstalling first.

## Build commands

The app has `prod` and `staging` flavours (see `docs/ENVIRONMENTS.md`). Release builds are the
`prod` flavour and keep the application ID `com.loho.elimupepe`; signing is unchanged.

```bash
flutter build apk --release --flavor prod --dart-define=ENV=prod
```

or

```bash
flutter build appbundle --release --flavor prod --dart-define=ENV=prod
```

Output names now include the flavour: `app-prod-release.apk` and
`build/app/outputs/bundle/prodRelease/app-prod-release.aab`.

## Automated CI/CD (GitHub Actions)

This project includes a `.github/workflows/google_play_deploy.yml` workflow for automated deployment. To use it, you must configure the following **GitHub Secrets** in your repository:

1.  **`ANDROID_KEYSTORE_BASE64`**: The base64-encoded string of your `.jks` file.
    - Generate it locally with: `base64 -w 0 android/app/upload-keystore.jks > b64_keystore.txt`
    - Copy the contents of `b64_keystore.txt` into the secret.
2.  **`ANDROID_STORE_PASSWORD`**: The `storePassword` from your `key.properties`.
3.  **`ANDROID_KEY_PASSWORD`**: The `keyPassword` from your `key.properties`.
4.  **`ANDROID_KEY_ALIAS`**: The `keyAlias` from your `key.properties` (e.g., `upload`).
5.  **`SERVICE_ACCOUNT_JSON`**: The JSON key for a Google Play Console Service Account.
    - You need to create a Service Account in the Google Cloud Console and link it to your Play Console under **Users & Permissions**.
    - The Service Account must have "Service Account User" and "Release Manager" permissions for your app.

### Triggering a Release
The workflow triggers automatically when you push a new version tag (e.g., `git tag v1.2.6 && git push origin v1.2.6`). It can also be triggered manually from the "Actions" tab.
