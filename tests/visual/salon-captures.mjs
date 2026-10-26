// Livraison visuelle : vrai rendu local, réponses Supabase simulées, aucun compte réel.
import { chromium } from '@playwright/test';
import { readFileSync, mkdirSync } from 'node:fs';
import assert from 'node:assert/strict';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4221';
const OUT = process.env.OUT ?? '/workspace/noodeu-salon-deliverables';
mkdirSync(OUT, { recursive: true });
const fixture = name => JSON.parse(readFileSync(new URL(`./fixtures/${name}.json`, import.meta.url), 'utf8'));
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
const scenes = [
  ['01-salon-questions', 'c14-conv-salon'],
  ['02-salon-petit-bac', 'c14-lobby-n2-018'],
  ['03-salon-pig30', 'c14-lobby-nd-de-chanceux'],
  ['04-salon-aleatoire', 'c14-random-mixed-lobby'],
  ['05-partenaire-disponible', 'c14-conv-salon'],
  ['06-question-longue', 'c14-conv-preferes-jeu'],
  ['09-salon-naval', 'c14-lobby-n2-078'],
];
try {
  for (const [name, fixtureName] of scenes) {
    const state = fixture(fixtureName);
    if (name.startsWith('05')) state.players.find(p => !p.is_me).ready = true;
    if (name.startsWith('06')) {
      state.rounds[0].card.text = 'Vous disposez d’une journée libre, sans rendez-vous ni obligation. Préférerais-tu partir ensemble découvrir un endroit inconnu, en décidant de la destination seulement au dernier moment, ou rester à la maison pour cuisiner, écouter de la musique et prendre enfin le temps de parler ? Pense aussi à ce qui te ferait du bien cette semaine : le plaisir de la nouveauté, le calme d’un lieu familier, un moment de complicité ou la possibilité de ralentir. Choisis l’option qui te ressemble aujourd’hui ; vous pourrez expliquer votre choix après la révélation.';
      state.rounds[0].card.options[0].text = 'Partir à l’aventure dans un lieu inconnu et improviser notre journée ensemble.';
      state.rounds[0].card.options[1].text = 'Rester chez nous, cuisiner et profiter d’un moment calme à deux.';
    }
    const context = await browser.newContext({ viewport: { width: 390, height: 780 }, serviceWorkers: 'block', locale: 'fr-FR', reducedMotion: 'reduce' });
    const page = await context.newPage();
    await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
    await setup(page, { ...duo, notifications: [], state });
    await page.goto(`${BASE}/partie/${SESSION}`, { waitUntil: 'networkidle' });
    await page.locator('.game-head').waitFor();
    await page.evaluate(async () => { await document.fonts.ready; await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))); });
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    await page.screenshot({ path: `${OUT}/${name}.png` });
    if (name.startsWith('06')) {
      const button = page.locator('.reading-answer-form > button');
      const before = await button.boundingBox();
      const region = page.getByRole('region', { name: 'Question de la manche', exact: true });
      await region.focus();
      await page.keyboard.press('End');
      await page.locator('.question-reading__hint').filter({ hasText: 'Début du texte' }).waitFor();
      const after = await button.boundingBox();
      assert.ok(Math.abs(after.y - before.y) < 1);
      await page.screenshot({ path: `${OUT}/07-question-longue-fin.png` });
    }
    if (name.startsWith('05')) {
      await page.getByRole('button', { name: 'Règles', exact: true }).click();
      await page.getByRole('dialog').waitFor();
      assert.equal(await page.locator('.chat-launcher').isVisible(), false);
      await page.screenshot({ path: `${OUT}/08-regles-au-premier-plan.png` });
    }
    console.log(`PASS capture ${name}`);
    await context.close();
  }
} finally { await browser.close(); }
