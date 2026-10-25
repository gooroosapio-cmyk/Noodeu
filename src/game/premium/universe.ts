// Univers visuels des jeux premium (kit « Jeux premium V4 ») : décor, matière et accents propres à chaque jeu.
// Les codes M01, G08… sont ceux de config.code ; ce ne sont pas des identifiants de jeux.
import type { SessionState } from "../../lib/types";

export interface Universe { code: string; name: string; tint: string; accent: string }

const LIST: Universe[] = [
  { code: "M01", name: "Le salon des galets", tint: "#F2E4EB", accent: "#48283D" },
  { code: "M04", name: "La mosaïque du jardin", tint: "#F2E4EB", accent: "#48283D" },
  { code: "M07", name: "La baie secrète", tint: "#F2E4EB", accent: "#48283D" },
  { code: "M09", name: "Le jardin des mots", tint: "#F2E4EB", accent: "#48283D" },
  { code: "M11", name: "Le petit duel", tint: "#F9DFC9", accent: "#48283D" },
  { code: "M12", name: "Le comptoir des 30", tint: "#F2E4EB", accent: "#48283D" },
  { code: "M16", name: "L’atelier des idées", tint: "#F9DFC9", accent: "#48283D" },
  { code: "G07", name: "Le studio du défi", tint: "#F9DFC9", accent: "#48283D" },
  { code: "G01", name: "Le cabinet des surprises", tint: "#F9DFC9", accent: "#48283D" },
  { code: "G02", name: "Le passeport des expériences", tint: "#F2E4EB", accent: "#48283D" },
  { code: "G03", name: "Les deux chemins", tint: "#F2E4EB", accent: "#48283D" },
  { code: "G04", name: "Sous les projecteurs", tint: "#F9DFC9", accent: "#48283D" },
  { code: "G05", name: "Les messages croisés", tint: "#F2E4EB", accent: "#48283D" },
  { code: "G08", name: "Le petit théâtre", tint: "#F2E4EB", accent: "#48283D" },
  { code: "G09", name: "L’atelier des mots", tint: "#F2E4EB", accent: "#48283D" },
  { code: "G10", name: "Le salon des opinions", tint: "#F2E4EB", accent: "#48283D" },
];
const BY_CODE = new Map(LIST.map((u) => [u.code, u]));

/** Chemin public d'une pièce du kit, servie localement (jamais depuis Drive). */
export const asset = (folder: string, name: string) => `/assets/premium/${folder}/${name}.svg`;

export function universeOf(st: SessionState): Universe | null {
  const code = (st.game.config as unknown as { code?: string }).code;
  return (code && BY_CODE.get(code)) || null;
}
