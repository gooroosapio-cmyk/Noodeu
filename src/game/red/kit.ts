// Kit rouge v1 (26/10/2026) : ressources locales sous /assets/noodeu/red-v1 (empreintes dans manifest.json).
// Les images sont décoratives ; textes, scores, dés et choix viennent toujours de l'état serveur.
import type { SessionState } from "../../lib/types";

const ROOT = "/assets/noodeu/red-v1";

export type RedBackground = "fond_salon" | "fond_papeterie" | "fond_jetons" | "fond_carnet" | "fond_cosmos" | "fond_pierre";
export type RedScene = "salon_contemporain" | "table_jeu" | "podium" | "carte_verite_vierge" | "choix_mer" | "choix_montagne";
export type RedIllustration =
  | "balance_avis" | "ballon_pendu" | "cadres_duo" | "carnet_phrase" | "cartes_action_verite" | "cartes_questionnaire"
  | "coeur_reessayer" | "coeurs_duo" | "de_decoratif" | "enveloppe_verrouillee" | "geste_ciseaux" | "geste_feuille" | "geste_pierre"
  | "jeton_deja" | "jeton_jamais" | "masque_trois_cartes" | "navire_croiseur" | "navire_cuirasse" | "navire_patrouilleur"
  | "navire_porte_avions" | "navire_sous_marin" | "pause_reconnexion" | "pion_o" | "pion_x" | "piste_de" | "planete_jupiter"
  | "planete_mars" | "planete_saturne" | "planete_venus" | "portes_dilemme" | "quiz_astronomie" | "sablier" | "salon_fauteuils"
  | "trophee_victoire" | "trophees_egalite" | "tuiles_petit_bac";
export type RedComponent =
  | "bouton_correct" | "bouton_desactive" | "bouton_incorrect" | "bouton_presse" | "bouton_repos" | "bouton_secondaire" | "bouton_selectionne"
  | "carte_correcte" | "carte_incorrecte" | "carte_neutre" | "carte_selectionnee" | "carte_verrouillee"
  | "de_face_1" | "de_face_2" | "de_face_3" | "de_face_4" | "de_face_5" | "de_face_6"
  | "manche_active" | "manche_future" | "manche_terminee" | "plateau_morpion_vierge";

/** Disposition de référence (05_integration/zones-ecrans.json) ; budgets indicatifs, jamais de positionnement absolu. */
export type RedLayout = "invite" | "settings" | "ready" | "card" | "binary" | "textarea" | "three_inputs" | "radio" | "qcm"
  | "board" | "keyboard" | "three_choices" | "dice" | "eight_inputs" | "oral" | "results" | "chat";

export interface RedKit {
  code: string;
  background: RedBackground;
  hero: RedIllustration | RedScene;
  layout: RedLayout;
  /** Le jeu demande-t-il une saisie de texte ? (Action ou vérité : jamais.) */
  textInput: boolean;
  pieces?: RedIllustration[];
}

export const redBackground = (name: RedBackground | RedScene) => `${ROOT}/fonds/${name}.webp`;
export const redIllustration = (name: RedIllustration) => `${ROOT}/illustrations/${name}.webp`;
export const redComponent = (name: RedComponent, ext: "webp" | "svg" = "webp") => `${ROOT}/composants/${name}.${ext}`;
const SCENES = new Set<string>(["salon_contemporain", "table_jeu", "podium", "carte_verite_vierge", "choix_mer", "choix_montagne"]);
export const redHero = (name: RedKit["hero"]) => (SCENES.has(name) ? redBackground(name as RedScene) : redIllustration(name as RedIllustration));

/** Jeux du kit par code de configuration (config.code), puis familles sans code. */
export const RED_KITS: Record<string, RedKit> = {
  G01: { code: "G01", background: "fond_papeterie", hero: "cartes_action_verite", layout: "card", textInput: false },
  G02: { code: "G02", background: "fond_jetons", hero: "coeurs_duo", layout: "binary", textInput: false, pieces: ["jeton_deja", "jeton_jamais"] },
  G03: { code: "G03", background: "fond_jetons", hero: "portes_dilemme", layout: "binary", textInput: false },
  G04: { code: "G04", background: "fond_jetons", hero: "cadres_duo", layout: "binary", textInput: false },
  G05: { code: "G05", background: "fond_papeterie", hero: "enveloppe_verrouillee", layout: "textarea", textInput: true },
  G07: { code: "G07", background: "fond_papeterie", hero: "sablier", layout: "oral", textInput: false },
  G08: { code: "G08", background: "fond_papeterie", hero: "masque_trois_cartes", layout: "three_inputs", textInput: true },
  G09: { code: "G09", background: "fond_carnet", hero: "carnet_phrase", layout: "textarea", textInput: true },
  G10: { code: "G10", background: "fond_jetons", hero: "balance_avis", layout: "binary", textInput: false },
  M01: { code: "M01", background: "fond_pierre", hero: "pion_x", layout: "board", textInput: false, pieces: ["pion_x", "pion_o"] },
  M04: { code: "M04", background: "fond_pierre", hero: "tuiles_petit_bac", layout: "board", textInput: false },
  M07: { code: "M07", background: "fond_pierre", hero: "navire_porte_avions", layout: "board", textInput: false,
    pieces: ["navire_porte_avions", "navire_cuirasse", "navire_croiseur", "navire_sous_marin", "navire_patrouilleur"] },
  M09: { code: "M09", background: "fond_carnet", hero: "ballon_pendu", layout: "keyboard", textInput: false },
  M11: { code: "M11", background: "fond_pierre", hero: "geste_pierre", layout: "three_choices", textInput: false,
    pieces: ["geste_pierre", "geste_feuille", "geste_ciseaux"] },
  M12: { code: "M12", background: "fond_pierre", hero: "piste_de", layout: "dice", textInput: false },
  M16: { code: "M16", background: "fond_carnet", hero: "tuiles_petit_bac", layout: "eight_inputs", textInput: true },
  decouverte: { code: "decouverte", background: "fond_papeterie", hero: "enveloppe_verrouillee", layout: "textarea", textInput: true },
  questionnaire: { code: "questionnaire", background: "fond_carnet", hero: "cartes_questionnaire", layout: "radio", textInput: false },
  autre: { code: "autre", background: "fond_salon", hero: "table_jeu", layout: "card", textInput: false },
};

/** Écrans communs, hors jeu. */
export const RED_SCREENS = {
  salon: { background: "fond_salon", hero: "salon_contemporain" },
  preparer: { background: "fond_salon", hero: "masque_trois_cartes" },
  victoire: { background: "fond_jetons", hero: "trophee_victoire" },
  egalite: { background: "fond_jetons", hero: "trophees_egalite" },
  defaite: { background: "fond_jetons", hero: "coeur_reessayer" },
  pause: { background: "fond_pierre", hero: "pause_reconnexion" },
} as const satisfies Record<string, { background: RedBackground; hero: RedKit["hero"] }>;

export function redKitOf(st: SessionState): RedKit {
  const cfg = st.game.config as unknown as { code?: string; mechanic?: string };
  if (cfg.code && RED_KITS[cfg.code]) return RED_KITS[cfg.code];
  if (cfg.mechanic === "test_form") return RED_KITS.questionnaire;
  if (cfg.mechanic === "pack_conversation") return RED_KITS.decouverte;
  return RED_KITS.autre;
}

/** Pièces de plateau du kit, à la place des anciennes images ; l'ancienne reste en secours. */
export const RED_PIECES: Record<string, string> = {
  "die-1": redComponent("de_face_1"), "die-2": redComponent("de_face_2"), "die-3": redComponent("de_face_3"),
  "die-4": redComponent("de_face_4"), "die-5": redComponent("de_face_5"), "die-6": redComponent("de_face_6"),
  cross: redIllustration("pion_x"), ring: redIllustration("pion_o"),
};
