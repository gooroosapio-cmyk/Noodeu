/* eslint-disable @typescript-eslint/no-explicit-any */
// Lot 4 : Le Pendu, Petit bac, Cite trois en 10 secondes. Le serveur garde le mot, la lettre et la consigne ;
// l'écran n'affiche que ce que le serveur a publié. Les échéances sont comparées à l'heure du serveur.
import { useEffect, useRef, useState } from "react";
import { t } from "../../i18n";
import { Alert, Icon, Loading } from "../../components/ui";
import type { Player } from "../../lib/types";
import { CardBox, nameOf, forWho, useMoves, type Common, type CRound } from "./ConversationGames";

type J = any;
type Send = (type: string, payload?: Record<string, unknown>, quiet?: boolean) => Promise<{ ok: boolean; error?: string; info?: any }>;
type Play = (type: string, payload?: Record<string, unknown>) => Promise<boolean>;

export const WORD_MECHS = ["nd_hangman", "nd_categories_stop", "nd_name_three_call"];
export const isWordMech = (m?: string) => Boolean(m && WORD_MECHS.includes(m));
const PREMIUM = "/assets/premium";
const KNOWN = ["repeated", "too_early", "fields_missing", "time_up", "stale_draft", "call_required", "waiting_ack", "correction_pending", "seen", "invalid_move"];
const LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

// ---------------------------------------------------------------------------
// Heure du serveur : décalage mesuré à chaque réponse (info.now), utilisé pour toutes les échéances.
// ---------------------------------------------------------------------------
let clockOffset = 0;
function noteServerTime(res: { info?: any }) {
  const now = res?.info?.now;
  if (now) clockOffset = new Date(now).getTime() - Date.now();
}
const serverNow = () => Date.now() + clockOffset;

function useTicker(active: boolean, ms = 250) {
  const [, setTick] = useState(0);
  useEffect(() => {
    if (!active) return;
    const id = setInterval(() => setTick((x) => x + 1), ms);
    return () => clearInterval(id);
  }, [active, ms]);
  return serverNow();
}
const secondsLeft = (at: string | undefined, now: number) => (at ? Math.max(0, Math.ceil((new Date(at).getTime() - now) / 1000)) : 0);

function useTimedMoves(c: Common, round: CRound) {
  const m = useMoves(c, round, KNOWN);
  const send: Send = async (type, payload = {}, quiet = false) => {
    const res = await m.send(type, payload, quiet);
    noteServerTime(res);
    return res;
  };
  const play: Play = async (type, payload = {}) => (await send(type, payload)).ok;
  return { ...m, send, play };
}

function ContinueBar({ card, me, partner, busy, last, label, after }: { card: J; me: Player; partner?: Player; busy: boolean; last: boolean; label?: string; after: (t: string) => Promise<boolean> }) {
  const continued = Boolean(card.continue?.[me.seat]);
  const theyContinued = Boolean(partner && card.continue?.[partner.seat]);
  return (
    <div className="action-bar stack stack--2">
      <button className="btn" disabled={busy || continued} onClick={() => void after("continue")}>
        {continued ? t("conv.waitingContinue", { name: nameOf(partner) }) : label ?? (last ? t("conv.finish") : t("conv.continue"))}
        {!continued && <Icon name="arrow-right" />}
      </button>
      {theyContinued && !continued && <p className="t-meta center">{t("conv.partnerContinued", { name: nameOf(partner) })}</p>}
    </div>
  );
}

function Totals({ c, label }: { c: Common; label?: string }) {
  const players = c.st.players;
  const totals: Record<string, number> = { 1: 0, 2: 0 };
  for (const r of c.st.rounds as unknown as CRound[]) for (const s of ["1", "2"]) totals[s] += Number(r.card?.scores?.[s] ?? 0);
  return (
    <div className="stack stack--2">
      {label && <p className="t-meta center">{label}</p>}
      <div className="mini-scores">
        {[...players].sort((a, b) => Number(b.is_me) - Number(a.is_me)).map((p) => (
          <div key={p.seat} className={`mini-scores__item${p.is_me ? " mini-scores__item--me" : ""}`}>
            <span className="t-meta">{nameOf(p)}</span><span className="t-score">{totals[p.seat]}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Le Pendu
// ---------------------------------------------------------------------------
function Hangman({ c, round }: { c: Common; round: CRound }) {
  const card = round.card;
  const players = c.st.players;
  const me = players.find((p) => p.is_me)!;
  const partner = players.find((p) => !p.is_me);
  const { err, play, after } = useTimedMoves(c, round);
  const busy = c.busy || !c.online;
  const giver = players.find((p) => p.seat === card.giver);
  const iGive = card.giver === me.seat;
  const errors = Number(card.errors ?? 0);
  const mask: (string | null)[] = card.mask ?? [];
  const guessed: string[] = card.guessed ?? [];
  const misses: string[] = card.misses ?? [];

  return (
    <section className="stack stack--5">
      <div className="q-progress">
        <span className="t-meta">{t("word.round", { n: round.round_no, total: c.st.session.total_rounds })}</span>
        <span className="t-meta">{forWho(giver, "word.hm.youGive", "word.hm.gives")}</span>
      </div>

      {card.phase === "choose" ? (
        iGive ? (
          <div className="stack stack--3">
            <h2 className="t-section">{t("word.hm.chooseTitle")}</h2>
            <p className="t-small muted">{t("word.hm.chooseHint", { name: nameOf(partner) })}</p>
            <div className="q-choices" role="list">
              {(round.private?.choices ?? []).map((w: J) => (
                <button key={w.id} className="q-choice hm-choice" disabled={busy} onClick={() => void play("choose_word", { word_id: w.id })}>{w.text}</button>
              ))}
            </div>
          </div>
        ) : (
          <p className="t-small row"><Icon name="clock" size={16} />{t("word.hm.waitChoice", { name: nameOf(partner) })}</p>
        )
      ) : (
        <div className="stack stack--4">
          <div className="hm-board">
            <img className="hm-flower" src={`${PREMIUM}/M09/flower-${Math.min(errors, 6)}.svg`} alt={t("word.hm.petals", { n: 6 - Math.min(errors, 6) })} width={112} height={112} />
            <p className="t-meta" aria-live="polite">{t("word.hm.errors", { n: errors, max: 6 })}</p>
          </div>
          <p className="hm-slots" aria-label={t("word.hm.maskLabel", { n: mask.length })}>
            {mask.map((x, i) => <span key={i} className={`hm-slot${x ? " hm-slot--on" : ""}`}>{x ?? ""}</span>)}
          </p>
          {iGive && round.private?.word?.text && !card.done && <p className="t-small center">{t("word.hm.yourWord")} <strong>{round.private.word.text}</strong></p>}
          {!card.done && (
            <div className="hm-keys" role="group" aria-label={t("word.hm.keyboard")}>
              {LETTERS.map((l) => {
                const used = guessed.includes(l);
                return (
                  <button key={l} className={`hm-key${used ? (misses.includes(l) ? " hm-key--miss" : " hm-key--hit") : ""}`}
                    disabled={busy || used || iGive} aria-label={used ? t("word.hm.keyUsed", { l }) : l} onClick={() => void play("guess_letter", { letter: l })}>{l}</button>
                );
              })}
            </div>
          )}
          {!card.done && (iGive ? <p className="t-meta center">{t("word.hm.watch", { name: nameOf(partner) })}</p> : <p className="t-meta center">{t("word.hm.yourTurn")}</p>)}
        </div>
      )}

      {card.done && (
        <div className="stack stack--4 enter" aria-live="polite">
          <p className="strong center">{card.found
            ? forWho(players.find((p) => p.seat === card.guesser), "word.hm.foundMe", "word.hm.found")
            : t("word.hm.notFound", { word: card.text })}</p>
          <ContinueBar card={card} me={me} partner={partner} busy={busy} last={round.round_no >= c.st.session.total_rounds} after={after} />
          <Totals c={c} />
        </div>
      )}
      {err && <Alert>{err}</Alert>}
    </section>
  );
}

// ---------------------------------------------------------------------------
// Petit bac
// ---------------------------------------------------------------------------
const STATUS_CHIP: Record<string, string> = { valid: "nd-chip--mint", accepted: "nd-chip--mint", unknown: "", contested: "nd-chip--peach", rejected: "nd-chip--peach", invalid: "nd-chip--peach", empty: "" };

function PetitBacWrite({ c, round, send }: { c: Common; round: CRound; send: Send }) {
  const card = round.card;
  const cats: string[] = card.categories ?? [];
  const labels = (c.st.game.config as any).category_labels ?? {};
  const priv = round.private ?? {};
  const [text, setText] = useState<Record<string, string>>(() => Object.fromEntries(cats.map((k) => [k, priv.drafts?.[k]?.text ?? ""])));
  const rev = useRef<Record<string, number>>(Object.fromEntries(cats.map((k) => [k, Number(priv.drafts?.[k]?.rev ?? 0)])));
  const [saved, setSaved] = useState<Record<string, boolean>>(() => Object.fromEntries(cats.map((k) => [k, true])));
  const timers = useRef<Record<string, number>>({});
  const now = useTicker(true);
  const left = secondsLeft(card.deadline_at, now);
  const canStop = now >= new Date(card.stop_after).getTime() && cats.every((k) => text[k]?.trim());
  const expired = useRef(false);
  const offline = !c.online;

  useEffect(() => {
    if (left === 0 && !expired.current) { expired.current = true; void send("expire", {}, true); }
  }, [left, send]);
  useEffect(() => () => Object.values(timers.current).forEach((id) => clearTimeout(id)), []);

  const save = (k: string, v: string) => {
    rev.current[k] += 1;
    const r = rev.current[k];
    setSaved((s) => ({ ...s, [k]: false }));
    void send("save_field", { category_id: k, text: v, draft_revision: r }, true).then((res) => {
      if (res.ok && rev.current[k] === r) setSaved((s) => ({ ...s, [k]: true }));
    });
  };
  const wasOnline = useRef(c.online);
  useEffect(() => {
    if (c.online && !wasOnline.current && left > 0) {
      for (const k of cats) if (!saved[k]) save(k, text[k] ?? "");
    }
    wasOnline.current = c.online;
    // Les valeurs courantes sont reprises au retour réseau, sans réinitialiser le chrono serveur.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [c.online]);
  const change = (k: string, v: string) => {
    setText((s) => ({ ...s, [k]: v }));
    clearTimeout(timers.current[k]);
    timers.current[k] = window.setTimeout(() => save(k, v), 250);
  };
  const stop = () => {
    Object.values(timers.current).forEach((id) => clearTimeout(id));
    const drafts: Record<string, unknown> = {};
    for (const k of cats) { rev.current[k] += 1; drafts[k] = { text: text[k] ?? "", draft_revision: rev.current[k] }; }
    void send("stop", { drafts });
  };

  const filled = cats.filter((k) => text[k]?.trim()).length;
  const pending = cats.some((k) => !saved[k]);
  const partner = c.st.players.find((p) => !p.is_me);
  return (
    <div className="stack stack--4 pb">
      <div className="pb-head">
        <span className="pb-token" aria-label={t("word.pb.letterIs", { l: card.letter })}>
          <img src="/assets/premium/M16/letter-token.svg" alt="" aria-hidden="true" />
          <span aria-hidden="true">{card.letter}</span>
        </span>
        <div className="pb-head__info">
          <span className={`pb-time${left <= 15 ? " pb-time--low" : ""}`} role="timer" aria-live={left <= 10 ? "polite" : "off"}>
            {String(Math.floor(left / 60)).padStart(2, "0")}:{String(left % 60).padStart(2, "0")}
          </span>
          <span className="t-meta">{t("word.pb.filled", { n: filled, total: cats.length })} · {pending ? t("word.pb.saving") : t("word.pb.saved")}</span>
        </div>
      </div>
      <div className="pb-grid">
        {cats.map((k) => (
          <div key={k} className={`pb-cell${text[k]?.trim() ? " is-filled" : ""}`}>
            <label className="pb-cell__label" htmlFor={`pb-${k}`}>
              <img src={`/assets/premium/M16/${k}.svg`} alt="" aria-hidden="true" width={22} height={22} />{labels[k] ?? k}
            </label>
            <input id={`pb-${k}`} className="input pb-cell__input" type="text" maxLength={80} autoComplete="off" autoCapitalize="words" enterKeyHint="next"
              placeholder={t("word.pb.placeholder", { l: card.letter })} value={text[k] ?? ""} disabled={offline || left === 0}
              onChange={(e) => change(k, e.target.value)}
              onFocus={(e) => { const el = e.currentTarget; window.setTimeout(() => el.scrollIntoView({ block: "center", behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches || document.documentElement.classList.contains("reduced-motion") ? "instant" : "smooth" }), 250); }}
              onKeyDown={(e) => {
                if (e.key !== "Enter") return;
                e.preventDefault();
                const next = cats[cats.indexOf(k) + 1];
                if (next) document.getElementById(`pb-${next}`)?.focus();
              }}
              onBlur={(e) => { if (!saved[k]) { clearTimeout(timers.current[k]); save(k, e.target.value); } }} />
          </div>
        ))}
      </div>
      <div className="pb-stop">
        <button className="btn" disabled={offline || !canStop || left === 0} onClick={stop}>
          <img src="/assets/premium/M16/stop.svg" alt="" aria-hidden="true" width={22} height={22} />{t("word.pb.stop")}
        </button>
        <p className="t-meta center">{!canStop && left > 0 ? t("word.pb.stopHint8", { total: cats.length }) : t("word.pb.partnerWriting", { name: nameOf(partner) })}</p>
      </div>
    </div>
  );
}

function PetitBacValidation({ c, round, send }: { c: Common; round: CRound; send: Send }) {
  const card = round.card;
  const players = c.st.players;
  const me = players.find((p) => p.is_me)!;
  const partner = players.find((p) => !p.is_me);
  const labels = (c.st.game.config as any).category_labels ?? {};
  const votes = round.private?.votes ?? {};
  const same = round.private?.same ?? {};
  const busy = c.busy || !c.online;
  const now = useTicker(!card.done);
  const left = secondsLeft(card.validation_deadline, now);
  const expired = useRef(false);
  useEffect(() => {
    if (!card.done && left === 0 && !expired.current) { expired.current = true; void send("expire", {}, true); }
  }, [left, card.done, send]);
  const order = [me, partner].filter(Boolean) as Player[];
  const final = Boolean(card.done);

  return (
    <div className="stack stack--4">
      {!final && <p className="t-small">{t("word.pb.judgeIntro", { n: left })}</p>}
      {(card.categories ?? []).map((k: string) => {
        const a = order.map((p) => ({ p, e: card.answers?.[p.seat]?.[k] ?? {} }));
        const ok = (e: J) => ["valid", "unknown"].includes(e.status);
        const needSame = !final && a.every((x) => ok(x.e)) && a[0].e.norm !== a[1]?.e.norm && !(a[0].e.acc && a[1]?.e.acc);
        return (
          <section key={k} className="card stack stack--3">
            <h3 className="t-card row"><img src={`/assets/premium/M16/${k}.svg`} alt="" aria-hidden="true" width={24} height={24} />{labels[k] ?? k}</h3>
            {a.map(({ p, e }) => {
              const st = final ? e.final : e.status;
              return (
                <div key={p.seat} className="stack stack--2">
                  <p className="row row--wrap" style={{ gap: 8 }}>
                    <span className="t-meta strong">{nameOf(p)}</span>
                    <span className="grow">{e.text || <span className="muted">{t("word.pb.empty")}</span>}</span>
                    {st && st !== "empty" && <span className={`nd-chip ${STATUS_CHIP[st] ?? ""}`}>{t(`word.pb.st.${st}` as never)}</span>}
                    {final && <span className="nd-chip">{t("word.pts", { n: e.points ?? 0 })}</span>}
                  </p>
                  {!final && ok(e) && (
                    <div className="chips" role="group" aria-label={t("word.pb.voteFor", { name: nameOf(p), cat: labels[k] ?? k })}>
                      {(["accept", "reject", "unresolved"] as const).map((v) => {
                        const current = votes[`${p.seat}:${k}`] ?? (e.status === "valid" ? "accept" : undefined);
                        return (
                          <button key={v} className="chip" aria-pressed={current === v} disabled={busy}
                            onClick={() => void send("judge_entry", { seat: p.seat, category_id: k, verdict: v })}>{t(`word.pb.vote.${v}` as never)}</button>
                        );
                      })}
                    </div>
                  )}
                </div>
              );
            })}
            {needSame && (
              <div className="stack stack--2">
                <p className="t-small">{t("word.pb.sameAsk")}</p>
                <div className="chips">
                  <button className="chip" aria-pressed={same[k] === true} disabled={busy} onClick={() => void send("judge_identity", { category_id: k, same: true })}>{t("word.pb.same")}</button>
                  <button className="chip" aria-pressed={same[k] === false} disabled={busy} onClick={() => void send("judge_identity", { category_id: k, same: false })}>{t("word.pb.different")}</button>
                </div>
              </div>
            )}
            {final && card.identity?.[k] === "contested" && <p className="t-meta">{t("word.pb.identityContested")}</p>}
          </section>
        );
      })}
      {!final && (
        <div className="stack stack--2">
          <button className="btn" disabled={busy || Boolean(card.confirmed?.[me.seat])} onClick={() => void send("confirm_validation")}>
            <Icon name="check" size={18} />{card.confirmed?.[me.seat] ? t("conv.waitingContinue", { name: nameOf(partner) }) : t("word.pb.confirm")}
          </button>
          {partner && card.confirmed?.[partner.seat] && !card.confirmed?.[me.seat] && <p className="t-meta center">{t("word.pb.partnerConfirmed", { name: nameOf(partner) })}</p>}
        </div>
      )}
    </div>
  );
}

function PetitBac({ c, round }: { c: Common; round: CRound }) {
  const card = round.card;
  const players = c.st.players;
  const me = players.find((p) => p.is_me)!;
  const partner = players.find((p) => !p.is_me);
  const { err, play, after, send } = useTimedMoves(c, round);
  const busy = c.busy || !c.online;
  return (
    <section className="stack stack--5">
      <div className="q-progress">
        <span className="t-meta">{t("word.round", { n: round.round_no, total: c.st.session.total_rounds })}</span>
        {card.letter && <span className="t-meta">{t("word.pb.letterIs", { l: card.letter })}</span>}
      </div>
      {card.phase === "loaded" ? (
        <div className="stack stack--3">
          <p className="t-small">{t("word.pb.readyText")}</p>
          <button className="btn" disabled={busy || Boolean(card.loaded?.[me.seat])} onClick={() => void play("round_loaded")}>
            {card.loaded?.[me.seat] ? t("conv.waitingContinue", { name: nameOf(partner) }) : t("word.ready")}
          </button>
          {partner && card.loaded?.[partner.seat] && !card.loaded?.[me.seat] && <p className="t-meta center">{t("word.partnerReady", { name: nameOf(partner) })}</p>}
        </div>
      ) : card.phase === "write" ? (
        <PetitBacWrite key={round.round_no} c={c} round={round} send={send} />
      ) : (
        <PetitBacValidation c={c} round={round} send={send} />
      )}
      {card.done && (
        <div className="stack stack--4">
          <ContinueBar card={card} me={me} partner={partner} busy={busy} last={round.round_no >= c.st.session.total_rounds} after={after} />
          <Totals c={c} />
        </div>
      )}
      {err && <Alert>{err}</Alert>}
    </section>
  );
}

// ---------------------------------------------------------------------------
// Cite trois en 10 secondes
// ---------------------------------------------------------------------------
function CiteLive({ c, round, send }: { c: Common; round: CRound; send: Send }) {
  const card = round.card;
  const players = c.st.players;
  const me = players.find((p) => p.is_me)!;
  const now = useTicker(true, 100);
  const starts = new Date(card.starts_at).getTime();
  const deadline = new Date(card.deadline_at).getTime();
  const acked = Boolean(card.acks?.[me.seat]);
  const both = Boolean(card.acks?.["1"] && card.acks?.["2"]);
  const sent = useRef({ ack: false, tick: false, interrupt: false });
  const isJudge = card.judge === me.seat;
  const busy = c.busy || !c.online;

  // Accusé de réception envoyé dès l'heure de départ (le serveur refuse tout envoi anticipé, on relance alors).
  useEffect(() => {
    if (acked || sent.current.ack || now < starts) return;
    sent.current.ack = true;
    void send("prompt_received", {}, true).then((res) => { if (!res.ok && res.error === "too_early") sent.current.ack = false; });
  }, [now, starts, acked, send]);
  // Accusé manquant 750 ms après le départ : le serveur annule la manche.
  useEffect(() => {
    if (both || sent.current.tick || now < starts + 1000) return;
    sent.current.tick = true;
    void send("tick", {}, true);
  }, [now, starts, both, send]);
  // Quitter l'écran pendant les 10 secondes annule la manche, sans point.
  useEffect(() => {
    const onHide = () => {
      if (document.visibilityState === "hidden" && serverNow() < deadline && !sent.current.interrupt) {
        sent.current.interrupt = true;
        void send("interrupt", {}, true);
      }
    };
    document.addEventListener("visibilitychange", onHide);
    return () => document.removeEventListener("visibilitychange", onHide);
  }, [deadline, send]);

  if (now < starts || !card.text) {
    return (
      <div className="cite-count" role="timer" aria-live="polite">
        <p className="t-section">{now < starts ? t("word.ct.startsIn", { n: secondsLeft(card.starts_at, now) }) : t("word.ct.receiving")}</p>
        <Loading />
      </div>
    );
  }
  const left = secondsLeft(card.deadline_at, now);
  const late = now >= deadline;
  const waitSec = Math.floor((now - deadline) / 1000);
  const respondent = players.find((p) => p.seat === card.respondent);
  return (
    <div className="stack stack--4">
      <p className="nd-chip">{forWho(respondent, "word.ct.youAnswer", "word.ct.answers")}</p>
      <article className="q-card"><h2 className="t-question">{card.text}</h2></article>
      <div className="cite-timer">
        <svg className="cite-dial" viewBox="0 0 120 120" width={120} height={120} aria-hidden="true">
          <circle cx="60" cy="60" r="52" className="cite-dial__track" />
          <circle cx="60" cy="60" r="52" className="cite-dial__arc" pathLength={100}
            strokeDasharray={`${Math.max(0, Math.min(100, (100 * Math.max(0, deadline - now)) / Math.max(1, deadline - starts)))} 100`} />
          <text x="60" y="70" textAnchor="middle" className="cite-dial__n">{left}</text>
        </svg>
        <p className="t-meta" role="timer" aria-live="off">{late ? t("word.ct.timeUp") : t("word.seconds", { n: left })}</p>
      </div>
      {isJudge ? (
        <div className="stack stack--2">
          <p className="t-small strong">{late ? t("word.ct.judgeLate") : t("word.ct.judgeNow")}</p>
          <div className="q-choices">
            <button className="btn btn--secondary" disabled={busy || !both} onClick={() => void send("verdict", { success: true })}>
              <img src={`${PREMIUM}/G07/success.svg`} alt="" width={22} height={22} />{t("word.ct.success")}
            </button>
            <button className="btn btn--secondary" disabled={busy || !both} onClick={() => void send("verdict", { success: false })}>
              <img src={`${PREMIUM}/G07/failure.svg`} alt="" width={22} height={22} />{t("word.ct.failure")}
            </button>
          </div>
          {!both && <p className="t-meta">{t("word.ct.waitAck")}</p>}
          {late && waitSec >= 30 && <Alert kind="info">{t("word.ct.reminder")}</Alert>}
        </div>
      ) : (
        <p className="t-small">{late ? t("word.ct.waitVerdict", { name: nameOf(players.find((p) => p.seat === card.judge)) }) : card.respondent === me.seat ? t("word.ct.goSpeak") : ""}</p>
      )}
      {late && waitSec >= 120 && (
        <div className="stack stack--2">
          <p className="t-small">{t("word.ct.voidAsk")}</p>
          <button className="btn btn--quiet" aria-pressed={card.void_votes?.[me.seat] === true} disabled={busy || card.void_votes?.[me.seat] === true}
            onClick={() => void send("void_vote", { accept: true })}>{t("word.ct.voidVote")}</button>
        </div>
      )}
    </div>
  );
}

function CiteTrois({ c, round }: { c: Common; round: CRound }) {
  const card = round.card;
  const players = c.st.players;
  const me = players.find((p) => p.is_me)!;
  const partner = players.find((p) => !p.is_me);
  const { err, play, after, send } = useTimedMoves(c, round);
  const busy = c.busy || !c.online;
  const [call, setCall] = useState(false);
  const target = Number((c.st.game.config as any).target ?? 30);
  let best = 0;
  for (const s of ["1", "2"]) best = Math.max(best, (c.st.rounds as unknown as CRound[]).reduce((n, r) => n + Number(r.card?.scores?.[s] ?? 0), 0));
  const correction = card.correction;

  return (
    <section className="stack stack--5">
      <div className="q-progress">
        <span className="t-meta">{t("word.ct.round", { n: round.round_no })}</span>
        <span className="t-meta">{t("word.ct.target", { n: target })}</span>
      </div>
      {card.adult && !card.done && <span className="nd-chip nd-chip--peach">{t("conv.adultChip")}</span>}

      {card.phase === "loading" ? (
        <div className="stack stack--3">
          {card.need_call && (
            <label className="switch-row">
              <span className="switch-row__text"><span>{t("word.ct.inCall")}</span><span className="t-meta">{t("word.ct.inCallHint")}</span></span>
              <input className="switch" type="checkbox" role="switch" checked={call || Boolean(card.loaded?.[me.seat])} disabled={busy || Boolean(card.loaded?.[me.seat])} onChange={(e) => setCall(e.target.checked)} />
            </label>
          )}
          <button className="btn" disabled={busy || Boolean(card.loaded?.[me.seat]) || (card.need_call && !call)} onClick={() => void play("round_loaded", { call })}>
            {card.loaded?.[me.seat] ? t("conv.waitingContinue", { name: nameOf(partner) }) : t("word.ready")}
          </button>
          {partner && card.loaded?.[partner.seat] && !card.loaded?.[me.seat] && <p className="t-meta center">{t("word.partnerReady", { name: nameOf(partner) })}</p>}
        </div>
      ) : card.phase === "live" && !card.done ? (
        <CiteLive key={round.round_no} c={c} round={round} send={send} />
      ) : null}

      {card.done && (
        <div className="stack stack--4 enter" aria-live="polite">
          {card.redacted ? <Alert kind="info">{t("conv.interrupted")}</Alert>
            : card.skipped ? <Alert kind="info">{t("word.ct.skipped")}</Alert>
            : card.void ? <Alert kind="info">{t(`word.ct.void.${card.void}` as never)}</Alert>
            : (
              <>
                {card.text && <CardBox card={card} />}
                <p className="strong center row" style={{ justifyContent: "center" }}>
                  <img src={`${PREMIUM}/G07/${card.verdict ? "success" : "failure"}.svg`} alt="" width={28} height={28} />
                  {card.verdict ? forWho(players.find((p) => p.seat === card.respondent), "word.ct.successMe", "word.ct.successOf")
                    : forWho(players.find((p) => p.seat === card.respondent), "word.ct.failureMe", "word.ct.failureOf")}
                </p>
                {card.corrected && <p className="t-meta center">{t("word.ct.corrected")}</p>}
                {card.correction_refused && <p className="t-meta center">{t("word.ct.correctionRefused")}</p>}
                {correction ? (
                  correction.votes?.[me.seat] ? <p className="t-meta center">{t("word.ct.correctionWait", { name: nameOf(partner) })}</p> : (
                    <div className="stack stack--2">
                      <p className="t-small">{t("word.ct.correctionAsk", { verdict: t(correction.proposed ? "word.ct.success" : "word.ct.failure") })}</p>
                      <div className="q-choices">
                        <button className="btn btn--secondary" disabled={busy} onClick={() => void after("correction_vote", { accept: true })}>{t("word.ct.accept")}</button>
                        <button className="btn btn--secondary" disabled={busy} onClick={() => void after("correction_vote", { accept: false })}>{t("word.ct.refuse")}</button>
                      </div>
                    </div>
                  )
                ) : (
                  <button className="btn btn--quiet" disabled={busy} onClick={() => void after("correction_request")}>{t("word.ct.correct")}</button>
                )}
              </>
            )}
          {!correction && (
            <ContinueBar card={card} me={me} partner={partner} busy={busy} last={false} after={after}
              label={best >= target ? t("word.ct.confirmFinal") : undefined} />
          )}
          <Totals c={c} label={best >= target ? t("word.ct.finalPending") : undefined} />
        </div>
      )}

      {err && <Alert>{err}</Alert>}
      {!card.done && <button className="btn btn--quiet" disabled={busy} onClick={() => void play("pass_round")}>{t("word.ct.pass")}</button>}
    </section>
  );
}

export function WordPlaying({ c }: { c: Common }) {
  const round = (c.st.rounds as unknown as CRound[]).find((r) => r.round_no === c.st.session.current_round);
  if (!round) return <Loading />;
  const m = round.card?.mech;
  if (m === "nd_hangman") return <Hangman key={round.round_no} c={c} round={round} />;
  if (m === "nd_categories_stop") return <PetitBac key={round.round_no} c={c} round={round} />;
  return <CiteTrois key={round.round_no} c={c} round={round} />;
}
