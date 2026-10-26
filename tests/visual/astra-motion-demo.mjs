// Démonstration vidéo de l'interface réelle avec réponses RPC simulées, aucune base distante.
import { chromium } from '@playwright/test';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,SESSION}=await import('./render-check.mjs');
const base=process.env.BASE??'http://127.0.0.1:4191';
const out=process.env.OUT??'/workspace/noodeu-astra-motion';mkdirSync(out,{recursive:true});
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const context=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block',recordVideo:{dir:out,size:{width:390,height:844}}});
const page=await context.newPage();
await page.route('**/*',r=>new URL(r.request().url()).origin===new URL(base).origin?r.continue():r.abort());
const state=JSON.parse(readFileSync(new URL('./fixtures/c14-mot-pendu-devineur.json',import.meta.url),'utf8'));
delete state.rounds[0].private;
await setup(page,{...duo,notifications:[],state});
await page.route('**/rpc/play_move',async route=>{
 const p=route.request().postDataJSON();const c=state.rounds[0].card;
 if(p.p_type==='guess_letter'){
  const letter=p.p_payload.letter;c.errors++;c.rev++;c.guessed.push(letter);c.misses.push(letter);state.session.state_version++;
 }
 await route.fulfill({json:{ok:true}});
});
await page.goto(`${base}/partie/${SESSION}`);await page.locator('.astra-flower__petal').first().waitFor();
await page.waitForTimeout(4500); // laisse le premier rattrapage transport simulé se stabiliser
await page.getByRole('button',{name:'B',exact:true}).click();await page.waitForTimeout(1600);
await page.getByRole('button',{name:'C',exact:true}).click();await page.waitForTimeout(1600);
const sample=await page.evaluate(async()=>{
 const frames=[];let last=performance.now();
 await new Promise(resolve=>{function frame(now){frames.push(now-last);last=now;if(frames.length<120)requestAnimationFrame(frame);else resolve()}requestAnimationFrame(frame)});
 const sorted=frames.slice(1).sort((a,b)=>a-b);
 return {samples:sorted.length,median_frame_ms:sorted[Math.floor(sorted.length*.5)],p95_frame_ms:sorted[Math.floor(sorted.length*.95)],ambient_animation:getComputedStyle(document.body,'::before').animationName};
});
writeFileSync(`${out}/performance.json`,JSON.stringify({...sample,scope:'Chromium local headless, fixture Pendu, aucune mesure appareil physique'},null,2));
const video=page.video();await context.close();writeFileSync(`${out}/video-path.txt`,await video.path());await browser.close();console.log(sample);
