// Dépendances DB absentes : HTTP404/PGRST202 réaliste, données fictives seulement.
import assert from 'node:assert/strict';
import {chromium} from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,activeDuo}=await import('./render-check.mjs');
const BASE=process.env.BASE ?? 'http://127.0.0.1:4232';
const browser=await chromium.launch({executablePath:process.env.PW_CHROMIUM ?? '/usr/bin/chromium'});
function absent(name){return {status:404,json:{code:'PGRST202',details:null,hint:null,message:`Could not find the function public.${name} in the schema cache`}};}
async function fixture(){const ctx=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});const page=await ctx.newPage();await setup(page,{...duo,notifications:[]});return {ctx,page};}
try{
 {const {ctx,page}=await fixture();let reads=0,writes=0;const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/rpc/get_duo_space',route=>{reads++;assert.equal(route.request().postDataJSON().p_couple,activeDuo.id);return route.fulfill(absent('get_duo_space'));});
  for(const path of ['**/rpc/set_duo_cover','**/rpc/save_duo_note','**/storage/v1/object/duo-covers/**'])await page.route(path,route=>{writes++;return route.abort();});
  await page.goto(`${BASE}/espace`);
  await page.getByText('Les notes et la photo personnelle ne sont pas disponibles pour le moment.',{exact:false}).waitFor();
  assert.equal(await page.getByRole('button',{name:'Changer la photo de couverture'}).isDisabled(),true);
  assert.equal(await page.getByRole('button',{name:'Ajouter',exact:true}).isDisabled(),true);
  assert.equal(await page.getByRole('heading',{name:'Coffre à souvenirs'}).isVisible(),true);
  assert.equal(await page.locator('.duo-cover img').getAttribute('src'),'/assets/original/duo-cover.webp');
  const prior=reads;const retried=page.waitForResponse(r=>r.url().includes('/rpc/get_duo_space'));await page.getByRole('button',{name:'Réessayer',exact:true}).click();await retried;
  assert.ok(reads>prior);assert.equal(writes,0);assert.deepEqual(errors,[]);
  await ctx.close();console.log('PASS Espace RPC absent404/PGRST202 : couverture par défaut, coffre accessible, notes/upload désactivés, reprise sans écriture');}
 {const {ctx,page}=await fixture();let reads=0,countQueries=0,denyCounter=false;const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/rpc/get_home_moment',route=>{reads++;assert.equal(route.request().postDataJSON().p_couple,activeDuo.id);return route.fulfill(absent('get_home_moment'));});
  await page.route('**/rest/v1/game_sessions?*',route=>{
   const url=new URL(route.request().url());if(!url.searchParams.has('couple_id'))return route.fallback();
   countQueries++;assert.equal(url.searchParams.get('couple_id'),`eq.${activeDuo.id}`);assert.equal(url.searchParams.get('status'),'in.(ended,closed)');
   if(denyCounter)return route.fulfill({status:503,json:{message:'Service unavailable'}});
   return route.fulfill({json:[{id:'fixture1',game_id:'fixture-game-a'},{id:'fixture2',game_id:'fixture-game-a'},{id:'fixture3',game_id:'fixture-game-b'}]});
  });
  await page.goto(`${BASE}/accueil`);await page.getByText('Question indisponible pour le moment.',{exact:true}).waitFor();
  await page.waitForFunction(()=>document.querySelector('.arcade-progress')?.textContent.includes('2 jeux terminés'));
  assert.ok(countQueries>0);assert.equal(await page.locator('.arcade-feature a').first().isVisible(),true);
  const prior=reads;denyCounter=true;await page.getByRole('button',{name:'Réessayer',exact:true}).click();
  await page.getByText('Progression indisponible',{exact:true}).waitFor();assert.ok(reads>prior);assert.deepEqual(errors,[]);
  await ctx.close();console.log('PASS Home RPC absent404/PGRST202 : question indisponible, compteur distinct filtré duo, jeux accessibles, panne compteur sans faux zéro');}
}finally{await browser.close();}
