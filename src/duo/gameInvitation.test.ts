import { test } from 'node:test';
import assert from 'node:assert/strict';
import { nextProposal, proposalKey } from './gameInvitation.ts';
const now = Date.parse('2026-10-25T20:00:00Z');
const n = { id: 'n1', type: 'game_proposed', couple_id: 'ab', read_at: null, created_at: new Date(now).toISOString(), data: { session_id: '00000000-0000-4000-a000-000000000001' } };
test('proposition récente seulement, dans un de mes duos actifs', () => {
  assert.equal(nextProposal([n], ['ab'], new Set(), now), n);
  assert.equal(nextProposal([n], ['ac'], new Set(), now), undefined);
  assert.equal(nextProposal([{...n, read_at: 'read'}], ['ab'], new Set(), now), undefined);
  assert.equal(nextProposal([n], ['ab'], new Set(), now + 86400000), undefined);
});
test('fermer une proposition écarte ses duplications sans affecter les autres salons', () => {
  assert.equal(nextProposal([n, {...n, id:'n2'}], ['ab'], new Set([proposalKey(n)!]), now), undefined);
  assert.equal(proposalKey({...n, data: {session_id:'//evil.example'}}), null);
  assert.equal(proposalKey({...n, type:'message'}), null);
});
