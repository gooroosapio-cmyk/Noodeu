// Régression peinture : un décor ne doit pas masquer le texte lorsque les animations sont coupées.
// Comparaison de pixels avec/sans décor, pas seulement visibilité DOM. Fixtures et réseau bloqué.
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { chromium } from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4269';
const OUT = process.argv[2] ?? 'test-results/v7-reduced-motion';
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
const results = []; let failures = 0;
async function ink(page, png, color) {
  return page.evaluate(async ({ data, color }) => {
    const image = new Image(); image.src = `data:image/png;base64,${data}`; await image.decode();
    const canvas = document.createElement('canvas'); canvas.width = image.width; canvas.height = image.height;
    const context = canvas.getContext('2d'); context.drawImage(image, 0, 0);
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    let count = 0;
    for (let i = 0; i < pixels.length; i += 4) if (color.every((value, channel) => Math.abs(pixels[i + channel] - value) < 24)) count++;
    return count;
  }, { data: png.toString('base64'), color });
}
try {
  for (const mode of ['reduce', 'profile', 'animated']) for (const [name, path, selector] of [
    ['home', '/accueil', '#arcade-title'], ['space', '/espace', '.v7-section-head h2'], ['vault', '/espace/coffre', '.v7-memory__kicker'],
  ]) {
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, reducedMotion: mode === 'reduce' ? 'reduce' : 'no-preference', serviceWorkers: 'block' });
    const page = await ctx.newPage(); page.setDefaultTimeout(8000);
    const row = { mode, name, errors: [] }; page.on('pageerror', error => row.errors.push(error.message));
    try {
      await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
      await setup(page, { ...duo, notifications: [] });
      if (mode === 'profile') await page.route('**/profiles?*', route => route.fulfill({ json: [{ id: '11111111-1111-4111-8111-111111111111', display_name: 'Maya', word_form: 'f', intimate_opt_in: false, reduced_motion: true, avatar_path: null }] }));
      await page.goto(`${BASE}${path}`, { waitUntil: 'networkidle' });
      const target = page.locator(selector).first(); await target.waitFor(); await target.scrollIntoViewIfNeeded();
      await page.evaluate(() => document.fonts.ready); await page.waitForTimeout(250);
      row.art = await page.locator('.noodeu-ambient img').evaluate(img => ({ src: img.currentSrc, loaded: img.complete && img.naturalWidth > 0, animation: getComputedStyle(img).animationName }));
      assert.ok(row.art.loaded); assert.match(row.art.src, mode === 'animated' ? /app-background\.svg$/ : /app-background-static\.png$/);
      if (mode !== 'animated') assert.equal(row.art.animation, 'none');
      await page.screenshot({ path: `${OUT}/${mode}-${name}.png` });
      const box = await target.boundingBox(); const color = await target.evaluate(node => getComputedStyle(node).color.match(/[\d.]+/g).slice(0, 3).map(Number));
      const foreground = await page.screenshot({ clip: box });
      await page.locator('.noodeu-ambient').evaluate(node => { node.style.visibility = 'hidden'; });
      const reference = await page.screenshot({ clip: box });
      await page.locator('.noodeu-ambient').evaluate(node => { node.style.visibility = ''; });
      row.paintedTextPixels = await ink(page, foreground, color); row.referenceTextPixels = await ink(page, reference, color);
      assert.ok(row.referenceTextPixels > 20, 'le témoin contient bien du texte peint');
      assert.ok(row.paintedTextPixels >= row.referenceTextPixels * .9, `texte masqué par le décor : ${JSON.stringify(row)}`);
      assert.deepEqual(row.errors, []); console.log(`PASS ${mode} ${name} pixels ${row.paintedTextPixels}/${row.referenceTextPixels}`);
    } catch (error) { row.failure = error.message; failures++; console.error(`FAIL ${mode} ${name}: ${error.message}`); }
    results.push(row); await ctx.close();
  }
} finally { writeFileSync(`${OUT}/matrix.json`, JSON.stringify(results, null, 2)); await browser.close(); }
if (failures) process.exitCode = 1;
