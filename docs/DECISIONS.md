# Décisions

Ordre de priorité : réponses récentes de la porteuse ou du porteur du projet > cahier des charges > documents validés > anciennes propositions.

## Décisions produit (questionnaire du 21 octobre 2026)

| # | Sujet | Décision |
|---|---|---|
| 1 | Hébergement | **Vercel** (offre gratuite) |
| 2 | Connexion | **E-mail + mot de passe, et Google** (Google à configurer, voir DEPLOIEMENT.md) |
| 3 | Rythme de jeu | **Direct et différé** : chacun répond quand il veut ; la révélation a lieu quand les deux ont terminé |
| 4 | Salon privé | **Fil de texte + messages vocaux liés à la partie, effacés à sa clôture** (texte livré, vocal à venir) |
| 5 | Vocal / dessin | **Les deux dès la V1** (prévu à l'étape 5, après la première tranche) |
| 6 | Public | **Adultes**, niveau « intime » **facultatif**, actif seulement si les **deux** l'acceptent |
| 7 | Premier jeu | **Portrait en cinq mots** |
| 8 | Séparation | **Chacun garde une copie en lecture seule** de l'historique commun |
| 9 | Suppression de compte | Les données communes suivent la règle 8 : l'autre garde l'historique en lecture seule |
| 10 | Souvenirs | **Historique + réponses que les deux ont choisi de garder** |
| 11 | 500 stories | **Import en brouillon**, validation par lots dans l'administration |
| 12 | Notifications | **Push web** (fiables sur Android ; iPhone seulement si l'app est installée) — à venir |
| 13 | Langue | **Français**, textes centralisés (`src/i18n/fr.ts`) pour une traduction future |

Interprétation signalée : la réponse « 1c » a été lue comme **2C** (connexion e-mail + Google).

## Décisions imposées par le cahier des charges ou le kit

- Navigation : exactement cinq onglets (Accueil, Bibliothèques, Astuces, Espace, Réglages). Le jeu et le salon n'en font pas partie.
- Parcours d'un jeu : sélection → règles et réglages → salon (préparation) → partie → résultat → rejouer / autre jeu / accueil.
- Astuces : rubrique strictement personnelle (aucun partage au duo).
- Pas d'IA appelée pendant les parties, pas de paiement, pas de service payant supplémentaire.

## Décisions techniques

- **Stack** : dépôt vide au départ. React + TypeScript + Vite + Supabase : simple, sans serveur à maintenir, et l'application finale est un site statique hébergeable gratuitement.
- **La base fait autorité** : toutes les transitions (participation, début, réponses, révélation, fin, clôture) passent par des fonctions PostgreSQL (`supabase/migrations/…300_sessions_engine.sql`). Le navigateur ne peut rien écrire directement dans les tables de jeu.
- **Secrets protégés à la source** : les réponses du ou de la partenaire ne sont jamais envoyées au navigateur avant la révélation, que ce soit par les tables (règles d'accès), par les fonctions ou par le temps réel (les signaux ne contiennent aucun contenu).
- **Temps réel = simple signal** : la base diffuse « quelque chose a changé (version N) » sur un canal privé ; chaque navigateur relit alors l'état autorisé. En secours, relecture périodique (4 s si le temps réel est coupé, 20 s sinon) et au retour au premier plan.
- **Idempotence** : une seule partie ouverte par couple, une seule réponse par étape, identifiant client pour les messages. Double clic, deux onglets ou réessai après coupure ne créent pas de doublon.
- **Aucune minuterie** dans la première tranche (« aucun chrono ne tourne »). Si des minuteries arrivent, leur échéance sera stockée côté serveur.
- **Invitation en deux confirmations** : la personne invitée saisit le code et confirme ; la personne qui invite confirme ensuite (« Confirmer mon duo » / « Ce n'est pas mon partenaire »). Code de 8 caractères sans caractères ambigus, valable 24 h, une seule utilisation, révocable, blocage après 8 essais erronés en 15 minutes.
- **Contenus figés** : une version de jeu publiée est immuable ; une partie garde la copie de ses cartes.
- **Hors connexion** : seule l'interface est mise en cache. Aucune donnée de couple, réponse ou message n'est stockée hors ligne. Une partie n'est jamais simulée sans réseau.
- **Brouillons** : la sélection en cours est gardée dans `sessionStorage` (survit au rafraîchissement, effacée à la fermeture de l'onglet).
- **Écriture** : formulations neutres plutôt qu'écriture inclusive avec point médian ; les mots des jeux s'accordent selon la forme choisie par chaque personne (féminin, masculin ou les deux).

## Refonte UI/UX (cahier du 21 octobre 2026)

Le cahier « Noodeu — Prompt complet de refonte UI/UX » prime sur les choix antérieurs qu'il contredit :

- **Vocabulaire « duo »** : deux joueurs ne forment pas forcément un couple. « Inviter quelqu'un », « Ton duo ».
  Les tables gardent leurs noms techniques (`couples`) ; l'interface parle de duo.
- **Un duo actif, plusieurs duos archivés** ; une même paire retrouve son espace après une nouvelle acceptation
  des deux (nouvel « épisode », dates affichées). Terminer un duo : décision d'un seul membre, l'autre est prévenu.
- **Discussion** (remplace la décision 4B « salon effacé à la fin de la partie ») : une seule messagerie, liée au duo,
  accessible par la bulle flottante et depuis le jeu. Les messages restent consultables dans l'archive du duo,
  en lecture seule. *À confirmer : souhaites-tu une durée de conservation limitée pour ces messages ?*
  Messages vocaux : toujours à faire.
- **Notifications** : centre interne (cloche), sans notification push pour l'instant.
- **Google** : le bouton n'apparaît que si le fournisseur est activé dans Supabase (aucun faux bouton).
- **Photo de profil** : stockage privé, lisible par soi et les personnes de ses duos ; recadrage dans le navigateur.
- **Suppression de compte** : fonction serveur `delete-account` (termine le duo, efface photo et compte ;
  l'historique commun reste chez l'autre avec la mention « Compte supprimé »).
- **Couverture de duo** : non ajoutée (facultative dans le cahier) ; surface sobre à la place.
- Ancienne table du salon (`session_messages`, vide) : mise hors service, pas supprimée ; suppression possible
  par une migration séparée avec ton accord.

## Salon : page distincte (confirmé)

Essai d'un onglet « Salon » remplaçant « Espace » annulé à la demande de l'utilisatrice ou de l'utilisateur :
« Reste sur ta logique de base onglet notre espace et le salon une page distincte pour patienter avant le début du jeu ».
- 4e onglet : **Espace** (duo, discussion, historique).
- **Salon de la partie** : page distincte `/partie/:id` (hors onglets) où l'on patiente avant le début du jeu.

## Ajustements d'interface (accueil, en-tête, bibliothèque)

- En-tête : **logo à gauche**, notifications puis photo de profil **à droite**.
- 4e onglet renommé **« Espace »** (`/espace`) ; `/notre-espace` redirige en conservant les paramètres.
- Carte principale de l'accueil : les deux éléments (ma photo et le bouton « + » ou la photo de l'autre) et le texte sont **centrés**.
- Accueil réorganisé en rubriques : carte du duo (ou de l'invitation) → « En ce moment » (partie ouverte) → « Tes favoris » → « À découvrir » / « Pour votre prochaine partie ». Pas de rubrique qui répète les onglets.
- Bibliothèques : seulement le **champ de recherche** et un bouton **« Filtres » déroulant** (Afficher tous/favoris, familles, durée, niveau, tri ; appliqué immédiatement, « Réinitialiser » et « Fermer »). Sous-titre, puces rapides, tri séparé et compteur visibles supprimés (le nombre de résultats reste annoncé aux lecteurs d'écran).
- 5e onglet renommé **« Réglages »** (plus court que « Paramètres ») ; `/reglages`, et `/parametres` redirige.

## Édition 2.1.0 — 144 activités (cadrage du 21 octobre 2026)

Réponses au QCM : 1b, 2b, 3a, 4 (variante), 5a, 6b, 7a, 8a (V1), 9a, 10a.

| # | Décision |
|---|---|
| 1 | **Famille 1 (Complicité et confidences) d'abord**, entièrement (18 activités), puis famille par famille. |
| 2 | Activités pas encore programmées : **visibles mais grisées, « Bientôt »**, non lançables (le serveur refuse aussi). |
| 3 | La démo « Portrait en cinq mots » est **remplacée** par N2-005 « Cinq mots, vraiment toi » ; les parties passées restent dans l'historique. |
| 4 | Bibliothèque : recherche + **puces visibles Tous / Ensemble / Duel** + panneau déroulant pour le reste (famille, mode, difficulté, mode muet, +18, favoris, tri). « Ensemble » = échange, création et coopération. |
| 5 | +18 : **double accord** — l'interrupteur des Réglages autorise, puis les deux l'activent dans les options de la partie. |
| 6 | **Solo autorisé** pour les casse-tête et la mémoire (familles 4 et 5 quand la fiche s'y prête) ; le reste se joue à deux. |
| 7 | Direct obligatoire pour vitesse/mémoire ; tour par tour, casse-tête et histoires jouables chacun à son moment. |
| 8 | V1 : **pas de micro** ; texte, toucher, sons synthétisés localement. |
| 9 | Créations sauvegardées dans l'Espace **sur accord des deux**, export PNG, jamais publiées automatiquement. |
| 10 | Historique : titre, date et résultat gardés ; réponses et contenus détaillés **effacés 24 h après la fin**, sauf « Garder ce souvenir » des deux. |

Noms d'onglets : le kit écrit « Notre espace » et « Paramètres » ; les choix du projet (« Espace », « Réglages »)
priment (consignes présentes > kit).

### Architecture retenue

- Les moteurs restent **côté base (PL/pgSQL)**, comme le moteur existant : transactions, verrou de partie,
  idempotence, tests locaux complets. Les réponses de l'autre ne sortent qu'après la révélation.
- Famille 1 : moteur générique « manches à étapes » (carte ou tirage par manche, étapes privées par siège ou par rôle,
  étapes visibles immédiatement ou à la révélation, réactions après révélation). Chaque activité a sa configuration et
  ses validations propres côté serveur.
- Préférences de partie privées (+18, thèmes à éviter) stockées par joueur, illisibles par l'autre ; seule leur
  combinaison filtre le tirage (`+18 si A et B`, exclusions = union).
- Catalogue importé par un script idempotent (`scripts/import_catalogue.py`) qui produit une migration de données et
  un rapport ; vignettes SVG copiées dans `public/assets/jeux/` (aucun appel à Drive).

## Nouvelle base : catégories 1 à 4 (cadrage du 24 octobre 2026)

Sources : Drive Noodeu (01_Se_decouvrir, 02_Mieux_se_comprendre, 03_04_Conversation_et_Mini_jeux,
05_Ressources_communes), point d'entrée `00_PROMPT_CLAUDE_CATEGORIES_1_4.txt`.

| # | Question | Décision |
|---|---|---|
| 1 | Ancienne base (145 activités) | Purge complète puis import neuf. La purge doit être collée dans l'éditeur SQL du projet Noodeu (l'outil en ligne refuse les suppressions). |
| 2 | Cartes de la catégorie 3 | Fournies par le propriétaire plus tard (voir 5). |
| 3 | Droits C1/C2 | Jouables en phase de test, sans droits commerciaux ; sources et réserve « droits commerciaux à confirmer » affichées. |
| 4 | RICE100, item 69 « ? » | Affiché tel quel avec la réserve « item source ambigu » ; passé, l'indice n'est pas calculé et on l'explique. |
| 5 | Banques vides (G01–G05, G09, G10, G07) | Les 8 jeux restent « Bientôt » jusqu'au dépôt des banques par le propriétaire. Aucune carte inventée. |
| 6 | Entrées « Questions » et « Tests » | Une page par entrée : bannière de la catégorie puis grille de packs en 2 colonnes, fiche au toucher. |
| 7 | Jeux et mini-jeux | Deux sections titrées en 2 colonnes : « Conversation et découverte » (8) puis « Mini-jeux » (8). |
| 8 | RICE100, QSI12, SPN16 | Section « À huis clos » : activation personnelle de chacun puis double consentement au lancement. |
| 9 | Thème Cocon pastel V5 | Refonte complète V5 de tous les écrans. |
| 10 | Packs longs de Se découvrir | Ordre de la source, reprise à la carte suivante d'une séance à l'autre ; Aron en 3 séries de 12. |
| 11 | Notes vocales | Écrit d'abord ; vocal 30 s dans un lot ultérieur, après vérification du stockage privé. |
| 12 | Ordre de livraison | Lot 1 : thème V5, bibliothèque, 7 packs C1 et 7 tests C2. Lot 2 : mini-jeux sans contenu bloqué (Morpion, Points et carrés, Pierre-feuille-ciseaux, Dé chanceux, Bataille navale). Lot 3 : Deux vérités et un mensonge, Pendu, Petit bac ; Cite trois et les 7 conversations dès réception des banques. |

Règles fixées par les documents (non redemandées) : même carte et même version pour les deux, réponses privées,
partage volontaire, passer = valeur nulle (jamais 0), aucun score de compatibilité ni diagnostic, calculs C2 côté
serveur, résultat individuel avec partage révocable des scores seulement, namespace `noodeu_c34_v1` pour les codes
G/M, versions C01 5.0.0 lues par un adaptateur sans changer `content_version`.

## Interface v2 (24 octobre 2026)

- Le dossier Drive « interface v2 » (première proposition pastel, compacte) **remplace** Cocon Pastel V5 pour les
  couleurs, tailles et densité (décision 9 du questionnaire : refonte complète, désormais selon ce kit). Logo inchangé.
- Bibliothèque : C01 et C02 en catégories horizontales qui ouvrent la liste de leurs packs (et non plus de grandes
  bannières de 148 px) ; C03 et C04 en grilles à deux colonnes, titres de section « Conversation et découverte » et
  « Mini-jeux » (décision 7) ; « À huis clos » en dernier, sans contenu tant que l'activation personnelle manque (décision 8).
- Les illustrations du kit sont découpées cellule par cellule en WebP ; les atlas complets ne sont pas servis.
- Conseils (stories), Espaces (souvenirs, rituels, capsules) et les écrans de connexion gardent leurs fonctions
  actuelles avec les nouveaux jetons ; leurs nouvelles mises en page suivront dans un lot dédié.
- Les banques des jeux C03 et de G07 sont arrivées dans le Drive le 24 octobre : ces jeux passent dans le lot 3,
  ils restent « Bientôt » jusque-là.

## Lot 2 : mini-jeux (25 octobre 2026)

Livrés selon les spécifications du kit C03/C04 V1 (`noodeu_c34_v1`) : Morpion (M01, N2-076), Points et carrés
(M04, N2-079), Pierre, feuille, ciseaux (M11, N2-083), Le Dé chanceux (M12, nd-de-chanceux), Bataille navale (M07, N2-078).
Moteur serveur « famille 6 » (`20261025000100_minijeux_lot2.sql`) ; règles du kit importées par `scripts/import_lot2.py`.

Écarts assumés, à revoir si besoin :
- Manche suivante (Morpion, Pierre-feuille-ciseaux) : un appui de l'un ou l'autre suffit, comme pour les autres jeux
  de plateau, au lieu de l'accord des deux.
- Pierre-feuille-ciseaux : les 30 secondes partent de la création de la manche (début de partie ou « Manche suivante »),
  sans étape « Prêt » par manche. L'annulation à l'échéance est décidée par l'heure du serveur.
- Bataille navale : l'option « Voir les flottes » après la partie (double accord) n'est pas proposée ; les positions
  restantes restent toujours secrètes, ce que le kit prévoit en l'absence d'accord.
- Revanche : « Rejouer » ouvre une nouvelle partie (nouveau tirage) ; elle n'est pas reliée à l'ancienne.
- Plateaux denses (Points et carrés, Bataille navale) : plateau entier par défaut, bouton « Agrandir le plateau »
  qui donne des cibles de 44 px avec défilement horizontal.

## Lot 3 : jeux de conversation (25 octobre 2026)

Livrés selon le kit C03/C04 V1 : Je n'ai jamais (G02), Tu préfères (G03), Qui de nous deux ? (G04), Devine ma réponse (G05),
Complète la phrase (G09), D'accord ou pas d'accord ? (G10), Action ou Vérité (G01), Deux vérités et un mensonge (G08).
Moteur « conversation » (famille 7, `20261025000200_conversation_engine.sql`) ; 730 cartes originales Noodeu importées
côté serveur par `scripts/import_lot3.py` (banques non lisibles par les clients).

- Cartes tirées sans remise, filtre +18 appliqué par le serveur avant tout tirage ; cartes +18 désactivées par défaut,
  activées seulement si les deux joueurs ont activé À huis clos et l'acceptent dans le salon.
- Retrait de l'accord +18 en cours de partie : immédiat ; la carte adulte en cours est interrompue sans pénalité, les
  réponses scellées effacées, et les cartes adultes déjà jouées ne sont plus affichées dans la partie.
- Passer clôt la carte sans rien révéler ; « Continuer » demande l'accord des deux.
- `set_session_prefs` (accord +18 d'une partie) est désormais livrée par cette migration ; elle manquait en ligne
  (migration 150 en attente), ce qui empêchait aussi l'accord « À huis clos » des questionnaires.

Écarts assumés :
- Réponses vocales non proposées (texte d'abord, décision 11 du cadrage) : le kit les rend facultatives.
- Sélection de thèmes non proposée : facultative dans le kit ; toutes les cartes autorisées sont tirées.
- Action ou Vérité : « Arrêter » passe par « Quitter la partie » du salon.
- La confirmation de majorité repose sur l'activation personnelle d'À huis clos dans Réglages.
- Mise en ligne : moteur, 730 cartes (empreintes identiques à la base de test pour chaque banque), règles des 8 jeux ;
  `play_move`, `round_after` et `set_session_prefs` ne sont plus appelables sans compte connecté.

## Lot 4 : Le Pendu, Petit bac, Cite trois en 10 secondes (25 octobre 2026)

Moteur famille 8 (`20261025000300_lot4_engine.sql`), banques importées côté serveur par `scripts/import_lot4.py`
(`20261025000310_lot4_catalogue.sql`) : 288 mots relus du Pendu (Lexique 4.10, CC BY-SA 4.0), index Petit bac de 134 entrées
(Lexique 4.10 et Wikidata CC0), 100 consignes originales de Cite trois (70 standard, 30 +18). Les exemples éditoriaux et notes
de jugement de G07 ne sont pas importés (jamais projetés, conformément au kit). Les mentions de licence figurent dans les règles.

- Le Pendu : le donneur choisit parmi 8 mots tirés au hasard dans le niveau réglé (liste privée), plutôt que dans tout le lot :
  le devineur, donneur à la manche suivante, ne voit ainsi qu'une petite partie du lot. Le niveau « difficile » ne compte que
  7 mots relus : une partie longue s'arrête plus tôt (partie écourtée), sans élargissement silencieux.
- Le Pendu : la fleur à six pétales du kit C03/C04 est utilisée ; les pièces « pendu-etape » de l'interface v2 (potence)
  ne le sont pas, le kit interdisant toute scène de pendaison.
- Petit bac : 4 lettres seulement couvrent les quatre catégories (B, C, R, T) ; la partie se joue donc en 3 manches,
  les options 5 et 7 restant désactivées comme le prévoit le kit. Une réponse valide contestée par un seul joueur devient
  « non tranchée » (0 provisoire, jamais déclarée fausse). Deux réponses de même forme normalisée sont identiques sans vote.
- Cite trois : l'appel reste externe (aucun enregistrement). La consigne est remise par le serveur à l'heure de départ ;
  l'accusé de réception doit arriver dans les 750 ms prévues par le kit, sinon la manche est annulée sans point : sur une
  connexion lente, cela peut arriver plus souvent. L'écart d'horloge est mesuré à chaque réponse du serveur.
- Cite trois : quitter l'écran pendant les 10 secondes annule la manche ; rappel au juge après 30 s ; « manche non évaluée »
  proposée aux deux après 120 s. Pas de choix de thèmes (facultatif dans le kit). La limite technique du nombre de manches
  passe de 50 à 200 (aucun plafond de jeu : fin à 30 points ou à épuisement des consignes).
- Réglage commun modifié dans le salon : les deux « prêt » sont annulés (comportement existant).

## Parcours : classement, rythme, question du jour, favoris, progression (26 octobre 2026)

Migrations `20261026000100_parcours_schema.sql`, `20261026000110_content_meta_data.sql` (générée par
`scripts/classify_contents.py`) et `20261026000120_parcours_engine.sql`. Aucune donnée existante n'est supprimée ; les
identifiants, sources, règles des jeux, ordres et calculs des questionnaires standardisés sont inchangés.

Classement
- 1001 questions de 15 banques classées par règles explicites (intensité Soft/Moyen/Hot, +18 indépendant, durée
  « rapide » 1–2 min ou « discussion » avec durée indicative, formats solo/duo/jeu/rituel/défi, saisons, thème) dans
  `content_meta`, table séparée des banques (textes jamais réécrits). Un doute donne « à relire » (57 cas,
  `docs/CLASSEMENT_A_RELIRE.md`), jamais un classement plus doux ; une carte « à relire » n'entre pas dans la question du jour.
- Les tests standardisés ne sont classés qu'au niveau de l'activité (ordre et calculs intacts) ; les 30 activités jouables
  ont une intensité, des formats et une durée.
- Plafond du duo : l'intensité la plus basse acceptée par les deux, appliquée côté serveur au tirage des cartes
  (`conv_draw`), à la création d'une partie (`filtered_out`) et à la question du jour ; la bibliothèque masque ce qui dépasse
  le plafond. Les réglages personnels (intensité, pays, fuseau, rappels, majorité) ne sont lisibles que par la personne
  (lecture du profil limitée aux colonnes publiques pour le partenaire, `get_my_prefs`).
- +18 désactivé par défaut ; l'activer demande une déclaration de majorité horodatée (refus serveur
  `adult_confirmation_required` sinon) ; il ne s'applique en partie que si les deux l'ont activé et acceptent dans le salon.
  Le texte « l'activation ne vaut jamais consentement » figure dans Réglages et dans la fenêtre de majorité.

Rythme
- Passer et Arrêter sans justification ni pénalité (« Quitter la partie » devient « Arrêter la partie », pour les deux).
- Plus tard : enregistrement personnel (`save_for_later`), aucune notification ni changement de la partie pour l'autre.
- Pause : chronos suspendus ; reprise seulement quand chaque joueur l'a demandée ; les échéances de la manche en cours sont
  décalées de la durée de la pause. Le partenaire de test accepte la reprise.
- Bandeau « Vous pouvez passer, faire une pause ou arrêter à tout moment. » au début des activités intimes et des parties
  dont les cartes +18 sont actives (`adult_active`).

Question du jour
- Même carte pour le duo, conservée la journée du fuseau du duo (fixé au premier tirage, Europe/Paris par défaut), au
  hasard, par thème ou de saison, 3 changements par jour au plus (visibles des deux), sans répétition sur 90 jours ;
  seulement des questions autonomes (jamais Aron, ni les affirmations Gottman, ni une consigne chronométrée).
  +18 seulement si les deux ont activé le +18 et le +18 dans la question du jour.
- Versions courte et approfondie : la version approfondie ajoute une relance rédigée par Noodeu (4 relances neutres), sans
  toucher au texte source ; seulement pour les packs de conversation ouverts.

Favoris, progression
- Favoris de questions (et, plus tard, de stories Conseils), Plus tard et avis privés (Utile, Trop intime, Bien adaptée)
  dans des tables personnelles (RLS par utilisateur) ; les favoris d'activités existants sont conservés.
- Progression du duo : compteurs seulement (consultées, réalisées à deux, passées) ; une question passée ne compte pas comme
  répondue ; un pack est terminé quand toutes ses cartes ont été réalisées (règle existante). Pour un test, seul « terminé »
  est montré côté partenaire (un refus ou un abandon reste privé).

Accompagnement, engagement
- Retour au calme facultatif en fin de partie : trois messages prérédigés envoyés dans la discussion du duo sur action
  explicite, ou message libre ; défi léger Soft non +18 tiré d'Action ou Vérité.
- Phrases de transition quand l'intensité monte d'une carte à la suivante.
- Ressources santé par pays (France, Suisse, Canada) issues d'organismes publics, vérifiées par recherche web (pages non
  ouvertes directement) ; Belgique et autres pays : à compléter, rien n'est affiché sans vérification.
- Rappels doux : réglage personnel (1 à 3 par semaine, heures calmes, espacement de 48 h, aucun contenu intime, aucun rappel
  si la question du jour a déjà été tirée). La fonction d'envoi existe mais n'est pas planifiée : l'écran l'indique.
  La planification demande l'extension gratuite `pg_cron`, à activer avec l'accord du responsable.

## Catalogue final du 24/10/2026 (27 octobre 2026)

Sources : « Noodeu – Catalogue consolidé, 5 catégories » (805 entrées, PDF) et « Packs G05, G08, G09, G10 » (4 × 30 entrées).
Lecture par `scripts/parse_catalogue_final.py` (effectifs identiques au sommaire pour les 41 sections), import par
`scripts/import_catalogue_final.py` (migrations `20261027000100` à `20261027000120`). Aucun texte n'est réécrit.

Cadrage (QCM du 27/10) :
- Écrasement complet : les banques sont vidées puis remplies avec les identifiants du catalogue (C1-01-001…). Les parties
  passées gardent le texte de leurs cartes ; favoris, « Plus tard », avis, cartes du jour et classements qui visaient une
  question disparue sont effacés ; la progression des 7 packs réécrits repart de zéro.
- G05, G08, G09, G10 s'ajoutent aux banques des jeux correspondants. Le catalogue n'ayant pas de banque pour ces quatre jeux,
  elles deviennent leur contenu : Devine ma réponse (G05), Complète la phrase (G09), D'accord ou pas (G10) ; G08 devient
  une réserve d'idées dans Deux vérités et un mensonge (les joueurs écrivent toujours leurs phrases).
- Rubriques : « Mieux se comprendre » rejoint « Se découvrir » (packs puis questionnaires) ; « À huis clos » passe en
  deuxième position ; puis Conversation, puis Mini-jeux. Les cinq grands traits (absents du catalogue final) sont retirés.
- Questionnaire aléatoire (Se découvrir et À huis clos) : 5, 10 ou 20 questions libres de la rubrique, tirées une fois au
  début de la partie ; jamais le protocole d'Aron ni un test ; +18 et intensité respectés ; aucune progression de pack.
- Nouvelle partie alors qu'une autre est ouverte : une fenêtre propose de fermer l'autre (arrêt pour les deux, réponses
  non gardées), au lieu de bloquer.

Correspondances :
- Se découvrir : C1-01 → 36 questions (séries de 12 conservées) ; C1-02 à C1-05 → rituels, place, projets, valeurs
  (Vrai / Faux) ; C1-06 → conversations ; C1-07 → Se retrouver (53, deux redondances fusionnées par le catalogue) ;
  nouveaux packs : C1-08 à C1-14 « 35 questions en séries de cinq » (séance = une série), C1-15 + C3-06 « Découverte et
  complicité », C1-16 « Recul et quotidien », C2-07 « Émotions, sécurité et intimité », C2-08 « Réconfort, confiance ».
- Questionnaires : C2-02 ECR-RS, C2-03 CSI-4, C2-04 AAIRS, C2-05 QSI, C2-06 SPN sur les grilles du catalogue, positions de
  la clé de cotation conservées (vérifiées texte à texte) ; C2-01 test de pureté allégé à 72 items, Oui / Non, sans score
  (consigne du catalogue).
- À huis clos : C5-01 à C5-07 (7 packs), C3-07 à C3-09 (« Scénarios, personnages et défis absurdes »), tests de pureté,
  qualité de la vie sexuelle et regard sur la sexualité, D'accord ou pas et Complète la phrase (banques G10 et G09 presque
  entièrement +18 : accord des deux obligatoire).
- Conversation : C3-01/C3-02 → Action ou vérité (39 vérités, 40 actions), C3-03 → Je n'ai jamais, C3-04 → Tu préfères
  (choix A / B du catalogue), C3-05 → Qui de nous deux. Mini-jeux : C4-01 → Cite trois (24 consignes).
- +18 : badge du catalogue repris tel quel. Les entrées G05/G08/G09/G10, sans badge, sont classées +18 quand le contexte
  est intime ; un doute donne +18 et « à relire » (liste dans `docs/CLASSEMENT_A_RELIRE.md`).
- Packs « Se découvrir » contenant des cartes +18 (Se retrouver, Ce qui compte pour nous, Découverte et complicité,
  Émotions…) : ces cartes sont sautées sans l'accord des deux dans le salon, ainsi que les cartes au-delà du plafond
  d'intensité ; l'ordre du pack est conservé. Un pack est « terminé » quand toutes ses cartes non +18 sont réalisées.
- Thèmes de la question du jour : titres des packs (le catalogue ne donne pas de thème aux cartes de jeux).

## Plusieurs duos actifs (27 octobre 2026)

Migration `20261027000300_multi_duos.sql` (fichier à coller : `docs/sql_editeur_duos_multiples.sql`).
- Une personne peut avoir jusqu'à 10 duos actifs en même temps (plafond technique contre les abus). Une même paire ne
  peut pas avoir deux duos actifs ; une paire qui s'est séparée retrouve son ancien espace à la réinvitation (inchangé).
- « Duo affiché » : choisi par la personne (`set_current_duo`), retenu côté serveur d'une connexion à l'autre. Toutes les
  fonctions « mon duo » (parties, discussion, question du jour, progression, filtres) servent ce duo ; les autres duos
  restent intacts (parties ouvertes, messages, progression). Bouton « Changer de duo » sur l'accueil et dans l'Espace,
  avec les messages non lus des autres duos ; une notification d'un autre duo y bascule avant de s'ouvrir.
- Accepter une invitation affiche le nouveau duo pour la personne qui accepte ; l'autre garde son duo affiché
  (le nouveau ne s'affiche chez elle que si elle n'en avait aucun). Aucune notification n'informe un partenaire
  des autres duos de l'autre.
- Terminer un duo (`leave_duo`) : aucune notification, pour personne ; les anciennes notifications « duo terminé » sont
  effacées. L'historique reste en lecture seule pour chacun. La suppression de compte termine tous les duos actifs.
- Cloisonnement : chaque accès vérifie l'appartenance au duo concerné (tables, fonctions, canaux temps réel) ; le duo
  affiché ne donne jamais accès à un duo dont on n'est pas membre (tests `c17_multi_duos.sql`).

## Questions +18 sans permission (28/10/2026)

- Les questions +18 font partie du jeu et de la conversation : plus d'activation dans les Réglages, plus d'accord dans le
  salon, plus de retrait en cours de partie, plus de plafond d'intensité. Toutes les cartes peuvent être tirées.
- Le salon des activités concernées (À huis clos ou cartes +18) affiche seulement : « Ce contenu contient des questions
  relatives au sexe. »
- La majorité reste déclarée à l'inscription. Les colonnes `intimate_opt_in`, `max_intensity` et `session_prefs.adult`
  restent en base, sans effet ; tous les profils sont passés à +18 actif et intensité « hot ».
- Les phrases de règles qui parlaient d'activer le +18 sont retirées (nouvelles versions de règles).
- Migration `20261028000100_sans_permission_adulte.sql`, tests `c18_sans_permission_adulte.sql`. Les tests c14 à c17
  restent exécutés sur le schéma antérieur à ce retrait, pour lequel ils ont été écrits.

## Jeux premium V4, lots J1 à J3 (28/10/2026)

- Chaque jeu a son univers (décor, matière, accents) servi depuis `public/assets/premium/<code>` ; le décor reste
  décoratif, sans texte ni interaction. Le serveur reste seul arbitre (tirages, minuteries, scores, secrets).
- Deux vérités et un mensonge (G08, version 2) : écriture simultanée, « OK, je suis prêt » (modifiable tant que l'autre
  n'est pas prêt), puis devinette simultanée. Les textes de l'autre ne sont transmis qu'une fois les deux prêts, les
  mensonges qu'après les deux choix. 4, 6 ou 10 manches, 6 par défaut. Score affiché « X/total ».
- Relance « je t'attends » : notification de partie dans l'application uniquement (pas de notification push), après
  20 s d'attente, une toutes les 60 s, 3 par manche et par joueur, vérifiées par le serveur.
- Notifications : présentation par type (relance, partie proposée, invitation, rappel) ; les messages de discussion ne
  créent plus de notification (les anciennes ont été supprimées).
- Test de pureté (ND-Q-011) rangé dans « Se découvrir » : indice sur 100 et nombre de « Non » sur 72 ; « Montrer mes
  réponses à la fin » activé par défaut, décochable.
- Le Dé chanceux : 30 points conservés pour gagner ; la victoire n'arrive qu'en conservant.
- Petit bac : 8 rubriques en grille 2 × 4 (Animal, Ville ; Métier, Objet ; Pays, Prénom ; Fruit ou légume, Célébrité),
  120 s par défaut ou 180 s, 3 manches (5 ou 7 au choix), barème 5/10/15. Index de validation rédigé par Noodeu
  (`scripts/petit_bac8_index.py`, banque `petit_bac_huit`, 866 entrées), **à relire** ; une réponse absente de l'index
  est arbitrée par les deux joueurs.
- Bataille navale : viser une case puis confirmer le tir (évite les tirs par erreur sur un petit écran). Points et
  carrés : zones de 28 px sans chevauchement, 44 px avec « Agrandir le plateau ».
- Migrations `20261028000200` à `20261028000500` ; les parties déjà commencées gardent leur version de règles.
