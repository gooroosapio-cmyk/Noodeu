"""Configuration des moteurs et textes de règles — famille 1 « Complicité et confidences ».

Chaque activité garde ses propres règles (fiche 2.1.0) ; le moteur générique « rounds » côté base applique
la configuration : tirage, étapes privées, ordre, révélation, réactions après révélation.
Les textes sont affichés aux joueurs : pas d'identifiant, de nom de moteur ni de détail technique.
"""

PRIVACY = "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer."

BACKGROUNDS = [
    {"name": "crème", "hex": "#FFF5E8"}, {"name": "menthe", "hex": "#A9D9C2"}, {"name": "jaune doux", "hex": "#F4D57A"},
    {"name": "bleu", "hex": "#91BDD4"}, {"name": "lilas", "hex": "#C7B5E5"}, {"name": "pêche", "hex": "#F6C5A6"},
]
PAPERS = [
    {"name": "papier corail", "hex": "#F17868"}, {"name": "papier menthe", "hex": "#A9D9C2"},
    {"name": "papier jaune", "hex": "#F4D57A"}, {"name": "papier bleu", "hex": "#91BDD4"},
    {"name": "papier lilas", "hex": "#C7B5E5"}, {"name": "papier kraft", "hex": "#D9B48F"},
]
RIBBONS = [
    {"name": "ruban prune", "hex": "#663C59"}, {"name": "ruban crème", "hex": "#FFF5E8"},
    {"name": "ruban rayé", "hex": "#F17868"}, {"name": "ruban doré", "hex": "#C9A227"},
]
LIGHTS = ["lumière du jour", "lampe douce", "guirlande", "bougies virtuelles", "pénombre"]
AMBIANCES = ["calme", "lecture", "musique douce", "fête légère", "rêverie", "matin tranquille"]
MOOD_REACTIONS = ["Merci de me le dire", "Je suis là", "Courage pour la suite", "Ça me fait plaisir pour toi",
                  "On en reparle quand tu veux", "Prends soin de toi"]

CARDS = {"label": "Nombre de cartes"}


def deck_game(rounds_options, default, steps, after=None, extra=None):
    cfg = {"engine": "rounds", "draw": {"deck": True}, "rounds_setting": "cartes",
           "settings": {"cartes": {**CARDS, "options": rounds_options, "default": default}},
           "steps": steps, "after": after or []}
    cfg.update(extra or {})
    return cfg


ENGINES = {
    # N2-001
    "conversation": {
        "config": deck_game([4, 8, 12], 8,
                            [{"key": "answer", "kind": "text", "params": {"max": 600}, "skippable": True}],
                            [{"key": "reaction", "kind": "reaction", "params": {"max": 300}}]),
        "rules": {
            "objective": "Échanger de petites histoires à partir de cartes, à votre rythme.",
            "how_to": ["Lisez la carte.", "Chacun écrit sa réponse en privé (600 caractères au plus) ou passe.",
                       "Quand vous avez confirmé tous les deux, les réponses apparaissent ensemble.",
                       "Un espace de réaction libre suit chaque carte."],
            "details": ["Fin après le nombre de cartes choisi, ou plus tôt si vous arrêtez ensemble.",
                        "Une carte passée s'affiche « Carte passée », sans justification à donner.",
                        "Aucun score, aucune mesure de sincérité."],
            "privacy": PRIVACY,
            "step_texts": {
                "answer": {"title": "Ta réponse", "prompt": "Raconte en quelques lignes.", "hint": "600 caractères au plus.", "confirm": "Confirmer ma réponse"},
                "reaction": {"title": "Réagir", "prompt": "Un mot sur ce que vous venez de lire ?", "hint": "Facultatif.", "confirm": "Envoyer"},
            },
        },
    },
    # N2-002
    "dilemma": {
        "config": deck_game([4, 8, 12], 8,
                            [{"key": "choice", "kind": "choice", "params": {"extras": ["depends", "neither"], "comment_max": 200}, "skippable": True}]),
        "rules": {
            "objective": "Deux options, ton choix : comparez vos préférences, sans bonne réponse.",
            "how_to": ["Choisis en secret une option, « Ça dépend » ou « Aucun des deux ».",
                       "Ajoute une phrase pour expliquer si tu veux.", "Les deux choix apparaissent ensemble."],
            "details": ["Une préférence n'est pas un engagement.", "Pas de classement de compatibilité.",
                        "Un choix non confirmé n'est jamais affiché."],
            "privacy": PRIVACY,
            "step_texts": {"choice": {"title": "Ton choix", "prompt": "Que choisirais-tu ?", "hint": "Une phrase d'explication est facultative.", "confirm": "Confirmer mon choix"}},
        },
    },
    # N2-003
    "experience": {
        "config": deck_game([8, 12], 8,
                            [{"key": "answer", "kind": "yes_no", "skippable": True}],
                            [{"key": "anecdote", "kind": "reaction", "params": {"max": 300}}]),
        "rules": {
            "objective": "Déjà vécu ? Répondez oui, non ou « Je passe », puis racontez si vous en avez envie.",
            "how_to": ["Lis la situation.", "Réponds Oui, Non ou Je passe, sans détail obligatoire.",
                       "Après la révélation, chacun peut ajouter une anecdote."],
            "details": ["« Je passe » n'est jamais compté comme un non.",
                        "À la fin : le nombre de cartes échangées, jamais de pourcentage ni de classement.",
                        "Les situations évoquées concernent des adultes."],
            "privacy": PRIVACY,
            "step_texts": {
                "answer": {"title": "Ta réponse", "prompt": "As-tu déjà vécu cette situation ?", "hint": "Tu peux passer.", "confirm": "Confirmer"},
                "anecdote": {"title": "Une anecdote ?", "prompt": "Raconte si tu en as envie.", "hint": "Facultatif, 300 caractères.", "confirm": "Partager"},
            },
        },
    },
    # N2-004
    "prediction": {
        "config": {"engine": "rounds", "draw": {"deck": True}, "rounds": 8, "roles": "alternate", "score": "prediction",
                   "steps": [{"key": "choice", "kind": "choice", "who": "a", "params": {"extras": ["other"]}},
                             {"key": "guess", "kind": "choice", "who": "b"}],
                   "after": []},
        "rules": {
            "objective": "Je mise sur ton choix : l'un choisit, l'autre devine. Les rôles s'inversent à chaque carte.",
            "how_to": ["La personne ciblée choisit en privé (ou « autre »).", "L'autre prédit son choix.",
                       "Révélation quand vous avez confirmé tous les deux."],
            "details": ["1 point par choix deviné sur les cartes ordinaires ; aucun point sur les cartes +18.",
                        "Une réponse « autre » annule le point de la carte.", "8 cartes."],
            "privacy": PRIVACY,
            "step_texts": {
                "choice": {"title": "Ton choix", "prompt": "Que choisis-tu, toi ?", "hint": "« Autre » reste possible.", "confirm": "Confirmer mon choix"},
                "guess": {"title": "Ta prédiction", "prompt": "Que va choisir {name} ?", "hint": "Un seul choix.", "confirm": "Confirmer ma prédiction"},
            },
        },
    },
    # N2-005 (remplace la démo « Portrait en cinq mots »)
    "select_words": {
        "config": {"engine": "rounds", "rounds": 1, "rerolls": 1,
                   "draw": {"lists": [{"key": "words", "bank": "portrait", "count": 20}]},
                   "steps": [{"key": "pick", "kind": "pick", "params": {"list": "words", "min": 5, "max": 5, "custom_max": 1, "custom_len": 24}}],
                   "after": [{"key": "surprise", "kind": "surprise", "params": {"from": "pick"}}]},
        "rules": {
            "objective": "Choisis cinq mots qui te ressemblent vraiment, puis découvrez vos deux portraits.",
            "how_to": ["Vingt mots s'affichent ; choisis-en exactement cinq pour toi.",
                       "Tu peux remplacer l'un d'eux par un mot à toi.", "Révélez, puis entoure un mot de l'autre qui te surprend."],
            "details": ["Une seule relance de la liste, avant que quiconque ait répondu.", "Pas de bonne réponse, aucun diagnostic de personnalité."],
            "privacy": PRIVACY,
            "step_texts": {
                "pick": {"title": "Ton portrait", "prompt": "Choisis 5 mots qui te ressemblent.", "hint": "Un mot personnel possible (24 caractères).", "confirm": "Valider mon portrait"},
                "surprise": {"title": "Un mot qui te surprend", "prompt": "Touche un mot du portrait de {name}.", "hint": "Facultatif.", "confirm": "Entourer ce mot"},
            },
        },
    },
    # N2-006
    "object_portrait": {
        "config": {"engine": "rounds", "rounds": 1,
                   "draw": {"lists": [{"key": "objects", "bank": "objects", "count": 16}], "fixed": {"backgrounds": BACKGROUNDS}},
                   "steps": [{"key": "board", "kind": "objects", "params": {"count": 3, "caption_max": 120, "backgrounds": 6}}],
                   "after": []},
        "rules": {
            "objective": "Fais ton portrait en trois objets, chacun avec une courte légende.",
            "how_to": ["Choisis trois objets parmi seize.", "Ajoute une légende à chacun (120 caractères) et une couleur de fond.",
                       "Les deux plateaux s'affichent ensemble."],
            "details": ["Aucune signification psychologique n'est attribuée aux objets."],
            "privacy": PRIVACY,
            "step_texts": {"board": {"title": "Ton plateau", "prompt": "Trois objets qui parlent de toi.", "hint": "Une légende courte pour chacun.", "confirm": "Valider mon plateau"}},
        },
    },
    # N2-007
    "mood": {
        "config": {"engine": "rounds", "rounds": 1, "draw": {"fixed": {}},  # listes fixes complétées à l'import
                   "steps": [{"key": "sky", "kind": "sky"}],
                   "after": [{"key": "reaction", "kind": "reaction", "params": {"options": MOOD_REACTIONS, "max": 120}}]},
        "rules": {
            "objective": "Montre ta météo du moment : quelques symboles, un mot d'énergie, une note si tu veux.",
            "how_to": ["Place jusqu'à trois symboles météo dans ton ciel.", "Choisis un mot d'énergie, ajoute une note facultative.",
                       "Révélez ensemble, puis envoyez-vous une réaction."],
            "details": ["Un tableau du moment, sans historique automatique.", "Les réactions ne corrigent pas le ressenti."],
            "privacy": PRIVACY,
            "step_texts": {
                "sky": {"title": "Ton ciel", "prompt": "Comment te sens-tu en ce moment ?", "hint": "1 à 3 symboles, 1 mot d'énergie.", "confirm": "Valider ma météo"},
                "reaction": {"title": "Réagir", "prompt": "Envoie une réaction à {name}.", "hint": "Facultatif.", "confirm": "Envoyer"},
            },
        },
    },
    # N2-008
    "rank": {
        "config": {"engine": "rounds", "rounds": 1,
                   "draw": {"lists": [{"key": "values", "bank": "values", "count": 10}]},
                   "steps": [{"key": "rank", "kind": "pick", "params": {"list": "values", "min": 5, "max": 5, "note_max": 120, "ordered": True}}],
                   "after": []},
        "rules": {
            "objective": "Tes cinq priorités du moment, classées de 1 à 5.",
            "how_to": ["Dix valeurs s'affichent ; choisis-en cinq et classe-les.", "Annote ton premier choix si tu veux.",
                       "Les deux colonnes s'affichent ensemble."],
            "details": ["Une photo du moment, sans score : les priorités changent.", "Une différence ne dit rien de votre compatibilité."],
            "privacy": PRIVACY,
            "step_texts": {"rank": {"title": "Tes priorités", "prompt": "Choisis 5 valeurs dans l'ordre.", "hint": "La première est la plus importante en ce moment.", "confirm": "Valider mon classement"}},
        },
    },
    # N2-009
    "appreciation": {
        "config": {"engine": "rounds", "rounds_setting": "cartes",
                   "settings": {"cartes": {**CARDS, "options": [1, 3], "default": 1}},
                   "draw": {"lists": [{"key": "prompts", "bank": "appreciation", "count": 6}]},
                   "steps": [{"key": "write", "kind": "share", "params": {"list": "prompts", "max": 280}}],
                   "after": [{"key": "received", "kind": "reaction", "params": {"options": ["Reçu", "Merci", "Ça me touche"], "max": 120}}]},
        "rules": {
            "objective": "Un compliment précis, fondé sur un fait observé.",
            "how_to": ["Choisis une amorce.", "Complète-la avec un exemple concret (280 caractères).",
                       "Vous recevez vos cartes en même temps ; « Reçu » suffit comme réponse."],
            "details": ["Si vous vous connaissez peu, appuyez-vous sur un détail de cette partie : rien d'inventé.",
                        "Export de sa propre carte uniquement, ou avec l'accord des deux."],
            "privacy": PRIVACY,
            "step_texts": {
                "write": {"title": "Ton compliment", "prompt": "Pour {name}, à partir d'un fait observé.", "hint": "280 caractères au plus.", "confirm": "Envoyer ma carte"},
                "received": {"title": "Répondre", "prompt": "Un mot pour {name} ?", "hint": "« Reçu » suffit.", "confirm": "Envoyer"},
            },
        },
    },
    # N2-010
    "listening": {
        "config": {"engine": "rounds", "rounds": 2, "roles": "alternate",
                   "draw": {"lists": [{"key": "topics", "bank": "small_topics", "count": 4}]},
                   "steps": [{"key": "share", "kind": "share", "who": "a", "visible": "immediate", "params": {"list": "topics", "max": 500}},
                             {"key": "reformulate", "kind": "text", "who": "b", "after": "share", "visible": "immediate", "params": {"max": 250}},
                             {"key": "confirm", "kind": "confirm", "who": "a", "after": "reformulate", "visible": "immediate"}],
                   "after": []},
        "rules": {
            "objective": "Je t'ai bien compris : l'un raconte, l'autre reformule sans conseiller.",
            "how_to": ["La personne qui commence choisit un thème léger et écrit (500 caractères).",
                       "L'autre reformule en 250 caractères, sans conseil.",
                       "L'auteur répond « Oui, c'est ça » ou précise une nuance.", "Puis les rôles s'inversent."],
            "details": ["Un passage chacun ; aucune note sur la qualité de l'écoute.",
                        "Les sujets graves n'ont pas leur place ici ; « Quitter » reste toujours visible."],
            "privacy": "Le récit et la reformulation s'affichent dès qu'ils sont envoyés : c'est le principe du jeu.",
            "step_texts": {
                "share": {"title": "Raconte", "prompt": "Choisis un thème et raconte.", "hint": "500 caractères au plus.", "confirm": "Envoyer"},
                "reformulate": {"title": "Reformule", "prompt": "Redis avec tes mots ce que {name} a raconté.", "hint": "Sans conseil, 250 caractères.", "confirm": "Envoyer ma reformulation"},
                "confirm": {"title": "C'est bien ça ?", "prompt": "{name} a-t-il ou a-t-elle bien compris ?", "hint": "Tu peux préciser une nuance.", "confirm": "Répondre"},
            },
        },
    },
    # N2-011
    "timeline_personal": {
        "config": {"engine": "rounds", "rounds": 1,
                   "draw": {"lists": [{"key": "prompts", "bank": "memory_prompts", "count": 3}]},
                   "steps": [{"key": "frise", "kind": "frise"}],
                   "after": [{"key": "shared", "kind": "reaction", "params": {"max": 160}}]},
        "rules": {
            "objective": "La frise de tes moments : trois cartes, un titre et une phrase chacune.",
            "how_to": ["Écris un titre et une phrase pour chacune des trois cartes.",
                       "Range-les dans l'ordre chronologique ou émotionnel.", "Révélez vos frises, puis ajoutez ensemble une carte libre."],
            "details": ["Aucun passé commun n'est présumé.", "Dates facultatives."],
            "privacy": PRIVACY,
            "step_texts": {
                "frise": {"title": "Ta frise", "prompt": "Trois moments à toi.", "hint": "Titre de 40 caractères, phrase de 160.", "confirm": "Valider ma frise"},
                "shared": {"title": "La carte commune", "prompt": "Ajoute ta ligne à la carte commune.", "hint": "160 caractères.", "confirm": "Ajouter"},
            },
        },
    },
    # N2-012
    "capsule": {
        "config": {"engine": "rounds", "rounds": 1, "reveal": "capsule",
                   "settings": {"delai": {"label": "Réouverture dans (jours)", "options": [7, 30, 90], "default": 30}},
                   "draw": {"lists": [{"key": "ideas", "bank": "capsule", "count": 3}],
                            "fixed": {"fields": ["Une envie", "Une petite action", "Une prédiction légère"]}},
                   "steps": [{"key": "capsule", "kind": "fields", "params": {"count": 3, "max": 180}}],
                   "after": []},
        "rules": {
            "objective": "Une capsule à rouvrir plus tard : une envie, une petite action, une prédiction légère.",
            "how_to": ["Remplis les trois champs (180 caractères chacun).", "Choisis pour chaque champ s'il sera partagé.",
                       "La capsule s'ouvre dans l'Espace à la date choisie (7, 30 ou 90 jours)."],
            "details": ["Un champ gardé pour toi n'est jamais montré à l'autre.",
                        "La capsule reste conservée jusqu'à sa réouverture ; elle disparaît si le duo la supprime."],
            "privacy": "Rien n'est visible avant la date de réouverture ; les champs non partagés restent à toi.",
            "step_texts": {"capsule": {"title": "Ta capsule", "prompt": "À rouvrir plus tard.", "hint": "Coche « partager » pour chaque champ à montrer.", "confirm": "Fermer la capsule"}},
        },
    },
    # N2-013
    "budget": {
        "config": {"engine": "rounds", "rounds": 1,
                   "draw": {"lists": [{"key": "activities", "bank": "date_menu", "count": None}], "fixed": {"budget": 12}},
                   "steps": [{"key": "buy", "kind": "buy", "params": {"max_items": 4, "budget": 12}}],
                   "after": [{"key": "common", "kind": "common", "params": {"from": "buy", "budget": 12}, "revisions": 1}]},
        "rules": {
            "objective": "Douze jetons d'envie : composez une proposition commune.",
            "how_to": ["Chacun dispose de 12 jetons fictifs.", "Achète jusqu'à 4 activités sans dépasser 12.",
                       "Révélez, puis proposez chacun une combinaison commune (12 jetons au plus).",
                       "Quand vos deux propositions sont identiques, l'accord est trouvé."],
            "details": ["Les jetons sont des unités de jeu : ni monnaie, ni achat, ni réservation.", "Une révision par personne."],
            "privacy": PRIVACY,
            "step_texts": {
                "buy": {"title": "Tes envies", "prompt": "Dépense jusqu'à 12 jetons.", "hint": "4 activités au plus.", "confirm": "Valider mes choix"},
                "common": {"title": "Proposition commune", "prompt": "Parmi vos choix, composez ensemble.", "hint": "12 jetons au plus ; une révision chacun.", "confirm": "Proposer"},
            },
        },
    },
    # N2-014
    "scene_builder": {
        "config": {"engine": "rounds", "rounds": 1,
                   "draw": {"lists": [{"key": "objects", "bank": "decor", "count": None}],
                            "fixed": {"lights": LIGHTS, "ambiances": AMBIANCES, "grid": {"cols": 6, "rows": 4}}},
                   "steps": [{"key": "place", "kind": "place", "params": {"count": 3}}, {"key": "light", "kind": "light"}],
                   "after": [{"key": "agree", "kind": "agree", "revisions": 2}]},
        "rules": {
            "objective": "Votre coin tranquille : un petit décor composé à deux.",
            "how_to": ["Chacun place trois objets sur sa moitié de la scène (toucher l'objet, puis la case).",
                       "Chacun propose un éclairage et une ambiance.", "Révélez la scène, puis choisissez ensemble l'une des deux propositions."],
            "details": ["Une scène de jeu, pas un projet de vie commune.", "Pas de gagnant."],
            "privacy": PRIVACY,
            "step_texts": {
                "place": {"title": "Ta moitié", "prompt": "Place trois objets.", "hint": "Touche un objet, puis une case de ta moitié.", "confirm": "Valider mes objets"},
                "light": {"title": "L'ambiance", "prompt": "Propose un éclairage et une ambiance.", "hint": "", "confirm": "Proposer"},
                "agree": {"title": "L'ambiance commune", "prompt": "Quelle proposition gardez-vous ?", "hint": "Choisissez la même pour vous accorder.", "confirm": "Choisir"},
            },
        },
    },
    # N2-015
    "attention": {
        "config": {"engine": "rounds", "rounds": 1,
                   "draw": {"lists": [{"key": "actions", "bank": "attentions", "count": None}]},
                   "steps": [{"key": "gesture", "kind": "gesture"}],
                   "after": [{"key": "return", "kind": "reaction", "params": {"max": 200}}]},
        "rules": {
            "objective": "La roue des petits gestes : une attention à réaliser dans l'app.",
            "how_to": ["Fais tourner la roue ; change d'action autant que tu veux.", "Réalise-la par un texte ou un dessin.",
                       "L'autre la reçoit et peut rendre une attention différente."],
            "details": ["Une carte chacun, jamais de dette ni de gage.", "Aucune action ne demande contact physique, dépense ni média intime."],
            "privacy": PRIVACY,
            "step_texts": {
                "gesture": {"title": "Ton attention", "prompt": "Réalise l'action tirée.", "hint": "Texte (280 caractères) ou dessin.", "confirm": "Envoyer mon attention"},
                "return": {"title": "Rendre une attention", "prompt": "Un mot en retour ?", "hint": "Facultatif.", "confirm": "Envoyer"},
            },
        },
    },
    # N2-121
    "taste_map": {
        "config": {"engine": "rounds", "rounds": 1,
                   "draw": {"lists": [{"key": "labels", "bank": "taste_labels", "count": None}],
                            "fixed": {"zones": ["souvent", "parfois", "pas mon truc"]}},
                   "steps": [{"key": "map", "kind": "zones", "params": {"max": 6}}],
                   "after": [{"key": "ask", "kind": "ask", "params": {"from": "map"}},
                             {"key": "reply", "kind": "reaction", "params": {"max": 200}}]},
        "rules": {
            "objective": "La carte de tes goûts : souvent, parfois, pas mon truc.",
            "how_to": ["Place jusqu'à six étiquettes dans les trois zones.", "Ajoute un détail facultatif sur l'une d'elles (80 caractères).",
                       "Révélez, puis touchez une étiquette de l'autre pour en savoir plus."],
            "details": ["Pas de pourcentage de ressemblance.", "Une étiquette laissée de côté n'est pas un désaccord ; répondre n'est jamais obligatoire."],
            "privacy": PRIVACY,
            "step_texts": {
                "map": {"title": "Ta carte", "prompt": "Range tes goûts.", "hint": "Touche une étiquette, puis une zone.", "confirm": "Valider ma carte"},
                "ask": {"title": "En savoir plus", "prompt": "Touche une étiquette de {name}.", "hint": "Une question facultative.", "confirm": "Demander"},
                "reply": {"title": "Répondre", "prompt": "Si tu en as envie.", "hint": "Facultatif.", "confirm": "Répondre"},
            },
        },
    },
    # N2-122
    "gift_box": {
        "config": {"engine": "rounds", "rounds": 1,
                   "draw": {"lists": [{"key": "prompts", "bank": "gift_prompts", "count": 3},
                                      {"key": "objects", "bank": "objects", "count": 12}],
                            "fixed": {"papers": PAPERS, "ribbons": RIBBONS}},
                   "steps": [{"key": "gift", "kind": "gift"}],
                   "after": []},
        "rules": {
            "objective": "La boîte à surprises : un objet symbolique, un mot et un petit dessin pour l'autre.",
            "how_to": ["Choisis un papier et un ruban.", "Remplis les trois compartiments (chacun peut rester vide).",
                       "Quand vous avez validé tous les deux, chacun ouvre la boîte de l'autre, un compartiment à la fois."],
            "details": ["Aucun gage, aucun achat réel.", "Rien n'est envoyé avant ta confirmation ; aucun message n'est écrit à ta place."],
            "privacy": PRIVACY,
            "step_texts": {"gift": {"title": "Ta boîte", "prompt": "Prépare une surprise pour {name}.", "hint": "Un compartiment peut rester vide.", "confirm": "Fermer la boîte"}},
        },
    },
    # N2-123
    "zine": {
        "config": {"engine": "rounds", "rounds": 1,
                   "draw": {"lists": [{"key": "themes", "bank": "zine_themes", "count": 1},
                                      {"key": "stickers", "bank": "stickers", "count": None}]},
                   "steps": [{"key": "page", "kind": "page"}, {"key": "cover", "kind": "cover_pick", "params": {"from": "page"}}],
                   "after": [{"key": "last1", "kind": "line", "who": "seat1"},
                             {"key": "last2", "kind": "line", "who": "seat2", "after": "last1"},
                             {"key": "last3", "kind": "line", "who": "seat1", "after": "last2"},
                             {"key": "last4", "kind": "line", "who": "seat2", "after": "last3"}]},
        "rules": {
            "objective": "Le mini-fanzine à deux : une couverture commune, une page chacun, une dernière page ensemble.",
            "how_to": ["Compose ta page : texte (200 caractères), gommettes et crayon.",
                       "Propose un détail de ta page pour la couverture.",
                       "Après la révélation, la dernière page se remplit en alternant deux interventions chacun."],
            "details": ["Ta page reste privée jusqu'à la validation ; l'autre ne peut ni la modifier ni la publier.",
                        "Enregistrement dans l'Espace seulement si vous le choisissez tous les deux."],
            "privacy": PRIVACY,
            "step_texts": {
                "page": {"title": "Ta page", "prompt": "Thème : {theme}", "hint": "Texte, gommettes et dessin : au moins un des trois.", "confirm": "Valider ma page"},
                "cover": {"title": "Pour la couverture", "prompt": "Quel détail de ta page proposes-tu ?", "hint": "Une gommette posée ou une courte phrase.", "confirm": "Proposer"},
                "last": {"title": "Dernière page", "prompt": "À ton tour d'ajouter une ligne ou une gommette.", "hint": "80 caractères.", "confirm": "Ajouter"},
            },
        },
    },
}

# Formes féminines du lexique Portrait (accord choisi par chaque joueur dans son profil).
FEMININE = {
    "franc": "franche", "discret": "discrète", "observateur": "observatrice", "protecteur": "protectrice",
    "aventurier": "aventurière", "casanier": "casanière", "ponctuel": "ponctuelle", "vif": "vive",
}


def feminine(word):
    if word in FEMININE:
        return FEMININE[word]
    if word.endswith("eux"):
        return word[:-1] + "se"
    if word.endswith("eur"):
        return word[:-1] + "se"
    if word.endswith("if"):
        return word[:-1] + "ve"
    if word.endswith("e"):
        return word
    return word + "e"
