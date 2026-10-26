process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo}=await import('./render-check.mjs');
const {chromium}=await import('@playwright/test');
const assert=(value,message)=>{if(!value)throw Error(message);console.log('PASS '+message)};
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const context=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});
const page=await context.newPage();await setup(page,duo);await page.clock.install();
let calls=0, fail=false, empty=false;
await page.route('**/rest/v1/game_sessions?*',async route=>{
 const url=new URL(route.request().url());
 if(url.searchParams.has('couple_id')) {
  assert(url.searchParams.get('couple_id')==='eq.44444444-4444-4444-8444-444444444444','fallback filtré sur le duo');
  assert(url.searchParams.get('status')==='in.(ended,closed)','fallback limité aux parties terminées');
 }
 await route.fulfill({json:[]});
});
await page.route('**/rpc/get_home_moment',async route=>{calls++; await route.fulfill({json:fail?{ok:false,error:'network'}:{ok:true,question:empty?null:`Question originale ${calls}`,games_played:0,server_now:'2026-10-25T22:59:59Z',expires_at:'2026-10-25T23:00:00Z'}})});
await page.goto(`${process.env.BASE ?? 'http://127.0.0.1:4193'}/accueil`);await page.getByText('Question originale 1',{exact:true}).waitFor();
await page.clock.runFor(1200);await page.getByText('Question originale 2',{exact:true}).waitFor();assert(calls===2,'renouvellement à échéance serveur');
fail=true;await page.evaluate(()=>window.dispatchEvent(new Event('online')));await page.getByRole('button',{name:'Réessayer',exact:true}).waitFor();assert(await page.getByText('Question originale 2',{exact:true}).count()===0,'pas de question périmée présentée comme courante');
assert(await page.locator('.arcade-progress').innerText().then(t=>t.includes('0 jeux terminés')),'compteur existant disponible sans RPC horaire');
fail=false;empty=true;await page.getByRole('button',{name:'Réessayer',exact:true}).click();await page.getByText('Question indisponible pour le moment.').waitFor();assert(true,'banque vide lisible');
empty=false;await page.evaluate(()=>document.dispatchEvent(new Event('visibilitychange')));await page.getByText(/Question originale/).waitFor();assert(true,'retour foreground recharge');
await page.emulateMedia({reducedMotion:'reduce'});await page.getByRole('button',{name:'Jeu suivant',exact:true}).click();await page.waitForFunction(()=>document.querySelector('.arcade-carousel').scrollLeft>0);assert(await page.locator('.arcade-carousel').evaluate(e=>e.scrollLeft)>0,'navigation carrousel');
await page.getByRole('button',{name:'5 minutes',exact:true}).click();assert(await page.getByRole('button',{name:'5 minutes',exact:true}).getAttribute('aria-pressed')==='true','filtre cinq minutes');
await page.getByRole('button',{name:'Surprise',exact:true}).focus();await page.keyboard.press('Enter');assert(await page.getByRole('button',{name:'5 minutes',exact:true}).getAttribute('aria-pressed')==='false','navigation clavier et surprise');
await page.emulateMedia({reducedMotion:'reduce'});assert(await page.locator('.arcade-feature').first().evaluate(e=>getComputedStyle(e).animationName)==='none','reduced motion');
await browser.close();
