# Système visuel et composants

Référence : direction « Complicité » (kit V1) + cahier de refonte UI/UX du 21 octobre 2026.
Tout est centralisé dans `src/styles/app.css` (jetons) et `src/components/`.

## Jetons

| Rôle | Valeur | Usage |
|---|---|---|
| `--c-bg` | #FFF8F0 | fond crème |
| `--c-surface` / `--c-surface-soft` | #FFFFFF / #FCE7DA | cartes / surfaces pêche |
| `--c-text` / `--c-text-2` | #43263E / #756672 | texte principal / secondaire |
| `--c-accent` / `--c-accent-soft` | #FF6B68 / #FFE2DA | action, sélection |
| `--c-border` / `--c-border-control` | #E5DAD2 / #8C7687 | séparations discrètes / contours de contrôles |
| `--c-focus`, `--c-danger`, `--c-success` | #593551, #A62F3E, #2F6C50 | focus, suppression, confirmation |

Contrastes mesurés (WCAG 2.2) : texte/fond 12,6:1 ; secondaire/fond 5,1:1 ; secondaire/pêche 4,5:1 ;
prune sur corail (boutons) 4,8:1 ; contours de contrôles 3,9 à 4,2:1 ; danger 6,8:1. Le blanc sur corail (2,8:1)
n'est **jamais** utilisé pour du texte. Les états (sélection, succès, erreur) ont toujours une icône ou un libellé.

Espacements 4, 8, 12, 16, 20, 24, 32, 40, 48. Marges de page : 16 (petits mobiles), 20 dès 390 px, 24 dès 768 px,
32 dès 1024 px. Rayons : 14 (boutons, champs), 20 (cartes), 24 (fenêtres). Une seule ombre, pour les éléments surélevés.

Typographie (en rem, suit la taille de texte de l'appareil) : titre public 30/36 (32/38 dès 390 px), titre de page
26/32 (24/30 sous 360 px), section 20/26, carte 17/23, texte 16/24, description 14/20, métadonnées 13/18,
navigation 12/16, boutons 16/20. Familles du kit : Nunito Sans 700 (titres), DM Sans 400–700 (texte).

Mise en page : une colonne sur mobile ; contenu plafonné à 1120 px ; formulaires 480 px ; lecture 640 px ;
listes en 2 colonnes dès 768 px et 3 dès 1024 px.

## Composants

| Composant | Fichier | Rôle |
|---|---|---|
| AppShell, TopBar, BottomNav, SubPage | `components/AppShell.tsx` | en-tête (photo + cloche à gauche, logo à droite), 5 onglets, sous-pages avec retour |
| Avatar | `components/Avatar.tsx` | vraie photo (lien signé, stockage privé) ou initiale |
| Sheet, ConfirmDialog, Toast, EmptyState, Alert, Loading | `components/ui.tsx` | fenêtres accessibles (focus gardé et rendu, Échap, bouton retour), confirmations, retours d'action |
| DuoIdentity | `duo/DuoIdentity.tsx` | ma photo + photo de l'autre ou vrai bouton « + » (Accueil et Notre espace) |
| ChatLauncher, ChatPanel, MessageList | `duo/Chat.tsx` | discussion du duo (bulle flottante, panneau, brouillon par duo) |
| NotificationCenter | `duo/Notifications.tsx` | centre de notifications (cloche) |
| InvitePanel, PendingRequest, JoinPanel | `duo/InviteScreens.tsx` | code, partage, copie, annulation ; double confirmation |
| GameCard, FilterSheet | `screens/Libraries.tsx` | carte de jeu (fiche et favori séparés), filtres à brouillon |

Navigation basse : 5 colonnes égales ; « Bibliothèques » devient « Biblio. » sous 440 px (nom accessible complet) ;
sa hauteur réelle est mesurée et réservée (texte agrandi compris) ; la bulle de discussion se place au-dessus.

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
