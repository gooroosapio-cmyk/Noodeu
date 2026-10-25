# Publication autorisée le25octobre2026

Réconciliation avec7fe29dfc4ca10c0f5624325a41d0c587294d677e : ajout Claude de confirmation du mot de passe conservé dans le design actuel, avec blocage des différences et protection anti-double-envoi. Aucun réglage Auth/Supabase modifié ; l'état de confirmation des e-mails documenté par Claude n'est pas vérifié par ce lot.

Types/lint/build/13unitaires réussis ; parcours auth connexion/inscription/confirmation/erreur/doubleclic/Googleinactif et salon/vidéoabsente/reducedmotion réussis. Captures finales320/390. Les comptes utilisés sont des fixtures, aucun compte réel créé ou modifié. Scan des460fichiers différents avant publication : aucun motif de clé privée, tokenGitHub, URLAWSsignée ou cléservice_role littérale trouvé. Captures suivies issues des fixtures fictives, assets originaux ou historiques conservés.

Les changements DB des lots refonte ne sont pas déployés. Audio explicitement désactivé au frontend, Google non configuré, vidéo non intégrée. Notes/couverture indisponibles clairement si RPCabsent ; tirage général classique conservé tant que config.pack.mixed_queue n'est pas vraie, avec explication de la dépendance serveur. Aucune migration/cron/RLS/storage/credential activé par le build.

La publication peut passer par les GitDataAPI du connecteur GitHub existant : le jetonCLI est invalide. Dans ce cas, le commit publié est un instantané dont l'arbre doit être identique à l'arbre local réconcilié, avec la tête de Claude comme parent. L'historique local détaillé reste conservé dans le dépôt et les bundles. Aucun force-push.

Vercel : deux checks existants noodeu/noodeu-wup1 ; projet cible noodeu. La documentation existante indique que ccr-7a7de876-azitw6 crée des prévisualisations et qu'une promotion explicite est requise. Aucun outil Vercel disponible ici. Le proxy de l'exécuteur refuse CONNECT vers noodeu.vercel.app (HTTP403), avant atteinte du site. Cette limite doit être levée via un accès autorisé pour la recette publique ; ne pas assimiler succès du build à succès de mise en production.

Le build publie assets/noodeu-release.json, non mis en cache, avec le SHA fourni par Vercel pour vérifier la version servie. Aucune donnée secrète dans cet endpoint.
