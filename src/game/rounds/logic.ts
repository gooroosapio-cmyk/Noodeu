// Logique d'affichage du moteur « manches à étapes » (famille 1). Miroir des règles de la base :
// l'interface ne décide de rien, elle choisit seulement quel écran montrer. La base valide tout.
import type { WordForm } from "../../lib/types.ts";

export type StepKind =
  | "text" | "choice" | "yes_no" | "pick" | "objects" | "sky" | "frise" | "gesture" | "buy" | "common" | "place"
  | "light" | "agree" | "gift" | "page" | "cover_pick" | "line" | "fields" | "share" | "confirm" | "reaction"
  | "surprise" | "zones" | "ask";

export interface StepDef {
  key: string;
  kind: StepKind;
  who?: "both" | "a" | "b" | "seat1" | "seat2";
  after?: string;
  visible?: "immediate";
  skippable?: boolean;
  revisions?: number;
  params?: Record<string, unknown>;
}

export interface RoundsConfig {
  engine: "rounds";
  mechanic: string;
  rounds?: number;
  rounds_setting?: string;
  roles?: "alternate";
  score?: "prediction";
  reveal?: "capsule";
  rerolls?: number;
  steps: StepDef[];
  after: StepDef[];
  settings?: Record<string, { label: string; options: (string | number)[]; default: string | number }>;
}

/** Élément tiré dans une banque : index et valeur (texte, ou objet selon la banque). */
export interface BankItem<V = unknown> { i: number; v: V }

export interface RoundCard {
  id?: string;
  text?: string;
  choices?: string[];
  adult?: boolean;
  theme?: string;
  role_a?: number;
  rerolled?: number;
  [list: string]: unknown;
}

export interface RAnswer {
  step: string;
  seat: number;
  skipped: boolean;
  revision?: number;
  payload: Record<string, unknown> | null;
}

export interface RRound {
  round_no: number;
  card: RoundCard;
  revealed: boolean;
  reveal_at?: string | null;
  answers: RAnswer[];
}

export function stepSeats(step: StepDef, card: RoundCard): number[] {
  const a = card.role_a ?? 1;
  switch (step.who ?? "both") {
    case "a": return [a];
    case "b": return [3 - a];
    case "seat1": return [1];
    case "seat2": return [2];
    default: return [1, 2];
  }
}

export function answerOf(round: RRound, key: string, seat: number): RAnswer | undefined {
  return round.answers.find((x) => x.step === key && x.seat === seat);
}

function hasStep(round: RRound, key: string) {
  return round.answers.some((x) => x.step === key);
}

export type Turn =
  | { kind: "answer"; step: StepDef; index: number; total: number }
  | { kind: "wait"; for?: StepDef }
  | { kind: "done" };

/**
 * Ce que l'appelant doit faire maintenant dans une manche non révélée : répondre à une étape,
 * attendre l'autre (étape dont la sienne dépend), ou rien (tout envoyé).
 */
export function nextTurn(cfg: RoundsConfig, round: RRound, seat: number): Turn {
  const mine = cfg.steps.filter((s) => stepSeats(s, round.card).includes(seat));
  for (let i = 0; i < mine.length; i++) {
    const s = mine[i];
    if (answerOf(round, s.key, seat)) continue;
    if (s.after && !hasStep(round, s.after)) {
      const dep = cfg.steps.find((x) => x.key === s.after);
      return { kind: "wait", for: dep };
    }
    return { kind: "answer", step: s, index: i, total: mine.length };
  }
  return { kind: "done" };
}

/** Étapes après révélation que l'appelant peut faire maintenant (ou réviser), dans l'ordre. */
export function afterTurns(cfg: RoundsConfig, round: RRound, seat: number): StepDef[] {
  if (!round.revealed) return [];
  return (cfg.after ?? []).filter((s) => {
    if (!stepSeats(s, round.card).includes(seat)) return false;
    if (s.after && !hasStep(round, s.after)) return false;
    const mine = answerOf(round, s.key, seat);
    return !mine || (mine.revision ?? 0) < (s.revisions ?? 0);
  });
}

/** Libellé d'un élément de banque : texte simple, mot accordé ({ m, f }) ou objet avec libellé. */
export function itemLabel(v: unknown, form: WordForm = "n"): string {
  if (typeof v === "string") return v;
  if (v && typeof v === "object") {
    const o = v as Record<string, unknown>;
    if (typeof o.m === "string" && typeof o.f === "string") {
      if (form === "f") return o.f;
      if (form === "m") return o.m;
      return o.f === o.m ? o.m : `${o.m} · ${o.f}`;
    }
    if (typeof o.label === "string") return o.label;
    if (typeof o.name === "string") return o.name;
  }
  return String(v ?? "");
}

export function list<V = unknown>(card: RoundCard, key: string): BankItem<V>[] {
  const l = card[key];
  return Array.isArray(l) ? (l as BankItem<V>[]) : [];
}

/** Liste fixe (libellés simples) : éclairages, zones, champs de capsule… */
export function fixed(card: RoundCard, key: string): string[] {
  const l = card[key];
  return Array.isArray(l) ? (l as unknown[]).map((x) => itemLabel(x)) : [];
}

/** Coût total d'un panier (« Douze jetons d'envie »). */
export function basketCost(card: RoundCard, items: number[]): number {
  const acts = list<{ cost: number }>(card, "activities");
  return items.reduce((sum, i) => sum + (acts[i]?.v.cost ?? 0), 0);
}

/** Bascule une sélection limitée (ordre conservé : utile au classement). */
export function toggleIn(list: number[], i: number, max: number): number[] {
  if (list.includes(i)) return list.filter((x) => x !== i);
  return list.length >= max ? list : [...list, i];
}

export function move<T>(arr: T[], from: number, to: number): T[] {
  if (to < 0 || to >= arr.length) return arr;
  const next = [...arr];
  const [x] = next.splice(from, 1);
  next.splice(to, 0, x);
  return next;
}
