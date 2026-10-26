// Données fictives seulement ; les appels extérieurs sont bloqués.
import {chromium} from '@playwright/test';
import {readFileSync, mkdirSync} from 'node:fs';
import assert from 'node:assert/strict';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,SESSION}=await import('./render-check.mjs');
const BASE=process.env.BASE ?? 'http://localhost:4173';
const OUT=process.env.OUT ?? 'test-results/astra-float';mkdirSync(OUT,{recursive:true});
const rebase=o=>Array.isArray(o)?o.map(rebase):o&&typeof o==='object'?('__rel'in o?new Date(Date.now()+o.__rel*1000).toISOString():Object.fromEntries(Object.entries(o).map(([k,v])=>[k,rebase(v)]))):o;
const b=await chromium.launch({executablePath:process.env.PW_CHROMIUM ?? '/usr/bin/chromium'});
try {
 for (const [width,height,zoom] of [[320,780,1],[360,780,1],[390,780,1],[430,780,1],[390,560,1],[320,780,2],[320,560,2],[390,320,2]]) {
  const ctx=await b.newContext({viewport:{width,height},serviceWorkers:'block'});
  const p=await ctx.newPage();
  await p.route('**/*',r=>new URL(r.request().url()).origin===new URL(BASE).origin?r.continue():r.abort());
  const state=rebase(JSON.parse(readFileSync(new URL('./fixtures/c14-mot-bac-saisie.json',import.meta.url))));
  state.rounds.at(-1).card.deadline_at=new Date(Date.now()+120000).toISOString();
  await setup(p,{...duo,state});
  await p.goto(`${BASE}/partie/${SESSION}`,{waitUntil:'networkidle'});
  if (zoom!==1) await p.addStyleTag({content:`html {font-size:${zoom*100}%}`});
  for (const ratio of [0,.25,.5,.75,1]) {
   await p.locator('main').evaluate((e,r)=>e.scrollTop=(e.scrollHeight-e.clientHeight)*r,ratio);
   await p.waitForTimeout(100);
   const hit=await p.evaluate(()=>{
    const b=document.querySelector('.chat-launcher').getBoundingClientRect();
    const main=document.querySelector('main'), m=main.getBoundingClientRect();
    const collisions=[...document.querySelectorAll('main a, main button, main input, main textarea, main select, main label, .session-toolbar a, .session-toolbar button')].filter(e=>{
     const r=e.getBoundingClientRect(), inMain=main.contains(e), top=inMain?Math.max(r.top,m.top):r.top, bottom=inMain?Math.min(r.bottom,m.bottom):r.bottom;
     return r.width&&r.height&&bottom>top&&Math.min(b.right,r.right)>Math.max(b.left,r.left)&&Math.min(b.bottom,bottom)>Math.max(b.top,top);
    }).map(e=>e.getAttribute('aria-label')||e.textContent||e.tagName);
    return {collisions,visible:b.top>=0&&b.bottom<=innerHeight&&b.left>=0&&b.right<=innerWidth};
   });
   if(hit.collisions.length) await p.screenshot({path:`${OUT}/failure-${width}x${height}-z${zoom}-${ratio}.png`});
   assert.deepEqual(hit.collisions,[],`${width}x${height} zoom${zoom} scroll${ratio}`);assert.ok(hit.visible);
  }
  await p.locator('main').evaluate(e=>e.scrollTop=0);await p.locator('input').first().focus();await p.waitForTimeout(100);
  await p.screenshot({path:`${OUT}/${width}x${height}-z${zoom}-petit-bac.png`});
  await p.locator('.chat-launcher').click();await p.getByRole('dialog').waitFor();assert.equal(await p.locator('.chat-launcher').isVisible(),false);
  console.log(`PASS ${width}x${height} texte${zoom}: 5 positions sans collision champs/labels/boutons, bulle visible, modal prioritaire`);
  await ctx.close();
 }
} finally {await b.close();}
