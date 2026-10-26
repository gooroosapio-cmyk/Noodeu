import assert from 'node:assert/strict';
import { test } from 'node:test';
import { draftKey, readChatDraft, restoreChatDraft, writeChatDraft } from './chatDraft.ts';

function storage() {
  const values = new Map<string,string>();
  Object.defineProperty(globalThis, 'sessionStorage', { configurable: true, value: {
    getItem: (key:string) => values.get(key) ?? null,
    setItem: (key:string,value:string) => values.set(key,value),
    removeItem: (key:string) => values.delete(key),
    clear: () => values.clear(),
  } });
  Object.defineProperty(globalThis, 'window', { configurable: true, value: new EventTarget() });
  return values;
}
test('un échec restaure seulement son duo et sa révision', () => {
  storage();
  const sent = writeChatDraft('AB', '', 'A');
  writeChatDraft('AC', 'Texte pour C', 'A');
  assert.equal(restoreChatDraft('AB', sent, 'Texte pour B', 'A'), true);
  assert.equal(readChatDraft('AB', 'A'), 'Texte pour B');
  assert.equal(readChatDraft('AC', 'A'), 'Texte pour C');
});
test('un échec ancien ne remplace ni nouvelle saisie ni nouveau brouillon vidé', () => {
  storage();
  const sent = writeChatDraft('AB', '', 'A');
  writeChatDraft('AB', 'Nouveau texte', 'A');
  assert.equal(restoreChatDraft('AB', sent, 'Ancien', 'A'), false);
  assert.equal(readChatDraft('AB', 'A'), 'Nouveau texte');
  writeChatDraft('AB', '', 'A');
  assert.equal(restoreChatDraft('AB', sent, 'Ancien', 'A'), false);
  assert.equal(readChatDraft('AB', 'A'), '');
});
test('nettoyage à la déconnexion : aucun ancien échec ne recrée les données', () => {
  const values=storage();const sent=writeChatDraft('AB', '', 'A');values.clear();
  assert.equal(restoreChatDraft('AB', sent, 'Ancien', 'A'), false);
  assert.equal(values.size,0);
});
test('un autre compte ne lit ni ne restaure le brouillon du même duo', () => {
  storage();const sent=writeChatDraft('AB', 'Privé A', 'A');
  assert.equal(readChatDraft('AB', 'B'),'');
  assert.equal(restoreChatDraft('AB',sent,'Privé A','B'),false);
  writeChatDraft('AB','Texte B','B');
  assert.equal(restoreChatDraft('AB',sent,'Privé A','A'),false);
  assert.equal(readChatDraft('AB','B'),'Texte B');
});
test('compatibilité lecture des anciennes clés et refus du contexte anonyme', () => {
  const values=storage();values.set(draftKey('AB'),'Brouillon historique');
  assert.equal(readChatDraft('AB','A'),'Brouillon historique');
  assert.equal(readChatDraft('AB',null),'');
});
test('stockage refusé : helpers sans exception ni restauration hasardeuse', () => {
  storage();Object.defineProperty(globalThis,'sessionStorage',{configurable:true,value:{getItem(){throw new Error('denied');},setItem(){throw new Error('denied');}}});
  assert.equal(readChatDraft('AB','A'),'');assert.equal(writeChatDraft('AB','Privé','A'),null);assert.equal(restoreChatDraft('AB','old','Privé','A'),false);
});
test('générateur de révision indisponible : aucun texte écrit partiellement', () => {
  const values=storage();const cryptoDescriptor=Object.getOwnPropertyDescriptor(globalThis,'crypto');
  try{Object.defineProperty(globalThis,'crypto',{configurable:true,value:{randomUUID(){throw new Error('unavailable');}}});assert.equal(writeChatDraft('AB','Privé','A'),null);assert.equal(values.size,0);}
  finally{if(cryptoDescriptor)Object.defineProperty(globalThis,'crypto',cryptoDescriptor);}
});
test('chaque écriture partielle A vers B reste privée, même si removeItem échoue', () => {
  for (const failAt of [1, 2, 3, 4]) {
    const values=storage();const previous=writeChatDraft('AB','Privé A','A');
    const original=sessionStorage.setItem;let writes=0;
    sessionStorage.setItem=(key,value)=>{writes++;if(writes===failAt)throw new Error('quota');original(key,value);};
    sessionStorage.removeItem=()=>{throw new Error('remove denied');};
    assert.equal(writeChatDraft('AB','Texte B','B'),null,`échec étape ${failAt}`);
    assert.equal(writes,failAt);
    assert.equal(readChatDraft('AB','B'),'');
    assert.equal(readChatDraft('AB','A'),failAt===1?'Privé A':'');
    if(failAt>1){
      assert.equal(values.get(`${draftKey('AB')}.owner`),'pending');
      assert.equal(restoreChatDraft('AB',previous,'Privé A','A'),false);
    }
  }
});
