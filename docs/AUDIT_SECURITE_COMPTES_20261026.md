# Comptes réels et audit de sécurité renforcé (26/10/2026)

Phase de test : inscription et usage gratuits. Décisions de cadrage du propriétaire :

- inscription par e-mail et mot de passe, ouverte à tous ;
- pas de CAPTCHA ;
- mot de passe de 8 caractères minimum ;
- mot de passe oublié traité à la main ;
- suppression de compte conservée telle quelle ;
- aucune donnée existante touchée.

Ce que le partenaire peut voir :
- les réponses de jeu partagées ;
- la conversation et les notes du duo ;
- le prénom et la photo.

## Inscription sans validation par e-mail

| Point | État |
|---|---|
| Confirmation d'e-mail (Supabase `mailer_autoconfirm`) | Déjà désactivée : le compte est actif immédiatement |
| Inscription ouverte (`disable_signup`) | Oui |
| Longueur minimale du mot de passe | 8 caractères (serveur et formulaire) |
| URL du site et redirections | `https://noodeu.vercel.app`, plus `localhost` pour le développement |
| Parcours vérifié | Inscription simulée → accueil directement ; prénom transmis au profil |
| Mot de passe oublié | Le bouton d'envoi d'e-mail est retiré, car aucun service d'envoi n'est configuré. Il est remplacé par « Contacte l'équipe Noodeu : nous le réinitialisons pour toi. » |
| Connexion Google | Reste désactivée, avec la mention « bientôt disponible » |

Conséquence assumée : l'adresse e-mail n'est pas vérifiée. Quelqu'un pourrait s'inscrire avec l'adresse d'une autre personne. C'est acceptable pour des testeurs connus. À revoir avant une ouverture publique (SMTP et confirmation, ou Google).

## Audit d'isolation (production lue en lecture seule, essais d'intrusion sur base locale)

### Ce qui a été vérifié

1. **Tables**
   - La sécurité par ligne (RLS) est active sur toutes les tables publiques.
   - Aucune table n'est lisible par un visiteur non connecté.
   - Lectures filtrées par appartenance au duo ou par propriétaire.
   - Écritures directes limitées aux favoris, aux « plus tard » et aux retours de l'utilisateur, uniquement sur ses propres lignes.
2. **Tables sensibles sans lecture directe** : réponses, manches, messages de partie, secrets de manche. On n'y accède que par des fonctions serveur qui vérifient l'identité.
3. **55 fonctions serveur privilégiées**
   - Aucune n'est appelable sans connexion.
   - Toutes fixent leur `search_path`.
   - Toutes les fonctions de partie passent par `lock_session`, qui exige d'être membre actif du duo et joueur de la partie.
   - L'administration est réservée à `app_admins`.
4. **Réponses privées**
   - Le texte d'une réponse gardée privée reste dans `private.round_secrets` et n'est jamais copié dans la carte visible.
   - Les réponses du partenaire n'apparaissent qu'après la révélation, et filtrées.
5. **Stockage** : les buckets sont privés. Les avatars sont visibles seulement par la personne et ses partenaires. Les couvertures de duo sont réservées aux membres du duo et ne peuvent être ni écrasées ni supprimées depuis le navigateur.
6. **Temps réel** : canaux privés par partie et par duo (`can_join_topic`).
7. **Profil**
   - L'e-mail n'est jamais exposé.
   - Le partenaire voit le prénom, la photo, la forme d'accord, et deux réglages sans contenu (« animations réduites », « accord pour le contenu intime »).
8. **Suppression de compte** (fonction serveur `delete-account`)
   - Identité vérifiée par jeton et confirmation explicite.
   - Tous les duos actifs sont fermés, les photos supprimées, puis le compte.
   - Les références restantes passent à `NULL` : l'historique partagé reste visible du partenaire de façon anonyme (« compte supprimé »).

### Preuves

- Nouveau test `supabase/tests/c43_isolation_comptes.sql`, sur deux duos A–B et C–D :
  - C ne lit aucune ligne de A–B ;
  - C est refusé sur 27 fonctions appelées avec les identifiants de A–B ;
  - C ne modifie pas le profil de A et ne met pas fin au duo A–B ;
  - C n'accède à aucun objet de stockage ni canal temps réel de A–B ;
  - B ne reçoit jamais le texte gardé privé par A : ni dans l'état de partie, ni dans les métadonnées, la progression ou ses éléments, ni après la manche.
  - Résultat : **OK**. Une fonction mal nommée fait échouer le test au lieu de passer pour un refus.
- La suite SQL existante (34 fichiers) repasse entièrement : **OK**.

### Points notés (pas des failles)

- **Anciens duos** : après la fin d'un duo, les deux anciens membres gardent l'historique en lecture seule (messages, parties, réponses révélées, prénom et photo). C'est voulu (« duos réactivables »). Si tu veux que la fin d'un duo coupe tout accès, c'est une évolution à décider.
- **Protection contre les mots de passe compromis** (alerte Supabase) : non activée, par choix (8 caractères seulement).
- **Alerte « fonctions privilégiées appelables »** (55) : c'est l'architecture voulue (toutes les opérations passent par le serveur). Chaque fonction vérifie l'identité, comme le prouve le test c43.

## Optimisation (migration `20261030001500_comptes_reels_perf.sql`, à valider)

- Index `couple_members(user_id)`. Chaque contrôle d'appartenance cherche par cette colonne, à chaque requête et pour chaque ligne lue. Sans index, le coût augmente avec le nombre de comptes.
- Index `session_prefs(user_id)` et `current_duo(couple_id)`, utiles pour la suppression de compte et le changement de duo.
- Trois règles « propriétaire » réécrites pour évaluer `auth.uid()` une seule fois par requête. Même effet, plus rapide.
- Aucune donnée modifiée. Appliquée sans erreur sur une copie de l'état de production (transaction annulée) et sur la base de test, où c43 repasse.

## Espace duo (migration `20261030000100_duo_space.sql`, préparée mais jamais appliquée)

En ligne, la couverture et les notes du duo affichent « pas disponible », parce que cette migration n'a jamais été appliquée. Pour un MVP entièrement fonctionnel, elle doit l'être. Elle crée :
- deux tables privées ;
- trois fonctions : lecture, note, couverture ;
- un bucket privé `duo-covers` (2 Mo, WebP, JPEG, PNG).

Côté sécurité :
- l'appartenance au duo est vérifiée à chaque appel ;
- un contrôle de version évite d'écraser une modification de l'autre ;
- un objet déposé ne peut ni être écrasé ni être supprimé depuis le navigateur.

Elle est testée par c30 et c43, et s'applique proprement sur l'état de production. Elle n'utilise aucun service payant.

## Suite (décisions du propriétaire)

- **Changer mon mot de passe** (Réglages → Compte) : le mot de passe actuel est revérifié avant la modification, et la confirmation est obligatoire. Aucun e-mail n'est nécessaire. Testé : confirmation différente bloquée ; mauvais mot de passe actuel refusé sans aucune modification ; changement réussi.
- **Historique après la fin d'un duo** : conservé en lecture seule pour les deux anciens membres (fonctionnement actuel, confirmé).
- **Migrations 1500 et 0100** : appliquées en ligne le 26/10 après accord écrit (« Applique 1500 et 0100 »), puis vérifiées en lecture seule.
