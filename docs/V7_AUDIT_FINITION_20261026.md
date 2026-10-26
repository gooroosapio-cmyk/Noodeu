# V7 — audit et finitions locales du 26 octobre 2026

Cette livraison est une proposition locale, sans publication Git, déploiement Vercel ni opération Supabase. La production reste sous la responsabilité du coordinateur de livraison.

## Référence auditée et garde-fou

- Dépôt : `gooroosapio-cmyk/Noodeu`.
- Branche distante auditée : `v7/interface-20261026`.
- SHA exact : `2f2623182ad4fa616722215dde1356ed9a7abeb9`.
- Base : `70fb1699790bc331888961e4f958a15dc45adf73`.
- Comparaison GitHub vérifiée : trois commits d'avance, aucun de retard ; ancêtre commun égal à la base.
- Commits V7 : `0240180b654071148fdd9504d84053d836207e49`, `9eebd6a532e3b21945c4615212745bea86cf54d8`, puis `2f2623182ad4fa616722215dde1356ed9a7abeb9`.
- `git diff 70fb1699790bc331888961e4f958a15dc45adf73..HEAD -- supabase` : vide avant les finitions. Le sous-arbre Supabase vaut `d952b6b936b3ce1b5c12de83dbe6e4c1575aa599` aux deux références.
- Branche locale de finition : `codex/v7-finitions-20261026`, créée à partir du SHA V7 exact. Aucun rebase ou fusion. L'ancien chantier local est conservé séparément.

Le rapport `docs/V7_INTERFACE_20261026.md` a été lu intégralement. Aucune instruction `AGENTS.md` ou skill `.agents/skills` n'a été trouvée dans l'arbre du dépôt audité. La checklist React du plugin Vercel a été utilisée pour relire les finitions ; elle n'a pas conduit à changer le framework ou les conventions du projet.

## Audit effectué avant modification

Les neuf images fournies dans `docs/captures/v7-20261026/` ont été ouvertes et inspectées. Les six captures numérotées comprennent des comparaisons antérieures ; les trois fichiers `fidelite-*` documentent la passe la plus récente. Elles ne sont pas toutes la capture du même état de code.

Le rendu local a été contrôlé avec des données fictives : 60 contextes d'écrans principaux, produisant 120 captures, puis 14 contextes de jeu et 34 captures. Largeurs : 320, 360, 390, 430 et 768 px. Les appels externes étaient interceptés ou bloqués et les service workers désactivés pour ces parcours.

| Constat | Origine et preuve | Finition |
| --- | --- | --- |
| Un envoi de message A–B échoue après passage vers A–C : le texte B revient dans le champ C. | Régression V7, reproduite dans Chromium avec une réponse RPC retardée. Risque d'envoi au mauvais destinataire lors d'un prochain clic ; aucune lecture non autorisée en base démontrée. | Brouillons et états d'envoi propres au compte et au duo ; restauration conditionnée à la révision, sans remplacer une nouvelle saisie. |
| Une lecture de partie A absorbe les relectures de B après navigation. | Régression V7, comparaison de vrais hooks React avec la base ; la file conservait la fermeture de A. | File de lectures propre au contexte utilisateur/session ; réponses, présence et rappels anciens ignorés. |
| Un favori optimiste reste affiché après navigation et échec de l'écriture. | Régression V7, reproduction avec écriture différée et nouveau consommateur du cache. | Abonnement au cache par compte, retour à l'état confirmé partagé entre écrans, protection contre les lectures antérieures à une mutation. |
| Le titre du chat chevauche le retour à texte agrandi ; le champ sort sur écran bas. | Reproduit à 320 px et à hauteur 420 px. | En-tête réorganisé, repli en hauteur et zone de messages défilante ; commandes conservées. |
| En mouvement réduit, le fond décoratif recouvre le texte de pages pourtant présentes dans le DOM. | Régression visuelle V7 confirmée par capture du coffre ; les assertions de visibilité seules ne détectaient pas l'occlusion. | Ordre de superposition explicite du décor derrière le contenu, indépendant des animations. |
| Cibles « Jouer » à 40 px et choix du mensonge à 36 px. | Mesure du DOM ; le second défaut était antérieur à V7. | Minimum 44 px. |
| Une archive B reste visible sous le titre de C après changement de duo. | Défaut antérieur à V7, reproduit ; pas présenté comme régression nouvelle. | Composant isolé par compte et duo, anciennes réponses ignorées. |
| Un souvenir au-delà des 30 dernières parties est inaccessible ; le coffre peut annoncer être vide. | Défaut antérieur à V7, reproduit avec une 31e partie conservée. | Lecture bornée et bouton vers les pages plus anciennes, ordre stable, filtrage par duo et conservation commune inchangés. |
| Une réouverture rapide du chat est annulée par le retour navigateur encore en cours ; deux fenêtres imbriquées ne consomment pas correctement leurs retours. | Défaut préexistant du registre de fenêtres, d'abord observé de façon intermittente puis reproduit avec un `history.back()` différé. | Retour en cours suivi explicitement ; la nouvelle fenêtre conserve son entrée d'historique et les fenêtres restantes réarment la leur. |

Les captures ont aussi confirmé la composition V7 de l'accueil, l'espace, le coffre, l'historique et la conversation. Les finitions ne changent ni les illustrations ni la palette. Ce contrôle ne revendique pas une fidélité pixel pour pixel aux témoins.

## Contrats préservés

- G08 conserve le fonctionnement **tour par tour de cette version** : rédaction de trois propositions, brouillon retrouvé après rechargement, effacement après « Passer cette carte », absence de propositions adverses pendant leur rédaction. Aucun retour à l'ancien simultané.
- Salon : validation des réglages, disponibilité des joueurs et lancement réservé à l'hôte restent sur les règles existantes.
- G01 reste oral : aucun champ de réponse de jeu et action « C'est répondu ! ». Le champ de conversation permanent est distinct ; les tests attendent désormais le chargement réel du jeu avant de vérifier cette différence.
- Les moteurs, scores, banques, formats de questionnaires, migrations et permissions ne changent pas.
- Les clés historiques des brouillons de conversation restent lisibles. Les métadonnées locales de propriétaire/révision empêchent une restauration tardive dans un autre contexte. Le repli en mémoire évite la perte du texte en cas d'échec lorsque le stockage est indisponible, dans l'instance active seulement ; fermer le chat ou recharger la page perd ce repli.
- Les archives et souvenirs ne citent aucune réponse de jeu privée supplémentaire. Les souvenirs restent ceux conservés par les deux joueurs.
- Une erreur réseau de chargement des archives est signalée et peut être réessayée ; elle n'est plus transformée en conversation vide.
- Une écriture locale de brouillon partiellement refusée rend le contenu indisponible plutôt que de l'attribuer à un autre compte. Les quatre étapes d'écriture et l'impossibilité de supprimer les clés sont couvertes.

## Vérifications

Avant les finitions : lint, types/build et 13 tests unitaires réussis ; 30 parcours existants réussis (V7 : 9, salon : 5, jeux rouges : 10, clavier : 6). Ces succès n'ont pas masqué les courses asynchrones reproduites séparément ci-dessus.

Validation finale : `npm run lint`, `npm run build` (incluant `tsc --noEmit`) et `npm test` réussis, avec **21 tests unitaires, aucun échec**. Le build local utilise une clé factice et ne doit jamais être téléversé tel quel en production.

| Suite finale | Résultat | Nature de la preuve |
| --- | --- | --- |
| V7, salon, jeux rouges, clavier | 9 + 5 + 10 + 6 réussis | Parcours Chromium sur le build compilé ; RPC et comptes fictifs. |
| Confidentialité chat/archives | 9 réussis | Retards, changement de duo, double envoi, déconnexion, stockage refusé, archives et erreur 503/reprise. |
| Pagination du coffre | 8 réussis | 31e souvenir, pagination bornée, double clic, reprise après erreur, changements de contexte, notes et vraie fin vide. |
| Géométrie et saisie du chat | 26 réussis | 320/360/390/430/768 px ; hauteurs 420/844/1024 ; taille racine 100/200 %, deux simulations de clavier superposé, deux stress de polices calculées doublées. |
| Mouvement réduit et peinture | 9 réussis | Accueil/espace/coffre, préférence système/profil/mouvement normal ; comparaison des pixels du texte avec et sans décor. |
| Historique des fenêtres | 4 réussis | Réouverture pendant un retour différé, fermeture avant son arrivée, retour/Échap, fenêtres imbriquées ; route conservée. |
| Contextes du hook de session | 9 réussis | Vrais hooks React/Chromium, serveur simulé : navigation, compte, démontage, coalescence, reprise et versions. |
| Cache du catalogue | 9 réussis | Vrais hooks React/Chromium : échecs retardés, nouveaux consommateurs, comptes séparés et mutations concurrentes. |

Soit **104 contrôles locaux réussis**, en plus des unités. Les 86 contrôles d'interface ont été rejoués sur le dernier build ; les 18 contrôles de hooks exécutent les sources concernées. Ce nombre ne signifie pas 104 parcours multijoueurs réels.

Le premier passage final avait échoué sur une réouverture de chat ; la cause a ensuite été reproduite avec un retour navigateur différé, corrigée, puis toutes les suites d'interface ont été rejouées. Le défaut de peinture en mouvement réduit avait également une preuve négative avant sa correction. Aucun résultat intermédiaire échoué n'est présenté comme un succès.

Le JavaScript initial représente environ **218,66 kB gzip** (index 61,54 ; React 99,40 ; Supabase 55,16 ; workbox 2,20 ; runtime 0,36). La console de jeu reste différée (83,97 kB gzip), comme l'admin (3,16 kB). Ces mesures décrivent les fichiers compilés, pas la latence perçue sur téléphone.

Les scripts reproductibles sont dans `tests/visual/`. Utiliser exclusivement un serveur local et des fixtures, par exemple `BASE=http://127.0.0.1:4268 node tests/visual/chat-privacy-flows.mjs`. Les suites de hooks `session-context-flows.mjs` et `catalog-cache-flows.mjs` démarrent leurs propres simulations. Ne pas pointer ces contrôles vers la production.

## Limites et remise

- Toutes les interactions décrites sont locales et simulées. Aucun compte réel ni nouvelle invitation n'a été utilisé. Aucun script SQL n'a été lancé.
- L'accès navigateur à la production avait échoué avec `net::ERR_TUNNEL_CONNECTION_FAILED`. Il n'a pas été contourné ni réessayé dans ce lot. Le salon réel avec Kalou, les politiques serveur et les migrations en ligne ne sont donc pas certifiés par cet audit front.
- La simulation de taille racine à 200 % ne double pas les textes exprimés en pixels. Des contrôles de stress supplémentaires sont distingués des vérifications sur appareil réel. Le clavier est simulé ; aucun essai physique iOS/Android n'est revendiqué.
- Le découpage du build a été vérifié, pas un gain de temps sur appareil ou réseau réel. Les en-têtes de cache CDN et le comportement de mise à jour de la PWA en production restent à vérifier après une éventuelle publication autorisée.
- Le coffre charge au maximum 30 parties par demande, puis propose les plus anciennes. Il n'effectue pas de balayage automatique illimité ; une modification concurrente de l'historique peut nécessiter une actualisation.
- Réserve distincte du test d'historique : avec un appel natif `history.back()` artificiellement retenu, une navigation vers l'accueil avant sa libération peut ramener à la partie. Aucune comparaison exécutée avant/après ne permet d'attribuer ce cas au correctif ; sa reproduction dans les conditions réelles reste à établir. Les quatre scénarios de fermeture/réouverture documentés ci-dessus passent.
- Audio, OAuth Google, vidéo de lancement et activations serveur antérieures ne sont pas rendus opérationnels par ces finitions.
- Pour publier ultérieurement : revalider la tête distante, examiner le commit local de finition et tester sa construction avec la configuration existante. Ne rejouer aucune migration et ne remplacer aucun travail concurrent. Ce document n'autorise pas une publication.
