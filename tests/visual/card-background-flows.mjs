// Portes en fond de cartes : fixtures RPC locales, contrastes conservateurs et lecture intégrale.
import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4221';
const OUT = process.env.OUT ?? 'test-results/card-backgrounds';
mkdirSync(OUT, { recursive: true });
const fixture = name => JSON.parse(readFileSync(new URL(`./fixtures/c14-${name}.json`, import.meta.url), 'utf8'));
const browser = await chromium.launch({ executablePath: '/usr/bin/chromium' });
const report = [];
const rgb = color => color.match(/[\d.]+/g).map(Number).slice(0, 3);
const mix = (front, back, alpha) => front.map((value, index) => value * alpha + back[index] * (1 - alpha));
const luminance = values => values.map(value => value / 255).map(value => value <= .04045 ? value / 12.92 : ((value + .055) / 1.055) ** 2.4).reduce((sum, value, index) => sum + value * [.2126, .7152, .0722][index], 0);
const contrast = (a, b) => (Math.max(luminance(a), luminance(b)) + .05) / (Math.min(luminance(a), luminance(b)) + .05);

async function open(name, width, height, zoom = 1, mutate) {
  const state = fixture(name); if (mutate) mutate(state);
  const context = await browser.newContext({ viewport: { width, height }, serviceWorkers: 'block', reducedMotion: 'reduce' });
  const page = await context.newPage(); const errors = [], moves = [];
  page.setDefaultTimeout(15000); page.on('pageerror', error => errors.push(error.message));
  await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
  await setup(page, { ...duo, notifications: [], state });
  await page.route('**/rpc/play_move', async route => { moves.push(route.request().postDataJSON()); await route.fulfill({ json: { ok: true } }); });
  const visit = async () => {
    await page.goto(`${BASE}/partie/${SESSION}`, { waitUntil: 'networkidle' });
    await page.locator('.reading-games').first().waitFor();
    if (zoom === 2) await page.addStyleTag({ content: 'html { font-size: 200%; }' });
    await page.evaluate(async () => { await document.fonts.ready; await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))); });
  };
  await visit(); return { state, context, page, errors, moves, visit };
}

async function checkBackgrounds(page) {
  const styles = await page.locator('.pick--doors .q-choice').evaluateAll(cards => cards.map(card => {
    const layer = card.querySelector('.card-choice-illustration--door');
    const image = layer.querySelector('img'); const label = card.querySelector('.q-choice__label');
    return { position: getComputedStyle(layer).position, pointer: getComputedStyle(layer).pointerEvents, alpha: Number(getComputedStyle(image).opacity), blur: getComputedStyle(image).filter, veil: getComputedStyle(layer, '::after').backgroundColor, foreground: getComputedStyle(label).color, background: getComputedStyle(card).backgroundColor, opacity: Number(getComputedStyle(card).opacity), layerZ: Number(getComputedStyle(layer).zIndex), labelZ: Number(getComputedStyle(label).zIndex) };
  }));
  for (const style of styles) {
    assert.equal(style.position, 'absolute'); assert.equal(style.pointer, 'none');
    assert.ok(style.alpha <= .3 && style.blur.includes('blur(')); assert.ok(style.labelZ > style.layerZ);
    assert.equal(style.opacity, 1);
    const veilAlpha = Number(style.veil.match(/[\d.]+/g)[3] ?? 1);
    const worstBackground = mix(rgb(style.veil), mix([0, 0, 0], rgb(style.background), style.alpha), veilAlpha);
    style.worstContrast = contrast(rgb(style.foreground), worstBackground);
    assert.ok(style.worstContrast >= 7, `Contraste conservateur ${style.worstContrast}`);
  }
  return styles;
}

try {
  for (const [width, height, zoom] of [[320, 780, 1], [390, 844, 1], [430, 932, 1], [320, 780, 2], [390, 844, 2], [430, 932, 2]]) {
    const { page, context, state, errors, moves, visit } = await open('conv-preferes-jeu', width, height, zoom);
    const confirm = page.locator('.reading-answer-form > button');
    const before = await confirm.boundingBox();
    const originalText = state.rounds[0].card.text;
    assert.equal(await page.locator('.t-question').textContent(), originalText);
    assert.equal(await page.locator('.t-question').evaluate(element => parseFloat(getComputedStyle(element).fontSize)), 18 * zoom);
    if (zoom === 1) {
      assert.ok(await page.locator('.question-reading__scroll').evaluate(element => element.scrollHeight <= element.clientHeight + 1), `Question standard entière ${width}`);
      assert.ok(await page.locator('.reading-answer-form__content').evaluate(region => [...region.querySelectorAll('.q-choice__label')].every(label => label.getBoundingClientRect().bottom <= region.getBoundingClientRect().bottom + 1)), `Choix standards entiers ${width}`);
    }
    const styles = await checkBackgrounds(page);
    await page.screenshot({ path: `${OUT}/${width}-z${zoom}-standard.png`, fullPage: true });
    await page.locator('.pick--doors [role="radio"]').last().click();
    assert.equal(moves.length, 0); const selectedStyles = await checkBackgrounds(page);
    await page.screenshot({ path: `${OUT}/${width}-z${zoom}-selected.png`, fullPage: true });
    await confirm.click(); await page.waitForFunction(() => !document.querySelector('.reading-answer-form > button').disabled);
    assert.equal(moves[0].p_type, 'lock'); assert.deepEqual(moves[0].p_payload, { choice: state.rounds[0].card.options.at(-1).id });
    assert.equal(await page.locator('.reveal__tile').count(), 0);
    await page.locator('.pick--doors button').evaluateAll(buttons => buttons.forEach(button => { button.disabled = true; }));
    await checkBackgrounds(page);

    state.rounds[0].card.text = `${'Imagine une journée à deux, avec toutes les possibilités que vous aimeriez prendre le temps de découvrir. '.repeat(14)}FIN DE LA QUESTION`;
    state.rounds[0].card.options.forEach((option, index) => { option.text = `${index + 1}. ${'Une proposition qui garde tous ses détails, même quand elle est longue. '.repeat(8)}FIN DU CHOIX`; });
    state.session.state_version += 1;
    await page.route('**/rpc/get_session_state', route => route.fulfill({ json: { ...state, session: { ...state.session, id: SESSION } } }));
    await visit();
    const after = await confirm.boundingBox();
    assert.ok(Math.abs(before.y - after.y) <= 1, `CTA stable ${width}/${zoom}: ${before.y} → ${after.y}`);
    assert.equal(await page.locator('.t-question').textContent(), state.rounds[0].card.text);
    await page.getByRole('region', { name: 'Question de la manche', exact: true }).focus(); await page.keyboard.press('End');
    await page.waitForFunction(() => document.querySelector('.question-reading__scroll').scrollTop > 0);
    const options = page.locator('.pick--doors [role="radio"]');
    for (let index = 0; index < 2; index++) assert.equal((await options.nth(index).textContent()).trim(), state.rounds[0].card.options[index].text);
    await page.getByRole('region', { name: 'Réponses proposées', exact: true }).focus(); await page.keyboard.press('End');
    await page.waitForFunction(() => document.querySelector('.reading-answer-form__content').scrollTop > 0);
    await options.last().click(); assert.equal(await options.last().getAttribute('aria-checked'), 'true');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    assert.deepEqual(errors, []);
    await page.screenshot({ path: `${OUT}/${width}-z${zoom}-long.png`, fullPage: true });
    report.push({ width, height, zoom, standard: zoom === 1 ? 'entire standard question and options visible' : 'full text with scrolling when needed', long: 'full text and keyboard scrolling', stableCta: true, contrast: Math.min(...[...styles, ...selectedStyles].map(style => style.worstContrast)), errors });
    await context.close();
    console.log(`PASS ${width}px ${zoom * 100}% : fonds absolus, question/choix entiers, contraste, verrouillage et CTA stable`);
  }
  for (const name of ['conv-preferes-jeu', 'conv-accord-jeu', 'conv-phrase-jeu', 'conv-devine-verdict']) {
    const { page, context, errors } = await open(name, 390, 844, 1, name === 'conv-preferes-jeu' ? state => {
      const card = state.rounds[0].card; card.done = true; card.answers = { 1: { choice: card.options[0].id }, 2: { choice: card.options[1].id } };
    } : undefined);
    if (name === 'conv-preferes-jeu') {
      const contained = await page.locator('.reveal__tile').evaluateAll(tiles => tiles.every(tile => {
        const art = tile.querySelector('.card-choice-illustration').getBoundingClientRect(); const box = tile.getBoundingClientRect();
        return art.left >= box.left && art.right <= box.right && art.top >= box.top && art.bottom <= box.bottom;
      })); assert.ok(contained);
    }
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false); assert.deepEqual(errors, []);
    await page.screenshot({ path: `${OUT}/390-${name}.png`, fullPage: true }); await context.close();
  }
  writeFileSync(`${OUT}/report.json`, JSON.stringify(report, null, 2));
} finally { await browser.close(); }
