# HowBuddy content database and admin editor

Lesson content is served from normalized tables in the existing PostgreSQL database. Each exercise is a separate JSONB record with a matching `exercise_type`. The Flutter API response remains the existing `roots` and `nodes` structure.

## Database cleanup

On API startup, `content_schema.sql` creates/updates the normalized schema. Once at least one normalized topic exists, it removes the old `lesson_content_by_language` snapshots. It also removes the obsolete lesson and exercise draft tables. The migration action and endpoint have been removed because the content migration was completed and verified.

## Editing and publishing

Open the protected support admin app and choose **Content**. Select a language, topic, and lesson, edit the content, and publish. Publishing refreshes the API's in-memory content cache immediately; no redeploy is needed for new content.

**Publish selected language** changes only the chosen language. **Publish all 5 languages** copies the current lesson or exercise text, answers, and explanation into English, French, Spanish, Hindi, and Russian. It does not translate text. Review and translate each language separately by selecting it in the language menu.

Deleting a lesson removes its exercises and revisions and compacts the remaining lesson order. Deleting an exercise removes it and its revision history. These actions are permanent.

## Verification

After deployment, open the content editor, publish a small change in one language, and verify the matching language in the web app. Then test the all-language option only with content you intend to copy verbatim, and inspect each language in the app. Confirm deletions affect only the selected exercise or the selected lesson and its attached content.
