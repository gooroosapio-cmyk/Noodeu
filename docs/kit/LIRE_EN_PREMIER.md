# Noodeu — Kit visuel Complicité V1

Livraison du 21 octobre 2026, destinée à l’intégration par Claude.

Le kit contient 18 illustrations PNG à fond transparent, 52 icônes SVG, 10 décors SVG, 9 sources SVG de marque et 12 exports PNG de marque. Les variantes de logo conservent le principe Complicité : bulles reliées, nom arrondi, double o en boucle. Le tracé vectoriel est une reconstruction de production ; il n’est pas une extraction pixel à pixel des anciennes maquettes générées.

## Commencer

1. Ouvrir `06_Previews/Galerie_Noodeu.html` après extraction de tout le ZIP.
2. Lire `05_Integration/GUIDE_CLAUDE.md` puis `05_Integration/PROMPT_CLAUDE.txt`.
3. Copier les dossiers 01 à 04 dans `public/assets/noodeu/` en gardant leurs noms.
4. Adapter les exemples CSS et React à l’application existante.

## Organisation

- 01_Logos : logos couleur, monochromes et signature ; symbole ; favicon ; icônes PWA.
- 02_Illustrations_PNG : un fichier distinct pour chaque illustration, alpha conservé.
- 03_Icones_SVG : navigation et commandes, grille 24 × 24, trait arrondi.
- 04_Decors_SVG : halos, rayons, cœur, lien, confettis et feuilles.
- 05_Integration : guide, prompt, code de départ, inventaire et correspondance des 30 écrans.
- 06_Previews : galerie locale et planches de contrôle, jamais utilisées comme interface.

## Décisions produit à conserver

Navigation : Accueil, Bibliothèques, Astuces, Notre espace, Paramètres. Le jeu n’est pas un onglet. Le salon est intégré à l’écran du jeu.

Les astuces sont personnelles : conseils, anecdotes, proverbes et découvertes en cartes courtes dans un carrousel vertical. Aucun espace partagé ni bouton « Partager au duo » à importer de la précédente proposition UI V2. Cette correction prime sur ces anciennes maquettes. Les citations et anecdotes doivent être sourcées dans les données éditoriales ; les illustrations ne contiennent pas de contenu factuel.

Les images n’intègrent aucun texte fonctionnel : titres, noms, dates, scores, champs et actions restent en HTML. Les exceptions sont le logo de marque et son slogan.

Toutes les illustrations sont transparentes. Les icônes d’installation PWA ont volontairement un fond prune opaque pour les lanceurs Android et iOS. Les planches de prévisualisation ont un fond, et ne sont pas des ressources de production.
