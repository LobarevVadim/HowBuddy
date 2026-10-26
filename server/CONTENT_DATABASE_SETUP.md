# Lesson content table

HowBuddy uses one PostgreSQL database. Account, progress, notification, and support data remain in their existing tables. Lesson content lives in a separate `lesson_content_by_language` table in that same database.

The table has one JSONB row per language (`en`, `fr`, `hi`, `es`, `ru`). It preserves the existing lesson JSON structure, including the topic tree, lessons, and exercises. The API loads English at startup, then loads a learner's selected language from PostgreSQL on first use. API startup and lesson requests do not read lesson files.

The temporary import route has been removed. The content database is now the source of truth. The prior JSON files are preserved in Git history. To import another JSON export, place all five files in a private directory outside the repository, set `DATABASE_URL` and `LESSON_CONTENT_DIR` in `server/.env`, and run `node src/import_lesson_content.js` from `server`. Do not commit database credentials or lesson exports containing unpublished material.

## Render

No second database or `CONTENT_DATABASE_URL` variable is required. Render's existing `DATABASE_URL` points to `howbuddy-demo-db`. On API startup, the server ensures the content table exists and loads English. Other languages load on demand from the same table. If the English content row is missing, API startup fails clearly.

## Verify the content rows

Connect to the existing `howbuddy-demo-db` and run:

```sql
SELECT language_code,
       jsonb_array_length(content->'roots') AS root_count,
       updated_at
FROM lesson_content_by_language
ORDER BY language_code;
```

Expect five rows: `en`, `fr`, `hi`, `es`, and `ru`. Then open the Topics/tree page in each language and open a lesson. The API's existing lesson endpoints keep their response format.
