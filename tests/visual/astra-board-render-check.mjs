// Vérifications UI avec RPC simulées uniquement ; aucune base distante appelée.
// BASE et PW_CHROMIUM configurables. Les invariants SQL se vérifient séparément.
import { chromium } from '@playwright/test';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,SESSION}=await import('./render-check.mjs');
const BASE=process.env.BASE ?? 'http://localhost:4173';
const OUT=process.env.OUT ?? 'test-results/astra-board-render';mkdirSync(OUT,{recursive:true});
const rebase=o=>Array.isArray(o)?o.map(rebase):o&&typeof o==='object'?('__rel'in o?new Date(Date.now()+o.__rel*1000).toISOString():Object.fromEntries(Object.entries(o).map(([k,v])=>[k,rebase(v)]))):o;
const fixture=name=>rebase(JSON.parse(readFileSync(new URL(`./fixtures/c14-${name}.json`, import.meta.url),'utf8')));
const browser=await chromium.launch({executablePath:process.env.PW_CHROMIUM ?? '/usr/bin/chromium'});
const results=[];
async function make(name,{width=320,zoom=1,reducedMotion='no-preference',mutate}={}){
 const ctx=await browser.newContext({viewport:{width,height:780},serviceWorkers:'block',reducedMotion});
 const page=await ctx.newPage();const state=fixture(name);if(mutate)mutate(state);
 const scenario={...duo,notifications:[],state};await page.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort()); await setup(page,scenario);
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(`${BASE}/partie/${SESSION}`,{waitUntil:'networkidle'});
 if(zoom!==1)await page.addStyleTag({content:`html {font-size:${zoom*100}%}`});
 await page.locator('.astra-board').first().waitFor({state:'attached'});
 await page.locator('details').evaluateAll(nodes=>nodes.filter(node=>node.querySelector('.astra-board')).forEach(node=>node.open=true));
 return {page,ctx,state,errors,scenario};
}
try{
 const cases=['mini-morpion-jeu','mini-morpion-fin','mini-points-jeu','mini-pfc-verrouille','mini-pfc-revelation','mini-de-jeu','mini-naval-placement','mini-naval-tirs','mot-pendu-devineur','mot-pendu-fin','mot-bac-saisie','mot-bac-arbitrage'];
 for(const [width,zoom] of [[320,1],[390,1],[320,2]])for(const name of cases){
  const {page,ctx,errors}=await make(name,{width,zoom});
  const metrics=await page.evaluate(()=>{
   const small=[...document.querySelectorAll('.astra-board button,.astra-board input,.astra-board select,.astra-board summary')].filter(el=>{const r=el.getBoundingClientRect();return !el.closest('[inert]')&&r.width>0&&r.height>0&&(r.width<43.9||r.height<43.9)}).map(el=>({label:el.getAttribute('aria-label')||el.textContent,width:el.getBoundingClientRect().width,height:el.getBoundingClientRect().height}));
   return {overflow:document.documentElement.scrollWidth-innerWidth,small};
  });
  if(name==='mot-bac-saisie'){assert.equal(await page.locator('.pb-cell').count(),8);assert.equal(await page.locator('.pb-grid').evaluate(el=>getComputedStyle(el).gridTemplateColumns.split(' ').length),2);}
  await page.screenshot({path:`${OUT}/${width}-z${zoom}-${name}.png`,fullPage:true});
  const row={name,width,zoom,...metrics,errors};results.push(row);console.log(JSON.stringify(row));await ctx.close();
 }
 writeFileSync(`${OUT}/report.json`,JSON.stringify(results,null,2));
 assert.ok(results.every(r=>r.overflow===0&&!r.errors.length&&!r.small.length),'Overflow, runtime error or small target');
 console.log('PASS responsive: 36 vues, 320/390px, texte200%, huit rubriques en deux colonnes');
}finally{await browser.close();}
