// Compositions et interactions avec états RPC locaux : aucun service distant appelé.
import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4221';
const OUT = process.env.OUT ?? 'test-results/board-cards-refinement';
mkdirSync(OUT, { recursive: true });
const fixture = name => JSON.parse(readFileSync(new URL(`./fixtures/c14-${name}.json`, import.meta.url), 'utf8'));
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
const report = [];

async function open(name, width = 390, zoom = 1, mutate) {
  const state = fixture(name);
  if (mutate) mutate(state);
  const context = await browser.newContext({ viewport: { width, height: 780 }, serviceWorkers: 'block', reducedMotion: 'reduce' });
  const page = await context.newPage();
  page.setDefaultTimeout(15000);
  const errors = [], moves = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
  await setup(page, { ...duo, notifications: [], state });
  await page.route('**/rpc/play_move', async route => {
    moves.push(route.request().postDataJSON());
    await route.fulfill({ json: { ok: true } });
  });
  await page.goto(`${BASE}/partie/${SESSION}`, { waitUntil: 'networkidle' });
  await page.locator('.reading-games').first().waitFor();
  if (zoom === 2) await page.addStyleTag({ content: 'html { font-size: 200%; }' });
  await page.evaluate(async () => { await document.fonts.ready; await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))); });
  return { state, context, page, errors, moves };
}

const editable = state => {
  const card = state.rounds[0].card;
  card.done = false; card.locked = {}; card.continue = {};
  delete card.answers; delete card.verdict;
  state.rounds[0].private = null;
};
const cases = [
  ['conv-av-choix'], ['conv-av-verite'], ['conv-jamais-attente', editable],
  ['conv-preferes-jeu'], ['conv-qui-revelation', editable], ['conv-devine-verdict', editable],
  ['conv-accord-jeu'], ['conv-phrase-jeu'], ['conv-dvm2-ecriture'], ['conv-dvm2-attente'],
  ['conv-dvm2-devine'], ['conv-dvm2-revelation'], ['pack-attente', state => { state.rounds[0].card.status = {}; state.rounds[0].private = null; }], ['test-jeu'],
];

try {
  for (const [width, zoom] of [[390, 1], [320, 2]]) for (const [name, mutate] of cases) {
    const { page, context, errors } = await open(name, width, zoom, mutate);
    const metrics = await page.evaluate(() => ({
      overflow: document.documentElement.scrollWidth - innerWidth,
      smallButtons: [...document.querySelectorAll('.reading-games button')].filter(element => element.getClientRects().length && element.getBoundingClientRect().height < 43.9).map(element => element.textContent),
      smallFields: [...document.querySelectorAll('.reading-games textarea')].filter(element => parseFloat(getComputedStyle(element).fontSize) < 16 * (parseFloat(getComputedStyle(document.documentElement).fontSize) / 16)).map(element => element.id),
    }));
    assert.equal(metrics.overflow, 0, `${name} ${width}/${zoom}: débordement`);
    assert.deepEqual(metrics.smallButtons, [], `${name}: cibles`);
    assert.deepEqual(metrics.smallFields, [], `${name}: champs`);
    assert.deepEqual(errors, []);
    if (zoom === 1 && ['conv-preferes-jeu', 'conv-qui-revelation', 'conv-accord-jeu'].includes(name)) {
      const form = await page.locator('.reading-answer-form').boundingBox();
      const content = await page.locator('.reading-answer-form__content').boundingBox();
      const available = await page.locator('.console-answer-zone').evaluate(element => element.clientWidth - parseFloat(getComputedStyle(element).paddingLeft) - parseFloat(getComputedStyle(element).paddingRight));
      assert.ok(Math.abs(form.width - available) <= 1 && Math.abs(content.width - form.width) <= 1, `${name}: formulaire et grille sur toute la largeur disponible`);
    }
    if (zoom === 1 && ['conv-preferes-jeu', 'conv-qui-revelation', 'conv-phrase-jeu', 'conv-devine-verdict'].includes(name)) {
      const fullyVisible = await page.locator('.reading-answer-form__content').evaluate(region => {
        const bottom = region.getBoundingClientRect().bottom;
        return [...region.querySelectorAll('.q-choice__label,.target-pick__plinth,.card-writing-paper .field__hint')].every(element => element.getBoundingClientRect().bottom <= bottom + 1);
      });
      assert.ok(fullyVisible, `${name}: libellés et compteurs visibles sans défilement initial`);
    }
    await page.screenshot({ path: `${OUT}/${width}-z${zoom}-${name}.png`, fullPage: true });
    if (name === 'conv-dvm2-ecriture' && zoom === 1) {
      await page.setViewportSize({ width, height: 1600 });
      await page.screenshot({ path: `${OUT}/390-g08-trois-champs.png`, fullPage: true });
    }
    report.push({ name, width, zoom, ...metrics, errors });
    await context.close();
  }
  console.log('PASS 28 vues : texte 100/200%, 320/390 px, cibles, champs, aucun débordement ni erreur de rendu');

  for (const name of ['conv-preferes-jeu', 'conv-accord-jeu']) {
    const { context, page, moves, state } = await open(name);
    const confirm = page.locator('.reading-answer-form > button');
    assert.ok(await confirm.isDisabled());
    const option = page.locator('.reading-answer-form [role="radio"]').last();
    await option.click();
    assert.equal(moves.length, 0, 'La sélection ne transmet rien avant Valider');
    assert.equal(await option.getAttribute('aria-checked'), 'true');
    await confirm.click();
    await page.waitForFunction(() => !document.querySelector('.reading-answer-form > button').disabled);
    assert.equal(moves[0].p_type, 'lock');
    assert.deepEqual(moves[0].p_payload, { choice: state.rounds[0].card.options.at(-1).id });
    assert.equal(await page.locator('.reveal__tile').count(), 0, 'Pas de révélation locale avant état serveur');
    await context.close();
  }
  console.log('PASS choix → Valider : ID serveur intact, aucun envoi anticipé ni révélation locale');

  {
    const { context, page, moves } = await open('conv-dvm2-ecriture');
    const values = ['Je joue du piano.', 'Je suis allé sur la Lune.', 'Je préfère le thé.'];
    assert.equal(await page.locator('.ready-pair__item').count(), 2);
    assert.equal(await page.locator('input[name="tt2-lie"]').count(), 3);
    for (let index = 0; index < values.length; index++) await page.locator(`#tt2-${index}`).fill(values[index]);
    await page.locator('input[name="tt2-lie"]').nth(1).check();
    assert.equal(await page.locator('input[name="tt2-lie"]:checked').count(), 1);
    assert.equal(moves.length, 0);
    await page.locator('.theatre-backstage button[type="submit"]').click();
    await page.waitForFunction(() => !document.querySelector('.theatre-backstage button[type="submit"]').disabled);
    assert.equal(moves[0].p_type, 'publish_three');
    assert.deepEqual(moves[0].p_payload, { confirmed_truths: true, lie_statement_id: 's2', statements: values.map((text, index) => ({ id: `s${index + 1}`, text })) });
    assert.equal(await page.locator('.theatre-card--pick').count(), 0, 'Aucune affirmation partenaire avant les deux prêts');
    await context.close();
  }
  console.log('PASS G08 simultané : 3 champs, 1 radio privé, 2 états prêt, payload inchangé');

  for (const choice of ['share', 'private', 'pass']) {
    const { context, page, moves } = await open('pack-attente', 390, 1, state => { state.rounds[0].card.status = {}; state.rounds[0].private = null; });
    if (choice !== 'pass') await page.locator('#q-text').fill('Une réponse personnelle.');
    await page.locator('.pack-answer-form__actions button').nth({ share: 0, private: 1, pass: 2 }[choice]).click();
    await page.waitForFunction(() => !document.querySelector('.pack-answer-form__actions button:last-child').disabled);
    assert.equal(moves[0].p_type, 'answer');
    assert.deepEqual(moves[0].p_payload, choice === 'pass' ? { choice } : { choice, text: 'Une réponse personnelle.' });
    await context.close();
  }
  console.log('PASS pack : partage, garder privé et passage conservent leurs payloads');

  {
    const { context, page, state } = await open('test-jeu', 390, 1, state => {
      const card = state.rounds[0].card;
      card.page_size = 3;
      card.scales[card.items[0].scale] = Array.from({ length: 7 }, (_, value) => ({ value, label_fr: `Niveau ${value}` }));
    });
    assert.equal(await page.locator('.q-item').count(), 3);
    assert.equal(await page.locator('.q-item').first().locator('.q-choice:not(.q-choice--pass)').count(), 7);
    assert.ok((await page.locator('.q-item').first().textContent()).includes(state.rounds[0].card.items[0].text));
    await page.locator('.q-item').first().locator('.q-choice:not(.q-choice--pass)').last().click();
    assert.equal(await page.locator('.q-item').first().locator('.q-choice:not(.q-choice--pass)').last().getAttribute('aria-checked'), 'true');
    await context.close();
  }
  console.log('PASS questionnaire : page_size=3, échelle serveur 7 réponses, ordre conservé');
  writeFileSync(`${OUT}/report.json`, JSON.stringify(report, null, 2));
} finally { await browser.close(); }
