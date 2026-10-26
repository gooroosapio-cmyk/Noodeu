import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
process.env.NOODEU_FIXTURES_ONLY='1';
const {setup,duo,SESSION}=await import('./render-check.mjs');
const browser=await chromium.launch({executablePath:'/usr/bin/chromium'});
const BASE=process.env.BASE??'http://localhost:4176';
async function make(name,width=320){const ctx=await browser.newContext({viewport:{width,height:844},serviceWorkers:'block'});const page=await ctx.newPage();const state=JSON.parse(readFileSync(new URL(`./fixtures/c14-${name}.json`,import.meta.url),'utf8'));await setup(page,{...duo,notifications:[],state});await page.goto(`${BASE}/partie/${SESSION}`);return {page,ctx};}
try{
 {const {page,ctx}=await make('mini-points-jeu');await page.getByRole('button',{name:'Plateau entier'}).waitFor();
  const sizes=await page.locator('.dots__edge').evaluateAll(xs=>xs.map(x=>{const r=x.getBoundingClientRect();return [r.width,r.height];}));assert.ok(sizes.length && sizes.every(([w,h])=>w>=44&&h>=44));
  await page.getByRole('button',{name:'Plateau entier'}).click();assert.ok(await page.locator('.dots').evaluate(x=>Boolean(x.closest('[inert]'))));await ctx.close();console.log('PASS points : 44px dès ouverture, aperçu compact non interactif');}
 {const {page,ctx}=await make('mini-naval-placement');await page.getByRole('gridcell',{name:/^J10/}).click();await page.getByText('Ce navire dépasse de la grille. Choisis une autre case ou tourne-le.').waitFor();await ctx.close();console.log('PASS naval : placement hors grille expliqué sans sauvegarde');}
 {const {page,ctx}=await make('mot-pendu-devineur');await page.locator('.hm-key').first().waitFor();const widths=await page.locator('.hm-key').evaluateAll(xs=>xs.map(x=>x.getBoundingClientRect().width));assert.ok(widths.every(w=>w>=44));await ctx.close();console.log('PASS pendu : toutes les lettres >=44px à320px');}
 {const {page,ctx}=await make('mini-de-jeu');await page.locator('.pig-actions').waitFor();const sizes=await page.locator('.pig-actions .btn').evaluateAll(xs=>xs.map(x=>x.getBoundingClientRect().height));assert.equal(sizes[0],sizes[1]);await ctx.close();console.log('PASS dé : actions de même hauteur, seuil30 conservé');}
}finally{await browser.close();}
