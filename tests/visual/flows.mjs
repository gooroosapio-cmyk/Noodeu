// Parcours UI sur fixtures : aucun backend ni compte réel. La sécurité est testée séparément en SQL.
import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
import {mkdirSync,readFileSync} from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,sessionState,SESSION,activeDuo}=await import('./render-check.mjs');
const browser=await chromium.launch({executablePath:process.env.PW_CHROMIUM??'/usr/bin/chromium'});
mkdirSync('test-results/flows',{recursive:true});
const invitation={id:'invite',type:'game_proposed',couple_id:activeDuo.id,data:{session_id:SESSION,title:'Portrait en cinq mots',name:'Alex'},created_at:new Date().toISOString(),read_at:null};
async function pageFor(scenario){const ctx=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});const page=await ctx.newPage();await setup(page,scenario);return {ctx,page};}
try {
 {const {ctx,page}=await pageFor({...duo,notifications:[invitation,{...invitation,id:'duplicate'}],state:sessionState('lobby')});
  await page.goto('http://localhost:4173/accueil');await page.getByRole('button',{name:'Accepter',exact:true}).waitFor();
  assert.equal(await page.getByRole('dialog').count(),1);await page.waitForTimeout(400);await page.screenshot({path:'test-results/flows/invitation.png'});
  await page.getByRole('button',{name:'Accepter',exact:true}).click();await page.waitForURL(`**/partie/${SESSION}`);assert.equal(await page.getByRole('button',{name:'Accepter',exact:true}).count(),0);await ctx.close();
  console.log('PASS invitation et duplication : acceptation explicite, navigation salon');}
 {const {ctx,page}=await pageFor({...duo,notifications:[invitation],state:sessionState('ended')});await page.goto('http://localhost:4173/accueil');
  await page.getByRole('button',{name:'Accepter',exact:true}).click();await page.getByText('Ce salon n’attend plus de joueurs. Tu peux fermer cette invitation.').waitFor();assert.ok(page.url().endsWith('/accueil'));
  await page.keyboard.press('Escape');assert.equal(await page.getByRole('dialog').count(),0);await ctx.close();console.log('PASS invitation périmée et fermeture Échap');}
 {const {ctx,page}=await pageFor({...duo,notifications:[invitation],state:sessionState('playing')});await page.goto(`http://localhost:4173/partie/${SESSION}`);await page.locator('main').waitFor();
  assert.equal(await page.getByRole('button',{name:'Accepter',exact:true}).count(),0);await ctx.close();console.log('PASS aucune invitation modale ni navigation forcée en partie');}
 {const {ctx,page}=await pageFor({...duo,notifications:[invitation],state:sessionState('lobby')});await page.goto('http://localhost:4173/accueil');await page.getByRole('button',{name:'Accepter',exact:true}).waitFor();
  await ctx.setOffline(true);await page.waitForFunction(()=>!navigator.onLine);assert.equal(await page.getByRole('button',{name:'Accepter',exact:true}).isDisabled(),true);
  await ctx.setOffline(false);await page.waitForFunction(()=>navigator.onLine);await page.getByRole('button',{name:'Refuser',exact:true}).click();assert.ok(page.url().endsWith('/accueil'));await ctx.close();console.log('PASS hors ligne/reconnexion et refus sans navigation');}
 {const {ctx,page}=await pageFor({...duo,notifications:[]});let saved=0;
  await page.route('**/rpc/save_duo_note',async route=>{saved++;await route.fulfill({json:{ok:true}});});
  await page.goto('http://localhost:4173/espace');await page.getByRole('button',{name:'Ajouter',exact:true}).click();
  await page.getByLabel('Votre note',{exact:true}).fill('Prévoir une promenade');
  await page.getByRole('button',{name:'Enregistrer la note'}).evaluate(button=>{button.click();button.click();});
  await page.waitForFunction(()=>!document.querySelector('[role="dialog"]'));assert.equal(saved,1);await ctx.close();console.log('PASS note : double clic, une écriture et fermeture');}
 {const {ctx,page}=await pageFor({auth:false});let oauth=0;await page.route('**/auth/v1/authorize**',route=>{oauth++;return route.abort();});
  await page.goto('http://localhost:4173/connexion');assert.equal(await page.getByRole('button',{name:/Google/}).isDisabled(),true);assert.equal(oauth,0);
  await page.addStyleTag({content:'html{font-size:200%}'});await page.screenshot({path:'test-results/flows/connexion-texte200.png',fullPage:true});await ctx.close();console.log('PASS Google inactif, texte 200 %');}
 {const state=JSON.parse(readFileSync(new URL('./fixtures/c14-pack-vf-jeu.json',import.meta.url),'utf8'));
  state.rounds[0].card.item.response='open';state.rounds[0].card.item.options=null;state.rounds[0].card.status={};
  const {ctx,page}=await pageFor({...duo,notifications:[],state});
  await page.route('**/rpc/get_audio_capability',r=>r.fulfill({json:{ok:true,enabled:true}}));
  await page.addInitScript(()=>{window.microphoneCalls=0;Object.defineProperty(navigator.mediaDevices,'getUserMedia',{value:async()=>{window.microphoneCalls++;throw new DOMException('Denied','NotAllowedError');}});});
  await page.goto(`http://localhost:4173/partie/${SESSION}`);await page.getByRole('button',{name:'Enregistrer un audio',exact:true}).waitFor();
  assert.equal(await page.evaluate(()=>window.microphoneCalls),0);
  await page.getByRole('button',{name:'Enregistrer un audio',exact:true}).click();
  await page.getByText('Micro indisponible ou permission refusée. Tu peux répondre par texte.').waitFor();
  assert.equal(await page.evaluate(()=>window.microphoneCalls),1);
  await page.locator('#q-text').fill('Le texte reste possible');await page.screenshot({path:'test-results/flows/audio-refus-micro.png',fullPage:true});
  await ctx.close();console.log('PASS audio : permission au clic seulement, refus micro et repli texte');}
 {const state=JSON.parse(readFileSync(new URL('./fixtures/c14-mini-naval-tirs.json',import.meta.url),'utf8'));
  const {ctx,page}=await pageFor({...duo,notifications:[],state});await page.goto(`http://localhost:4173/partie/${SESSION}`);
  await page.getByRole('button',{name:'Agrandir le plateau',exact:true}).first().click();
  const cells=await page.locator('.board-zoom .naval__cell').evaluateAll(cells=>cells.map(c=>({w:c.getBoundingClientRect().width,h:c.getBoundingClientRect().height})));
  assert.ok(cells.length>0 && cells.every(c=>c.w>=44 && c.h>=44));await ctx.close();console.log('PASS naval : sélection agrandie, cellules 44 px minimum');}
 {const state=JSON.parse(readFileSync(new URL('./fixtures/c14-mot-bac-saisie.json',import.meta.url),'utf8'));
  const rebase=o=>Array.isArray(o)?o.map(rebase):o&&typeof o==='object'?('__rel'in o?new Date(Date.now()+o.__rel*1000).toISOString():Object.fromEntries(Object.entries(o).map(([k,v])=>[k,rebase(v)]))):o;
  const {ctx,page}=await pageFor({...duo,notifications:[],state:rebase(state)});await page.goto(`http://localhost:4173/partie/${SESSION}`);
  const inputs=page.locator('.pb-cell input');await inputs.first().fill('Arbre');await inputs.first().press('Enter');assert.equal(await inputs.nth(1).evaluate(el=>el===document.activeElement),true);
  await ctx.setOffline(true);await page.waitForFunction(()=>!navigator.onLine);assert.equal(await inputs.first().isDisabled(),true);
  await ctx.setOffline(false);await page.waitForFunction(()=>navigator.onLine);assert.equal(await inputs.first().inputValue(),'Arbre');await ctx.close();console.log('PASS Petit bac : clavier suivant, hors ligne, brouillon conservé au retour réseau');}
 {const other='00000000-0000-4000-a000-000000000002';const {ctx,page}=await pageFor({...duo,notifications:[]});let arrived;
  const requested=new Promise(resolve=>{arrived=resolve;});
  await page.route('**/rpc/get_session_state',async route=>{const id=route.request().postDataJSON().p_session;const state=sessionState('lobby');state.session.id=id;state.game.title=id===other?'Session B':'Session A';state.session.state_version=id===other?1:99;
   if(id===SESSION){arrived();await new Promise(resolve=>setTimeout(resolve,1200));}await route.fulfill({json:state});});
  await page.goto(`http://localhost:4173/partie/${SESSION}`,{waitUntil:'domcontentloaded'});await requested;
  await page.evaluate(id=>{history.pushState({},'',`/partie/${id}`);dispatchEvent(new PopStateEvent('popstate'));},other);
  await page.getByText('Session B',{exact:true}).first().waitFor();await page.waitForTimeout(1400);assert.equal(await page.getByText('Session A',{exact:true}).count(),0);await ctx.close();console.log('PASS changement de salon : réponse tardive du précédent ignorée');}
 {const state=JSON.parse(readFileSync(new URL('./fixtures/c14-conv-dvm2-ecriture.json',import.meta.url),'utf8'));
  const {ctx,page}=await pageFor({...duo,notifications:[],state});await page.goto(`http://localhost:4173/partie/${SESSION}`);
  await page.locator('#tt2-0').fill('Je chante');await page.locator('#tt2-1').fill('Je danse');await page.locator('#tt2-2').fill('Je vole');
  await page.locator('.theatre-note').nth(2).getByRole('button').click();await page.reload();
  await page.locator('#tt2-0').waitFor();assert.equal(await page.locator('#tt2-0').inputValue(),'Je chante');assert.equal(await page.locator('#tt2-2').inputValue(),'Je vole');
  assert.equal(await page.locator('.theatre-note').nth(2).getByRole('button').getAttribute('aria-pressed'),'true');await ctx.close();console.log('PASS G08 : brouillon et mensonge conservés après rechargement, clé par joueur/séance/manche');}
} finally {await browser.close();}
