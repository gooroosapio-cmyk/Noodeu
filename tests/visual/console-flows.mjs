// Fixtures locales uniquement : contrôle des états UI, jamais de requête vers la base réelle.
import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync } from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION, sessionState } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4191';
const OUT = process.env.OUT ?? 'test-results/astra-console';
mkdirSync(OUT, { recursive: true });
const fixture = name => JSON.parse(readFileSync(new URL(`./fixtures/${name}.json`, import.meta.url), 'utf8'));
const browser = await chromium.launch({ executablePath: '/usr/bin/chromium' });
const results = [];
async function make(state, size = { width: 390, height: 844 }, zoom = 1) {
  const context = await browser.newContext({ viewport: size, serviceWorkers: 'block', reducedMotion: 'reduce' });
  const page = await context.newPage();
  page.setDefaultTimeout(10000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  // Toute sortie réseau est bloquée avant d'installer les routes de fixtures.
  await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
  await setup(page, { ...duo, notifications: [], state, open: { id: SESSION, game_id: state.session.game_id, status: state.session.status, title: state.game.title } });
  await page.goto(`${BASE}/partie/${SESSION}`);
  await page.locator('.session-toolbar').waitFor();
  if (zoom !== 1) await page.addStyleTag({ content: `html { font-size: ${zoom * 100}%; }` });
  return { page, context, errors };
}
async function capture(page, name) {
  await page.screenshot({ path: `${OUT}/${name}.png` });
}
try {
  {
    const { page, context, errors } = await make(fixture('c14-conv-av-choix'));
    const moves = [];
    await page.route('**/rpc/play_move', async route => { moves.push(route.request().postDataJSON()); await new Promise(resolve => setTimeout(resolve, 80)); return route.fulfill({ json: { ok: true } }); });
    await page.getByRole('button', { name: 'Action Un défi à vivre', exact: true }).evaluate(button => { button.click(); button.click(); });
    await page.waitForFunction(() => !document.querySelector('.td-console-choice')?.disabled);
    assert.equal(moves.length, 1);
    assert.equal(moves[0].p_type, 'choose_kind');
    assert.equal(moves[0].p_payload.kind, 'dare');
    assert.equal(await page.locator('.session-console').count(), 1);
    assert.equal(await page.locator('.topbar, .nav').count(), 0);
    await capture(page, 'action-verite-choix-390');
    await page.getByRole('button', { name: 'Règles', exact: true }).click();
    assert.ok(await page.getByRole('dialog').locator('ol li').count() > 0);
    assert.equal(await page.locator('.chat-launcher').isVisible(), false);
    await page.keyboard.press('Escape');
    assert.equal(await page.locator('.chat-launcher').isVisible(), true);
    const mutations = [];
    for (const fn of ['set_paused', 'abandon_session']) await page.route(`**/rpc/${fn}`, route => { mutations.push(fn); return route.fulfill({ json: { ok: true } }); });
    await page.getByRole('link', { name: /Réduire la partie/ }).click();
    await page.waitForURL('**/accueil');
    assert.deepEqual(mutations, []);
    await page.getByRole('link', { name: 'Reprendre la partie', exact: true }).click();
    await page.waitForURL(`**/partie/${SESSION}`);
    await page.getByRole('button', { name: 'Quitter', exact: true }).click();
    await page.getByRole('dialog').waitFor();
    assert.deepEqual(mutations, []);
    await page.keyboard.press('Escape');
    const pauseRequest = page.waitForRequest('**/rpc/set_paused');
    await page.getByRole('button', { name: 'Pause', exact: true }).click();
    await pauseRequest;
    assert.deepEqual(mutations, ['set_paused']);
    assert.deepEqual(errors, []);
    await context.close();
    results.push('Choix Action serveur, double clic verrouillé, plein écran app, règles/chat/modal, Réduire/Reprendre sans mutation, Quitter confirmé, Pause distincte');
  }
  {
    const state = fixture('c14-conv-av-verite');
    const { page, context, errors } = await make(state);
    const initial = await page.locator('.console-answer-zone').boundingBox();
    const card = state.rounds[0].card;
    card.text = 'Quel moment aimerais-tu partager ? '.repeat(35);
    state.session.state_version += 1;
    await page.route('**/rpc/get_session_state', route => route.fulfill({ json: { ...state, session: { ...state.session, id: SESSION } } }));
    await page.evaluate(() => window.dispatchEvent(new Event('focus')));
    await page.reload();
    await page.locator('#td-text').waitFor();
    const long = await page.locator('.console-answer-zone').boundingBox();
    assert.ok(Math.abs(initial.y - long.y) <= 1, 'La réponse ne descend pas avec la longueur de la question');
    const question = page.getByRole('region', { name: 'Question de la manche' });
    assert.ok(await question.evaluate(el => el.scrollHeight > el.clientHeight));
    await question.focus(); await page.keyboard.press('End');
    await page.waitForFunction(() => document.querySelector('.console-question .question-reading__scroll')?.scrollTop > 0);
    await capture(page, 'question-longue-scroll-390');
    const moves = [];
    await page.route('**/rpc/play_move', route => { moves.push(route.request().postDataJSON()); return route.fulfill({ json: { ok: true } }); });
    const send = page.getByRole('button', { name: 'Envoyer ma réponse', exact: true });
    assert.equal(await send.isDisabled(), true);
    await page.locator('#td-text').fill('Une réponse choisie.');
    await send.click();
    await page.waitForFunction(() => !document.querySelector('#td-text')?.disabled);
    assert.equal(moves[0].p_type, 'submit_text');
    assert.equal(moves[0].p_payload.text, 'Une réponse choisie.');
    await page.getByRole('button', { name: 'Changer de carte', exact: true }).click();
    await page.waitForFunction(() => !document.querySelector('#td-text')?.disabled);
    assert.equal(moves[1].p_type, 'replace_card');
    await page.getByRole('button', { name: 'Passer mon tour', exact: true }).click();
    assert.equal(moves[2].p_type, 'skip_round');
    assert.deepEqual(errors, []);
    await context.close();
    results.push('Question longue : géométrie stable, région défilable au clavier ; vérité vide bloquée, envoi/remplacement/passage serveur');
  }
  for (const [name, mutate] of [
    ['attente-choix', state => { state.rounds[0].card.active = 2; }],
    ['action', state => { Object.assign(state.rounds[0].card, { phase: 'respond', kind: 'dare', text: 'Fais découvrir ton coin préféré de la pièce.', card_id: 'test-dare' }); }],
    ['revelation', state => { Object.assign(state.rounds[0].card, { phase: 'reveal', kind: 'truth', text: 'Un petit bonheur ?', done: true, response: { text: 'Nos promenades.' } }); }],
    ['passee', state => { Object.assign(state.rounds[0].card, { done: true, skipped: true }); }],
  ]) {
    const state = fixture('c14-conv-av-choix'); mutate(state);
    const { page, context, errors } = await make(state);
    if (name === 'attente-choix') assert.equal(await page.locator('.td-console-choice').count(), 0);
    if (name === 'action') {
      let move;
      await page.route('**/rpc/play_move', route => { move = route.request().postDataJSON(); return route.fulfill({ json: { ok: true } }); });
      await page.getByRole('button', { name: "C'est fait", exact: true }).click();
      assert.equal(move.p_type, 'submit_action'); assert.deepEqual(move.p_payload, { status: 'done' });
    }
    if (name === 'revelation') await page.getByText('Nos promenades.', { exact: true }).waitFor();
    if (name === 'passee') await page.getByText("Carte passée, rien n'a été révélé.", { exact: true }).waitFor();
    await capture(page, `action-verite-${name}-390`);
    assert.deepEqual(errors, []); await context.close();
  }
  results.push('Action/Vérité : attente partenaire, action sans texte/preuve, révélation et manche passée');
  {
    const { page, context } = await make(fixture('c14-conv-av-choix'));
    await context.setOffline(true);
    await page.getByText('En attente du réseau', { exact: true }).waitFor();
    assert.equal(await page.locator('.td-console-choice').first().isDisabled(), true);
    assert.equal(await page.getByRole('button', { name: 'Passer mon tour', exact: true }).isDisabled(), true);
    assert.equal(await page.getByRole('link', { name: /Réduire la partie/ }).isVisible(), true);
    await context.setOffline(false);
    await page.getByText('En attente du réseau', { exact: true }).waitFor({ state: 'detached' });
    await context.close();
    const state = fixture('c14-conv-jamais-attente');
    state.rounds[0].card.answers = { '2': { text: 'REPONSE_SCELLEE_TEST' } };
    const sealed = await make(state);
    assert.equal((await sealed.page.locator('body').innerText()).includes('REPONSE_SCELLEE_TEST'), false);
    await sealed.context.close();
    results.push('Hors ligne : actions désactivées, réduction disponible ; réponse scellée absente du DOM avant révélation');
  }
  for (const [name, state] of [['portrait', sessionState('playing')], ['action-verite', fixture('c14-conv-av-choix')], ['dilemme', fixture('c14-conv-preferes-jeu')]]) {
    for (const [width, height, zoom] of [[320, 640, 1], [390, 560, 1], [320, 640, 2]]) {
      const { page, context, errors } = await make(state, { width, height }, zoom);
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
      const last = page.locator('.console-round-controls button').last();
      await last.focus(); await last.scrollIntoViewIfNeeded();
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const box = await last.boundingBox(); assert.ok(box.y >= 0 && box.y + box.height <= height);
      const chat = await page.locator('.chat-launcher').boundingBox();
      await capture(page, `${name}-${width}x${height}-${zoom * 100}`);
      assert.ok(!chat || box.x + box.width <= chat.x || chat.x + chat.width <= box.x || box.y + box.height <= chat.y || chat.y + chat.height <= box.y, `${name}-${width}x${height}-${zoom * 100} : chat et commandes ne se recouvrent pas`);
      assert.deepEqual(errors, []); await context.close();
    }
  }
  results.push('Portrait, dilemme et Action/Vérité : 320 px, petite hauteur et texte 200 %, dernière commande accessible, aucun débordement horizontal ni recouvrement du chat');
  {
    const { page, context, errors } = await make(fixture('c14-conv-salon'));
    assert.equal(await page.locator('.session-console').count(), 0);
    await page.getByRole('button', { name: 'Règles', exact: true }).click();
    assert.ok(await page.getByRole('dialog').locator('ol li').count() > 0);
    await page.keyboard.press('Escape');
    await capture(page, 'salon-conversation-390');
    assert.deepEqual(errors, []); await context.close();
    results.push('Salon compact : règles réelles, réglages fournis par le moteur');
  }
  for (const status of ['paused', 'ended', 'abandoned']) {
    const state = sessionState(status);
    if (status === 'paused') state.session.pause_state = { resume: [1] };
    const { page, context, errors } = await make(state);
    assert.equal(await page.locator('.session-console').count(), 0);
    await page.locator('.chat-launcher').waitFor();
    assert.equal(await page.locator('.chat-launcher').isVisible(), true);
    await capture(page, `session-${status}-390`);
    assert.deepEqual(errors, []); await context.close();
  }
  results.push('États pause, fin et abandon : sortie de la console active, chat disponible');
  for (const result of results) console.log(`PASS ${result}`);
} finally { await browser.close(); }
