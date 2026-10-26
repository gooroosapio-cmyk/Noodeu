# Clôture locale du lot serveur — 26 octobre 2026

Le lot est validé sur PostgreSQL Docker local : validation atomique des réglages,
preuves G08 renforcées, moteur M04 12 × 12 points préparé et garde-fous serveur.
La version M04 préparée reste **non publiée et non courante**. Le chemin public
continue à créer des parties historiques 5 × 5 points. Aucun déploiement distant
ni activation 12 × 12 ne fait partie de cette validation.

Base Git de la revue : `104564da4a7d8dc5761f9616d40d8f8a1ba5f658`.
Les fichiers du lot étaient non commités ; les empreintes de leur contenu relu
sont dans `SERVER_GUARDS_DOTS12_20261026_EVIDENCE.json`. Elles identifient la source
au moment de la clôture, et ne prétendent pas constituer une attestation signée
de chaque exécution antérieure. La reprise a relu les résultats déjà terminés ;
seul l'upgrade a été rejoué pour valider le nouveau lanceur et son inclusion SQL.

## Comportement livré

### Réglages — migration 009 et C30

`update_session_settings` verrouille et authentifie la séance, exige le salon,
puis valide **tout** le patch contre le schéma de la version figée de la séance.
SQL NULL, JSON null, types non objets, clé inconnue, options absentes/non tableaux
et valeur non autorisée retournent `invalid_settings`. Une clé invalide mêlée à
une clé valide refuse l'ensemble avant toute écriture. Les réglages, disponibilités,
préférences, manches et `state_version` sont comparés avant/après les refus.

L'égalité utilisée est l'égalité JSONB, sans containment de sous-objet : une chaîne
`"4"` n'est pas le nombre `4`, un objet incomplet n'est pas une option objet.
JSONB considère cependant `4.0` égal à `4` : le RPC stocke la **valeur déclarée
dans les options**, donc `4`, afin que le cast entier du démarrage reste valide.
Un patch `{"cartes":4}` répare aussi un ancien salon contenant `4.0`, avec un
incrément de version et remise à zéro des confirmations. Un patch inchangé ne
modifie rien ; un vrai changement incrémente une seule fois et fait reconfirmer
les deux sièges. G08 conserve son mode simultané et ses options 4/6/10.

C30 vérifie les trois démarrages, les options texte/booléennes/objets, la version
figée malgré une nouvelle version publiée, les tiers, l'état hors salon et un jeu
sans réglages. C32 vérifie aussi le vrai rôle `authenticated`, le refus anonyme
par ACL et l'absence de mutation après refus. Il n'y a pas de nettoyage massif
des anciens réglages : les autres clés héritées restent telles quelles jusqu'à
un traitement explicite ; la canonisation s'applique aux clés du patch valide.

### G08 — C19 et concurrence

C19 exige désormais la réponse exacte `session_not_found` pour un tiers. Son
ancien `EXCEPTION WHEN OTHERS THEN NULL` pouvait avaler l'échec de sa propre
assertion. Les assertions couvrent aussi la suppression du secret après reprise,
les parts privées exactes de chaque siège et la devinette scellée avant révélation.
Le test séquentiel C19 et les courses intertransactions sont des preuves distinctes.

Le harnais `tests/sql/server_concurrency.py` a terminé quatre courses : deux
publications G08, deux devinettes G08, deux appels M04 avec le même action ID,
puis deux action IDs distincts sur le même segment. Chaque course observe deux
PID distincts simultanément en `wait_event_type=Lock`, leur requête balisée et une
chaîne `pg_blocking_pids` remontant au coordinateur. Le verrou est ensuite conservé
deux secondes avant libération. Les vues de chaque siège sont lues dans la
transaction du worker avant son commit ; les phases intermédiaires et finales
sont vérifiées. Lancer simplement deux threads ne suffit pas à faire passer ce test.

Les deux publications et les deux secrets subsistent ; les choix restent privés
avant révélation ; quatre rejeux exacts n'ont aucun second effet. Pour M04, une
seule action modifie le segment, la révision, `state_version` et le journal.
Le doublon exact répond `repeated:true` ; l'autre action est refusée. Le duo témoin
C–D, sa partie historique et le catalogue sont identiques avant/après.

### M04 — migration 010, C31, C32 et upgrade

Le draft `noodeu-m04-2.0.0` porte le contrat `dots12-v1` : **12 × 12 points,
11 × 11 cases, 121 cases et 264 segments**. C31 couvre tous les segments et leurs
adjacences, les index jusqu'à 120, les payloads invalides sans mutation, les tours,
la fermeture simple/double, le rejeu après capture et les scores autoritaires.
Une partie de 264 appels RPC vérifie après chaque coup que le score correspond
aux propriétaires ; la fin totalise 121 points sans égalité.

Les signatures historiques de géométrie restent présentes. L'aiguillage 12 points
requiert le mécanisme et les dimensions attendus ; les cartes historiques sans
dimensions conservent 16 cases. Les fonctions globales d'application, de robot,
d'aiguillage et d'autoplay sont remplacées par 010 : un draft inactif ne dispense
donc pas des vérifications de non-régression de ces fonctions.

C31 exerce un robot réel sur une chaîne préparée de 121 captures. C32 remplace
temporairement `bot_step` pour mesurer séparément le plafond exact 264 pour Dots12,
40 pour le format historique et 40 pour un autre mécanisme ayant les mêmes
dimensions. Une exception réelle au troisième appel prouve l'annulation du travail
du robot et la restauration des deux GUC d'identité humaine. Cette instrumentation
ne prétend pas retester l'intelligence du robot. Les six signatures privées sont
inaccessibles à `anon` et `authenticated`, vérifiées par ACL et appels réels.

`supabase/tests/upgrade/dots12_from_008.sql` crée une partie5 déjà jouée et un salon5
**avant** 010, prend des snapshots complets, inclut 010 dans la transaction et
compare séances, cartes, secrets, journal, catalogue et versions publiées. La
partie continue par RPC, reconnaît l'action prémigration et refuse la géométrie12 ;
le salon prémigration démarre encore en5. Le rollback final est contrôlé : aucune
fixture, aucun schéma de test, aucun draft12 ni fonction `db_setup12` ne subsiste.
Ce test reste hors du glob des tests exécutés après010, car il exige son absence.

## Exécutions et preuves

Dossier principal : `/workspace/noodeu-server-validation-20261026/`.
Conteneur fixé : `noodeu-refonte-test-20261025`, PostgreSQL 16.
Base témoin008 : `noodeu_server_20261026_010539`.
Base intégrée009/010 : `noodeu_server_20261026_010539_integrated`.
Toutes les cibles dédiées sont marquées `noodeu:disposable-local-sql-test`.

| Preuve | Résultat constaté | Journal |
| --- | --- | --- |
| Baseline par étapes historiques | 6 slices anciennes, 7 fichiers C14–C17 au bon étage, puis 10 fichiers C18–C27 réussis ; premier C28 refusé par sa garde de nom | `baseline-results.json` |
| Garde C28/C29 adaptée au nouveau nom jetable marqué | Arbitrage, latence et payload naval réussis après correction | `c28_*.sql.log`, `c29_naval_payload_validation.sql.log` |
| Suite intégrée après009/010 | **16 fichiers C18–C32, tous exit 0** ; C28 a deux fichiers | `integrated-results.json`, `integrated-*.log` |
| Concurrence réelle | **4 courses, `ok:true`**, run `39a0c23f-8f3a-4d1c-ae16-a33b44ed2865` | `server-concurrency.log` |
| Comparaison baseline008 / clone010 | **92 versions publiées et tous les pointeurs identiques**, seul ajout : draft N2-079 version2 non publié ; aucun résidu C31 | `dots-baseline-comparison.log` |
| Réapplication010 locale | Pas de deuxième draft ; garde non publiée/non courante conservée | `dots-migration010-reapply.log`, `dots-gate.log` |
| Upgrade008→010 transactionnel | Compatibilité des données et RPC, rollback intégral vérifié | `dots-upgrade-versioned.log` |
| Nouveau lanceur, phase upgrade | Réexécution ciblée exit0, `ok:true`, SQL inclus empreinté ; pas de migration persistée | `closeout-runner-upgrade-results.json`, `closeout-runner-upgrade.log` |

Ces comptes portent sur des fichiers et courses, pas sur un nombre inventé
d'assertions. Les temps C28 sont des mesures PostgreSQL locales ; ils ne prédisent
pas la latence réseau ou de production. C14/C17 ne sont pas annoncés passés sur
le schéma courant après suppression de leurs anciennes préconditions.

## Échecs conservés et corrections prouvées

- Le premier passage baseline s'arrête à C28, exit3 : la garde ne reconnaissait
  que `noodeu_lot6_clean_2154` et `noodeu`. L'ajout accepte le préfixe dédié **et**
  le marqueur obligatoire ; les deux C28 et C29 ont ensuite réussi. Le résultat
  initial reste un échec dans `baseline-results.json`, même si les journaux
  individuels ont été remplacés par la réexécution réussie.
- Mutation volontaire du contrôle tiers : l'ancien C19 termine à tort avec exit0,
  le nouveau échoue comme attendu avec exit3 sur l'assertion exacte. Voir
  `mutation-results.json`, `mutation-c19-old.log`, `mutation-c19-fixed.log`.
- C30 contre l'ancien validateur échoue dès SQL NULL, accepté à tort avec
  `{"ok":true}`. Voir `mutation-c30-old-validator.log`. C30 avec009 réussit,
  notamment pour `4.0`, les inconnus mêlés à un réglage valide et les snapshots
  sans mutation. Cette mutation s'arrête au premier défaut et ne prouve pas
  isolément que chaque autre cas aurait échoué contre l'ancienne fonction.
- Vérification CLI du nouveau lanceur : le nom générique `noodeu` est refusé
  avant Docker (exit2 attendu) ; la liste de suite contient bien 16 fichiers.
  Les deux scripts Python compilent. Aucun échec inattendu n'est laissé ouvert.

## Reproduction locale sans recréer de base

`tests/sql/server_regression.py` réutilise les protections de connexion du harnais :
contexte Docker `default` explicitement inspecté en Unix, conteneur fixé, psql par
socket Unix, nom `noodeu_server_*`, marqueur vérifié avant chaque test, délais de
statement/verrou et `ON_ERROR_STOP`. Les variables Docker qui pourraient rediriger
le daemon sont retirées. Les journaux et empreintes sont écrits dans un répertoire
temporaire neuf. Il ne crée ni ne supprime de base, n'applique aucune migration
persistante et ne lance pas les courses automatiquement.

Depuis la racine du dépôt, sur les bases dédiées existantes :

```sh
python3 tests/sql/server_regression.py noodeu_server_20261026_010539_integrated suite --list
python3 tests/sql/server_regression.py noodeu_server_20261026_010539_integrated suite
python3 tests/sql/server_regression.py noodeu_server_20261026_010539 upgrade
python3 tests/sql/server_concurrency.py noodeu_server_20261026_010539_integrated
```

La branche `upgrade` du nouveau lanceur a été exécutée de bout en bout ; la branche
`suite` a été compilée et sa sélection contrôlée, sans répéter les 16 tests déjà
validés par la campagne intégrée. Le SQL upgrade inclut uniquement la migration010
connue, dans la transaction annulée. Il refuse une base déjà migrée010.

Ne pas utiliser `scripts/run_sql_tests.sh` pour cette reprise : ce script historique
supprime/recrée la base générique `noodeu`. Les garde-fous historiques de C28/C29
gardent leurs deux anciens noms autorisés pour compatibilité ; ce sont les
lanceurs dédiés qui imposent la cible locale marquée. C30 seul n'atteste pas sa
cible : il doit également passer par cette connexion contrôlée.

Les tests SQL sont transactionnels. Le harnais concurrent doit, lui, committer
entre connexions : ses quatre comptes fictifs, deux duos et trois séances restent
dans la base, identifiés dans le rapport de run. Il n'effectue aucun nettoyage ;
seule sa séance G08 fictive est archivée directement pour libérer le créneau,
sans purger cartes ni secrets. Une erreur/expiration du processus peut laisser
un résultat transactionnel incertain : consulter les PID, fixtures et journaux
avant de relancer, sans effacement automatique.

## Limites et activation ultérieure

La validation porte sur transactions, RPC, ACL, RLS et projections SQL avec
identités locales synthétiques. Elle ne couvre pas les JWT signés, PostgREST,
Realtime Supabase, deux téléphones physiques, les politiques d'un environnement
distant ni la charge de production. Les courses sont des scénarios déterministes
de contention, pas une exploration exhaustive de tous les ordonnancements.
Le marqueur et le nom de conteneur sont des garde-fous opératoires, pas une
authentification de l'origine des données d'une base arbitrairement renommée.

La mise en service 12×12 requiert encore :

1. Terminer et valider le client `dots12-v1` : 12 points/121 cases, historique5,
   navigation, cibles 44 px, petits écrans, clavier/zoom et planches revues.
2. Vérifier le déploiement client compatible, les sessions anciennes et les RPC
   sur l'environnement de recette réellement visé ; tester reprise et deux appareils.
3. Préparer une migration d'activation distincte qui contrôle les préconditions,
   publie explicitement le draft attendu et bascule `games.current_version` dans
   une transaction. Ne pas relier les séances existantes à la nouvelle version.
4. Faire valider cette mise en service et son plan de retour. Remettre le pointeur
   historique ne convertirait pas des séances12 déjà créées : conserver la prise
   en charge des deux formats tant qu'elles existent.

Le lot serveur peut être commité localement avec ces preuves ; ce rapport
n'autorise pas à lui seul une publication ni un déploiement.
