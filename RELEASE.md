# Releasing Slice of Gourmet

Package / bundle ID: `dev.imrn.sliceofgourmet`. Version lives in `pubspec.yaml` as `name+build`
(now `1.2.0+3`). Bump the build number for every store upload.

## 1. Android

### Upload key (once)

```
keytool -genkey -v -keystore ~/keys/sliceofgourmet-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Back the .jks and its passwords up somewhere safe. Then copy `android/key.properties.example`
to `android/key.properties` (gitignored) and fill it in. Without that file, release builds are
signed with the debug key, which is fine for testing but Play will reject it.

### Build

```
flutter build appbundle --release
# build/app/outputs/bundle/release/app-release.aab
```

Already set: targetSdk 36 (Play requirement since 31 Aug 2026), minSdk 24, R8 shrinking, only the
INTERNET permission, app name "Slice of Gourmet", adaptive icon, backups off.

### Play Console

1. Create the app, upload the .aab to Internal testing first. Keep Play App Signing on.
2. Store listing: short and full description, 512 px icon, 1024x500 feature graphic,
   at least 2 phone screenshots.
3. App content:
   - Privacy policy URL (required, see section 4).
   - Ads: no. Target audience: 13+ (or 18+). Content rating questionnaire.
   - Data safety:
     - No data collected without sign-in.
     - With Google sign-in and the optional consent box ticked: Name, Email address and Device
       model are collected for Analytics, sent over HTTPS, not shared, not sold.
     - Users can turn the consent off in Profile. Say how they can ask for deletion (email).
4. App links (optional): to open shared recipe links in the app, put
   `https://sliceofgourmet.com/.well-known/assetlinks.json` on the site with the SHA-256 of the
   Play app signing key (Play Console > Setup > App signing shows a ready made file).

## 2. iOS (on a Mac with Xcode)

1. `flutter build ios --release` once, then open `ios/Runner.xcworkspace`.
2. Runner target > Signing & Capabilities: choose your Team, keep automatic signing. Xcode adds the
   Associated Domains capability from `Runner/Runner.entitlements`. If you do not want universal
   links yet, delete that capability.
3. Already set: iOS 15.0 minimum, display name "Slice of Gourmet", app icons, PrivacyInfo.xcprivacy,
   no permission prompts (the app uses no camera, photos, location or tracking),
   ITSAppUsesNonExemptEncryption = NO.
4. `flutter build ipa --release`, upload with Xcode Organizer or Transporter.
5. App Store Connect:
   - Listing: name, subtitle, description, keywords, support URL, 6.9 inch and 6.5 inch iPhone
     screenshots (and iPad if you keep iPad support).
   - Privacy policy URL (required).
   - App Privacy labels: Name and Email Address, linked to the user, used for Analytics, not
     used for tracking, only when the user signs in and opts in. Otherwise "Data not collected".
   - Review notes: sign-in is optional. See section 3 for guideline 4.8.
6. Universal links (optional): put `https://sliceofgourmet.com/.well-known/apple-app-site-association`
   on the site:
   `{"applinks":{"details":[{"appIDs":["TEAMID.dev.imrn.sliceofgourmet"],"components":[{"/":"/*/*/"}]}]}}`
   served as `application/json` with no redirect.
7. Later: Flutter now generates new iOS apps with the UIScene lifecycle. Apple will require it in a
   future SDK. Migrate when that is announced (AppDelegate + SceneDelegate, see Flutter docs).

## 3. Google sign-in (do this yourself, nothing was created)

The code is ready and fails safely: on iOS, sign-in is hidden and nothing is gated until a client
ID is supplied. On Android a missing OAuth client shows "Google sign-in is not available right now
(configuration error)" instead of crashing.

In Google Cloud Console (APIs & Services > Credentials), in one project:

1. OAuth consent screen: app name, support email, the privacy policy URL, scopes `email`,
   `profile`, `openid`. Publish it (In production) so any Google account can sign in.
2. Android OAuth clients, package `dev.imrn.sliceofgourmet`, one per SHA-1:
   - Debug: `keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android`
   - Upload: `keytool -list -v -alias upload -keystore ~/keys/sliceofgourmet-upload.jks`
   - Play app signing: Play Console > Setup > App signing > App signing key certificate SHA-1.
     This is the one real users hit; without it sign-in fails for Play installs.
3. iOS OAuth client, bundle ID `dev.imrn.sliceofgourmet`. Note the client ID and its iOS URL scheme
   (the reversed client ID).
4. Wire the iOS client in:
   - Copy `ios/Flutter/GoogleSignIn.xcconfig.example` to `ios/Flutter/GoogleSignIn.xcconfig` and set
     `GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.XXXX`. This becomes the URL scheme
     in Info.plist.
   - Build with `--dart-define=GOOGLE_IOS_CLIENT_ID=XXXX.apps.googleusercontent.com`. The app passes
     it to the SDK as the client ID (no GIDClientID or GoogleService-Info.plist needed).
5. No google-services.json or GoogleService-Info.plist is needed. There is no Firebase and no
   backend token check, so no web client ID is needed either.

App Store guideline 4.8: an app that offers Google sign-in must also offer Sign in with Apple (or
another login that meets 4.8). Pick one before submitting to Apple:

- Recommended: ship iOS without Google sign-in (just do not pass `GOOGLE_IOS_CLIENT_ID`). Every
  feature then works without an account, which also avoids guideline 5.1.1 issues about forcing
  sign-in. Add Google plus Sign in with Apple together in a later version.
- Or add Sign in with Apple now (package `sign_in_with_apple`, the capability in Xcode) next to
  Google.

## 4. Privacy policy (blocking)

The site has no privacy policy page yet, and both stores require one. The app links to
`https://sliceofgourmet.com/privacy-policy/` (`kPrivacyPolicyUrl` in `lib/core/constants.dart`).
Publish a page at that address (WordPress > Settings > Privacy can generate a draft) covering:
the app, optional Google sign-in, the name, email and device model sent to the signup sheet,
how to ask for deletion, and a contact email.

## 5. Optional build settings

- `--dart-define=SHEETS_WEBHOOK_URL=...` and `SHEETS_WEBHOOK_SECRET=...` turn on the opt in signup
  log. Without them nothing is sent.
- `--dart-define=SOG_BASE_URL=...` points the app at another copy of the site (staging, tests).

## 6. Scalability: keeping load off WordPress

App side:

- Full local catalog (Hive). Home, browse, search and saved read only the cache; search runs on
  the device. No polling and no per screen fetches.
- First run: 5 requests of 50 recipes, then manifest, ids and categories.
- After that, one `GET /sog/v1/manifest` (a few hundred bytes) at most every 6 hours, on app
  resume, or on a manual refresh limited to once per 15 minutes (pull to refresh shares the
  limit). It is sent with If-None-Match, so the usual answer is an empty 304.
- When the catalog changed, the app fetches the id list conditionally, diffs it, and downloads
  only the changed recipes with `modified_after`. Deleted recipes are removed locally.
- A full recipe is fetched once and again only when its modified time changes.
- Failures back off exponentially (2, 4, 8 ... minutes up to 6 hours) with random jitter, so a
  site outage does not get a thundering herd when it comes back.
- Images load from the Jetpack Photon CDN (i0.wp.com) at fixed widths (320 to 1440 px), decoded at
  display size and cached on disk. They never hit the Hostinger server.

Server side (sog-recipes plugin 0.1.9):

- Every sog/v1 GET sends ETag, Cache-Control (`public, max-age`, `stale-while-revalidate=3600`,
  `stale-if-error=86400`) and answers If-None-Match with 304. Single recipes also honor
  If-Modified-Since.
- LiteSpeed Cache stores sog/v1 responses (tag `sog_api`), so repeat requests are served without
  PHP or MySQL. Verified with curl: second request `x-litespeed-cache: hit`, conditional requests
  `304` with an empty body.
- Saving, trashing, or publishing a post, changing recipe meta, or editing a category purges the
  `sog_api` tag and the manifest transient, so the next manifest check sees the change.
- The id list is one indexed query cached for a day and cleared on change.

Rough cost per active user: about 4 manifest checks a day, almost all 304 cache hits. 100k daily
users is about 400k tiny cached hits a day, well within LiteSpeed on shared hosting. If traffic
grows past that, put Cloudflare in front and cache `/wp-json/sog/v1/*` at the edge; the headers
are already correct for it.
