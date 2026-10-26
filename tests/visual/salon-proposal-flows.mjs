// Salon : contrats d'interface sur fixtures et RPC simulés uniquement, aucune base distante.
import { chromium, expect } from '@playwright/test';
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4221';
const OUT = process.env.OUT ?? 'test-results/salon-proposal';
mkdirSync(OUT, { recursive: true });
const fixture = name => JSON.parse(readFileSync(new URL(`./fixtures/${name}.json`, import.meta.url), 'utf8'));
const film = '**/assets/original/launch/noodeu-launch-3s.mp4';
const deferred = () => { let resolve; const promise = new Promise(r => { resolve = r; }); return { promise, resolve }; };
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
const results = [];
const contexts = new Set();
async function make(name = 'c14-lobby-n2-002', options = {}) {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, serviceWorkers: 'block', reducedMotion: options.motion ?? 'reduce' });
  contexts.add(context);
  const page = await context.newPage();
  page.setDefaultTimeout(8000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const state = fixture(name);
  state.session.id = SESSION;
  options.prepare?.(state);
  const server = {
    state, calls: [], handlers: {},
    bump() { this.state.session.state_version += 1; },
    apply(fn, args) {
      if (fn === 'update_session_settings') {
        Object.assign(this.state.session.settings, args.p_settings);
        this.state.players.forEach(player => { player.ready = false; });
      } else if (fn === 'set_ready') {
        const me = this.state.players.find(player => player.is_me);
        if (me) me.ready = args.p_ready;
      } else if (fn === 'abandon_session') this.state.session.status = 'abandoned';
      else if (fn === 'set_session_prefs') this.state.my_prefs = { adult: args.p_adult, excluded_topics: args.p_excluded };
      else return { ok: false, error: 'unexpected_mock_mutation' };
      this.bump();
      return { ok: true };
    },
  };
  // Toutes les requêtes externes sont bloquées avant installation des réponses fictives.
  await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
  await setup(page, { ...duo, notifications: [], state });
  await page.route('**/rpc/get_session_state', route => route.fulfill({ json: server.state }));
  await page.route('**/rpc/get_open_session', route => route.fulfill({ json: ['lobby', 'playing', 'paused'].includes(server.state.session.status)
    ? { id: SESSION, game_id: server.state.session.game_id, title: server.state.game.title, status: server.state.session.status } : null }));
  await page.route(/\/rpc\/(set_ready|update_session_settings|abandon_session|set_paused|set_session_prefs)$/, async route => {
    const fn = new URL(route.request().url()).pathname.split('/').at(-1);
    const args = route.request().postDataJSON();
    server.calls.push({ fn, args });
    const response = server.handlers[fn] ? await server.handlers[fn](args) : server.apply(fn, args);
    await route.fulfill({ json: response });
  });
  await options.beforeGoto?.({ page, context, server });
  await page.goto(`${BASE}/partie/${SESSION}`);
  await page.locator('.lobby-proposal').waitFor();
  return { page, context, server, errors, async close() { assert.deepEqual(errors, []); await context.close(); contexts.delete(context); } };
}
async function refresh(h) { h.server.bump(); await h.page.evaluate(() => window.dispatchEvent(new Event('focus'))); }
const cta = page => page.locator('.salon-launch > button');
const group = (page, label) => page.getByRole('group', { name: label, exact: true });
const pick = async (page, label, value) => group(page, label).getByRole('radio', { name: String(value), exact: true }).locator('..').click();
async function check(name, fn) {
  if (process.env.ONLY && !new RegExp(process.env.ONLY, 'i').test(name)) return;
  try { await fn(); results.push({ name, ok: true }); console.log(`PASS ${name}`); }
  catch (error) { results.push({ name, ok: false, error: error.message }); console.error(`FAIL ${name}: ${error.message}`); }
  finally { for (const context of contexts) await context.close(); contexts.clear(); }
}
try {
  await check('Matrice des paramètres réels, choix serveur, formats fixes et panneaux', async () => {
    const cases = [
      ['c14-lobby-n2-002', { 'Nombre de cartes': [10, 20, 30] }],
      ['c14-lobby-n2-018', { 'Nombre de manches': [3, 5, 7], 'Temps par manche (secondes)': [120, 180] }],
      ['c14-lobby-n2-023', { 'Nombre de manches': [4, 6, 10], 'Difficulté des mots': ['facile', 'standard', 'difficile'] }],
      ['c14-lobby-n2-076', { 'Victoires pour gagner la série': [1, 2, 3] }],
      ['c14-random-mixed-lobby', { 'Nombre de questions': [5, 10, 20] }],
      ['c14-lobby-nd-de-chanceux', {}], ['c14-lobby-n2-078', {}], ['c14-lobby-n2-083', {}],
    ];
    for (const [name, groups] of cases) {
      const h = await make(name), { page, server } = h;
      assert.equal(await page.locator('.salon-config input[type=radio]').count(), Object.values(groups).flat().length);
      for (const [label, values] of Object.entries(groups)) {
        const radios = group(page, label).getByRole('radio');
        assert.deepEqual(await radios.evaluateAll(inputs => inputs.map(input => input.parentElement.textContent.trim())), values.map(String));
        assert.equal(await radios.evaluateAll(inputs => inputs.filter(input => input.checked).length), 1);
        const [key, def] = Object.entries(server.state.game.config.settings).find(([, def]) => def.label === label);
        await expect(group(page, label).getByRole('radio', { name: String(server.state.session.settings[key] ?? def.default), exact: true })).toBeChecked();
      }
      if (name.endsWith('nd-de-chanceux')) await expect(page.locator('.salon-config')).toContainText('30 points à conserver pour gagner');
      if (name.endsWith('n2-078')) { await expect(page.locator('.salon-config')).toContainText('10 × 10 cases'); await expect(page.locator('.salon-config')).toContainText('5 navires · 1 tir par tour'); }
      if (name.endsWith('n2-083')) { await expect(page.locator('.salon-config')).toContainText('2 victoires pour gagner'); await expect(page.locator('.salon-config')).toContainText('30 s pour choisir'); }
      if (name === 'c14-random-mixed-lobby') { assert.equal(server.state.session.total_rounds, 20); await expect(group(page, 'Nombre de questions').getByRole('radio', { name: '5', exact: true })).toBeChecked(); }
      await expect(page.locator('.salon-ready-count')).toHaveText('0/2 prêts');
      await expect(cta(page)).toHaveText('Je suis disponible');
      assert.equal(server.calls.length, 0);
      await h.close();
    }
    const h = await make();
    await h.page.getByRole('button', { name: 'Description', exact: true }).click();
    await expect(h.page.getByRole('dialog')).toContainText(h.server.state.game.rules.objective);
    assert.equal(await h.page.getByRole('dialog').locator('ol').count(), 0);
    await h.page.keyboard.press('Escape');
    await h.page.getByRole('button', { name: 'Règles', exact: true }).click();
    assert.ok(await h.page.getByRole('dialog').locator('ol li').count() > 0);
    await h.page.keyboard.press('Escape');
    assert.equal(h.server.calls.length, 0);
    await h.close();
  });

  await check('Réglage confirmé : type numérique, aucun choix optimiste, remise à zéro des disponibilités', async () => {
    const h = await make('c14-lobby-n2-002', { prepare: state => { state.players[0].ready = true; } });
    const gate = deferred(), started = deferred();
    h.server.handlers.update_session_settings = async args => { started.resolve(); await gate.promise; return h.server.apply('update_session_settings', args); };
    await pick(h.page, 'Nombre de cartes', 20); await started.promise;
    await expect(cta(h.page)).toBeDisabled();
    await expect(group(h.page, 'Nombre de cartes').getByRole('radio', { name: '10', exact: true })).toBeChecked();
    assert.equal(await group(h.page, 'Nombre de cartes').getByRole('radio', { name: '20', exact: true }).isChecked(), false);
    assert.equal(h.server.calls.length, 1);
    assert.deepEqual(h.server.calls[0].args.p_settings, { cartes: 20 });
    gate.resolve();
    await expect(group(h.page, 'Nombre de cartes').getByRole('radio', { name: '20', exact: true })).toBeChecked();
    await expect(h.page.locator('.salon-ready-count')).toHaveText('0/2 prêts');
    assert.equal(await h.page.locator('.salon-player.is-ready').count(), 0);
    await expect(cta(h.page)).toHaveText('Je suis disponible');
    h.server.state.players[1].ready = true; await refresh(h);
    await expect(cta(h.page)).toHaveText('Lancer la partie');
    await pick(h.page, 'Nombre de cartes', 30);
    await expect(h.page.locator('.salon-ready-count')).toHaveText('0/2 prêts');
    assert.equal(h.server.calls.length, 2);
    await h.close();
  });

  await check('Refus des réglages visible ; choix précédent conservé ; clavier et valeurs texte', async () => {
    const h = await make('c14-lobby-n2-023');
    h.server.handlers.update_session_settings = async () => ({ ok: false, error: 'invalid_settings' });
    await pick(h.page, 'Difficulté des mots', 'difficile');
    await expect(h.page.getByRole('alert')).toContainText("Ce réglage n'est pas possible.");
    await expect(group(h.page, 'Difficulté des mots').getByRole('radio', { name: 'standard', exact: true })).toBeChecked();
    assert.deepEqual(h.server.calls[0].args.p_settings, { difficulte: 'difficile' });
    delete h.server.handlers.update_session_settings;
    await group(h.page, 'Difficulté des mots').getByRole('radio', { name: 'standard', exact: true }).focus();
    await h.page.keyboard.press('ArrowRight');
    await expect(group(h.page, 'Difficulté des mots').getByRole('radio', { name: 'difficile', exact: true })).toBeChecked();
    assert.equal(h.server.calls.length, 2);
    await expect(h.page.getByRole('alert')).toHaveCount(0);
    await h.close();
  });

  await check('Disponibilité : double clic, attente, erreur serveur, relance, annulation', async () => {
    const h = await make(); const gate = deferred(), started = deferred();
    h.server.handlers.set_ready = async () => { started.resolve(); await gate.promise; return { ok: false, error: 'not_enough_cards' }; };
    await cta(h.page).evaluate(button => { button.click(); button.click(); }); await started.promise;
    await expect(cta(h.page)).toBeDisabled(); assert.equal(h.server.calls.length, 1);
    await expect(h.page.locator('.salon-ready-count')).toHaveText('0/2 prêts');
    gate.resolve();
    await expect(h.page.getByRole('alert')).toContainText('Pas assez de cartes disponibles pour ces réglages.');
    await expect(cta(h.page)).toHaveText('Je suis disponible');
    delete h.server.handlers.set_ready;
    await cta(h.page).click();
    await expect(h.page.locator('.salon-ready-count')).toHaveText('1/2 prêts');
    await expect(cta(h.page)).toHaveText('Annuler ma disponibilité');
    await expect(h.page.locator('.salon-launch__status')).toContainText('Alex');
    await cta(h.page).evaluate(button => { button.click(); button.click(); });
    await expect(h.page.locator('.salon-ready-count')).toHaveText('0/2 prêts');
    assert.deepEqual(h.server.calls.filter(c => c.fn === 'set_ready').map(c => c.args.p_ready), [true, true, false]);
    await h.close();
  });

  await check('Partenaire prêt : démarrage uniquement sur réception du snapshot playing', async () => {
    const h = await make('c14-lobby-n2-002', { prepare: state => { state.players[1].ready = true; } });
    const gate = deferred(), started = deferred();
    h.server.handlers.set_ready = async args => { started.resolve(); await gate.promise; assert.equal(args.p_ready, true); const playing = fixture('c14-conv-preferes-jeu'); playing.session.id = SESSION; playing.session.state_version = h.server.state.session.state_version + 1; h.server.state = playing; return { ok: true, status: 'playing' }; };
    await expect(cta(h.page)).toHaveText('Lancer la partie');
    await cta(h.page).click(); await started.promise;
    assert.equal(await h.page.locator('[data-session-status="lobby"]').count(), 1);
    gate.resolve();
    await h.page.locator('[data-session-status="playing"]').waitFor();
    assert.equal(await h.page.locator('.lobby-proposal').count(), 0);
    assert.equal(h.server.calls.length, 1);
    await h.close();
  });

  await check('Hors ligne, lecture seule et siège absent bloquent les commandes de mutation', async () => {
    const h = await make();
    await h.context.setOffline(true);
    await h.page.getByText('En attente du réseau', { exact: true }).waitFor();
    await expect(cta(h.page)).toBeDisabled();
    for (const radio of await h.page.locator('.salon-config input').all()) await expect(radio).toBeDisabled();
    await h.page.getByRole('button', { name: 'Règles', exact: true }).click(); await h.page.getByRole('dialog').waitFor(); await h.page.keyboard.press('Escape');
    await h.page.getByRole('button', { name: 'Quitter', exact: true }).click();
    await expect(h.page.getByRole('dialog').getByRole('button', { name: 'Quitter la partie', exact: true })).toBeDisabled();
    await h.page.keyboard.press('Escape'); assert.equal(h.server.calls.length, 0);
    await h.context.setOffline(false); await expect(cta(h.page)).toBeEnabled();
    await h.close();
    for (const mode of ['read_only', 'no_me']) {
      const x = await make('c14-lobby-n2-002', { prepare: state => { if (mode === 'read_only') state.session.read_only = true; else { state.players.forEach(p => { p.is_me = false; }); state.my_seat = null; } } });
      await expect(cta(x.page)).toBeDisabled();
      for (const radio of await x.page.locator('.salon-config input').all()) await expect(radio).toBeDisabled();
      assert.equal(x.server.calls.length, 0); await x.close();
    }
  });

  await check('Réduire sans mutation ; Quitter exige confirmation et résiste au double clic', async () => {
    const h = await make();
    await h.page.getByRole('link', { name: /Réduire la partie/ }).click(); await h.page.waitForURL('**/accueil'); assert.equal(h.server.calls.length, 0);
    await h.page.locator(`#arcade-resume a[href="/partie/${SESSION}"]`).click(); await h.page.locator('.lobby-proposal').waitFor();
    await h.page.getByRole('button', { name: 'Quitter', exact: true }).click();
    await expect(h.page.getByRole('dialog')).toContainText('Quitter annule ce salon pour vous deux.'); assert.equal(h.server.calls.length, 0);
    await h.page.keyboard.press('Escape'); assert.equal(h.server.calls.length, 0);
    const gate = deferred(), started = deferred();
    h.server.handlers.abandon_session = async args => { started.resolve(); await gate.promise; return h.server.apply('abandon_session', args); };
    await h.page.getByRole('button', { name: 'Quitter', exact: true }).click();
    await h.page.getByRole('dialog').getByRole('button', { name: 'Quitter la partie', exact: true }).evaluate(button => { button.click(); button.click(); }); await started.promise;
    assert.equal(h.server.calls.length, 1); assert.equal(h.server.calls[0].fn, 'abandon_session');
    gate.resolve(); await h.page.waitForURL('**/accueil'); await h.close();
  });

  await check('Ancien moteur rounds : Options, modification, remise à zéro et verrou pendant préparation', async () => {
    const head = deferred(), headStarted = deferred(); let headCount = 0;
    const h = await make('N2-001-lobby', { motion: 'no-preference', prepare: state => { state.players[0].ready = true; }, beforeGoto: async ({ page }) => {
      await page.route(film, async route => { headCount++; headStarted.resolve(); await head.promise; await route.fulfill({ status: 404, body: '' }); });
    } });
    assert.equal(await h.page.locator('.salon-config input[type=radio]').count(), 0);
    await h.page.getByRole('button', { name: 'Options', exact: true }).click();
    await h.page.getByRole('dialog').getByRole('radio', { name: '12', exact: true }).click();
    await expect(h.page.getByRole('dialog').getByRole('radio', { name: '12', exact: true })).toHaveAttribute('aria-checked', 'true');
    assert.deepEqual(h.server.calls[0].args.p_settings, { cartes: 12 });
    await h.page.keyboard.press('Escape'); await expect(h.page.locator('.salon-ready-count')).toHaveText('0/2 prêts');
    await cta(h.page).click(); await headStarted.promise;
    await expect(h.page.getByRole('button', { name: 'Options', exact: true })).toBeDisabled();
    assert.equal(h.server.calls.filter(c => c.fn === 'set_ready').length, 0);
    head.resolve(); await expect(cta(h.page)).toHaveText('Annuler ma disponibilité');
    // StrictMode rejoue le montage en développement : deux HEAD possibles, un seul RPC métier.
    assert.ok(headCount >= 1 && headCount <= 2);
    assert.equal(h.server.calls.filter(c => c.fn === 'set_ready').length, 1);
    await h.close();
  });

  await check('Film absent/type HTML, mouvement réduit et non-rejeu : une seule confirmation', async () => {
    for (const kind of ['404', 'html', 'reduce']) {
      let heads = 0;
      const h = await make('c14-lobby-n2-002', { motion: kind === 'reduce' ? 'reduce' : 'no-preference', beforeGoto: async ({ page }) => {
        await page.route(film, route => { heads++; return route.fulfill(kind === 'html' ? { status: 200, contentType: 'text/html', body: '<!doctype html>' } : { status: 404, body: '' }); });
      } });
      await cta(h.page).evaluate(button => { button.click(); button.click(); });
      await expect(cta(h.page)).toHaveText('Annuler ma disponibilité');
      assert.equal(h.server.calls.length, 1);
      assert.ok(kind === 'reduce' ? heads === 0 : heads >= 1 && heads <= 2);
      const initialHeads = heads;
      await cta(h.page).click(); await expect(cta(h.page)).toHaveText('Je suis disponible');
      await cta(h.page).click(); await expect(cta(h.page)).toHaveText('Annuler ma disponibilité');
      assert.equal(heads, initialHeads);
      await h.close();
    }
  });

  await check('Préparation : Réduire, perte réseau ou lecture seule empêchent un prêt tardif', async () => {
    for (const action of ['reduce', 'offline', 'read_only']) {
      const gate = deferred(), started = deferred();
      const h = await make('c14-lobby-n2-002', { motion: 'no-preference', beforeGoto: async ({ page }) => {
        await page.route(film, async route => { started.resolve(); await gate.promise; await route.fulfill({ status: 404, body: '' }).catch(() => {}); });
      } });
      await cta(h.page).click(); await started.promise;
      if (action === 'reduce') { await h.page.getByRole('link', { name: /Réduire la partie/ }).click(); await h.page.waitForURL('**/accueil'); }
      if (action === 'offline') { await h.context.setOffline(true); await h.page.getByText('En attente du réseau', { exact: true }).waitFor(); }
      if (action === 'read_only') { h.server.state.session.read_only = true; await refresh(h); await h.page.waitForFunction(() => document.querySelector('.session-toolbar__quit')?.tagName === 'A'); }
      gate.resolve(); await h.page.waitForTimeout(1800);
      assert.equal(h.server.calls.filter(c => c.fn === 'set_ready').length, 0, action);
      if (action !== 'reduce') await expect(cta(h.page)).toBeDisabled();
      await h.close();
    }
  });

  await check('HEAD bloqué : watchdog libère la préparation sans double confirmation', async () => {
    const started = deferred(); let heldRoute;
    const h = await make('c14-lobby-n2-002', { motion: 'no-preference', beforeGoto: async ({ page }) => { await page.route(film, route => { heldRoute = route; started.resolve(); }); } });
    const time = Date.now(); await cta(h.page).click(); await started.promise;
    await expect(cta(h.page)).toHaveText('Annuler ma disponibilité', { timeout: 5000 });
    assert.ok(Date.now() - time < 4000);
    assert.equal(h.server.calls.filter(c => c.fn === 'set_ready').length, 1);
    await heldRoute.fulfill({ status: 404, body: '' }).catch(() => {});
    await h.page.waitForTimeout(100); assert.equal(h.server.calls.length, 1);
    await h.close();
  });
} finally {
  for (const context of contexts) await context.close();
  await browser.close();
  writeFileSync(`${OUT}/results.json`, JSON.stringify(results, null, 2));
}
if (results.some(result => !result.ok)) process.exitCode = 1;
