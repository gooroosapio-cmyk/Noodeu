// Changement de mot de passe (Réglages) : fonction serveur unique, aucune reconnexion côté navigateur.
// Réponses Supabase simulées ; aucun compte ni mot de passe réel.
import assert from 'node:assert/strict';
import {chromium} from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY = '1';
const {setup, duo} = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4173';
const browser = await chromium.launch({executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium'});
let failures = 0;
async function scenario(name, body) {
  const page = await browser.newPage({viewport: {width: 390, height: 844}});
  const calls = {token: 0, userUpdate: 0, rpc: []};
  await setup(page, duo);
  await page.route('**/auth/v1/token**', (r) => { calls.token++; return r.abort(); });
  await page.route('**/auth/v1/user', (r) => { if (r.request().method() === 'PUT') { calls.userUpdate++; return r.abort(); } return r.fallback(); });
  try {
    await page.goto(`${BASE}/reglages`);
    await page.getByRole('button', {name: 'Changer mon mot de passe'}).click();
    await body(page, calls);
    assert.equal(calls.token, 0, 'aucune reconnexion depuis le navigateur');
    assert.equal(calls.userUpdate, 0, 'aucune mise à jour directe du compte depuis le navigateur');
    console.log('PASS ' + name);
  } catch (e) { failures++; console.log('FAIL ' + name + ' : ' + e.message); }
  await page.close();
}
const fill = async (page, cur, next, conf = next) => {
  const s = page.locator('.sheet');
  await s.getByLabel('Mot de passe actuel').fill(cur);
  await s.getByLabel('Nouveau mot de passe').fill(next);
  await s.getByLabel('Confirmer le mot de passe').fill(conf);
  return s.getByRole('button', {name: /Enregistrer le nouveau/});
};
const rpc = (page, calls, handler) => page.route('**/rest/v1/rpc/change_password', async (r) => { calls.rpc.push(r.request().postDataJSON()); return handler(r); });

await scenario('confirmation différente : envoi bloqué', async (page, calls) => {
  await rpc(page, calls, (r) => r.fulfill({json: {ok: true}}));
  const save = await fill(page, 'ancien', 'nouveau-mdp', 'autre-chose');
  assert.ok(await save.isDisabled());
  await page.getByText('Les deux mots de passe ne sont pas identiques.').waitFor();
  assert.equal(calls.rpc.length, 0);
});
await scenario('mauvais mot de passe actuel : message précis, rien ne change', async (page, calls) => {
  await rpc(page, calls, (r) => r.fulfill({json: {ok: false, error: 'wrong_password'}}));
  await (await fill(page, 'faux', 'nouveau-mdp')).click();
  await page.getByText('Le mot de passe actuel ne correspond pas.').waitFor();
  assert.deepEqual(calls.rpc[0], {p_current: 'faux', p_new: 'nouveau-mdp'});
});
await scenario('panne réseau : jamais présentée comme un mauvais mot de passe', async (page, calls) => {
  await rpc(page, calls, (r) => r.abort('internetdisconnected'));
  await (await fill(page, 'ancien', 'nouveau-mdp')).click();
  await page.getByText(/Modification impossible pour le moment/).waitFor();
  assert.equal(await page.getByText('Le mot de passe actuel ne correspond pas.').count(), 0);
});
await scenario('trop d’essais : blocage annoncé', async (page, calls) => {
  await rpc(page, calls, (r) => r.fulfill({json: {ok: false, error: 'too_many_attempts'}}));
  await (await fill(page, 'ancien', 'nouveau-mdp')).click();
  await page.getByText(/Trop d’essais/).waitFor();
});
await scenario('succès : feuille fermée, confirmation', async (page, calls) => {
  await rpc(page, calls, (r) => r.fulfill({json: {ok: true}}));
  await (await fill(page, 'ancien', 'nouveau-mdp')).click();
  await page.getByText('Mot de passe modifié.').waitFor();
  assert.equal(await page.locator('.sheet').count(), 0);
});
await scenario('déconnexion pendant la requête : réponse ignorée, aucune reconnexion', async (page, calls) => {
  let release;
  await rpc(page, calls, (r) => new Promise((ok) => { release = () => ok(r.fulfill({json: {ok: true}})); }));
  await (await fill(page, 'ancien', 'nouveau-mdp')).click();
  await page.waitForFunction(() => document.querySelector('.sheet button[aria-busy="true"]'));
  // Autre onglet : déconnexion, diffusée par supabase-js sur le canal du jeton (BroadcastChannel).
  await page.evaluate(() => {
    const key = Object.keys(localStorage).find((k) => /^sb-.*-auth-token$/.test(k));
    localStorage.removeItem(key);
    new BroadcastChannel(key).postMessage({event: 'SIGNED_OUT', session: null});
  });
  await page.waitForURL((u) => !u.pathname.startsWith('/reglages'), {timeout: 5000});
  release();
  await page.waitForTimeout(500);
  assert.equal(await page.getByText('Mot de passe modifié.').count(), 0, 'aucun succès affiché après déconnexion');
  assert.equal(await page.evaluate(() => Object.keys(localStorage).some((k) => /^sb-.*-auth-token$/.test(k))), false, 'pas de session recréée');
});
await browser.close();
if (failures) process.exitCode = 1;
