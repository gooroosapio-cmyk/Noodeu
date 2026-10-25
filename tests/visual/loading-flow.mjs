import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
import {mkdirSync} from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,sessionState,SESSION}=await import('./render-check.mjs');
const browser=await chromium.launch({executablePath:'/usr/bin/chromium'});const BASE=process.env.BASE??'http://localhost:4181';
mkdirSync('test-results/loading-final',{recursive:true});
try {for(const motion of ['no-preference','reduce']){
 const ctx=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block',reducedMotion:motion});const page=await ctx.newPage();await setup(page,{...duo,state:sessionState('lobby'),notifications:[]});let release,started;const requestStarted=new Promise(r=>started=r);
 const gate=new Promise(r=>release=r);
 await page.route('**/rpc/get_session_state',async r=>{started();await gate;return r.fulfill({json:sessionState('lobby')});});
 await page.goto(`${BASE}/partie/${SESSION}`,{waitUntil:'domcontentloaded'});await requestStarted;const logo=page.locator('.page-loading .logo');await logo.waitFor();const rect=await logo.evaluate(el=>{const r=el.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height};});assert.ok(Math.abs(rect.x+rect.width/2-195)<2);assert.ok(Math.abs(rect.y+rect.height/2-422)<50);
 const animation=await page.locator('.page-loading__logo').evaluate(x=>getComputedStyle(x).animationName);assert.equal(animation,motion==='reduce'?'none':'logo-breathe');
 await page.screenshot({path:`test-results/loading-final/loading-${motion}.png`});release();await page.locator('.lobby').waitFor();assert.equal(await page.locator('.page-loading').count(),0);await ctx.close();console.log(`PASS chargement ${motion}: logo centré, mouvement adapté, fin sans attente artificielle`);
}}finally{await browser.close();}
