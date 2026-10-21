import { test } from "node:test";
import assert from "node:assert/strict";
import { nextStep, portraitReveal, toggleWord, wordLabel } from "./portrait.ts";
import type { Round } from "../lib/types.ts";

const word = { id: "portrait.curieux", f: "Curieuse", m: "Curieux" };

test("accord des mots selon la personne décrite", () => {
  assert.equal(wordLabel(word, "f"), "Curieuse");
  assert.equal(wordLabel(word, "m"), "Curieux");
  assert.equal(wordLabel(word, "n"), "Curieux · Curieuse");
  assert.equal(wordLabel({ id: "x", f: "Calme", m: "Calme" }, "n"), "Calme");
});

test("sélection limitée au nombre demandé", () => {
  let sel: string[] = [];
  for (const id of ["a", "b", "c", "d", "e", "f"]) sel = toggleWord(sel, id, 5);
  assert.deepEqual(sel, ["a", "b", "c", "d", "e"]);
  assert.deepEqual(toggleWord(sel, "c", 5), ["a", "b", "d", "e"]);
});

const round: Round = {
  round_no: 1,
  card: { words: [] },
  revealed: true,
  answers: [
    { step: "self", seat: 1, skipped: false, payload: { words: ["a", "b", "c", "d", "e"] } },
    { step: "guess", seat: 1, skipped: false, payload: { words: ["v", "w", "x", "y", "z"] } },
    { step: "self", seat: 2, skipped: true, payload: null },
    { step: "guess", seat: 2, skipped: false, payload: { words: ["a", "c", "e", "q", "r"] } },
  ],
};

test("mots retrouvés : portrait du siège 1 deviné par le siège 2", () => {
  const r = portraitReveal(round, 1);
  assert.deepEqual(r.found, ["a", "c", "e"]);
});

test("une étape passée ne compte pas comme un échec", () => {
  const r = portraitReveal(round, 2);
  assert.equal(r.chosen, null);
  assert.deepEqual(r.found, []);
});

test("étape suivante", () => {
  const partial: Round = { ...round, answers: [round.answers[0]] };
  assert.equal(nextStep(partial, ["self", "guess"], 1), "guess");
  assert.equal(nextStep(partial, ["self", "guess"], 2), "self");
  assert.equal(nextStep(round, ["self", "guess"], 1), null);
});
