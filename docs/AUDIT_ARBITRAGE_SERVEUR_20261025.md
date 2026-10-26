# Audit de l'arbitrage serveur — 25 octobre 2026

Périmètre : `/workspace/Noodeu`, base de code `7d8a591`, branche
`codex/refonte-incrementale-20261025`. Migrations additives 007 et 008 uniquement,
sans modification des anciennes migrations, de l'interface, des questionnaires
standardisés, d'Aron ou de P20. Aucun push, déploiement, accès aux identifiants,
service de production, stockage ou cron réel.

## Petit bac : constat et correction

L'arbitrage existant est déjà effectué au serveur. Les brouillons restent privés
jusqu'au gel commun. Une réponse absente de l'index de sa rubrique a le statut
`unknown` ; elle n'est pas déclarée fausse. Deux accords permettent de l'accepter
ou de la refuser. Une réponse reconnue peut aussi être contestée. Le barème est
5 points pour une même réponse valide, 10 pour deux réponses valides différentes,
15 pour l'unique réponse valide ; une réponse non tranchée vaut 0. Ce barème,
les délais et les mouvements RPC n'ont pas changé.

Trois défauts ont été reproduits avant correction dans PostgreSQL 16 :

| Saisie, rubrique, initiale | Réponse historique | Réponse des nouvelles parties |
| --- | --- | --- |
| `e` + accent combinant, dans « éléphant », animal, E | `unknown` | `valid` |
| tabulations autour de « chat », animal, C | `invalid` | `valid` |
| espaces insécables autour de « chat », animal, C | `invalid` | `valid` |

La migration `20261029000700_petit_bac_normalization.sql` ajoute
`private.pb_norm_v2`, une copie figée de la banque sous le nom
`petit_bac_huit_unicode`, et une nouvelle version de `N2-018` (3 dans les bases
testées). Les versions 1 et 2 et leurs banques restent identiques ; la fonction
de classement conserve sa branche historique pour elles. Aucune partie, réponse,
banque ancienne ou règle ancienne n'est modifiée ou recalculée.

La normalisation v2 traite casse, accents composés/décomposés, ligatures œ/æ,
apostrophes courbes et espaces Unicode courants ; elle retire les espaces
périphériques et réduit les espaces successifs. Les articles et traits d'union
restent significatifs. Les variantes absentes comme « chevaux » restent à
vérifier, sans déduction automatique ni rejet fondé sur l'absence.

La requête de recherche balayait auparavant `content_banks` (plan observé :
1 595 lignes écartées, 125 buffers partagés). Un index GIN partiel sur les alias
de la seule nouvelle banque sert désormais réellement à la requête (plan
`Bitmap Index Scan on content_banks_pb8_v2_aliases_idx`, 7 buffers avec le tri).
La rubrique est toujours vérifiée : « chat » ne devient pas une ville valide.

## Contrat pour l'interface

Les statuts `empty`, `invalid`, `valid`, `unknown`, les champs `final`, `points`,
`scores`, les mouvements et le déroulement restent compatibles. Les réponses
de la nouvelle banque ajoutent `index_version: "pb8-2026-10-29-v2"` et :

| `reason` | Sens affichable |
| --- | --- |
| `empty_answer` | Aucune réponse |
| `wrong_initial` | La réponse ne commence pas par la lettre demandée |
| `indexed_match` | Réponse reconnue dans cette rubrique, contestable |
| `not_in_index` | Absente de notre index : à vérifier ensemble |

`reason` décrit le contrôle initial, et ne remplace jamais le verdict final des
joueurs. L'interface doit garder un repli sur les statuts pour les anciennes
parties, qui ne contiennent pas ces champs. Les confirmations sont annulées
lorsqu'un vote change, comme auparavant.

## Index réel et provenance

L'index comporte 866 entrées, 941 alias et 16 lettres communes aux huit rubriques :
`A B C D E F G H L M N O P R S T`. Les 866 entrées et leurs alias sont identiques
entre les banques huit rubriques historique et nouvelle ; aucune liste externe,
aucun dictionnaire acheté et aucun enrichissement automatique n'ont été importés.

| Rubrique | Entrées |
| --- | ---: |
| Animal | 136 |
| Ville | 131 |
| Métier | 96 |
| Objet | 104 |
| Pays | 120 |
| Prénom | 114 |
| Fruit ou légume | 76 |
| Célébrité | 89 |

La banque historique à quatre rubriques contient 134 entrées ; la banque huit
rubriques les reprend et ajoute 732 entrées distinctes du script local
`scripts/petit_bac8_index.py`. Le script déclare une rédaction Noodeu et une
relecture encore nécessaire. L'index est donc limité et ne constitue pas un
dictionnaire exhaustif ni une preuve de validité éditoriale pour chaque entrée.

Les attributions existantes mentionnent Lexique 4.10 et certaines données
géographiques Wikidata. La page officielle de [Lexique](https://www.lexique.org/)
annonce CC BY-SA 4.0 ; la [politique officielle de Wikidata](https://www.wikidata.org/wiki/Wikidata:Licensing)
indique CC0 pour les données structurées. Ces pages ont été consultées le
25 octobre 2026 ; aucun contenu lexical n'a été téléchargé.
Ces licences générales sont corroborées. En revanche, le dépôt ne fournit pas
de traçabilité source/licence par entrée ni de preuve de relecture complète du
lot Noodeu : ces points restent incertains. Les attributions existantes sont
conservées, sans affirmer une validation des droits de chaque entrée.

## Tests réalisés

Conteneur autorisé : `noodeu-refonte-test-20261025`, image `postgres:16`.
Bases autorisées : `noodeu_lot6_clean_2154` et `noodeu`, avec shim local Supabase.
Les tests de jeu se terminent par `ROLLBACK` ; aucune fixture n'est conservée.

- `c28_petit_bac_arbitrage.sql` passe sur les deux bases : les 941 alias sont
  reconnus dans leur rubrique ; Unicode, casse, ligatures, espaces, initiales,
  catégories et variantes inconnues sont vérifiés. Le parcours `play_move`
  couvre secrets, gel, acceptation, contestation, confirmations et scores 5/10/15.
- Même identifiant d'action rejoué : `repeated`, aucun second gel ni score.
  Deuxième Stop avec un nouvel identifiant : refus `phase`, état inchangé.
  Ces réessais sont séquentiels ; aucune latence réseau ni charge concurrente
  multi-appareils n'est revendiquée.
- Une partie créée avec la version 2 continue à utiliser cette version après
  remise du catalogue en version 3 ; son classement historique reste inchangé.
- Application de 007 avec comparaison avant/après : anciennes versions et
  banques identiques. Réapplication : zéro entrée, zéro version, zéro mise à jour.
- `c14_minijeux.sql`, `c21_de30_petitbac8.sql` et
  `c29_naval_payload_validation.sql` passent sur les deux bases après 007 + 008.
- Le bloc Pendu de `c14_lot4.sql` passe sur la base `noodeu`. Le test complet de lot 4
  est écrit pour le catalogue initial à quatre rubriques ; il n'est pas présenté
  comme passé sur le catalogue huit rubriques.

Reproduction du test Petit bac :

```sh
docker exec -i noodeu-refonte-test-20261025 psql -U postgres -d noodeu_lot6_clean_2154 -X -v ON_ERROR_STOP=1 < supabase/tests/c28_petit_bac_arbitrage.sql
docker exec -i noodeu-refonte-test-20261025 psql -U postgres -d noodeu_lot6_clean_2154 -X -v ON_ERROR_STOP=1 < supabase/tests/c28_petit_bac_latency.sql
```

Mesure locale de fonctions serveur avec `clock_timestamp`, même base, séries
successives de 2 000 classements et 1 000 gels complets (16 réponses inconnues) :

| Opération | Historique moyenne / p95 | v2 moyenne / p95 |
| --- | ---: | ---: |
| Réponse reconnue | 0,083 / 0,132 ms | 0,058 / 0,078 ms |
| Réponse absente | 0,163 / 0,246 ms | 0,057 / 0,077 ms |
| Gel de seize réponses | 2,495 / 2,682 ms | 1,060 / 1,362 ms |

Il s'agit du temps PostgreSQL local, sans réseau, rendu client, charge de
production ou objectif de performance garanti. Le script de mesure est versionné
et n'impose aucun seuil dépendant du matériel.

## Autres mini-jeux et dépendances

Pendu : erreurs et fin à six erreurs calculées serveur. Morpion : victoire
prioritaire sur la nulle, y compris à la neuvième case. PFC : révélation commune
après deux gestes ; expiration d'un geste isolé sans révélation. Dé chanceux :
tirage serveur, cible versionnée à 30, victoire à la conservation. Aucun défaut
exigeant une modification de ces mécanismes n'a été observé dans les cas testés.

Bataille navale : deux défauts de payload sont reproduits et corrigés par 008 :
orientation absente pouvant créer un bateau hors plateau impossible à couler,
et tir sans coordonnées consommant un tour. Le rapport
`AUDIT_NAVAL_20261025.md` détaille les validations et la préservation du calcul
touché/coulé et des secrets.

007 dépend de l'état migré jusqu'à `20261029000600` (notamment les banques de
`20261028000500` et le moteur de `20261025000300`). 008 dépend du moteur mini-jeux
de `20261025000100`, et est indépendante des fonctions de 007. L'ordre livré
reste 007 puis 008. Les migrations sont préparées et testées localement ; elles
n'ont été appliquées à aucun environnement réel.
