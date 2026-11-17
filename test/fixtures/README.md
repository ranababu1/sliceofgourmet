Captured from the live API (read only) on 18 Nov 2026:

- `recipes_list.json`: `GET /wp-json/sog/v1/recipes?per_page=3`
- `recipes_featured.json`: `GET /wp-json/sog/v1/recipes?per_page=3&category=featured`
- `recipes_sparse.json`: list items 1931 (no photo, no summary), 2623 (cook 0), 1127 (servings 0, yield only)
- `recipe_<id>.json`: `GET /wp-json/sog/v1/recipes/<id>`
  - 3574 complete, 2640 ingredient groups and notes, 2072 step photos, 2310 `&` in text
- `recipe_not_found.json`: body of the 404 for an unknown id
- `categories.json`: `GET /wp-json/wp/v2/categories?per_page=100&hide_empty=true&_fields=id,name,slug,count,parent`
- `post_by_slug.json`: `GET /wp-json/wp/v2/posts?slug=chapli-kabab&_fields=id,link`
