// États de partie issus des fixtures SQL locales ; RPC simulées, aucun service distant appelé.
import { chromium, expect } from '@playwright/test';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://localhost:4221';
const OUT = process.env.OUT ?? 'test-results/board-word-refinement';
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
const rebase = o => Array.isArray(o) ? o.map(rebase) : o && typeof o === 'object' ? '__rel' in o ? new Date(Date.now() + o.__rel * 1000).toISOString() : Object.fromEntries(Object.entries(o).map(([k, v]) => [k, rebase(v)])) : o;
const report = { visual: [], flows: [] };
async function make(name, { width = 390, height = 844, zoom = 1, reducedMotion = 'no-preference', mutate, move } = {}) {
  const context = await browser.newContext({ viewport: { width, height }, reducedMotion, serviceWorkers: 'block' });
  const page = await context.newPage();
  const state = rebase(JSON.parse(readFileSync(new URL(`./fixtures/c14-mot-${name}.json`, import.meta.url), 'utf8')));
  if (mutate) mutate(state);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
  await setup(page, { ...duo, notifications: [], state });
  if (move) await page.route('**/rpc/play_move', async route => {
    const result = await move(route.request().postDataJSON(), state);
    state.session.state_version++;
    if (result?.httpStatus) return route.fulfill({ status: result.httpStatus, contentType: 'application/json', body: JSON.stringify({ message: 'Service temporarily unavailable' }) });
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(result ?? { ok: true }) });
  });
  await page.goto(`${BASE}/partie/${SESSION}`, { waitUntil: 'networkidle' });
  if (zoom !== 1) await page.addStyleTag({ content: `html { font-size:${zoom * 100}% }` });
  await page.locator('.word-board').first().waitFor({ state: 'attached' });
  await page.locator('details').evaluateAll(nodes => nodes.filter(node => node.querySelector('.word-board')).forEach(node => node.open = true));
  return { page, context, state, card: state.rounds.at(-1).card, errors };
}
const pass = text => { report.flows.push(text); console.log('PASS', text); };
try {
  if (process.env.FLOWS_ONLY !== '1') {
    const cases = ['pendu-choix', 'pendu-devineur', 'pendu-donneur', 'pendu-fin', 'bac-saisie', 'bac-arbitrage', 'bac-resultat', 'cite-appel', 'cite-juge', 'cite-correction'];
    const sizes = process.env.QUICK ? [[390, 844, 1]] : [[320, 780, 1], [360, 780, 1], [390, 844, 1], [430, 932, 1], [320, 780, 2], [390, 460, 1]];
    for (const [width, height, zoom] of sizes) for (const name of cases) {
      const { page, context, errors } = await make(name, { width, height, zoom });
      const metrics = await page.evaluate(() => {
        const root = document.querySelector('.word-board');
        const targets = [...root.querySelectorAll('button,input,summary')].filter(el => el.getBoundingClientRect().width && !el.closest('[inert]'));
        return {
          overflow: document.documentElement.scrollWidth - innerWidth,
          small: targets.filter(el => { const r = el.getBoundingClientRect(); return r.width < 43.9 || r.height < 43.9; }).map(el => ({ text: el.textContent || el.id, w: el.getBoundingClientRect().width, h: el.getBoundingClientRect().height })),
          inputs: [...root.querySelectorAll('input[type="text"]')].map(el => parseFloat(getComputedStyle(el).fontSize)),
          accent: getComputedStyle(root).getPropertyValue('--board-accent').trim(),
          brokenImages: [...root.querySelectorAll('img')].filter(el => !el.complete || !el.naturalWidth).map(el => el.getAttribute('src')),
        };
      });
      if (name === 'bac-saisie') {
        assert.equal(await page.locator('.pb-cell').count(), 8);
        assert.equal(await page.locator('.pb-grid').evaluate(el => getComputedStyle(el).gridTemplateColumns.split(' ').length), 2);
      }
      if (name === 'bac-arbitrage' || name === 'bac-resultat') {
        assert.equal(await page.locator('.pb-comparison').count(), 8);
        assert.equal(await page.locator('.pb-answer').count(), 16);
      }
      await page.screenshot({ path: `${OUT}/${width}-${height}-z${zoom}-${name}.png`, fullPage: true });
      if (width === 390 && height === 844 && zoom === 1) {
        const bottom = name === 'pendu-devineur' ? page.locator('.hm-key').last() : name === 'bac-saisie' ? page.locator('.pb-stop') : name === 'cite-juge' ? page.locator('.cite-verdicts') : null;
        if (bottom) { await bottom.scrollIntoViewIfNeeded(); await page.screenshot({ path: `${OUT}/${width}-${height}-z${zoom}-${name}-controls.png`, fullPage: true }); }
      }
      report.visual.push({ name, width, height, zoom, ...metrics, errors });
      await context.close();
    }
    writeFileSync(`${OUT}/report.json`, JSON.stringify(report, null, 2));
    const failures = report.visual.filter(r => r.overflow > 0 || r.small.length || r.errors.length || r.brokenImages.length || r.inputs.some(size => size < 16) || r.accent !== '#B72132');
    assert.deepEqual(failures, [], 'Responsive / targets / inputs / palette / images');
    pass(`${report.visual.length} captures : ${sizes.map(([w,h,z]) => `${w}×${h} texte ${z*100}%`).join(', ')}, contrôles 44 px`);
  }
  if (process.env.VISUAL_ONLY !== '1') {
    {
      const { page, context } = await make('pendu-devineur');
      assert.equal((await page.locator('.hm-key').allTextContents()).join(''), 'AZERTYUIOPQSDFGHJKLMWXCVBN');
      assert.equal(await page.locator('.hm-key--hit').count(), 2);
      assert.equal(await page.locator('.hm-key--miss').count(), 2);
      assert.equal(await page.locator('.hm-slot').count(), 7);
      assert.equal(await page.getByText('Ton mot :', { exact: false }).count(), 0);
      assert.equal(await page.locator('.is-falling').count(), 0);
      await context.close(); pass('Pendu : AZERTY, états distincts, mot privé absent, snapshot sans chute');
    }
    {
      let stopped;
      const { page, context, card } = await make('bac-saisie', { height: 460, move: args => { if (args.p_type === 'stop') stopped = args; } });
      assert.equal(await page.getByRole('button', { name: 'Stop', exact: true }).isDisabled(), true);
      const inputs = page.locator('.pb-cell__input');
      for (let i = 0; i < 8; i++) await inputs.nth(i).fill(['Chat', 'Copenhague', 'Charpentier', 'Crayon', 'Canada', 'Camille', 'Carotte', 'Céline Dion'][i]);
      await inputs.last().focus(); await page.waitForTimeout(350);
      assert.equal(await inputs.last().evaluate(el => { const r = el.getBoundingClientRect(); return r.top >= 0 && r.bottom <= innerHeight; }), true);
      await page.getByRole('button', { name: 'Stop', exact: true }).click();
      await expect.poll(() => Boolean(stopped)).toBe(true);
      assert.deepEqual(Object.keys(stopped.p_payload.drafts).sort(), [...card.categories].sort());
      await context.close(); pass('Petit bac : huit brouillons au STOP, dernier champ visible en petite hauteur');
    }
    {
      let vote;
      const { page, context } = await make('bac-arbitrage', { move: args => { vote = args; } });
      const unknown = page.locator('.pb-answer[data-status="unknown"]').first();
      assert.match(await unknown.innerText(), /À vérifier/);
      assert.match(await unknown.innerText(), /Absente de notre index/);
      assert.equal(await unknown.getByText('Mauvaise initiale', { exact: true }).count(), 0);
      await page.locator('.pb-answer[data-status="valid"]').first().getByRole('button', { name: 'Contester', exact: true }).click();
      assert.equal(vote.p_type, 'judge_entry'); assert.equal(vote.p_payload.verdict, 'reject');
      await context.close(); pass('Petit bac : inconnu à vérifier, contestation reconnue transmise au moteur');
    }
    {
      const { page, context, card } = await make('cite-juge', { mutate: st => { const c = st.rounds.at(-1).card; c.starts_at = new Date(Date.now() - 9500).toISOString(); c.deadline_at = new Date(Date.now() + 500).toISOString(); } });
      assert.equal(await page.getByText('En appel', { exact: true }).count(), 1);
      assert.match(await page.locator('.cite-player').innerText(), /Alex répond/);
      assert.equal(await page.locator('.cite-prompt h2').textContent(), card.text);
      await page.waitForTimeout(600);
      assert.match(await page.locator('.cite-timer').innerText(), /Temps écoulé/);
      assert.equal(await page.getByRole('button', { name: /Réussi.*\+3/ }).count(), 1);
      assert.equal(await page.getByRole('button', { name: /Raté.*0/ }).count(), 1);
      assert.equal(await page.locator('.mini-scores').count(), 0);
      const deadline = card.deadline_at;
      await page.reload({ waitUntil: 'networkidle' });
      assert.equal(card.deadline_at, deadline);
      assert.match(await page.locator('.cite-timer').innerText(), /Temps écoulé/);
      await context.close(); pass('Cite trois : identité/appel/consigne, juge +3/0, zéro sans verdict, reload sans nouveau chrono');
    }
    {
      const { page, context } = await make('cite-juge', { reducedMotion: 'reduce', mutate: st => { st.rounds.at(-1).card.judge = 2; st.rounds.at(-1).card.respondent = 1; st.rounds.at(-1).card.need_call = false; } });
      assert.equal(await page.locator('.cite-verdicts').count(), 0);
      assert.equal(await page.getByText('En appel', { exact: true }).count(), 1);
      assert.match(await page.locator('.cite-player').innerText(), /toi qui réponds/);
      await context.close(); pass('Cite trois : répondant sans contrôles de juge, mouvement réduit');
    }
    {
      let acks = 0; let ticks = 0;
      const { page, context, card } = await make('cite-juge', {
        mutate: st => { const c = st.rounds.at(-1).card; c.acks = { 2: true }; c.starts_at = new Date(Date.now() + 1800).toISOString(); c.deadline_at = new Date(new Date(c.starts_at).getTime() + 10000).toISOString(); },
        move: (args, st) => {
          if (args.p_type === 'prompt_received') { acks++; if (acks === 1) return { httpStatus: 503 }; assert.ok(Date.now() - new Date(st.rounds.at(-1).card.starts_at).getTime() <= 750, 'ACK encore dans la fenêtre serveur de 750 ms'); st.rounds.at(-1).card.acks[1] = true; }
          if (args.p_type === 'tick') { ticks++; if (ticks === 1) return { httpStatus: 503 }; }
        },
      });
      const deadline = card.deadline_at;
      await expect.poll(() => acks).toBe(2);
      assert.equal(acks, 2); assert.equal(card.deadline_at, deadline); assert.equal(await page.evaluate(() => navigator.onLine), true);
      await context.close(); pass('Cite trois : ACK HTTP503 repris dans les 750 ms, navigateur online, échéance inchangée');
    }
    {
      let ticks = 0;
      const { page, context, card } = await make('cite-juge', {
        mutate: st => { const c = st.rounds.at(-1).card; c.acks = { 1: true }; c.starts_at = new Date(Date.now() - 1500).toISOString(); },
        move: args => { if (args.p_type === 'tick') { ticks++; if (ticks === 1) return { httpStatus: 503 }; } },
      });
      const deadline = card.deadline_at;
      await expect.poll(() => ticks).toBe(2);
      assert.equal(ticks, 2); assert.equal(card.deadline_at, deadline); assert.equal(await page.evaluate(() => navigator.onLine), true);
      await context.close(); pass('Cite trois : tick HTTP503 repris online sans score ni nouveau délai');
    }
    {
      let attempts = 0;
      const { page, context, card } = await make('cite-juge', {
        mutate: st => { const c = st.rounds.at(-1).card; c.acks = { 2: true }; c.starts_at = new Date(Date.now() - 1500).toISOString(); },
        move: (args, st) => {
          if (args.p_type === 'prompt_received') { attempts++; if (attempts === 1) return { ok: false, error: 'network' }; }
          if (['prompt_received', 'tick'].includes(args.p_type)) {
            Object.assign(st.rounds.at(-1).card, { done: true, void: 'loading', phase: 'result' });
            delete st.rounds.at(-1).card.text;
          }
        },
      });
      const deadline = card.deadline_at;
      await expect(page.getByText(/manche annulée, aucun point/)).toBeVisible();
      assert.equal(card.deadline_at, deadline); assert.equal(await page.locator('.cite-verdicts').count(), 0);
      assert.equal(card.scores, undefined);
      await context.close(); pass('Cite trois : reprise tardive annulée par le serveur, aucun point ni délai supplémentaire');
    }
    {
      let attempts = 0;
      const { page, context, card } = await make('cite-juge', {
        mutate: st => { const c = st.rounds.at(-1).card; c.acks = { 1: true }; c.starts_at = new Date(Date.now() - 1500).toISOString(); },
        move: (args, st) => {
          if (args.p_type !== 'tick') return;
          attempts++;
          if (attempts <= 4) return { ok: false, error: 'network' };
          Object.assign(st.rounds.at(-1).card, { done: true, void: 'loading', phase: 'result' });
          delete st.rounds.at(-1).card.text;
        },
      });
      const deadline = card.deadline_at;
      const retry = page.getByRole('button', { name: 'Réessayer la confirmation', exact: true });
      await expect(retry).toBeVisible({ timeout: 10000 });
      assert.equal(attempts, 4);
      await retry.click(); await expect(page.getByText(/manche annulée, aucun point/)).toBeVisible();
      await page.waitForTimeout(1200);
      assert.equal(attempts, 5); assert.equal(card.deadline_at, deadline);
      await context.close(); pass('Cite trois : quatre tentatives bornées, reprise explicite, aucune boucle après résultat');
    }
    {
      const long = 'Cite trois endroits dans lesquels tu aimerais te retrouver pour partager un moment calme, puis explique ce qui rend chacun de ces lieux particulier, sans reprendre un endroit déjà cité par ton partenaire. '.repeat(3);
      const { page, context } = await make('cite-juge', { width: 320, zoom: 2, mutate: st => st.rounds.at(-1).card.text = long });
      assert.equal(await page.locator('.cite-prompt h2').textContent(), long);
      const region = page.getByRole('region', { name: 'Consigne de la manche', exact: true });
      assert.equal(await region.evaluate(el => el.scrollHeight > el.clientHeight), true);
      await region.focus(); await page.keyboard.press('End');
      await expect.poll(() => region.evaluate(el => el.scrollTop)).toBeGreaterThan(0);
      await page.screenshot({ path: `${OUT}/320-z2-long-prompt.png`, fullPage: true });
      await context.close(); pass('Cite trois : consigne longue intégrale dans une zone de lecture stable et défilante au clavier');
    }
  }
  writeFileSync(`${OUT}/report.json`, JSON.stringify(report, null, 2));
} finally { await browser.close(); }
