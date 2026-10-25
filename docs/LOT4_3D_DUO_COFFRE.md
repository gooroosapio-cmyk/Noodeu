# Lot4 — correction utilisateur 21:24

## Réalisé
48 illustrations3D bitmap originales : 45 activités auditées et trois entrées, palette cerise/bordeaux/ivoire. Fichiers WebP alpha256, 916878 octets au total. Piment rouge enflammé pour À huis clos. Inventaire par ID dans ILLUSTRATIONS_3D_LOT4.md. Art aussi utilisé dans les salons et le lancement aléatoire ; les anciens jeux hors catalogue gardent leurs ressources historiques. Les icônes de commande restent vectorielles.
Home : avatars équilibrés dans un support en relief avec médaillon duo, noms et statut réel conservés. Pas d'image décorative ajoutée au bloc. Boutons égaux sur la même ligne.
Espace : couverture compacte en haut, deux avatars, description de la partie réellement ouverte uniquement pour le duo courant, sinon état vide. Coffre remonté avant les notes, sélection Souvenirs par défaut, visible même vide. Gérer le duo discret avec cible44px. Correction du statut de présence lors de l'affichage d'un autre duo.
Salon : Discussion supprimé, description visible directement avant réglages, Description/Règles égaux et accessibles. Chat flottant unique sur accueil, jeux et sous-pages ; bande réservée hors contenu défilant, masqué sous une modal. Champ16px minimum, cibles44 conservées.
Petit bac : inspection des pixels a identifié le bouton Stop superposé aux derniers champs ; repositionné après la grille, sans recouvrement.

## Validation
Types/lint/build et 13 tests unitaires réussis. Build avec avertissement de taille du bundle existant.
24 rendus320/390px, huit rendus texte200%, vingt rendus ciblés360/430/768/1440px, quatre états de jeux390x844 : pas de débordement global, contenu masqué sous navigation, erreur JS ou petite cible signalée. Après les derniers ajustements coffre/Stop/art aléatoire : nouvelles captures ciblées et parcours dédiés.
Tests lot4 : bulle unique sur quatre routes, bande sans chevauchement, modal au-dessus/Escape, pas de Discussion salon, description visible, guides égaux, coffre visible,48 images distinctes. Petit bac faible hauteur460 : champs>=16px, Stop après dernière case. Dix parcours jeux du lot3 rejoués avec succès ; Petit bac erreur/réessai revérifié.
L'échec initial du harness était une fermeture d'historique encore en cours avant navigation, puis une attente du mauvais libellé Modifier au lieu de Gérer ; harness corrigé. Aucun défaut produit dissimulé par ces corrections.

## Limites et prudence
Les captures utilisent des données fictives et certaines fixtures historiques de catalogue : leur taxonomie ne remplace pas la dernière migration (pureté dans Se découvrir). Elles prouvent le rendu et les interactions ciblées, pas une connexion réelle à deux appareils. Pas de test Safari/iOS ou clavier mobile physique ; hauteur460 simulée seulement. Aucun nouveau test SQL nécessaire au lot purement frontend, aucune mutation de base distante.
Runway : get_task existant réussi ; téléchargement de l'URL officielle échoué URLError, aucun codeHTTP ni fichier local. Pas de nouvelle génération vidéo ni transfert incertain en cours. Vidéo réelle non intégrée. Audio, nettoyage24h, couverture et notes privées nécessitent toujours installation des dépendances/migrations non appliquées en production.
Aucun push, merge, rebase ou déploiement. Les docs de Claude apparues sur le distant ne sont pas fusionnées. Autorisation et coordination restent nécessaires pour réconciliation et publication.

Planche finale Library : libfile_d3528b9694bc819194ee3f4bc38ce243. Les huit captures ont été inspectées après correction du chevauchement Petit bac. Les contrôles normaux restent atteignables par défilement à petite hauteur ; aucune promesse de tout faire tenir sans défilement à200%.
