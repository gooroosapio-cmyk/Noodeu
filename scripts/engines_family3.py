"""Configuration des moteurs et textes de règles — famille 3 « Dessin et création ».

Moteur « board » côté base (supabase/migrations/20261022030010_board_family3_rules.sql). Aucune reconnaissance
d'image : c'est toujours l'autre joueur qui devine ou qui valide. Textes affichés aux joueurs.
"""
import math

EXTRA_BANKS = ["palette_scenes"]
SHARED = "Le jeu vérifie chaque coup sur le serveur. Ce que seul l'un de vous doit voir reste caché à l'autre."
CREATION = "Votre création reste dans la partie ; vous pouvez la garder en souvenir si vous êtes d'accord tous les deux, et l'enregistrer en image."


def board(rounds, score="coop", turn="alternate", **extra):
    return {"engine": "board", "rounds": rounds, "score": score, "turn": turn, **extra}


def rules(objective, how_to, details, privacy=SHARED):
    return {"objective": objective, "how_to": how_to, "details": details, "privacy": privacy, "step_texts": {}}


def stroke(points, c=0):
    return {"c": c, "w": 1, "p": [[round(x, 3), round(y, 3)] for x, y in points]}


def arc(cx, cy, r, a0, a1, n=16):
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / n), cy + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


# Amorces des gribouillis (traits normalisés 0..1), une par forme de la banque « doodle_shapes ».
STARTERS = {
    "arc ouvert": [stroke(arc(0.5, 0.55, 0.22, math.pi, 2 * math.pi))],
    "spirale": [stroke([(0.5 + 0.02 * t * math.cos(t), 0.5 + 0.02 * t * math.sin(t)) for t in [i * 0.4 for i in range(32)]])],
    "zigzag": [stroke([(0.25 + 0.1 * i, 0.45 if i % 2 else 0.6) for i in range(6)])],
    "deux cercles": [stroke(arc(0.4, 0.5, 0.08, 0, 2 * math.pi)), stroke(arc(0.6, 0.5, 0.08, 0, 2 * math.pi))],
    "boucle": [stroke([(0.3, 0.6), (0.45, 0.4), (0.55, 0.35), (0.6, 0.45), (0.5, 0.55), (0.45, 0.45), (0.6, 0.35), (0.72, 0.6)])],
    "vague": [stroke([(0.2 + 0.04 * i, 0.5 + 0.06 * math.sin(i * 0.8)) for i in range(16)])],
    "triangle ouvert": [stroke([(0.35, 0.65), (0.5, 0.35), (0.65, 0.65)])],
    "ligne brisée": [stroke([(0.25, 0.6), (0.4, 0.45), (0.5, 0.55), (0.62, 0.38), (0.75, 0.5)])],
    "ovale incliné": [stroke([(0.5 + 0.15 * math.cos(a) * math.cos(0.5) - 0.08 * math.sin(a) * math.sin(0.5),
                               0.5 + 0.15 * math.cos(a) * math.sin(0.5) + 0.08 * math.sin(a) * math.cos(0.5))
                              for a in [i * 2 * math.pi / 24 for i in range(25)]])],
    "trois points": [stroke([(0.4, 0.5)]), stroke([(0.5, 0.42)]), stroke([(0.6, 0.5)])],
    "crochet": [stroke([(0.5, 0.3), (0.5, 0.55)] + arc(0.42, 0.55, 0.08, 0, math.pi))],
    "demi-lune": [stroke(arc(0.5, 0.5, 0.15, math.pi / 2, 3 * math.pi / 2) + arc(0.55, 0.5, 0.1, 3 * math.pi / 2, math.pi / 2))],
}

CONSTRAINTS = ["deux couleurs seulement", "un seul objet géant", "titre tout en bas", "tout doit être symétrique",
               "au moins un objet à l'envers", "aucun objet au centre"]

WEAVE_PALETTE = [{"name": "lavande", "hex": "#C7B5E5"}, {"name": "or", "hex": "#E2B33C"}, {"name": "corail", "hex": "#F17868"},
                 {"name": "menthe", "hex": "#A9D9C2"}, {"name": "prune", "hex": "#663C59"}, {"name": "bleu", "hex": "#91BDD4"}]

ENGINES = {
    # N2-031
    "draw_guess": {"config": board(6), "rules": rules(
        "Faire deviner un objet par le dessin, sans écrire de lettres.",
        ["Celui qui dessine voit l'objet ; l'autre voit le dessin se construire.", "Trois propositions pour trouver.",
         "Les rôles changent à chaque manche."],
        ["Un point commun par objet trouvé, six manches.", "Pas de lettres ni de chiffres dans le dessin.",
         "Aucune reconnaissance automatique : c'est toi qui devines."])},
    # N2-032
    "complete_doodle": {"config": board(2, starters=STARTERS, creation=True), "rules": rules(
        "Transformer un gribouillis en dessin, trois traits à la fois.",
        ["Une amorce est dessinée pour vous.", "À tour de rôle, ajoutez jusqu'à trois traits, puis passez la main.",
         "Après quatre passages, chacun propose un titre."],
        ["Pas de note artistique.", "Tu peux annuler tes propres traits pendant ton passage.", "Deux gribouillis par partie."], CREATION)},
    # N2-033
    "draw_dictation": {"config": board(2), "rules": rules(
        "Reproduire un modèle géométrique décrit seulement par des mots.",
        ["Le guide voit le modèle et le décrit par écrit.", "L'autre place cercles, carrés et triangles sur une grille 6 × 6 "
         "et peut poser des questions.", "Quand le dessinateur valide, les deux grilles s'affichent côte à côte."],
        ["Score indicatif : les formes à la bonne case (et dans le bon sens pour les triangles).",
         "Quatre formes puis six. Les rôles changent."])},
    # N2-034
    "exquisite_drawing": {"config": board(1, creation=True), "rules": rules(
        "Un personnage dessiné à deux, sans voir les parties de l'autre.",
        ["Trois bandes : tête, corps, jambes. L'un dessine la tête et les jambes, l'autre le corps.",
         "Seuls deux repères de raccord dépassent d'une bande à l'autre.", "Quand les trois bandes sont prêtes, la créature apparaît."],
        ["Donnez-lui un nom tous les deux.", "Aucun score."], CREATION)},
    # N2-035
    "pixel_art": {"config": board(1, creation=True), "rules": rules(
        "Une mosaïque de 8 × 8 à deux, d'après un petit modèle.",
        ["Chacun peint avec ses trois couleurs.", "Pour recouvrir une case de l'autre, propose le changement : il l'accepte ou non.",
         "Validez tous les deux quand le tableau vous plaît."],
        ["Mode modèle : la mosaïque est comparée case par case au modèle (case peinte ou vide).", "Une seule mosaïque par partie."], CREATION)},
    # N2-036
    "tangram": {"config": board(1, turn="free"), "rules": rules(
        "Reformer le carré avec les sept pièces du tangram.",
        ["Touche une pièce, puis déplace-la avec les flèches.", "Tourne-la d'un quart de tour ; seul le parallélogramme se retourne.",
         "Vous pouvez déplacer les pièces tous les deux."],
        ["Réussite quand la silhouette est couverte exactement, sans chevauchement (contrôle par surfaces, pas par cadres).",
         "Les pièces se posent sur une grille : la rotation se fait par quarts de tour."])},
    # N2-037
    "jigsaw": {"config": board(2, turn="free"), "rules": rules(
        "Reconstituer une illustration découpée en carreaux.",
        ["Touche un carreau, puis l'emplacement où l'échanger.", "Vous pouvez jouer tous les deux, sans ordre imposé."],
        ["3 × 3 puis 4 × 4. Les déplacements sont comptés, sans compétition.", "Découpe rectangulaire, pas de rotation."])},
    # N2-038
    "sticker_portrait": {"config": board(1, turn="simultaneous", creation=True), "rules": rules(
        "Composer chacun un personnage en gommettes, puis les découvrir ensemble.",
        ["Choisis jusqu'à douze gommettes et place-les.", "Quand vous avez fini tous les deux, les deux portraits s'affichent."],
        ["Un personnage imaginaire, jamais une description d'une vraie personne.", "Enregistrable en image."],
        "Ton portrait reste caché jusqu'à ce que vous ayez fini tous les deux.")},
    # N2-039
    "emblem": {"config": board(1, creation=True), "rules": rules(
        "Créer votre petit emblème : deux symboles, un support, un nom.",
        ["L'un choisit un symbole et sa couleur, puis l'autre.", "Choisissez ensemble la forme du support et un nom (24 caractères).",
         "Validez tous les deux."],
        ["Les symboles sont des dessins originaux, aucun logo officiel.", "Enregistrable en image."], CREATION)},
    # N2-040
    "stroke_budget": {"config": board(4), "rules": rules(
        "Faire deviner un objet en dix traits, pas un de plus.",
        ["Chaque trait compte, même un simple point.", "La gomme coûte aussi un trait.", "Trois propositions pour trouver."],
        ["Une couleur. Quatre manches, rôles alternés.", "Un point commun par objet trouvé."])},
    # N2-041
    "mirror_draw": {"config": board(1, creation=True), "rules": rules(
        "Dessiner sur la moitié gauche : le miroir complète la droite.",
        ["À tour de rôle, deux traits chacun.", "Chaque trait est reflété automatiquement.", "Après six tours, nommez la figure."],
        ["Pas de symétrie à corriger : elle est automatique.", "Traits dans la moitié gauche uniquement."], CREATION)},
    # N2-042
    "palette": {"config": board(1, creation=True), "rules": rules(
        "Composer une palette de cinq couleurs pour une scène.",
        ["Chacun choisit trois couleurs en secret.", "Les couleurs communes sont gardées.",
         "Puis proposez à tour de rôle une couleur ; l'autre l'accepte ou non, jusqu'à cinq."],
        ["Un choix esthétique, sans bonne réponse.", "Chaque couleur a un nom lisible."],
        "Tes trois couleurs restent cachées jusqu'à ce que vous ayez choisi tous les deux.")},
    # N2-043
    "poster": {"config": board(1, constraints=CONSTRAINTS, creation=True), "rules": rules(
        "Une affiche pour un événement improbable, avec une contrainte.",
        ["L'un écrit le titre, l'autre compose le visuel avec des objets.", "Puis l'autre écrit le sous-titre et le premier un détail."],
        ["Titre 40 caractères, sous-titre 80, cinq objets au plus.", "Événement et date fictifs, affichés comme tels."], CREATION)},
    # N2-044
    "silent_comic": {"config": board(1, creation=True), "rules": rules(
        "Une bande dessinée muette en trois cases.",
        ["L'un dessine la première case, l'autre la deuxième, le premier conclut.", "Pas de texte dans les cases ; gommettes autorisées.",
         "Chacun donne ensuite un titre en secret."],
        ["Les titres s'affichent ensemble : l'écart d'interprétation fait partie du jeu.", "Aucun score."],
        "Ton titre reste caché jusqu'à ce que vous l'ayez écrit tous les deux.")},
    # N2-045
    "tile_scene": {"config": board(1), "rules": rules(
        "Construire une petite île tuile après tuile.",
        ["À tour de rôle, posez une tuile de votre main à côté d'une tuile existante.", "Une maison doit toucher un chemin.",
         "Objectif commun : deux maisons reliées par le même chemin."],
        ["Fin à quinze tuiles posées.", "Aucune tuile jouable ? L'échange est gratuit."])},
    # N2-127
    "constellation": {"config": board(1, creation=True), "rules": rules(
        "Composer une petite mélodie en reliant des étoiles.",
        ["Chaque étoile porte une note (do, ré, mi, sol, la).", "À tour de rôle, ajoutez une étoile : une même étoile peut revenir.",
         "Huit notes, puis donnez un nom à votre constellation."],
        ["Le son ne démarre que si tu touches « Écouter ».", "Les notes s'affichent aussi en toutes lettres."], CREATION)},
    # N2-128
    "flipbook": {"config": board(1, creation=True), "rules": rules(
        "Un petit dessin animé de huit images, à deux.",
        ["L'un fait les images impaires, l'autre les paires.", "Sur chaque image, place les deux objets et ajoute jusqu'à trois traits.",
         "L'image précédente apparaît en transparence pour t'aider."],
        ["Lecture à 4 images par seconde, avec pause et image par image.", "Si les animations sont réduites sur ton appareil, la lecture est manuelle."],
        CREATION)},
    # N2-129
    "weaving": {"config": board(1, weave_palette=WEAVE_PALETTE, creation=True), "rules": rules(
        "Tisser un petit textile de 6 × 6 d'après un modèle.",
        ["L'un choisit les couleurs des fils verticaux, l'autre des fils horizontaux.",
         "Chacun règle les croisements de sa moitié : fil vertical dessus ou dessous.", "Donnez un titre, puis validez tous les deux."],
        ["Mode modèle : les 36 croisements sont comparés au modèle.", "Un repère indique quel fil passe dessus, sans dépendre des couleurs."],
        CREATION)},
}
