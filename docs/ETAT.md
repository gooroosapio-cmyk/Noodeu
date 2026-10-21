# État du projet — 21 octobre 2026

En ligne : **https://noodeu.vercel.app** (Vercel ; mise en production explicite, voir DEPLOIEMENT.md).

## Ce qui fonctionne et a été testé

| Élément | Comment c'est vérifié |
|---|---|
| Base de données : identité, couple, invitations, catalogue, parties, salon, temps réel | 6 migrations appliquées au projet Supabase ; code des fonctions en ligne **identique** à la version testée (comparaison d'empreintes) |
| Association de deux comptes (invitation, double confirmation, expiration, révocation, essais répétés, cas d'erreur) | Tests SQL, **sur le vrai projet Supabase** et en local |
| Partie complète de « Portrait en cinq mots » entre deux comptes | Tests SQL (deux comptes simulés au niveau de la base) |
| Un troisième compte n'accède à rien | Tests SQL |
| Réponses secrètes jusqu'à la révélation (table, API, temps réel) | Tests SQL ; voir la réserve sur le temps réel ci-dessous |
| Aucun doublon après actions répétées | Tests SQL |
| Séparation : historique en lecture seule | Tests SQL |
| Logique d'affichage du jeu (accord des mots, mots retrouvés) | `npm test` (5 tests) |
| Écrans sur petits écrans 320 / 390 / 430 px : aucun défilement horizontal, aucune erreur | `tests/visual/render-check.mjs` (15 écrans × 3 largeurs, données simulées) |
| Kit visuel Complicité intégré | 101 fichiers vérifiés par SHA-256 |
| Compilation de production + PWA (manifeste, service worker) | `npm run build` |

## Ce qui n'a PAS encore pu être testé

- **Une vraie partie entre deux navigateurs.** Mon environnement de travail ne peut pas joindre l'API Supabase :
  le réseau la refuse. L'interface n'a donc jamais parlé au vrai serveur. La logique serveur est testée, et les
  écrans le sont avec des données simulées, mais le branchement des deux reste à vérifier, par exemple sur l'adresse de test Vercel.
- **Le temps réel en conditions réelles.** Le projet Supabase étant neuf, son service temps réel n'avait pas encore
  préparé son stockage du jour : les signaux émis pendant le test n'y étaient pas observables. Le contenu des signaux
  ne comporte par construction aucune réponse. Le test local l'a vérifié. Sans temps réel, l'application relit l'état toutes les 4 s.
- La reprise après fermeture de l'application et la présence en ligne sur de vrais téléphones.
- La réception des e-mails de confirmation (dépend du réglage d'adresse du site dans Supabase).

## Limites connues et étapes suivantes

- **Contenu de démonstration** : les règles de « Portrait en cinq mots » sont déduites des maquettes et la liste de
  30 mots est provisoire, en attendant le manuel « Famille 01 — Se découvrir ».
- Messages vocaux du salon, mécanique de dessin et vocal dans les jeux : **à faire** (décisions 4D et 5D).
- Astuces : écran d'attente ; import des 500 stories en brouillon et carrousel : **étape 6**.
- Notifications push : **à faire** (décision 12B).
- Suppression de compte : nécessite une fonction serveur dédiée ; **à faire** (le bouton l'annonce honnêtement).
- Administration des contenus et import contrôlé : **étape 7**.
- Connexion Google : code prêt, à activer après configuration (voir DEPLOIEMENT.md).
- Envoi d'e-mails en volume : nécessite un fournisseur SMTP (à décider).
- Les parties terminées dont personne ne relance de partie restent « terminées » (salon ouvert) jusqu'à la partie
  suivante ; un nettoyage automatique est à prévoir.
