import type { Answer, Round, Word, WordForm } from "../lib/types.ts";

/** Libellé d'un mot accordé selon la personne décrite. */
export function wordLabel(word: Word, form: WordForm): string {
  if (form === "f") return word.f;
  if (form === "m") return word.m;
  return word.f === word.m ? word.m : `${word.m} · ${word.f}`;
}

export function answerOf(round: Round, step: string, seat: number): Answer | undefined {
  return round.answers.find((a) => a.step === step && a.seat === seat);
}

export interface PortraitReveal {
  /** Mots choisis par la personne décrite (null si elle a passé). */
  chosen: string[] | null;
  /** Mots imaginés par l'autre (null si elle a passé). */
  guessed: string[] | null;
  /** Mots en commun. */
  found: string[];
}

/** Compare le portrait de `aboutSeat` avec ce que l'autre siège a imaginé. */
export function portraitReveal(round: Round, aboutSeat: number): PortraitReveal {
  const otherSeat = aboutSeat === 1 ? 2 : 1;
  const self = answerOf(round, "self", aboutSeat);
  const guess = answerOf(round, "guess", otherSeat);
  const chosen = self && !self.skipped ? self.payload?.words ?? null : null;
  const guessed = guess && !guess.skipped ? guess.payload?.words ?? null : null;
  const found = chosen && guessed ? chosen.filter((w) => guessed.includes(w)) : [];
  return { chosen, guessed, found };
}

/** Prochaine étape à jouer pour un siège, ou null si tout est envoyé. */
export function nextStep(round: Round, stepKeys: string[], seat: number): string | null {
  return stepKeys.find((k) => !answerOf(round, k, seat)) ?? null;
}

/** Ajoute ou retire un mot d'une sélection limitée. */
export function toggleWord(selection: string[], id: string, max: number): string[] {
  if (selection.includes(id)) return selection.filter((w) => w !== id);
  if (selection.length >= max) return selection;
  return [...selection, id];
}
