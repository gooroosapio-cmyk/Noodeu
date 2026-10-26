// Parcours UI sur fixtures : aucun backend ni compte réel. La sécurité est testée séparément en SQL.
import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
import {mkdirSync,readFileSync} from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,sessionState,SESSION,activeDuo}=await import('./render-check.mjs');
const BASE=process.env.BASE ?? 'http://localhost:4173';
const browser=await chromium.launch({executablePath:process.env.PW_CHROMIUM??'/usr/bin/chromium'});
mkdirSync('test-results/flows',{recursive:true});
const invitation={id:'invite',type:'game_proposed',couple_id:activeDuo.id,data:{session_id:SESSION,title:'Portrait en cinq mots',name:'Alex'},created_at:new Date().toISOString(),read_at:null};
async function pageFor(scenario){const ctx=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});const page=await ctx.newPage();await setup(page,scenario);return {ctx,page};}
try {
 {const {ctx,page}=await pageFor({...duo,notifications:[invitation,{...invitation,id:'duplicate'}],state:sessionState('lobby')});
  await page.goto(`${BASE}/accueil`);await page.getByRole('button',{name:'Accepter',exact:true}).waitFor();
  assert.equal(await page.getByRole('dialog').count(),1);await page.waitForTimeout(400);await page.screenshot({path:'test-results/flows/invitation.png'});
  await page.getByRole('button',{name:'Accepter',exact:true}).click();await page.waitForURL(`**/partie/${SESSION}`);assert.equal(await page.getByRole('button',{name:'Accepter',exact:true}).count(),0);await ctx.close();
  console.log('PASS invitation et duplication : acceptation explicite, navigation salon');}
 {const {ctx,page}=await pageFor({...duo,notifications:[invitation],state:sessionState('ended')});await page.goto(`${BASE}/accueil`);
  await page.getByRole('button',{name:'Accepter',exact:true}).click();await page.getByText('Ce salon n’attend plus de joueurs. Tu peux fermer cette invitation.').waitFor();assert.ok(page.url().endsWith('/accueil'));
  await page.keyboard.press('Escape');assert.equal(await page.getByRole('dialog').count(),0);await ctx.close();console.log('PASS invitation périmée et fermeture Échap');}
 {const {ctx,page}=await pageFor({...duo,notifications:[invitation],state:sessionState('playing')});await page.goto(`${BASE}/partie/${SESSION}`);await page.locator('main').waitFor();
  assert.equal(await page.getByRole('button',{name:'Accepter',exact:true}).count(),0);await ctx.close();console.log('PASS aucune invitation modale ni navigation forcée en partie');}
 {const {ctx,page}=await pageFor({...duo,notifications:[invitation],state:sessionState('lobby')});await page.goto(`${BASE}/accueil`);await page.getByRole('button',{name:'Accepter',exact:true}).waitFor();
  await ctx.setOffline(true);await page.waitForFunction(()=>!navigator.onLine);assert.equal(await page.getByRole('button',{name:'Accepter',exact:true}).isDisabled(),true);
  await ctx.setOffline(false);await page.waitForFunction(()=>navigator.onLine);await page.getByRole('button',{name:'Refuser',exact:true}).click();assert.ok(page.url().endsWith('/accueil'));await ctx.close();console.log('PASS hors ligne/reconnexion et refus sans navigation');}
 {const {ctx,page}=await pageFor({...duo,notifications:[]});let saved=0;
  await page.route('**/rpc/save_duo_note',async route=>{saved++;await route.fulfill({json:{ok:true}});});
  await page.goto(`${BASE}/espace`);await page.getByRole('button',{name:'Ajouter',exact:true}).click();
  await page.getByLabel('Votre note',{exact:true}).fill('Prévoir une promenade');
  await page.getByRole('button',{name:'Enregistrer la note'}).evaluate(button=>{button.click();button.click();});
  await page.waitForFunction(()=>!document.querySelector('[role="dialog"]'));assert.equal(saved,1);await ctx.close();console.log('PASS note : double clic, une écriture et fermeture');}
 {const {ctx,page}=await pageFor({auth:false});let oauth=0;await page.route('**/auth/v1/authorize**',route=>{oauth++;return route.abort();});
  await page.goto(`${BASE}/connexion`);assert.equal(await page.getByRole('button',{name:/Google/}).isDisabled(),true);assert.equal(oauth,0);
  await page.addStyleTag({content:'html{font-size:200%}'});await page.screenshot({path:'test-results/flows/connexion-texte200.png',fullPage:true});await ctx.close();console.log('PASS Google inactif, texte 200 %');}
 // Build livré : l’audio reste fermé même si le serveur annonce enabled=true.
 // Les anciens tests de permission/codec exigent un harnais audio distinct ;
 // ne pas prétendre les exécuter en forçant seulement une réponse RPC.
 {const state=JSON.parse(readFileSync(new URL('./fixtures/c14-pack-vf-jeu.json',import.meta.url),'utf8'));
  state.rounds[0].card.item.response='open';state.rounds[0].card.item.options=null;state.rounds[0].card.status={};
  const {ctx,page}=await pageFor({...duo,notifications:[],state});let capabilityCalls=0,audioWrites=0;
  await page.route('**/rpc/get_audio_capability',r=>{capabilityCalls++;return r.fulfill({json:{ok:true,enabled:true}});});
  await page.route('**/rpc/reserve_answer_audio',r=>{audioWrites++;return r.abort();});
  await page.route('**/storage/v1/object/answer-audio/**',r=>{audioWrites++;return r.abort();});
  await page.addInitScript(()=>{window.microphoneCalls=0;Object.defineProperty(navigator.mediaDevices,'getUserMedia',{value:async()=>{window.microphoneCalls++;throw new DOMException('Denied','NotAllowedError');}});});
  await page.goto(`${BASE}/partie/${SESSION}`);
  await page.getByText('L’audio n’est pas encore disponible. Tu peux écrire ta réponse.').waitFor();
  assert.equal(await page.getByRole('button',{name:'Enregistrer un audio',exact:true}).count(),0);
  await page.locator('#q-text').fill('Le texte reste possible');
  const send=page.locator('form').getByRole('button',{name:'Envoyer et partager',exact:true});
  assert.equal(await send.isEnabled(),true);
  const submitted=page.waitForRequest(request=>request.url().includes('/rpc/play_move'));
  await send.click();const payload=(await submitted).postDataJSON().p_payload;
  assert.equal(payload.text,'Le texte reste possible');assert.equal(payload.audio_id,undefined);
  assert.equal(capabilityCalls,0);assert.equal(audioWrites,0);assert.equal(await page.evaluate(()=>window.microphoneCalls),0);
  await ctx.close();console.log('PASS audio désactivé : aucun RPC capability, micro ou upload ; réponse texte envoyée');}
 {const state=JSON.parse(readFileSync(new URL('./fixtures/c14-mini-naval-tirs.json',import.meta.url),'utf8'));
  const {ctx,page}=await pageFor({...duo,notifications:[],state});await page.goto(`${BASE}/partie/${SESSION}`);
  await page.locator('.naval').first().waitFor();
  const targetMode=page.getByRole('button',{name:'Cibler une case',exact:true});
  if(await targetMode.count())await targetMode.first().click();
  await page.locator('.board-zoom .naval__cell').first().waitFor();
  const cells=await page.locator('.board-zoom .naval__cell').evaluateAll(cells=>cells.map(c=>({w:c.getBoundingClientRect().width,h:c.getBoundingClientRect().height})));
  assert.ok(cells.length>0 && cells.every(c=>c.w>=44 && c.h>=44));await ctx.close();console.log('PASS naval : sélection agrandie, cellules 44 px minimum');}
 {const state=JSON.parse(readFileSync(new URL('./fixtures/c14-mot-bac-saisie.json',import.meta.url),'utf8'));
  const rebase=o=>Array.isArray(o)?o.map(rebase):o&&typeof o==='object'?('__rel'in o?new Date(Date.now()+o.__rel*1000).toISOString():Object.fromEntries(Object.entries(o).map(([k,v])=>[k,rebase(v)]))):o;
  const {ctx,page}=await pageFor({...duo,notifications:[],state:rebase(state)});await page.goto(`${BASE}/partie/${SESSION}`);
  const inputs=page.locator('.pb-cell input');await inputs.first().fill('Arbre');await inputs.first().press('Enter');assert.equal(await inputs.nth(1).evaluate(el=>el===document.activeElement),true);
  await ctx.setOffline(true);await page.waitForFunction(()=>!navigator.onLine);assert.equal(await inputs.first().isDisabled(),true);
  await ctx.setOffline(false);await page.waitForFunction(()=>navigator.onLine);assert.equal(await inputs.first().inputValue(),'Arbre');await ctx.close();console.log('PASS Petit bac : clavier suivant, hors ligne, brouillon conservé au retour réseau');}
 {const other='00000000-0000-4000-a000-000000000002';const {ctx,page}=await pageFor({...duo,notifications:[]});let arrived;
  const requested=new Promise(resolve=>{arrived=resolve;});
  await page.route('**/rpc/get_session_state',async route=>{const id=route.request().postDataJSON().p_session;const state=sessionState('lobby');state.session.id=id;state.game.title=id===other?'Session B':'Session A';state.session.state_version=id===other?1:99;
   if(id===SESSION){arrived();await new Promise(resolve=>setTimeout(resolve,1200));}await route.fulfill({json:state});});
  await page.goto(`${BASE}/partie/${SESSION}`,{waitUntil:'domcontentloaded'});await requested;
  await page.evaluate(id=>{history.pushState({},'',`/partie/${id}`);dispatchEvent(new PopStateEvent('popstate'));},other);
  await page.getByText('Session B',{exact:true}).first().waitFor();await page.waitForTimeout(1400);assert.equal(await page.getByText('Session A',{exact:true}).count(),0);await ctx.close();console.log('PASS changement de salon : réponse tardive du précédent ignorée');}
 {const state=JSON.parse(readFileSync(new URL('./fixtures/c14-conv-dvm2-ecriture.json',import.meta.url),'utf8'));
  const {ctx,page}=await pageFor({...duo,notifications:[],state});await page.goto(`${BASE}/partie/${SESSION}`);
  await page.locator('#tt2-0').fill('Je chante');await page.locator('#tt2-1').fill('Je danse');await page.locator('#tt2-2').fill('Je vole');
  await page.locator('.theatre-note').nth(2).getByRole('radio').check();await page.reload();
  await page.locator('#tt2-0').waitFor();assert.equal(await page.locator('#tt2-0').inputValue(),'Je chante');assert.equal(await page.locator('#tt2-2').inputValue(),'Je vole');
  assert.equal(await page.locator('.theatre-note').nth(2).getByRole('radio').isChecked(),true);await ctx.close();console.log('PASS G08 : brouillon et mensonge conservés après rechargement, clé par joueur/séance/manche');}
 {const {ctx,page}=await pageFor({...duo,notifications:[]});let uploads=0;
  await page.route('**/storage/v1/object/duo-covers/**',r=>{uploads++;return r.abort();});await page.goto(`${BASE}/espace`);
  await page.getByRole('button',{name:'Changer la photo de couverture'}).waitFor();
  await page.locator('input[type=file]').setInputFiles({name:'faux.png',mimeType:'image/png',buffer:Buffer.from('not an image')});
  await page.getByText('Cette image est illisible. Choisis une autre photo.').waitFor();assert.equal(uploads,0);await ctx.close();console.log('PASS couverture : faux PNG rejeté avant upload');}
 {const {ctx,page}=await pageFor({...duo,notifications:[]});let calls=0,arrived;const requested=new Promise(r=>{arrived=r;});
  await page.route('**/rpc/get_duo_space',async route=>{const first=++calls===1;if(first){arrived();await new Promise(r=>setTimeout(r,1000));}
   await route.fulfill({json:{ok:true,version:first?0:1,cover_path:null,notes:[{id:'note-order',body:first?'Ancienne note retardée':'Note récente conservée',due_on:null,done:false,version:first?0:1}]}});});
  await page.goto(`${BASE}/espace`,{waitUntil:'domcontentloaded'});await requested;await page.evaluate(()=>window.dispatchEvent(new Event('focus')));
  await page.getByText('Note récente conservée').waitFor();await page.waitForTimeout(1200);assert.equal(await page.getByText('Ancienne note retardée').count(),0);
  await ctx.close();console.log('PASS espace : actualisation tardive ne remplace pas les notes récentes');}
} finally {await browser.close();}
