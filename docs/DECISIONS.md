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
