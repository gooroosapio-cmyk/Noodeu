# Accueil — typographie, rotation et discussion flottante

Révision locale après f13cb89. Claude a terminé selon le propriétaire ; **attendre la validation explicite des nouveaux visuels avant fusion/publication/déploiement**. Aucun distant relu ou modifié dans ce lot.

## Changements
- Titres et boutons Home légèrement réduits, question en graisse400. Tailles en rem, saisies16px intactes, cibles44px minimum. Notre espace devient un bouton maison seul, nom accessible conservé.
- Quatre cartes de carrousel : rotation automatique toutes les3000ms, jamais lancement de jeu. Un seul timer avec nettoyage. Pause au survol/focus, onglet caché ; toucher/swipe/clavier/navigation manuelle suspendent jusqu'à reprise explicite. Contrôle Pause/Reprendre accessible. Mouvement réduit : rotation désactivée et contrôle retiré ; navigation manuelle toujours possible. La sortie d'une pause repart sur un délai complet, sans rattrapage.
- Suppression du wrapper chat-dock et de la marge fixe qui créait une bande derrière la bulle. Réserve de fin de contenu défilable et scroll-padding pour atteindre les derniers contrôles. La bulle seule flotte, se place sur un bord libre lorsque sa position habituelle recouvrirait une commande. Priorité au bas droit ; autres positions de bord en cas de collision. Pas d'animation de déplacement. Une vraie modal masque la bulle. Réévaluation sur scroll/redimensionnement/contenu, écouteurs nettoyés.
- Calques décoratifs issus des WebP3D originaux déjà présents : cartes, tasse, dé, podium, lanterne. Opacité4,5à12%, décor sans événements, hors zones CTA autant que possible. Aucune génération/dépense ni asset externe. Charte cerise conservée.
- Aucun changement de banque, fréquence horaire, migrations ou moteur de jeu. Les migrations005+006 et dépendances antérieures restent préparées, non appliquées en production.

## Vérification
- Types via build, lint, build et13unitaires réussis.
-14 assertions autoplay sur horloge contrôlée : avant3000ms, rotation exacte, unicité, hover/focus/toucher/reprise, caché/visible, reduced-motion, nettoyage navigation. Le test substitue scroll instantané au scroll doux pour mesurer le déclenchement : il ne certifie pas la fluidité sur chaque appareil.
- Bulle :15positions de défilement (5à320/390/430), aucun chevauchement avec les boutons/liens mesurés ; modal devant la bulle aux3largeurs. Premier test avait détecté Voir tout masqué à320px au milieu de page ; choix supplémentaires de placement corrigent ce cas, test final réussi.
- Rendus Home320/390/430 avec et sans partie, texte200% aux3largeurs : aucun overflow horizontal, commande finale inaccessible sous nav, erreur JS ou cible<44px. Captures de fixtures seulement.
- Contrôle complémentaire salon/jeu portrait/notifications aux3largeurs pour la suppression du rail commun. Voir les journaux pour le résultat exact, sans prétendre une revue de tous les jeux.
- Le premier test temporel avançait depuis une horloge non arrêtée ; corrigé en gelant l'horloge avant montage. Un changement dynamique reduced-motion a aussi conduit à ajouter un garde direct dans le callback, en plus du nettoyage de l'effet.

## Limites
Pas de validation utilisateur encore reçue. Pas de test tactile sur appareil physique, de performances bas de gamme ni de couverture exhaustive du positionnement flottant sur tous les formulaires/claviers. Si toutes les positions candidates sont occupées, le placement minimise le recouvrement ; l'espace de fin défilable permet de dégager les commandes. Le mouvement de la bulle entre bords est un compromis explicite pour supprimer le rail sans masquer les boutons testés.

La capture montre une phase fixe du carrousel ; la rotation se vérifie dans les tests, pas dans un JPEG. La question reste horaire, malgré le terme « jour » du message. La réserve sur les droits C1/C2 est inchangée.
