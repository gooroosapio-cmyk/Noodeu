/* eslint-disable @typescript-eslint/no-explicit-any */
// Jeux de conversation (catégorie 3) : cartes tirées par le serveur, réponses scellées, révélation commune,
// « Continuer » des deux. L'écran ne reçoit jamais la réponse de l'autre avant la révélation.
import { LaterButton } from "../Later";
import { rpc } from "../../lib/supabase";
import { IntensityTransition, useSessionMeta } from "../../parcours/meta";
import { useEffect, useState } from "react";
import { Link } from "react-router";
import { t } from "../../i18n";
import { useAuth } from "../../auth/AuthProvider";
import { Alert, Art, Icon, Loading } from "../../components/ui";
import { Avatar } from "../../components/Avatar";
import type { Player, SessionState } from "../../lib/types";

type J = any;
type Run = (fn: string, args?: Record<string, unknown>) => Promise<{ ok: boolean; error?: string; info?: any }>;
export interface Common { st: SessionState; run: Run; busy: boolean; online: boolean; act?: (fn: string, args: Record<string, unknown>) => Promise<{ ok: boolean; error?: string; info?: any }> }
export interface CRound { round_no: number; card: J; revealed: boolean; private: J }

export const CONVERSATION_MECHS = ["nd_never", "nd_dilemma", "nd_duo_target", "nd_opinion", "nd_sentence", "nd_predict", "nd_truth_dare", "nd_two_truths"];
export const isConversationMech = (m?: string) => Boolean(m && CONVERSATION_MECHS.includes(m));
const roundsOf = (st: SessionState) => st.rounds as unknown as CRound[];
export const nameOf = (p?: Player) => (p ? (p.is_me ? t("game.you") : p.display_name || "?") : "?");
/** Texte selon que la personne désignée est soi (« Tu es le sujet ») ou l'autre (« Sujet : Alex »). */
export const forWho = (p: Player | undefined, mine: string, theirs: string) => (p?.is_me ? t(mine as never) : t(theirs as never, { name: nameOf(p) }));
const MAX = 1000;
/** Cartes tirées d'une banque de questions : elles peuvent être gardées pour plus tard (jamais Deux vérités, écrites par les joueurs). */
const LATER_MECHS = new Set(["nd_never", "nd_dilemma", "nd_duo_target", "nd_opinion", "nd_sentence", "nd_predict", "nd_truth_dare"]);

function moveError(code?: string, extra: string[] = []) {
  const known = ["invalid_text", "locked", "no_cards", "duplicate_text", "not_your_turn", "phase"];
  if (code && extra.includes(code)) return t(`word.err.${code}` as never);
  return code && known.includes(code) ? t(`conv.err.${code}` as never) : t("q.err.generic");
}

export function useMoves(c: Common, round: CRound, known: string[] = []) {
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => setErr(null), [round.round_no]);
  /** Coup brut : renvoie la réponse du serveur ; « quiet » n'affiche pas d'erreur (échéances, relances automatiques). */
  const send = async (type: string, payload: Record<string, unknown> = {}, quiet = false) => {
    if (!quiet) setErr(null);
    const args = { p_round: round.round_no, p_action: crypto.randomUUID(), p_type: type, p_payload: payload };
    // Les envois automatiques passent hors du verrou d'interface (pas de refus « busy » au moment d'une échéance).
    const res = quiet && c.act ? await c.act("play_move", args) : await c.run("play_move", args);
    if (!quiet && !res.ok && res.error !== "busy" && res.error !== "stale_round") setErr(moveError(res.error, known));
    return res;
  };
  const play = async (type: string, payload: Record<string, unknown> = {}) => (await send(type, payload)).ok;
  const after = async (type: string, payload: Record<string, unknown> = {}) => {
    setErr(null);
    const res = await c.run("round_after", { p_round: round.round_no, p_type: type, p_payload: payload });
    if (!res.ok && res.error !== "busy") setErr(moveError(res.error, known));
    return res.ok;
  };
  return { err, play, after, send };
}

// ---------------------------------------------------------------------------
// Éléments communs
// ---------------------------------------------------------------------------
export function CardBox({ card, label }: { card: J; label?: string }) {
  if (card.redacted) return <article className="q-card"><p className="muted">{t("conv.redacted")}</p></article>;
  return (
    <article className="q-card">
      <div className="q-card__head">
        <span className="row row--wrap" style={{ gap: 6 }}>
          {label && <span className="nd-chip">{label}</span>}
          {card.adult && <span className="nd-chip nd-chip--peach">{t("conv.adultChip")}</span>}
        </span>
        {card.theme && <span className="t-meta">{card.theme}</span>}
      </div>
      {card.prompt
        ? <h2 className="t-question" aria-label={card.text}>{card.prompt}</h2>
        : card.text && <h2 className={`t-question${card.text.length > 140 ? " t-question--long" : ""}`}>{card.text}</h2>}
    </article>
  );
}

function optionText(card: J, id?: string) {
  return (card.options ?? []).find((o: J) => o.id === id)?.text ?? "";
}

/** Valeur révélée d'une réponse, en texte lisible. */
function answerText(card: J, a: J, players: Player[]) {
  if (!a) return "";
  if (a.choice) return optionText(card, a.choice);
  if (a.seat) return nameOf(players.find((p) => p.seat === a.seat));
  return a.text ?? "";
}

function Reveal({ card, players }: { card: J; players: Player[] }) {
  const me = players.find((p) => p.is_me)!;
  const partner = players.find((p) => !p.is_me);
  return (
    <div className="stack stack--3 enter" aria-live="polite">
      {[me, partner].filter(Boolean).map((p) => (
        <section key={p!.seat} className={`q-answer${p!.is_me ? " q-answer--me" : ""}`}>
          <h3 className="t-meta strong">
            {card.mech === "nd_predict"
              ? (p!.seat === card.subject ? forWho(p, "conv.predict.myAnswer", "conv.predict.subjectAnswer") : forWho(p, "conv.predict.myGuess", "conv.predict.guessOf"))
              : nameOf(p)}
          </h3>
          <p className="q-answer__text">{answerText(card, card.answers?.[p!.seat], players)}</p>
        </section>
      ))}
    </div>
  );
}

function Status({ card, me, partner }: { card: J; me: Player; partner?: Player }) {
  const mine = Boolean(card.locked?.[me.seat]);
  const theirs = Boolean(partner && card.locked?.[partner.seat]);
  return (
    <div className="stack stack--2">
      {mine && <span className="nd-chip"><Icon name="lock-keyhole" size={16} />{t("q.pack.sealed")}</span>}
      <p className="t-meta row"><Icon name={theirs ? "check" : "clock"} size={16} />{theirs ? t("conv.partnerLocked", { name: nameOf(partner) }) : t("conv.partnerThinking", { name: nameOf(partner) })}</p>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Réponse scellée : choix, désignation, texte
// ---------------------------------------------------------------------------
function SealedForm({ card, me, partner, players, busy, play }: { card: J; me: Player; partner?: Player; players: Player[]; busy: boolean; play: (t: string, p?: Record<string, unknown>) => Promise<boolean> }) {
  const [choice, setChoice] = useState<string | null>(null);
  const [seat, setSeat] = useState<number | null>(null);
  const [text, setText] = useState("");
  const m = card.mech;
  const textual = m === "nd_sentence" || m === "nd_predict";
  const role = m === "nd_predict" ? (card.subject === me.seat ? "subject" : "predictor") : null;
  const ready = textual ? Boolean(text.trim()) : m === "nd_duo_target" ? seat !== null : choice !== null;
  const payload = textual ? { text: text.trim() } : m === "nd_duo_target" ? { seat } : { choice };
  return (
    <form className="stack stack--4" onSubmit={(e) => { e.preventDefault(); if (ready) void play("lock", payload); }}>
      {role && (
        <p className="nd-chip">{role === "subject" ? t("conv.predict.youSubject") : t("conv.predict.youPredict", { name: nameOf(partner) })}</p>
      )}
      {m === "nd_duo_target" ? (
        <div className="target-pick" role="radiogroup" aria-label={t("conv.target.label")}>
          {players.map((p) => (
            <button key={p.seat} type="button" role="radio" aria-checked={seat === p.seat} className="target-pick__btn" disabled={busy} onClick={() => setSeat(p.seat)}>
              <Avatar name={p.display_name} path={p.avatar_path} size={56} me={p.is_me} />
              <span>{p.is_me ? `${p.display_name} (${t("game.you")})` : p.display_name}</span>
            </button>
          ))}
        </div>
      ) : textual ? (
        <div className="field">
          <label className="field__label" htmlFor="conv-text">
            {m === "nd_sentence" ? t("conv.sentence.label") : role === "subject" ? t("conv.predict.subjectLabel") : t("conv.predict.guessLabel", { name: nameOf(partner) })}
          </label>
          <textarea id="conv-text" className="input q-textarea" maxLength={MAX} value={text} disabled={busy} onChange={(e) => setText(e.target.value)} />
          <span className="field__hint">{t("conv.textHint", { n: MAX - text.length })}</span>
        </div>
      ) : (
        <div className={card.options?.length === 2 && m !== "nd_dilemma" ? "q-choices" : "stack stack--2"} role="radiogroup" aria-label={t("conv.choose")}>
          {(card.options ?? []).map((o: J) => (
            <button key={o.id} type="button" role="radio" aria-checked={choice === o.id} className="q-choice" disabled={busy} onClick={() => setChoice(o.id)}>
              <span className="q-choice__dot" aria-hidden="true" />{o.text}
            </button>
          ))}
        </div>
      )}
      <button className="btn" type="submit" disabled={busy || !ready}><Icon name="lock-keyhole" size={18} />{t("conv.lock")}</button>
    </form>
  );
}

// ---------------------------------------------------------------------------
// Action ou Vérité
// ---------------------------------------------------------------------------
function TruthDare({ card, me, partner, busy, play }: { card: J; me: Player; partner?: Player; busy: boolean; play: (t: string, p?: Record<string, unknown>) => Promise<boolean> }) {
  const [text, setText] = useState("");
  const active = card.active === me.seat;
  if (!active) {
    return card.phase === "choice"
      ? <p className="t-small muted center">{t("conv.td.waitChoice", { name: nameOf(partner) })}</p>
      : <p className="t-small muted center">{t("conv.td.waitAnswer", { name: nameOf(partner) })}</p>;
  }
  if (card.phase === "choice") {
    return (
      <div className="stack stack--3">
        <p className="t-small">{t("conv.td.choose")}</p>
        <div className="q-choices">
          <button className="btn" disabled={busy} onClick={() => void play("choose_kind", { kind: "truth" })}>{t("conv.td.truth")}</button>
          <button className="btn btn--secondary" disabled={busy} onClick={() => void play("choose_kind", { kind: "dare" })}>{t("conv.td.dare")}</button>
        </div>
      </div>
    );
  }
  return (
    <div className="stack stack--4">
      <div className="field">
        <label className="field__label" htmlFor="td-text">{card.kind === "truth" ? t("conv.td.answer") : t("conv.td.shareOptional")}</label>
        <textarea id="td-text" className="input q-textarea" maxLength={MAX} value={text} disabled={busy} onChange={(e) => setText(e.target.value)} />
        <span className="field__hint">{card.kind === "truth" ? t("conv.textHint", { n: MAX - text.length }) : t("conv.td.noProof")}</span>
      </div>
      {card.kind === "truth" ? (
        <button className="btn" disabled={busy || !text.trim()} onClick={() => void play("submit_text", { text: text.trim() })}><Icon name="send" size={18} />{t("conv.td.send")}</button>
      ) : (
        <button className="btn" disabled={busy} onClick={() => void play("submit_action", { status: "done", ...(text.trim() ? { text: text.trim() } : {}) })}>
          <Icon name="check" size={18} />{t("conv.td.done")}
        </button>
      )}
      <button className="btn btn--secondary" disabled={busy} onClick={() => void play("replace_card")}><Icon name="refresh" size={18} />{t("conv.td.replace")}</button>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Deux vérités et un mensonge
// ---------------------------------------------------------------------------
function TwoTruths({ card, priv, me, partner, busy, play, sessionId }: { card: J; priv: J; me: Player; partner?: Player; busy: boolean; play: (t: string, p?: Record<string, unknown>) => Promise<boolean>; sessionId: string }) {
  const [texts, setTexts] = useState(["", "", ""]);
  const [idea, setIdea] = useState<string | null>(null);
  const [lie, setLie] = useState<string | null>(null);
  const [truthOk, setTruthOk] = useState(false);
  const [guess, setGuess] = useState<string | null>(null);
  const author = card.author === me.seat;
  if (card.phase === "write") {
    if (!author) return <p className="t-small muted center">{t("conv.tt.waitWrite", { name: nameOf(partner) })}</p>;
    const ready = texts.every((x) => x.trim()) && lie && truthOk && new Set(texts.map((x) => x.trim().toLowerCase())).size === 3;
    return (
      <form className="stack stack--4" onSubmit={(e) => {
        e.preventDefault();
        if (ready) void play("publish_three", { confirmed_truths: true, lie_statement_id: lie, statements: texts.map((x, i) => ({ id: `s${i + 1}`, text: x.trim() })) });
      }}>
        <p className="t-small">{t("conv.tt.writeHint")}</p>
        <div className="stack stack--2">
          <button type="button" className="btn btn--quiet btn--sm btn--auto" disabled={busy} onClick={async () => {
            const r = await rpc<{ text: string }>("get_two_truths_idea", { p_session: sessionId });
            setIdea(r.ok ? (r as unknown as { text: string }).text : t("conv.tt.noIdea"));
          }}><Icon name="sparkles" size={16} />{t("conv.tt.idea")}</button>
          {idea && <p className="t-small card card--soft" aria-live="polite">{idea}</p>}
        </div>
        {texts.map((x, i) => (
          <div key={i} className="field">
            <label className="field__label" htmlFor={`tt-${i}`}>{t("conv.tt.statement", { n: i + 1 })}</label>
            <input id={`tt-${i}`} className="input" maxLength={240} value={x} disabled={busy}
              onChange={(e) => setTexts(texts.map((y, k) => (k === i ? e.target.value : y)))} />
            <label className="row t-small">
              <input type="radio" name="tt-lie" checked={lie === `s${i + 1}`} onChange={() => setLie(`s${i + 1}`)} />
              {t("conv.tt.thisIsLie")}
            </label>
          </div>
        ))}
        <label className="row t-small"><input type="checkbox" checked={truthOk} onChange={(e) => setTruthOk(e.target.checked)} />{t("conv.tt.confirmTruths")}</label>
        <button className="btn" type="submit" disabled={busy || !ready}><Icon name="send" size={18} />{t("conv.tt.publish")}</button>
      </form>
    );
  }
  return (
    <div className="stack stack--3">
      <div className="stack stack--2" role={author ? undefined : "radiogroup"} aria-label={t("conv.tt.whichLie")}>
        {(card.statements ?? []).map((s: J) => (
          <button key={s.id} type="button" role={author ? undefined : "radio"} aria-checked={author ? undefined : guess === s.id} className="q-choice"
            disabled={busy || author} onClick={() => setGuess(s.id)}>
            {!author && <span className="q-choice__dot" aria-hidden="true" />}
            <span className="grow">{s.text}</span>
            {author && priv?.lie === s.id && <span className="nd-chip nd-chip--peach">{t("conv.tt.yourLie")}</span>}
          </button>
        ))}
      </div>
      {author
        ? <p className="t-small muted">{t("conv.tt.waitGuess", { name: nameOf(partner) })}</p>
        : <button className="btn" disabled={busy || !guess} onClick={() => guess && void play("lock_guess", { statement_id: guess })}>{t("conv.tt.lockGuess")}</button>}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Écran de manche
// ---------------------------------------------------------------------------
export function AdultWithdraw({ c }: { c: Common }) {
  const prefs = (c.st as unknown as { my_prefs?: { adult: boolean; excluded_topics: string[] } }).my_prefs;
  if (!prefs?.adult) return null;
  return (
    <button className="btn btn--quiet btn--sm" disabled={c.busy || !c.online}
      onClick={() => c.run("set_session_prefs", { p_adult: false, p_excluded: prefs.excluded_topics ?? [] })}>
      {t("conv.adultWithdraw")}
    </button>
  );
}

function RoundView({ c, round }: { c: Common; round: CRound }) {
  const card = round.card;
  const players = c.st.players;
  const me = players.find((p) => p.is_me)!;
  const partner = players.find((p) => !p.is_me);
  const { err, play, after } = useMoves(c, round);
  const busy = c.busy || !c.online;
  const total = c.st.session.total_rounds;
  const m = card.mech;
  const meta = useSessionMeta(c.st.session.id, round.round_no);
  const prevId = (roundsOf(c.st).find((r) => r.round_no === round.round_no - 1)?.card as { card_id?: string } | undefined)?.card_id;
  const curId = (card as { card_id?: string }).card_id;
  const continued = Boolean(card.continue?.[me.seat]);
  const theyContinued = Boolean(partner && card.continue?.[partner.seat]);
  const label = m === "nd_truth_dare" && card.kind ? t(card.kind === "truth" ? "conv.td.truth" : "conv.td.dare")
    : m === "nd_predict" ? forWho(players.find((p) => p.seat === card.subject), "conv.predict.subjectIsMe", "conv.predict.subjectIs") : undefined;

  return (
    <section className="stack stack--5" key={round.round_no}>
      <div className="q-progress">
        <span className="t-meta">{t("conv.round", { n: round.round_no, total })}</span>
        {m === "nd_truth_dare" && <span className="t-meta">{forWho(players.find((p) => p.seat === card.active), "conv.td.yourTurn", "conv.td.turnOf")}</span>}
        {m === "nd_two_truths" && <span className="t-meta">{forWho(players.find((p) => p.seat === card.author), "conv.tt.youAuthor", "conv.tt.authorIs")}</span>}
      </div>
      <IntensityTransition prev={prevId ? meta[prevId] : undefined} cur={curId ? meta[curId] : undefined} />
      {(card.text || card.redacted) && <CardBox card={card} label={label} />}

      {card.done ? (
        <div className="stack stack--4">
          {card.redacted ? <Alert kind="info">{t("conv.interrupted")}</Alert>
            : card.skipped ? <Alert kind="info">{t("conv.skipped")}</Alert>
            : m === "nd_truth_dare" ? (
              <section className="q-answer">
                <h3 className="t-meta strong">{nameOf(players.find((p) => p.seat === card.active))}</h3>
                <p className="q-answer__text">{card.response?.text ?? t("conv.td.actionDone")}</p>
              </section>
            ) : m === "nd_two_truths" ? (
              <div className="stack stack--2">
                {(card.statements ?? []).map((s: J) => (
                  <p key={s.id} className={`q-choice${s.id === card.lie ? " q-choice--lie" : ""}`}>
                    <span className="grow">{s.text}</span>
                    {s.id === card.lie && <span className="nd-chip nd-chip--peach">{t("conv.tt.theLie")}</span>}
                    {s.id === card.guess && <span className="nd-chip">{t("conv.tt.guessed")}</span>}
                  </p>
                ))}
                <p className="strong">{card.found
                  ? forWho(players.find((p) => p.seat === card.guesser), "conv.tt.foundMe", "conv.tt.found")
                  : forWho(players.find((p) => p.seat === card.author), "conv.tt.notFoundMe", "conv.tt.notFound")}</p>
              </div>
            ) : <Reveal card={card} players={players} />}

          {m === "nd_predict" && !card.skipped && !card.redacted && (
            card.subject === me.seat ? (
              <div className="stack stack--2">
                <p className="t-small strong">{t("conv.predict.verdictAsk", { name: nameOf(partner) })}</p>
                <div className="q-choices">
                  <button className="btn btn--secondary" aria-pressed={card.verdict === true} disabled={busy} onClick={() => void after("verdict", { matches: true })}>
                    <Icon name="thumbs-up" size={18} />{t("conv.predict.matches")}
                  </button>
                  <button className="btn btn--secondary" aria-pressed={card.verdict === false} disabled={busy} onClick={() => void after("verdict", { matches: false })}>
                    <Icon name="thumbs-down" size={18} />{t("conv.predict.noMatch")}
                  </button>
                </div>
              </div>
            ) : (
              <p className="t-small">{card.verdict === undefined ? t("conv.predict.waitVerdict", { name: nameOf(partner) })
                : card.verdict ? t("conv.predict.pointWon") : t("conv.predict.noPoint")}</p>
            )
          )}

          <div className="action-bar stack stack--2">
            <button className="btn" disabled={busy || continued} onClick={() => void after("continue")}>
              {continued ? t("conv.waitingContinue", { name: nameOf(partner) }) : round.round_no < total ? t("conv.continue") : t("conv.finish")}
              {!continued && <Icon name="arrow-right" />}
            </button>
            {theyContinued && !continued && <p className="t-meta center">{t("conv.partnerContinued", { name: nameOf(partner) })}</p>}
          </div>
        </div>
      ) : m === "nd_truth_dare" ? (
        <TruthDare card={card} me={me} partner={partner} busy={busy} play={play} />
      ) : m === "nd_two_truths" ? (
        <TwoTruths card={card} priv={round.private} me={me} partner={partner} busy={busy} play={play} sessionId={c.st.session.id} />
      ) : card.locked?.[me.seat] ? (
        <Status card={card} me={me} partner={partner} />
      ) : (
        <>
          <SealedForm key={round.round_no} card={card} me={me} partner={partner} players={players} busy={busy} play={play} />
          {partner && card.locked?.[partner.seat] && <p className="t-meta row"><Icon name="check" size={16} />{t("conv.partnerLocked", { name: nameOf(partner) })}</p>}
        </>
      )}

      {err && <Alert>{err}</Alert>}
      {!card.done && !card.redacted && LATER_MECHS.has(m) && <LaterButton sessionId={c.st.session.id} round={round.round_no} disabled={!c.online} />}
      {!card.done && <button className="btn btn--quiet" disabled={busy} onClick={() => void play("skip_round")}>{t("conv.skip")}</button>}
      {(card.adult || !card.done) && <AdultWithdraw c={c} />}
    </section>
  );
}

export function ConversationPlaying({ c }: { c: Common }) {
  const round = roundsOf(c.st).find((r) => r.round_no === c.st.session.current_round);
  if (!round) return <Loading />;
  return <RoundView key={round.round_no} c={c} round={round} />;
}

export function ConversationResults({ c, navigate }: { c: Common; navigate: (to: string) => void }) {
  const players = c.st.players;
  const result = c.st.session.result as { points?: Record<string, number>; shortened?: boolean; target_reached?: boolean } | undefined;
  const cite = c.st.game.mechanic === "nd_name_three_call";
  const scored = Boolean(result?.points);
  const rounds = roundsOf(c.st).filter((r) => r.card?.done);
  const ended = c.st.session.status === "ended" && !c.st.session.read_only;
  return (
    <section className="stack stack--5">
      <div className="q-result-head">
        <Art name="trophy" size={96} />
        <h1 className="t-page">{t("conv.endTitle")}</h1>
        <p className="t-small muted">{t("conv.endText", { n: rounds.length, title: c.st.game.title })}</p>
        {result?.shortened && <p className="t-meta">{cite ? t("word.ct.shortened") : t("conv.shortened")}</p>}
        {cite && !result?.target_reached && !result?.shortened && <p className="t-meta">{t("word.ct.noWinner")}</p>}
      </div>
      {scored && (
        <div className="mini-scores">
          {players.map((p) => (
            <div key={p.seat} className={`mini-scores__item${p.is_me ? " mini-scores__item--me" : ""}`}>
              <span className="t-meta">{nameOf(p)}</span><span className="t-score">{result!.points![String(p.seat)] ?? 0}</span>
            </div>
          ))}
        </div>
      )}
      {rounds.map((r) => (
        <details key={r.round_no} className="card">
          <summary className="strong">{r.card.redacted ? t("conv.redacted") : r.card.text ?? r.card.statements?.[0]?.text
            ?? (r.card.letter ? t("word.pb.roundLetter", { n: r.round_no, l: r.card.letter }) : t("conv.round", { n: r.round_no, total: c.st.session.total_rounds }))}</summary>
          {r.card.skipped ? <p className="muted">{t("conv.skipped")}</p>
            : r.card.mech === "nd_categories_stop" ? <p className="t-small">{players.map((p) => `${nameOf(p)} : ${r.card.scores?.[p.seat] ?? 0}`).join(" · ")}</p>
            : r.card.mech === "nd_hangman" ? <p className="t-small">{r.card.found ? t("word.hm.resultFound") : t("word.hm.resultMissed")}</p>
            : r.card.mech === "nd_name_three_call" ? <p className="t-small">{r.card.void ? t(`word.ct.void.${r.card.void}` as never) : r.card.verdict ? t("word.ct.success") : t("word.ct.failure")}</p>
            : r.card.answers ? <Reveal card={r.card} players={players} />
            : r.card.response ? <p className="q-answer__text">{r.card.response.text ?? t("conv.td.actionDone")}</p> : null}
        </details>
      ))}
      {ended && (
        <div className="stack stack--2">
          <button className="btn" disabled={c.busy || !c.online} onClick={async () => { await c.run("close_session"); navigate(`/bibliotheques/${c.st.session.game_id}`); }}>{t("game.replay")}</button>
          <button className="btn btn--secondary" disabled={c.busy || !c.online} onClick={async () => { await c.run("close_session"); navigate("/bibliotheques"); }}>{t("game.otherGame")}</button>
        </div>
      )}
      <Link className="btn btn--quiet" to="/accueil">{t("game.home")}</Link>
    </section>
  );
}

/** Salon : cartes +18 facultatives, désactivées par défaut ; chacun active pour soi. */
export function OptionalAdult({ st, busy, online, run }: { st: SessionState; busy: boolean; online: boolean; run: Run }) {
  const { profile } = useAuth();
  const prefs = (st as unknown as { my_prefs?: { adult: boolean; excluded_topics: string[] } }).my_prefs ?? { adult: false, excluded_topics: [] };
  return (
    <div className="group">
      <label className="switch-row">
        <span className="switch-row__text">
          <span>{t("conv.adultToggle")}</span>
          <span className="t-meta">{profile?.intimate_opt_in ? t("conv.adultToggleHint") : t("conv.adultNeedProfile")}</span>
        </span>
        <input className="switch" type="checkbox" role="switch" checked={prefs.adult} disabled={busy || !online || !profile?.intimate_opt_in}
          onChange={(e) => run("set_session_prefs", { p_adult: e.target.checked, p_excluded: prefs.excluded_topics })} />
      </label>
    </div>
  );
}
