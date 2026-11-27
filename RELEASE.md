# Releasing Slice of Gourmet

Package / bundle ID: `dev.imrn.sliceofgourmet`. Version lives in `pubspec.yaml` as `name+build`
(now `1.2.1+4`). Bump the build number for every store upload.

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
   - Data safety: Data is not collected.
     The app has no account and no analytics or ads. A first name, if the user types one, and
     their saved recipes are stored only on the device. Nothing personal is sent to you, to
     Google, or to the website. The app only downloads public recipes and images from
     sliceofgourmet.com.
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
   - App Privacy labels: Data not collected.
     A first name and saved recipes stay in on-device storage (UserDefaults / app files) and
     never leave the phone. Declare UserDefaults (CA92.1) and file timestamps (C617.1) in
     PrivacyInfo.xcprivacy; that file is already in the project.
   - Review notes: there is no sign-in and no account. Guideline 4.8 does not apply.
6. Universal links (optional): put `https://sliceofgourmet.com/.well-known/apple-app-site-association`
   on the site:
   `{"applinks":{"details":[{"appIDs":["TEAMID.dev.imrn.sliceofgourmet"],"components":[{"/":"/*/*/"}]}]}}`
   served as `application/json` with no redirect.
7. Later: Flutter now generates new iOS apps with the UIScene lifecycle. Apple will require it in a
   future SDK. Migrate when that is announced (AppDelegate + SceneDelegate, see Flutter docs).

## 3. No account

The app does not use Google sign-in, Sign in with Apple, or any other account. Every tab is
open to everyone. The user can type a first name (skippable) so the home screen can say
"Hi, {name}". That name and their shortlist stay on the device in SharedPreferences / Hive.

Do not create OAuth clients or add google-services.json / GoogleService-Info.plist for this
version.

## 4. Privacy policy (blocking)

The site has no privacy policy page yet, and both stores still require a URL even when no
personal data is collected. The app links to
`https://sliceofgourmet.com/privacy-policy/` (`kPrivacyPolicyUrl` in `lib/core/constants.dart`).
Publish a page at that address covering: the app has no account; a name and saved recipes stay
on the device and are not sent anywhere; the app downloads public recipes and images from the
site; and a contact email.

## 5. Optional build settings

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
