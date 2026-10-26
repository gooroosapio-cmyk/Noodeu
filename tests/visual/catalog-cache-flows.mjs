// Vrais hooks React, HTTP Supabase simulé et sorties externes bloquées.
// Usage : node tests/visual/catalog-cache-flows.mjs (serveur Vite local éphémère).
import assert from 'node:assert/strict';
import { chromium, expect } from '@playwright/test';
import { createServer } from 'vite';

process.env.VITE_SUPABASE_URL = 'https://catalog-fixture.supabase.co';
process.env.VITE_SUPABASE_PUBLISHABLE_KEY = 'visual-test-placeholder';
const server = await createServer({ server: { host: '127.0.0.1', port: 0, strictPort: false }, logLevel: 'error' });
await server.listen();
const base = `http://127.0.0.1:${server.httpServer.address().port}`;
const html = await server.transformIndexHtml('/catalog-fixture', '<!doctype html><html><body><div id="root"></div><script type="module" src="/tests/visual/catalog-harness.mjs"></script></body></html>');
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
let failures = 0;

async function scenario(name, run) {
  const context = await browser.newContext({ serviceWorkers: 'block' });
  const page = await context.newPage();
  page.setDefaultTimeout(5000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const favorites = new Map();
  const reads = [];
  const mutations = [];
  const heldReads = [];
  let holdAccount = null;
  await page.routeWebSocket('**', socket => socket.close());
  await page.route('**/*', route => new URL(route.request().url()).origin === base ? route.continue() : route.abort());
  await page.route(`${base}/catalog-fixture`, route => route.fulfill({ contentType: 'text/html', body: html }));
  await page.route('https://catalog-fixture.supabase.co/**', async route => {
    const request = route.request();
    const url = new URL(request.url());
    if (!url.pathname.endsWith('/game_favorites')) return route.fulfill({ json: [] });
    if (request.method() === 'GET') {
      const account = url.searchParams.get('user_id').replace(/^eq\./, '');
      const body = [...(favorites.get(account) ?? [])].map(game_id => ({ game_id }));
      reads.push(account);
      if (holdAccount === account) {
        holdAccount = null;
        heldReads.push({ account, release: () => route.fulfill({ json: body }) });
        return;
      }
      return route.fulfill({ json: body });
    }
    const payload = request.method() === 'POST' ? request.postDataJSON() : null;
    const account = payload?.user_id ?? url.searchParams.get('user_id').replace(/^eq\./, '');
    const gameId = payload?.game_id ?? url.searchParams.get('game_id').replace(/^eq\./, '');
    mutations.push({ account, gameId, settle: async (ok) => {
      if (ok) {
        const next = new Set(favorites.get(account) ?? []);
        if (request.method() === 'POST') next.add(gameId); else next.delete(gameId);
        favorites.set(account, next);
        await route.fulfill({ json: [] });
      } else {
        await route.fulfill({ status: 503, json: { code: 'fixture_failure', message: 'Écriture refusée dans la fixture' } });
      }
    } });
  });
  const view = name => page.locator(`[data-consumer="${name}"]`);
  const state = async name => JSON.parse(await view(name).locator('output').textContent());
  const show = async consumers => {
    await page.evaluate(consumers => window.catalogHarness.render(consumers), consumers);
    await expect(page.locator('[data-consumer]')).toHaveCount(consumers.length);
  };
  const settled = async name => expect.poll(async () => (await state(name)).loading).toBe(false);
  const expectFavorites = async (name, wanted) => expect.poll(async () => (await state(name)).favorites).toEqual(wanted);
  try {
    await page.goto(`${base}/catalog-fixture`);
    await page.waitForFunction(() => window.catalogHarness);
    await run({ page, favorites, reads, mutations, heldReads, hold: account => { holdAccount = account; }, view, state, show, settled, expectFavorites });
    assert.deepEqual(errors, []);
    console.log(`PASS ${name}`);
  } catch (error) {
    failures += 1;
    console.error(`FAIL ${name}: ${error.stack}`);
  } finally {
    await context.close();
  }
}

try {
  await scenario('requêtes et doubles clics fusionnés, consommateurs synchronisés', async ({ page, reads, mutations, view, show, settled, expectFavorites }) => {
    await show([{ name: 'a', userId: 'account-a' }, { name: 'b', userId: 'account-a' }]);
    await settled('a'); await settled('b');
    assert.equal(reads.length, 1);
    await view('a').locator('[data-action="one"]').click();
    await expectFavorites('b', ['game-one']);
    await view('b').locator('[data-action="one"]').click();
    await expect.poll(() => mutations.length).toBe(1);
    await mutations[0].settle(true);
    await expect.poll(() => page.evaluate(() => window.catalogWrites.length)).toBe(2);
    await expectFavorites('a', ['game-one']); await expectFavorites('b', ['game-one']);
  });
  await scenario('échec après navigation : la nouvelle fiche reçoit le rollback', async ({ mutations, view, show, settled, expectFavorites }) => {
    await show([{ name: 'old', userId: 'account-a' }]); await settled('old');
    await view('old').locator('[data-action="one"]').click();
    await expect.poll(() => mutations.length).toBe(1);
    await show([]);
    await show([{ name: 'new', userId: 'account-a' }]); await settled('new');
    await expectFavorites('new', ['game-one']);
    await mutations[0].settle(false);
    await expectFavorites('new', []);
  });
  for (const finishWriteFirst of [false, true]) {
    await scenario(`lecture tardive préserve le favori ${finishWriteFirst ? 'confirmé' : 'encore en écriture'}`, async ({ page, mutations, heldReads, hold, view, show, settled, expectFavorites }) => {
      await show([{ name: 'a', userId: 'account-a' }]); await settled('a');
      hold('account-a');
      await view('a').locator('[data-action="reload"]').click();
      await expect.poll(() => heldReads.length).toBe(1);
      await view('a').locator('[data-action="one"]').click();
      await expect.poll(() => mutations.length).toBe(1);
      if (finishWriteFirst) {
        await mutations[0].settle(true);
        await expect.poll(() => page.evaluate(() => window.catalogWrites.length)).toBe(1);
      }
      await heldReads[0].release();
      await expect.poll(() => page.evaluate(() => window.catalogReloads)).toBe(1);
      await expectFavorites('a', ['game-one']);
      if (!finishWriteFirst) await mutations[0].settle(true);
      await expect.poll(() => page.evaluate(() => window.catalogWrites.length)).toBe(1);
      await expectFavorites('a', ['game-one']);
    });
  }
  await scenario('échec indépendant : une autre écriture en vol reste visible', async ({ page, mutations, view, show, settled, expectFavorites }) => {
    await show([{ name: 'a', userId: 'account-a' }]); await settled('a');
    await view('a').locator('[data-action="one"]').click();
    await view('a').locator('[data-action="two"]').click();
    await expect.poll(() => mutations.length).toBe(2);
    await mutations[0].settle(false);
    await expectFavorites('a', ['game-two']);
    await mutations[1].settle(true);
    await expect.poll(() => page.evaluate(() => window.catalogWrites.length)).toBe(2);
    await expectFavorites('a', ['game-two']);
  });
  await scenario('échec ambigu : relire après la requête ancienne, sans la réutiliser', async ({ page, favorites, reads, mutations, heldReads, hold, view, show, settled, expectFavorites }) => {
    await show([{ name: 'a', userId: 'account-a' }]); await settled('a');
    hold('account-a');
    await view('a').locator('[data-action="reload"]').click();
    await expect.poll(() => heldReads.length).toBe(1);
    await view('a').locator('[data-action="one"]').click();
    await expect.poll(() => mutations.length).toBe(1);
    // Réponse perdue après un enregistrement côté serveur : la relecture fait foi.
    favorites.set('account-a', new Set(['game-one']));
    await mutations[0].settle(false);
    await expect.poll(() => page.evaluate(() => window.catalogWrites.length)).toBe(1);
    await expectFavorites('a', []);
    await heldReads[0].release();
    await expect.poll(() => reads.length).toBe(3);
    await expectFavorites('a', ['game-one']);
  });
  await scenario('réconciliation ambiguë reportée jusqu’à la dernière écriture', async ({ page, favorites, reads, mutations, view, show, settled, expectFavorites }) => {
    await show([{ name: 'a', userId: 'account-a' }]); await settled('a');
    await view('a').locator('[data-action="one"]').click();
    await view('a').locator('[data-action="two"]').click();
    await expect.poll(() => mutations.length).toBe(2);
    favorites.set('account-a', new Set(['game-one']));
    await mutations[0].settle(false);
    await expectFavorites('a', ['game-two']);
    assert.equal(reads.length, 1, 'pas de relecture qui ignorerait les favoris pendant l’autre écriture');
    await mutations[1].settle(true);
    await expect.poll(() => page.evaluate(() => window.catalogWrites.length)).toBe(2);
    await expect.poll(() => reads.length).toBe(2);
    await expectFavorites('a', ['game-one', 'game-two']);
  });
  await scenario('changement de compte monté : réponse A tardive ignorée par B', async ({ favorites, heldReads, hold, show, settled, expectFavorites, state }) => {
    favorites.set('account-a', new Set(['private-a']));
    favorites.set('account-b', new Set(['private-b']));
    hold('account-a');
    await show([{ name: 'same', userId: 'account-a' }]);
    await expect.poll(() => heldReads.length).toBe(1);
    await show([{ name: 'same', userId: 'account-b' }]);
    await settled('same'); await expectFavorites('same', ['private-b']);
    await heldReads[0].release();
    await show([{ name: 'same', userId: 'account-b' }, { name: 'observer', userId: 'account-a' }]);
    await settled('observer'); await expectFavorites('observer', ['private-a']);
    await expectFavorites('same', ['private-b']);
    assert.equal((await state('same')).userId, 'account-b');
    await show([{ name: 'same', userId: 'account-a' }]);
    await settled('same'); await expectFavorites('same', ['private-a']);
  });
  await scenario('échec du compte A ne change pas les favoris du compte B monté', async ({ page, favorites, reads, mutations, view, show, settled, expectFavorites }) => {
    favorites.set('account-b', new Set(['private-b']));
    await show([{ name: 'same', userId: 'account-a' }]); await settled('same');
    await view('same').locator('[data-action="one"]').click();
    await expect.poll(() => mutations.length).toBe(1);
    await show([{ name: 'same', userId: 'account-b' }]); await settled('same');
    await expectFavorites('same', ['private-b']);
    favorites.set('account-a', new Set(['server-a']));
    await mutations[0].settle(false);
    await expect.poll(() => page.evaluate(() => window.catalogWrites.length)).toBe(1);
    await expectFavorites('same', ['private-b']);
    assert.deepEqual(reads, ['account-a', 'account-b'], 'pas de relecture A sous la nouvelle authentification B');
    await show([{ name: 'same', userId: 'account-a' }]);
    await expect.poll(() => reads.length).toBe(3);
    await expectFavorites('same', ['server-a']);
  });
} finally {
  await browser.close();
  await server.close();
}
if (failures) process.exitCode = 1;
