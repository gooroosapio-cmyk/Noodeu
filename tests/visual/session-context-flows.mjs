// Vrais hooks React, RPC/canaux/horloges simulés. Aucun serveur ni appel réseau nécessaire.
// Exécution : node tests/visual/session-context-flows.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { createRequire } from 'node:module';
import ts from 'typescript';
import { chromium } from '@playwright/test';

const require = createRequire(import.meta.url);
const modules = {
  react: ['react', 'cjs/react.development.js'],
  scheduler: ['scheduler', 'cjs/scheduler.development.js'],
  'react-dom': ['react-dom', 'cjs/react-dom.development.js'],
  'react-dom/client': ['react-dom', 'cjs/react-dom-client.development.js'],
};
const definitions = Object.entries(modules).map(([name, [pkg, file]]) => `${JSON.stringify(name)}: function(require,module,exports){\n${readFileSync(join(dirname(require.resolve(pkg)), file), 'utf8')}\n}`).join(',');
const source = readFileSync(new URL('../../src/game/useSession.ts', import.meta.url), 'utf8');
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM ?? '/usr/bin/chromium' });
let passes = 0;

async function scenario(name, verify) {
  const page = await browser.newPage();
  await page.route('**/*', route => route.abort());
  await page.setContent('<div id="root"></div>');
  await page.addScriptTag({ content: `
    const process={env:{NODE_ENV:'development'}};
    const definitions={${definitions}}, modules={};
    function require(name){if(modules[name])return modules[name].exports;const module={exports:{}};modules[name]=module;definitions[name](require,module,module.exports);return module.exports;}
    const React=require('react'), ReactDOM=require('react-dom/client');
    window.calls=[]; window.timers=new Map(); window.subscriptions=[]; window.resumes=[]; window.done=[];
    let timerId=0;
    const timer=(fn,ms)=>{const id=++timerId;timers.set(id,{fn,ms});return id;};
    const clear=id=>timers.delete(id);
    modules['../lib/supabase']={exports:{rpc:(fn,args)=>new Promise(resolve=>calls.push({fn,args,resolve,pending:true}))}};
    modules['../lib/realtime']={exports:{subscribePrivate:(topic,opts)=>{const sub={topic,opts,active:true};subscriptions.push(sub);opts.onStatus('connecting');return ()=>{sub.active=false;};}}};
    modules['../lib/useOnline']={exports:{onResume:callback=>{const sub={callback,active:true};resumes.push(sub);return ()=>{sub.active=false;};}}};
    const hookModule={exports:{}};
    (function(require,module,exports,setTimeout,clearTimeout,setInterval,clearInterval){${compiled}})(require,hookModule,hookModule.exports,timer,clear,timer,clear);
    window.view=null;
    function Probe({id,user}){window.view=hookModule.exports.useSession(id,user);return React.createElement('div',null,view.loading?'loading':view.state?.session.id??'empty');}
    const reactRoot=ReactDOM.createRoot(document.getElementById('root'));
    window.IS_REACT_ACT_ENVIRONMENT=true;
    window.render=(id,user='user')=>React.act(()=>reactRoot.render(React.createElement(Probe,{id,user})));
    window.unmount=()=>React.act(()=>reactRoot.unmount());
    window.emitStatus=(s,index=subscriptions.length-1)=>React.act(()=>subscriptions[index].opts.onStatus(s));
    window.presence=(keys,index=subscriptions.length-1)=>React.act(()=>subscriptions[index].opts.onPresence(keys));
    window.broadcast=(v,index=subscriptions.length-1)=>React.act(()=>subscriptions[index].opts.broadcast.state({v}));
    window.finish=(index,version=1,error=null)=>React.act(async()=>{
      const call=calls[index];call.pending=false;
      call.resolve(error?{ok:false,error}:{ok:true,session:{id:call.args.p_session,state_version:version}});
      await Promise.resolve();
    });
    window.reload=name=>React.act(()=>{view.load().then(()=>done.push(name));});
    window.action=name=>React.act(()=>{view.act('move',{}).then(res=>done.push({name,...res}));});
    window.poll=()=>React.act(()=>{const [id,t]=[...timers.entries()].at(-1);timers.delete(id);t.fn();});
    window.inspect=()=>({
      calls:calls.map(c=>({fn:c.fn,id:c.args.p_session,pending:c.pending})),
      state:view.state?.session??null,loading:view.loading,error:view.error,channel:view.channel,
      present:view.present,recoveryEpoch:view.recoveryEpoch,done:[...done],timers:[...timers.values()].map(t=>t.ms),
    });
  ` });
  try {
    await verify(page);
    passes += 1;
    console.log(`PASS ${name}`);
  } finally { await page.close(); }
}

try {
  await scenario('A → B : la lecture de B démarre sans attendre A ; aucun rappel ne relit A', async page => {
    await page.evaluate(() => render('A'));
    await page.evaluate(() => render('B'));
    assert.deepEqual(await page.evaluate(() => calls.map(c => c.args.p_session)), ['A', 'B']);
    await page.evaluate(() => emitStatus('live'));
    await page.evaluate(() => finish(0, 99));
    assert.deepEqual(await page.evaluate(() => calls.map(c => c.args.p_session)), ['A', 'B']);
    await page.evaluate(() => finish(1));
    assert.equal(await page.evaluate(() => view.state?.session.id), 'B');
    assert.deepEqual(await page.evaluate(() => calls.map(c => c.args.p_session)), ['A', 'B', 'B']);
    await page.evaluate(() => finish(2, 2));
    assert.equal(await page.evaluate(() => view.state.session.state_version), 2);
  });

  await scenario('rafales : une lecture en vol, une suivante ; les premiers appelants terminent sans attendre les suivants', async page => {
    await page.evaluate(() => render('A'));
    await page.evaluate(() => { for (let i = 0; i < 20; i++) reload('first-' + i); });
    assert.equal(await page.evaluate(() => calls.length), 1);
    await page.evaluate(() => finish(0));
    assert.equal(await page.evaluate(() => calls.length), 2);
    await page.evaluate(() => { for (let i = 0; i < 20; i++) reload('second-' + i); });
    assert.equal(await page.evaluate(() => calls.filter(c => c.pending).length), 1);
    await page.evaluate(() => finish(1, 2));
    assert.equal(await page.evaluate(() => done.filter(n => n.startsWith('first-')).length), 20);
    assert.equal(await page.evaluate(() => done.filter(n => n.startsWith('second-')).length), 0);
    assert.equal(await page.evaluate(() => calls.length), 3);
    assert.equal(await page.evaluate(() => calls.filter(c => c.pending).length), 1);
    await page.evaluate(() => finish(2, 3));
    assert.equal(await page.evaluate(() => done.length), 40);
  });

  await scenario('changement de compte : réponse/version/présence/statut anciens sans effet', async page => {
    await page.evaluate(() => render('A', 'first-account'));
    await page.evaluate(() => render('A', 'second-account'));
    assert.equal(await page.evaluate(() => calls.length), 2);
    await page.evaluate(() => finish(1, 1));
    await page.evaluate(() => finish(0, 99));
    await page.evaluate(() => { presence(['old-user'], 0); emitStatus('down', 0); broadcast(100, 0); });
    const result = await page.evaluate(() => inspect());
    assert.equal(result.state.state_version, 1);
    assert.deepEqual(result.present, []);
    assert.equal(result.channel, 'connecting');
    assert.equal(result.error, null);
    assert.equal(result.calls.length, 2);
    await page.evaluate(() => broadcast(2));
    assert.equal(await page.evaluate(() => calls.length), 3);
  });

  await scenario('callback de fin : une nouvelle demande ne vole pas la lecture déjà promise au lot suivant', async page => {
    await page.evaluate(() => render('A'));
    await page.evaluate(() => finish(0));
    await page.evaluate(() => {
      view.load().then(() => { view.load().then(() => done.push('after-first')); });
      reload('already-queued');
    });
    await page.evaluate(() => finish(1, 2));
    assert.equal(await page.evaluate(() => calls.length), 3);
    await page.evaluate(() => finish(2, 3));
    assert.equal(await page.evaluate(() => done.includes('already-queued')), true);
    assert.equal(await page.evaluate(() => calls.filter(c => c.pending).length), 1);
    await page.evaluate(() => finish(3, 4));
    assert.equal(await page.evaluate(() => done.includes('after-first')), true);
  });

  await scenario('A → B → A : l’ancienne génération A ne remplace pas le nouveau snapshot', async page => {
    await page.evaluate(() => render('A'));
    await page.evaluate(() => render('B'));
    await page.evaluate(() => render('A'));
    await page.evaluate(() => finish(2, 1));
    await page.evaluate(() => finish(0, 99));
    await page.evaluate(() => finish(1, 99));
    assert.equal(await page.evaluate(() => view.state.session.state_version), 1);
    assert.equal(await page.evaluate(() => calls.length), 3);
  });

  await scenario('démontage : réponses, file, timer et callbacks tardifs ne relancent aucune lecture', async page => {
    await page.evaluate(() => render('A'));
    await page.evaluate(() => reload('queued'));
    await page.evaluate(() => { window.oldPoll = [...timers.values()][0].fn; window.oldView = view; });
    await page.evaluate(() => unmount());
    assert.equal(await page.evaluate(() => done.includes('queued')), true, 'Quitter libère la promesse sans attendre le réseau ancien');
    assert.equal(await page.evaluate(() => calls[0].pending), true);
    await page.evaluate(() => finish(0));
    await page.evaluate(() => { oldPoll(); resumes[0].callback(); emitStatus('live', 0); broadcast(2, 0); });
    assert.equal(await page.evaluate(() => calls.length), 1);
    assert.equal(await page.evaluate(() => timers.size), 0);
    const staleAction = await page.evaluate(() => oldView.act('move', {}));
    assert.deepEqual(staleAction, { ok: false, error: 'stale_session' });
    assert.equal(await page.evaluate(() => calls.length), 1);
  });

  await scenario('ancienne action en échec après navigation : aucune pollution de la récupération de B', async page => {
    await page.evaluate(() => render('A'));
    await page.evaluate(() => finish(0));
    await page.evaluate(() => action('old-action'));
    await page.evaluate(() => render('B'));
    await page.evaluate(() => finish(1, 0, 'network'));
    await page.evaluate(() => finish(2, 1));
    const result = await page.evaluate(() => inspect());
    assert.equal(result.state.id, 'B');
    assert.equal(result.error, null);
    assert.equal(result.recoveryEpoch, 0);
    assert.equal(result.calls.length, 3);
  });

  await scenario('coupure pendant une lecture : snapshot antérieur ignoré, reprise marquée une seule fois', async page => {
    await page.evaluate(() => render('A'));
    await page.evaluate(() => finish(0, 4));
    await page.evaluate(() => emitStatus('live'));
    await page.evaluate(() => emitStatus('down'));
    await page.evaluate(() => reload('recovery'));
    await page.evaluate(() => finish(1, 5));
    assert.equal(await page.evaluate(() => view.state.session.state_version), 4);
    await page.evaluate(() => finish(2, 6));
    assert.equal(await page.evaluate(() => view.recoveryEpoch), 1);
    await page.evaluate(() => reload('normal'));
    await page.evaluate(() => finish(3, 7));
    assert.equal(await page.evaluate(() => view.recoveryEpoch), 1);
    await page.evaluate(() => reload('older'));
    await page.evaluate(() => finish(4, 3));
    assert.equal(await page.evaluate(() => view.state.session.state_version), 7);
  });

  await scenario('poll et reprise : ancien contexte annulé, cadence du contexte courant conservée', async page => {
    await page.evaluate(() => render('A'));
    await page.evaluate(() => { window.oldPoll = [...timers.values()][0].fn; });
    await page.evaluate(() => render('B'));
    await page.evaluate(() => { oldPoll(); resumes[0].callback(); });
    assert.equal(await page.evaluate(() => calls.length), 2);
    await page.evaluate(() => finish(1));
    await page.evaluate(() => emitStatus('live'));
    await page.evaluate(() => finish(2, 2));
    assert.deepEqual(await page.evaluate(() => [...timers.values()].map(t => t.ms)), [20000]);
    await page.evaluate(() => poll());
    assert.deepEqual(await page.evaluate(() => calls.map(c => c.args.p_session)), ['A', 'B', 'B', 'B']);
  });
  console.log(`${passes} scénarios useSession validés ; aucun appel serveur réel.`);
} finally {
  await browser.close();
}
