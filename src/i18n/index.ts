import { fr, type MessageKey } from "./fr";

// Une seule langue pour l'instant (décision 13B) : tous les textes passent par t()
// afin de pouvoir ajouter une traduction sans toucher aux écrans.
const dictionary: Record<MessageKey, string> = fr;

export function t(key: MessageKey, vars?: Record<string, string | number>): string {
  let text = dictionary[key] ?? key;
  if (vars) for (const [k, v] of Object.entries(vars)) text = text.replaceAll(`{${k}}`, String(v));
  return text;
}

/** Remplace {partner} etc. dans les textes éditoriaux venus de la base. */
export function fill(text: string, vars: Record<string, string>): string {
  return text.replace(/\{(\w+)\}/g, (_, k: string) => vars[k] ?? "");
}

export type { MessageKey };
