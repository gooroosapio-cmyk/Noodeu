import { test } from "node:test";
import assert from "node:assert/strict";
import { afterTurns, basketCost, itemLabel, move, nextTurn, stepSeats, toggleIn, type RRound, type RoundsConfig } from "./logic.ts";

const listening: RoundsConfig = {
  engine: "rounds", mechanic: "listening", roles: "alternate",
  steps: [
    { key: "share", kind: "share", who: "a", visible: "immediate" },
    { key: "reformulate", kind: "text", who: "b", after: "share", visible: "immediate" },
    { key: "confirm", kind: "confirm", who: "a", after: "reformulate" },
  ],
  after: [],
};

const round = (role_a: number, answers: RRound["answers"] = [], revealed = false): RRound =>
  ({ round_no: 1, card: { role_a }, revealed, answers });

test("rôles : le siège « a » change selon la carte", () => {
  assert.deepEqual(stepSeats({ key: "x", kind: "text", who: "a" }, { role_a: 2 }), [2]);
  assert.deepEqual(stepSeats({ key: "x", kind: "text", who: "b" }, { role_a: 2 }), [1]);
  assert.deepEqual(stepSeats({ key: "x", kind: "text" }, {}), [1, 2]);
});

test("écoute : l'auteur raconte, l'autre attend puis reformule", () => {
  assert.equal(nextTurn(listening, round(1), 1).kind, "answer");
  assert.equal(nextTurn(listening, round(1), 2).kind, "wait");
  const r = round(1, [{ step: "share", seat: 1, skipped: false, payload: {} }]);
  const t2 = nextTurn(listening, r, 2);
  assert.equal(t2.kind === "answer" && t2.step.key, "reformulate");
  const t1 = nextTurn(listening, r, 1);
  assert.equal(t1.kind, "wait", "l'auteur attend la reformulation avant de confirmer");
});

test("étapes après révélation : révision limitée", () => {
  const cfg: RoundsConfig = { engine: "rounds", mechanic: "budget", steps: [], after: [{ key: "common", kind: "common", revisions: 1 }] };
  assert.equal(afterTurns(cfg, round(1, [], false), 1).length, 0, "rien avant la révélation");
  assert.equal(afterTurns(cfg, round(1, [], true), 1).length, 1);
  const once = round(1, [{ step: "common", seat: 1, skipped: false, revision: 0, payload: {} }], true);
  assert.equal(afterTurns(cfg, once, 1).length, 1, "une révision encore possible");
  const twice = round(1, [{ step: "common", seat: 1, skipped: false, revision: 1, payload: {} }], true);
  assert.equal(afterTurns(cfg, twice, 1).length, 0);
});

test("libellés : accord du lexique Portrait et objets", () => {
  assert.equal(itemLabel({ m: "curieux", f: "curieuse" }, "f"), "curieuse");
  assert.equal(itemLabel({ m: "calme", f: "calme" }, "n"), "calme");
  assert.equal(itemLabel({ m: "vif", f: "vive" }, "n"), "vif · vive");
  assert.equal(itemLabel({ label: "memory", cost: 2 }), "memory");
});

test("sélection limitée, ordre et budget", () => {
  assert.deepEqual(toggleIn([1, 2], 3, 2), [1, 2]);
  assert.deepEqual(toggleIn([1, 2], 1, 2), [2]);
  assert.deepEqual(move(["a", "b", "c"], 2, 0), ["c", "a", "b"]);
  assert.equal(basketCost({ activities: [{ i: 0, v: { cost: 3 } }, { i: 1, v: { cost: 4 } }] }, [0, 1]), 7);
});
