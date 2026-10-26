# Lesson content database and Content Studio

HowBuddy uses one PostgreSQL database. Account, progress, notification, support, and lesson content all remain in the existing Render database. No second database or service is needed.

The original `lesson_content_by_language` table remains as a rollback/import source, with one legacy JSONB snapshot per language (`en`, `fr`, `es`, `hi`, `ru`). Normalized content uses:

- `content_topics` and `content_topic_translations` for topic IDs, translated questions, and language-specific tree structure.
- `content_tree_roots` for each language's ordered roots.
- `content_lessons` and `content_lesson_translations` for lesson order, language-specific source, title, and text.
- `content_exercises` for one row per localized exercise. Each row has an individual JSONB payload and one of the twelve constrained Flutter exercise types.
- Draft tables for unpublished changes and `content_revisions` for published lesson/exercise versions.

Languages currently differ in their topic counts, lesson counts, and exercise types. The normalized schema preserves these differences rather than forcing all languages into English's structure. The API rebuilds the existing `roots`/`nodes` and `{topic, content, exercises}` response formats, so Flutter's lesson loading contract is unchanged.

## First migration

Deploy the API and web admin panel code. Sign in to the private admin panel with an address listed in `ADMIN_EMAILS`, open **Content**, and select **Migrate existing content once**. The API validates each language independently, then copies all five trees, lesson mappings, and exercise sets inside one PostgreSQL transaction. If validation fails, the transaction rolls back and the legacy rows remain unchanged. On success, the API refreshes its in-memory content and reads from the normalized tables.

The migration action refuses to run again once normalized topics exist. Keep the legacy table until you have checked the tree and opened lessons in all five languages. Do not remove it during the initial rollout.

## Using Content Studio

Open **Content**, choose a topic and lesson, and select a language. Lesson text and exercises can be saved as drafts; drafts are visible only in the admin panel. **Publish** exposes the change through the API and refreshes the content cache without a deployment.

Use **Add lesson** to create a draft under an existing topic in the selected language. Add and publish at least one exercise in that language, then publish the lesson. Each language keeps its own topic tree and lesson count. When a lesson translation is missing, English is used as the fallback. Existing language-specific exercise sets remain independent. An exercise's type is fixed after creation so its saved interaction data continues to match Flutter grading.

The editor provides the fields used by the app: prompt, options, accepted/correct answers, correct order, pairs, paragraph segments, categories, and explanation. Fill-in-the-blank paragraph segments are separated with `|`; matching/categorization/cause-and-effect/Venn pairs use one `left => right` pair per line. The API validates the required fields for the selected type.

## Render and verification

No second database or `CONTENT_DATABASE_URL` variable is required. Render's existing `DATABASE_URL` points to `howbuddy-demo-db`. API startup creates the content tables and loads English. Other languages load from the same database on demand. Before migration, the API uses the legacy table; afterward, it reads normalized rows. Publishing refreshes the cache immediately. Student requests do not read lesson files.

In the admin panel, confirm Content shows nonzero topic, lesson, exercise, and language counts. You can also query the database:

```sql
SELECT language_code, COUNT(*) AS published_exercises
FROM content_exercises
WHERE status = 'published'
GROUP BY language_code
ORDER BY language_code;
```

Check the tree and open a lesson in every language. Keep the legacy snapshots in `lesson_content_by_language` while verifying.
