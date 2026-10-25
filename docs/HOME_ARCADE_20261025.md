# Accueil Arcade — révision locale du 25 octobre 2026

## Périmètre
Suite à la référence « 02 · Arcade boutique » : bandeau duo horizontal compact (avatars réels chevauchants, noms, statut en ligne seulement si vrai, accès Notre espace), trois filtres égaux, carrousel manuel avec Tu préfères en premier, grille asymétrique question/reprise/progression, deux prochaines activités réelles. Palette cerise/bordeaux conservée. La navigation et le chat flottant restent accessibles. Aucun autre écran refait, aucune publication.

Le parent a inspecté la référence et transmis sa description. Préparation Library réussie pour libfile_7d3b9970ffc08191bfec087c8a967bc6 ; téléchargement par helper dans cet exécuteur terminé en erreur « library file transfer failed: download failed » (exit 1). Aucun fichier local de référence exploitable, pas de nouvelle tentative. Comparaison de composition seulement : ne pas affirmer une correspondance pixel à pixel. Captures nouvelles inspectées réellement sur fixtures fictives.

## Question du moment
Migration préparée `20261029000500_home_moment.sql`, uniquement appliquée au PostgreSQL Docker jetable noodeu_lot6_clean_2154. Douze questions originales nouvelles, courtes, générales, non intimes, sans reprise de banque tierce ou instrument standardisé. Provenance stockée par ligne. Les banques de jeu, leurs exclusions, licences et l'ordre des tests ne sont pas modifiés. Ce choix évite d'exposer un contenu dont les droits ou thèmes ne seraient pas vérifiés sur Home.

RPC `get_home_moment(p_couple)` : contrôle d'appartenance active, verrou par duo, créneau UTC de 3600 secondes déterminé par le serveur, tirage persistant et exclusion de la question précédente. Stockage limité à la dernière question par duo. Une question retirée est masquée immédiatement. Banque vide : question null, pas de texte fictif. Aucun cron ni notification, aucune modification des parties ou réponses en cours.

Frontend : délai calculé depuis server_now/expires_at, refresh à visibilité/retour réseau, rejet des réponses tardives et masquage immédiat des données d'un autre duo. Échec réseau ou RPC absente : état indisponible et Réessayer, aucune question périmée présentée comme actuelle. La progression compte les game_id distincts des sessions ended/closed du seul duo demandé. Les cinq pastilles sont un indicateur plafonné à cinq, pas des résultats inventés. Le nombre exact est affiché.

Sans migration déployée, question ET progression restent indisponibles ; les cartes, navigation et reprise continuent de fonctionner. Aucune prétention de disponibilité production. Nouvelle migration à faire examiner avant application : table privée, droits RPC nouveaux, pas de modification d'une permission existante.

## Vérification exécutée
- Types, lint et build : réussis. Correction de l'accès non typé à process dans vite.config.ts via loadEnv limité au préfixe VERCEL_GIT_ ; aucun secret publié.
- Unitaires existants : 13/13 réussis.
- SQL c27 : réussi sur Docker jetable, transaction rollback. A/B même question et échéance, C rejeté, A–B et A–C isolés, B ne lit pas A–C, progression vide réelle, changement de créneau sans répétition, banque désactivée/vide, droits anonymes et accès direct refusés.
- Navigateur simulé : 8 contrôles réussis (échéance serveur, erreur sans contenu périmé, vide, foreground, carrousel, filtre, clavier/Surprise, reduced-motion). Le premier essai de navigation avec horloge virtuelle et scroll animé a échoué ; passage testé en mouvement réduit/instantané. Le scroll doux reste non automatisé dans ce test.
- 18 rendus : trois états Home (sans duo, avec partie, sans partie), 320/360/390/430/768/1440 px. Aucun débordement horizontal, contenu inaccessible sous nav, erreur JS ou cible mesurée <44px.
- 4 rendus texte 200 % : 320/390 avec/sans partie, mêmes contrôles réussis. Défilement vertical conservé pour ne pas rogner le contenu. La rangée de filtres reste égale, le texte peut revenir à la ligne.
- Captures haut/bas du nouvel accueil, données fictives ; aucun compte réel utilisé. Les images3D existantes originales sont réutilisées (portes, tasse, dé, jeux), aucune nouvelle génération ni dépense.

## Limites et suite
Aucun test de production, de latence réelle multi-appareils, de fermeture navigateur à la frontière horaire, ni revue Admin Claude. Les tests réseau sont simulés, l'isolation SQL est réellement exécutée. Pas d'inspection des pixels de référence faute de téléchargement. Pas de capture avant garantie au SHA1263757, ni comparaison graphique automatisée. Pas de nouvelle vérification distante demandée ; conserver Admin Claude lors de la future réconciliation.

Audio reste désactivé, Google non configuré, vidéo non intégrée. Pause de publication maintenue ; aucune tentative GitHub/Vercel. La passation1263757 reste intacte et le nouveau bundle inclut ce commit comme ancêtre.
