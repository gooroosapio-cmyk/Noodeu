// Recette Admin côté interface uniquement. Tous les RPC sont des fixtures ; aucune
// écriture distante, permission DB ou suppression réelle n'est exécutée ici.
import assert from 'node:assert/strict';
import {chromium} from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup}=await import('./render-check.mjs');
const BASE=process.env.BASE??'http://127.0.0.1:4221';
const browser=await chromium.launch({executablePath:'/usr/bin/chromium'});
const questions=[
 {bank:'fixture_pack',idx:0,id:'p1',text:'Question alpha pour la recette',adult:false,category:'Découverte fixture',activity:'Pack fixture',type:'pack',mechanic:'pack_conversation'},
 {bank:'fixture_pack',idx:1,id:'p2',text:'Question bêta pour la recette',adult:true,category:'Découverte fixture',activity:'Pack fixture',type:'pack',mechanic:'pack_conversation'},
 {bank:'fixture_test',idx:0,id:'t1',text:'Item noté fixture',adult:false,category:'Découverte fixture',activity:'Test fixture',type:'test',mechanic:'test_form'},
 {bank:'fixture_dilemma',idx:0,id:'d1',text:'Dilemme fixture',adult:false,category:'Jeux fixture',activity:'Dilemme fixture',type:'game',mechanic:'nd_dilemma',options:[{id:'a',text:'Option A'},{id:'b',text:'Option B'}]},
];
let failed=0,passed=0;
async function run(name,body,scenario={admin:true}){
 if(process.env.ONLY&&!new RegExp(process.env.ONLY).test(name))return;
 const ctx=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});const page=await ctx.newPage();page.setDefaultTimeout(7000);
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 // Tout domaine externe non couvert par setup est refusé, y compris une URL
 // Supabase différente de celle des fixtures.
 await page.route('**/*',route=>{const u=new URL(route.request().url());return ['localhost','127.0.0.1'].includes(u.hostname)?route.continue():route.abort();});
 await setup(page,{duos:[],notifications:[],...scenario});
 await page.route('**/rpc/admin_list_questions',r=>r.fulfill({json:scenario.admin?{ok:true,questions}:{ok:false,error:'forbidden'}}));
 try{await body(page,ctx);assert.deepEqual(errors,[]);passed++;console.log('PASS '+name);}
 catch(e){failed++;console.error('FAIL '+name+' : '+e.message);}
 finally{await ctx.close();}
}
const admin=page=>page.goto(`${BASE}/admin/questions`);
const firstRow=page=>page.locator('.admin-q').filter({hasText:'Question alpha pour la recette'});
try{
 await run('non-admin : entrée absente et route refusée sans formulaire',async page=>{
  await page.goto(`${BASE}/reglages`);await page.getByRole('heading',{name:'Réglages',exact:true}).waitFor();
  assert.equal(await page.locator('a[href="/admin/questions"]').count(),0);
  await admin(page);await page.getByText("Cette page est réservée à l'administration.").waitFor();
  assert.equal(await page.locator('.admin-form,.admin-list').count(),0);
 },{admin:false});
 await run('anonyme : route Admin protégée par authentification',async page=>{
  let calls=0;await page.route('**/rpc/admin_list_questions',r=>{calls++;return r.abort();});
  await admin(page);await page.waitForURL(u=>u.pathname==='/'&&u.searchParams.get('next')==='/admin/questions');assert.equal(calls,0);
 },{auth:false,admin:false});
 await run('RPC Admin absents : entrée cachée et erreur lisible',async page=>{
  const missing=name=>({status:404,json:{code:'PGRST202',message:`Could not find the function public.${name} in the schema cache`,details:null,hint:null}});
  await page.route('**/rpc/is_app_admin',r=>r.fulfill(missing('is_app_admin')));
  await page.route('**/rpc/admin_list_questions',r=>r.fulfill(missing('admin_list_questions')));
  await page.goto(`${BASE}/reglages`);await page.getByRole('heading',{name:'Réglages',exact:true}).waitFor();assert.equal(await page.locator('a[href="/admin/questions"]').count(),0);
  await admin(page);await page.getByText("L'action n'a pas abouti. Réessaie dans un instant.",{exact:true}).waitFor();assert.equal(await page.locator('.admin-form,.admin-list').count(),0);
 });
 await run('admin : entrée, recherche, catégories et protection des tests',async page=>{
  await page.goto(`${BASE}/reglages`);await page.locator('a[href="/admin/questions"]').click();await page.locator('.admin-q').first().waitFor();assert.equal(await page.locator('.admin-q').count(),4);
  await page.getByRole('searchbox',{name:'Rechercher'}).fill('ALPHA');assert.equal(await page.locator('.admin-q').count(),1);
  await page.getByRole('searchbox',{name:'Rechercher'}).fill('');await page.locator('.admin-filters select').nth(0).selectOption('Jeux fixture');assert.equal(await page.locator('.admin-q').count(),1);
  await page.locator('.admin-filters select').nth(0).selectOption('Découverte fixture');await page.locator('.admin-filters select').nth(1).selectOption('Test fixture');
  assert.equal(await page.getByRole('button',{name:'Ajouter une question',exact:true}).isDisabled(),true);assert.equal(await page.getByRole('button',{name:'Supprimer',exact:true}).count(),0);
 });
 await run('édition : vide refusé, erreur serveur conservée, sauvegarde validée',async page=>{
  let calls=0,accept=false,payload;
  await page.route('**/rpc/admin_update_question',r=>{calls++;payload=r.request().postDataJSON();return r.fulfill({json:accept?{ok:true}:{ok:false,error:'invalid_text'}});});
  await admin(page);const row=page.locator('.admin-q').first();await row.getByRole('button',{name:'Modifier',exact:true}).click();
  await row.getByLabel('Texte de la question').fill('  ');assert.equal(await row.getByRole('button',{name:'Enregistrer',exact:true}).isDisabled(),true);await row.locator('form').evaluate(f=>f.requestSubmit());assert.equal(calls,0);
  await row.getByLabel('Texte de la question').fill('Modification fixture');await row.getByRole('button',{name:'Enregistrer',exact:true}).click();await row.getByRole('alert').waitFor();assert.equal(calls,1);assert.equal(await row.locator('textarea').inputValue(),'Modification fixture');
  accept=true;await row.getByRole('button',{name:'Enregistrer',exact:true}).click();await page.getByText('Modification fixture',{exact:true}).waitFor();assert.equal(calls,2);assert.equal(payload.p_bank,'fixture_pack');assert.equal(payload.p_id,'p1');assert.equal(payload.p_text,'Modification fixture');
 });
 await run('suppression : annulation, confirmation explicite et refus serveur',async page=>{
  let calls=0,accept=false;await page.route('**/rpc/admin_delete_question',r=>{calls++;return r.fulfill({json:accept?{ok:true}:{ok:false,error:'last_question'}});});
  await admin(page);const row=firstRow(page);await row.getByRole('button',{name:'Supprimer',exact:true}).click();await page.getByRole('dialog').getByRole('button',{name:'Annuler',exact:true}).click();assert.equal(calls,0);assert.equal(await row.count(),1);
  await row.getByRole('button',{name:'Supprimer',exact:true}).click();await page.getByRole('dialog').getByRole('button',{name:'Supprimer',exact:true}).click();await row.getByRole('alert').waitFor();assert.equal(calls,1);assert.equal(await row.count(),1);
  accept=true;await row.getByRole('button',{name:'Supprimer',exact:true}).click();await page.getByRole('dialog').getByRole('button',{name:'Supprimer',exact:true}).click();await row.waitFor({state:'detached'});assert.equal(calls,2);
 });
 await run('révocation : erreur forbidden sans modification optimiste',async page=>{
  await page.route('**/rpc/admin_set_question_adult',r=>r.fulfill({json:{ok:false,error:'forbidden'}}));
  await admin(page);const row=firstRow(page);const toggle=row.getByRole('button',{name:'Question tout public : toucher pour la marquer +18'});await toggle.click();await row.getByRole('alert').waitFor();assert.equal(await toggle.getAttribute('aria-pressed'),'false');
 });
 await run('marquage +18 : double clic une seule écriture',async page=>{
  let calls=0;await page.route('**/rpc/admin_set_question_adult',async r=>{calls++;assert.equal(r.request().postDataJSON().p_adult,true);await new Promise(resolve=>setTimeout(resolve,150));return r.fulfill({json:{ok:true}});});
  await admin(page);const row=firstRow(page);await row.getByRole('button',{name:'Question tout public : toucher pour la marquer +18'}).evaluate(b=>{b.click();b.click();});
  await row.getByRole('button',{name:'Question +18 : toucher pour la passer en tout public'}).waitFor();assert.equal(calls,1,'un seul admin_set_question_adult pour deux clics synchrones');
 });
 await run('ajout : options requises puis double soumission une seule écriture',async page=>{
  let calls=0,payload;await page.route('**/rpc/admin_add_question',async r=>{calls++;payload=r.request().postDataJSON();await new Promise(resolve=>setTimeout(resolve,150));return r.fulfill({json:{ok:true}});});
  await admin(page);await page.locator('.admin-filters select').nth(1).selectOption('Dilemme fixture');await page.getByRole('button',{name:'Ajouter une question',exact:true}).click();
  const form=page.locator('.admin-form');await form.getByLabel('Texte de la question').fill('Nouvelle question fixture');assert.equal(await form.getByRole('button',{name:'Ajouter une question',exact:true}).isDisabled(),true);
  await form.getByLabel('Proposition 1').fill('Un');await form.getByLabel('Proposition 2').fill('Deux');
  await form.evaluate(f=>{f.requestSubmit();f.requestSubmit();});await form.waitFor({state:'detached'});assert.equal(calls,1,'un seul admin_add_question pour deux soumissions synchrones');assert.deepEqual(payload.p_options,['Un','Deux']);
 });
 await run('édition : double soumission une seule écriture',async page=>{
  let calls=0;await page.route('**/rpc/admin_update_question',async r=>{calls++;await new Promise(resolve=>setTimeout(resolve,150));return r.fulfill({json:{ok:true}});});
  await admin(page);await firstRow(page).getByRole('button',{name:'Modifier',exact:true}).click();const form=page.locator('.admin-form');await form.getByLabel('Texte de la question').fill('Texte double fixture');await form.evaluate(f=>{f.requestSubmit();f.requestSubmit();});await form.waitFor({state:'detached'});assert.equal(calls,1,'un seul admin_update_question pour deux soumissions synchrones');
 });
 await run('suppression : double clic de confirmation une seule écriture',async page=>{
  let calls=0;await page.route('**/rpc/admin_delete_question',async r=>{calls++;await new Promise(resolve=>setTimeout(resolve,150));return r.fulfill({json:{ok:true}});});
  await admin(page);const row=firstRow(page);await row.getByRole('button',{name:'Supprimer',exact:true}).click();await page.getByRole('dialog').getByRole('button',{name:'Supprimer',exact:true}).evaluate(b=>{b.click();b.click();});await row.waitFor({state:'detached'});assert.equal(calls,1,'un seul admin_delete_question pour deux confirmations synchrones');
 });
}finally{await browser.close();}
console.log(`ADMIN : ${passed} réussi(s), ${failed} échoué(s)`);if(failed)process.exitCode=1;
