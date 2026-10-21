# État du projet — 21 octobre 2026 (après la refonte UI/UX)

En ligne : **https://noodeu.vercel.app** (Vercel ; mise en production explicite, voir DEPLOIEMENT.md).

## Ce qui fonctionne et comment c'est vérifié

| Élément | Vérification |
|---|---|
| Base : identité, duos, invitations, catalogue, parties, temps réel (6 migrations) + duos par épisodes, notifications, discussion, photos (migration 7) | 50 fonctions en ligne **identiques** à la version testée (empreintes comparées) |
| Invitation : code non prédictible, double confirmation, expiration, annulation, nouveau code invalidant l'ancien, essais limités | Tests SQL en local **et sur le projet Supabase** |
| A–B archivé, A–C actif, C n'accède à rien de A–B (table, adresse directe, canal temps réel, photo), reprise A–B dans le même espace avec un nouvel épisode | Tests SQL sur Supabase |
| Réponses secrètes avant révélation ; aucun doublon après actions répétées ; partie clôturée à la fin d'un duo | Tests SQL sur Supabase |
| Discussion : envoi idempotent, non-lus réels, archive en lecture seule | Tests SQL sur Supabase |
| Notifications personnelles (demande, acceptation, refus, fin de duo, partie proposée, messages) | Tests SQL sur Supabase |
| Interface : 23 écrans × 320/360/390/430/768/1440 px + écran bas (390×560) : aucun défilement horizontal, rien sous la barre de navigation, aucune erreur | `tests/visual/render-check.mjs` (données simulées) |
| Texte agrandi à 200 % à 320 et 390 px : aucun débordement | idem, `ZOOM=2` |
| Contrastes de la palette | calcul WCAG (voir DESIGN.md) |
| Logique de jeu | `npm test` |

## Ce qui n'a PAS pu être testé par moi

Mon environnement ne peut joindre ni l'API Supabase ni le site en ligne. Restent donc à vérifier **sur de vrais appareils** :
- une partie et une discussion entre deux téléphones (le temps réel en conditions réelles) ;
- l'envoi d'une photo de profil (stockage) ;
- la suppression de compte (fonction serveur déployée, jamais exécutée : l'essayer effacerait un compte) ;
- le bouton Google (il apparaîtra seul quand le fournisseur sera activé dans Supabase) ;
- le comportement en mode application installée (PWA) et clavier ouvert sur un vrai téléphone.

## Limites connues et suites

- Contenu de jeu **de démonstration** (règles déduites des maquettes, 30 mots provisoires). Ses consignes publiées
  emploient encore « ton ou ta partenaire » : une version 2 neutre sera publiée avec le contenu validé.
- Astuces : écran d'attente ; import des 500 stories en brouillon et carrousel : étape suivante.
- Messages vocaux, dessin, notifications push : à faire.
- Couverture de duo, signalement/blocage : non implémentés (facultatifs dans le cahier).
- Administration des contenus : à faire.
- Sur 320 px avec texte à 200 %, les libellés de navigation se coupent sur plusieurs lignes (pas de chevauchement).
