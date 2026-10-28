import {createHash} from 'node:crypto';

export function lessonRevision(lesson) {
  return createHash('sha256').update(JSON.stringify(lesson.exercises)).digest('hex');
}
