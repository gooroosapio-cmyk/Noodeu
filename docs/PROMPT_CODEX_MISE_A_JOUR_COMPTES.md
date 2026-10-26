# Prompt pour Codex : mise en ligne de la mise à jour « comptes réels »

Réponds en français. Fais un audit avant toute action.

## Contexte

- La production sert `0ee5ebf` (ta livraison V7). Point de retour arrière : ce déploiement.
- La branche `v7/interface-20261026` contient maintenant, après `0ee5ebf`, les commits de Claude :
  - **Comptes réels.** À la connexion, « mot de passe oublié » devient un message de contact, car aucun service d'e-mail n'est configuré. Ajout de « Changer mon mot de passe » dans Réglages, avec revérification du mot de passe actuel.
  - **Test SQL et rapport.** Nouveau test d'isolation `supabase/tests/c43_isolation_comptes.sql` et rapport `docs/AUDIT_SECURITE_COMPTES_20261026.md`.
  - **Fusion sans conflit** de ton commit `0ee5ebf`.
- **Base de données : rien à faire.** Les migrations `20261030001500_comptes_reels_perf.sql` et `20261030000100_duo_space.sql` sont déjà appliquées en ligne par Claude, avec l'accord du propriétaire. N'applique aucune migration.

## Règles

- Aucun secret dans le navigateur, sur GitHub ou dans les journaux. Ne demande jamais de token ni de mot de passe.
- Aucune migration, aucune modification de données de production, aucun service payant.
- Pas de force-push, pas de réécriture d'historique. Ne touche jamais au projet Limpid.
- Ne prétends rien sans preuve.

## Étapes

1. **Audit.** Lance `git fetch`, puis `git log --oneline 0ee5ebf..origin/v7/interface-20261026`, et lis le diff. Le seul changement attendu sous `supabase/` est la migration 1500 et le test c43 : ce sont des fichiers, pas des actions.
2. **Vérifications locales.** `npm ci`, `npm run lint`, `npm run typecheck`, `npm test` (21 tests), `npm run build`, puis tes parcours V7 habituels.
3. **Déploiement de test (preview).** Déploie le dernier commit de la branche en preview, puis vérifie :
   - `/assets/noodeu-release.json` doit renvoyer le bon commit ;
   - **création d'un compte** avec une adresse de test jetable : arrivée directe sur l'accueil, sans e-mail ;
   - **Réglages → Changer mon mot de passe** :
     - un mauvais mot de passe actuel est refusé ;
     - le changement avec le bon fonctionne ;
     - après déconnexion, on se reconnecte avec le nouveau mot de passe ;
   - **Espace → couverture et « Nos notes »** : une note ajoutée apparaît, et la photo de couverture se change. Ces fonctions ne sont plus « pas disponibles » ;
   - supprime ensuite ce compte de test (Réglages → Supprimer mon compte) ;
   - l'écran de connexion affiche « Mot de passe oublié ? Contacte l'équipe Noodeu… », sans bouton d'envoi d'e-mail.
4. **Production.** Le propriétaire autorise la mise en production de ce commit précis, une fois tous les contrôles de la preview verts. Promeus cette preview validée, et aucun autre commit.
5. **Après la mise en production.** Refais les contrôles 3 sur noodeu.vercel.app. Au moindre défaut bloquant, reviens au déploiement de `0ee5ebf` et signale-le avec ses preuves.

## Rapport attendu

- Commit et identifiants de déploiement.
- Sorties des vérifications.
- Résultat de chaque contrôle.
- Ce qui n'a pas pu être vérifié.
