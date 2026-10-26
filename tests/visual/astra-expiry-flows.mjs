// Vérifications UI avec RPC simulées uniquement ; aucune base distante appelée.
// BASE et PW_CHROMIUM configurables. Les invariants SQL se vérifient séparément.
const BASE=process.env.BASE ?? 'http://localhost:4173';
import {chromium,expect} from '@playwright/test';
import {readFileSync} from 'node:fs';import assert from 'node:assert/strict';
process.env.NOODEU_FIXTURES_ONLY='1';const {setup,duo,SESSION}=await import('./render-check.mjs');
const rebase=o=>Array.isArray(o)?o.map(rebase):o&&typeof o==='object'?('__rel'in o?new Date(Date.now()+o.__rel*1000).toISOString():Object.fromEntries(Object.entries(o).map(([k,v])=>[k,rebase(v)]))):o;
const b=await chromium.launch({executablePath:process.env.PW_CHROMIUM ?? '/usr/bin/chromium'});
try{for(const name of ['mini-pfc-verrouille','mot-bac-saisie','mot-bac-arbitrage']){
 const ctx=await b.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});const p=await ctx.newPage();
 const state=rebase(JSON.parse(readFileSync(new URL(`./fixtures/c14-${name}.json`, import.meta.url))));const c=state.rounds.at(-1).card;
 c.deadline_at=new Date(Date.now()+1500).toISOString();c.stop_after=new Date(Date.now()-10000).toISOString();if(name==='mot-bac-arbitrage')c.validation_deadline=c.deadline_at;
 await p.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort()); await setup(p,{...duo,state,notifications:[]});let fail=true;const calls=[];let firstDone;const first=new Promise(r=>firstDone=r);
 await p.route('**/rpc/play_move',async route=>{const args=route.request().postDataJSON();if(args.p_type!=='expire')throw Error('unexpected move '+args.p_type);calls.push(Date.now());if(!fail){c.rev++;state.session.state_version++;if(name==='mini-pfc-verrouille'){Object.assign(c,{done:true,void:true,locked:{},scores:{1:0,2:0}});state.rounds.at(-1).revealed=true;}else if(name==='mot-bac-saisie'){c.phase='validate';c.validation_deadline=new Date(Date.now()+60000).toISOString();c.answers={};}else{c.done=true;c.phase='done';c.scores={1:0,2:0};}}
 await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(fail?{ok:false,error:'network'}:{ok:true})});firstDone();});
 await p.goto(`${BASE}/partie/${SESSION}`,{waitUntil:'networkidle'});await first;await p.waitForTimeout(150);assert.equal(calls.length,1);assert.equal(await p.evaluate(()=>navigator.onLine),true);fail=false;await p.evaluate(()=>window.dispatchEvent(new Event('focus')));await p.waitForTimeout(2200);assert.equal(calls.length,2);assert.ok(calls[1]-calls[0]>=950);await p.waitForTimeout(1800);assert.equal(calls.length,2);console.log(`PASS ${name}: échec RPC online=true, reprise au focus, 2 appels espacés, état serveur avancé, aucune boucle`);await ctx.close();
}
 // Le budget automatique est fini ; la reprise manuelle reste visible et limitée en fréquence.
 {
  const ctx=await b.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});
  const p=await ctx.newPage();
  await p.clock.install({time:new Date()});
  const state=rebase(JSON.parse(readFileSync(new URL('./fixtures/c14-mini-pfc-verrouille.json',import.meta.url))));
  const card=state.rounds.at(-1).card;
  card.deadline_at=new Date(Date.now()-1000).toISOString();
  await p.route('**/*', route => new URL(route.request().url()).origin === new URL(BASE).origin ? route.continue() : route.abort()); await setup(p,{...duo,state,notifications:[]});
  const calls=[];let fail=true;
  await p.route('**/rpc/play_move',async route=>{
   assert.equal(route.request().postDataJSON().p_type,'expire');
   calls.push(await p.evaluate(()=>Date.now()));
   if(!fail){
    Object.assign(card,{rev:card.rev+1,done:true,void:true,locked:{},scores:{1:0,2:0}});
    state.rounds.at(-1).revealed=true;state.session.state_version++;
   }
   await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(fail?{ok:false,error:'network'}:{ok:true})});
  });
  await p.goto(`${BASE}/partie/${SESSION}`,{waitUntil:'networkidle'});
  await expect.poll(()=>calls.length).toBe(1);
  for(const [i,delay] of [1600,3100,6100,12100,20100].entries()){
   await p.clock.fastForward(delay);
   await expect.poll(()=>calls.length).toBe(i+2);
   await new Promise(resolve=>setTimeout(resolve,100));
  }
  const retry=p.getByRole('button',{name:'Réessayer la confirmation',exact:true});
  await retry.waitFor();
  fail=false;await retry.click();
  // Le clic peut lui-même attendre plus d'une seconde (défilement/actionnabilité).
  // On contrôle l'intervalle réel des appels, pas leur nombre avant le prochain tick.
  await p.clock.fastForward(1100);
  await expect.poll(()=>calls.length).toBe(7);
  assert.ok(calls[6]-calls[5]>=1000);
  await expect(retry).toHaveCount(0);
  await p.locator('.astra-board--result').waitFor();
  await p.clock.fastForward(25000);
  assert.equal(calls.length,7);
  console.log('PASS budget épuisé : message + bouton visibles, reprise manuelle espacée ≥1s, état final serveur, aucun appel supplémentaire');
  await ctx.close();
 }
}finally{await b.close();}
