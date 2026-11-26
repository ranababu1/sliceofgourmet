# Slice of Gourmet

Recipe app for [sliceofgourmet.com](https://sliceofgourmet.com), built with Flutter for Android and iOS.

## Features

- Every recipe from the site, cached on the device and usable offline
- Search, categories, saved recipes and a clean step by step recipe view
- Light and dark themes, subtle motion that respects the system reduce motion setting
- Optional Google sign-in

## How data loads

Recipes come from the `sog-recipes` plugin on the site (read only):

- `GET /wp-json/sog/v1/manifest` small catalog fingerprint, checked before any sync
- `GET /wp-json/sog/v1/recipes` recipe cards and full recipes (`page`, `per_page`, `modified_after`, `full`)
- `GET /wp-json/sog/v1/recipes/ids` every id with its modified time
- `GET /wp-json/sog/v1/recipes/{id}` one full recipe
- `GET /wp-json/wp/v2/categories` and `wp/v2/posts?slug=` for categories and shared links

First launch downloads the catalog in pages of 50 with a progress screen. After that the app checks
the manifest at most every 6 hours (or when the user taps refresh, limited to once per 15 minutes)
and only downloads recipes that changed. Screens read from the local cache. See RELEASE.md for details.

Test fixtures in `test/fixtures` are captured from the live API.

## Develop

```
flutter pub get
flutter analyze
flutter test
flutter run
```

## Release

See [RELEASE.md](RELEASE.md).
