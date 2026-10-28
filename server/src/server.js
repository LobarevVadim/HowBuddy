import dotenv from 'dotenv';
import {createHowBuddyApi} from './app.js';

dotenv.config();
createHowBuddyApi().start().catch((error) => {
  console.error('Could not initialize the API.', error);
  process.exitCode = 1;
});