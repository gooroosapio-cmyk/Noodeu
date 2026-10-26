// Coffre : pagination et isolation des contextes, données fictives et réseau externe bloqué.
// BASE=http://127.0.0.1:4269 node tests/visual/vault-pagination-flows.mjs
import assert from 'node:assert/strict';
import { mkdirSync } from 'node:fs';
import { chromium, expect } from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY = '1';
const { setup, duo, activeDuo } = await import('./render-check.mjs');
const BASE = process.env.BASE ?? 'http://127.0.0.1:4269';
const OUT = process.env.OUT ?? 'test-results/vault-pagination';
mkdirSync(OUT, { recursive: true });
const A = activeDuo.id;
const B = '77777777-7777-4777-8777-777777777777';
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
const deferred = () => { let resolve; const promise = new Promise(r => { resolve = r; }); return { promise, resolve }; };
const row = (n, keep = false, coupleId = A, extra = {}) => ({
  ...duo.history[0], id: `00000000-0000-4000-a000-${String(n).padStart(12, '0')}`, couple_id: coupleId,
  created_at: new Date(Date.UTC(2026, 9, 26, 12) - n * 60_000).toISOString(),
  games: { title: `Souvenir fixture ${n}` }, session_players: [{ keep_memory: keep }, { keep_memory: keep }], ...extra,
});
const recent = (keptIds = []) => Array.from({ length: 30 }, (_, i) => row(i + 1, keptIds.includes(i + 1)));
const secondDuo = { ...activeDuo, id: B, current: false, partner: { ...activeDuo.partner, name: 'Duo B fixture' } };
let passed = 0, failures = 0;

async function run(name, history, body, initialPath = '/espace/coffre') {
  if (process.env.ONLY && !new RegExp(process.env.ONLY).test(name)) return;
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, serviceWorkers: 'block' });
  const page = await ctx.newPage();
  page.setDefaultTimeout(8000);
  const errors = [], calls = [];
  const scenario = { ...duo, notifications: [], duos: [{ ...activeDuo, current: true }, { ...secondDuo }], history };
  page.on('pageerror', error => errors.push(error.message));
  let intercept;
  try {
    await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort());
    await setup(page, scenario);
    await page.route('**/rest/v1/game_sessions?*', async route => {
      const query = new URL(route.request().url()).searchParams;
      const call = { couple: query.get('couple_id'), offset: Number(query.get('offset') ?? 0), limit: Number(query.get('limit')), order: query.get('order'), status: query.get('status'), select: query.get('select') };
      calls.push(call);
      if (intercept && await intercept(route, call)) return;
      await route.fallback();
    });
    const harness = {
      calls, scenario,
      intercept: fn => { intercept = fn; },
      open: () => page.goto(BASE + initialPath),
      select: async id => {
        scenario.duos.forEach(d => { d.current = d.id === id; });
        await page.evaluate(() => window.dispatchEvent(new Event('focus')));
      },
    };
    await body(page, harness);
    for (const call of calls) {
      assert.ok([`eq.${A}`, `eq.${B}`].includes(call.couple), 'chaque page doit filtrer le duo');
      assert.equal(call.limit, 30, 'lecture bornée à 30 parties');
      assert.equal(call.order, 'created_at.desc,id.desc', 'ordre stable, y compris aux dates identiques');
      assert.equal(call.status, 'in.(ended,closed,abandoned)');
      assert.equal(call.select, 'id,game_id,status,created_at,started_at,ended_at,current_round,total_rounds,games(title),session_players(keep_memory)', 'aucune colonne privée ni nouvelle jointure');
    }
    assert.deepEqual(errors, []);
    passed++;
    console.log('PASS ' + name);
  } catch (error) {
    failures++;
    console.error('FAIL ' + name + ': ' + error.stack);
  } finally { await ctx.close(); }
}

const memories = page => page.locator('.v7-memories a');
const more = page => page.getByRole('button', { name: 'Voir plus ancien', exact: true });
const retry = page => page.getByRole('button', { name: 'Réessayer', exact: true });
const settled = page => expect(page.getByRole('region', { name: 'Souvenirs gardés' })).toHaveAttribute('aria-busy', 'false');

try {
  await run('31e souvenir accessible ; aucun faux coffre vide ; double clic bloqué', [...recent(), row(31, true), row(0, true, B)], async (page, h) => {
    const held = deferred(), started = deferred();
    h.intercept(async (_route, call) => { if (call.offset === 30) { started.resolve(); await held.promise; } });
    await h.open();
    await expect(page.getByText('Aucun souvenir trouvé dans les parties récentes.', { exact: false })).toBeVisible();
    assert.equal(await page.getByText('Aucun souvenir pour le moment', { exact: false }).count(), 0);
    assert.equal(await memories(page).count(), 0);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(350);
    await page.screenshot({ path: `${OUT}/31e-avant.png`, fullPage: true });
    await more(page).evaluate(button => { button.click(); button.click(); });
    await started.promise;
    await expect(more(page)).toBeDisabled();
    assert.equal(h.calls.filter(c => c.offset === 30).length, 1);
    held.resolve();
    await expect(memories(page)).toHaveCount(1);
    await expect(memories(page)).toContainText('Souvenir fixture 31');
    await settled(page);
    assert.equal(await more(page).count(), 0);
    await page.screenshot({ path: `${OUT}/31e-apres.png`, fullPage: true });
  });

  await run('échec de page ; souvenirs préservés ; reprise au même offset', [...recent([1]), row(31, true)], async (page, h) => {
    let failuresLeft = 1;
    h.intercept(async (route, call) => {
      if (call.offset === 30 && failuresLeft-- > 0) {
        await route.fulfill({ status: 400, json: { message: 'fixture pagination error', code: 'fixture_error' } });
        return true;
      }
    });
    await h.open();
    await expect(memories(page)).toHaveCount(1);
    await more(page).click();
    await expect(retry(page)).toBeVisible();
    await expect(page.getByRole('alert')).toBeVisible();
    await expect(memories(page)).toHaveCount(1);
    await retry(page).click();
    await expect(memories(page)).toHaveCount(2);
    assert.deepEqual(h.calls.filter(c => c.offset > 0).map(c => c.offset), [30, 30]);
    assert.equal(await page.getByRole('alert').count(), 0);
  });

  await run('première lecture en erreur ; reprise sans faux état vide', [row(1, true)], async (page, h) => {
    let fail = true;
    h.intercept(async route => {
      if (fail) { await route.fulfill({ status: 400, json: { message: 'fixture initial error' } }); return true; }
    });
    await h.open();
    await expect(retry(page)).toBeVisible();
    assert.equal(await page.getByText('Aucun souvenir', { exact: false }).count(), 0);
    fail = false;
    await retry(page).click();
    await expect(memories(page)).toHaveCount(1);
    assert.ok(h.calls.every(c => c.offset === 0));
  });

  await run('chevauchement entre pages dédupliqué ; dates identiques ordonnées', Array.from({ length: 31 }, (_, i) => row(i + 1, true, A, { created_at: '2026-10-26T12:00:00Z' })).reverse(), async (page, h) => {
    h.intercept(async (route, call) => {
      if (call.offset === 30) {
        await route.fulfill({ json: [h.scenario.history.find(r => r.id.endsWith('000000000002')), h.scenario.history.find(r => r.id.endsWith('000000000001'))] });
        return true;
      }
    });
    await h.open();
    await expect(memories(page)).toHaveCount(30);
    await expect(memories(page).first()).toContainText('Souvenir fixture 31');
    await expect(memories(page).last()).toContainText('Souvenir fixture 2');
    await more(page).click();
    await expect(memories(page)).toHaveCount(31);
    await expect(memories(page).last()).toContainText('Souvenir fixture 1');
  });

  await run('réponse initiale tardive du duo A ignorée après passage à B', [row(1, true), row(90, true, B)], async (page, h) => {
    const held = deferred(), started = deferred(), delivered = deferred();
    h.intercept(async (route, call) => {
      if (call.couple === `eq.${A}`) {
        started.resolve(); await held.promise;
        await route.fulfill({ json: [row(1, true)] }); delivered.resolve(); return true;
      }
    });
    await h.open(); await started.promise;
    await h.select(B);
    await expect(memories(page)).toContainText('Souvenir fixture 90');
    held.resolve(); await delivered.promise;
    await page.waitForTimeout(100);
    await expect(memories(page)).toHaveCount(1);
    assert.equal(await page.getByText('Souvenir fixture 1', { exact: true }).count(), 0);
  });

  await run('page ancienne A ignorée après A → B → A ; pagination réinitialisée', [...recent([1]), row(31, true), row(90, true, B)], async (page, h) => {
    const held = deferred(), started = deferred(), delivered = deferred();
    h.intercept(async (route, call) => {
      if (call.offset === 30) {
        started.resolve(); await held.promise;
        await route.fulfill({ json: [row(31, true)] }); delivered.resolve(); return true;
      }
    });
    await h.open(); await expect(memories(page)).toHaveCount(1);
    await more(page).click(); await started.promise;
    await h.select(B); await expect(memories(page)).toContainText('Souvenir fixture 90');
    h.scenario.history = [row(2, true), row(90, true, B)];
    await h.select(A); await expect(memories(page)).toContainText('Souvenir fixture 2');
    held.resolve(); await delivered.promise;
    await page.waitForTimeout(100);
    await expect(memories(page)).toHaveCount(1);
    assert.equal(await page.getByText('Souvenir fixture 31', { exact: true }).count(), 0);
    assert.equal(h.calls.at(-1).offset, 0);
  });

  await run('notes sans requête souvenirs ; retour tardif abandonné puis rechargement', [...recent([1]), row(31, true)], async (page, h) => {
    const held = deferred(), started = deferred(), delivered = deferred();
    h.intercept(async (route, call) => {
      if (call.offset === 30) {
        started.resolve(); await held.promise;
        await route.fulfill({ json: [row(31, true)] }); delivered.resolve(); return true;
      }
    });
    await h.open();
    await expect(page.getByText('Choisir une idée pour notre prochain week-end')).toBeVisible();
    assert.equal(h.calls.length, 0);
    await page.getByRole('button', { name: 'Souvenirs', exact: true }).click();
    await expect(memories(page)).toHaveCount(1);
    await more(page).click(); await started.promise;
    await page.getByRole('button', { name: 'Nos notes', exact: true }).click();
    const count = h.calls.length;
    held.resolve(); await delivered.promise;
    await page.waitForTimeout(100);
    assert.equal(await memories(page).count(), 0);
    assert.equal(h.calls.length, count);
    await page.getByRole('button', { name: 'Souvenirs', exact: true }).click();
    await expect(memories(page)).toHaveCount(1);
    assert.equal(h.calls.at(-1).offset, 0);
  }, '/espace/coffre?tab=notes');

  await run('page pleine sans souvenir puis fin vide : état vide seulement après vérification', recent(), async (page, h) => {
    await h.open(); await expect(more(page)).toBeVisible();
    assert.equal(await page.getByText('Aucun souvenir pour le moment', { exact: false }).count(), 0);
    await more(page).click();
    await expect(page.getByText('Aucun souvenir pour le moment', { exact: false })).toBeVisible();
    assert.equal(await more(page).count(), 0);
    assert.equal(h.calls.at(-1).offset, 30);
  });
} finally { await browser.close(); }
console.log(`VAULT PAGINATION : ${passed} réussi(s), ${failures} échoué(s) ; aucun serveur externe appelé.`);
if (failures) process.exitCode = 1;
