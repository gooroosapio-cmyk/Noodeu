# Classement des contenus : cas à relire

Généré par `scripts/classify_contents.py` (classement par règles, sans modification des textes).
Une ligne relue et validée se corrige dans le script (exception par identifiant) puis la migration est régénérée ;
une correction manuelle en base (`source` différent de `regles-v1`) n'est jamais écrasée.

| Banque | Soft | Moyen | Hot | À relire |
|---|---:|---:|---:|---:|
| q_aron | 11 | 25 | 0 | 0 |
| q_gottman_open | 30 | 0 | 0 | 0 |
| q_usu_roadtrip | 42 | 3 | 8 | 1 |
| q_series | 27 | 7 | 1 | 1 |
| q_complicite | 12 | 0 | 5 | 0 |
| q_recul | 22 | 2 | 0 | 1 |
| q_emotions | 5 | 2 | 9 | 2 |
| q_reconfort | 18 | 2 | 0 | 0 |
| q_hc_envies | 0 | 4 | 16 | 4 |
| q_hc_parler | 0 | 5 | 15 | 5 |
| q_hc_corps | 0 | 1 | 19 | 1 |
| q_hc_protection | 0 | 8 | 12 | 8 |
| q_hc_plaisir | 0 | 3 | 17 | 3 |
| q_hc_envies_plus | 0 | 0 | 14 | 0 |
| q_hc_intimite_plus | 0 | 1 | 10 | 1 |
| q_hc_complements | 0 | 0 | 15 | 0 |
| q_gottman_rituals | 12 | 1 | 0 | 0 |
| q_gottman_roles | 6 | 1 | 0 | 0 |
| q_gottman_goals | 10 | 0 | 0 | 0 |
| q_gottman_values | 17 | 3 | 0 | 1 |
| conv_never | 40 | 2 | 11 | 0 |
| conv_dilemma | 34 | 1 | 19 | 1 |
| conv_target | 29 | 2 | 22 | 2 |
| conv_opinion | 0 | 4 | 26 | 4 |
| conv_sentence | 7 | 1 | 22 | 9 |
| conv_predict | 15 | 3 | 12 | 4 |
| conv_truth_dare | 69 | 8 | 2 | 1 |
| cite_trois | 9 | 2 | 13 | 1 |
| conv_two_truths_ideas | 1 | 0 | 29 | 0 |

Total : 804 questions classées, 50 à relire.

| Identifiant | Classement | Raison | Texte |
|---|---|---|---|
| C1-07-037 | hot | vocabulaire intime (erotique) dans une carte non marquée +18 dans le kit | T’as déjà fait un rêve érotique à mon sujet ? |
| C1-12-003 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | C’est quoi tes limites à ne jamais dépasser pendant les rapports sexuels ? |
| C1-16-010 | moyen | ton léger (ridicule) mais sujet sensible (peur) : Moyen ou Soft ? | Y a une peur que t’as encore aujourd’hui et que tu trouves un peu ridicule ? |
| C2-07-001 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Tu te sens plus à l’aise pour parler de tes émotions ou de tes envies sexuelles ? |
| C2-07-006 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Tu te sens plus proche de l’autre après une conversation profonde ou après un moment intime ? |
| C5-01-010 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quelle limite tu veux pouvoir poser sans avoir à raconter ton passé ni te justifier ? |
| C5-01-013 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quelles conditions te permettent de parler de sexe sans te sentir obligé d’aller plus loin ? |
| C5-01-014 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Parler de tes parties génitales te met à l’aise, ou tu préfères commencer par des questions plus générales ? |
| C5-01-020 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | À la fin de ce pack, quelle info sur tes limites tu veux garder pour toi, partager, ou préciser plus tard ? |
| C5-02-001 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quel mot te semble le plus facile pour lancer une conversation sur votre sexualité ? |
| C5-02-002 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Tu préfères parler de sexe à voix haute, par écrit, ou en appel ? |
| C5-02-003 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | À quel moment une discussion sexuelle a le plus de chances de bien se passer pour toi ? |
| C5-02-007 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quels mots tu préfères pour parler de vulve, clitoris, pénis ? |
| C5-02-018 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quand vos envies ne coïncident pas, quelle conversation te semblerait utile ? |
| C5-03-020 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quel sujet sur ton corps t’aimerais mieux connaître avant d’en parler avec un partenaire ? |
| C5-04-001 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Comment tu lancerais une conversation sur les préservatifs avant que le moment devienne intime ? |
| C5-04-002 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qu’est-ce qui te rendrait une discussion sur le dépistage plus simple ? |
| C5-04-005 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Si un préservatif gêne, irrite ou semble mal adapté, comment tu voudrais le signaler ? |
| C5-04-010 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Pour choisir une contraception, quels besoins personnels tu voudrais pouvoir faire entendre ? |
| C5-04-012 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | En cas d’oubli contraceptif ou de préservatif qui se déchire, quel premier contact tu saurais chercher ? |
| C5-04-014 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qu’aimerais-tu comprendre sur ce qu’un résultat de dépistage dit et ne dit pas ? |
| C5-04-015 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Comment tu voudrais parler d’une IST diagnostiquée sans juger ? |
| C5-04-018 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quelles informations de santé te semblent utiles à partager, et quels détails tu veux garder privés ? |
| C5-05-003 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui t’a le plus appris à parler de sexualité ? |
| C5-05-008 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | À ton avis, pourquoi le clitoris reste-t-il difficile à nommer dans certaines conversations ? |
| C5-05-017 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Que répondrais-tu à l’idée que demander un dépistage serait un manque de confiance ? |
| C5-07-007 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | C’est quoi le pire timing pour parler de sexe selon toi ? |
| C1-05-005 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | On a des points de vue proches sur la place de la sexualité dans nos vies. |
| C3-04-006 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Tu préfères… Parler de sexe par message / En face |
| C3-05-015 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui de nous deux est le plus susceptible de vouloir parler de sexe en premier ? |
| C3-05-022 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui de nous deux est le plus susceptible de vouloir parler de ses fantasmes ? |
| PK-G10-007 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Demander un dépistage, ce n’est pas un manque de confiance. |
| PK-G10-013 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Parler de ses limites, ça rend les rapports plus sereins. |
| PK-G10-015 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Le consentement peut être retiré à tout moment. |
| PK-G10-028 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Parler de ses envies par message, c’est parfois plus facile. |
| PK-G09-002 | hot · +18 | entrée sans badge dans son PDF, classée +18 par prudence : à confirmer | Le truc qui me fait le plus kiffer c’est… |
| PK-G09-006 | hot · +18 | entrée sans badge dans son PDF, classée +18 par prudence : à confirmer | Le truc que j’ose pas encore te dire c’est… |
| PK-G09-012 | hot · +18 | entrée sans badge dans son PDF, classée +18 par prudence : à confirmer | Le truc le plus underrated qui me fait kiffer c’est… |
| PK-G09-015 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Ma limite la plus importante c’est… |
| PK-G09-016 | hot · +18 | entrée sans badge dans son PDF, classée +18 par prudence : à confirmer | Le truc que j’aimerais qu’on essaie ensemble c’est… |
| PK-G09-023 | hot · +18 | entrée sans badge dans son PDF, classée +18 par prudence : à confirmer | Ce qui me fait me sentir en sécurité c’est… |
| PK-G09-025 | hot · +18 | entrée sans badge dans son PDF, classée +18 par prudence : à confirmer | Le truc le plus simple qui me fait fondre c’est… |
| PK-G09-028 | hot · +18 | entrée sans badge dans son PDF, classée +18 par prudence : à confirmer | Quand je suis gêné·e, j’aimerais que tu… |
| PK-G09-029 | hot · +18 | entrée sans badge dans son PDF, classée +18 par prudence : à confirmer | Le truc que j’aimerais qu’on fasse plus souvent c’est… |
| PK-G05-010 | moyen · +18 | entrée sans badge dans son PDF, classée +18 par prudence : à confirmer; carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Tu penses que je suis plus à l’aise pour parler de mes émotions ou de mes envies ? |
| PK-G05-018 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Tu penses que je suis plus à l’aise pour parler de sexe par message ou en face ? |
| PK-G05-020 | hot · +18 | entrée sans badge dans son PDF, classée +18 par prudence : à confirmer | Tu dirais que je suis plutôt du genre à proposer un truc nouveau ou à rester sur ce qu’on connaît ? |
| PK-G05-023 | hot · +18 | entrée sans badge dans son PDF, classée +18 par prudence : à confirmer | D’après toi, je préfère un moment improvisé ou un moment prévu ? |
| C3-02-013 | moyen | ton léger (invente, super-pouvoir) mais sujet sensible (defaut) : Moyen ou Soft ? | Invente un super-pouvoir basé sur ton plus gros défaut. |
| C4-01-009 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Donne trois façons de commencer une discussion sur les envies sexuelles. |
