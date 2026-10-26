// V7 : bouton conversation fixe et réservé, saisie en pied de jeu, chat intégré, historique paginé.
// Réponses Supabase simulées à partir d'états réels (fixtures) ; aucune donnée ni appel externe réel.
import assert from 'node:assert/strict';
import {readFileSync, mkdirSync} from 'node:fs';
import {chromium, expect} from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY = '1';
const {setup, duo, SESSION} = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4173';
const OUT = process.argv[2] ?? 'test-results/v7';
mkdirSync(OUT, {recursive: true});
const browser = await chromium.launch({executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium'});
const fixture = (name) => { const s = JSON.parse(readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8')); if (s.session) s.session.id = SESSION; return s; };
let failures = 0;
async function scenario(name, width, fn, scenarioState) {
  const ctx = await browser.newContext({viewport: {width, height: 800}, serviceWorkers: 'block'});
  const page = await ctx.newPage(); page.setDefaultTimeout(7000);
  const errors = []; page.on('pageerror', (e) => errors.push(e.message));
  try {
    await page.route('**/*', (r) => new URL(r.request().url()).origin === new URL(BASE).origin ? r.continue() : r.abort());
    await setup(page, scenarioState ?? duo);
    await fn(page);
    assert.deepEqual(errors, []);
    console.log(`PASS ${name} (${width}px)`);
  } catch (e) { failures++; console.error(`FAIL ${name} (${width}px) : ${e.message}`); await page.screenshot({path: `${OUT}/ECHEC-${width}-${name.replace(/\W+/g, '-')}.png`}).catch(() => {}); }
  finally { await ctx.close(); }
}
const box = async (loc) => { const b = await loc.boundingBox(); assert.ok(b, 'élément visible'); return b; };

try {
  for (const width of [360, 390, 412]) {
    await scenario('bouton conversation fixe, réservé au-dessus de la navigation', width, async (page) => {
      await page.goto(`${BASE}/accueil`);
      const fab = page.locator('.chat-launcher--fixed');
      const nav = page.locator('nav.nav');
      const before = await box(fab);
      const navBox = await box(nav);
      assert.ok(before.width >= 44 && before.height >= 44, 'cible ≥ 44 px');
      assert.ok(Math.abs(navBox.y - (before.y + before.height) - 12) <= 1, '12 px au-dessus de la navigation');
      assert.ok(Math.abs(width - (before.x + before.width) - 16) <= 1, '16 px du bord droit');
      await page.locator('main').evaluate((m) => m.scrollTo(0, m.scrollHeight));
      await page.waitForTimeout(250);
      const after = await box(fab);
      assert.deepEqual([after.x, after.y], [before.x, before.y], 'le bouton ne bouge pas au défilement');
      const mainBottom = await page.locator('main').evaluate((m) => m.getBoundingClientRect().bottom);
      assert.ok(mainBottom <= before.y + 0.5, 'la zone défilante s’arrête au-dessus du bouton');
      await page.screenshot({path: `${OUT}/${width}-accueil.png`});
    });
    await scenario('jeu : saisie en pied, sans navigation, actions dégagées, chat intégré', width, async (page) => {
      await page.goto(`${BASE}/partie/${SESSION}`);
      assert.equal(await page.locator('nav.nav').count(), 0, 'pas de navigation principale en jeu');
      const composer = page.locator('.v7-game-composer');
      const input = page.getByLabel(/Message à/);
      await expect(input).toBeVisible();
      const done = page.getByRole('button', {name: 'C’est répondu !'});
      await done.scrollIntoViewIfNeeded();
      const a = await box(done), c = await box(composer);
      assert.ok(a.y + a.height + 16 <= c.y + 0.5, `actions à 16 px au moins du pied (écart ${c.y - a.y - a.height})`);
      await page.screenshot({path: `${OUT}/${width}-jeu-saisie.png`});
      await input.focus();
      const sheet = page.locator('.sheet--game-chat');
      await expect(sheet).toBeVisible();
      await page.locator('#chat-input').fill('Brouillon en jeu');
      await page.waitForTimeout(500);
      await page.screenshot({path: `${OUT}/${width}-jeu-chat.png`});
      await page.getByRole('button', {name: 'Retour au jeu'}).click();
      await expect(sheet).toHaveCount(0);
      await expect(page.getByRole('button', {name: 'C’est répondu !'})).toBeVisible();
      await expect(page.getByLabel(/Message à/)).toHaveValue('Brouillon en jeu');
    }, {...duo, state: fixture('rouge-g01-verite.json')});
  }
  await scenario('question sans « Courte / Approfondie » ni doublon de progression', 390, async (page) => {
    await page.goto(`${BASE}/partie/${SESSION}`);
    await expect(page.locator('.pack-question')).toBeVisible();
    assert.equal(await page.getByText(/^(Courte|Approfondie)$/).count(), 0);
    assert.equal(await page.getByRole('progressbar').count(), 1, 'une seule progression');
    await page.screenshot({path: `${OUT}/390-question.png`});
  }, {...duo, state: fixture('c14-pack-vf-jeu.json')});
  await scenario('espace : aperçu limité à trois parties, Tout voir', 390, async (page) => {
    await page.goto(`${BASE}/espace`);
    await expect(page.getByRole('heading', {name: 'Parties récentes'})).toBeVisible();
    const rows = page.locator('.v7-list .v7-row');
    assert.ok(await rows.count() <= 3, 'trois parties au plus');
    const all = page.getByRole('link', {name: /Tout voir/});
    assert.match(await all.getAttribute('href') ?? '', /^\/espace\/historique/);
  });
  await scenario('conversation plein écran : sans navigation ni bouton flottant, retour', 390, async (page) => {
    await page.goto(`${BASE}/accueil`);
    await page.getByRole('button', {name: /Ouvrir la discussion/}).last().click();
    const sheet = page.locator('.sheet--chat-page');
    await expect(sheet).toBeVisible();
    const box = await sheet.boundingBox();
    assert.ok(box && box.width === 390 && box.y === 0, 'occupe tout l’écran');
    const input = page.locator('#chat-input');
    assert.equal(await input.evaluate((el) => el === document.activeElement), false, 'pas de clavier à l’ouverture');
    const ib = await input.boundingBox();
    assert.ok(ib && ib.height >= 52 && ib.y + ib.height <= 844, 'saisie 52 px en pied');
    await page.screenshot({path: `${OUT}/390-chat.png`});
    await page.locator('.chat-head__back').click();
    await expect(sheet).toHaveCount(0);
  });
} finally { await browser.close(); }
if (failures) process.exitCode = 1;
