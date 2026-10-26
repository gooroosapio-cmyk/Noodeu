process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,SESSION}=await import('./render-check.mjs');
const {chromium}=await import('@playwright/test');
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
for(const width of [320,390,430]){
 const context=await browser.newContext({viewport:{width,height:780},reducedMotion:'reduce',serviceWorkers:'block'});const page=await context.newPage();
 await setup(page,{...duo,open:{id:SESSION,game_id:'ND-G-G03',status:'playing',title:'Tu préfères'}});
 await page.goto(`${process.env.BASE ?? 'http://127.0.0.1:4193'}/accueil`);await page.getByText('Question du moment').waitFor();
 for(const ratio of [0,.25,.5,.75,1]){
  await page.locator('main').evaluate((e,r)=>e.scrollTop=(e.scrollHeight-e.clientHeight)*r,ratio);
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  const collision=await page.evaluate(()=>{const b=document.querySelector('.chat-launcher').getBoundingClientRect();return [...document.querySelectorAll('main a,main button')].filter(e=>{const r=e.getBoundingClientRect();return r.width&&r.height&&Math.min(b.right,r.right)>Math.max(b.left,r.left)&&Math.min(b.bottom,r.bottom)>Math.max(b.top,r.top)}).map(e=>e.textContent)});
  if(collision.length)throw Error(`${width}/${ratio}: ${collision}`);
 }
 console.log(`PASS ${width}: bulle sans chevauchement des contrôles sur cinq positions`);
 await page.locator('.chat-launcher').click();await page.getByRole('dialog').waitFor();
 if(await page.locator('.chat-launcher').isVisible())throw Error('chat au-dessus modal');
 console.log(`PASS ${width}: modal devant la bulle`);await context.close();
}
await browser.close();
