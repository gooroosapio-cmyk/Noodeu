// Salon (kit rouge) : validation liée à une révision, revalidation après changement, lancement réservé à l'hôte.
// Réponses serveur simulées à partir d'états réels (fixtures rouge-*) ; les règles serveur sont testées dans
// supabase/tests/c41_salon_revision_g01_g08.sql. Aucun appel externe réel.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {chromium,expect} from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,SESSION}=await import('./render-check.mjs');
const BASE=process.env.BASE??'http://127.0.0.1:4173';
const browser=await chromium.launch({executablePath:process.env.PW_CHROMIUM??'/usr/bin/chromium'});
const fixture=name=>JSON.parse(readFileSync(new URL(`./fixtures/${name}`,import.meta.url),'utf8'));
let failures=0;
async function scenario(name,fn){
 const ctx=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});
 const page=await ctx.newPage();page.setDefaultTimeout(7000);
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 try{await page.route('**/*',r=>new URL(r.request().url()).origin===new URL(BASE).origin?r.continue():r.abort());await fn(page);assert.deepEqual(errors,[]);console.log(`PASS ${name}`);}
 catch(e){failures++;console.error(`FAIL ${name} : ${e.message}`);}
 finally{await ctx.close();}
}
try{
 // 1. Valider envoie la révision affichée ; un changement de réglage remet à « Valider ».
 await scenario('validation liée à la révision, revalidation après changement',async page=>{
  const state=fixture('rouge-salon-preparer.json');state.session.id=SESSION;
  await setup(page,{...duo,notifications:[],state});
  const calls=[];
  await page.route('**/rpc/get_session_state',r=>r.fulfill({json:state}));
  await page.route('**/rpc/set_ready_rev',r=>{const b=r.request().postDataJSON();calls.push(b);
   if(b.p_rev!==state.session.settings_rev)return r.fulfill({json:{ok:false,error:'settings_changed',settings_rev:state.session.settings_rev}});
   const me=state.players.find(p=>p.is_me);me.ready=b.p_ready;me.ready_rev=b.p_ready?b.p_rev:null;state.session.state_version++;return r.fulfill({json:{ok:true}});});
  await page.route('**/rpc/set_ready',r=>{calls.push({legacy:true});return r.fulfill({json:{ok:true}});});
  await page.goto(`${BASE}/partie/${SESSION}`);
  const validate=page.getByRole('button',{name:'Valider les réglages'});
  await validate.click();
  await expect.poll(()=>calls.length).toBe(1);
  assert.deepEqual(calls[0],{p_session:SESSION,p_ready:true,p_rev:state.session.settings_rev});
  await page.evaluate(()=>window.dispatchEvent(new Event('focus')));
  await expect(page.getByRole('button',{name:'Modifier les réglages'})).toBeVisible();
  // L'autre change un réglage : nouvelle révision, validations retirées par le serveur.
  state.session.settings_rev++;state.session.settings.cartes=7;state.players.forEach(p=>{p.ready=false;p.ready_rev=null;});state.session.state_version++;
  await page.evaluate(()=>window.dispatchEvent(new Event('focus')));
  await expect(validate).toBeVisible();
  await expect(page.getByRole('radiogroup',{name:'Nombre de tours'}).getByRole('radio',{name:'7'})).toBeChecked();
  assert.ok(!calls.some(c=>c.legacy),'aucun appel à l\'ancien set_ready');
 });
 // 2. Révision périmée : message clair, aucune validation implicite.
 await scenario('révision périmée refusée avec message',async page=>{
  const state=fixture('rouge-salon-preparer.json');state.session.id=SESSION;
  await setup(page,{...duo,notifications:[],state});
  await page.route('**/rpc/get_session_state',r=>r.fulfill({json:state}));
  await page.route('**/rpc/set_ready_rev',r=>r.fulfill({json:{ok:false,error:'settings_changed',settings_rev:state.session.settings_rev+1}}));
  await page.goto(`${BASE}/partie/${SESSION}`);
  await page.getByRole('button',{name:'Valider les réglages'}).click();
  await expect(page.getByText('Les réglages viennent de changer',{exact:false}).first()).toBeVisible();
 });
 // 3. Les deux ont validé : l'hôte voit « Lancer » (désactivé tant que l'autre n'est pas présent), l'invité non.
 await scenario('lancement réservé à l\'hôte, jamais silencieux',async page=>{
  const host=fixture('rouge-salon-pret-hote.json');host.session.id=SESSION;
  await setup(page,{...duo,notifications:[],state:host});
  let launches=0;
  await page.route('**/rpc/get_session_state',r=>r.fulfill({json:host}));
  await page.route('**/rpc/launch_session',r=>{launches++;return r.fulfill({json:{ok:true,status:'playing'}});});
  await page.goto(`${BASE}/partie/${SESSION}`);
  await expect(page.getByRole('heading',{name:'Tout est prêt'})).toBeVisible();
  const launch=page.getByRole('button',{name:'Lancer la partie'});
  await expect(launch).toBeVisible();await expect(launch).toBeDisabled();
  await expect(page.getByText('doit être dans le salon pour lancer',{exact:false})).toBeVisible();
  await page.waitForTimeout(1500);assert.equal(launches,0,'aucun démarrage automatique');
 });
 await scenario('partenaire de test : toujours présent, Lancer actif, un seul appel',async page=>{
  const host=fixture('rouge-salon-pret-hote.json');host.session.id=SESSION;host.players.find(p=>!p.is_me).test_partner=true;
  await setup(page,{...duo,notifications:[],state:host});
  let launches=0;
  await page.route('**/rpc/get_session_state',r=>r.fulfill({json:host}));
  await page.route('**/rpc/launch_session',async r=>{launches++;await new Promise(f=>setTimeout(f,300));return r.fulfill({json:{ok:true,status:'playing'}});});
  await page.goto(`${BASE}/partie/${SESSION}`);
  const launch=page.getByRole('button',{name:'Lancer la partie'});
  await expect(launch).toBeEnabled();
  await launch.dblclick();
  await page.waitForTimeout(800);assert.equal(launches,1,'double clic : un seul appel');
 });
 await scenario('l\'invité attend le lancement de l\'hôte',async page=>{
  const guest=fixture('rouge-salon-pret-invite.json');guest.session.id=SESSION;
  await setup(page,{...duo,notifications:[],state:guest});
  await page.route('**/rpc/get_session_state',r=>r.fulfill({json:guest}));
  await page.goto(`${BASE}/partie/${SESSION}`);
  await expect(page.getByText('lance la partie',{exact:false})).toBeVisible();
  assert.equal(await page.getByRole('button',{name:'Lancer la partie'}).count(),0);
 });
}finally{await browser.close();}
if(failures)process.exitCode=1;
