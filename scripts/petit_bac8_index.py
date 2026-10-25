#!/usr/bin/env python3
"""Index du Petit bac à 8 rubriques (version pb8-2026-10-28-v1, À RELIRE).

Rédigé par Noodeu pour la validation automatique : une réponse absente reste « inconnue » et se fait arbitrer
par les deux joueurs ; l'index n'est jamais présenté comme exhaustif. Les lettres retenues sont celles où chaque
rubrique a au moins une entrée. Sortie : SQL des entrées (banque petit_bac_huit) sur la sortie standard.
"""
import json
import sys
import unicodedata

def norm(s: str) -> str:
    s = s.replace("œ", "oe").replace("Œ", "OE").replace("æ", "ae").replace("Æ", "AE")
    s = "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")
    return " ".join(s.upper().replace("’", "'").split())

W = {
    "animal": """abeille aigle âne antilope araignée autruche baleine belette bison blaireau bouc biche buffle caille canard castor
    cerf chameau chat chauve-souris cheval chèvre chien chimpanzé chouette cigogne cochon colibri coq corbeau coyote crabe crocodile
    cygne daim dauphin dinde dindon dromadaire écureuil éléphant émeu escargot étoile de mer faisan faucon flamant fouine fourmi furet
    gazelle geai gecko girafe gorille grenouille grillon guépard guêpe hamster hérisson hibou hippopotame homard hyène iguane impala
    jaguar kangourou koala lama lapin lémurien léopard lézard lièvre lion loup loutre lynx macaque manchot marmotte merle mouche
    mouette mouflon moustique mouton mulet narval oie orque ours panda panthère paon papillon perroquet phoque pie pigeon pingouin
    poisson-clown poney porc-épic poule puma putois raie rat raton laveur renard renne requin rhinocéros rossignol sanglier sardine
    sauterelle serpent singe souris suricate tapir taupe taureau tigre tortue toucan truite vache vautour ver de terre vipère zèbre""",
    "ville": """Abidjan Accra Agadir Ajaccio Alger Amiens Amsterdam Angers Anvers Athènes Avignon Bamako Bangkok Barcelone Bastia Berlin
    Besançon Biarritz Bordeaux Boston Bruges Bruxelles Bucarest Budapest Caen Calais Cannes Casablanca Chicago Copenhague Cotonou
    Dakar Delhi Dijon Douala Dubaï Dublin Dunkerque Édimbourg Évian Florence Francfort Fribourg Genève Gênes Grenoble Hambourg Hanoï
    Helsinki Houston Istanbul Jérusalem Johannesburg Kinshasa Kyoto Lagos Lausanne Le Caire Le Havre Le Mans Libreville Liège Lille
    Lima Lisbonne Lomé Londres Lorient Los Angeles Lyon Madrid Marseille Melbourne Metz Miami Milan Montpellier Montréal Moscou
    Mulhouse Munich Nantes Naples Nancy Nice Nîmes Niamey Orléans Oslo Ottawa Ouagadougou Oran Palerme Paris Pau Perpignan Poitiers
    Prague Québec Quimper Rabat Reims Rennes Rio de Janeiro Rome Rouen Saint-Étienne Séoul Strasbourg Stockholm Sydney Tanger Tokyo
    Toulon Toulouse Tours Tunis Turin Valence Varsovie Venise Versailles Vienne Vichy Yaoundé Zagreb Zurich""",
    "metier": """acteur agriculteur aide-soignant architecte artisan astronaute avocat banquier bijoutier boucher boulanger cardiologue
    caissier charpentier chauffeur chef cuisinier chirurgien coiffeur comptable cordonnier couvreur couturier cuisinier danseur
    dentiste designer développeur diététicien docteur douanier ébéniste éboueur éducateur électricien enseignant épicier facteur
    fermier fleuriste forgeron garagiste gendarme géomètre guide horloger hôtesse illustrateur infirmier informaticien ingénieur
    jardinier journaliste juge kinésithérapeute libraire luthier maçon magicien maître-nageur marin mécanicien médecin menuisier
    musicien notaire opticien orthophoniste ostéopathe pâtissier peintre pharmacien photographe pilote plombier poissonnier pompier
    policier professeur psychologue puériculteur radiologue réceptionniste reporter sage-femme sapeur-pompier secrétaire serveur
    soudeur steward styliste tailleur technicien traducteur vendeur vétérinaire vigneron""",
    "objet": """agenda aiguille ampoule armoire arrosoir assiette balai ballon bague bougie bouteille bol bonnet boussole bracelet brosse
    cafetière cahier caillou calculatrice canapé casque casserole ceinture chaise chapeau ciseaux clé coussin couteau crayon cuillère
    dé dentifrice drap éponge escabeau étagère éventail fauteuil fenêtre flûte fourchette gant gobelet gomme guitare horloge imperméable
    jumelles jouet lampe lit livre loupe lunettes marteau miroir montre mouchoir nappe oreiller ordinateur panier parapluie peigne
    pinceau poêle porte-monnaie pot radio râteau règle réveil sac savon seau serviette stylo table tabouret tapis tasse téléphone
    tournevis trousse valise vase verre vélo ventilateur violon""",
    "pays": """Afghanistan Afrique du Sud Albanie Algérie Allemagne Angola Argentine Arménie Australie Autriche Belgique Bénin Bolivie
    Brésil Bulgarie Burkina Faso Cameroun Canada Chili Chine Colombie Congo Corée du Sud Côte d'Ivoire Croatie Cuba Danemark Djibouti
    Dominique Égypte Équateur Espagne Estonie États-Unis Éthiopie Fidji Finlande France Gabon Gambie Ghana Grèce Guatemala Guinée
    Haïti Honduras Hongrie Inde Indonésie Irak Iran Irlande Islande Israël Italie Jamaïque Japon Jordanie Kenya Laos Lettonie Liban
    Libye Lituanie Luxembourg Madagascar Mali Malte Maroc Mauritanie Mexique Monaco Mongolie Mozambique Namibie Népal Nicaragua Niger
    Nigeria Norvège Nouvelle-Zélande Oman Ouganda Pakistan Panama Paraguay Pays-Bas Pérou Philippines Pologne Portugal Qatar Roumanie
    Royaume-Uni Russie Rwanda Sénégal Serbie Singapour Slovaquie Somalie Soudan Suède Suisse Syrie Tanzanie Tchad Thaïlande Togo
    Tunisie Turquie Ukraine Uruguay Venezuela Vietnam Yémen Zambie Zimbabwe""",
    "prenom": """Adam Adèle Aïcha Alice Amadou Amina Antoine Arthur Awa Baptiste Basile Béatrice Benjamin Bernard Blanche Brigitte Camille
    Caroline Céline Charles Chloé Claire Clément Damien Daniel David Delphine Denis Diane Dylan Eden Édouard Élise Émile Emma Éric
    Fabien Fanny Fatou Félix Florence François Gabriel Gaspard Georges Gilles Grace Hélène Henri Hugo Ibrahim Inès Isabelle Ivan
    Jacques Jade Jeanne Jules Julie Karim Kevin Khadija Laura Léa Léon Lina Louis Lucas Lucie Malik Manon Marie Mathis Maxime Nadia
    Nathan Nicolas Noé Nora Océane Olivier Omar Oscar Pablo Patrick Paul Pauline Pierre Quentin Raphaël Rachel Romain Rose Sacha
    Samuel Sarah Sophie Sylvie Théo Thomas Timothée Ursule Valentin Valérie Victor Victoire Wassim William Xavier Yanis Yasmine
    Yves Zoé Zacharie""",
    "fruit-legume": """abricot ail ananas artichaut asperge aubergine avocat banane betterave brocoli carotte cassis céleri cerise
    champignon châtaigne chou chou-fleur citron citrouille clémentine coing concombre courge courgette datte échalote endive épinard
    fenouil figue fraise framboise goyave grenade groseille haricot kaki kiwi laitue lentille litchi mandarine mangue melon mirabelle
    mûre myrtille navet nectarine noix oignon olive orange pamplemousse panais papaye pastèque patate douce pêche petit pois poire
    poireau poivron pomme pomme de terre potiron prune pruneau radis raisin rhubarbe roquette salade tomate topinambour""",
}

# Personnalités publiques attestées : nom complet et nom d'usage acceptés.
CELEB = """Adele|Albert Einstein|Alain Delon|Angela Merkel|Audrey Tautou|Barack Obama|Beyoncé|Bob Marley|Brigitte Bardot|Céline Dion|
Charles Aznavour|Charlie Chaplin|Coco Chanel|Christian Dior|Dalida|Didier Drogba|David Bowie|Elvis Presley|Édith Piaf|Emmanuel Macron|
Frida Kahlo|Freddie Mercury|Fela Kuti|Gérard Depardieu|Gustave Eiffel|Greta Thunberg|Henri Salvador|Isabelle Adjani|Jacques Brel|
Jean-Paul Belmondo|Johnny Hallyday|Kylian Mbappé|Lady Gaga|Léonard de Vinci|Louis Armstrong|Madonna|Marie Curie|Michael Jackson|
Molière|Nelson Mandela|Napoléon Bonaparte|Omar Sy|Pablo Picasso|Pelé|Rihanna|Roger Federer|Salif Keita|Serena Williams|
Simone Veil|Stromae|Taylor Swift|Teddy Riner|Usain Bolt|Victor Hugo|Vincent van Gogh|Whitney Houston|Yannick Noah|Youssou N'Dour|
Zinedine Zidane|Aya Nakamura|Dua Lipa|Brad Pitt|Rafael Nadal|Ronaldo|Shakira|Thierry Henry|Jean Gabin|Gad Elmaleh|Booba|Indila|
Louane|Mylène Farmer|Nina Simone|Oprah Winfrey|Patrick Bruel|Quincy Jones|Rachida Dati|Sophie Marceau|Tina Turner|Uderzo|Vanessa Paradis|
Wolfgang Amadeus Mozart|Yves Saint Laurent|Ludwig van Beethoven|Marilyn Monroe|Muhammad Ali|Gilles Deleuze|Kofi Annan|Miriam Makeba"""

def entries():
    out = []
    for cat, blob in W.items():
        words = blob.split()
        # Les entrées de plusieurs mots sont reconstituées à partir de la liste ci-dessous.
        multi = {"étoile de mer", "raton laveur", "ver de terre", "Le Caire", "Le Havre", "Le Mans", "Los Angeles", "Rio de Janeiro",
                 "Afrique du Sud", "Burkina Faso", "Corée du Sud", "Côte d'Ivoire", "Nouvelle-Zélande", "Pays-Bas", "pomme de terre",
                 "petit pois", "patate douce", "chef cuisinier"}
        text = " " + " ".join(words) + " "
        items = []
        for m in sorted(multi, key=len, reverse=True):
            if f" {m} " in text:
                items.append(m)
                text = text.replace(f" {m} ", " ")
        items += text.split()
        for w in items:
            out.append((cat, w, [norm(w)]))
    for raw in CELEB.replace("\n", "").split("|"):
        name = raw.strip()
        parts = name.split()
        aliases = [norm(name)]
        if len(parts) > 1:
            last = " ".join(parts[1:]) if parts[-2].lower() in ("de", "van") else parts[-1]
            aliases.append(norm(last))
        out.append(("celebrite", name, aliases))
    return out

def main():
    rows = entries()
    seen = set()
    data = []
    for cat, text, aliases in rows:
        key = (cat, aliases[0])
        if key in seen:
            continue
        seen.add(key)
        acc = f"pb8-{cat}-{aliases[0].lower().replace(' ', '-').replace(chr(39), '')}"
        data.append({"id": acc, "acc": acc, "cat": cat, "text": text, "aliases": aliases})
    cats = sorted({d["cat"] for d in data})
    letters = sorted(l for l in {a[0] for d in data for a in d["aliases"]}
                     if all(any(a[0] == l for d in data if d["cat"] == c for a in d["aliases"]) for c in cats))
    print(f"-- {len(data)} entrées, {len(cats)} rubriques ; lettres couvertes partout : {''.join(letters)}", file=sys.stderr)
    print(json.dumps(data, ensure_ascii=False))

if __name__ == "__main__":
    main()
