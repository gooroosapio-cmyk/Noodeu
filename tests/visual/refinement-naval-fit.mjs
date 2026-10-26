// Vue navale entière/ciblage. Fixtures historiques et RPC simulées uniquement.
import { chromium } from '@playwright/test';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, SESSION } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://localhost:4221';
const OUT = process.env.OUT ?? 'test-results/refinement-naval-fit';
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
const matrix = [], flows = [];
async function make(phase, { width = 390, height = 844, text = 1 } = {}) {
  const ctx = await browser.newContext({ viewport: { width, height }, serviceWorkers: 'block' });
  const page = await ctx.newPage();
  const state = JSON.parse(readFileSync(new URL(`./fixtures/c14-mini-naval-${phase}.json`, import.meta.url), 'utf8'));
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
    return { pageOverflow: Math.max(0, document.documentElement.scrollWidth - innerWidth), panelOverflowX: panel.scrollWidth - panel.clientWidth,
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
try {
  for (const width of [320, 360, 390, 430]) for (const height of [{ 320: 640, 360: 740, 390: 844, 430: 932 }[width], 460]) for (const text of [1, 2]) for (const phase of ['placement', 'tirs']) {
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
  console.log('PASS 64 vues : 4 largeurs × 2 hauteurs × texte100/200% × placement/tirs × aperçu/ciblage ; coordonnées, cibles, empreintes et proportions');
  {
    const { page, ctx, state } = await make('placement'); let requests = [];
    await routeMove(page, state, args => { requests.push(args); });
    await page.getByRole('gridcell', { name: /^F1 :/ }).click();
    assert.equal(await page.getByRole('button', { name: /^Placer.*F1/ }).count(), 0); assert.equal(requests.length, 0);
    await page.getByRole('button', { name: 'Cibler une case', exact: true }).click();
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
    flows.push('Placement : aperçu sans sélection/RPC ; J10 invalide ; F1 + rotationV + survolG2 conserve ancre ; payloadF1/V exact ; retour aperçu sans boutons'); await ctx.close();
  }
  {
    const { page, ctx, state, c } = await make('tirs'); let requests = [];
    await routeMove(page, state, args => { requests.push(args); c.shots['1'].push({ r: args.p_payload.row, c: args.p_payload.col, res: 'hit', ship: 'croiseur' }); c.rev++; c.last = { seat: 1, type: 'fire' }; });
    assert.equal(await page.locator('.mini-naval-ship').count(), 0);
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
    flows.push('Tirs : flotte adverse absente ; pan sans cible/RPC ; zoom66 ; clavierJ9→J10 ; confirmation unique payload9/9 ; impact serveur visible en aperçu ; 5 navires privés dans Ma flotte'); await ctx.close();
  }
  console.log(flows.map(message => `PASS ${message}`).join('\n'));
} finally {
  writeFileSync(`${OUT}/matrix.json`, JSON.stringify(matrix, null, 2));
  writeFileSync(`${OUT}/flows.json`, JSON.stringify(flows, null, 2));
  await browser.close();
}
