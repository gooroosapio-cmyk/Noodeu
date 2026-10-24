# Classement des contenus : cas à relire

Généré par `scripts/classify_contents.py` (classement par règles, sans modification des textes).
Une ligne relue et validée se corrige dans le script (exception par identifiant) puis la migration est régénérée ;
une correction manuelle en base (`source` différent de `regles-v1`) n'est jamais écrasée.

| Banque | Soft | Moyen | Hot | À relire |
|---|---:|---:|---:|---:|
| q_aron | 11 | 25 | 0 | 0 |
| q_gottman_open | 29 | 1 | 0 | 0 |
| q_usu_roadtrip | 50 | 4 | 1 | 1 |
| q_gottman_rituals | 12 | 1 | 0 | 0 |
| q_gottman_roles | 6 | 1 | 0 | 0 |
| q_gottman_goals | 10 | 0 | 0 | 0 |
| q_gottman_values | 17 | 2 | 1 | 1 |
| conv_never | 62 | 15 | 23 | 7 |
| conv_dilemma | 65 | 17 | 18 | 12 |
| conv_target | 68 | 12 | 20 | 10 |
| conv_opinion | 64 | 12 | 24 | 6 |
| conv_sentence | 64 | 8 | 28 | 2 |
| conv_predict | 64 | 13 | 23 | 7 |
| conv_truth_dare | 74 | 18 | 38 | 6 |
| cite_trois | 68 | 7 | 25 | 5 |

Total : 1001 questions classées, 57 à relire.

| Identifiant | Classement | Raison | Texte |
|---|---|---|---|
| USU_ROADTRIP55-FRTR01-037 | hot | vocabulaire intime (erotique) dans une carte non marquée +18 dans le kit | As-tu déjà fait un rêve érotique à mon sujet ? Quel était ce rêve ? |
| GOTTMAN_VALUES20-FRTR01-005 | hot | vocabulaire intime (sexualit) dans une carte non marquée +18 dans le kit | Nous avons des points de vue semblables sur la place de la sexualité dans nos vies. |
| G02-J079 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Je n’ai jamais ressenti de la gêne après une première nuit ensemble sans savoir comment reprendre la conversation. |
| G02-J080 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Je n’ai jamais réalisé après coup que j’aurais aimé parler de nos attentes sexuelles plus tôt. |
| G02-J088 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Je n’ai jamais trouvé plus facile de parler de sexualité par message qu’en face à face. |
| G02-J090 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Je n’ai jamais demandé qu’on reprenne calmement une discussion sur le sexe au lieu de plaisanter pour l’éviter. |
| G02-J097 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Je n’ai jamais proposé de faire un dépistage des IST avant de commencer une vie sexuelle à deux. |
| G02-J098 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Je n’ai jamais laissé l’autre se charger seul de parler de contraception. |
| G02-J100 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Je n’ai jamais eu besoin de dire que notre vie sexuelle ne regardait pas nos proches. |
| G03-T071 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Pour aborder la sexualité entre nous, tu préfères… En parler au fil des échanges / Prévoir une conversation dédiée où l’on peut tout mettre à plat |
| G03-T078 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Pour découvrir un sujet lié à la sexualité, tu préfères… Choisir une ressource ensemble puis en parler / Te renseigner de ton côté puis partager ce que tu souhaites |
| G03-T080 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Après une conversation sur le sexe qui t’a mis mal à l’aise, tu préfères… Revenir sur le passage précis qui t’a gêné / Commencer par expliquer ce qui te mettrait plus en confiance pour la suite |
| G03-T081 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Dans une conversation sur la sexualité de ton partenaire, tu préfères… Connaître les grandes lignes de son passé sexuel / Parler surtout de ses envies et limites actuelles |
| G03-T083 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Pour préciser tes limites sexuelles, tu préfères… Commencer par ce que tu ne souhaites pas / Commencer par ce qui te met à l’aise puis préciser tes limites |
| G03-T084 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Pour clarifier l’exclusivité d’une relation sexuelle, tu préfères… Ouvrir la discussion dès que la relation devient intime / Convenir d’abord d’un moment pour dire clairement ce que chacun souhaite |
| G03-T086 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Pour parler du dépistage des IST, tu préfères… Prévoir ensemble quand vous allez vous renseigner / Faire chacun vos démarches puis partager les informations utiles à votre relation |
| G03-T087 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Pour discuter de contraception, tu préfères… Vous renseigner ensemble auprès d’un professionnel de santé / Préparer chacun vos questions puis en discuter et demander conseil si nécessaire |
| G03-T088 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Si tu n’es pas à l’aise pour raconter un détail de ton passé sexuel, tu préfères… Dire simplement que tu souhaites le garder privé / Expliquer pourquoi tu ne veux pas entrer dans ce détail, sans le raconter |
| G03-T094 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Pour garder notre intimité privée auprès des amis, tu préfères… Convenir à l’avance des sujets qui restent entre nous / Vérifier l’accord de l’autre avant de partager un élément personnel |
| G03-T098 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Après un moment intime qui t’a laissé des questions, tu préfères… Proposer un petit échange dès que vous êtes au calme / Demander un vrai moment à part pour en parler plus tranquillement |
| G03-T099 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Si un proche pose une question sur notre vie sexuelle, tu préfères… Répondre clairement que le sujet reste privé / Réorienter la conversation avec humour sans donner de détail |
| G04-Q071 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui de nous deux lancerait le premier une discussion sur nos envies sexuelles ? |
| G04-Q075 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui de nous deux utiliserait plus facilement les mots exacts pour parler de sexualité ? |
| G04-Q076 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui de nous deux commencerait plus volontiers une discussion sur le sexe par une plaisanterie ? |
| G04-Q079 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui de nous deux aurait le plus besoin d’un moment calme pour parler de sa vie sexuelle ? |
| G04-Q080 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui de nous deux voudrait préciser ce que signifie « être à l’aise » avant de poursuivre une conversation sur le sexe ? |
| G04-Q084 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui de nous deux rirait le plus facilement pour cacher sa gêne pendant une discussion sur le sexe ? |
| G04-Q086 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui de nous deux poserait le plus facilement une limite à ce qu’on raconte de notre intimité aux amis ? |
| G04-Q089 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui de nous deux demanderait plus volontiers qu’un message intime reste seulement dans notre conversation ? |
| G04-Q093 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui de nous deux penserait le plus vite à demander ce que l’autre souhaite garder privé de son passé sexuel ? |
| G04-Q095 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Qui de nous deux préférerait parler des attentes sexuelles avant une première nuit ensemble ? |
| G10-O081 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Parler de ses préférences sexuelles est plus facile par message qu’en face à face. |
| G10-O083 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Une conversation sur les envies sexuelles est plus utile à un moment calme qu’au lit. |
| G10-O085 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Il est plus facile de parler de ce qui plaît que de ce qu’on aimerait changer au lit. |
| G10-O086 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Une petite discussion après avoir fait l’amour peut prolonger la complicité. |
| G10-O088 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Dire qu’on manque d’expérience peut faciliter une première conversation sur la sexualité. |
| G10-O099 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Les mots tendres rendent une conversation sexuelle plus facile que l’humour. |
| G09-P090 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Après une conversation franche sur nos envies sexuelles, j’aimerais me sentir… |
| G09-P096 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Une chose intime que je préfère garder hors des conversations avec mes amis, c’est… |
| G05-D073 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quel mot te gêne le plus à prononcer dans une conversation sur le sexe ? |
| G05-D075 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quelle phrase t’aiderait à lancer une discussion sur notre vie sexuelle sans te sentir maladroit ? |
| G05-D078 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | À quel moment trouves-tu le plus simple d’avoir une vraie conversation sur la sexualité ? |
| G05-D089 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quand un échange sur le sexe devient gênant, qu’est-ce qui t’aiderait le plus à reprendre la conversation ? |
| G05-D091 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quel aspect de ton passé sexuel préfères-tu garder privé ? |
| G05-D099 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quelle limite aimerais-tu poser sur ce que tes amis peuvent savoir de ta vie sexuelle ? |
| G05-D100 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Quelle attitude te ferait sentir que tu peux parler de tes limites sexuelles sans être jugé ? |
| G01-A030 | moyen | ton léger (invente) mais sujet sensible (argent) : Moyen ou Soft ? | Invente deux petites attentions qu'on pourrait s'offrir à distance sans dépenser d'argent. Choisis celle que tu préfères. |
| G01-A041 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Écris un sujet lié à la sexualité dont tu n'as pas encore osé me parler, puis une question simple pour ouvrir la discussion. |
| G01-A045 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Dis-moi comment tu préfères qu'on aborde le sexe avec toi : par une conversation directe, par l'humour ou autrement. Donne un exemple de phrase qui te mettrait à l'aise. |
| G01-V075 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Si tu devais choisir ce qui doit rester strictement entre nous dans nos échanges sur le sexe, que voudrais-tu garder privé ? |
| G01-A053 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Écris un message pour dire que tu aimerais parler de notre vie sexuelle, sans reproche ni sous-entendu. |
| G01-A055 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Écris une chose que tu ne veux pas voir partagée sur notre intimité, puis demande-moi ce que je voudrais garder privé. |
| G07-C072 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Donne trois mots qui peuvent apparaître dans une discussion sur le plaisir sexuel. |
| G07-C082 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Donne trois façons de commencer une discussion sur les envies sexuelles. |
| G07-C086 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Cite trois moments calmes où des adultes peuvent parler de leur vie sexuelle. |
| G07-C090 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Trouve trois phrases pour dire qu’on aimerait parler de sexualité plus tard. |
| G07-C097 | moyen · +18 | carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer | Cite trois détails qui peuvent faire préférer un lieu privé pour parler de sexualité. |
