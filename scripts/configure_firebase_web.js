const {readFileSync, writeFileSync} = require('node:fs');

const target = process.argv[2];
if (!target) throw new Error('Pass the built Firebase service-worker path.');

const required = ['FIREBASE_API_KEY', 'FIREBASE_PROJECT_ID', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_WEB_APP_ID'];
const missing = required.filter((name) => !process.env[name]);
if (missing.length) {
  console.log(`Web push worker not configured (missing ${missing.join(', ')}).`);
  process.exit(0);
}

const config = {
  apiKey: process.env.FIREBASE_API_KEY,
  projectId: process.env.FIREBASE_PROJECT_ID,
  messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.FIREBASE_WEB_APP_ID,
  authDomain: process.env.FIREBASE_AUTH_DOMAIN || undefined,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || undefined,
};
const worker = readFileSync(target, 'utf8').replace(
  'const firebaseConfig = null;',
  `const firebaseConfig = ${JSON.stringify(config)};`,
);
writeFileSync(target, worker);
