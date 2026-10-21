# Guide d’intégration

## Priorité des ressources

Ce kit fournit des ressources de production. Les maquettes précédentes restent des références de composition. Le code doit reconstruire les composants accessibles et responsive, pas afficher les captures comme écrans. Les règles éditoriales et mécaniques des jeux restent celles des documents produit actualisés ; le kit ne définit pas leur contenu.

Correction de la V2 : Astuces est un espace individuel de lecture et découverte. Garder Enregistrer, la source et les commandes Suivante/Précédente. Retirer les vues de partage au duo et les transferts vers le salon. Le salon reste uniquement un élément des jeux.

## Installation

Copier 01_Logos, 02_Illustrations_PNG, 03_Icones_SVG et 04_Decors_SVG sous public/assets/noodeu/. Charger noodeu.css une seule fois. Importer et adapter NoodeuVisuals.tsx si le projet utilise React. Ce fichier n’est pas une application et ne contient ni routage complet, ni connexion réseau.

Ne pas utiliser Drive comme serveur de ressources : télécharger les fichiers, les versionner dans le dépôt, puis les servir depuis l’application. Ne pas charger simultanément l’ensemble des 18 PNG au premier écran. Précharger uniquement l’illustration immédiatement utile ; charger les autres à la demande. Une conversion WebP/AVIF conservant l’alpha peut être ajoutée au build après comparaison visuelle ; conserver les PNG sources.

## Marque

Logo principal : noodeu-logo-couleur.svg sur ivoire ou blanc. Variante prune sur fond clair monochrome ; variante blanc sur prune. Taille de logo proposée 140 à 170 px de large en en-tête, minimum 120 px. Utiliser le symbole à 32–48 px et le favicon simplifié à 16–32 px. Réserver autour du logo environ la moitié de la hauteur du symbole. Ne pas étirer, ajouter de contour, d’ombre ou changer les proportions.

La signature est destinée aux pages d’accueil larges ; éviter le slogan minuscule dans un en-tête mobile. Les logos SVG n’ont pas de dépendance à une police. Les formes de marque sont figées ; ne pas les retaper avec une police approchante.

Les fichiers app-icon 192 et 512 ont un fond opaque volontaire. L’icône 180 sert à apple-touch-icon. Ajouter les entrées de manifest-icons.example.json au manifeste existant, sans en remplacer les routes, scope ou start_url. Le symbole est centré et éloigné des bords pour la découpe système.

## Couleurs et typographie

Ivoire #FFF8F0 : fond ; prune #48283D : texte et pictogrammes ; corail #FF716B : action ; abricot #F4C6AE : surfaces secondaires. Texte prune sur les boutons corail. Ne pas utiliser le corail clair pour un petit texte sur ivoire. Un état sélectionné se lit avec un libellé ou une coche en plus de la couleur.

Nunito Sans 700/800 pour les titres et DM Sans 400/500/600 pour le corps sont les polices cibles. Les fichiers de police ne sont pas inclus. Les installer depuis leur distribution autorisée dans le projet et conserver leur licence. Les exemples utilisent system-ui en repli. Corps de texte 16 px minimum ; titres 28–36 px. Vérifier les cinq libellés de navigation à 320 px et avec le zoom texte, sans les tronquer : l’agrandissement peut augmenter la hauteur de barre.

## Illustrations

Fonds alpha réels. Garder le ratio du fichier et object-fit: contain. Largeur courante 220–320 px en état vide ou accueil ; 96–160 px en carte. Conserver width et height pour réserver la place. Un décor redondant avec le titre porte alt="" ; utiliser l’alt descriptif du manifeste seulement si l’image transmet un sens absent du texte.

Les illustrations sont fixes. Pour les animer, utiliser un mouvement très léger du conteneur ou créer ultérieurement des calques ; ne pas déplacer artificiellement un bras isolé d’un PNG aplati. Les décors SVG sont séparés pour permettre de légères animations locales. Les cartes des illustrations sont décoratives : elles ne remplacent jamais de vraies cartes interactives.

## Icônes

52 fichiers sur une grille 24 × 24. Taille de rendu 20–24 px, cible tactile d’au moins 44 × 44 px. Le composant fourni utilise un masque CSS pour hériter de currentColor ; un SVG chargé par img garde sa couleur interne prune. Pour une icône informative seule, fournir un nom accessible. Dans un bouton déjà nommé, masquer l’icône aux lecteurs d’écran. Un même symbole garde le même sens dans tout le produit.

## Composants et mouvement

Bouton principal 52 px, cartes arrondies 24 px, champs 16 px, espacements 8/12/16/24/32. Animations locales 160–220 ms. Les trois points de chargement indiquent une opération en cours ; ils ne représentent pas une progression chiffrée. La présence réelle vient du serveur. La pulsation de cœur n’est exécutée qu’une fois après une action volontaire. Toutes les animations s’arrêtent avec prefers-reduced-motion.

Astuces : une carte courte à la fois, sans minuterie automatique. Glissement vertical et commandes accessibles. La fin d’une sélection est explicite. Préserver la position de lecture et les favoris personnels. Aucun texte factuel ne doit être inventé pour remplir un composant.

Jeu : montrer Salon et Pause ; garder les contrôles Passer et confirmation selon la mécanique. Le salon est une feuille liée à la session, sans perte de brouillon à sa fermeture. Les valeurs affichées et les scores ne viennent jamais des illustrations.

## Vérifications avant livraison

- Ressources chargées sans erreur, dimensions réservées et transparence intacte sur ivoire et prune.
- Logos lisibles aux petites tailles et icônes non rognées.
- Parcours à 320/390/430 px, clavier ouvert, zoom texte et lecteur d’écran.
- Boutons focusables, noms accessibles, absence de contenu essentiel dans une image.
- États désactivé, envoi, erreur, reconnexion, pause et reprise liés au vrai état de l’application.
- Aucun chargement massif des images hors écran ; mesurer le poids réellement transféré.

## Inventaire

assets-manifest.json contient le chemin, la taille en octets et SHA-256 de chaque ressource. ecrans-assets.csv associe les 30 vues précédentes aux images réutilisables. generation-prompts.json documente la création des illustrations avec le générateur intégré. Les SVG natifs ont été dessinés en code ; leur usage ne nécessite pas d’IA à l’exécution.
