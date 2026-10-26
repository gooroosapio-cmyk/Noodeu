// Préparation/prêt : fixtures seulement, aucun appel externe réel.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {chromium,expect} from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,SESSION}=await import('./render-check.mjs');
const BASE=process.env.BASE??'http://127.0.0.1:4221';
const browser=await chromium.launch({executablePath:'/usr/bin/chromium'});
let failures=0;
try {
 for(const changed of [false,true]) {
  const ctx=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block',reducedMotion:'no-preference'});
  const page=await ctx.newPage();page.setDefaultTimeout(7000);
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  let release,headStarted;const held=new Promise(r=>release=r),started=new Promise(r=>headStarted=r);
  try {
   await page.clock.install();await page.clock.pauseAt(new Date());
   await page.route('**/*',r=>new URL(r.request().url()).origin===new URL(BASE).origin?r.continue():r.abort());
   const state=JSON.parse(readFileSync(new URL('./fixtures/c14-lobby-n2-002.json',import.meta.url),'utf8'));
   state.session.id=SESSION;state.players.forEach(p=>p.ready=false);
   await setup(page,{...duo,notifications:[],state});
   let reads=0;const ready=[];
   await page.route('**/rpc/get_session_state',r=>{reads++;return r.fulfill({json:state});});
   await page.route('**/rpc/set_ready',r=>{ready.push(r.request().postDataJSON());state.players.find(p=>p.is_me).ready=true;state.session.state_version++;return r.fulfill({json:{ok:true}});});
   await page.route('**/assets/original/launch/noodeu-launch-3s.mp4',async r=>{headStarted();await held;await r.fulfill({status:404,body:''}).catch(()=>{});});
   await page.goto(`${BASE}/partie/${SESSION}`);const cta=page.locator('.salon-launch > button');
   await expect(cta).toHaveText('Valider les réglages');await cta.click();await started;
   assert.equal(ready.length,0);
   state.session.state_version++;
   if(changed)state.session.settings.cartes=20;
   const before=reads;await page.evaluate(()=>window.dispatchEvent(new Event('focus')));await expect.poll(()=>reads).toBeGreaterThan(before);
   // Observe réellement le nouveau snapshot avant de terminer la préparation.
   if(changed)await expect(page.getByRole('group',{name:'Nombre de cartes',exact:true}).getByRole('radio',{name:'20',exact:true})).toBeChecked();
   release();await page.clock.runFor(1800);
   if(changed){
    await expect(cta).toHaveText('Valider les réglages');assert.equal(ready.length,0,'changement de réglages : aucune validation implicite');
    await expect(page.getByText('Les réglages ont changé. Vérifie-les puis valide à nouveau.',{exact:true})).toBeVisible();
    await cta.click();await page.clock.runFor(1800);await expect.poll(()=>ready.length).toBe(1);
   }else{await expect.poll(()=>ready.length).toBe(1);assert.equal(ready[0].p_ready,true);}
   assert.deepEqual(errors,[]);console.log(`PASS préparation : ${changed?'nouveaux réglages exigent revalidation':'version seule conserve la validation'}`);
  }catch(e){failures++;console.error(`FAIL préparation ${changed?'settings changés':'version seule'} : ${e.message}`);}
  finally{release();await ctx.close();}
 }
}finally{await browser.close();}
if(failures)process.exitCode=1;
