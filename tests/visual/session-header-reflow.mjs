// Repli du titre complet et commandes accessibles, uniquement sur fixtures locales.
import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4221';
const OUT = process.env.OUT ?? 'test-results/session-header-reflow';
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: '/usr/bin/chromium' });
const results = [];
try {
  for (const [width, height, scale] of [[320, 460, 2], [390, 460, 2], [390, 844, 1]]) {
    for (const long of [false, true]) {
      const state = JSON.parse(readFileSync(new URL('./fixtures/c14-mini-naval-tirs.json', import.meta.url), 'utf8'));
      if (long) state.game.title = 'Bataille navale — la grande expédition entre amis';
      const context = await browser.newContext({ viewport: { width, height }, serviceWorkers: 'block', reducedMotion: 'reduce' });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      await page.route('**/*', r => new URL(r.request().url()).origin === new URL(BASE).origin ? r.continue() : r.abort());
      await setup(page, { ...duo, state, notifications: [] });
      await page.goto(`${BASE}/partie/${SESSION}`);
      await page.locator('.session-console').waitFor();
      if (scale === 2) await page.addStyleTag({ content: 'html { font-size: 200%; }' });
      await page.evaluate(async () => { await document.fonts.ready; await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))); });
      const geometry = await page.evaluate(() => {
        const rect = selector => { const r = document.querySelector(selector).getBoundingClientRect(); return { x: r.x, y: r.y, width: r.width, height: r.height, right: r.right, bottom: r.bottom }; };
        const header = rect('.session-toolbar'), title = rect('.session-toolbar__identity'), chat = rect('.chat-launcher');
        const controls = ['.session-toolbar__reduce', '.session-toolbar__menu'].map(rect);
        const overlap = r => Math.max(0, Math.min(r.right, chat.right) - Math.max(r.x, chat.x)) * Math.max(0, Math.min(r.bottom, chat.bottom) - Math.max(r.y, chat.y));
        return { header, title, controls, chatOverlap: [title, ...controls].map(overlap), overflow: document.documentElement.scrollWidth > innerWidth + 1 };
      });
      await page.screenshot({ path: `${OUT}/${width}x${height}-text${scale}-${long ? 'long' : 'naval'}.png` });
      assert.equal(geometry.overflow, false);
      assert.equal(await page.locator('.session-toolbar h1').textContent(), state.game.title);
      assert.ok(geometry.header.height <= height * (scale === 2 ? (long ? .7 : .45) : (long ? .25 : .16)), 'header preserves usable viewport');
      assert.ok(geometry.title.width >= (scale === 2 ? width - 32 : 100), `title has reading width: ${JSON.stringify({width,height,scale,long,geometry})}`);
      for (const b of geometry.controls) assert.ok(b.width >= 44 && b.height >= 44 && b.y >= 0 && b.bottom <= height && b.x >= 0 && b.right <= width, '44px commands remain in viewport');
      const [reduce, menu] = geometry.controls;
      assert.ok(reduce.right <= menu.x || menu.right <= reduce.x || reduce.bottom <= menu.y || menu.bottom <= reduce.y, 'commands do not overlap');
      assert.ok(geometry.chatOverlap.every(n => n === 0), 'chat reserves space without covering title or commands');
      await page.screenshot({ path: `${OUT}/${width}x${height}-text${scale}-${long ? 'long' : 'naval'}.png` });
      await page.locator('.session-toolbar__menu').click();
      await page.getByRole('dialog', { name: 'Commandes de la partie', exact: true }).waitFor();
      await page.keyboard.press('Escape');
      assert.deepEqual(errors, []);
      results.push({ width, height, scale, long, ...geometry, ok: true });
      await context.close();
    }
  }
  console.log(`PASS ${results.length} en-têtes : titre entier, largeur de lecture, commandes 44px et chat dégagé.`);
} finally {
  writeFileSync(`${OUT}/results.json`, JSON.stringify(results, null, 2));
  await browser.close();
}
