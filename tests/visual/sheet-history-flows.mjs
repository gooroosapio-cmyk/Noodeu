// Historique des feuilles : retour différé, réouverture, Escape et pile imbriquée. Fixtures uniquement.
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { chromium, expect } from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4269';
const OUT = process.argv[2] ?? 'test-results/sheet-history';
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
const results = []; let failures = 0;
async function scenario(name, action) {
  const ctx = await browser.newContext({ viewport: { width: 430, height: 420 }, serviceWorkers: 'block' });
  const page = await ctx.newPage(); page.setDefaultTimeout(4000);
  const row = { name, errors: [] }; page.on('pageerror', error => row.errors.push(error.message));
  try {
    await page.addInitScript(() => {
      const realBack = history.back.bind(history);
      window.__sheetHistory = { hold: false, pending: 0, pops: 0, release() { this.hold = false; this.pending--; realBack(); } };
      history.back = () => { if (window.__sheetHistory.hold) window.__sheetHistory.pending++; else realBack(); };
      window.addEventListener('popstate', () => window.__sheetHistory.pops++);
    });
    await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
    const state = JSON.parse(readFileSync(new URL('./fixtures/rouge-g08-ecriture.json', import.meta.url), 'utf8')); state.session.id = SESSION;
    await setup(page, { ...duo, state, notifications: [] });
    await page.goto(`${BASE}/partie/${SESSION}`, { waitUntil: 'networkidle' });
    await expect(page.getByLabel('Affirmation 3')).toBeVisible();
    await page.addStyleTag({ content: 'html{font-size:200%}' });
    await action(page);
    assert.equal(new URL(page.url()).pathname, `/partie/${SESSION}`, 'la fermeture des feuilles conserve la route');
    assert.deepEqual(row.errors, []); console.log(`PASS ${name}`);
  } catch (error) { failures++; row.failure = error.message; console.error(`FAIL ${name}: ${error.message}`); await page.screenshot({ path: `${OUT}/${name}-failure.png` }).catch(() => {}); }
  results.push(row); await ctx.close();
}
async function openChat(page) {
  // Une activation réelle, indépendante du focus laissé par la fermeture précédente.
  await page.getByLabel('Affirmation 3').focus();
  await page.locator('#game-chat-input').click();
  await expect(page.locator('.sheet--game-chat')).toHaveCount(1);
}
async function holdClose(page) {
  await page.evaluate(() => { window.__sheetHistory.hold = true; });
  await page.getByRole('button', { name: 'Retour au jeu', exact: true }).click();
  await expect(page.locator('.sheet--game-chat')).toHaveCount(0);
  await expect.poll(() => page.evaluate(() => window.__sheetHistory.pending)).toBe(1);
}
try {
  await scenario('reopen-during-pending-back', async page => {
    await openChat(page); await holdClose(page);
    await openChat(page);
    await page.evaluate(() => window.__sheetHistory.release());
    await expect.poll(() => page.evaluate(() => window.__sheetHistory.pops)).toBe(1);
    await page.waitForTimeout(150);
    await expect(page.locator('.sheet--game-chat')).toHaveCount(1);
    await page.screenshot({ path: `${OUT}/reopened-chat.png` });
    await page.keyboard.press('Escape'); await expect(page.locator('.sheet--game-chat')).toHaveCount(0);
    await expect.poll(() => page.evaluate(() => window.__sheetHistory.pops)).toBe(2);
  });
  await scenario('close-reopened-before-pending-back', async page => {
    await openChat(page); await holdClose(page); await openChat(page);
    await page.getByRole('button', { name: 'Retour au jeu', exact: true }).click();
    await expect(page.locator('.sheet--game-chat')).toHaveCount(0);
    await page.evaluate(() => window.__sheetHistory.release());
    await expect.poll(() => page.evaluate(() => window.__sheetHistory.pops)).toBe(1);
    assert.equal(await page.evaluate(() => window.__sheetHistory.pending), 0);
    assert.equal(await page.evaluate(() => Boolean(history.state?.noodeuSheet)), false);
  });
  await scenario('normal-back-and-escape', async page => {
    await openChat(page); await page.evaluate(() => history.back());
    await expect(page.locator('.sheet--game-chat')).toHaveCount(0);
    await openChat(page); await page.keyboard.press('Escape');
    await expect(page.locator('.sheet--game-chat')).toHaveCount(0);
    await expect.poll(() => page.evaluate(() => window.__sheetHistory.pops)).toBe(2);
  });
  await scenario('nested-sheets-back', async page => {
    await page.getByRole('button', { name: 'Règles et commandes de la partie' }).click();
    await page.getByRole('button', { name: 'Règles', exact: true }).click();
    await expect(page.locator('.sheet')).toHaveCount(2);
    await page.evaluate(() => history.back()); await expect(page.locator('.sheet')).toHaveCount(1);
    await expect.poll(() => page.evaluate(() => Boolean(history.state?.noodeuSheet))).toBe(true);
    await page.evaluate(() => history.back()); await expect(page.locator('.sheet')).toHaveCount(0);
  });
} finally { writeFileSync(`${OUT}/results.json`, JSON.stringify(results, null, 2)); await browser.close(); }
if (failures) process.exitCode = 1;
