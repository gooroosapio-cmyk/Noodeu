// Captures et géométrie du salon/états communs, exclusivement fixtures locales.
import { chromium } from '@playwright/test';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';
process.env.NOODEU_FIXTURES_ONLY='1';
const { setup, duo, SESSION }=await import('./render-check.mjs');
const BASE=process.env.BASE??'http://127.0.0.1:4221';
const OUT=process.env.OUT??'/workspace/noodeu-refinement-session';
mkdirSync(OUT,{recursive:true});
const fixture=name=>JSON.parse(readFileSync(new URL(`./fixtures/${name}.json`,import.meta.url),'utf8'));
const cases=[['salon-questions','c14-conv-salon'],['salon-pig','c14-lobby-nd-de-chanceux'],['salon-aleatoire','c14-random-mixed-lobby'],['salon-g08','c14-conv-salon'],['salon-pret','c14-conv-salon'],['salon-texte-long','c14-conv-salon'],['resultat','c14-mini-morpion-fin'],['pause','c14-mini-morpion-jeu'],['invitation',null],['naval-statut','c14-mini-naval-tirs']];
const sizes=[[320,640,1],[360,740,1],[390,844,1],[430,932,1],[768,1024,1],[1440,900,1],[320,640,2],[390,460,1]];
const browser=await chromium.launch({executablePath:'/usr/bin/chromium'});
const results=[];
try{
 for(const[name,fn]of cases.filter(([name])=>!process.env.ONLY||new RegExp(process.env.ONLY).test(name))) for(const[width,height,zoom]of sizes){
  let state=fn?fixture(fn):null;
  if(name==='salon-g08'){
   const source=fixture('c14-conv-dvm2-ecriture');
   state={...source,session:{...source.session,status:'lobby',current_round:0},rounds:[]};
   state.players.forEach(p=>p.ready=false);
  }
  if(name==='salon-pret')state.players[1].ready=true;
  if(name==='salon-texte-long'){state.players[0].display_name='Alexandrine-Charlotte';state.players[1].display_name='Jean-Baptiste Théophile';state.game.title='Les conversations qui nous rapprochent, à notre rythme';state.game.rules.objective='Une description longue qui reste lisible avec le texte agrandi. '.repeat(5);}

  if(name==='pause'){state.session.status='paused';state.session.paused_by=state.players[1].user_id;state.session.pause_state={resume:[]};}
  const context=await browser.newContext({viewport:{width,height},serviceWorkers:'block',reducedMotion:'reduce',locale:'fr-FR'});
  const page=await context.newPage(); const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/*',r=>new URL(r.request().url()).origin===new URL(BASE).origin?r.continue():r.abort());
  await setup(page,{...duo,notifications:[],state,invitations:{outgoing:{id:'fixture-invite',code:'K7PM-Q2RX',status:'open',expires_at:'2026-10-29T10:00:00Z',expired:false,claimer_name:null},incoming:null}});
  await page.goto(name==='invitation'?`${BASE}/inviter`:`${BASE}/partie/${SESSION}`);
  await page.locator(name==='invitation'?'.invite-refinement':'.session-toolbar').waitFor();
  if(zoom===2)await page.addStyleTag({content:'html{font-size:200% !important}'});
  await page.evaluate(async()=>{await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));});
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1),false,`${name} ${width} no document overflow`);
  if(name.startsWith('salon')){
   const players=await page.locator('.salon01-players').boundingBox(),activity=await page.locator('.salon01-game').boundingBox();assert.ok(players.y+players.height<=activity.y+1,'players before game');
   assert.equal(await page.locator('.salon-player__name').filter({hasText:/^(Toi|Partenaire)$/}).count(),0,'real names shown');
   if(name==='salon-g08')assert.equal(await page.locator('.salon01-kicker').textContent(),'À vous deux');
   const description=await page.locator('.lobby-description').boundingBox();const settings=await page.locator('.salon-config').boundingBox();
   assert.ok(description.y<settings.y,'description before settings');
   const guide=await page.locator('.lobby-guide__button').evaluateAll(es=>es.map(e=>{const r=e.getBoundingClientRect();return{w:r.width,h:r.height};}));
   assert.ok(Math.abs(guide[0].w-guide[1].w)<1&&Math.abs(guide[0].h-guide[1].h)<1,'equal guide buttons');
   assert.ok(guide.every(r=>r.h>=44&&r.w>=44),'44px guide buttons');
   const radios=await page.locator('.salon-setting__choice > span').evaluateAll(es=>es.map(e=>e.getBoundingClientRect().height));assert.ok(radios.every(h=>h>=44));
   if(name==='salon-aleatoire'&&zoom===1){const ys=await page.locator('.salon-setting__choice').evaluateAll(es=>es.map(e=>Math.round(e.getBoundingClientRect().y)));assert.equal(new Set(ys).size,1,'5/10/20 same line');}
   await page.getByRole('button',{name:'Règles',exact:true}).click();await page.getByRole('dialog').waitFor();
   assert.equal(await page.locator('.chat-launcher').isVisible(),false,'modal blocks chat');await page.keyboard.press('Escape');
  }
  if(name==='naval-statut'){
   assert.equal(await page.locator('.session-player-strip').getByText('Réponse validée',{exact:true}).count(),0,'naval lock is not an answer');
   assert.ok(await page.locator('.session-player-strip').textContent().then(x=>x.includes('À toi de jouer')||x.includes('À son tour')));
   const grid=page.locator('.board-zoom').first();await grid.scrollIntoViewIfNeeded();
   await page.waitForTimeout(180);
   const collision=await page.evaluate(()=>{const a=document.querySelector('.chat-launcher').getBoundingClientRect(),b=document.querySelector('.board-zoom').getBoundingClientRect();return Math.max(0,Math.min(a.right,b.right)-Math.max(a.left,b.left))*Math.max(0,Math.min(a.bottom,b.bottom)-Math.max(a.top,b.top));});
   assert.equal(collision,0,'chat does not cover read-only or active board');
  }
  if(name==='resultat'){
   const result=await page.locator('main > .stage').boundingBox();const after=await page.locator('.after-game').boundingBox();
   assert.ok(after.y>=result.y+result.height-1,'retour au calme after result without overlap');
  }
  assert.deepEqual(errors,[]);
  await page.evaluate(()=>{if(document.activeElement instanceof HTMLElement)document.activeElement.blur();});
  await page.screenshot({path:`${OUT}/${name}-${width}x${height}-${zoom}.png`});
  results.push({name,width,height,textScale:zoom,ok:true});await context.close();
 }
 console.log(`PASS ${results.length} vues salon/états communs`);
}finally{writeFileSync(`${OUT}/results.json`,JSON.stringify(results,null,2));await browser.close();}
