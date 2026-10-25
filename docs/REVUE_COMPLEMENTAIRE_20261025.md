# Revue critique complémentaire — 25 octobre 2026

Relecture indépendante en lecture seule, puis corrections locales par l’agent principal. Aucun accès de production. Branche codex/refonte-incrementale-20261025 basée sur 49d3c1e35052ce06fcca0a61ae465d65ae7b8b92. Au dernier contrôle, le distant a avancé vers 48ec7b40c885e68a279ffb0d43e410823be49bd8 : aucune fusion ni réécriture réalisée, réconciliation à revoir avant intégration.

## Défauts corrigés
- Versions NULL : comparaisons IS DISTINCT FROM pour refuser le contournement des conflits notes/couverture ; tests création et modification sans version.
- Famine worker : timestamp de dernière collecte, sélection des réservations jamais traitées puis plus anciennes tentatives, lot borné à 100 et SKIP LOCKED. Test de 101 réservations sans objet, toutes atteintes sur deux collectes.
- Micro : pistes arrêtées, timers nettoyés et état rétabli si constructeur/start du codec échoue ; permission tardive après passage en arrière-plan n’ouvre pas un enregistrement. Test navigateur avec permission réussie puis exception constructeur.
- Notes : numéro de génération des chargements empêche une ancienne réponse de rétablir un état périmé du même duo. Test avec réponses délibérément inversées.
- Couverture : arrêt de la chaîne après démontage du duo avant upload ou association ; test faux PNG refusé au décodage avant tout upload.
- Audio multipiste : refus de tout fichier autre qu’une unique piste audio. Test avec un vrai fichier WebM à deux pistes.
- Tirage : tests ajoutés pour abandon/recréation sans répétition et passage au cycle suivant après épuisement simulé des cartes éligibles. Ordres source et next_index conservés.

## Validation après corrections
Lint, types, build et 13 tests Node réussis. Trois tests Python réussis. Les 21 fichiers SQL passent sur la base jetable ; c25 renforcé rejoué ensuite avec succès. Quatorze parcours navigateur passent. Les corrections ne changent pas la composition des écrans : les captures déjà livrées restent représentatives. Aucune nouvelle prétention de recette Realtime/Storage/Edge physique.

## Limites restantes explicites
Audio toujours désactivé. Il faut déployer puis tester Edge/Storage/worker/cadence sous autorisation du propriétaire avant de parler d’expérience audio opérationnelle ou de nettoyage automatique en production. L’échéance serveur coupe l’accès ; la latence de suppression physique dépendra de la cadence et des pannes. Les brouillons/couvertures non associés après conflit ou interruption restent privés ; aucun nettoyage automatique des couvertures n’est préparé dans ce lot. Pas de purge implicite.

Le mélange de progression ancienne/nouvelle n’a pas de scénario dédié ajouté ; seule la lecture du code et les suites existantes étayent ce cas. Permissions micro tardives en arrière-plan et interruption de permission au démontage sont protégées par le code, mais non testées sur appareil réel. La validation MIME du service Storage est configurée ; le décodage de couverture est client, pas un scanner serveur. Aucun audit de sécurité exhaustif ou mesure de performance mobile revendiqué.

## Livraison Library
La planche JPEG a finalement été créée par action directe : libfile_665b6b1f50208191a84faf2c622a5fe6. Le parent a reçu un scope_violation à sa lecture : aucun contournement, déplacement ou copie de cette planche pour lui donner accès. Le ZIP final est une livraison distincte explicitement demandée au propriétaire, pas une tentative d’élargir le scope du parent.
