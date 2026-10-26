# Intégration de la révision compacte du26octobre

Autorisation propriétaire04:13UTC : corrections, fusion et déploiement pour essai en ligne. Aucun accord de modifier les credentials, permissions, Storage/RLS ou scheduler. Ce rapport décrit le code intégré ; les statuts de publication et le SHA distant sont consignés séparément après tentative, jamais déduits d'un build local.

## Réconciliation

Base locale conservée66c3669, correctifs compacité4b0f82f. Distant exact importé via connecteur GitHub :6ca9725562b58e99d454b460bd319416dad0733a ; huit commits signés,68blobs et arbres vérifiés, ancêtre commun104564d. Aucun reset, force-push ou suppression de données.

AdminQuestions, route, entrée conditionnelle, traductions, styles et tests de Claude sont conservés ; authentification identique depuis104564d, confirmation du mot de passe maintenue. Home conserve le sélecteur multi-duos ajouté par Claude. Bibliothèque conserve le classement des jeux de conversation. Les tirages SQL gardent la correction qui saute les questions supprimées par l'Admin.

Quatre conflits résolus après comparaison : SessionScreen garde la dernière console cerise et le menu compact, Chat réunit les zones protégées, ConversationGames conserve les objets et opinions sans code de justesse, WordGames conserve AZERTY et repriseHTTP503. GameFrame et son fichierCSS distants sont conservés comme sources, mais leur ancien thème canard et leurs règles globales ne sont pas importés dans la console active. Aucun élément fonctionnel Admin n'est écarté par ce choix visuel.

## Corrections visibles

- La ligne Règles/Pause/Quitter disparaît pendant les jeux. Menu44px avec Sheet, focus/Escape/retour et confirmation de sortie ; Réduire continue sans mutation de séance.
- Noms/avatars conservés, sous-titres Toi/Partenaire redondants retirés ; tours, validation et présence réels restent.
- Petitbac : huit rubriques, retrait Rempli/Àremplir, état d'envoi/erreur conservé, cartes96px minimum.
- Tupréfères : portes originales en arrière-plan à30%, flou0,7px, voile40%, deux choix égaux. Contraste conservateur minimal9,87:1. Questions standards intégrales320/390/430 ; lecture défilable clavier des textes longs/200%.
- Questions ouvertes : espace de lecture208px, illustration réduite ; question standard complète sans écrasement du champ. Textes longs et réponses restent intégraux, sans clamp.
- Naval : vue entière100cases rectangulaires en lecture seule ; Cibler active44px/66px, clavier/pan/rotation/confirmation. Les positions de navires ne changent pas ; sprites contain. Placement compact : plateau initial entier à320×640,360×740,390×844,430×932. Petiteshauteurs/texte200% peuvent défiler.

## Défauts d'intégration traités

Admin : preuve locale avant correction de deuxRPC sur double soumission synchrone (ajout/modification/suppression). Verrousref+finally et contrôlesbusy ajoutés sans changement de rôle ; une seule requête après correction.11scénarios Admin locaux réussis, dont refus/révocation et annulation de suppression.

SQL : préfixes Claude300001–800 conservés, nouvelles009/010renommées300009/300010 ; testsC38–C40 et manifest explicite19.300011préparée exclut l'indexUnicode du mapping Admin, sans toucher ACL/RLS/guard. Voir SQL_CONCORDANCE_MERGE_20261026.md et ses preuves.68migrations et19tests passent dans une nouvelle base Docker jetable ; quatre courses concurrentes, upgrade et activation sous rollback passent. Zéro opération DBproduction.

## Validation et limites

Lint, TypeScript,13unitaires, build ; console/réduction/reprise, lecture longue200%, chat16contextes×3positions ; cartes6configurations ; naval64vues+2parcours,13groupes antérieurs et10fluxmini-jeux ; compacité24vues ; Admin11scénarios ; absenceRPC404/PGRST202 et pannecompteur503 ; authconnexion/inscription et doubleenvoi. Les fixtures contiennent des données synthétiques ; aucune modification de compte réel.

Les anciens tests utilisant selectsalon, boutonsG08 ou boutonmicro inactif ont été adaptés aux vrais contrôles. Le build conserve son avertissement de chunk>500kB. Pas de mesure sur appareil physique, clavierlogicielAndroid/iOS ou connexionRealtime de production.

## Dépendances et publication

La documentation Claude annonce300003–800appliquées ; cette information n'est pas un contrôle direct de la DB effectué ici. Sans001, notes/photo personnelle sont indisponibles explicitement ; coffre existant et couverture par défaut restent. Home possède un repli de compteur et un état d'erreur honnête sans questionRPC. Audio restefalse, Google inactif, vidéoRunway absente. Le clipfleur est une démonstration locale distincte.

300009/300010/300011 ne sont pas appliquées à distance. Dots12 reste une activation séparée, hors automigrations ; ancienDots5compatible. Ne jamais rejouer les migrations historiques/purges ou scripts destructifs sur une base réelle.

La documentation Vercel distante indique que ccr-7a7de876-azitw6 produit une prévisualisation, avec promotion explicite pour noodeu.vercel.app. Un statut GitHub Vercelsuccess seul ne vaut donc pas miseenproduction. AucunoutilVercel, CLIauthentifiée ou credentialVercel existant n'est disponible dans cet exécuteur. La publication GitHub autorisée est poursuivie ; une promotion ou connexion Vercel du propriétaire peut rester nécessaire. Ne pas inventer une branchemain de production ni modifier la configuration pour contourner cette limite.
