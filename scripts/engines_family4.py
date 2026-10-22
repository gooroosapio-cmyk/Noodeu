"""Configuration des moteurs et textes de règles — famille 4 « Mémoire et observation ».

Moteur « board » côté base (supabase/migrations/20261022040010_board_family4_rules.sql). Ce qu'il faut mémoriser
n'est envoyé qu'à l'écran concerné, puis retiré à la fin de l'observation ; les réponses sont notées sur le serveur.
Aucun temps de réaction n'est comparé entre deux appareils. Textes affichés aux joueurs.
"""

# Banques du kit (data/banques) utilisées directement par ces moteurs.
EXTRA_BANKS = ["objects", "pixel_patterns", "sorts"]
SHARED = "Le jeu vérifie chaque réponse sur le serveur. Ce que tu dois mémoriser n'est affiché que sur ton écran."
PRIVATE = "Ta réponse reste cachée jusqu'à ce que vous ayez répondu tous les deux."
NO_COMPARE = "La comparaison porte sur le jeu, jamais sur la mémoire des personnes."


def board(rounds, score="duel", turn="simultaneous", **extra):
    return {"engine": "board", "rounds": rounds, "score": score, "turn": turn, **extra}


def rules(objective, how_to, details, privacy=SHARED):
    return {"objective": objective, "how_to": how_to, "details": details, "privacy": privacy, "step_texts": {}}


SIMON_BUTTONS = [{"shape": "cercle", "color": "corail"}, {"shape": "carré", "color": "bleu"},
                 {"shape": "triangle", "color": "menthe"}, {"shape": "losange", "color": "jaune"}]

ENGINES = {
    # N2-046
    "memory_pairs": {"config": board(1, turn="alternate"), "rules": rules(
        "Retrouver le plus de paires cachées.",
        ["À ton tour, retourne deux cartes.", "Une paire trouvée te reste et tu rejoues.",
         "Sinon, les deux cartes restent visibles un instant, puis c'est à l'autre."],
        ["Huit paires, un point par paire, égalité possible.", "Pendant que la paire ratée est visible, aucune autre carte ne se retourne."],
        "Les cartes ne sont dévoilées par le serveur qu'au moment où elles sont retournées.")},
    # N2-047
    "change_detection": {"config": board(6), "rules": rules(
        "Repérer l'objet qui a changé de case.",
        ["Observe la grille pendant 12 secondes.", "Après un court masque, un objet a bougé : touche sa nouvelle case.",
         "Vous répondez chacun en privé."],
        ["Un point par bonne case, six manches.", "L'objet bouge toujours vers une case vide."], PRIVATE)},
    # N2-048
    "differences": {"config": board(2, turn="free"), "rules": rules(
        "Trouver les cinq différences entre deux vues de la même scène.",
        ["Alterne entre les deux vues ou regarde-les côte à côte.", "Touche dans la vue modifiée l'objet qui a changé.",
         "Une pastille verrouille chaque différence trouvée."],
        ["Un point par différence trouvée, sans score de vitesse.", "Les erreurs sont comptées à titre indicatif.",
         "Changements possibles : rotation, couleur, taille, reflet, objet absent."])},
    # N2-049
    "zoom_recognition": {"config": board(6), "rules": rules(
        "Reconnaître un objet à partir d'un détail.",
        ["Un détail de l'objet s'affiche.", "Choisis parmi quatre noms, ou élargis le cadrage (trois niveaux au plus)."],
        ["3, 2 ou 1 point selon le cadrage où tu as répondu ; six manches."], PRIVATE)},
    # N2-050
    "visual_search": {"config": board(5, turn="free"), "rules": rules(
        "Retrouver l'icône identique à la cible.",
        ["La cible est affichée au-dessus de la grille.", "Touche l'icône exactement identique : même objet, même couleur."],
        ["Une seule occurrence exacte par grille.", "Un mauvais toucher ajoute une erreur ; moins d'erreurs, plus de points (5 au mieux).",
         "Aucun chronomètre."])},
    # N2-051
    "recall_set": {"config": board(5), "rules": rules(
        "Se souvenir des objets d'un plateau.",
        ["Observe huit objets pendant 15 secondes.", "Puis sélectionne exactement huit objets parmi seize, et confirme."],
        ["Un point par bon objet, sur 8 ; cinq manches.", NO_COMPARE], PRIVATE)},
    # N2-052
    "simon": {"config": board(1, buttons=SIMON_BUTTONS), "rules": rules(
        "Reproduire une suite de boutons qui s'allument.",
        ["Regarde la suite s'allumer, puis touche les boutons dans le même ordre.",
         "Chaque niveau réussi allonge la suite."],
        ["Arrêt après deux erreurs ou au dernier niveau.", "Ton score est la longueur de la plus longue suite réussie.",
         "Le son est facultatif ; chaque bouton a une forme et une couleur."])},
    # N2-053
    "rhythm": {"config": board(4), "rules": rules(
        "Retrouver un motif rythmique.",
        ["Regarde (ou écoute) le motif sur huit temps.", "Puis coche les temps qui étaient joués."],
        ["Un point par temps juste, sur 8 ; quatre manches.", "Pas de frappe en direct : aucun réflexe n'est mesuré.",
         "Le son ne démarre que si tu touches « Écouter »."], PRIVATE)},
    # N2-054
    "ordered_recall": {"config": board(4), "rules": rules(
        "Remettre les objets du panier dans l'ordre d'apparition.",
        ["Six objets apparaissent l'un après l'autre.", "Puis remets-les dans l'ordre, en privé."],
        ["Un point par position exacte, sur 6 ; quatre manches.", NO_COMPARE], PRIVATE)},
    # N2-055
    "spatial_recall": {"config": board(4), "rules": rules(
        "Replacer des objets à leur place sur un plan.",
        ["Observe la grille 4 × 4 pendant 15 secondes.", "Puis replace chaque objet dans sa case."],
        ["Un point par position exacte ; quatre manches.", "Le plateau ne tourne pas entre l'observation et la réponse."], PRIVATE)},
    # N2-056
    "pixel_recall": {"config": board(4), "rules": rules(
        "Reproduire un motif de 5 × 5 cases.",
        ["Observe le motif pendant 12 secondes.", "Puis touche les cases pour les colorer ou les vider."],
        ["Un point par case exacte, vides comprises, sur 25.", "Les différences s'affichent après la réponse de chacun."], PRIVATE)},
    # N2-057
    "sorting": {"config": board(3), "rules": rules(
        "Trier 24 cartes selon une règle affichée.",
        ["Pour chaque carte, touche le bac qui convient.", "Vous avez les mêmes cartes, chacun sur son écran."],
        ["Un point par bonne affectation, sur 24.", "La durée n'est jamais comparée entre deux appareils."], PRIVATE)},
    # N2-058
    "go_nogo": {"config": board(3), "rules": rules(
        "Réagir seulement au bon signal.",
        ["Des formes colorées apparaissent l'une après l'autre.", "Touche uniquement quand c'est la cible indiquée."],
        ["Score : bonnes touches moins fausses alertes.", "Aucune animation clignotante ; un mode lent est proposé.",
         "Tes touches sont envoyées en une fois à la fin de la série."], PRIVATE)},
    # N2-059
    "precision": {"config": board(5), "rules": rules(
        "Retrouver la position d'un repère sur une ligne.",
        ["Un repère s'affiche sur une ligne de 0 à 100 pendant 3 secondes.", "Puis place ton curseur au même endroit et confirme."],
        ["Score : 100 moins l'écart, à chaque manche ; cinq manches.", "Les positions ne dépendent pas de la taille de l'écran."], PRIVATE)},
    # N2-060
    "split_memory": {"config": board(3, score="coop", turn="free"), "rules": rules(
        "Reconstituer ensemble un plateau dont chacun n'a vu que la moitié.",
        ["Chacun observe quatre objets différents pendant 12 secondes.", "Puis placez ensemble les huit objets sur la grille commune.",
         "Validez tous les deux."],
        ["Réussite si les huit positions sont justes.", "Une aide par manche peut révéler une position.",
         "Utilisez le chat pour vous raconter ce que vous avez vu."],
        "Ta moitié du plateau n'est affichée que sur ton écran, et seulement pendant l'observation.")},
    # N2-130
    "silhouette": {"config": board(6), "rules": rules(
        "Reconnaître un objet à sa silhouette.",
        ["Une ombre et quatre objets en couleur.", "Choisis en privé et confirme.", "Un indice peut dévoiler une partie colorée."],
        ["Un point par bonne réponse ; six manches.", "L'indice ne change pas le score mais apparaît au récapitulatif."], PRIVATE)},
    # N2-131
    "layers": {"config": board(6), "rules": rules(
        "Retrouver l'ordre de trois disques superposés.",
        ["Observe quels disques passent devant les autres.", "Range-les du fond vers le devant, puis confirme."],
        ["Un point par ordre exact ; six scènes.", "Un indice révèle la position d'une couche."], PRIVATE)},
    # N2-132
    "rotation": {"config": board(6), "rules": rules(
        "Replacer des objets dans une grille tournée.",
        ["Le modèle reste visible avec une flèche : quart de tour, demi-tour ou trois quarts, toujours dans le sens horaire.",
         "Replace les trois objets dans la grille tournée."],
        ["Un point par position exacte, sur 3 ; six manches.", "Vous pouvez en discuter avant de verrouiller votre réponse."], PRIVATE)},
}
