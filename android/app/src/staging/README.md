# Staging flavour files

`google-services.json` here is a COPY of the production client with the package name changed to
`com.loho.elimupepe.staging`, so the Gradle build can complete. It is not a registered Firebase app:
the staging manifest and the Dart startup code disable Crashlytics, Performance and Analytics
collection, so nothing is sent.

When the staging Android app is registered in Firebase project `elimupepe-8acc4`, replace this file
with the downloaded one and remove the three `*_collection_enabled` meta-data entries from
`AndroidManifest.xml` in this folder and the `isStaging` checks in `lib/main.dart`.
