# Ressources visuelles intégrées

Source : dossier Drive « Noodeu_Complicite_Kit_Visuel_V1 », archive `Noodeu_Complicite_Kit_Visuel_V1.zip`
(livraison du 21 octobre 2026), téléchargée le 21 octobre 2026. **101 fichiers vérifiés un par un** contre les
empreintes SHA-256 de `docs/kit/assets-manifest.json` : aucun écart.

| Dossier du projet | Contenu | Rôle | Dimensions / usage |
|---|---|---|---|
| `public/assets/noodeu/01_Logos/` | 21 fichiers : logos couleur, prune, blanc, signature ; symbole ; favicon ; icônes PWA | En-têtes, onglet du navigateur, icône d'installation | Logo 120–170 px de large ; symbole 32–48 px ; icônes PWA 180/192/512 px à fond prune opaque (voulu) |
| `public/assets/noodeu/02_Illustrations_PNG/` | 18 illustrations PNG transparentes | **Sources** de référence (non modifiées) | 1448 × 1086 px, RGBA |
| `public/assets/noodeu/02_Illustrations_WEBP/` | 18 versions WebP générées | Affichage (≈ 30 Ko au lieu de ≈ 550 Ko) | 720 × 540 px, transparence conservée ; `scripts/optimize-illustrations.py` |
| `public/assets/noodeu/03_Icones_SVG/` | 52 icônes | Navigation et commandes (masque CSS, couleur du texte) | Grille 24 × 24, affichées en 16–24 px dans des cibles de 44 px minimum |
| `public/assets/noodeu/04_Decors_SVG/` | 10 décors | Réservés aux animations légères à venir | — |
| `docs/kit/` | Guide, inventaire, correspondance des 30 écrans, CSS et composants d'exemple | Référence d'intégration | — |

Usage des illustrations dans l'application :

| Illustration | Écran |
|---|---|
| 01 connexion à deux | Accueil public uniquement |
| 02 invitation | (plus utilisée ; le code d'invitation est l'élément principal) |
| 03 duo confirmé | (plus utilisée ; la confirmation montre la vraie initiale ou photo) |
| 04 portrait en mots | Vignette et fiche « Portrait en cinq mots » |
| 09 attente douce | Attente du partenaire, demande envoyée |
| 11 fin de partie | Fin de partie |
| 12 astuce | Astuces (en attente de publication) |
| 13 favoris | (plus utilisée : zéro résultat sans grande illustration) |
| 14 duo à créer | Plus utilisée comme faux profil : remplacée par le composant DuoIdentity (vraie photo + vrai bouton +) |
| 15 invitation expirée | Code expiré |
| 16 reconnexion | Partie injoignable, profil injoignable |
| 17 pause | Pause, partie quittée |

Non encore utilisées : 05 conversation, 06 quiz-devinette, 07 dessin créatif, 08 coopération, 10 révélation,
18 rire ensemble (prévues pour les prochains jeux et mécaniques).

Polices : Nunito Sans (titres) et DM Sans (texte), installées depuis les paquets `@fontsource` (licence SIL Open Font
License 1.1, incluse dans chaque paquet). Elles sont servies par l'application, sans appel à Google Fonts.

Les 30 maquettes PNG (`Noodeu_Complicite_30_Ecrans_PNG_V2.zip`) ont servi de références de composition ; elles ne sont
pas intégrées comme images. Correction appliquée : aucun bouton « Partager au duo » dans Astuces.

Voir aussi `docs/DESIGN.md` (inventaire des images après la refonte, rôles décoratifs/informatifs).
