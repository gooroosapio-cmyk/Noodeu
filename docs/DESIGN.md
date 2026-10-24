# Système visuel et composants

Référence actuelle : **interface v2** (première proposition pastel, version compacte, 24 octobre 2026),
dossier Drive « interface v2 ». Elle remplace les tailles et la densité de Cocon Pastel V5 et des kits précédents.
Priorité : `05_Composants/tokens.json` et `noodeu-ui.css` du kit, puis `00_Guides/REGLES_PRODUCTION.md`, puis les maquettes.
Tout est centralisé dans `src/styles/app.css` (jetons) et `src/components/`.

## Jetons

| Rôle | Valeur | Usage |
|---|---|---|
| `--c-bg` / `--c-surface` | #FCF8F4 / #FFFFFF | fond / cartes |
| `--c-text` / `--c-text-2` | #30283E / #685C74 | texte principal / secondaire |
| `--c-accent` / `--c-accent-down` | #7654BD / #62439F | action principale (texte blanc) / action pressée, focus |
| `--c-peach`, `--c-sage` (menthe), `--c-lavender`, `--c-butter` | #FFE3D1, #D8EFE6, #E8DEF5, #FFF0BA | tuiles et bannières |
| `--c-border` / `--c-border-control` | #E8E0EB / #9B89A6 | séparation décorative / bordure de champ |
| `--c-success`, `--c-danger` | #24664D, #A83948 | confirmation, erreur |

Relief discret : bord inférieur de 2 px sur les tuiles et le bouton principal ; ombre de surface `0 2px 8px #30283E0F`.
Rayons : tuile 14, bouton 12, champ 10, panneau 18, fenêtre basse 22.

Typographie (rem, suit la taille de texte de l'appareil) : titre de page 22/28, section 17/22, catégorie 16/20,
tuile de jeu 14/18, texte 14/21, question 20/27, bouton 14/18, saisie 16/22, aide 12/18, navigation 11/14, score 28/34.
Nunito Sans 700 (titres, boutons) ; DM Sans (texte, champs), polices auto-hébergées (OFL).

Mesures : marges 16 (12 sous 360 px), grille 10 (8 sous 360 px), catégorie horizontale ≈ 74 px, tuile ≥ 72 px,
boutons et champs ≥ 44 px, icônes 20 px dans une cible de 44 px, navigation ≥ 64 px + zone sûre.
Contenu centré, largeur maximale 600 px. Aucun `transform: scale` global ; les cartes grandissent avec le texte.

## Ressources

- `public/assets/v2/art/*.webp` : les 53 illustrations nommées du manifeste, **découpées cellule par cellule** dans
  les huit atlas PNG du kit (aucune planche complète n'est affichée). Nom = clé du manifeste (C01, G01, M07,
  RICE100, c01-aron36, duo-hands…). Composant `Art`.
- `public/assets/v2/icones/` : icônes Lucide du kit (licence ISC jointe), renommées selon les noms du code ;
  neuf icônes absentes de Lucide (chevron-up, skip, eraser, puzzle, cards, leaf, quote, bookmark-filled, gift)
  reprennent celles du kit précédent. Composant `Icon` (masque CSS, hérite de la couleur).
- Illustration d'une activité : pack → `c01-*`, questionnaire → instrument (`IPIP50`…), C03/C04 → code de référence.
- Les pièces de jeu natives (`06_Jeux` : pions, dés, navires, étapes du Pendu…) serviront aux mini-jeux des lots 2 et 3.

## Bibliothèque

Ordre imposé : C01 « Se découvrir » puis C02 « Mieux se comprendre » en catégories horizontales empilées, qui ouvrent
la liste de leurs packs ; C03 « Conversation et découverte » et C04 « Mini-jeux » en grilles à deux colonnes ;
« À huis clos » en dernier, visible seulement après activation personnelle dans Réglages. Recherche conservée.


## Composants

| Composant | Fichier | Rôle |
|---|---|---|
| AppShell, TopBar, BottomNav, SubPage | `components/AppShell.tsx` | en-tête (photo + cloche à gauche, logo à droite), 5 onglets, sous-pages avec retour |
| Avatar | `components/Avatar.tsx` | vraie photo (lien signé, stockage privé) ou initiale |
| Sheet, ConfirmDialog, Toast, EmptyState, Alert, Loading | `components/ui.tsx` | fenêtres accessibles (focus gardé et rendu, Échap, bouton retour), confirmations, retours d'action |
| DuoIdentity | `duo/DuoIdentity.tsx` | ma photo + photo de l'autre ou vrai bouton « + » (Accueil et Espace) |
| ChatLauncher, ChatPanel, MessageList | `duo/Chat.tsx` | discussion du duo (bulle flottante, panneau, brouillon par duo) |
| NotificationCenter | `duo/Notifications.tsx` | centre de notifications (cloche) |
| InvitePanel, PendingRequest, JoinPanel | `duo/InviteScreens.tsx` | code, partage, copie, annulation ; double confirmation |
| ShelfBanner, TileGrid, GameTile, PackList, ShelfPage | `screens/Libraries.tsx` | catégories horizontales, grille à deux colonnes, listes de packs |
| QuestionnairePlaying, QuestionnaireResults | `game/board/QuestionnaireGames.tsx` | carte commune des packs (réponse privée, partage, révélation), questionnaires paginés et résultats |
| Art | `components/ui.tsx` | illustration découpée du kit interface v2 |

Navigation basse : Accueil, Bibliothèque, Conseils, Espaces, Réglages ; 5 colonnes égales, onglet actif en violet sur
pastille lavande ; sa hauteur réelle est mesurée et réservée (texte agrandi compris) ; la bulle de discussion se place au-dessus.

## Images

| Ressource | Usage | Type | Taille max | Alt / repli |
|---|---|---|---|---|
| Logo couleur SVG | en-tête (104 px), accueil public (120 px) | informatif (lien « retour à l'accueil ») | 120 px | « Noodeu » |
| 01 connexion à deux | accueil public | décoratif | 200 px de haut | alt vide |
| 04 portrait en mots | vignette de jeu 68–72 px | décoratif (le titre est à côté) | 72 px | alt vide |
| 09 attente, 11 fin, 12 astuce, 15 expirée, 16 reconnexion, 17 pause | états | décoratif | 200 px | alt vide |
| Photo de profil | en-tête, duo, parties | personnelle (stockage privé) | 512 px enregistrés | initiale si absente ou en échec |

Remplacé : l'illustration « personne + cercle + » (14 duo à créer) ne sert plus de faux profil ; elle est remplacée
par le composant `DuoIdentity` (vraie photo + vrai bouton d'invitation). Aucune image ne contient de texte fonctionnel.
