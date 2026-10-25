// Univers visuels des jeux premium (kit « Jeux premium V4 ») : décor, matière et accents propres à chaque jeu.
// Les codes M01, G08… sont ceux de config.code ; ce ne sont pas des identifiants de jeux.
import type { SessionState } from "../../lib/types";

export interface Universe { code: string; name: string; tint: string; accent: string }

const LIST: Universe[] = [
  { code: "M01", name: "Le salon des galets", tint: "#E8DEF5", accent: "#7654BD" },
  { code: "M04", name: "La mosaïque du jardin", tint: "#D8EFE6", accent: "#24664D" },
  { code: "M07", name: "La baie secrète", tint: "#DCEEF1", accent: "#316A7E" },
  { code: "M09", name: "Le jardin des mots", tint: "#E2EDD8", accent: "#45683D" },
  { code: "M11", name: "Le petit duel", tint: "#F4E1CF", accent: "#925435" },
  { code: "M12", name: "Le comptoir des 30", tint: "#E6DFF1", accent: "#7654BD" },
  { code: "M16", name: "L’atelier des idées", tint: "#FAE9C9", accent: "#86552D" },
  { code: "G07", name: "Le studio du défi", tint: "#F7DECF", accent: "#A05238" },
  { code: "G01", name: "Le cabinet des surprises", tint: "#F4DDD6", accent: "#9A4D5A" },
  { code: "G02", name: "Le passeport des expériences", tint: "#D9E9E4", accent: "#326954" },
  { code: "G03", name: "Les deux chemins", tint: "#E5DFF3", accent: "#7654BD" },
  { code: "G04", name: "Sous les projecteurs", tint: "#F6EBCB", accent: "#836021" },
  { code: "G05", name: "Les messages croisés", tint: "#DBE7F2", accent: "#3B638B" },
  { code: "G08", name: "Le petit théâtre", tint: "#E9DFF0", accent: "#80518C" },
  { code: "G09", name: "L’atelier des mots", tint: "#E1EADC", accent: "#4D6D41" },
  { code: "G10", name: "Le salon des opinions", tint: "#F0DDE3", accent: "#8D4D67" },
];
const BY_CODE = new Map(LIST.map((u) => [u.code, u]));

/** Chemin public d'une pièce du kit, servie localement (jamais depuis Drive). */
export const asset = (folder: string, name: string) => `/assets/premium/${folder}/${name}.svg`;

export function universeOf(st: SessionState): Universe | null {
  const code = (st.game.config as unknown as { code?: string }).code;
  return (code && BY_CODE.get(code)) || null;
}
