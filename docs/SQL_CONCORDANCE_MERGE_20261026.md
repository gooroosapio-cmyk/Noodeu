# SQL après fusion Claude — concordance et validation locale

L'historique fusionné s'applique sur une nouvelle base PostgreSQL locale :
**68 migrations, 19 fichiers de tests intégrés, un upgrade, un test d'activation
annulée et quatre courses concurrentes réussis**. Le contrôle final confirme
N2-079 version1 courante, draft version2 non publié, aucune fixture d'activation
résiduelle. Aucune DB de production n'a été lue ou modifiée dans cette campagne.

Sources de fusion : ancêtre `104564da4a7d8dc5761f9616d40d8f8a1ba5f658`, référence
Claude `6ca9725562b58e99d454b460bd319416dad0733a`, HEAD local de validation
`4b0f82fe8eaac7f9017d2f3fde855d71be9d3d28` avec fusion encore non commitée.
Les SHA256 des fichiers effectivement exécutés sont dans
`SQL_CONCORDANCE_MERGE_20261026_EVIDENCE.json`.

Ce document donne les **noms actuels à utiliser**. Les anciens rapports et leurs
journaux restent des preuves de leur campagne d'origine : leurs numéros C23–C32
et préfixes290 ne sont pas renommés rétroactivement.

## Ordre actuel des migrations préparées

Sous `supabase/migrations/`, après l'historique antérieur :

| Fichier actuel | Rôle |
| --- | --- |
| `20261029000100_admin_questions.sql` | Administration des questions et adaptation des tirages |
| `20261029000200_tu_preferes_situations.sql` | Contenu Tu préfères fourni par le propriétaire |
| `20261029000300_accord_phrase_se_decouvrir.sql` | Contenu et classement Accord/Phrase |
| `20261030000100_duo_space.sql` | Notes partagées et couverture privée |
| `20261030000200_audio_answers.sql` | Préparation audio, désactivée |
| `20261030000300_random_packs.sql` | Packs aléatoires ; saute les questions supprimées par l'Admin |
| `20261030000400_random_mixed.sql` | Tirage général mélangé ; saute les questions supprimées par l'Admin |
| `20261030000500_home_moment.sql` | Question horaire serveur, sans cron |
| `20261030000600_home_catalogue.sql` | Source catalogue des questions Home |
| `20261030000700_petit_bac_normalization.sql` | Normalisation et banque Unicode versionnée |
| `20261030000800_naval_payload_validation.sql` | Validation des placements et tirs navals |
| `20261030000900_session_settings_validation.sql` | Réglages atomiques et valeurs canoniques |
| `20261030001000_dots12_versioned.sql` | Moteur Dots12 et draft non publié/non courant |
| `20261030001100_admin_exclude_petit_bac_index.sql` | Exclut l'index Unicode de l'Administration des questions |

Les anciens fichiers290001–008 du lot Noodeu correspondent maintenant à300001–008.
Les corps003/004 comportent également les modifications Claude de saut des
questions supprimées : ce ne sont pas de simples renommages. Les nouveaux009/010
sont renommés en300009/300010 sans modification de leur contenu SQL.

**Ne pas rejouer les fichiers300001–008 renommés sur une base ayant déjà reçu les
anciens290001–008.** L'historique réel et les migrations enregistrées doivent être
rapprochés avant toute opération distante. Cette campagne a utilisé une base neuve
et n'a modifié aucune table distante de suivi de migrations.

## Concordance des tests

| Ancien nom local | Nom actuel |
| --- | --- |
| `c23_duo_space.sql` | `c30_duo_space.sql` |
| `c24_audio.sql` | `c31_audio.sql` |
| `c25_random.sql` | `c32_random.sql` |
| `c26_random_mixed.sql` | `c33_random_mixed.sql` |
| `c27_home_moment.sql` | `c34_home_moment.sql` |
| `c28_petit_bac_arbitrage.sql` | `c35_petit_bac_arbitrage.sql` |
| `c28_petit_bac_latency.sql` | `c36_petit_bac_latency.sql` |
| `c29_naval_payload_validation.sql` | `c37_naval_payload_validation.sql` |
| `c30_session_settings.sql` | `c38_session_settings.sql` |
| `c31_dots12.sql` | `c39_dots12.sql` |
| `c32_server_guards.sql` | `c40_server_guards.sql` |

C18–C22 gardent leurs noms. Claude ajoute `c23_admin_questions.sql`,
`c24_tu_preferes_situations.sql` et `c25_accord_phrase.sql`. Le lanceur
`tests/sql/server_regression.py` utilise maintenant un **manifest explicite de19
fichiers**, C18–C25 puis C30–C40, et refuse un fichier manquant. Il n'utilise plus
la plage18–32 qui aurait silencieusement omis une partie de la suite fusionnée.
Les helpers transactionnels `t30/t31/t32` restent inchangés dans C38/C39/C40 ; leurs
messages historiques ne changent pas l'identité du fichier attesté par le runner.
Les gardes de bases marquées sur C35–C37 sont conservées.

`supabase/tests/upgrade/dots12_from_008.sql` inclut maintenant
`20261030001000_dots12_versioned.sql`. Sa précondition demeure : historique préparé
jusqu'à300008 ou300009, mais300010 absente. Les tests upgrade/activation restent
hors du manifest de la suite ordinaire.

## Correction additive300011 et preuve du défaut

L'Admin excluait `hangman_words`, `petit_bac` et `petit_bac_huit`. Après300007,
N2-018 utilisait `petit_bac_huit_unicode`, qui entrait donc à tort dans le mapping
des questions éditables.300011 remplace uniquement `private.admin_bank_map()` pour
ajouter cette quatrième exclusion. Les sources distantes290001 et300007 restent
inchangées ; aucun guard, RPC public, ACL, propriétaire ou politique RLS n'est réécrit.

C23 vérifie que la banque Unicode existe et est effectivement courante, qu'elle
est absente de la liste et du mapping Admin, puis qu'un ajout Admin retourne
exactement `not_found` sans mutation de l'index. Avant300011, le test étendu a
échoué avec exit3 sur « ni mots ni index, y compris banque Unicode » ; la transaction
a été annulée et les fixtures contrôlées absentes. Après300011, C23 entier réussit.
Ce premier échec s'arrête au contrôle de liste ; il n'est pas présenté comme une
exécution isolée de chaque assertion suivante sur l'ancienne fonction.

La comparaison avant/après300011 vérifie : **866 entrées et empreinte d'index
identiques**, ACL/propriétaire/security-definer/search-path du mapping identiques,
définition d'`admin_guard`, définitions/ACL des cinq RPC Admin et empreinte des
politiques RLS identiques. Seul le mapping Unicode passe de présent à absent.

## Exécution locale et limites

- Conteneur : `noodeu-refonte-test-20261025`, contexte Docker `default`, endpoint
  `unix:///var/run/docker.sock`, psql par socket Unix.
- Base créée pour cette campagne : `noodeu_server_merge_20261026_042733_22d838`,
  marquée `noodeu:disposable-local-sql-test`. PostgreSQL16.15.
- Aucun DROP DATABASE, nettoyage d'ancienne base ou usage du script historique
  `scripts/run_sql_tests.sh` n'a été effectué.
- Dossier de preuves : `/workspace/noodeu-server-merged-validation-20261026_042733`.

| Étape | Résultat et preuve |
| --- | --- |
| Construction jusqu'à300009 | Shim local +66 migrations réussis, `build-through-009.json` |
| Upgrade transactionnel avant300010 | Ancienne partie5/salon5 conservés ; rollback intégral, `upgrade-results.json` |
|300010 puis300011 | Deux migrations réussies ;68 migrations au total, `admin-unicode-fix.json` |
| C23 avant011 | Échec attendu reproduisant le défaut ; aucune fixture persistée, `c23-before-011.expected-failure.log` |
| Suite intégrée | **19/19 fichiers exit0**, `suite-results.json` |
| Activation facultative sous rollback | Trois refus exacts, activation/rejeu, ancienne5/nouvelle12, `activation-results.json` |
| Concurrence | **4 courses, `ok:true`**, run `9cc716e8-7545-435b-beab-0d6972964381`, `server-concurrency-results.json` |
| Contrôle final indépendant en lecture | current1/draft2 non publié,92 versions publiées, zéro fixture d'activation, Unicode hors Admin, `final-readonly-state.json` |

Les courses conservent volontairement leurs quatre utilisateurs fictifs, deux duos
et trois séances, identifiés par le run. Les autres tests sont annulés. Les chiffres
concernent des fichiers et courses, pas un nombre inventé d'assertions. Les tests
historiques C14–C17 n'ont pas été rejoués sur le schéma final ; les preuves de leur
étage historique restent dans la campagne précédente.

Sur cette base dédiée existante :

```sh
python3 tests/sql/server_regression.py noodeu_server_merge_20261026_042733_22d838 suite --list
python3 tests/sql/server_regression.py noodeu_server_merge_20261026_042733_22d838 suite
python3 tests/sql/server_regression.py noodeu_server_merge_20261026_042733_22d838 activation
python3 tests/sql/server_concurrency.py noodeu_server_merge_20261026_042733_22d838
```

L'upgrade nécessite une autre base neuve arrêtée avant300010 ; il refuse cette base
finale déjà migrée. Ne pas réappliquer les migrations pour recréer artificiellement
cette précondition. Le runner ne crée ni ne supprime de base et n'applique aucune
migration persistante. Compilation Python, sélection19 et `git diff --check` réussis.

Ce sont des preuves PostgreSQL locales avec identités synthétiques. Elles ne
valident pas JWT signés, PostgREST, Realtime distant, Storage HTTP, charge production
ou deux appareils physiques. Aucun nouveau déploiement Edge/worker n'a été réalisé.

## Activation Dots12 et dépendances de mise en service

`supabase/optional/activate_dots12_after_validation.sql` garde son chemin et reste
**hors migrations automatiques**. Il sélectionne l'unique version
`noodeu-m04-2.0.0` / contrat `dots12-v1`, exige le catalogue historique attendu et
ne modifie aucune séance. Le test fusionné confirme l'idempotence, la publication
unique et la compatibilité des séances5. Il a uniquement été exécuté sous rollback :
aucune activation persistante ni DB de production n'est autorisée par cette campagne.
L'étape propriétaire reste décrite dans `SERVER_GUARDS_DOTS12_20261026.md` ; lire
300010 à la place de l'ancien préfixe290010 dans les références historiques.

L'audio300002 reste désactivé et conserve ses dépendances : Edge
`supabase/functions/read-answer-audio/index.ts`, worker `scripts/audio_worker.py`,
ffmpeg/ffprobe, Storage privé, cadence et configuration serveur à valider séparément.
Les renommages SQL ne déploient aucun de ces services et ne modifient aucun secret.
