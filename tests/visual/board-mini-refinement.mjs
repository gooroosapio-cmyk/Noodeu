// Fixtures locales et réponses RPC simulées : ce test ne valide aucune base distante.
import { chromium } from '@playwright/test';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://localhost:4221';
const OUT = process.env.OUT ?? 'test-results/refinement-mini';
const flowsOnly = process.argv.includes('--flows-only');
mkdirSync(OUT, { recursive: true });
const rebase = value => Array.isArray(value) ? value.map(rebase) : value && typeof value === 'object'
  ? '__rel' in value ? new Date(Date.now() + value.__rel * 1000).toISOString() : Object.fromEntries(Object.entries(value).map(([key, item]) => [key, rebase(item)])) : value;
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
const matrix = [], checks = [];
const pass = message => { checks.push(message); console.log('PASS', message); };
function dots12(state) {
  // Contrat exact de la migration préparée 20261029001000 ; aucune activation de version.
  const c = state.rounds.at(-1).card;
  Object.assign(c, { dot_rows: 12, dot_columns: 12, box_rows: 11, box_columns: 11, total_boxes: 121, total_edges: 264,
    owner: Array.from({ length: 121 }, (_, index) => index < 2 ? 1 : 0) });
}
async function make(name, { width = 390, zoom = 1, mutate = () => {}, reducedMotion = 'no-preference' } = {}) {
  const ctx = await browser.newContext({ viewport: { width, height: 844 }, serviceWorkers: 'block', reducedMotion });
  const page = await ctx.newPage();
  const state = rebase(JSON.parse(readFileSync(new URL(`./fixtures/c14-${name}.json`, import.meta.url), 'utf8')));
  mutate(state);
  await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
  await setup(page, { ...duo, state, notifications: [] });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(`${BASE}/partie/${SESSION}`, { waitUntil: 'networkidle' });
  if (zoom !== 1) await page.addStyleTag({ content: `html { font-size:${zoom * 100}% }` });
  await page.locator('.mini-refined').first().waitFor({ state: 'attached' });
  await page.locator('details').evaluateAll(nodes => nodes.filter(node => node.querySelector('.mini-refined')).forEach(node => { node.open = true; }));
  return { ctx, page, state, c: state.rounds.at(-1).card, errors };
}
async function rpc(page, state, handler) {
  await page.route('**/rpc/play_move', async route => {
    const result = await handler(route.request().postDataJSON());
    state.session.state_version++;
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(result ?? { ok: true }) });
  });
}
try {
  const scenarios = ['mini-morpion-jeu', 'mini-morpion-fin', 'mini-points-jeu', 'refinement-dots12', 'mini-pfc-verrouille', 'mini-pfc-revelation', 'mini-de-jeu', 'mini-naval-placement', 'mini-naval-tirs'];
  for (const width of flowsOnly ? [] : [320, 360, 390, 430]) for (const zoom of [1, 2]) for (const name of scenarios) {
    const { page, ctx, errors } = await make(name === 'refinement-dots12' ? 'mini-points-jeu' : name, { width, zoom, mutate: name === 'refinement-dots12' ? dots12 : undefined });
    const geometry = await page.evaluate(() => ({
      overflow: Math.max(0, document.documentElement.scrollWidth - innerWidth),
      small: [...document.querySelectorAll('.mini-refined button,.mini-refined input,.mini-refined select,.mini-refined summary')].filter(node => {
        const box = node.getBoundingClientRect();
        return !node.closest('[inert]') && box.width > 0 && box.height > 0 && (box.width < 43.9 || box.height < 43.9);
      }).map(node => ({ label: node.getAttribute('aria-label') || node.textContent, width: node.getBoundingClientRect().width, height: node.getBoundingClientRect().height })),
      fields: [...document.querySelectorAll('.mini-refined input,.mini-refined select')].map(node => parseFloat(getComputedStyle(node).fontSize)),
      palette: getComputedStyle(document.querySelector('.mini-refined')).getPropertyValue('--board-accent').trim(),
    }));
    matrix.push({ name, width, textScale: zoom, ...geometry, errors });
    if ((width === 390 && zoom === 1) || (width === 320 && zoom === 2)) {
      await page.screenshot({ path: `${OUT}/${width}-text${zoom}-${name}.png`, fullPage: true });
      const board = page.locator('.mini-refined .board-zoom,.mini-refined .astra-ttt,.mini-refined .rps,.mini-refined .pig-tray').first();
      await board.scrollIntoViewIfNeeded();
      await page.screenshot({ path: `${OUT}/${width}-text${zoom}-${name}-board.png`, fullPage: true });
    }
    await ctx.close();
  }
  if (!flowsOnly) {
    writeFileSync(`${OUT}/matrix.json`, JSON.stringify(matrix, null, 2));
    assert.ok(matrix.every(row => !row.overflow && !row.small.length && !row.errors.length && row.fields.every(size => size >= 16) && row.palette === '#B72132'), JSON.stringify(matrix.filter(row => row.overflow || row.small.length || row.errors.length || row.palette !== '#B72132')));
    pass('72 vues : 320/360/390/430 px × texte100/200% × 9 états, aucun débordement, cible <44 px ou erreur JS ; champs ≥16 px');
  }

  for (const modern of [false, true]) {
    const { page, ctx, c, state } = await make('mini-points-jeu', { mutate: modern ? dots12 : undefined });
    assert.equal(await page.locator('.dots__dot').count(), modern ? 144 : 25);
    assert.equal(await page.locator('.dots__box').count(), modern ? 121 : 16);
    assert.equal(await page.locator('.dots__edge').count(), modern ? 264 : 40);
    assert.equal(await page.locator('.dots__box--me').first().textContent(), 'M');
    assert.equal(await page.locator('.dots__box--me').first().evaluate(node => getComputedStyle(node).backgroundColor), 'rgb(242, 214, 219)');
    assert.equal(await page.locator('.dots__edge--me').first().evaluate(node => getComputedStyle(node, '::after').backgroundColor), 'rgb(183, 33, 50)');
    let calls = 0;
    await rpc(page, state, args => { calls++; c.edges[args.p_payload.edge_id] = 1; c.rev++; });
    const panel = page.locator('.board-zoom--dots');
    await panel.scrollIntoViewIfNeeded();
    await page.screenshot({ path: `${OUT}/390-text1-${modern ? 'refinement-dots12' : 'mini-points-jeu'}-board.png`, fullPage: true });
    const box = await panel.boundingBox();
    await page.mouse.move(box.x + box.width - 40, box.y + box.height - 40);
    await page.mouse.down(); await page.mouse.move(box.x + 40, box.y + 40, { steps: 5 }); await page.mouse.up();
    assert.equal(calls, 0, 'Un déplacement du plateau ne trace pas de segment');
    if (modern) assert.ok(await panel.evaluate(node => node.scrollLeft > 0 && node.scrollTop > 0));
    await page.getByRole('button', { name: 'Agrandir le plateau', exact: true }).click();
    assert.equal(Math.round(await page.locator('.dots__edge').first().evaluate(node => node.getBoundingClientRect().width)), 66);
    const edge = page.locator(`[data-edge="h:${modern ? 11 : 4}:${modern ? 10 : 3}"]`);
    await edge.click();
    await page.waitForFunction(() => document.querySelector('.dots__edge[aria-pressed="true"]'));
    assert.equal(calls, 1);
    await page.getByRole('button', { name: 'Vue entière', exact: true }).click();
    assert.equal(await page.locator('.astra-overview[inert]').count(), 1);
    await page.getByRole('button', { name: 'Jouer', exact: true }).click();
    assert.equal(Math.round(await page.locator('.dots__edge').first().evaluate(node => node.getBoundingClientRect().width)), 44);
    pass(`Points : ${modern ? '12×12/121/264' : '5×5/16/40'} exacts, initiale réelle, pan sans coup, zoom66/44 px, coin inférieur accessible, vue entière inerte`);
    await ctx.close();
  }
  {
    const { page, ctx, state, c } = await make('mini-de-jeu', { mutate: state => Object.assign(state.rounds.at(-1).card, { rev: 4 }) });
    let release, count = 0;
    await rpc(page, state, async args => { count++; await new Promise(resolve => { release = resolve; }); c.rev++; c.last = { type: args.p_type, seat: 1 }; Object.assign(c, { die: 1, turn_total: 0, rolls: [], bust: true, turn: 2, log: [{ seat: 1, die: 1 }] }); });
    await page.getByRole('button', { name: 'Lancer', exact: true }).evaluate(node => { node.click(); node.click(); });
    await page.waitForTimeout(100);
    assert.equal(count, 1); assert.match(await page.locator('.pig-die-img').getAttribute('src'), /die-5.webp$/);
    release(); await page.locator('.pig-pot.is-bust').waitFor();
    assert.match(await page.locator('.pig-die-img').getAttribute('src'), /die-1.webp$/);
    assert.deepEqual(c.banked, { '1': 12, '2': 24 });
    assert.equal(await page.locator('.pig-pot__val').textContent(), '0');
    assert.equal(await page.locator('.pig-tray__die').evaluate(node => parseFloat(getComputedStyle(node).animationDuration)), 0.28);
    await page.reload({ waitUntil: 'networkidle' }); assert.equal(await page.locator('.astra-die--land').count(), 0);
    pass('Pig : double clic =1 RPC, face conservée pendant attente, 1 serveur annule seul provisoire, acquis12/24 intacts, animation280 ms sans rejeu au rechargement'); await ctx.close();
  }
  {
    const { page, ctx } = await make('mini-naval-placement');
    await page.getByRole('gridcell', { name: /^J10 :/ }).click();
    assert.ok(await page.locator('.naval__cell--preview-invalid').count());
    assert.equal(await page.getByRole('button', { name: /Placer.*J10/ }).isDisabled(), true);
    await page.getByRole('gridcell', { name: /^F1 :/ }).click();
    assert.equal(await page.locator('.naval__cell--preview-valid').count(), 5);
    await page.getByRole('gridcell', { name: /^G1 :/ }).hover();
    assert.equal(await page.getByRole('button', { name: /Placer.*F1/ }).count(), 1, 'Le survol ne modifie pas l’ancre choisie au clic');
    assert.equal(await page.getByRole('button', { name: /Placer.*G1/ }).count(), 0);
    await page.getByRole('button', { name: /Placer.*F1/ }).click();
    assert.equal(await page.locator('.mini-naval-ship').count(), 5);
    assert.equal(await page.locator('.naval__cell--preview-valid').count(), 0);
    pass('Naval placement : 5 bateaux privés, empreinte5 cases, débordement invalide, ancreF1 inchangée au survolG1 avant confirmation'); await ctx.close();
  }
  {
    const { page, ctx, state, c } = await make('mini-naval-tirs');
    assert.equal(await page.locator('.mini-naval-ship').count(), 0);
    assert.equal(await page.locator('.mini-fleet-manifest li').count(), 5);
    let calls = 0;
    await rpc(page, state, args => { calls++; c.shots['1'].push({ r: args.p_payload.row, c: args.p_payload.col, res: 'hit', ship: 'croiseur' }); c.rev++; c.last = { seat: 1, type: 'fire' }; });
    await page.getByRole('gridcell', { name: /^A1 :/ }).click(); assert.equal(calls, 0);
    await page.getByRole('button', { name: /Tirer.*A1/ }).evaluate(node => { node.click(); node.click(); });
    await page.locator('.naval__cell--hit').waitFor(); assert.equal(calls, 1);
    await page.getByRole('tab', { name: /Ma flotte/ }).click();
    assert.equal(await page.locator('.mini-naval-ship').count(), 5);
    pass('Naval tirs : aucune position adverse dans le plateau, réticule sans RPC, confirmation unique, flotte propre accessible par onglet'); await ctx.close();
  }
  {
    const { page, ctx } = await make('mini-pfc-revelation', { mutate: state => { state.rounds.at(-1).card.locked = { '1': true }; } });
    assert.equal(await page.locator('.rps--reveal').count(), 0);
    pass('PFC : aucune révélation à un seul verrou même si une fixture contient gestes finaux'); await ctx.close();
  }
  {
    const { page, ctx } = await make('mini-de-jeu', { reducedMotion: 'reduce' });
    assert.equal(await page.locator('.pig-tray__die').evaluate(node => getComputedStyle(node).animationName), 'none');
    pass('Mouvement réduit : dé immobile'); await ctx.close();
  }
  for (const name of ['mini-points-jeu', 'mini-de-jeu', 'mini-naval-tirs']) {
    const { page, ctx } = await make(name, { mutate: state => {
      const round = state.rounds.at(-1), c = round.card;
      c.done = true; c.winner = 1; round.revealed = true;
      if (c.mech === 'dots_boxes') {
        c.owner = Array.from({ length: 16 }, (_, index) => index < 9 ? 1 : 2); c.tally = { '1': 9, '2': 7 }; c.scores = c.tally;
        c.edges = Object.fromEntries(Array.from({ length: 5 }, (_, row) => Array.from({ length: 4 }, (_, col) => [[`h:${row}:${col}`, 1], [`v:${col}:${row}`, 2]])).flat(2));
      } else if (c.mech === 'nd_pig') {
        c.banked = { '1': 31, '2': 24 }; c.scores = c.banked; c.turn_total = 0; c.die = null; c.rolls = [];
      } else { c.scores = { '1': 1, '2': 0 }; c.sunk['1'] = c.ships.map(ship => ship.id); }
    } });
    if (name === 'mini-points-jeu') { assert.equal(await page.locator('.dots__edge--on').count(), 40); assert.equal(await page.locator('.dots__edge:not(:disabled)').count(), 0); }
    if (name === 'mini-de-jeu') { assert.equal(await page.locator('.mini-pig-result img').count(), 1); assert.match(await page.locator('.mini-pig-result').innerText(), /31/); }
    if (name === 'mini-naval-tirs') { assert.equal(await page.locator('.mini-fleet-manifest .is-sunk').count(), 5); assert.equal(await page.locator('.mini-naval-ship').count(), 0); }
    await page.locator('.mini-refined').first().scrollIntoViewIfNeeded();
    await page.screenshot({ path: `${OUT}/390-result-${name}.png`, fullPage: true });
    pass(`Résultat ${name} : objets et valeurs de la carte finale, aucune action de plateau ou position adverse`); await ctx.close();
  }
  writeFileSync(`${OUT}/${flowsOnly ? 'flows' : 'checks'}.json`, JSON.stringify(checks, null, 2));
} finally { await browser.close(); }
