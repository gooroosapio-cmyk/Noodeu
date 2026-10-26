// Kit rouge : G01 sans saisie (« C'est répondu » / « C'est fait »), G08 tour par tour sans fuite côté devineur.
// États réels (fixtures rouge-*), coups interceptés ; les règles serveur sont testées par c41. Aucun appel externe.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {chromium,expect} from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,SESSION}=await import('./render-check.mjs');
const BASE=process.env.BASE??'http://127.0.0.1:4173';
const browser=await chromium.launch({executablePath:process.env.PW_CHROMIUM??'/usr/bin/chromium'});
const fixture=name=>{const s=JSON.parse(readFileSync(new URL(`./fixtures/${name}`,import.meta.url),'utf8'));s.session.id=SESSION;return s;};
let failures=0;
async function scenario(name,state,fn,width=390){
 const ctx=await browser.newContext({viewport:{width,height:780},serviceWorkers:'block'});
 const page=await ctx.newPage();page.setDefaultTimeout(7000);
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const moves=[];
 try{
  await page.route('**/*',r=>new URL(r.request().url()).origin===new URL(BASE).origin?r.continue():r.abort());
  await setup(page,{...duo,notifications:[],state});
  await page.route('**/rpc/get_session_state',r=>r.fulfill({json:state}));
  await page.route('**/rpc/play_move',r=>{moves.push(r.request().postDataJSON());return r.fulfill({json:{ok:true}});});
  await page.goto(`${BASE}/partie/${SESSION}`);
  await fn(page,moves);assert.deepEqual(errors,[]);console.log(`PASS ${name} (${width}px)`);
 }catch(e){failures++;console.error(`FAIL ${name} (${width}px) : ${e.message}`);}
 finally{await ctx.close();}
}
try{
 for(const width of [320,412]){
  await scenario('G01 vérité : aucune zone de saisie, C’est répondu sans texte',fixture('rouge-g01-verite.json'),async(page,moves)=>{
   assert.equal(await page.locator('textarea, input[type="text"], input:not([type])').count(),0,'aucun champ dans Action ou vérité');
   await expect(page.getByRole('button',{name:'Changer de carte'})).toBeVisible();
   await expect(page.getByRole('button',{name:'Passer',exact:true})).toBeVisible();
   const done=page.getByRole('button',{name:'C’est répondu !'});
   await done.scrollIntoViewIfNeeded();await expect(done).toBeInViewport();
   await done.click();
   await expect.poll(()=>moves.length).toBe(1);
   assert.equal(moves[0].p_type,'mark_done');assert.deepEqual(moves[0].p_payload,{});
  },width);
 }
 await scenario('G01 action : C’est fait',fixture('rouge-g01-action.json'),async(page,moves)=>{
  await page.getByRole('button',{name:'C’est fait !'}).click();
  await expect.poll(()=>moves.length).toBe(1);assert.equal(moves[0].p_type,'mark_done');
 });
 await scenario('G01 observateur : aucune commande de réponse',fixture('rouge-g01-action-observe.json'),async page=>{
  assert.equal(await page.getByRole('button',{name:/C’est (fait|répondu)/}).count(),0);
  await expect(page.getByText('réalise son action',{exact:false})).toBeVisible();
 });
 await scenario('G08 auteur : trois propositions, un mensonge, verrouillage',fixture('rouge-g08-ecriture.json'),async(page,moves)=>{
  const lock=page.getByRole('button',{name:'Verrouiller mes propositions'});
  await expect(lock).toBeDisabled();
  for(const [i,txt] of ['J’ai vécu à Lisbonne.','Je joue du violon.','Je n’ai jamais vu la mer.'].entries())await page.getByLabel(`Affirmation ${i+1}`).fill(txt);
  await page.getByRole('radio',{name:'Mon mensonge'}).nth(1).check();
  await page.getByRole('checkbox').check();
  await lock.click();
  await expect.poll(()=>moves.length).toBe(1);
  assert.equal(moves[0].p_type,'publish_three');assert.equal(moves[0].p_payload.lie_statement_id,'s2');
  assert.equal(moves[0].p_payload.statements.length,3);
 });
 await scenario('G08 auteur : le brouillon survit au rechargement',fixture('rouge-g08-ecriture.json'),async page=>{
  await page.getByLabel('Affirmation 1').fill('Brouillon un');
  await page.getByLabel('Affirmation 3').fill('Brouillon trois');
  await page.getByRole('radio',{name:'Mon mensonge'}).nth(2).check();
  await page.getByRole('checkbox').check();
  await page.reload();
  await expect(page.getByLabel('Affirmation 1')).toHaveValue('Brouillon un');
  await expect(page.getByLabel('Affirmation 3')).toHaveValue('Brouillon trois');
  await expect(page.getByRole('radio',{name:'Mon mensonge'}).nth(2)).toBeChecked();
  await expect(page.getByRole('checkbox')).toBeChecked();
 });
 for(const [label,file,field] of [['tour par tour','rouge-g08-ecriture.json','Affirmation 1'],['simultané','c14-conv-dvm2-ecriture.json',null]]){
  const state=fixture(file);
  await scenario(`G08 ${label} : brouillon oublié après « Passer cette carte »`,state,async page=>{
   const input=field?page.getByLabel(field):page.locator('input, textarea').first();
   await input.fill('Brouillon à oublier');
   const drafts=()=>page.evaluate(()=>Object.keys(sessionStorage).filter(k=>k.includes('two-truths')).length);
   await expect.poll(drafts).toBe(1);
   const card=state.rounds.find(r=>r.round_no===state.session.current_round).card;
   Object.assign(card,{done:true,skipped:true,skipped_by:1});state.session.state_version++;
   await page.evaluate(()=>window.dispatchEvent(new Event('focus')));
   await expect(page.getByText('passée',{exact:false}).first()).toBeVisible();
   await expect.poll(drafts).toBe(0);
  });
 }
 await scenario('G08 devineur pendant l’écriture : rien à lire, pas de champ',fixture('rouge-g08-attente.json'),async page=>{
  assert.equal(await page.locator('input, textarea').count(),0);
  await expect(page.getByText('écrit ses trois affirmations',{exact:false})).toBeVisible();
 });
 await scenario('G08 devineur : choisit puis valide',fixture('rouge-g08-devine.json'),async(page,moves)=>{
  await page.getByRole('radio',{name:/salé que sucré/}).click();
  await page.getByRole('button',{name:'Valider mon choix'}).click();
  await expect.poll(()=>moves.length).toBe(1);
  assert.equal(moves[0].p_type,'lock_guess');assert.equal(moves[0].p_payload.statement_id,'s2');
 });
}finally{await browser.close();}
if(failures)process.exitCode=1;
