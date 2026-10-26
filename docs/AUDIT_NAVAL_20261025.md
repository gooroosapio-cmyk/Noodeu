# Audit serveur des mini-jeux — 25 octobre 2026

Deux défauts de validation de Bataille navale ont été reproduits puis corrigés par la migration additive `20261029000800_naval_payload_validation.sql`. L'API, les règles, les scores et les flottes déjà enregistrées ne changent pas.

## Défauts reproduits

Les appels ci-dessous passaient par `public.play_move`, avec les joueurs et une partie créés dans une transaction ensuite annulée.

| Entrée | Comportement avant correction | Comportement corrigé |
| --- | --- | --- |
| Porte-avions avec `start_row: 9`, `start_col: 0`, sans `orientation` | `ok: true`, flotte enregistrée avec `o: null`. Le calcul des cases traitait cette orientation comme verticale, jusqu'à la ligne 13 ; le navire ne pouvait donc pas être coulé. | `error: placement`, carte et secret inchangés. |
| Tir avec charge `{}` | `ok: true`, tir `{r: null, c: null, res: miss}` enregistré, tour passé. | `error: invalid_move`, aucun tir ni changement de tour. |

Le même contrôle refuse les coordonnées absentes, JSON `null`, chaînes, booléens, objets, tableaux, fractions, valeurs négatives, supérieures à 9 ou débordant la capacité d'un entier. Les valeurs JSON mathématiquement entières comme `0.0` sont acceptées. Les placements doivent préciser `H` ou `V` et respecter les limites de la grille et les chevauchements déjà contrôlés.

## Périmètre de la migration

- `private.bn_check(jsonb)` valide la forme de la flotte et les coordonnées avant conversion entière.
- `private.board_apply6(...)` conserve toutes ses branches à l'identique sauf la validation des coordonnées de `fire`.
- Les algorithmes touché, coulé, victoire, alternance, secrets et idempotence restent inchangés.
- Aucune table, politique RLS, donnée historique ou version de jeu n'est modifiée. Les éventuelles flottes historiques malformées ne sont pas réparées automatiquement.
- Dépendance : moteur mini-jeux `20261025000100_minijeux_lot2.sql`. La migration 008 n'appelle aucune fonction ajoutée par la migration 007.

## Vérifications effectuées

Uniquement dans le conteneur Docker `noodeu-refonte-test-20261025` (PostgreSQL 16), bases `noodeu_lot6_clean_2154` et `noodeu` :

| Vérification | Résultat |
| --- | --- |
| Nouveau `c29_naval_payload_validation.sql`, avant migration | Échec attendu : le placement sans orientation était accepté. |
| Nouveau C29, après migration, sur les deux bases | Réussi ; transactions annulées. |
| `c14_minijeux.sql`, après migrations 007 et 008, sur les deux bases | Réussi ; transactions annulées. |
| `c21_de30_petitbac8.sql`, après migrations 007 et 008, sur les deux bases | Réussi ; transactions annulées. |
| Bloc Pendu de `c14_lot4.sql` (lignes 1–147), sur `noodeu` | Réussi ; transaction annulée. |
| 100 lancers Dé chanceux avec charges falsifiées `die:99`, `turn_total:99999`, scores 99999, chacun rejoué avec le même identifiant | Tous les dés produits par le serveur sont entre 1 et 6 ; charges de score ignorées ; 100 répétitions sans second effet. Transaction annulée. |
| Comparaison textuelle de `board_apply6` avec sa définition précédente | Branches non navales et logique navale après validation des coordonnées identiques. |

C29 vérifie les erreurs structurées sans mutation de carte, secret, version de session ou journal des coups ; une flotte légale ; la confidentialité de chaque flotte ; le refus d'un tir déjà joué ; le double clic ; les cinq cases du porte-avions marquées coulées après cinq impacts ; la victoire après 17 impacts et la confidentialité après la partie. Les accès `SELECT` directs de `authenticated` aux tables privées de secrets et de coups restent refusés.

Les tests existants confirment également : six erreurs calculées par le serveur au Pendu, victoire prioritaire sur la nulle à la neuvième case au Morpion, neuf combinaisons PFC et aucune révélation d'un geste isolé, tirages et scores serveur du Dé chanceux, victoire à 30 points conservés ou plus.

Exemple d'exécution du nouveau test sur la base jetable :

```sh
docker exec -i noodeu-refonte-test-20261025 psql -X -v ON_ERROR_STOP=1 -U postgres -d noodeu_lot6_clean_2154 < supabase/tests/c29_naval_payload_validation.sql
```

Les seules écritures persistantes de cet audit sont les définitions des deux fonctions dans les bases Docker de test. Aucun commit, push, déploiement, accès production ni modification d'identifiants n'a été effectué.
