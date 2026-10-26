// Aperçus du code intégré, données fictives ; aucun service distant.
import {chromium} from '@playwright/test';import{readFileSync,mkdirSync,writeFileSync}from'node:fs';import assert from'node:assert/strict';
process.env.NOODEU_FIXTURES_ONLY='1';const{setup,duo,SESSION}=await import('./render-check.mjs');
const BASE=process.env.BASE??'http://127.0.0.1:4221',OUT=process.env.OUT??'/workspace/noodeu-refinement-deliverables/screens';mkdirSync(OUT,{recursive:true});
const rebase=o=>Array.isArray(o)?o.map(rebase):o&&typeof o==='object'?'__rel'in o?new Date(Date.now()+o.__rel*1000).toISOString():Object.fromEntries(Object.entries(o).map(([k,v])=>[k,rebase(v)])):o;
const fixture=n=>rebase(JSON.parse(readFileSync(new URL(`./fixtures/c14-${n}.json`,import.meta.url))));
const editable=s=>{const r=s.rounds[0];Object.assign(r.card,{done:false,locked:{},continue:{}});delete r.card.answers;delete r.card.verdict;r.private=null;r.revealed=false;};
const scenes=[
 ['01-invitation',null],['02-salon-g08','conv-dvm2-ecriture'],['03-salon-aleatoire','random-mixed-lobby'],['04-salon-pig','lobby-nd-de-chanceux'],
 ['05-question-ouverte','pack-attente'],['06-questionnaire','test-jeu'],['07-action-verite','conv-av-choix'],['08-verite-saisie','conv-av-verite'],
 ['09-jamais','conv-jamais-attente'],['10-tu-preferes','conv-preferes-jeu'],['11-qui','conv-qui-revelation'],['12-devine','conv-devine-verdict'],
 ['13-opinions','conv-accord-jeu'],['14-complete','conv-phrase-jeu'],['15-g08-ecrire','conv-dvm2-ecriture'],['16-g08-deviner','conv-dvm2-devine'],['17-g08-reveler','conv-dvm2-revelation'],
 ['18-morpion','mini-morpion-jeu'],['19-pfc-choix','mini-pfc-verrouille'],['20-pfc-revelation','mini-pfc-revelation'],['21-pig','mini-de-jeu'],
 ['22-naval-placement','mini-naval-placement'],['23-naval-tirs','mini-naval-tirs'],['24-dots12-vue','mini-points-jeu'],['25-dots12-ciblage','mini-points-jeu'],
 ['26-pendu','mot-pendu-devineur'],['27-petit-bac','mot-bac-saisie'],['28-bac-correction','mot-bac-arbitrage'],['29-cite-appel','mot-cite-appel'],['30-cite-juge','mot-cite-juge'],
 ['31-resultat','mini-morpion-fin'],['32-reconnexion','mini-morpion-jeu'],['33-chat-integre','mini-morpion-jeu'],['34-partage-revele','pack-revelation'],['35-question-longue','conv-preferes-jeu'],['36-egalite','mini-morpion-fin'],
];
const browser=await chromium.launch({executablePath:'/usr/bin/chromium'}),report=[];
try{for(const[name,f]of scenes.filter(([name])=>!process.env.ONLY||new RegExp(process.env.ONLY).test(name))){
 const state=f?fixture(f):null;
 if(name==='02-salon-g08'){state.session.status='lobby';state.session.current_round=0;state.rounds=[];state.players.forEach(p=>p.ready=false);}
 if(name==='05-question-ouverte'){state.rounds[0].card.status={};state.rounds[0].private=null;}
 if(['09-jamais','11-qui','12-devine'].includes(name))editable(state);
 if(name.startsWith('24-')||name.startsWith('25-'))Object.assign(state.rounds.at(-1).card,{dot_rows:12,dot_columns:12,box_rows:11,box_columns:11,total_boxes:121,total_edges:264,owner:Array.from({length:121},(_,i)=>i<2?1:0)});
 if(name==='35-question-longue')state.rounds[0].card.text='Vous disposez d’une journée libre, sans rendez-vous ni obligation. Préférerais-tu partir ensemble découvrir un endroit inconnu, en décidant de la destination seulement au dernier moment, ou rester à la maison pour cuisiner, écouter de la musique et prendre enfin le temps de parler ? Pense aussi à ce qui te ferait du bien cette semaine : le plaisir de la nouveauté, le calme d’un lieu familier, un moment de complicité ou la possibilité de ralentir. Choisis l’option qui te ressemble aujourd’hui ; vous pourrez expliquer votre choix après la révélation.';
 if(name==='36-egalite'){state.session.result.points={'1':0,'2':0};Object.assign(state.rounds[0].card,{winner:0,line:[],scores:{'1':0,'2':0},board:[1,2,1,1,2,2,2,1,1]});}
 const context=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block',reducedMotion:'reduce',locale:'fr-FR'}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(e.message));await page.route('**/*',r=>new URL(r.request().url()).origin===new URL(BASE).origin?r.continue():r.abort());
 await setup(page,{...duo,state,notifications:[],invitations:{outgoing:{id:'fixture',code:'K7PM-Q2RX',status:'open',expires_at:'2026-10-29T10:00:00Z',expired:false,claimer_name:null},incoming:null}});
 await page.goto(f?`${BASE}/partie/${SESSION}`:`${BASE}/inviter`,{waitUntil:'networkidle'});await page.locator(f?'.session-toolbar':'.invite-refinement').waitFor();await page.evaluate(()=>document.fonts.ready);
 if(name==='24-dots12-vue')await page.getByRole('button',{name:'Vue entière',exact:true}).click();
 if(name==='25-dots12-ciblage'){const board=page.locator('.board-zoom');await board.scrollIntoViewIfNeeded();await board.evaluate(e=>{e.scrollLeft=e.scrollWidth;e.scrollTop=e.scrollHeight;});await page.locator('[data-edge="h:11:10"]').focus();}
 if(name==='32-reconnexion'){await context.setOffline(true);await page.getByText('En attente du réseau',{exact:true}).waitFor();}
 if(name==='33-chat-integre'){await page.locator('.chat-launcher').click();await page.getByRole('dialog').waitFor();}
 if(name==='36-egalite')assert.equal(await page.locator('.session-result-refinement h1').textContent(),'Égalité');
 await page.waitForTimeout(150);assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1),false);assert.deepEqual(errors,[]);
 await page.screenshot({path:`${OUT}/${name}.png`});
 const targets={'24-dots12-vue':'.astra-overview','15-g08-ecrire':'.theatre-form button[type="submit"]','21-pig':'.pig-actions','22-naval-placement':'.board-zoom','23-naval-tirs':'.board-zoom','26-pendu':'.hm-key:last-child','27-petit-bac':'.pb-stop','28-bac-correction':'.pb-comparison:last-of-type','30-cite-juge':'.cite-verdicts'};
 if(targets[name]&&await page.locator(targets[name]).count()){await page.locator(targets[name]).first().scrollIntoViewIfNeeded();await page.waitForTimeout(150);await page.screenshot({path:`${OUT}/${name}-commandes.png`});}
 if(name==='35-question-longue'){await page.getByRole('region',{name:'Question de la manche',exact:true}).focus();await page.keyboard.press('End');await page.waitForFunction(()=>{const e=document.querySelector('.question-reading__scroll');return e.scrollTop+e.clientHeight>=e.scrollHeight-2;});await page.screenshot({path:`${OUT}/${name}-fin.png`});}
 report.push({name,fixture:f,width:390,height:844,errors,ok:true});await context.close();
}console.log(`PASS ${report.length} états finaux capturés`);}finally{writeFileSync(`${OUT}/manifest.json`,JSON.stringify(report,null,2));await browser.close();}
