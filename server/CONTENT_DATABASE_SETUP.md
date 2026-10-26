# Lesson content table

HowBuddy uses one PostgreSQL database. Account, progress, notification, and support data remain in their existing tables. Lesson content lives in a separate `lesson_content_by_language` table in that same database.

The table has one JSONB row per language (`en`, `fr`, `hi`, `es`, `ru`). It preserves the existing lesson JSON structure, including the topic tree, lessons, and exercises. The API reads this table into memory once at startup and keeps that snapshot until the next API restart or redeploy. API startup and lesson requests do not read files from `server/data/`.

## Populate the table

The importer creates the table if needed and imports all five current JSON files. From PowerShell:

```powershell
cd C:\Users\Konst\OneDrive\Desktop\Codex\HowBuddy\server
npm run content:import
```

The importer uses `DATABASE_URL` from `server/.env` (or the current environment). For the Render database, use its **External Database URL** temporarily in `server/.env` while running the import from your computer. Keep that file private and do not commit it. The import command updates the existing five language rows, so run it again whenever you change lesson content in the JSON files.

## Render

No second database or `CONTENT_DATABASE_URL` variable is required. Render's existing `DATABASE_URL` points to `howbuddy-demo-db`. On API startup, the server ensures the content table exists and loads it. The table must be populated before deploying the code that requires database-backed lessons; otherwise startup reports that English lesson content is missing.

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
