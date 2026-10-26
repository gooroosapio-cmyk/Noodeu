// Repli du chat intégré V7 et cibles tactiles. Fixtures uniquement, réseau externe bloqué.
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { chromium, expect } from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4269';
const OUT = process.argv[2] ?? 'test-results/v7-chat-layout';
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
const results = [];
const stressOnly = process.argv.includes('--stress-only');
let failures = 0;
async function make(width, height, text, overlay = false) {
  const ctx = await browser.newContext({ viewport: { width, height }, serviceWorkers: 'block' });
  const page = await ctx.newPage(); page.setDefaultTimeout(8000);
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
  if (overlay) await page.addInitScript(() => {
    // Le layout reste haut, mais le clavier masque le bas : modèle visualViewport iOS.
    Object.defineProperty(window, 'visualViewport', { configurable: true, value: Object.assign(new EventTarget(), { height: 420, offsetTop: 0, width: innerWidth }) });
  });
  const state = JSON.parse(readFileSync(new URL('./fixtures/rouge-g08-ecriture.json', import.meta.url), 'utf8'));
  state.session.id = SESSION;
  await setup(page, { ...duo, state, notifications: [] });
  await page.route('**/duo_messages?*', route => route.fulfill({ json: Array.from({ length: 24 }, (_, i) => ({ id: `layout-${i}`, user_id: i % 2 ? state.players[0].user_id : state.players[1].user_id, client_id: `layout-${i}`, body: `Message ${i + 1} : une idée pour notre prochaine partie.`, created_at: new Date(Date.UTC(2026, 9, 21, 18, i)).toISOString() })) }));
  await page.goto(`${BASE}/partie/${SESSION}`, { waitUntil: 'networkidle' });
  await expect(page.getByLabel('Affirmation 1')).toBeVisible();
  await expect(page.locator('#game-chat-input')).toBeVisible();
  if (text !== 1) await page.addStyleTag({ content: `html{font-size:${text * 100}%}` });
  await page.evaluate(() => document.fonts.ready);
  return { page, ctx, errors };
}
async function geometry(page, visibleHeight) {
  return page.locator('.sheet--game-chat').evaluate((sheet, visibleHeight) => {
    const rect = node => { const b = node.getBoundingClientRect(); return { x: b.x, y: b.y, width: b.width, height: b.height, right: b.right, bottom: b.bottom }; };
    const title = sheet.querySelector('.sheet__title'), back = sheet.querySelector('.chat-head__return'), close = sheet.querySelector('.sheet__head > .icon-btn:last-child');
    const input = sheet.querySelector('#chat-input'), send = sheet.querySelector('.composer button'), body = sheet.querySelector('.sheet__body');
    const target = node => { const box = rect(node); return { ...box, hit: node.contains(document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2)) }; };
    return { sheet: rect(sheet), title: rect(title), back: target(back), close: target(close), input: target(input), send: target(send),
      body: { ...rect(body), client: body.clientHeight, scroll: body.scrollHeight }, overflow: document.documentElement.scrollWidth - innerWidth,
      inset: getComputedStyle(document.documentElement).getPropertyValue('--kb-inset').trim(), visibleHeight };
  }, visibleHeight);
}
function check(row) {
  assert.equal(row.overflow, 0);
  assert.ok(row.sheet.y >= -.5 && row.sheet.bottom <= row.visibleHeight + .5, JSON.stringify(row));
  assert.ok(row.title.bottom <= row.back.y + .5, 'identité distincte des commandes');
  assert.ok(row.back.right <= row.close.x + .5, 'retour distinct de la fermeture');
  assert.ok(row.body.client >= 44, `messages sans espace visible : ${JSON.stringify(row)}`);
  for (const name of ['back', 'close', 'input', 'send']) {
    const item = row[name];
    assert.ok(item.width >= 44 && item.height >= 44, `${name} cible <44`);
    assert.ok(item.x >= -.5 && item.right <= row.sheet.right + .5 && item.y >= row.sheet.y && item.bottom <= row.visibleHeight + .5, `${name} hors écran : ${JSON.stringify(row)}`);
    assert.ok(item.hit, `${name} recouvert`);
  }
}
try {
  const cases = stressOnly ? [] : [320, 360, 390, 430, 768].flatMap(width => [1, 2].flatMap(text => [width === 768 ? 1024 : 844, 420].map(height => ({ width, height, text }))));
  if (!stressOnly) cases.push(...[320, 390].map(width => ({ width, height: 844, text: 2, overlay: true })));
  for (const test of cases) {
    const { width, height, text, overlay } = test;
    const { page, ctx, errors } = await make(width, height, text, overlay);
    const name = `${width}x${height}-text${text}${overlay ? '-keyboard-overlay' : ''}`;
    const result = { ...test, errors };
    try {
      const lieHeights = await page.locator('.red-tt__lie').evaluateAll(nodes => nodes.map(node => node.getBoundingClientRect().height));
      assert.equal(lieHeights.length, 3); assert.ok(lieHeights.every(value => value >= 44));
      result.lieHeights = lieHeights;
      await page.getByLabel('Affirmation 3').fill('Un brouillon de jeu conservé.');
      await page.getByLabel('Affirmation 3').focus();
      await page.screenshot({ path: `${OUT}/${name}-game.png` });
      await page.locator('#game-chat-input').focus(); await page.locator('.sheet--game-chat').waitFor();
      await page.locator('#chat-input').fill('Un message assez long pour vérifier plusieurs lignes de saisie sans cacher les commandes ni la conversation. '.repeat(3));
      await page.waitForTimeout(200);
      result.layout = await geometry(page, overlay ? 420 : height); check(result.layout);
      const body = page.locator('.sheet--game-chat .sheet__body');
      await body.evaluate(node => { node.scrollTop = 0; });
      assert.equal(await body.evaluate(node => node.scrollTop), 0);
      await body.evaluate(node => { node.scrollTop = node.scrollHeight; });
      assert.ok(await body.evaluate(node => node.scrollTop > 0), 'les messages peuvent défiler');
      await page.screenshot({ path: `${OUT}/${name}-chat.png` });
      await page.getByRole('button', { name: 'Retour au jeu', exact: true }).click();
      await expect(page.locator('.sheet--game-chat')).toHaveCount(0);
      await expect(page.getByLabel('Affirmation 3')).toHaveValue('Un brouillon de jeu conservé.');
      await page.locator('#game-chat-input').focus(); await page.locator('.sheet--game-chat').waitFor();
      await page.getByRole('button', { name: 'Fermer la conversation et revenir au jeu', exact: true }).click();
      await expect(page.locator('.sheet--game-chat')).toHaveCount(0);
      assert.deepEqual(errors, []);
      console.log(`PASS ${name}`);
    } catch (error) { failures++; result.failure = error.message; console.error(`FAIL ${name}: ${error.message}`); await page.screenshot({ path: `${OUT}/${name}-failure.png` }).catch(() => {}); }
    results.push(result); await ctx.close();
  }
  for (const width of stressOnly ? [] : [320, 390]) {
    const { page, ctx, errors } = await make(width, 844, 1);
    await page.goto(`${BASE}/accueil`, { waitUntil: 'networkidle' });
    const play = page.locator('.v7-home .arcade-feature .btn'); await play.first().waitFor();
    const sizes = await play.evaluateAll(nodes => nodes.map(node => ({ width: node.getBoundingClientRect().width, height: node.getBoundingClientRect().height })));
    assert.ok(sizes.length > 0 && sizes.every(box => box.width >= 44 && box.height >= 44));
    await page.screenshot({ path: `${OUT}/${width}-home.png` });
    results.push({ width, home: sizes, errors }); await ctx.close(); console.log(`PASS accueil ${width}px cibles44`);
  }
  for (const height of [844, 420]) {
    const { page, ctx, errors } = await make(390, height, 1);
    const result = { width: 390, height, computedTextScale: 2, errors };
    try {
      await page.locator('#game-chat-input').focus(); await page.locator('.sheet--game-chat').waitFor();
      await page.locator('#chat-input').fill('Saisie multiligne et texte agrandi, sans masquer les commandes. '.repeat(6));
      await page.locator('.sheet--game-chat').evaluate(sheet => {
        // Diagnostic de texte : snapshot avant toute mutation pour éviter le doublement hérité.
        const snapshot = [sheet, ...sheet.querySelectorAll('*')].map(node => { const style = getComputedStyle(node); return { node, font: parseFloat(style.fontSize), line: parseFloat(style.lineHeight) }; });
        for (const { node, font, line } of snapshot) { node.style.fontSize = `${font * 2}px`; if (Number.isFinite(line)) node.style.lineHeight = `${line * 2}px`; }
      });
      await page.waitForTimeout(200);
      result.layout = await geometry(page, height); check(result.layout);
      await page.screenshot({ path: `${OUT}/390x${height}-computed-text2-chat.png` });
      await page.getByRole('button', { name: 'Retour au jeu', exact: true }).click();
      await expect(page.locator('.sheet--game-chat')).toHaveCount(0); assert.deepEqual(errors, []);
      console.log(`PASS 390x${height} texte calculé×2`);
    } catch (error) { failures++; result.failure = error.message; console.error(`FAIL 390x${height} texte calculé×2 : ${error.message}`); await page.screenshot({ path: `${OUT}/390x${height}-computed-text2-failure.png` }).catch(() => {}); }
    results.push(result); await ctx.close();
  }
} finally { writeFileSync(`${OUT}/matrix.json`, JSON.stringify(results, null, 2)); await browser.close(); }
if (failures) process.exitCode = 1;
