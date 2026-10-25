# Lot6 — correction 21:54

Base locale :9fae209d484ba20bf6708c23be579913629b5f49, même branche. Aucun push, merge, rebase ou déploiement.

## Interface
- Emblème central supprimé du composant DuoIdentity : Home et Espace gardent les deux portraits, sans ajout décoratif.
- Se découvrir reprend une carte pastel du même langage que les autres. Bitmap3D alpha conservé, rectangle blanc CSS retiré.
- Titre et illustration des cartes de jeux centrés. Plateaux/choix concernés centrés avec largeur bornée ; champs gardent leur alignement de lecture, plateaux denses gardent leur défilement local.
- 5/10/20 questions : trois commandes égales sur une ligne, labels pouvant se répartir sur plusieurs lignes à200%, cibles>=44px.
- Avertissement court existant au lancement aléatoire et au salon, sans activation+18. Description courte du salon conservée ; textes redondants de pied retirés. Barre de validation du salon non superposée aux réglages.
- Un refus d'enregistrement du nombre choisi est visible et bloque la navigation, au lieu de démarrer silencieusement avec le réglage par défaut.

## Migration additive préparée
20261029000400_random_mixed.sql publie une nouvelle version RND1, garde content_level=standard (mode mixte dans Se découvrir) et adult_available=true. Pool : six banques ordinaires existantes et les huit banques q_hc_*. Exceptions q_aron/q_series et tous les test_form hors mélange. Aucun texte/source_position/idx/statut de droits/licence modifié. Disponibilité des banques ne vaut pas autorisation commerciale.
Le serveur tire une file persistée, applique les exclusions, mémorise les cartes réellement présentées par duo et jeu dans private.pack_draws. Pas de répétition d'identifiant avant épuisement ; si le reliquat est inférieur au nombre demandé, la séance termine ce reliquat, puis la suivante ouvre un nouveau cycle. Le couple et la file sont préservés après reconnexion. Les versions anciennes conservent le moteur antérieur.
Les feedbacks trop_intime des deux membres écartent la carte sans exposer leur auteur. Les exclusions de thèmes privées sont respectées lorsqu'une annotation topic_tags est disponible. Par prudence, une carte non annotée n'est pas candidate si une exclusion de thème existe. La majorité des banques actuelles n'a pas cette annotation : certaines préférences peuvent donc empêcher le démarrage, signalé par une erreur neutre. Aucune classification de thèmes inventée ni suppression de contenu.

## Validation exécutée
Types, lint, build et13tests unitaires réussis.42rendus aux six largeurs320/360/390/430/768/1440, huit rendus texte200%, puis six captures finales390x844 et reprise ciblée du salon après allègement. Pas de débordement global, masquage sous navigation, erreurJS ou cible<44 détectée.
Douze lancements navigateur :5/10/20 à320/360/390/430, réglage envoyé correctement, trois boutons égaux sur la même ligne, avertissement présent et aucun checkbox d'activation. Refus réseau du réglage testé, sans navigation. Deux portraits sans emblème, bitmap sans fond CSS et centrage vérifiés. Pixels des vues bibliothèque/questions/salon et planche finale inspectés.
c26_random_mixed.sql réussi :14banques, exceptions intactes,5/10/20, exclusion de B forçant un tirage effectivement À huis clos, aucune répétition interne et entre séances présentées, reconnexion et manche suivante stables, réponses privées non révélées, tiers refusé, exclusions de thèmes et annotations, erreur sans cartes. Fixtures SQL transactionnelles avec rollback, comptes fictifs uniquement.
c18_sans_permission_adulte et c25_random réussis. Validation supplémentaire sur une nouvelle base jetable noodeu_lot6_clean_2154 : les58migrations finales appliquées depuis le shim vide, puis c18/c25/c26 réussis. Cela valide le fichier de migration final complet.
Pendant l'itération locale, la garde published_version_is_immutable a refusé une tentative de correction de règles dans une version publiée. Aucun contournement : ajout d'une nouvelle version sur la base d'essai, puis validation propre depuis zéro. Un premier test attendait un résultat JSON alors que not_enough_cards lève une exception ; attente corrigée, comportement d'erreur testé avec succès.

## Limites / livraison
Tests navigateur sur fixtures ; pas de Safari/iOS, clavier mobile physique ou réseau Supabase multi-appareils. Migration uniquement testée localement et préparée pour revue, non appliquée à distance. Les limitations vidéo/audio/stockage privé des lots précédents restent valables.
Planche Library : libfile_9a7d83972f1481918384c53edc7a4e57. ZIP indépendants<18Mo : code+rapports+bundle incrémental, captures+résultats, assets+manifest. Originaux PNG conservés au workspace ; WebP de production tous conservés. Aucune génération Runway supplémentaire.
