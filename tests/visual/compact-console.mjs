// Validation locale avec RPC fictives ; aucun accès à un compte réel.
import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,SESSION}=await import('./render-check.mjs');
const BASE=process.env.BASE??'http://127.0.0.1:4221',OUT=process.env.OUT??'test-results/compact-console';
mkdirSync(OUT,{recursive:true});
const rebase=o=>Array.isArray(o)?o.map(rebase):o&&typeof o==='object'?'__rel'in o?new Date(Date.now()+o.__rel*1000).toISOString():Object.fromEntries(Object.entries(o).map(([k,v])=>[k,rebase(v)])):o;
const browser=await chromium.launch({executablePath:'/usr/bin/chromium'}),results=[];
try {
 for(const f of ['conv-preferes-jeu','conv-av-verite','mot-bac-saisie','pack-attente']) for(const [width,height,zoom] of [[320,780,1],[360,780,1],[390,844,1],[430,844,1],[320,640,2],[390,460,1]]) {
  if(process.env.ONLY && !f.includes(process.env.ONLY))continue;
  const state=rebase(JSON.parse(readFileSync(new URL(`./fixtures/c14-${f}.json`,import.meta.url),'utf8')));
  const context=await browser.newContext({viewport:{width,height},reducedMotion:'reduce',serviceWorkers:'block'}),page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));await page.route('**/*',r=>new URL(r.request().url()).origin===new URL(BASE).origin?r.continue():r.abort());
  await setup(page,{...duo,state,notifications:[]});await page.goto(`${BASE}/partie/${SESSION}`);await page.locator('.session-console').waitFor();
  if(zoom===2)await page.addStyleTag({content:'html{font-size:200%}'});
  await page.evaluate(async()=>{await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));});
  assert.equal(await page.locator('.session-toolbar__commands').count(),0);
  assert.equal(await page.locator('.session-player-strip__status').filter({hasText:/^(Toi|Partenaire)$/}).count(),0);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
  for(const s of ['.session-toolbar__reduce','.session-toolbar__menu']){const b=await page.locator(s).boundingBox();assert.ok(b.width>=44&&b.height>=44);assert.ok(b.x>=0&&b.x+b.width<=width);}
  if(f==='pack-attente'&&zoom===1){const region=page.getByRole('region',{name:'Question du pack',exact:true});assert.ok(await region.evaluate(e=>{const q=e.querySelector('.t-question').getBoundingClientRect();const b=e.getBoundingClientRect();return q.top>=b.top-1&&q.bottom<=b.bottom+1;}),'Question standard du pack visible intégralement');}
  if(f==='mot-bac-saisie'){
   assert.equal(await page.locator('.pb-cell').count(),8);assert.equal(await page.getByText('NaN:NaN',{exact:true}).count(),0);assert.equal(await page.locator('.pb-cell__state').filter({hasText:/Rempli/i}).count(),0);
   assert.doesNotMatch(await page.locator('.astra-board--petitbac').innerText(), /rempli/iu, 'Compteur et consigne sans le libellé superflu');
   const inputs=page.locator('.pb-cell__input');assert.equal(await inputs.count(),8);await inputs.last().focus();await inputs.last().scrollIntoViewIfNeeded();
   assert.ok(await inputs.last().evaluate(e=>parseFloat(getComputedStyle(e).fontSize)>=16));
  }
  await page.locator('.session-toolbar__menu').click();await page.getByRole('dialog',{name:'Commandes de la partie',exact:true}).waitFor();
  assert.equal(await page.locator('.chat-launcher').isVisible(),false);assert.equal(await page.getByRole('button',{name:'Règles',exact:true}).isVisible(),true);
  assert.equal(await page.getByRole('button',{name:'Pause',exact:true}).isVisible(),true);assert.equal(await page.getByRole('button',{name:'Quitter',exact:true}).isVisible(),true);
  await page.keyboard.press('Escape');await page.getByRole('dialog').waitFor({state:'detached'});
  assert.ok(await page.locator('.session-toolbar__menu').evaluate(e=>e===document.activeElement));
  await page.screenshot({path:`${OUT}/${f}-${width}-${height}-${zoom}.png`});assert.deepEqual(errors,[]);results.push({f,width,height,zoom,ok:true});await context.close();
 }
 console.log(`PASS ${results.length} vues : header compact, commandes conservées, statuts utiles, huit champs, clavier/200%.`);
}finally{writeFileSync(`${OUT}/report.json`,JSON.stringify(results,null,2));await browser.close();}
