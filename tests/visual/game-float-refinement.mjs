// Le chat ne couvre ni texte partagé ni plateau, même en lecture seule.
import {chromium} from '@playwright/test';import assert from 'node:assert/strict';import{readFileSync,mkdirSync,writeFileSync}from'node:fs';
process.env.NOODEU_FIXTURES_ONLY='1';const{setup,duo,SESSION}=await import('./render-check.mjs');
const BASE=process.env.BASE??'http://127.0.0.1:4221',OUT=process.env.OUT??'test-results/game-float-refinement';mkdirSync(OUT,{recursive:true});
const browser=await chromium.launch({executablePath:'/usr/bin/chromium'}),report=[];
const cases=['pack-revelation','mot-pendu-devineur','mini-naval-tirs','conv-dvm2-revelation'];
try{for(const name of cases)for(const[w,h,z]of[[320,640,1],[390,844,1],[430,932,1],[320,640,2]]){
 const context=await browser.newContext({viewport:{width:w,height:h},serviceWorkers:'block',reducedMotion:'reduce'}),page=await context.newPage();
 const state=JSON.parse(readFileSync(new URL(`./fixtures/c14-${name}.json`,import.meta.url)));
 await page.route('**/*',r=>new URL(r.request().url()).origin===new URL(BASE).origin?r.continue():r.abort());await setup(page,{...duo,state,notifications:[]});
 await page.goto(`${BASE}/partie/${SESSION}`);await page.locator('.chat-launcher').waitFor();if(z===2)await page.addStyleTag({content:'html{font-size:200%}'});await page.evaluate(()=>document.fonts.ready);
 for(const ratio of[0,.5,1]){
  await page.locator('main').evaluate((e,r)=>e.scrollTop=(e.scrollHeight-e.clientHeight)*r,ratio);await page.waitForTimeout(220);
  const overlap=await page.evaluate(()=>{const a=document.querySelector('.chat-launcher').getBoundingClientRect(),main=document.querySelector('main').getBoundingClientRect();return [...document.querySelectorAll('main .hm-slots,main .q-answer,main .reveal,main .question-reading,main .board-zoom')].map(e=>{const r=e.getBoundingClientRect(),l=Math.max(r.left,main.left,0),t=Math.max(r.top,main.top,0),right=Math.min(r.right,main.right,innerWidth),bottom=Math.min(r.bottom,main.bottom,innerHeight);return{cls:e.className,area:Math.max(0,Math.min(a.right,right)-Math.max(a.left,l))*Math.max(0,Math.min(a.bottom,bottom)-Math.max(a.top,t))};}).filter(x=>x.area>1);});
  assert.deepEqual(overlap,[],`${name} ${w}/${z} at ${ratio}`);
 }
 await page.screenshot({path:`${OUT}/${name}-${w}-${z}.png`});report.push({name,w,h,z,positions:3,ok:true});await context.close();
}console.log('PASS 16 contextes × 3 positions : texte/plateaux dégagés du chat');}finally{writeFileSync(`${OUT}/report.json`,JSON.stringify(report,null,2));await browser.close();}
