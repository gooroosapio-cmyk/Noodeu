# Réconciliation locale du 26 octobre 2026

Cette livraison réconcilie le commit local `7488ab3f79894610c8085f753c8a6e6048c93d63` et le commit Claude `1dc479825c796e61a7e8b2531220883bf1af8335`. Elle conserve leurs historiques. Aucune écriture GitHub, publication Vercel ni migration de production n'a été exécutée pendant ce lot.

## Résolution des chevauchements

- **Salon** : composition Claude conservée (joueurs, jeu, description, réglages, validation), dans les tokens cerise/bordeaux actifs. Vrais avatars et noms, absence de symbole central, boutons Description/Règles égaux et Quitter distinct de Réduire. Les choix 5/10/20 restent sur une ligne aux tailles usuelles. G08 reste simultané ; aucun premier joueur n'est ajouté.
- **Validation** : les réglages sont verrouillés après validation, puis déverrouillés par « Modifier les réglages ». Une fenêtre Options déjà ouverte respecte aussi l'état prêt et la lecture seule. Si les réglages changent pendant la préparation, une nouvelle validation explicite est nécessaire ; un changement de `state_version` seul ne l'annule pas. Le champ `game_version` a été ajouté au type TypeScript : il existait déjà dans la réponse SQL, sans changement du schéma.
- **Naval** : la vue entière rectangulaire reste affichée par défaut. Un toucher ouvre les grandes cibles à la coordonnée visée ; il ne place aucun navire et n'arme aucun tir. Entrée/Espace et le bouton Cibler donnent la même possibilité au clavier. Les choix et confirmations restent séparés. Flotte propre, sprites proportionnés, rotation, placement aléatoire, défilement, zoom et journal sont conservés. Aucune position adverse cachée n'est utilisée.
- **Styles historiques** : les fichiers `GameFrame.tsx` et `game-frame.css` de Claude sont préservés. La feuille globale n'est pas réimportée : elle masquerait des scores dans les consoles actives. Seuls les styles utiles au salon sont transposés dans la feuille ciblée existante.
- **Corrections utilisateur conservées** : pas de barre Règles/Pause/Quitter dans le corps des jeux, commandes accessibles par le menu, Réduire rouge et chat flottant. Portes illustrées sous le texte de Tu préfères, questions/réponses non tronquées et huit rubriques Petit bac. Le mot « rempli » restant dans le compteur et la note Petit bac a aussi été retiré ; le compteur conserve son libellé accessible.

## Vérification

Les captures et parcours utilisent des données fictives, avec les requêtes externes bloquées. Ils ne prouvent pas le comportement de deux téléphones réels, ni les ACL de production.

Les preuves détaillées sont fournies dans l'archive de passation. Les contrôles couvrent lint, TypeScript, build, 13 tests unitaires, Admin/auth, fonctions indisponibles, confidentialité, réduction/reprise, double clic, validation des réglages, lecture longue et texte 200 %, salon et plateau naval. Le contrôle de visibilité du plateau exclut désormais la surface occupée par l'en-tête fixe : une mesure de débordement seule n'était pas suffisante.

| Contrôle exécuté | Résultat |
| --- | --- |
| Lint, TypeScript, build | Réussis ; avertissement existant de chunk JS >500 kB |
| Unitaires | 13 réussis |
| Salon | 12 parcours et 48 vues réussis |
| Naval | 64 vues et 4 parcours réussis ; plateau initial entier à 320/360/390/430 px |
| En-tête petite hauteur/200 %, titres longs | 6 cas réussis, pixels inspectés |
| Admin/auth et replis indisponibles | 11 Admin, 4 auth/salon, 2 replis RPC réussis |
| Préparation et changement concurrent de réglages | 2 cas réussis |
| Confidentialité et parcours existants | 13 parcours réussis sur fixtures |
| Consoles et lecture | 7 groupes console, 15 groupes lecture réussis |
| Cartes et compacité | 6 profils Tu préfères et 24 vues compactes réussis |

Les tests de logique sur le premier build fusionné restent valables après la seule correction d'en-tête et des libellés Petit bac. Les contrôles géométriques concernés ont été relancés sur ces corrections. Les petits écrans et le texte agrandi ont un repli vertical accessible ; à petite hauteur l'en-tête cesse d'être fixe. Aucune expérience sur appareil physique n'est revendiquée.

Deux échecs intermédiaires ont été corrigés : un champ API absent du type TypeScript, puis une assertion de test qui lisait les appels avant la réponse du passage de carte. Un essai navigateur sans configuration fictive était non interprétable ; il a été relancé avec la configuration prévue. Le défaut d'en-tête à texte agrandi a été découvert par inspection des pixels, puis ajouté aux vérifications.

## Dépendances et limites inchangées

Aucun fichier SQL, Admin ou d'authentification ne change par rapport à `7488ab3`. Les 19 tests SQL et quatre courses concurrentes de cette version restent des preuves antérieures, non réexécutées pour cette fusion d'interface. Aucun test SQL n'a visé la production.

Lire `SQL_CONCORDANCE_MERGE_20261026.md` avant toute opération DB. Les migrations préparées `20261030000900_session_settings_validation.sql`, `20261030001000_dots12_versioned.sql` et `20261030001100_admin_exclude_petit_bac_index.sql` ne sont pas appliquées en production par cette livraison. L'activation 12×12 reste séparée dans `supabase/optional/activate_dots12_after_validation.sql`. Ne jamais rejouer des tests, purges ou toutes les anciennes migrations sur une base réelle.

Audio désactivé ; Google non configuré ; vidéo Runway de lancement absente. Notes/couverture personnelle et autres fonctionnalités dépendant d'une migration absente affichent leur indisponibilité. Aucun secret, credential, RLS, accès Storage ou scheduler n'a été modifié. Les dépendances Edge/worker/nettoyage audio 24 h sont décrites dans la passation précédente et restent non déployées.

## Publication

L'autorisation utilisateur de publier persiste, mais l'API GitHub a refusé la dernière tentative d'écriture avec HTTP 403 « Resource not accessible by integration ». La vérification en lecture de l'installation active n'y a pas trouvé Noodeu parmi les dépôts sélectionnés. Aucune nouvelle écriture ne doit être tentée sans élément pertinent confirmant la correction de l'accès.

Vercel est coordonné par le parent : projet `noodeu`, jamais `noodeu-wup1`. Après accès corrigé, revérifier le distant, publier sans force-push, identifier le SHA effectivement construit, vérifier un état terminal et le domaine `noodeu.vercel.app`. Une preview READY ne prouve pas une promotion en production. Ne pas modifier la protection existante.
