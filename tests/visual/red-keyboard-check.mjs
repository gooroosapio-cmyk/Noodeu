// Clavier ouvert (émulation : hauteur visible réduite à 420 px) : le champ actif et la validation restent visibles.
import assert from 'node:assert/strict';
import {readFileSync,mkdirSync} from 'node:fs';
import {chromium} from '@playwright/test';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,SESSION}=await import('./render-check.mjs');
const BASE=process.env.BASE??'http://127.0.0.1:4173';
const OUT=process.argv[2]??'test-results/red-keyboard';mkdirSync(OUT,{recursive:true});
const browser=await chromium.launch({executablePath:process.env.PW_CHROMIUM??'/usr/bin/chromium'});
const fixture=name=>{const s=JSON.parse(readFileSync(new URL(`./fixtures/${name}`,import.meta.url),'utf8'));s.session.id=SESSION;return s;};
const cases=[
 ['g08-ecriture','rouge-g08-ecriture.json',page=>page.getByLabel('Affirmation 3'),'Verrouiller mes propositions'],
 ['g09-phrase','c14-conv-phrase-jeu.json',page=>page.locator('textarea').first(),'Valider'],
 ['m16-petit-bac','c14-mot-bac-saisie.json',page=>page.locator('input').last(),null],
];
let failures=0;
try{
 for(const width of [320,390]) for(const [name,file,field,cta] of cases){
  const ctx=await browser.newContext({viewport:{width,height:420},serviceWorkers:'block'});
  const page=await ctx.newPage();page.setDefaultTimeout(7000);
  try{
   const state=fixture(file);
   await page.route('**/*',r=>new URL(r.request().url()).origin===new URL(BASE).origin?r.continue():r.abort());
   await setup(page,{...duo,notifications:[],state});
   await page.route('**/rpc/get_session_state',r=>r.fulfill({json:state}));
   await page.goto(`${BASE}/partie/${SESSION}`);
   const input=field(page);await input.focus();await input.fill('Test');await page.waitForTimeout(400);
   const inView=async loc=>{const b=await loc.boundingBox();return b&&b.y>=0&&b.y+b.height<=420;};
   assert.ok(await inView(input),'champ actif visible');
   if(cta){const btn=page.getByRole('button',{name:cta}).first();await btn.scrollIntoViewIfNeeded();assert.ok(await inView(btn),`« ${cta} » visible`);
    const b=await btn.boundingBox();const hit=await page.evaluate(([x,y])=>{const el=document.elementFromPoint(x,y);return el?el.closest('button')?.textContent??el.className:'';},[b.x+b.width/2,b.y+b.height/2]);
    assert.ok(String(hit).includes(cta),`« ${cta} » non recouvert (trouvé : ${hit})`);}
   const over=await page.evaluate(()=>document.documentElement.scrollWidth-innerWidth);assert.ok(over<=0,`débordement ${over}px`);
   await page.screenshot({path:`${OUT}/${width}x420-clavier-${name}.png`});
   console.log(`PASS clavier ${name} ${width}px`);
  }catch(e){failures++;console.error(`FAIL clavier ${name} ${width}px : ${e.message}`);await page.screenshot({path:`${OUT}/${width}x420-clavier-${name}-ECHEC.png`}).catch(()=>{});}
  finally{await ctx.close();}
 }
}finally{await browser.close();}
if(failures)process.exitCode=1;
