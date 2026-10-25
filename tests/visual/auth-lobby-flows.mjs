import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
import {readFileSync,mkdirSync} from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,SESSION}=await import('./render-check.mjs');
const BASE=process.env.BASE??'http://localhost:4179';
const browser=await chromium.launch({executablePath:'/usr/bin/chromium'});
const out='test-results/auth-lobby-flows';mkdirSync(out,{recursive:true});
async function context(scenario,reducedMotion='no-preference'){const ctx=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block',reducedMotion});const page=await ctx.newPage();page.setDefaultTimeout(10000);await setup(page,scenario);return {ctx,page};}
const lobby=JSON.parse(readFileSync(new URL('./fixtures/c14-lobby-n2-002.json',import.meta.url),'utf8'));
try {
 for(const mode of ['connexion','inscription']) {
  const {ctx,page}=await context({auth:false});let calls=0;
  await page.route('**/auth/v1/token**',async r=>{calls++;await new Promise(resolve=>setTimeout(resolve,400));return r.fulfill({status:400,json:{error:'invalid_grant',error_description:'Invalid login credentials'}});});
  await page.route('**/auth/v1/signup**',async r=>{calls++;await new Promise(resolve=>setTimeout(resolve,400));return r.fulfill({status:400,json:{msg:'User already registered'}});});
  await page.goto(`${BASE}/${mode}`);await page.getByLabel('Adresse e-mail',{exact:true}).fill('maya@exemple.invalid');
  await page.locator('#password').fill('motdepasse-fictif');
  await page.getByRole('button',{name:'Afficher le mot de passe'}).click();assert.equal(await page.locator('#password').getAttribute('type'),'text');
  await page.getByRole('button',{name:'Masquer le mot de passe'}).click();assert.equal(await page.locator('#password').getAttribute('type'),'password');
  assert.equal(await page.getByRole('button',{name:'Continuer avec Google'}).isDisabled(),true);
  if(mode==='inscription'){await page.locator('#name').fill('Maya');await page.getByRole('checkbox').check();await page.locator('#password2').fill('different');assert.equal(await page.locator('button[type=submit]').isDisabled(),true);await page.locator('form').evaluate(f=>f.requestSubmit());assert.equal(calls,0);await page.locator('#password2').fill('motdepasse-fictif');}
  await page.locator('form').evaluate(form=>{form.requestSubmit();form.requestSubmit();});await page.getByRole('alert').waitFor();assert.equal(calls,1);assert.ok(page.url().endsWith(mode));
  await page.setViewportSize({width:390,height:450});await page.locator('#password').focus();await page.locator('#password').scrollIntoViewIfNeeded();
  const r=await page.locator('#password').boundingBox();assert.ok(r.y>=0&&r.y+r.height<=450);
  await page.screenshot({path:`${out}/${mode}-erreur-clavier.png`});await ctx.close();console.log(`PASS ${mode}: mot de passe, Google inactif, double envoi bloqué, erreur visible, petite hauteur`);
 }
 {const {ctx,page}=await context({...duo,notifications:[],state:lobby});let ready=0,head=0;
  await page.route('**/rpc/set_ready',r=>{ready++;return r.fulfill({json:{ok:true}});});
  await page.route('**/assets/original/launch/noodeu-launch-3s.mp4',async r=>{head++;await new Promise(resolve=>setTimeout(resolve,800));return r.fulfill({status:404,body:''});});
  await page.goto(`${BASE}/partie/${SESSION}`);const guide=page.locator('.lobby-guide__button');await guide.first().waitFor();const sizes=await guide.evaluateAll(xs=>xs.map(x=>{const r=x.getBoundingClientRect();return [r.width,r.height];}));assert.deepEqual(sizes[0],sizes[1]);
  await page.getByRole('button',{name:'Description',exact:true}).click();await page.getByRole('dialog').waitFor();assert.equal(await page.getByRole('dialog').locator('ol').count(),0);await page.keyboard.press('Escape');
  await page.getByRole('button',{name:'Règles',exact:true}).click();assert.ok(await page.getByRole('dialog').locator('ol li').count()>0);await page.keyboard.press('Escape');
  const settings=page.locator('.lobby-settings select');assert.equal(await settings.count(),1);assert.equal(await settings.locator('option').count(),3);
  const button=page.locator('.lobby .action-bar button');await button.evaluate(x=>{x.click();x.click();});await page.waitForTimeout(200);assert.equal(ready,0);assert.equal(await button.isDisabled(),true);
  await page.waitForFunction(()=>!document.querySelector('.lobby .action-bar button')?.disabled);assert.equal(ready,1);assert.equal(head,1);
  await button.click();await page.waitForTimeout(150);assert.equal(head,1);assert.equal(ready,2);
  await ctx.setOffline(true);await page.getByText('En attente du réseau',{exact:true}).waitFor();assert.equal(await button.isDisabled(),true);
  await ctx.setOffline(false);await page.getByText('En attente du réseau',{exact:true}).waitFor({state:'detached'});
  await page.screenshot({path:`${out}/salon.png`});await ctx.close();console.log('PASS salon : panneaux distincts, géométrie, réglages réels, attente avant prêt, 404 sans blocage, double clic, non-rejeu, hors ligne/reconnexion');
 }
 {const {ctx,page}=await context({...duo,notifications:[],state:lobby},'reduce');let requests=0,ready=0;
  await page.route('**/assets/original/launch/**',r=>{requests++;return r.abort();});await page.route('**/rpc/set_ready',r=>{ready++;return r.fulfill({json:{ok:true}});});
  await page.goto(`${BASE}/partie/${SESSION}`);await page.locator('.lobby .action-bar button').click();await page.waitForTimeout(100);assert.equal(requests,0);assert.equal(ready,1);await ctx.close();console.log('PASS reduced-motion : vidéo ignorée sans requête, prêt confirmé');
 }
}finally{await browser.close();}
