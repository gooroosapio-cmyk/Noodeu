// Lecture intégrale : fixtures uniquement, aucun accès au service réel.
import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync } from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4221';
const OUT = process.env.OUT ?? 'test-results/question-reading';
mkdirSync(OUT, { recursive: true });
const fixture = name => JSON.parse(readFileSync(new URL(`./fixtures/${name}.json`, import.meta.url), 'utf8'));
const browser = await chromium.launch({ executablePath: '/usr/bin/chromium' });
const sentence = 'Prends le temps de raconter ce souvenir avec tous les détails que tu souhaites partager. ';
const longQuestion = `${sentence.repeat(24)}FIN DE LA QUESTION INTÉGRALE`;
const longOption = `${'Cette réponse garde tous ses mots et peut se lire jusqu’au bout. '.repeat(9)}FIN DE L’OPTION`;
const sizes = [[390, 844, 1], [320, 560, 1], [320, 640, 2]];

async function open(state, width, height, zoom) {
  const context = await browser.newContext({ viewport: { width, height }, serviceWorkers: 'block', reducedMotion: 'reduce' });
  const page = await context.newPage();
  page.setDefaultTimeout(10000);
  const errors = [];
  const audioRequests = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('request', request => { if (/reserve_answer_audio|read-answer-audio|answer-audio\//.test(request.url())) audioRequests.push(request.url()); });
  await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
  await setup(page, { ...duo, notifications: [], state });
  await page.addInitScript(() => {
    window.__readingMicRequests = 0;
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => { window.__readingMicRequests += 1; throw new Error('Micro interdit dans cette fixture'); };
  });
  async function visit() {
    await page.goto(`${BASE}/partie/${SESSION}`);
    await page.locator('.reading-games').first().waitFor();
    await page.locator('.chat-launcher').waitFor();
    if (zoom === 2) await page.addStyleTag({ content: 'html { font-size: 200%; }' });
    await page.evaluate(async () => { await document.fonts.ready; await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))); });
  }
  await visit();
  return { page, context, errors, audioRequests, visit };
}

async function checkFullText(locator, expected, fontSize) {
  assert.equal((await locator.textContent()).trim(), expected);
  const style = await locator.evaluate(element => {
    const computed = getComputedStyle(element);
    return { font: parseFloat(computed.fontSize), clamp: computed.webkitLineClamp, ellipsis: computed.textOverflow, whitespace: computed.whiteSpace, overflow: computed.overflow };
  });
  if (fontSize) assert.equal(style.font, fontSize);
  assert.ok(!style.clamp || style.clamp === 'none');
  assert.notEqual(style.ellipsis, 'ellipsis');
  assert.notEqual(style.whitespace, 'nowrap');
  assert.notEqual(style.overflow, 'hidden');
}

async function checkScroll(page, label) {
  const region = page.getByRole('region', { name: label, exact: true });
  assert.ok(await region.evaluate(element => element.scrollHeight > element.clientHeight + 1));
  await page.locator('.question-reading__hint[data-overflow="true"]').first().waitFor();
  const outer = page.locator('.question-reading').first();
  const hint = outer.locator('.question-reading__hint');
  const contentBox = await region.boundingBox();
  const hintBox = await hint.boundingBox();
  assert.ok(hintBox.y >= contentBox.y + contentBox.height - 1, 'L’indice ne recouvre jamais le texte');
  assert.ok(await region.getAttribute('aria-describedby'));
  await region.focus();
  await page.keyboard.press('End');
  await page.waitForFunction(() => document.querySelector('.question-reading__scroll').scrollTop > 0);
  await hint.filter({ hasText: 'Début du texte' }).waitFor();
}

try {
  if (!process.env.ONLY || process.env.ONLY === 'conversation') for (const [width, height, zoom] of sizes) {
    const state = fixture('c14-conv-preferes-jeu');
    const { page, context, errors, visit } = await open(state, width, height, zoom);
    const card = state.rounds[0].card;
    await checkFullText(page.locator('.t-question'), card.text, 18 * zoom);
    const before = await page.locator('.reading-answer-form > button').boundingBox();
    card.text = longQuestion;
    card.options.forEach((option, index) => { option.text = `${index + 1}. ${longOption}`; });
    state.session.state_version += 1;
    await page.route('**/rpc/get_session_state', route => route.fulfill({ json: { ...state, session: { ...state.session, id: SESSION } } }));
    await visit();
    await checkFullText(page.locator('.t-question'), longQuestion, 18 * zoom);
    const after = await page.locator('.reading-answer-form > button').boundingBox();
    await page.screenshot({ path: `${OUT}/conversation-layout-${width}-${height}-${zoom}.png` });
    assert.ok(Math.abs(before.y - after.y) < 1, `Le bouton de validation reste stable avec les longs textes (${before.y} → ${after.y})`);
    await checkScroll(page, 'Question de la manche');
    const options = page.getByRole('radio');
    for (let index = 0; index < card.options.length; index += 1) {
      await checkFullText(options.nth(index), card.options[index].text, 14 * zoom);
      assert.ok((await options.nth(index).boundingBox()).height >= 44);
    }
    const answers = page.getByRole('region', { name: 'Réponses proposées', exact: true });
    assert.ok(await answers.evaluate(element => element.scrollHeight > element.clientHeight));
    await answers.focus();
    await page.keyboard.press('End');
    await page.waitForFunction(() => document.querySelector('.reading-answer-form__content').scrollTop > 0);
    await options.last().click();
    assert.equal(await options.last().getAttribute('aria-checked'), 'true');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    await page.screenshot({ path: `${OUT}/conversation-${width}-${height}-${zoom}.png` });
    assert.deepEqual(errors, []);
    await context.close();
    console.log(`PASS conversation ${width}px / ${zoom * 100}% : texte intégral, indice, clavier, options longues et validation stable`);
  }

  if (!process.env.ONLY || process.env.ONLY === 'pack') for (const [width, height, zoom] of sizes) {
    const state = fixture('c14-pack-attente');
    state.rounds[0].card.status = {};
    state.rounds[0].private = null;
    state.rounds[0].card.item.text = 'Un souvenir à partager ?';
    const { page, context, errors, audioRequests, visit } = await open(state, width, height, zoom);
    const before = await page.locator('#q-text').boundingBox();
    state.rounds[0].card.item.text = longQuestion;
    state.session.state_version += 1;
    await page.route('**/rpc/get_session_state', route => route.fulfill({ json: { ...state, session: { ...state.session, id: SESSION } } }));
    await visit();
    const after = await page.locator('#q-text').boundingBox();
    assert.ok(Math.abs(before.y - after.y) < 1, `Formulaire du pack stable ${width}/${zoom} (${before.y} → ${after.y})`);
    await checkFullText(page.locator('.t-question'), longQuestion, 18 * zoom);
    await checkScroll(page, 'Question du pack');
    assert.ok(await page.locator('#q-text').evaluate(element => parseFloat(getComputedStyle(element).fontSize) >= 16));
    assert.match(await page.locator('.audio-answer').innerText(), /L’audio n’est pas encore disponible/);
    assert.equal(await page.locator('.audio-answer button, .audio-answer audio').count(), 0);
    assert.equal(await page.evaluate(() => window.__readingMicRequests), 0);
    assert.deepEqual(audioRequests, []);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    await page.screenshot({ path: `${OUT}/pack-${width}-${height}-${zoom}.png` });
    assert.deepEqual(errors, []);
    await context.close();
    console.log(`PASS pack ${width}px / ${zoom * 100}% : question entière, réponse stable, saisie ≥16px et audio inactif`);
  }

  if (!process.env.ONLY || process.env.ONLY === 'questionnaire') for (const [width, height, zoom] of [[390, 844, 1], [320, 640, 2]]) {
    const state = fixture('c14-test-jeu');
    const card = state.rounds[0].card;
    card.items[0].text = longQuestion;
    const scale = card.scales[card.items[0].scale];
    scale[0].label_fr = longOption;
    const { page, context, errors } = await open(state, width, height, zoom);
    const first = page.locator('.q-item').first();
    assert.ok((await first.locator('legend').textContent()).includes(longQuestion));
    await checkFullText(first.getByRole('radio').first(), longOption, 14 * zoom);
    await page.locator('.q-item').last().getByRole('radio').last().click();
    const footer = page.locator('.questionnaire-playing > .action-bar');
    assert.equal(await footer.evaluate(element => getComputedStyle(element).position), 'static');
    assert.equal(await page.locator('.q-item').count(), 5);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    await page.screenshot({ path: `${OUT}/questionnaire-${width}-${zoom}.png` });
    assert.deepEqual(errors, []);
    await context.close();
    console.log(`PASS questionnaire ${width}px / ${zoom * 100}% : libellés intégraux, cinq items et dernière réponse accessibles`);
  }

  if (!process.env.ONLY || process.env.ONLY === 'revelation') for (const name of ['c14-conv-devine-verdict', 'c14-pack-revelation']) {
    for (const [width, height, zoom] of [[390, 844, 1], [320, 640, 2]]) {
      const state = fixture(name);
      const answer = `${'Je peux lire chaque phrase de cette réponse partagée.\n'.repeat(12)}FIN DE LA RÉPONSE INTÉGRALE`;
      state.rounds[0].card.answers['2'].text = answer;
      const { page, context, errors } = await open(state, width, height, zoom);
      const text = page.locator('.q-answer__text').filter({ hasText: 'FIN DE LA RÉPONSE INTÉGRALE' });
      await checkFullText(text, answer, 14 * zoom);
      assert.equal(await text.evaluate(element => getComputedStyle(element).whiteSpace), 'pre-wrap');
      await text.scrollIntoViewIfNeeded();
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
      await page.screenshot({ path: `${OUT}/${name}-${width}-${zoom}.png` });
      assert.deepEqual(errors, []);
      await context.close();
      console.log(`PASS ${name} ${width}px / ${zoom * 100}% : réponse révélée entière, retours à la ligne et taille préservés`);
    }
  }

  if (!process.env.ONLY || process.env.ONLY === 'inputs') for (const name of ['c14-conv-phrase-jeu', 'c14-conv-av-verite', 'c14-conv-dvm2-ecriture']) {
    const { page, context, errors } = await open(fixture(name), 320, 640, 2);
    const fields = page.locator('.reading-games textarea');
    assert.ok(await fields.count() > 0);
    for (const field of await fields.all()) {
      assert.ok(await field.evaluate(element => parseFloat(getComputedStyle(element).fontSize) >= 32));
      const value = 'Ma réponse reste entière, avec ses détails et sa dernière phrase.';
      await field.fill(value);
      assert.equal(await field.inputValue(), value);
    }
    const targets = await page.locator('.reading-games button').evaluateAll(elements => elements.filter(element => element.getClientRects().length).map(element => element.getBoundingClientRect().height));
    assert.ok(targets.every(height => height >= 44));
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    assert.deepEqual(errors, []);
    await context.close();
    console.log(`PASS saisies ${name} 320px / 200% : textes entiers, champs agrandis et cibles ≥44px`);
  }
} finally { await browser.close(); }
