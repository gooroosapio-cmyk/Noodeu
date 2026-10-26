# Noodeu — salon et consoles, proposition du 26 octobre 2026

Statut : implémentation locale à examiner. **Aucun push, fusion, déploiement ou changement de production.** Branche `codex/refonte-incrementale-20261025`. Reprise vérifiée depuis `104564da4a7d8dc5761f9616d40d8f8a1ba5f658`, correctifs serveur sauvegardés dans `96057f0` puis lot visuel complémentaire. Le SHA exact de livraison figure dans le README de l'archive.

## Références et méthode

Les dix planches `01_Salon_prive.png` à `10_Resultats_Reconnexion_FINAL.png` du dossier Drive `13_FDUUQKyd6-RMVsIWACXqGpwKnO_YG9` ont été inspectées côté parent/reviewer. Elles n'ont **pas** été vues dans cet exécuteur : les premiers transferts ont échoué par refus du tunnel HTTP403, sans fichier matérialisé. Aucun nouveau téléchargement ni contournement n'a été tenté. Le propriétaire a explicitement accepté en appel la transmission sous forme de cahier visuel détaillé. Cette révision suit ce cahier ; elle ne revendique pas une comparaison pixel à pixel avec les PNG originaux.

Les captures livrées montrent le vrai code React exécuté dans Chromium local avec des réponses RPC fictives. Les noms, réponses, scores, chronos et invitations sont des fixtures. Elles ne prouvent pas une connexion à des comptes réels. Aucun élément de maquette n'est incorporé comme écran aplati.

## Intention et résultat

Le salon était une succession de panneaux indépendants et les réponses de plusieurs jeux partageaient une présentation générique. La nouvelle composition place les deux participants au-dessus de l'activité, distingue l'objet illustré, les réglages et l'action principale, et utilise des objets et matériaux adaptés à chaque mécanique. Les surfaces de commande restent cerise/bordeaux ; les objets ont leurs couleurs naturelles. Le logo à deux mains, Nunito Sans et DM Sans sont conservés. Les tokens actifs `#F7F1F1`, `#B72132`, `#43131C` et les états sémantiques succès/erreur n'ont pas été remplacés.

Le bouton rouge Réduire conserve la séance et revient à l'application. Pause et Quitter restent distincts ; Quitter demande confirmation. Les parties n'affichent pas la navigation principale. Le chat conserve une bulle sans dock ; si le contenu remplit l'écran, une place lui est réservée dans l'en-tête. Les régions de texte, réponses, fleur et grilles sont protégées contre son recouvrement, y compris en lecture seule. Le panneau de chat/modal passe au premier plan.

## Fidélité et écarts justifiés

| Planche | Transposition réelle | États contrôlés et écarts |
|---|---|---|
| 01 Salon | Fauteuils 3D dans le parcours d'invitation existant ; portraits, statuts réels, jeu illustré, description visible, Description/Règles égaux, paramètres serveur, disponibilité/lancement | Invitation, préparation, partenaire prêt, règles, refus, hors ligne. Pas de second système de salon ni faux sélecteur 2×2 : la partie existante est liée à une activité, choisie dans la bibliothèque. Code/copie/partage restent dans l'invitation de duo. |
| 02 Questions / questionnaires | Papeterie et enveloppe, réponse confortable, compteur ; partage/privé/passer conservés. Échelles et pagination issues du serveur | Questions longues, réponses longues, attente/révélation, échelle7/page3 et cinq items existants. Aucun quiz à corrigé objectif n'est présent dans le catalogue final inspecté : notamment H05 est explicitement un pack de questions ouvertes. Aucun corrigé, score ou chrono fictif n'a été inventé. |
| 03 A/V / Jamais / Tu préfères | Pile de cartes, choix A/V dédiés, action/vérité/passé ; jetons égaux ; deux portes et deux choix équilibrés, validation séparée | Sélection, validation, attente, révélation, passage. Les objets sont décoratifs ; ils ne prédisent pas la réponse. Refus sans pénalité, avertissement +18 court conservé. |
| 04 Qui / Devine / Opinions | Médaillons des vrais avatars/noms sur socles ; enveloppe et rôles ; balance avec deux jetons égaux | Choix, réponse/prédiction, verdict serveur, opinions sans justesse. Les captures utilisent des initiales car les fixtures n'ont pas de photo. Les panneaux révélés gardent la palette commune, sans surface pêche héritée. |
| 05 Complète / G08 | Papier/amorce et champ intégré ; masque et trois cartes, trois champs numérotés, radios privés du mensonge, deux prêts puis devinette | **G08 simultané**, 4/6/10 manches existantes. Mensonge et texte adverses restent privés avant le moment prévu. Le formulaire complet défile sur petit écran ; pas de champs coupés pour tenir artificiellement. |
| 06 Morpion / Points / PFC | Plateau céramique, X/O 3D et trait serveur ; panneau, segments et initiales ; trois gestes égaux et choix adverse opaque | Morpion en cours/fin/égalité, Dots5 et Dots12, PFC verrou/révélation/reprise. Dots12 =144 points/121 cases/264 segments. Vue entière en lecture seule ; mode de jeu avec cibles44/66px, zoom et déplacement. |
| 07 Naval | Grille lisible, flotte propre 3D, empreinte valide/invalide, rotation/auto-placement existants, cible confirmée avant tir, impact et journal | Placement, tir, flotte, raté/touché/coulé, retour réseau. Seules les positions de sa propre flotte sont utilisées. La couleur des surfaces suit Noodeu plutôt que le bleu de la référence. La confirmation ne change plus au simple survol après sélection. |
| 08 Pendu / Petit bac | Fleur en pot 3D, tuiles, clavier AZERTY ; lettre/chrono/8 rubriques2×4 ; comparaison en huit cartes de deux réponses | Fleur : un pétale par erreur confirmée, aucun retrait optimiste/rejeu au rechargement. Bac : saisie, STOP, arbitrage, inconnu «À vérifier», contestation et score. Grille/clavier défilent si nécessaire ; clavier logiciel physique non testé. |
| 09 Pig / Cite trois | Plateau céramique et dé serveur ; acquis/provisoire distincts ; chrono 3D, répondant, consigne, verdict+3/0 | Pig acquis conservés sur1, doubles clics, reprise. Cite trois : appel, accusé de réception, jugement, interruption/expiration, erreursHTTP503 et réessais bornés. Aucun enregistrement ni reconnaissance vocale simulée. |
| 10 Résultats / reconnexion | Objets du jeu et coupe sobre, résultat et scores serveur, Rejouer/Retour séparés ; état conservé et bannière de connexion | Résultats et détails accessibles, pause/reprise, erreurs API avec navigateur en ligne, réconciliation sans rejouer les animations rattrapées. Pas de défaite déduite d'une déconnexion. Le retour au calme ne chevauche plus le résultat. |

Les questions et réponses restent intégrales dans le DOM. Une question longue se lit dans une région de défilement au clavier, avec indicateur de débordement ; la longueur ne déplace pas les commandes. Ce choix répond à la contrainte contradictoire de lecture complète et de commandes stables sans réduire le corps à une taille illisible. Corps14–18px selon rôle, saisies16px minimum, cibles44px minimum, reflow à200%. Les nouvelles animations sont courtes et désactivées en mouvement réduit ; elles suivent le résultat serveur.

## Ressources originales

Quatre objets 3D ont été générés pour cette révision, inspectés sur fond du thème, séparés et optimisés en WebP alpha512×512 :

- `refinement3d/opinions-balance.webp` : équilibre sans notion de bonne opinion, 52 144 octets.
- `refinement3d/truths-mask.webp` : masque et trois cartes vierges, 42 350 octets.
- `refinement3d/salon-chairs.webp` : deux fauteuils et table, 35 162 octets.
- `refinement3d/result-cup.webp` : coupe et jetons, 45 146 octets.

Total ajouté :174 802 octets. Source, dimensions, empreintes et provenance : `public/assets/original/refinement3d/PROVENANCE.json`. Le master PNG généré reste dans `/workspace/generated_images`, hors assets de production et hors archive compacte. Ce sont des créations générées pour Noodeu, sans emprunt d'actif WePlay ni affirmation de licence tierce. Les14 pièces3D de plateau, les gestes PFC et les illustrations de bibliothèque existantes sont réutilisés. Points, segments, socles, papier et petites animations sont des composants CSS/SVG, pas présentés comme des images3D générées.

Le clip `noodeu-fleur-refinement-demo.mp4` est une capture du fonctionnement local avec réponses serveur simulées. **Ce n'est pas la vidéo Runway de lancement**, qui demeure absente et n'a entraîné aucune nouvelle dépense.

## Validation exécutée

Les dimensions exactes des campagnes sont dans les fichiers JSON de preuves ; les totaux suivants ne représentent pas des tests sur téléphones physiques.

- Lint, TypeScript, build de production et13 tests unitaires : réussis.
- Salon :11 groupes fonctionnels existants, disponibilité/paramètres/refus/double clic/absence réseau/retour/fermer/film absent.64 vues des salons et états communs, puis16 vues ciblées résultats/Naval après correction. Profils320/360/390/430/768/1440, petite hauteur390×460, texte320 à200%.
- Cartes :28 vues390×780/320×780 à200%, payloads de choix, G08 privé, pack partager/privé/passer, formats7choix/page3.15 cas supplémentaires de lecture intégrale et6 cas de layout : réussis.
- Mini-jeux :72 vues, 4largeurs×100/200%×9états ;10 groupes nouveaux et13 groupes existants : réussis. Dots ancien25/16/40 et nouveau144/121/264, pan sans coup, dernier segment, clavier, cibles44/66, un seul RPC sur double clic Pig, flotte privée, confirmation du placement figée après clic.
- Mots :60 vues, 10états×6profils ;10 flux finaux, dont véritables réponsesHTTP503 simulées pour accusé/tick, reprise bornée et maintien du délai initial. Régressions fleur, expiration et erreurs Petit bac : réussies.
- Console :7 groupes, Réduire/Reprendre sans mutation, Pause distincte, Quitter confirmé, saisies/attente/révélation, petite hauteur/200% : réussis.
- Transport :3 parcours Pig/Naval/Pendu, coup normal animé, panne API navigateur en ligne, rattrapage sans animation et nouveau coup animé : réussis.
- Chat :16 contextes×3positions protègent textes/grilles ; accueil320/390/430×5positions et modal : réussis. La composition Home n'a pas été modifiée.
- Serveur :16 fichiers SQL C18–C32, quatre courses réellement exécutées sur connexions PostgreSQL distinctes, upgrade5→draft12 et activation optionnelle transactionnelle : réussis.92 versions publiées et leurs pointeurs sont restés inchangés hors transaction de test. Détails : `SERVER_GUARDS_DOTS12_20261026.md` et `_EVIDENCE.json`.

Échecs rencontrés et traités : ancienne garde C28 refusant le nom de nouvelle base jetable, ancien C19 avalant une assertion (preuve par mutation), ancien validateur acceptantNULL/clés inconnues ; choix visuels trop étroits, chevauchement résultat/retour au calme, chat sur zones en lecture seule, placement naval modifié au survol, libellé naval «réponse validée» inapproprié et reprise Cite troisHTTP503. Deux tests de navigateur étaient obsolètes : assertion Pause avant réception effective de la requête et ancien nom d'animation navale ; ils attendent maintenant le vrai événement et la nouvelle animation, puis passent.

Le build conserve un avertissement de chunk JS >500kB : environ1 046kB brut/288kB gzip lors de la validation. Pas de mesure de performance sur appareil bas de gamme ni de promesse60fps. Aucun compte réel, appareil Android/iOS physique, clavier logiciel réel, déploiement Supabase/Vercel ou connexion Realtime de production n'a été testé.

## Serveur et activation restant au propriétaire

`20261029000900_session_settings_validation.sql` rejette les clés inconnues, contrôle le type et les options exactes, canonicalise4.0→4, remet les deux disponibilités à zéro une seule fois si modification. Le test G08 ne masque plus l'assertion de confidentialité.

`20261029001000_dots12_versioned.sql` prépare une version12 **non publiée et non courante**. Les séances5 existantes continuent avec leur version. L'interface peut rendre les deux contrats. Pour proposer les nouvelles parties12 après validation, le script `supabase/optional/activate_dots12_after_validation.sql` est séparé des migrations automatiques ; il publie/bascule uniquement la version attendue et refuse une divergence. Il a été testé avec rollback, jamais appliqué de façon persistante.

Les dépendances des lots précédents restent à contrôler :001 espace/notes/couverture,002 audio,003 tirage par paquets,004 questions aléatoires mixtes,005–006 question horaire/catalogueHome,007 normalisation Petit bac,008 validation navale. Ne jamais rejouer les anciennes purges ni `scripts/run_sql_tests.sh` sur un projet réel. Les scripts protégés `tests/sql/server_regression.py` et `server_concurrency.py` exigent une base Docker locale marquée ; ils refusent une cible de production.

Audio demeure désactivé. Sa mise en service exige les dépendances privées, l'Edge de lecture, le worker et la suppression effective objets+métadonnées24h, avec contrôle des URLs/cache et autorisation distincte du scheduler. Google demeure un emplacement non opérationnel. La vidéo de lancement n'est pas intégrée. Les avertissements sur les droits de banques, l'ordre des tests/Aron/P20 et les règles de partage explicite sont conservés.

Après validation des nouveaux aperçus seulement : récupérer le distant, préserver et réconcilier les derniers commits Claude/Admin, vérifier l'état réel des migrations/configurations, refaire les contrôles sur la version réconciliée puis suivre la publication autorisée. Ce rapport ne donne pas cette autorisation.
