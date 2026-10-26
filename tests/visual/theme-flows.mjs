// Recette du thème sur fixtures seulement, sans serveur réel.
import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
import {mkdirSync} from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,sessionState,SESSION,activeDuo}=await import('./render-check.mjs');
const BASE=process.env.BASE ?? 'http://localhost:4173';
const browser=await chromium.launch({executablePath:'/usr/bin/chromium'});
mkdirSync('test-results/theme-flows',{recursive:true});
async function make(scenario){const ctx=await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce',serviceWorkers:'block'});const page=await ctx.newPage();await setup(page,scenario);return {page,ctx};}
try{
 {const {page,ctx}=await make({...duo,notifications:[]});await page.goto(`${BASE}/accueil`);
  await page.locator('.home-duo-card__actions > .btn').first().waitFor();
  const controls=await page.locator('.home-duo-card__actions > .btn').evaluateAll(xs=>xs.map(x=>{const r=x.getBoundingClientRect();return {w:r.width,h:r.height,y:r.y};}));
  assert.equal(controls.length,2);assert.ok(Math.abs(controls[0].w-controls[1].w)<1);assert.equal(controls[0].h,controls[1].h);assert.equal(controls[0].y,controls[1].y);
  assert.equal(await page.locator('.home-duo-card .art').count(),0);assert.equal(await page.locator('.home-duo-card .avatar').count(),2);
  await page.goto(`${BASE}/espace`);await page.locator('.duo-cover__identity .avatar').first().waitFor();
  assert.equal(await page.locator('.duo-dashboard').getByRole('link',{name:'Choisir un jeu'}).count(),0);
  assert.equal(await page.locator('.duo-dashboard').getByRole('button',{name:'Ouvrir la discussion'}).count(),0);
  await ctx.close();console.log('PASS accueil : avatars centrés et CTA égaux ; espace sans actions redondantes');}
 {const invite={id:'theme-invite',type:'game_proposed',couple_id:activeDuo.id,data:{session_id:SESSION,title:'Portrait en cinq mots',name:'Alex'},created_at:new Date().toISOString(),read_at:null};
  const {page,ctx}=await make({...duo,notifications:[invite],state:sessionState('lobby')});await page.goto(`${BASE}/accueil`);const dialog=page.getByRole('dialog');await dialog.waitFor();
  const r=await dialog.boundingBox();assert.ok(Math.abs(r.y+r.height/2-422)<2);assert.ok(Math.abs(r.x+r.width/2-195)<2);
  const buttons=await dialog.locator('.action-pair button').evaluateAll(xs=>xs.map(x=>{const r=x.getBoundingClientRect();return [r.width,r.height];}));assert.deepEqual(buttons[0],buttons[1]);
  assert.equal(await dialog.evaluate(el=>getComputedStyle(el).animationName),'none');
  await dialog.getByRole('button',{name:'Accepter',exact:true}).focus();await page.keyboard.press('Tab');assert.ok(await dialog.evaluate(el=>el.contains(document.activeElement)));
  await page.screenshot({path:'test-results/theme-flows/invitation-centree.png'});await page.goBack();await dialog.waitFor({state:'detached'});assert.ok(page.url().endsWith('/accueil'));
  await ctx.close();console.log('PASS invitation : centrage, égalité, focus contenu, retour et reduced-motion');}
 for(const status of ['lobby','playing','paused']){
  const {page,ctx}=await make({...duo,notifications:[],state:sessionState(status)});let calls=0;
  await page.route('**/rpc/abandon_session',r=>{calls++;return r.fulfill({json:{ok:false,error:'network'}});});
  await page.goto(`${BASE}/partie/${SESSION}`);const quit=page.getByRole('button',{name:'Quitter la partie',exact:true});await quit.click();
  await page.getByRole('dialog').getByRole('button',{name:'Annuler',exact:true}).click();assert.equal(calls,0);
  await quit.click();const confirm=page.getByRole('dialog').getByRole('button',{name:'Quitter la partie',exact:true});
  await ctx.setOffline(true);await page.waitForFunction(()=>!navigator.onLine);assert.equal(await confirm.isDisabled(),true);
  await ctx.setOffline(false);await confirm.click();await page.getByRole('dialog').getByRole('alert').waitFor();assert.equal(calls,1);assert.ok(page.url().includes('/partie/'));
  await page.route('**/rpc/abandon_session',r=>{calls++;return r.fulfill({json:{ok:true}});});
  await confirm.evaluate(el=>{el.click();el.click();});await page.waitForURL('**/accueil');assert.equal(calls,2);await ctx.close();console.log(`PASS quitter ${status} : annuler, hors ligne, échec visible, confirmation et double clic`);
 }
}finally{await browser.close();}
