// Non-régression chat/archives : comptes et RPC fictifs, réseau externe bloqué.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {chromium,expect} from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,SESSION}=await import('./render-check.mjs');
const BASE=process.env.BASE??'http://127.0.0.1:4268';
const browser=await chromium.launch({executablePath:'/usr/bin/chromium'});
const game=JSON.parse(readFileSync(new URL('./fixtures/rouge-g01-verite.json',import.meta.url),'utf8'));game.session.id=SESSION;
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};};
let failures=0,passed=0;
async function run(name,body){if(process.env.ONLY&&!new RegExp(process.env.ONLY).test(name))return;const ctx=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block',reducedMotion:'reduce'});const page=await ctx.newPage();page.setDefaultTimeout(8000);const errors=[];page.on('pageerror',e=>errors.push(e.message));try{
 await page.route('**/*',r=>new URL(r.request().url()).origin===new URL(BASE).origin?r.continue():r.abort());await setup(page,{...duo,notifications:[],state:game});await body(page);assert.deepEqual(errors,[]);passed++;console.log('PASS '+name);
}catch(e){failures++;console.error('FAIL '+name+': '+e.message);}finally{await ctx.close();}}
async function contexts(page){
 const b={...duo.duos[0],current:true,partner:{...duo.duos[0].partner,name:'B fixture'}};
 const c={...b,current:false,id:'77777777-7777-4777-8777-777777777777',partner:{...b.partner,id:'fixture-c',name:'C fixture'}};
 await page.route('**/rpc/get_my_duos',r=>r.fulfill({json:[b,c]}));
 await page.addInitScript(id=>sessionStorage.setItem(`noodeu.chat.draft.${id}`,'Message destiné à B fixture'),b.id);
 return {b,c,async select(which){b.current=which==='B';c.current=which==='C';await page.evaluate(()=>window.dispatchEvent(new Event('focus')));}};
}
async function sending(page){let calls=0;const started=deferred(),held=deferred();await page.route('**/rpc/send_duo_message',async r=>{calls++;started.resolve();await held.promise;await r.fulfill({json:{ok:false,error:'network'}}).catch(()=>{});});return {started,held,count:()=>calls};}
try{
 await run('Composer : erreur retardée reste dans le duo initial et double envoi bloqué',async page=>{
  const h=await contexts(page),send=await sending(page);
  await page.goto(`${BASE}/partie/${SESSION}`);await expect(page.locator('#game-chat-input')).toHaveValue('Message destiné à B fixture');
  await page.locator('.v7-game-composer').evaluate(f=>{f.requestSubmit();f.requestSubmit();});await send.started.promise;assert.equal(send.count(),1);
  await h.select('C');await expect(page.locator('#game-chat-input')).toHaveAttribute('placeholder','Écrire à C fixture…');await expect(page.locator('#game-chat-input')).toHaveValue('');
  send.held.resolve();await expect.poll(()=>page.evaluate(id=>sessionStorage.getItem(`noodeu.chat.draft.${id}`),h.b.id)).toBe('Message destiné à B fixture');
  await expect(page.locator('#game-chat-input')).toHaveValue('');assert.equal(await page.locator('.v7-game-composer__error').count(),0);
  await h.select('B');await expect(page.locator('#game-chat-input')).toHaveValue('Message destiné à B fixture');
 });
 await run('Composer : un nouveau brouillon Chat reste intact après ancien échec',async page=>{
  const h=await contexts(page),send=await sending(page);await page.goto(`${BASE}/partie/${SESSION}`);
  await page.getByRole('button',{name:'Envoyer le message à B fixture'}).click();await send.started.promise;
  await page.locator('#game-chat-input').focus();await page.locator('#chat-input').fill('Nouveau brouillon B');
  send.held.resolve();await expect.poll(()=>page.evaluate(id=>sessionStorage.getItem(`noodeu.chat.draft.${id}`),h.b.id)).toBe('Nouveau brouillon B');
  await expect(page.locator('#chat-input')).toHaveValue('Nouveau brouillon B');await page.getByRole('button',{name:'Retour au jeu'}).click();await expect(page.locator('#game-chat-input')).toHaveValue('Nouveau brouillon B');
 });
 await run('Chat : bascule de duo, erreur retardée et retour ne contaminent pas C',async page=>{
  const h=await contexts(page),send=await sending(page);await page.goto(`${BASE}/partie/${SESSION}`);await page.locator('#game-chat-input').focus();await expect(page.locator('#chat-input')).toHaveValue('Message destiné à B fixture');
  await page.locator('form.composer').evaluate(f=>{f.requestSubmit();f.requestSubmit();});await send.started.promise;assert.equal(send.count(),1);
  await h.select('C');await expect(page.locator('.chat-head h2')).toHaveText('C fixture');await expect(page.locator('#chat-input')).toHaveValue('');
  await page.locator('#chat-input').fill('Privé C fixture');send.held.resolve();
  await expect.poll(()=>page.evaluate(id=>sessionStorage.getItem(`noodeu.chat.draft.${id}`),h.b.id)).toBe('Message destiné à B fixture');
  await expect(page.locator('#chat-input')).toHaveValue('Privé C fixture');
  await h.select('B');await expect(page.locator('#chat-input')).toHaveValue('Message destiné à B fixture');
 });
 for(const newer of [false,true])await run(`Chat sans stockage : ${newer?'saisie récente préservée':'échec restaure en mémoire'}`,async page=>{
  await contexts(page);const send=await sending(page);
  await page.addInitScript(()=>{const get=Storage.prototype.getItem,set=Storage.prototype.setItem;Storage.prototype.getItem=function(k){if(this===sessionStorage)throw new Error('storage denied fixture');return get.call(this,k);};Storage.prototype.setItem=function(k,v){if(this===sessionStorage)throw new Error('storage denied fixture');return set.call(this,k,v);};});
  await page.goto(`${BASE}/partie/${SESSION}`);await page.locator('#game-chat-input').focus();await page.locator('#chat-input').fill('Message en mémoire');
  await page.locator('form.composer').evaluate(f=>f.requestSubmit());await send.started.promise;
  if(newer)await page.locator('#chat-input').fill('Saisie plus récente');send.held.resolve();
  await expect(page.locator('.sheet--game-chat [role="alert"]').first()).toBeVisible();
  await expect(page.locator('#chat-input')).toHaveValue(newer?'Saisie plus récente':'Message en mémoire');
 });
 await run('Déconnexion : un ancien échec ne recrée aucun brouillon privé',async page=>{
  await contexts(page);const send=await sending(page);await page.route('**/auth/v1/logout**',r=>r.fulfill({status:204,body:''}));
  await page.goto(`${BASE}/partie/${SESSION}`);await page.getByRole('button',{name:'Envoyer le message à B fixture'}).click();await send.started.promise;
  await page.evaluate(()=>{history.pushState({},'', '/reglages');window.dispatchEvent(new PopStateEvent('popstate'));});
  await page.getByRole('button',{name:'Me déconnecter',exact:true}).click();await page.waitForURL(u=>u.pathname==='/');
  send.held.resolve();await page.waitForTimeout(250);
  assert.equal(await page.evaluate(()=>Object.keys(sessionStorage).filter(k=>k.startsWith('noodeu.chat.draft.')).length),0);
 });
 await run('Archives : panne503 affichée puis reprise explicite sans faux vide',async page=>{
  const archived=duo.duos[1];let fail=true,calls=0;
  await page.route('**/rest/v1/duo_messages?*',r=>{const id=new URL(r.request().url()).searchParams.get('couple_id');if(id!==`eq.${archived.id}`)return r.fallback();calls++;return fail?r.fulfill({status:503,headers:{'retry-after':'0'},json:{message:'Fixture unavailable'}}):r.fulfill({json:[{id:'archive-fixed',client_id:'archive-fixed',user_id:'partner',body:'Archive récupérée',created_at:'2026-10-26T10:00:00Z'}]});});
  await page.goto(`${BASE}/espace?duo=${archived.id}`);await page.locator('details.disclosure > summary').click();const details=page.locator('details.disclosure');
  await expect(details.getByRole('alert')).toBeVisible({timeout:15000});assert.equal(await details.getByText('Aucun message',{exact:false}).count(),0);assert.ok(calls>=1);const prior=calls;
  fail=false;await details.getByRole('button',{name:'Réessayer',exact:true}).click();await expect(page.getByText('Archive récupérée',{exact:true})).toBeVisible();assert.equal(calls,prior+1);
 });
 for(const delayed of [false,true])await run(`Archives : ${delayed?'retour tardif ignoré':'messages chargés isolés'} après changement de duo`,async page=>{
  const b={...duo.duos[1],partner:{...duo.duos[1].partner,name:'Archive B'}};
  const c={...b,id:'77777777-7777-4777-8777-777777777777',partner:{...b.partner,id:'fixture-c',name:'Archive C'}};
  await page.route('**/rpc/get_my_duos',r=>r.fulfill({json:[duo.duos[0],b,c]}));const held=deferred(),started=deferred();
  await page.route('**/rest/v1/duo_messages?*',async r=>{const id=new URL(r.request().url()).searchParams.get('couple_id');if(id===`eq.${b.id}`){started.resolve();if(delayed)await held.promise;}return r.fulfill({json:[{id:'fixture-'+id,client_id:'client-'+id,user_id:'partner',body:id===`eq.${b.id}`?'Texte archive B':'Texte archive C',created_at:'2026-10-26T10:00:00Z'}]});});
  await page.goto(`${BASE}/espace?duo=${b.id}`);await page.locator('details.disclosure > summary').click();await started.promise;if(!delayed)await expect(page.getByText('Texte archive B',{exact:true})).toBeVisible();
  await page.getByRole('button',{name:'Choisir le duo et gérer l’espace'}).click();await page.getByRole('radio',{name:/Archive C/}).locator('..').click();await expect(page.getByRole('heading',{name:'Espace avec Archive C'})).toBeVisible();
  assert.equal(await page.getByText('Texte archive B',{exact:true}).count(),0);await page.locator('details.disclosure > summary').click();await expect(page.getByText('Texte archive C',{exact:true})).toBeVisible();held.resolve();await page.waitForTimeout(200);assert.equal(await page.getByText('Texte archive B',{exact:true}).count(),0);
 });
}finally{await browser.close();}
console.log(`CHAT PRIVACY : ${passed} réussi(s), ${failures} échoué(s)`);if(failures)process.exitCode=1;
