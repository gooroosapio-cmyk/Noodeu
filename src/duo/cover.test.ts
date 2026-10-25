import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateCover, COVER_MAX_BYTES } from './cover.ts';
test('couverture : seuls les formats image bornés sont acceptés', () => {
  assert.equal(validateCover({type:'image/jpeg', size:12000}), null);
  for (const f of [{type:'image/svg+xml',size:12},{type:'text/html',size:12},{type:'image/png',size:0},{type:'image/png',size:COVER_MAX_BYTES+1}]) assert.ok(validateCover(f));
});
