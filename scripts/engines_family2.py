"""Configuration des moteurs et textes de règles — famille 2 « Mots et répartie ».

Moteur générique « board » côté base : état public partagé, secrets par joueur, coups validés un par un
(supabase/migrations/20261022000410_board_family2_rules.sql). Les textes sont affichés aux joueurs.
"""

SHARED = "Le jeu vérifie chaque coup sur le serveur. Ce que seul l'un de vous doit voir reste caché à l'autre."


def board(rounds, score="coop", turn="alternate"):
    return {"engine": "board", "rounds": rounds, "score": score, "turn": turn}


def rules(objective, how_to, details, privacy=SHARED):
    return {"objective": objective, "how_to": how_to, "details": details, "privacy": privacy, "step_texts": {}}


ENGINES = {
    # N2-016
    "taboo": {"config": board(6), "rules": rules(
        "Faire deviner un mot sans prononcer les trois mots interdits.",
        ["Celui qui fait deviner voit le mot et les mots interdits.", "Il écrit un indice ; l'autre propose une réponse.",
         "Jusqu'à trois indices et trois réponses par mot. Les rôles changent à chaque mot."],
        ["Un point commun par mot trouvé, six mots par partie.",
         "Les mots interdits et le mot à deviner sont refusés dans les indices, même accordés.",
         "Un indice qui contourne la règle peut être signalé, sans sanction automatique."])},
    # N2-017
    "anagram": {"config": board(5, turn="free"), "rules": rules(
        "Retrouver le mot caché derrière des lettres mélangées.",
        ["Les mêmes lettres s'affichent chez vous deux.", "Déplacez-les pour essayer, puis proposez un mot.",
         "Le premier mot valide de la bonne longueur fait gagner la manche."],
        ["Tous les mots du lexique formés avec ces lettres sont acceptés.", "Accents ignorés. Cinq manches.",
         "Le temps n'est qu'indicatif."])},
    # N2-018
    "categories": {"config": board(3, score="duel", turn="simultaneous"), "rules": rules(
        "Un petit bac à deux : un mot par catégorie, tous commençant par la lettre tirée.",
        ["Chacun remplit ses quatre cases en privé, puis confirme.", "Les grilles s'affichent ensemble.",
         "Un mot de la liste d'exemples est accepté d'office ; pour un autre mot, c'est l'autre qui valide."],
        ["Un point par mot accepté. Même réponse des deux : un point chacun.", "Trois lettres par partie (C, P, S ou T).",
         "Une case vide ne coûte rien."],
        "Ta grille reste cachée jusqu'à ce que vous ayez confirmé tous les deux.")},
    # N2-019
    "word_chain": {"config": board(1), "rules": rules(
        "Construire ensemble une chaîne : la dernière lettre d'un mot commence le suivant.",
        ["Choisissez votre mot dans la réserve affichée, chacun votre tour.", "Pas de doublon dans la chaîne.",
         "Bloqués ? Passez, ou repartez d'un nouveau mot de départ."],
        ["Douze mots ajoutés, ou deux passes de suite, terminent la partie.", "Score commun : le nombre de mots ajoutés.",
         "Accents ignorés pour les lettres. Une impasse n'est pas une faute."])},
    # N2-020
    "convergence": {"config": board(3, turn="simultaneous"), "rules": rules(
        "Deux mots au départ : trouver le même mot qui les relie.",
        ["Chacun écrit en secret un mot qui relie les deux mots affichés.", "Les deux mots apparaissent ensemble.",
         "S'ils diffèrent, vos deux mots deviennent la nouvelle paire. Cinq essais au plus."],
        ["Réussite quand vos deux mots coïncident (accents et majuscules ignorés).", "Aucune réponse attendue : seul votre accord compte.",
         "Trois paires par partie, sans chronomètre."],
        "Ton mot reste caché jusqu'à ce que vous ayez écrit tous les deux.")},
    # N2-021
    "word_ladder": {"config": board(3), "rules": rules(
        "Passer d'un mot à un autre en changeant une seule lettre à la fois.",
        ["À tour de rôle, changez une lettre du mot actuel.", "Chaque mot intermédiaire doit exister dans le lexique du jeu.",
         "Vous pouvez revenir en arrière ou demander un mot voisin."],
        ["Atteignez le mot d'arrivée. Le chemin le plus court s'affiche à la fin.", "Même longueur à chaque étape.",
         "Trois échelles par partie."])},
    # N2-022
    "word_search": {"config": board(2, turn="free"), "rules": rules(
        "Retrouver cinq mots cachés dans une grille de 6 × 6.",
        ["Touchez la première puis la dernière lettre d'un mot.", "Lignes et colonnes, à l'endroit ou à l'envers.",
         "Vous cherchez ensemble : chaque mot trouvé compte pour vous deux."],
        ["Partie finie quand tous les mots sont trouvés.", "Pas de diagonale.", "Deux grilles par partie."])},
    # N2-023
    "masked_word": {"config": board(5), "rules": rules(
        "Découvrir un mot masqué, lettre par lettre, sans dessin de pendu.",
        ["À tour de rôle, proposez une lettre ou le mot entier.", "Une bonne lettre se révèle à toutes ses places.",
         "Un indice par mot : une lettre offerte."],
        ["Six erreurs au plus par mot. Une lettre déjà essayée ne compte pas.", "Accents ignorés. Cinq mots par partie.",
         "Celui qui commence change à chaque mot."])},
    # N2-024
    "syllables": {"config": board(5, turn="free"), "rules": rules(
        "Recomposer un mot à partir de fragments mélangés.",
        ["Touchez les fragments dans l'ordre pour former le mot.", "Validez quand vous êtes satisfaits.",
         "Dès la troisième manche, un fragment intrus s'est glissé : laissez-le de côté."],
        ["Essais illimités, sans pénalité.", "Le découpage est ludique, pas une leçon de phonétique.", "Cinq mots par partie."])},
    # N2-025
    "letter_market": {"config": board(3, score="duel"), "rules": rules(
        "Acheter les bonnes lettres, puis composer le plus long mot.",
        ["Vous avez chacun A, E, I, O, R, S, T, N et 8 jetons.", "À tour de rôle, achetez au plus trois lettres au marché "
         "(voyelle 2 jetons, consonne 1).", "Puis chacun compose en privé un mot du lexique avec ses lettres."],
        ["Score : la longueur du mot. Égalité partagée.", "Chaque lettre ne sert qu'une fois.",
         "Au moins trois mots sont toujours faisables avec la base et le marché. Trois manches."],
        "Ton mot reste caché jusqu'à ce que vous ayez composé tous les deux.")},
    # N2-026
    "semantic_intruder": {"config": board(8, score="duel", turn="simultaneous"), "rules": rules(
        "Quatre mots, une famille annoncée : un seul n'y a pas sa place.",
        ["Chacun choisit l'intrus en secret.", "Les deux choix s'affichent ensemble, avec l'explication."],
        ["Un point par bonne réponse.", "Huit manches.", "Les critères sont concrets, jamais une question de goût."],
        "Ton choix reste caché jusqu'à ce que vous ayez choisi tous les deux.")},
    # N2-027
    "telegram": {"config": board(4), "rules": rules(
        "Faire passer une scène avec cinq mots seulement.",
        ["L'un reçoit une scène et écrit exactement cinq mots, sans les mots de la scène.",
         "L'autre écrit une phrase qui reconstruit la scène (60 caractères au plus).",
         "La scène s'affiche, puis l'auteur dit si l'idée est passée. Les rôles s'inversent."],
        ["Pas de score automatique de sens : c'est l'auteur qui juge.", "Un mot avec apostrophe ou trait d'union compte pour un.",
         "Quatre scènes par partie."])},
    # N2-028
    "rhymes": {"config": board(2), "rules": rules(
        "Composer une chaîne de mots qui riment, même quand le sens part de travers.",
        ["Un son est tiré ; à tour de rôle, ajoutez un mot qui rime.", "Une petite phrase est possible, facultative.",
         "Un indice donne le début d'un mot encore libre."],
        ["Huit mots de la liste du jeu, ou deux passes de suite, terminent la manche.",
         "La rime suit une liste relue : le son compte, pas seulement les dernières lettres.", "Résultat commun, deux sons par partie."])},
    # N2-029
    "clue_grid": {"config": board(2), "rules": rules(
        "Un seul mot d'indice doit faire trouver trois mots du plateau.",
        ["Celui qui donne l'indice voit les 3 cibles, les 8 mots neutres et le piège.",
         "Il donne un mot ; l'autre touche jusqu'à trois mots.",
         "Un mot neutre arrête le tour, le piège termine la manche."],
        ["Réussite si les trois cibles sont trouvées en trois tours au plus.", "L'indice ne peut pas être un mot du plateau.",
         "Deux plateaux par partie, rôles inversés."])},
    # N2-030
    "sentence_order": {"config": board(3), "rules": rules(
        "Remettre en ordre une phrase coupée en morceaux.",
        ["À tour de rôle, déplacez un morceau.", "La phrase d'origine est reconnue dès qu'elle est reconstituée.",
         "Une autre phrase vous convient ? Validez-la tous les deux."],
        ["Dix déplacements au plus, puis la phrase d'origine s'affiche.", "La ponctuation reste attachée à son morceau.",
         "Trois phrases par partie."])},
    # N2-124
    "word_growth": {"config": board(3), "rules": rules(
        "Faire grandir un petit mot, une lettre à la fois.",
        ["À tour de rôle, ajoutez une lettre et réordonnez pour former un nouveau mot.", "Aucune lettre ne disparaît.",
         "Un indice propose une lettre possible."],
        ["La manche se termine quand plus aucun mot ne peut grandir.", "Score commun : le nombre d'étapes.",
         "Les chemins possibles s'affichent à la fin. Trois mots de départ par partie."])},
    # N2-125
    "cross_letters": {"config": board(3, turn="free"), "rules": rules(
        "Placer deux mots de cinq lettres qui se croisent sur une seule tuile.",
        ["L'un remplit l'horizontale, l'autre la verticale, avec les tuiles communes.",
         "La tuile du centre doit servir aux deux mots.", "Chacun propose son mot ; le jeu dit s'il est juste."],
        ["Réussite quand les deux mots se lisent dans le bon sens et partagent la tuile du centre.",
         "Trois grilles par partie."])},
    # N2-126
    "rebus": {"config": board(6, turn="free"), "rules": rules(
        "Deux images, des sons à assembler, un mot à trouver.",
        ["Regardez les deux images et dites-les à voix haute dans l'ordre.", "Chacun peut proposer une réponse.",
         "Un indice affiche la lecture de chaque image."],
        ["Trois essais communs par rébus, puis la solution s'affiche avec son explication.",
         "On assemble les sons, pas l'orthographe. Accents ignorés.", "Six rébus par partie."])},
}
