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

- Navigation : exactement cinq onglets (Accueil, Bibliothèques, Astuces, Notre espace, Paramètres). Le jeu et le salon n'en font pas partie.
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
