# Lot 3 — ergonomie des jeux et erreurs

Base locale : 0ff11ca. Aucun push, changement de production ou migration dans ce lot.

## Corrections
- Navigation après fermeture conditionnée au succès RPC dans les familles plateau, conversation, questionnaire et rounds.
- Naval : sélection compacte du navire, progression réelle, lignes/colonnes accessibles, un arrêt Tab, flèches/Home/End et défilement local.
- Mosaïque historique : cases de 44 px, défilement limité au plateau.
- PFC : noms visibles à la révélation, annulation des rappels d'expiration à la sortie, reprises bornées.
- Simon/rythme : nettoyage des lectures différées à la sortie et respect du mouvement réduit.
- Petit bac : erreur d'enregistrement visible, texte conservé, réessai explicite avec révision supérieure.
- Résultats mini-jeux : scores lisibles et illustration propre à la mécanique.

## Preuves
MATRICE_JEUX_LOT3.md et CSV : 117 lignes (16 activités actuelles, 72 historiques, 29 tests/packs hors revue complète de ce lot). Les IDs réutilisés sont distingués par mécanique. 745 rendus corrélés incluent répétitions et salons du lot précédent : ce ne sont pas 745 états uniques.
88 cycles erreur/reconnexion/quitter réussis sur fixtures. Dix vérifications game-review-flows, quatre mini-flows, trois memory-lifecycle et le parcours Petit bac erreur/réessai réussis. Types, lint, 13 tests unitaires et build réussis (avertissement de taille du bundle).
Captures ciblées 320/390 px, texte200%, naval aux six largeurs. Inspection des pixels des planches historiques, conversations, mots et planche livrée. Les cibles insuffisantes de la mosaïque détectées au premier passage sont corrigées et revérifiées.
Fixtures de progression de cinq mini-jeux créées par RPC sur PostgreSQL jetable, transaction annulée ; aucun compte réel. Les anciennes fixtures restent identifiées comme telles. Pas de nouvelle exécution de toute la suite SQL pour ces changements frontend.

## Limites
La matrice indique les résultats/révélations non disponibles ; aucune prétention à tous les coups de chaque jeu, aux lecteurs d'écran matériels, à Safari/iOS ou à deux appareils réseau réels. Les tests navigateur utilisent des réponses simulées et ne prouvent pas la sécurité serveur. Les essais de harness initialement incorrects (alias SQL, libellé de bouton, ID de session) ont été corrigés, puis réussis.
Vidéo : lecture du task Runway existant réussie, téléchargement standard de son URL officielle échoué URLError, aucun fichier local. Pas de vidéo factice ni nouvelle génération. Audio/cover/notes restent dépendants des migrations et services non déployés ; aucune promesse d'audio opérationnel en production.

## Livrable
Planche Library libfile_7c741596d0708191bd50d791a09480d1 : huit écrans réellement capturés, données fictives. Cette planche précède la correction utilisateur 21:24 (nouveaux bitmaps3D, duo enrichi, chat flottant et coffre remonté), traitée au lot suivant.
