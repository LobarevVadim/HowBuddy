# Lesson content database

The API reads lesson content from PostgreSQL and keeps an in-memory snapshot for requests. It no longer reads lesson JSON files while serving routes. The files under `server/data/` are seed/import sources only.

The content database has one `lesson_content_by_language` table with one JSONB row per language (`en`, `fr`, `hi`, `es`, `ru`). This preserves the current lesson JSON structure and API responses without splitting nested exercises into many relational tables.

## Render setup

1. In Render, create a PostgreSQL database named `howbuddy-content-db` in the **same region** as `howbuddy-demo-api`.
2. Copy its **Internal Database URL**.
3. In the `howbuddy-demo-api` service, add `CONTENT_DATABASE_URL` and paste that URL.
4. Save and redeploy the API.

The API creates the content table on startup and inserts missing language rows from the five checked-in JSON seed files. Existing database rows are left intact. It reloads the cached content from PostgreSQL at startup and every five minutes. The normal lesson endpoints, language selection, notifications, and Bobo continue to receive the same JSON structure as before.

If `CONTENT_DATABASE_URL` is empty, the API temporarily uses `DATABASE_URL` so an unset content database does not prevent deployment. Set `CONTENT_DATABASE_URL` to move content into the separate database.

Render currently permits only one active Free Postgres database per workspace, and a Free database expires after 30 days. Since HowBuddy already has a Free account database, a second independent Render database requires choosing a paid database plan. Do not choose a paid plan unless you accept its cost. See [Render's current Free instance limits](https://render.com/docs/free).

## Importing revised lesson files

After editing one or more files under `server/data/`, run this from PowerShell:

```powershell
cd C:\Users\Konst\OneDrive\Desktop\Codex\HowBuddy\server
$env:CONTENT_DATABASE_URL = "PASTE THE CONTENT DATABASE EXTERNAL URL HERE"
npm run content:import
Remove-Item Env:CONTENT_DATABASE_URL
```

The importer validates the JSON and upserts all five language records. It uses the external database URL because it runs on your laptop. Do not paste that URL into GitHub or commit it to `.env.example`. The API refreshes its in-memory snapshot within five minutes.

For a local API, set `CONTENT_DATABASE_URL` in the ignored `server/.env` file. If it is omitted, local development uses `DATABASE_URL`.

## Verification

- Check the API's `/health` endpoint to confirm the API remains online.
- Open the Topics/tree page in each language and open a lesson; the existing `/lessons/tree` and `/lessons/exercises` responses remain unchanged.
- To verify the database directly, connect to the content database and run:

```sql
SELECT language_code, jsonb_array_length(content->'roots') AS root_count,
       updated_at
FROM lesson_content_by_language
ORDER BY language_code;
```

Expect one row per language. The API cache refreshes from this table every five minutes.
