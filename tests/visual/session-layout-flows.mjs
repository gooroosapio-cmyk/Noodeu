// Régressions de mise en page : fixtures locales et réseau externe bloqué.
import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync } from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://localhost:4173';
const OUT = process.env.OUT ?? 'test-results/session-layout-flows';
mkdirSync(OUT, { recursive: true });
const fixture = name => JSON.parse(readFileSync(new URL(`./fixtures/${name}.json`, import.meta.url), 'utf8'));
const browser = await chromium.launch({ executablePath: '/usr/bin/chromium' });

async function open(state, width, height, zoom) {
  const context = await browser.newContext({ viewport: { width, height }, serviceWorkers: 'block', reducedMotion: 'reduce' });
  const page = await context.newPage();
  page.setDefaultTimeout(10000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
  await setup(page, { ...duo, notifications: [], state });
  await page.goto(`${BASE}/partie/${SESSION}`);
  await page.locator('.session-toolbar').waitFor();
  if (zoom === 2) await page.addStyleTag({ content: 'html { font-size: 200%; }' });
  return { page, context, errors };
}

try {
  for (const [width, height, zoom] of [[390, 844, 1], [320, 640, 2]]) {
    const state = fixture('c14-pack-attente');
    state.rounds[0].card.status = {};
    state.rounds[0].private = null;
    state.rounds[0].card.item.text = 'Un souvenir à partager ?';
    const { page, context, errors } = await open(state, width, height, zoom);
    const field = page.locator('#q-text');
    await field.waitFor();
    const short = await field.boundingBox();
    state.rounds[0].card.item.text = 'Quel souvenir voudrais-tu explorer avec ton partenaire ? '.repeat(35);
    state.session.state_version += 1;
    await page.route('**/rpc/get_session_state', route => route.fulfill({ json: { ...state, session: { ...state.session, id: SESSION } } }));
    await page.reload();
    await field.waitFor();
    if (zoom === 2) await page.addStyleTag({ content: 'html { font-size: 200%; }' });
    const long = await field.boundingBox();
    assert.ok(Math.abs(short.y - long.y) < 1, 'La longueur de la question ne déplace pas le formulaire');
    const question = page.getByRole('region', { name: 'Question du pack' });
    assert.ok(await question.evaluate(element => element.scrollHeight > element.clientHeight));
    await question.focus();
    await page.keyboard.press('End');
    await page.waitForFunction(() => document.querySelector('.pack-question .question-reading__scroll').scrollTop > 0);
    await page.screenshot({ path: `${OUT}/pack-long-${width}-${zoom}.png` });
    let move;
    await page.route('**/rpc/play_move', route => { move = route.request().postDataJSON(); return route.fulfill({ json: { ok: true } }); });
    await field.fill('Réponse privée de test.');
    await page.locator('form button.btn--secondary').click();
    assert.equal(move.p_type, 'answer');
    assert.deepEqual(move.p_payload, { choice: 'private', text: 'Réponse privée de test.' });
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    assert.deepEqual(errors, []);
    await context.close();
    console.log(`PASS pack ${width}px / ${zoom * 100}% : question stable, défilement clavier, réponse privée préservée`);
  }

  for (const [width, height, zoom] of [[390, 844, 1], [320, 640, 2]]) {
    const { page, context, errors } = await open(fixture('c14-mini-morpion-fin'), width, height, zoom);
    const stage = page.locator('main > .stage');
    // Un clic Playwright peut défiler programmatiquement un overflow:hidden : vérifier d'abord la géométrie réelle.
    assert.ok(await stage.evaluate(element => element.scrollHeight <= element.clientHeight + 1), 'Le résultat doit conserver toute sa hauteur');
    await page.locator('details summary').first().click();
    assert.equal(await page.locator('details[open] .ttt').count(), 1);
    assert.ok(await stage.evaluate(element => element.scrollHeight <= element.clientHeight + 1), 'Le plateau développé doit agrandir le résultat');
    const replay = page.getByRole('button', { name: 'Rejouer', exact: true });
    await replay.scrollIntoViewIfNeeded();
    await page.screenshot({ path: `${OUT}/resultat-rejouer-${width}-${zoom}.png` });
    let close = 0;
    await page.route('**/rpc/close_session', route => { close += 1; return route.fulfill({ json: { ok: true } }); });
    await replay.click();
    await page.waitForURL('**/bibliotheques/**');
    assert.equal(close, 1);
    assert.deepEqual(errors, []);
    await context.close();
    console.log(`PASS résultat ${width}px / ${zoom * 100}% : contenu non rogné, détail du plateau et Rejouer accessibles`);
  }

  for (const [width, height, zoom] of [[390, 844, 1], [320, 640, 2]]) {
    const { page, context, errors } = await open(fixture('c14-test-jeu'), width, height, zoom);
    const items = page.locator('.q-item');
    assert.equal(await items.count(), 5);
    const footer = page.locator('.questionnaire-playing > .action-bar');
    assert.equal(await footer.evaluate(element => getComputedStyle(element).position), 'static');
    for (let index = 0; index < 5; index += 1) {
      const radio = items.nth(index).getByRole('radio').last();
      await radio.scrollIntoViewIfNeeded();
      await radio.click();
      assert.equal(await radio.getAttribute('aria-checked'), 'true');
    }
    const end = await items.last().boundingBox();
    const commands = await footer.boundingBox();
    assert.ok(commands.y >= end.y + end.height, 'Les commandes suivent la dernière réponse sans la recouvrir');
    await page.screenshot({ path: `${OUT}/questionnaire-finliste-${width}-${zoom}.png` });
    let save;
    await page.route('**/rpc/play_move', route => { save = route.request().postDataJSON(); return route.fulfill({ json: { ok: true } }); });
    await footer.locator('button').first().click();
    assert.equal(save.p_type, 'save');
    assert.equal(Object.keys(save.p_payload.answers).length, 5);
    assert.equal(save.p_payload.page, 1);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    assert.deepEqual(errors, []);
    await context.close();
    console.log(`PASS questionnaire ${width}px / ${zoom * 100}% : cinq items accessibles, commandes après la liste, pagination préservée`);
  }
} finally { await browser.close(); }
