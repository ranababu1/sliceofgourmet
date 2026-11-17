# Recipe App

## Overview

A simple and intuitive recipe app that allows users to search and explore various recipes. The app fetches its data from an external datasource, providing up-to-date recipes from different cuisines, ingredients, and cooking techniques.

### Key Features

* Search Functionality: Users can search for recipes based on ingredients, cuisine, or recipe name.
* External Data Integration: The app retrieves recipes from a reliable external API, ensuring a constantly refreshed set of recipes.
* Filter Options: Sort recipes by difficulty, cooking time, and dietary restrictions (e.g., vegetarian, gluten-free).
* Favorites: Users can mark their favorite recipes for easy access later.

## Data source

Recipes come from the sog-recipes plugin on sliceofgourmet.com (read only):

- `GET /wp-json/sog/v1/recipes` list cards (`page`, `per_page`, `search`, `category`)
- `GET /wp-json/sog/v1/recipes/{id}` full recipe
- `GET /wp-json/wp/v2/categories` categories, `GET /wp-json/wp/v2/posts?slug=` for shared links

Test fixtures in `test/fixtures` are captured from the live API.

## Release

```
flutter test
flutter build appbundle --release   # Android
flutter build ipa --release         # iOS, on a Mac
```
