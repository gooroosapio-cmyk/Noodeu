// Univers visuels des jeux premium (kit « Jeux premium V4 ») : décor, matière et accents propres à chaque jeu.
// Les codes M01, G08… sont ceux de config.code ; ce ne sont pas des identifiants de jeux.
import type { SessionState } from "../../lib/types";

export interface Universe { code: string; name: string; tint: string; accent: string }

const LIST: Universe[] = [
  { code: "M01", name: "Le salon des galets", tint: "#D7ECE9", accent: "#17656B" },
  { code: "M04", name: "La mosaïque du jardin", tint: "#D7ECE9", accent: "#17656B" },
  { code: "M07", name: "La baie secrète", tint: "#D7ECE9", accent: "#17656B" },
  { code: "M09", name: "Le jardin des mots", tint: "#D7ECE9", accent: "#17656B" },
  { code: "M11", name: "Le petit duel", tint: "#F9DFC9", accent: "#80502E" },
  { code: "M12", name: "Le comptoir des 30", tint: "#D7ECE9", accent: "#17656B" },
  { code: "M16", name: "L’atelier des idées", tint: "#F9DFC9", accent: "#80502E" },
  { code: "G07", name: "Le studio du défi", tint: "#F9DFC9", accent: "#80502E" },
  { code: "G01", name: "Le cabinet des surprises", tint: "#F9DFC9", accent: "#80502E" },
  { code: "G02", name: "Le passeport des expériences", tint: "#D7ECE9", accent: "#17656B" },
  { code: "G03", name: "Les deux chemins", tint: "#D7ECE9", accent: "#17656B" },
  { code: "G04", name: "Sous les projecteurs", tint: "#F9DFC9", accent: "#80502E" },
  { code: "G05", name: "Les messages croisés", tint: "#D7ECE9", accent: "#17656B" },
  { code: "G08", name: "Le petit théâtre", tint: "#D7ECE9", accent: "#17656B" },
  { code: "G09", name: "L’atelier des mots", tint: "#D7ECE9", accent: "#17656B" },
  { code: "G10", name: "Le salon des opinions", tint: "#D7ECE9", accent: "#17656B" },
];
const BY_CODE = new Map(LIST.map((u) => [u.code, u]));

/** Chemin public d'une pièce du kit, servie localement (jamais depuis Drive). */
export const asset = (folder: string, name: string) => `/assets/premium/${folder}/${name}.svg`;

export function universeOf(st: SessionState): Universe | null {
  const code = (st.game.config as unknown as { code?: string }).code;
  return (code && BY_CODE.get(code)) || null;
}
