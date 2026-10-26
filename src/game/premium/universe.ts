// Les univers nomment les scènes ; les commandes et surfaces gardent les tokens actifs de Noodeu.
// Les codes M01, G08… sont ceux de config.code ; ce ne sont pas des identifiants de jeux.
import type { SessionState } from "../../lib/types";

export interface Universe { code: string; name: string; tint: string; accent: string }

const LIST: Universe[] = [
  { code: "M01", name: "Le salon des galets", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "M04", name: "La mosaïque du jardin", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "M07", name: "La baie secrète", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "M09", name: "Le jardin des mots", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "M11", name: "Le petit duel", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "M12", name: "Le comptoir des 30", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "M16", name: "L’atelier des idées", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "G07", name: "Le studio du défi", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "G01", name: "Le cabinet des surprises", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "G02", name: "Le passeport des expériences", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "G03", name: "Les deux chemins", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "G04", name: "Sous les projecteurs", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "G05", name: "Les messages croisés", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "G08", name: "Le petit théâtre", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "G09", name: "L’atelier des mots", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
  { code: "G10", name: "Le salon des opinions", tint: "var(--c-accent-soft)", accent: "var(--c-accent-down)" },
];
const BY_CODE = new Map(LIST.map((u) => [u.code, u]));

/** Chemin public d'une pièce du kit, servie localement (jamais depuis Drive). */
export const asset = (folder: string, name: string) => `/assets/premium/${folder}/${name}.svg`;

export function universeOf(st: SessionState): Universe | null {
  const code = (st.game.config as unknown as { code?: string }).code;
  return (code && BY_CODE.get(code)) || null;
}
