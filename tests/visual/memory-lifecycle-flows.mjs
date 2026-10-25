import {chromium} from '@playwright/test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY='1';const {setup,duo,SESSION}=await import('./render-check.mjs');const BASE=process.env.BASE??'http://localhost:4183';const browser=await chromium.launch({executablePath:'/usr/bin/chromium'});
try{for(const gid of ['N2-052','N2-053']){
 const ctx=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});const page=await ctx.newPage();const state=JSON.parse(readFileSync(new URL(`./fixtures/${gid}-b0.json`,import.meta.url)));await setup(page,{...duo,state,notifications:[]});
 await page.addInitScript(()=>{window.__tones=0;const Original=window.AudioContext;window.AudioContext=class extends Original{constructor(...args){super(...args);window.__tones++;}};});
 await page.goto(`${BASE}/partie/${SESSION}`);
 if(gid==='N2-052'){await page.getByRole('checkbox',{name:'Son',exact:true}).check();await page.getByRole('button',{name:'Revoir la suite',exact:true}).click();}
 else await page.getByRole('button',{name:'Écouter',exact:true}).click();
 await page.waitForFunction(()=>window.__tones>0);await page.getByRole('link',{name:'Retour',exact:true}).click();const count=await page.evaluate(()=>window.__tones);await page.waitForTimeout(1600);assert.equal(await page.evaluate(()=>window.__tones),count);await ctx.close();console.log(`PASS ${gid} : lecture sonore au clic, aucun nouveau son après sortie`);
}
 const ctx=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block',reducedMotion:'reduce'});const page=await ctx.newPage();const state=JSON.parse(readFileSync(new URL('./fixtures/N2-052-b0.json',import.meta.url)));await setup(page,{...duo,state,notifications:[]});await page.goto(`${BASE}/partie/${SESSION}`);await page.locator('.simon').waitFor();assert.ok(await page.locator('ol li').count()>0);assert.equal(await page.locator('.simon-btn--lit').count(),0);await ctx.close();console.log('PASS Simon : séquence textuelle et aucun flash en reduced-motion');
}finally{await browser.close();}
