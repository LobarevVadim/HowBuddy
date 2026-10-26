# HowBuddy content database and admin editor

Lesson content is served from normalized tables in the existing PostgreSQL database. Each exercise is a separate JSONB record with a matching `exercise_type`. The Flutter API response remains the existing `roots` and `nodes` structure.

## Database cleanup

On API startup, `content_schema.sql` creates/updates the normalized schema. Once at least one normalized topic exists, it removes the old `lesson_content_by_language` snapshots. It also removes the obsolete lesson and exercise draft tables. The migration action and endpoint have been removed because the content migration was completed and verified.

## Editing and publishing

Open the protected support admin app and choose **Content**. Select a language, topic, and lesson, edit the content, and publish. Publishing refreshes the API's in-memory content cache immediately; no redeploy is needed for new content.

**Publish only [language]** changes only the chosen language. **Translate + publish all 5** keeps that source language and uses Google Cloud Translation to create the other four language versions. Exercise JSON structure and exercise type are preserved; learner-facing strings, including prompts, choices, accepted answers, and explanations, are translated. Review translations before learners use them.

The **Translate whole topic to all 5** action translates the selected topic question plus every published lesson and exercise available in the selected source language. It replaces matching translations in the other four languages, creates missing translated entries, and deletes target-language lesson or exercise entries that are not present in the selected source. Revision snapshots are retained for recovery.

### Google Cloud Translation setup

Set `GOOGLE_TRANSLATE_API_KEY` on the Render **API service** only. Enable the Cloud Translation API and billing in the Google Cloud project, then restrict the API key to Cloud Translation. The key is never sent to the Flutter app or admin web app. If this variable is absent, publishing to all five languages returns a clear configuration error; publishing to one language continues to work.

Deleting a lesson removes its exercises and revisions and compacts the remaining lesson order. Deleting an exercise removes it and its revision history. These actions are permanent.

## Verification

After deployment, open the content editor, publish a small change in one language, and verify the matching language in the web app. Then test the all-language option only with content you intend to copy verbatim, and inspect each language in the app. Confirm deletions affect only the selected exercise or the selected lesson and its attached content.
