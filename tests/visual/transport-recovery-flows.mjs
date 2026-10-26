// Fixtures locales : une panne API sans événement navigateur offline ne doit pas rejouer les coups rattrapés.
import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4191';
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
const scenarios = [
  { fixture: 'c14-mini-de-jeu', selector: '.pig', animation: 'astra-die-land',
    change(card, n) { Object.assign(card, { rev: n, last: { type: 'roll', seat: 1 }, die: n === 7 ? 5 : 4 }); } },
  { fixture: 'c14-mini-naval-tirs', selector: '.astra-board--naval', animation: 'astra-confirmed',
    change(card, n) { Object.assign(card, { rev: n, last: { type: 'fire', seat: 1 } }); if (n > 7) card.shots[1].push({ r: 0, c: n - 8, res: 'miss' }); } },
  { fixture: 'c14-mot-pendu-devineur', selector: '.astra-flower', animation: 'astra-petal-fall',
    change(card, n) { Object.assign(card, { rev: n, last: { type: 'guess_letter', seat: 1 }, errors: n - 6 }); } },
];
try {
  for (const scenario of scenarios) {
    const state = JSON.parse(readFileSync(new URL(`./fixtures/${scenario.fixture}.json`, import.meta.url), 'utf8'));
    const card = state.rounds[0].card;
    scenario.change(card, 7);
    const context = await browser.newContext({ viewport: { width: 390, height: 844 }, serviceWorkers: 'block', reducedMotion: 'no-preference' });
    const page = await context.newPage();
    page.setDefaultTimeout(8000);
    // Bloquer toute vraie sortie réseau avant les routes de fixture.
    await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
    await setup(page, { ...duo, notifications: [], state });
    await page.addInitScript(() => {
      window.transportAnimations = [];
      document.addEventListener('animationstart', event => window.transportAnimations.push(event.animationName));
    });
    await page.goto(`${BASE}/partie/${SESSION}`);
    await page.locator(scenario.selector).waitFor();
    let fail = false;
    let holdNext = false;
    let releaseOld;
    let signalHeld;
    const oldRequestHeld = new Promise(resolve => { signalHeld = resolve; });
    await page.route('**/rpc/get_session_state', async route => {
      if (holdNext) {
        holdNext = false;
        const snapshot = structuredClone({ ...state, session: { ...state.session, id: SESSION } });
        await new Promise(resolve => {
          releaseOld = async () => { await route.fulfill({ json: snapshot }); resolve(); };
          signalHeld();
        });
        return;
      }
      return route.fulfill({ json: fail ? { ok: false, error: 'network' } : { ...state, session: { ...state.session, id: SESSION } } });
    });
    // Le canal WebSocket n'a jamais fonctionné : le premier événement via HTTP reste animable.
    state.session.state_version += 1;
    scenario.change(card, 8);
    await page.evaluate(() => window.dispatchEvent(new Event('focus')));
    await page.waitForFunction(name => window.transportAnimations.includes(name), scenario.animation);
    await page.waitForTimeout(750);
    if (scenario.fixture === 'c14-mini-de-jeu') {
      holdNext = true;
      await page.evaluate(() => window.dispatchEvent(new Event('focus')));
      await oldRequestHeld;
    }
    fail = true;
    await page.evaluate(() => window.dispatchEvent(new Event('focus')));
    await page.getByText('Connexion interrompue', { exact: true }).waitFor();
    assert.equal(await page.evaluate(() => navigator.onLine), true);
    if (releaseOld) {
      await releaseOld();
      await page.waitForTimeout(100);
      assert.equal(await page.getByText('Connexion interrompue', { exact: true }).isVisible(), true, 'Une réponse antérieure à la coupure ne prouve pas la reprise');
    }
    state.session.state_version += 1;
    scenario.change(card, 9);
    fail = false;
    await page.evaluate(() => { window.transportAnimations = []; });
    await page.getByRole('button', { name: 'Réessayer', exact: true }).click();
    await page.getByText('Connexion interrompue', { exact: true }).waitFor({ state: 'hidden' });
    await page.waitForTimeout(150);
    assert.equal(await page.evaluate(name => window.transportAnimations.includes(name), scenario.animation), false, `${scenario.fixture} : aucun événement rejoué à la reprise`);
    state.session.state_version += 1;
    scenario.change(card, 10);
    await page.evaluate(() => window.dispatchEvent(new Event('focus')));
    await page.waitForFunction(name => window.transportAnimations.includes(name), scenario.animation);
    // La coupure n'a pas désactivé les événements futurs, même quand le WebSocket est indisponible.
    console.log(`PASS ${scenario.fixture} : panne API avec navigateur en ligne, rattrapage sans animation, coup suivant animé en polling`);
    await context.close();
  }
} finally {
  await browser.close();
}
