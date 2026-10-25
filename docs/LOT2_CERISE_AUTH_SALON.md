# Lot intermédiaire — cerise, authentification, salon et mini-jeux

État du 25 octobre 2026. Branche locale `codex/refonte-incrementale-20261025`, base `49d3c1e35052ce06fcca0a61ae465d65ae7b8b92`. Aucun push, fusion, déploiement, migration en production ou modification de secrets. Le distant observé `48ec7b40c885e68a279ffb0d43e410823be49bd8` comporte seulement deux documents J4 depuis la base ; non intégré, attente de coordination avec Claude.

Planche finale Library : `libfile_8981bb84290c8191974c165619340002` (`noodeu-cerise-lot2.jpg`). Huit écrans réellement capturés et inspectés, données fictives ; captures auth complètes incluses dans les livrables.

## Dernière direction retenue

La référence couleur reçue à 21:03 supplante la palette pétrole du lot précédent et la première harmonisation prune. Fond rosé clair, blanc, cerise #B72132, bordeaux #43131C, texte #251A1D, secondaire #76676B, rose #FBE7E9. Logo couleur original restauré, aucun changement de son fichier source. Les couleurs spécifiques des mini-jeux restent permises. Les rapports pétrole et leurs captures sont historiques, pas la cible actuelle.

Les deux références `1000318217.jpg` (composition auth) et `1000318222.jpg` (couleurs) ont été résolues par Library mais la matérialisation a échoué : `library file transfer failed: download failed`, code de sortie 1, aucun statut HTTP détaillé fourni. Aucun octet local à inspecter ; adaptation fondée sur les descriptions de pixels transmises par le parent. Aucun refus d'accès contourné.

## Implémentation

- Accueil : deux avatars/initiales centrés, deux boutons égaux, aucune image décorative dans le bloc duo. Espace : couverture en haut avec avatars ; commandes jeu/discussion redondantes retirées, messagerie flottante conservée.
- Invitation : modal centrée, boutons égaux Accepter/Refuser, focus piégé, Échap/retour, revalidation de l'invitation et aucune navigation avant acceptation.
- Bibliothèque : deux grandes cartes puis deux colonnes. 45 illustrations d'activités distinctes, plus trois catégories et un portrait historique (49 SVG originaux). Générateur et manifeste de provenance conservés. La carte cerise garde son illustration sur une petite surface blanche, sans la réduire à une silhouette.
- Auth : titres français, champs arrondis avec icônes et vrais labels, bouton avec flèche, mot de passe affichable, autoComplete préservé, erreurs visibles, protection des doubles envois et gestion de l'échec de réinitialisation. Google reste un emplacement désactivé. Aucune configuration OAuth. Aucun téléphone ajouté. L'attestation d'âge existante à l'inscription est conservée ; aucun interrupteur d'activation du contenu intime ajouté.
- Deux fonds bitmap originaux générés dans cet exécuteur avec OpenAI imagegen, réellement inspectés puis optimisés : `auth-ribbons.webp` (17 622 octets), `app-ivory.webp` (6 678 octets). Aucun texte/UI incorporé. Provenance et empreintes dans `public/assets/original/backgrounds/PROVENANCE.json`. Les anciens visuels du kit gardent leurs réserves de droits ; génération de ces fonds ne régularise pas les autres actifs.
- Salon : identités équilibrées, statut prêt visible ; cadre Description/Règles à deux contrôles égaux, panneaux distincts ; Quitter est un vrai bouton bordé avec confirmation. Réglages uniquement issus de `config.settings` serveur, remis par RPC existante ; paramètres fixes affichés comme règles, notamment Pig 30. Aucun réglage fictif de victoire ni altération des tests standardisés.
- Mini-jeux : scores en deux cartes ; choix PFC illustrés conservés ; alerte de fin de temps sans clignotement ; plateau points 44 px et aperçu compact inerte ; placement naval invalide expliqué ; clavier pendu >=44 px à 320 px ; actions dé égales ; Petit bac Enter final ferme le clavier. Grands arcs décoratifs déjà retirés, scènes sobres conservées.
- Chargement : logo original centré, respiration douce, statique en reduced-motion ; texte différé, aucune attente artificielle. Reconnexion : message discret différé pour le canal direct, distinction hors-ligne/erreur réseau, action Réessayer. Le dernier état reste visible.
- Navigation : les libellés respectent maintenant le texte système agrandi ; hauteur mesurée pour éviter de masquer le contenu.

## Vidéo : préparation uniquement, blocage réel

Library `libfile_7032cb4773e0819196e4da11279cf065` et poster `libfile_48f72b09c62c8191b669dfd9544556f4` : préparation réussie, téléchargement par helper échoué avec `download failed`, code 1. Aucun fichier, aucun ffprobe ni contrôle des pixels local. Aucune nouvelle génération vidéo ni dépense Runway.

`LaunchFilm.tsx` prépare le passage avant confirmation prêt : aucune manche démarrée localement, envoi prêt seulement après fin/passage/échec ; muet, playsInline, sans boucle, garde session, reduced-motion, délai de secours et annulation. Le chemin local est réservé mais le fichier est absent. **La vidéo n'est pas livrée ni opérationnelle.** Les tests prouvent l'absence de blocage et l'ordre des RPC, pas la lecture d'une vidéo réelle ni la synchronisation sur deux appareils.

## Validation exécutée

- TypeScript, ESLint, build Vite et 13 tests unitaires : réussis. Avertissement de bundle >500 kB conservé ; pas d'erreur build.
- 2 scénarios chargement : réussis (logo centré, animation normale/statique en reduced-motion, disparition dès données reçues).
- 5 scénarios Home/invitation/Quitter et 4 scénarios mini-jeux : réussis (géométrie, focus, Échap/retour, hors ligne, erreurs, double clic, cibles44).
- 4 scénarios auth/salon : réussis (connexion/inscription erreur, visibilité mot de passe, Google inactif, doubles soumissions, viewport réduit450px ; panneaux, options réelles, aucun prêt avant tentative média, 404 sans blocage, pas de rejeu, hors ligne/reconnexion, reduced-motion).
- 11 salons générés par les RPC réelles dans PostgreSQL jetable, en transaction annulée, utilisateurs fictifs. 66 rendus à 320/360/390/430/768/1440 réussis. Sans défilement est un objectif sur écran standard, pas une garantie universelle : texte200%, clavier et faible hauteur doivent rester défilables.
- 36 rendus mini-jeux à320/390, 12 rendus auth aux six largeurs, 31 rendus auth/mini-jeux/salons à320 texte200% : réussis avant la dernière substitution cerise.
- Dernière palette cerise : 10 rendus ciblés390x844 et les mêmes10 à320 texte200% réussis ; parcours Home/invitation/Quitter et auth/salon rejoués avec succès. Ces captures testent des fixtures, pas une connexion à des comptes réels.
- Une première tentative de rendu via serveur statique sans fallback SPA n'affichait pas l'application : résultats exclus. Relance avec Vite preview réussie ; harness renforcé pour exiger un enfant dans #root.
- Tests SQL21fichiers et worker3tests : réussis dans le lot sécurité précédent ; non rejoués pour ces changements frontend. Aucune migration nouvelle dans ce lot.

## Contrastes sRGB

Les valeurs ci-dessous portent sur les couleurs de surfaces unies ; le corail du logo et les rubans restent décoratifs.

| Usage | Couleurs | Ratio |
|---|---|---|
| Action cerise | #FFFFFF / #B72132 | 6.41:1 |
| Navigation/CTA sombre | #FFFFFF / #43131C | 15.57:1 |
| Texte | #251A1D / #F7F1F1 | 15.12:1 |
| Secondaire | #76676B / #F7F1F1 | 4.79:1 |
| Secondaire sur rose | #76676B / #FBE7E9 | 4.51:1 |
| Bordure de champ | #937886 / #FFFFFF | 3.98:1 |

## Limites et suite

Pas de test sur comptes réels. Clavier logiciel natif Android/iOS, lecteur d'écran natif, autofill du trousseau et comportement Safari non testés : viewport réduit et attributs autocomplete testés/inspectés, sans les assimiler à ces appareils. Vidéo réelle et parcours multi-appareils toujours bloqués par média absent. Audio demeure dépendant des fonctions, stockage privé et nettoyage serveur préparés, jamais déployés ; aucune promesse de suppression automatique en production.

Revue exhaustive de chaque état historique encore à poursuivre ; ce lot constitue un jalon stable, pas une clôture de toutes les demandes. Les améliorations serveur/privacy précédentes restent présentes. Avant une livraison en production : revue propriétaire, coordination Claude et réconciliation du distant, décision sur les dépendances audio et média, puis autorisations séparées de push/PR brouillon et déploiement.
