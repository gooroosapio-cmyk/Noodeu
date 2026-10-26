// Vue navale entière/ciblage. Fixtures historiques et RPC simulées uniquement.
import { chromium } from '@playwright/test';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://localhost:4221';
const OUT = process.env.OUT ?? 'test-results/refinement-naval-fit';
const flowsOnly = process.argv.includes('--flows-only');
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
const matrix = [], flows = [];
async function make(phase, { width = 390, height = 844, text = 1, touch = false, card = {} } = {}) {
  const ctx = await browser.newContext({ viewport: { width, height }, hasTouch: touch, serviceWorkers: 'block' });
  const page = await ctx.newPage();
  const state = JSON.parse(readFileSync(new URL(`./fixtures/c14-mini-naval-${phase}.json`, import.meta.url), 'utf8'));
  Object.assign(state.rounds.at(-1).card, card);
  await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
  await setup(page, { ...duo, state, notifications: [] });
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.goto(`${BASE}/partie/${SESSION}`, { waitUntil: 'networkidle' });
  if (text !== 1) await page.addStyleTag({ content: `html { font-size:${text * 100}% }` });
  await page.locator('.naval-viewport').waitFor(); await page.evaluate(() => document.fonts.ready);
  return { page, ctx, state, c: state.rounds.at(-1).card, errors };
}
async function metrics(page) {
  return page.locator('.naval-viewport').evaluate(view => {
    const panel = view.querySelector('.naval-viewport__panel'), grid = view.querySelector('.naval');
    const cell = grid.querySelector('[data-cell="0"]'), r = cell.getBoundingClientRect();
    const fleet = [...grid.querySelectorAll('.mini-naval-ship')].map(ship => {
      const box = ship.getBoundingClientRect(), image = ship.querySelector('image'), m = image.getScreenCTM();
      const corners = [[85, 12], [170, 12], [85, 244], [170, 244]].map(([x, y]) => new DOMPoint(x, y).matrixTransform(m));
      return { orientation: ship.classList.contains('mini-naval-ship--h') ? 'H' : 'V', length: Number(ship.style.getPropertyValue('--ship-length')),
        width: box.width, height: box.height, scaleX: Math.hypot(m.a, m.b), scaleY: Math.hypot(m.c, m.d),
        hullWithinFootprint: corners.every(point => point.x >= box.left - 1 && point.x <= box.right + 1 && point.y >= box.top - 1 && point.y <= box.bottom + 1) };
    });
    const small = [...document.querySelectorAll('.mini-refined button,.mini-refined input,.mini-refined select,.mini-refined summary')].filter(node => {
      const box = node.getBoundingClientRect(); return box.width > 0 && box.height > 0 && (box.width < 43.9 || box.height < 43.9);
    }).map(node => node.getAttribute('aria-label') || node.textContent);
    const clippedHeaders = [...grid.querySelectorAll('.naval__head')].filter(node => { const range = document.createRange(); range.selectNodeContents(node); return range.getBoundingClientRect().width > node.getBoundingClientRect().width + 1; }).map(node => node.textContent);
    const clippedMarkers = [...grid.querySelectorAll('.astra-shot')].filter(node => { const marker = node.getBoundingClientRect(), cell = node.parentElement.getBoundingClientRect(); return marker.left < cell.left - 1 || marker.right > cell.right + 1 || marker.top < cell.top - 1 || marker.bottom > cell.bottom + 1 || Math.abs(marker.width - marker.height) > 1; }).length;
    const panelBox = panel.getBoundingClientRect(), toolbarBottom = document.querySelector('.session-toolbar')?.getBoundingClientRect().bottom ?? 0;
    return { pageOverflow: Math.max(0, document.documentElement.scrollWidth - innerWidth), panelOverflowX: panel.scrollWidth - panel.clientWidth,
      toolbarBottom, visiblePanelHeight: Math.max(0, Math.min(panelBox.bottom, innerHeight) - Math.max(panelBox.top, toolbarBottom)),
      panelOverflowY: panel.scrollHeight - panel.clientHeight, gridWidth: grid.getBoundingClientRect().width, gridHeight: grid.getBoundingClientRect().height,
      cellWidth: r.width, cellHeight: r.height, cells: grid.querySelectorAll('[role="gridcell"]').length, buttons: grid.querySelectorAll('button').length,
      readonly: grid.getAttribute('aria-readonly'), small, clippedHeaders, clippedMarkers, fleet };
  });
}
async function routeMove(page, state, handle) {
  await page.route('**/rpc/play_move', async route => {
    const args = route.request().postDataJSON(); const result = await handle(args); state.session.state_version++;
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(result ?? { ok: true }) });
  });
}
async function assertFocusedCell(page, index) {
  assert.equal(await page.locator(':focus').getAttribute('data-cell'), String(index));
  assert.equal(await page.locator(':focus').evaluate(node => getComputedStyle(node).outlineStyle), 'solid');
  const target = await page.locator(`.naval [data-cell="${index}"]`).boundingBox(), panel = await page.locator('.naval-viewport__panel').boundingBox();
  assert.ok(target.width >= 44 && target.height >= 44);
  assert.ok(target.x >= panel.x && target.y >= panel.y && target.x + target.width <= panel.x + panel.width && target.y + target.height <= panel.y + panel.height, `Case focalisée hors plateau visible : ${JSON.stringify({ target, panel })}`);
}
try {
  if (!flowsOnly) for (const width of [320, 360, 390, 430]) for (const height of [{ 320: 640, 360: 740, 390: 844, 430: 932 }[width], 460]) for (const text of [1, 2]) for (const phase of ['placement', 'tirs']) {
    const { page, ctx, errors } = await make(phase, { width, height, text });
    if (phase === 'placement' && height !== 460 && text === 1) {
      await page.waitForTimeout(300);
      const initialBoard = await page.locator('.naval').boundingBox();
      assert.ok(initialBoard.y + initialBoard.height <= height, `Plateau initial coupé : ${JSON.stringify({ width, height, initialBoard })}`);
      await page.screenshot({ path: `${OUT}/${width}x${height}-placement-initial.png`, fullPage: true });
    }
    for (const mode of ['overview', 'target']) {
      if (mode === 'target') await page.getByRole('button', { name: 'Cibler une case', exact: true }).click();
      const panel = page.locator('.naval-viewport__panel'); await panel.scrollIntoViewIfNeeded(); await page.waitForTimeout(300);
      const row = { width, height, text, phase, mode, ...await metrics(page), errors: [...errors] };
      matrix.push(row);
      await page.screenshot({ path: `${OUT}/${width}x${height}-text${text}-${phase}-${mode}.png`, fullPage: true });
      assert.equal(row.cells, 100); assert.equal(row.pageOverflow, 0); assert.equal(row.small.length, 0); assert.equal(row.errors.length, 0);
      assert.ok(row.visiblePanelHeight >= 44, `Plateau masqué par le bandeau : ${JSON.stringify(row)}`);
      assert.equal(row.clippedHeaders.length, 0, JSON.stringify(row));
      assert.equal(row.clippedMarkers, 0, JSON.stringify(row));
      if (mode === 'overview') {
        assert.equal(row.buttons, 0); assert.equal(row.readonly, 'true'); assert.ok(row.panelOverflowX <= 1, JSON.stringify(row));
        if (height !== 460) assert.ok(row.panelOverflowY <= 1, JSON.stringify(row));
        assert.ok(row.cellWidth > row.cellHeight + 1, JSON.stringify(row));
      } else { assert.equal(row.buttons, 100); assert.ok(row.cellWidth >= 44 && row.cellHeight >= 44); }
      for (const ship of row.fleet) {
        assert.ok(Math.abs(ship.scaleX - ship.scaleY) < .001, `Coque déformée : ${JSON.stringify(ship)}`);
        assert.ok(ship.hullWithinFootprint, JSON.stringify(ship));
        assert.ok(Math.abs(ship.width - (ship.orientation === 'H' ? ship.length * row.cellWidth + (ship.length - 1) * 2 : row.cellWidth)) < 1);
        assert.ok(Math.abs(ship.height - (ship.orientation === 'V' ? ship.length * row.cellHeight + (ship.length - 1) * 2 : row.cellHeight)) < 1);
      }
    }
    await ctx.close();
  }
  if (!flowsOnly) console.log('PASS 64 vues : 4 largeurs × 2 hauteurs × texte100/200% × placement/tirs × aperçu/ciblage ; coordonnées, cibles, empreintes et proportions');
  {
    const { page, ctx, state } = await make('placement'); let requests = [];
    await routeMove(page, state, args => { requests.push(args); });
    const overview = await page.locator('.naval-overview').boundingBox();
    await page.mouse.move(overview.x + overview.width - 30, overview.y + 50); await page.mouse.down();
    await page.mouse.move(overview.x + 30, overview.y + 80, { steps: 5 }); await page.mouse.up();
    assert.equal(await page.locator('.naval button').count(), 0); assert.equal(requests.length, 0);
    await page.getByRole('gridcell', { name: /^A10 :/ }).click();
    await assertFocusedCell(page, 9);
    assert.equal(await page.getByRole('button', { name: /^Placer.*A10/ }).count(), 0); assert.equal(requests.length, 0);
    await page.getByRole('button', { name: 'Vue entière', exact: true }).click();
    assert.equal(await page.locator(':focus').textContent(), 'Cibler une case');
    await page.getByRole('gridcell', { name: /^J10 :/ }).click();
    await assertFocusedCell(page, 99);
    assert.equal(await page.getByRole('button', { name: /^Placer.*J10/ }).count(), 0); assert.equal(requests.length, 0);
    await page.getByRole('gridcell', { name: /^J10 :/ }).click();
    assert.equal(await page.getByRole('button', { name: /^Placer.*J10/ }).isDisabled(), true);
    await page.getByRole('gridcell', { name: /^F1 :/ }).click();
    await page.getByRole('button', { name: /^Tourner/ }).click();
    assert.equal(await page.locator('.naval__cell--preview-valid').count(), 5);
    await page.getByRole('gridcell', { name: /^G2 :/ }).hover();
    await page.getByRole('button', { name: /^Placer.*F1/ }).click();
    await page.getByRole('button', { name: /Enregistrer ce placement/ }).click();
    assert.equal(requests.length, 1);
    assert.deepEqual(requests[0].p_payload.ships.find(ship => ship.id === 'porte-avions'), { id: 'porte-avions', start_row: 5, start_col: 0, orientation: 'V' });
    await page.getByRole('button', { name: 'Vue entière', exact: true }).click();
    assert.equal(await page.locator('.naval button').count(), 0);
    await page.screenshot({ path: `${OUT}/390-placement-F1-vertical-overview.png`, fullPage: true });
    flows.push('Placement : drag aperçu sans ouverture ; tapA10 sous sprite et tapJ10 ouvrent/focalisent44 sans sélection/RPC ; retour au bouton Cibler ; J10 invalide ; F1 + rotationV + survolG2 conserve ancre ; payloadF1/V exact ; retour aperçu sans boutons'); await ctx.close();
  }
  {
    const { page, ctx, state, c } = await make('tirs', { touch: true }); let requests = [];
    await routeMove(page, state, args => { requests.push(args); c.shots['1'].push({ r: args.p_payload.row, c: args.p_payload.col, res: 'hit', ship: 'croiseur' }); c.rev++; c.last = { seat: 1, type: 'fire' }; });
    assert.equal(await page.locator('.mini-naval-ship').count(), 0);
    await page.getByRole('gridcell', { name: /^A7 :/ }).tap();
    assert.equal(await page.getByRole('gridcell', { name: /^A7 :/ }).isDisabled(), true);
    assert.equal(await page.locator(':focus').getAttribute('role'), 'region');
    assert.equal(await page.locator('.naval__cell--aim').count(), 0); assert.equal(requests.length, 0);
    await page.getByRole('button', { name: 'Vue entière', exact: true }).click();
    await page.locator('.naval-viewport__panel').focus(); await page.keyboard.press('Enter');
    await assertFocusedCell(page, 0);
    assert.equal(await page.locator('.naval__cell--aim').count(), 0); assert.equal(requests.length, 0);
    await page.getByRole('button', { name: 'Vue entière', exact: true }).click();
    await page.getByRole('gridcell', { name: /^J10 :/ }).tap();
    await assertFocusedCell(page, 99);
    assert.equal(await page.locator('.naval__cell--aim').count(), 0); assert.equal(requests.length, 0);
    await page.waitForTimeout(300);
    await page.screenshot({ path: `${OUT}/390-tap-J10-target.png`, fullPage: true });
    await page.getByRole('button', { name: 'Vue entière', exact: true }).click();
    await page.getByRole('button', { name: 'Cibler une case', exact: true }).click();
    const panel = page.locator('.naval-viewport__panel'); await panel.scrollIntoViewIfNeeded();
    const box = await panel.boundingBox(); await page.mouse.move(box.x + box.width - 30, box.y + box.height - 30); await page.mouse.down(); await page.mouse.move(box.x + 30, box.y + 30, { steps: 5 }); await page.mouse.up();
    assert.equal(await page.locator('.naval__cell--aim').count(), 0); assert.equal(requests.length, 0);
    await page.getByRole('button', { name: 'Agrandir le plateau', exact: true }).click();
    assert.equal(Math.round((await metrics(page)).cellWidth), 66);
    const j9 = page.getByRole('gridcell', { name: /^J9 :/ }); await j9.focus(); await page.keyboard.press('ArrowRight');
    assert.match(await page.locator(':focus').getAttribute('aria-label'), /^J10 :/); await page.keyboard.press('Enter'); assert.equal(requests.length, 0);
    await page.getByRole('button', { name: /Tirer.*J10/ }).evaluate(node => { node.click(); node.click(); });
    await page.locator('[data-cell="99"].naval__cell--hit').waitFor();
    assert.equal(requests.length, 1); assert.deepEqual(requests[0].p_payload, { row: 9, col: 9 });
    await page.getByRole('button', { name: 'Vue entière', exact: true }).click();
    await page.screenshot({ path: `${OUT}/390-tir-J10-overview.png`, fullPage: true });
    await page.getByRole('tab', { name: 'Ma flotte', exact: true }).click();
    assert.equal(await page.locator('.mini-naval-ship').count(), 5);
    flows.push('Tirs : flotte adverse absente ; tap case déjà tirée sans cible/RPC ; Entrée ouvre44 ; tap tactileJ10 focalise sans tirer ; pan sans cible/RPC ; zoom66 ; clavierJ9→J10 ; confirmation unique payload9/9 ; impact serveur visible en aperçu ; 5 navires privés dans Ma flotte'); await ctx.close();
  }
  {
    const { page, ctx, state, c } = await make('placement'); const requests = [];
    await routeMove(page, state, args => {
      requests.push(args);
      if (args.p_type === 'random_fleet') state.rounds.at(-1).private.fleet = c.ships.map((ship, i) => ({ ...ship, r: i * 2, c: 1, o: 'H' }));
      if (args.p_type === 'lock_fleet') c.locked['1'] = true;
      c.rev++;
    });
    await page.getByRole('button', { name: 'Placement aléatoire', exact: true }).click();
    await page.locator('.mini-naval-ship--h').nth(4).waitFor();
    assert.equal(requests.length, 1); assert.equal(requests[0].p_type, 'random_fleet');
    assert.deepEqual(await page.locator('.mini-naval-ship').evaluateAll(ships => ships.map(ship => [ship.style.gridRow, ship.style.gridColumn])), [2, 4, 6, 8, 10].map((row, i) => [`${row} / span 1`, `3 / span ${[5, 4, 3, 3, 2][i]}`]));
    await page.getByRole('button', { name: 'Valider ma flotte', exact: true }).click();
    await page.getByText('Flotte verrouillée', { exact: true }).waitFor();
    assert.equal(requests.length, 2); assert.equal(requests[1].p_type, 'lock_fleet');
    await page.getByRole('gridcell', { name: /^A2 :/ }).click();
    assert.equal(await page.locator('.naval button:enabled').count(), 0); assert.equal(requests.length, 2);
    flows.push('Placement aléatoire : une RPC, cinq empreintes serveur exactes ; verrouillage confirmé ; agrandissement de la flotte verrouillée sans modification'); await ctx.close();
  }
  {
    const { page, ctx, state } = await make('tirs', { card: { turn: 2 }, touch: true }); const requests = [];
    await routeMove(page, state, args => { requests.push(args); });
    await page.getByRole('gridcell', { name: /^J10 :/ }).tap();
    assert.equal(await page.locator('.naval button:enabled').count(), 0);
    assert.equal(await page.locator('.naval__cell--aim').count(), 0); assert.equal(requests.length, 0);
    assert.equal(await page.locator('.mini-naval-ship').count(), 0);
    flows.push('Tour adverse : agrandir reste possible, aucune cible active, aucun tir ni navire adverse exposé'); await ctx.close();
  }
  console.log(flows.map(message => `PASS ${message}`).join('\n'));
} finally {
  writeFileSync(`${OUT}/matrix.json`, JSON.stringify(matrix, null, 2));
  writeFileSync(`${OUT}/flows.json`, JSON.stringify(flows, null, 2));
  await browser.close();
}
