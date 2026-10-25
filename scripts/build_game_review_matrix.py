"""Construit une matrice de couverture depuis les fixtures et journaux réels, sans serveur."""
import json,re,csv,argparse
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--logs',default='/tmp');ap.add_argument('--lifecycle',default='test-results/game-matrix/lifecycle.json');args=ap.parse_args()
root=Path(__file__).resolve().parents[1];fix=root/'tests/visual/fixtures';cases=json.loads((root/'tests/visual/game-review-cases.json').read_text());life=json.loads(Path(args.lifecycle).read_text());lmap={(x['scope'],x['id'],x['mechanic']):x for x in life}
# Les tests et packs du catalogue restent explicitement hors de cette passe de jeux.
for line in (root/'docs/INVENTAIRE_VISUEL_PETROLE.md').read_text().splitlines():
 if not line.startswith('| ') or 'ND-Q-' not in line:continue
 cells=[s.strip() for s in line.split('|')[1:-1]]
 cases.append({'scope':'catalogue — hors lot jeux','id':cells[0],'title':cells[1],'mechanic':cells[2],'fixture':None})
evidence={};logs=['game-audit-320','game-audit-390','game-history-rounds','game-fixes','game-progress','game-final-200','game-delivery','logo-lobbies']
for name in logs:
 path=Path(args.logs)/('noodeu-'+name+'.log')
 if not path.exists():continue
 for line in path.read_text().splitlines():
  m=re.search(r' (\d\d-[^:]+): débordement=(\d+)px .*erreurs=(\d+)',line)
  if not m:continue
  screen=m[1];fname=None
  if screen.startswith('60-'):fname='c14-'+screen[3:]+'.json'
  elif screen.startswith(('50-','51-')):fname=screen[3:].rsplit('-',1)[0]+('-play.json' if screen.startswith('50-') else '-reveal.json')
  elif screen.startswith('53-'):
   for suffix,code in [('manche-finie','b2'),('debut','b0'),('coup','b1'),('fin','b3')]:
    if screen.endswith('-'+suffix):fname=screen[3:-len(suffix)-1]+'-'+code+'.json';break
  if not fname or not (fix/fname).exists():continue
  state=json.loads((fix/fname).read_text());key=('actuel' if fname.startswith('c14-') else 'historique',state['session']['game_id'],state['game']['mechanic']);status=state['session']['status'];current=next((r for r in state['rounds'] if r['round_no']==state['session']['current_round']),{})
  category='salon' if status=='lobby' else 'résultats' if status in ['ended','closed'] else 'révélation' if current.get('revealed') or current.get('card',{}).get('done') else 'jeu'
  ev=evidence.setdefault(key,{}).setdefault(category,[]);ev.append({'log':name,'screen':screen,'fixture':fname,'ok':m[2]=='0' and m[3]=='0' and 'masqué-sous-nav=true' not in line,'petites_cibles':'petites-cibles=' in line})
rows=[]
for case in cases:
 key=(case['scope'],case['id'],case['mechanic']);ev=evidence.get(key,{});lc=lmap.get(key);row={'périmètre':case['scope'],'id':case['id'],'jeu':case['title'],'mécanique':case['mechanic'],'chargement':'Commun testé lot2 ; pas ralenti individuellement'}
 modes=set()
 if case.get('fixture'):
  st=json.loads((fix/case['fixture']).read_text());cfg=st['game']['config'];modes.add(str(cfg.get('turn',cfg.get('engine','non précisé'))))
 for values in ev.values():
  for item in values:
   st=json.loads((fix/item['fixture']).read_text());r=next((r for r in st['rounds'] if r['round_no']==st['session']['current_round']),{});phase=r.get('card',{}).get('phase')
   if phase:modes.add(str(phase))
 row['modes/phases observés']=' / '.join(sorted(modes)) or 'Hors lot'
 for state in ['salon','jeu','révélation','résultats']:
  e=ev.get(state,[]);row[state]=(str(len(e))+' rendus réussis' if e and all(x['ok'] for x in e) else 'ÉCHEC rendu' if e else 'NON TESTÉ dans ces journaux')
 row['erreurs']= 'Refus abandon testé ; coups spécifiques : voir rapport' if lc else 'NON TESTÉ dans ce lot'
 row['reconnexion']= 'Simulation hors-ligne/retour réussie' if lc and lc['lifecycle']=='réussi' else 'NON TESTÉ'
 row['quitter']= 'Annuler, refus, double clic, Échap réussis' if lc and lc['lifecycle']=='réussi' else 'NON TESTÉ'
 row['sources']=' ; '.join(sorted({x['fixture'] for v in ev.values() for x in v}) or ([case['fixture']] if case.get('fixture') else []))
 row['limites']='Fixtures Chromium ; pas de partie multi-appareils ni natif. Métier exhaustif NON TESTÉ.'
 rows.append(row)
out=root/'docs';headers=list(rows[0]);
with (out/'MATRICE_JEUX_LOT3.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=headers);w.writeheader();w.writerows(rows)
md='# Matrice des jeux et états — lot3\n\nSources : fixtures versionnées, journaux de captures et 88 scénarios de cycle de vie. Chaque ligne distingue ID ET mécanique : certains IDs historiques ont été réaffectés. Les jeux historiques ne sont pas réintroduits au catalogue.\n\n« Rendu réussi » signifie absence de débordement et d’erreur JavaScript, pas validation de tous les coups. Les petites cibles détectées de N2-035 ont été corrigées et retestées strictement. Les contrôles partagés loading/reconnect/quit ne prouvent pas une synchronisation réelle. Les tests et packs sont listés comme hors lot, sans prétendre leur couverture.\n\n'
for scope in ['actuel','historique','catalogue — hors lot jeux']:
 md+='## '+scope+'\n\n| Jeu / mécanique | Salon | Jeu | Révélation | Résultats | Erreur / réseau / quitter |\n|---|---|---|---|---|---|\n'
 for row in rows:
  if row['périmètre']!=scope:continue
  md+='| '+row['id']+' · '+row['jeu']+' (`'+row['mécanique']+'`) | '+' | '.join(row[k] for k in ['salon','jeu','révélation','résultats'])+' | '+('Cycle commun réussi ; coups non exhaustifs' if row['quitter'].startswith('Annuler') else 'Non testé dans ce lot')+' |\n'
md+='\nLe CSV fournit les fichiers source et limites par ligne. La couverture du lot précédent reste dans LOT2_CERISE_AUTH_SALON.md. Aucun ordre/scoring de test standardisé modifié.\n'
(out/'MATRICE_JEUX_LOT3.md').write_text(md)
(out/'MATRICE_JEUX_LOT3_EVIDENCE.json').write_text(json.dumps({'rows':rows,'captures':{str(k):v for k,v in evidence.items()}},ensure_ascii=False,indent=2))
print(len(rows),'lignes ;',len(life),'cycles ;',sum(len(v) for d in evidence.values() for v in d.values()),'rendus corrélés')
