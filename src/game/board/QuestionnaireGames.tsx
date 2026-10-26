/* eslint-disable @typescript-eslint/no-explicit-any */
// Packs de questions (C01) et questionnaires (C02) : textes, ordre, échelles et calculs viennent du serveur.
// L'écran n'affiche jamais une réponse du partenaire avant la révélation : il ne la reçoit pas.
import { AudioAnswer, AudioPlayback } from "../audio/AudioAnswer";
import { LaterButton } from "../Later";
import { IntensityTransition, useSessionMeta } from "../../parcours/meta";
import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router";
import { t } from "../../i18n";
import { Alert, Art, Icon, Loading } from "../../components/ui";
import type { Player, SessionState } from "../../lib/types";
import { NudgeButton } from "../premium/Nudge";
import { ReadingRegion } from "../ReadingRegion";

type J = any;
type Run = (fn: string, args?: Record<string, unknown>) => Promise<{ ok: boolean; error?: string; info?: any }>;
interface Common { st: SessionState; run: Run; busy: boolean; online: boolean }
interface QRound { round_no: number; card: J; revealed: boolean; private: J }

export const isQuestionnaireMech = (m?: string) => m === "pack_conversation" || m === "test_form";
const roundsOf = (st: SessionState) => st.rounds as unknown as QRound[];
const nameOf = (p?: Player) => (p ? (p.is_me ? t("game.you") : p.display_name || "?") : "?");
const MAX_TEXT = 500;

function moveError(code?: string) {
  const known = ["empty_answer", "invalid_text", "invalid_option", "already_submitted", "adult_consent_required"];
  return code && known.includes(code) ? t(`q.err.${code}` as never) : t("q.err.generic");
}

// ---------------------------------------------------------------------------
// Packs de questions
// ---------------------------------------------------------------------------
type PackAnswer = { choice: "share" | "private" | "pass"; text?: string; value?: number; audio_id?: string; expires_at?: string } | null;

function optionLabel(card: J, value: number | undefined) {
  if (value === undefined || value === null) return null;
  return (card.item.options ?? []).find((o: J) => o.value === value)?.label_fr ?? String(value);
}

/** Réponse affichée après la révélation : contenu seulement s'il a été partagé. */
function AnswerView({ card, a, mine }: { card: J; a: PackAnswer; mine?: PackAnswer }) {
  if (!a) return <p className="t-meta">{t("q.pack.noAnswer")}</p>;
  if (a.choice === "pass") return <p className="t-meta">{t("q.pack.passed")}</p>;
  // Ma propre réponse gardée pour moi : je la relis (elle vient de ma part privée), l'autre ne la voit pas.
  const shown = a.choice === "share" ? a : mine && mine.choice !== "pass" ? mine : null;
  if (!shown || (shown.text === undefined && shown.value === undefined)) return <p className="t-meta">{t("q.pack.keptPrivate")}</p>;
  return (
    <div className="stack stack--2">
      {shown.value !== undefined && <p className="strong">{optionLabel(card, shown.value)}</p>}
      {shown.audio_id && shown.expires_at ? <AudioPlayback key={shown.audio_id} id={shown.audio_id} expiresAt={shown.expires_at} /> : shown.text && <p className="q-answer__text">{shown.text}</p>}
      {a.choice !== "share" && <p className="t-meta row"><Icon name="lock-keyhole" size={16} />{t("q.pack.onlyYou")}</p>}
    </div>
  );
}

function PackRevealed({ c, round, me, partner }: { c: Common; round: QRound; me: Player; partner?: Player }) {
  const card = round.card;
  const mineSecret = (round.private?.answer ?? null) as PackAnswer;
  const minePublic = (card.answers?.[me.seat] ?? null) as PackAnswer;
  const canShare = mineSecret && mineSecret.choice !== "pass" && (mineSecret.text !== undefined || mineSecret.value !== undefined);
  const shared = minePublic?.choice === "share";
  return (
    <div className="stack stack--3 enter" aria-live="polite">
      {[me, partner].filter(Boolean).map((p) => (
        <section key={p!.seat} className={`q-answer${p!.is_me ? " q-answer--me" : ""}`} aria-label={t("q.pack.answerOf", { name: nameOf(p) })}>
          <h3 className="t-meta strong">{nameOf(p)}</h3>
          <AnswerView card={card} a={(card.answers?.[p!.seat] ?? null) as PackAnswer} mine={p!.is_me ? mineSecret : undefined} />
        </section>
      ))}
      {canShare && !c.st.session.read_only && (
        <button className="btn btn--secondary btn--sm" disabled={c.busy || !c.online}
          onClick={() => c.run("set_answer_shared", { p_round: round.round_no, p_share: !shared })}>
          <Icon name={shared ? "eye-off" : "eye"} size={18} />{shared ? t("q.pack.unshare") : t("q.pack.share")}
        </button>
      )}
    </div>
  );
}

function PackForm({ card, busy, onSend, sessionId, round }: { card: J; busy: boolean; sessionId: string; round: number; onSend: (p: Record<string, unknown>) => Promise<boolean> }) {
  const [audioBusy, setAudioBusy] = useState(false);
  const blocked = busy || audioBusy;
  const tf = card.item.response === "true_false" || (card.item.options ?? []).length > 0;
  const [text, setText] = useState("");
  const [value, setValue] = useState<number | null>(null);
  const has = Boolean(text.trim()) || value !== null;
  const payload = (choice: string) => ({ choice, ...(text.trim() ? { text: text.trim() } : {}), ...(value !== null ? { value } : {}) });
  return (
    <form className="pack-answer-form stack stack--4" onSubmit={(e) => { e.preventDefault(); if (has && !blocked) void onSend(payload("share")); }}>
      <div className="pack-answer-form__content stack stack--4">
      {tf && (
        <div className="q-choices" role="radiogroup" aria-label={t("q.pack.yourAnswer")}>
          {(card.item.options ?? []).map((o: J) => (
            <button key={o.value} type="button" role="radio" aria-checked={value === o.value} className="q-choice" disabled={blocked}
              onClick={() => setValue(value === o.value ? null : o.value)}>
              <span className="q-choice__dot" aria-hidden="true" /><span className="q-choice__label">{o.label_fr}</span>
            </button>
          ))}
        </div>
      )}
      <div className="field pack-answer-paper">
        <div className="pack-answer-paper__heading">
          <label className="field__label" htmlFor="q-text">{tf ? t("q.pack.comment") : t("q.pack.yourAnswer")}</label>
          <Icon name="pencil" size={18} />
        </div>
        <textarea id="q-text" className="input q-textarea" maxLength={MAX_TEXT} value={text} disabled={blocked}
          rows={4} aria-describedby="q-text-hint" onChange={(e) => setText(e.target.value)} placeholder={tf ? "" : t("q.pack.placeholder")} />
        <span id="q-text-hint" className="field__hint">{t("q.pack.hint", { n: MAX_TEXT - text.length })}</span>
      </div>
      {!tf && <AudioAnswer key={`${sessionId}:${round}`} sessionId={sessionId} round={round} disabled={busy} onSend={onSend} onBusy={setAudioBusy} />}
      </div>
      <div className="pack-answer-form__actions stack stack--2">
        <button className="btn" type="submit" disabled={blocked || !has}><Icon name="send" size={18} />{t("q.pack.sendShare")}</button>
        <button className="btn btn--secondary" type="button" disabled={blocked || !has} onClick={() => void onSend(payload("private"))}>
          <Icon name="lock-keyhole" size={18} />{t("q.pack.sendPrivate")}
        </button>
        <button className="btn btn--quiet" type="button" disabled={blocked} onClick={() => void onSend({ choice: "pass" })}>{t("q.pack.pass")}</button>
      </div>
    </form>
  );
}

function PackPlaying({ c, round }: { c: Common; round: QRound }) {
  const [err, setErr] = useState<string | null>(null);
  const card = round.card;
  const me = c.st.players.find((p) => p.is_me)!;
  const partner = c.st.players.find((p) => !p.is_me);
  const total = c.st.session.total_rounds;
  const first = c.st.players.find((p) => p.seat === card.first);
  const iAnswered = Boolean(card.status?.[me.seat]);
  const theyAnswered = Boolean(partner && card.status?.[partner.seat]);
  useEffect(() => setErr(null), [round.round_no]);
  const meta = useSessionMeta(c.st.session.id, round.round_no);
  const prevItem = (c.st.rounds as unknown as QRound[]).find((r) => r.round_no === round.round_no - 1)?.card?.item?.id;

  async function send(payload: Record<string, unknown>) {
    setErr(null);
    const res = await c.run("play_move", { p_round: round.round_no, p_action: crypto.randomUUID(), p_type: "answer", p_payload: payload });
    if (!res.ok && res.error !== "busy" && res.error !== "stale_round") setErr(moveError(res.error));
    return res.ok;
  }

  return (
    <section className="pack-playing pack-board reading-games stack stack--5" key={round.round_no}>
      {/* V7 : une seule progression, celle du cadre de jeu (Manche i/N) ; plus de doublon Carte / Série / Séance. */}
      <IntensityTransition prev={prevItem ? meta[prevItem] : undefined} cur={meta[card.item.id]} />
      <ReadingRegion className="console-question pack-question" label="Question du pack" resetKey={card.item.id}>
        <div className="q-card__head">
          <span className="pack-question__meta row row--wrap">
            {card.item.adult && <span className="nd-chip nd-chip--peach">+18</span>}
            <span className="nd-chip">{card.set_no ? t("q.pack.setChip", { s: card.set_no }) : t("q.pack.cardChip", { n: card.index + 1 })}</span>
          </span>
          <img className="pack-question__object" src="/assets/original/library3d/G05.webp" width={72} height={72} alt="" aria-hidden="true" />
        </div>
        <h2 className={`t-question${card.item.text.length > 140 ? " t-question--long" : ""}`}>{card.item.text}</h2>
        <p className="t-meta">{first?.is_me ? t("q.pack.youFirst") : t("q.pack.firstSpeaker", { name: nameOf(first) })}</p>
        {!c.st.session.read_only && <LaterButton sessionId={c.st.session.id} round={round.round_no} disabled={!c.online} />}
      </ReadingRegion>

      {card.done ? (
        <PackRevealed c={c} round={round} me={me} partner={partner} />
      ) : iAnswered ? (
        <div className="card stack stack--2 center" aria-live="polite">
          <span className="nd-chip"><Icon name="lock-keyhole" size={16} />{t("q.pack.sealed")}</span>
          <p>{theyAnswered ? t("q.pack.bothDone") : t("q.pack.waiting", { name: nameOf(partner) })}</p>
          {!theyAnswered && <NudgeButton st={c.st} partner={partner} />}
        </div>
      ) : (
        <>
          {theyAnswered && <p className="t-meta row"><Icon name="check" size={16} />{t("q.pack.partnerDone", { name: nameOf(partner) })}</p>}
          <PackForm key={round.round_no} sessionId={c.st.session.id} round={round.round_no} card={card} busy={c.busy || !c.online} onSend={send} />
        </>
      )}
      {err && <Alert>{err}</Alert>}

      {card.done && (
        <div className="action-bar stack stack--2">
          {round.round_no < total && (
            <button className="btn" disabled={c.busy || !c.online} onClick={() => c.run("next_round", { p_from_round: round.round_no })}>
              {t("q.pack.next")}<Icon name="arrow-right" />
            </button>
          )}
          {round.round_no < total && (
            <button className="btn btn--secondary" disabled={c.busy || !c.online} onClick={() => c.run("end_pack_session")}>{t("q.pack.stopHere")}</button>
          )}
        </div>
      )}
    </section>
  );
}

function PackResults({ c }: { c: Common }) {
  const me = c.st.players.find((p) => p.is_me)!;
  const partner = c.st.players.find((p) => !p.is_me);
  const rounds = roundsOf(c.st).filter((r) => r.card?.done);
  return (
    <div className="stack stack--3">
      <p className="t-small muted">{t("q.pack.endText", { n: rounds.length })}</p>
      {rounds.map((r) => (
        <details key={r.round_no} className="card">
          <summary className="strong">{r.card.item.text}</summary>
          <PackRevealed c={c} round={r} me={me} partner={partner} />
        </details>
      ))}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Questionnaires
// ---------------------------------------------------------------------------
type Answers = Record<string, number | boolean | null>;

function ScaleItem({ item, scale, value, onChange, disabled }: {
  item: J; scale: J[]; value: number | null | undefined; onChange: (v: number | null) => void; disabled: boolean;
}) {
  const id = `it-${item.id}`;
  return (
    <fieldset className="q-item q-item--scale" aria-describedby={item.note ? `${id}-note` : undefined}>
      <legend className="q-item__text"><span className="q-item__no">{item.position}.</span> {item.text}</legend>
      {item.note && <p id={`${id}-note`} className="t-meta row"><Icon name="info" size={16} />{item.note}</p>}
      <div className={`q-scale${scale.length > 5 ? " q-scale--long" : ""}`} role="radiogroup" aria-label={item.text} data-scale-count={scale.length}>
        {scale.map((o) => (
          <button key={o.value} type="button" role="radio" aria-checked={value === o.value} className="q-choice" disabled={disabled}
            onClick={() => onChange(o.value)}>
            <span className="q-choice__dot" aria-hidden="true" /><span className="q-choice__label">{o.label_fr}</span>
          </button>
        ))}
        <button type="button" role="radio" aria-checked={value === null} className="q-choice q-choice--pass" disabled={disabled}
          onClick={() => onChange(null)}>{t("q.test.pass")}</button>
      </div>
    </fieldset>
  );
}

function CheckItem({ item, value, onChange, disabled }: { item: J; value: boolean | null | undefined; onChange: (v: boolean | null) => void; disabled: boolean }) {
  const id = `it-${item.id}`;
  return (
    <div className="q-check q-item--checkbox">
      <label className="q-check__row" htmlFor={id}>
        <input id={id} type="checkbox" checked={value === true} disabled={disabled} onChange={(e) => onChange(e.target.checked)} />
        <span><span className="q-item__no">{item.position}.</span> {item.text}</span>
      </label>
      {item.note && (
        <div className="stack stack--2">
          <p className="t-meta row"><Icon name="info" size={16} />{item.note}</p>
          <button type="button" className="chip" aria-pressed={value === null} disabled={disabled} onClick={() => onChange(value === null ? false : null)}>{t("q.test.pass")}</button>
        </div>
      )}
    </div>
  );
}

/** Test de pureté : score avec son dénominateur (indice sur 100, Non sur 72). */
function PurityScore({ scores, total }: { scores: Record<string, number>; total: number }) {
  return (
    <div className="purity-score">
      <p className="purity-score__main"><strong>{scores.indice}</strong>/100</p>
      <p className="t-small">{t("q.purity.nonOf", { n: scores.non, total })}</p>
      <p className="t-meta">Indice adapté : nombre de « Non » ÷ {total} × 100, arrondi. Ce questionnaire n’est pas un test scientifique validé.</p>
    </div>
  );
}

/** Réponses montrées au clic final (test de pureté) : liste repliable, Oui/Non par question. */
function SharedAnswers({ card, answers, who }: { card: J; answers: Record<string, number | null>; who: string }) {
  const items: J[] = card.items ?? [];
  return (
    <details className="disclosure">
      <summary>{t("q.purity.seeAnswers", { name: who })}<Icon name="chevron-down" /></summary>
      <ol className="purity-answers">
        {items.map((it) => {
          const v = answers[it.id];
          return (
            <li key={it.id}>
              <span className="grow">{it.text}</span>
              <span className={`purity-answer${v === 1 ? " is-yes" : v === 0 ? " is-no" : ""}`}>{v === 1 ? t("q.purity.yes") : v === 0 ? t("q.purity.no") : t("q.purity.skipped")}</span>
            </li>
          );
        })}
      </ol>
    </details>
  );
}

function Scores({ card, scores }: { card: J; scores: Record<string, number> }) {
  if (card.instrument === "PURETE72" || (scores && "indice" in scores && "non" in scores)) return <PurityScore scores={scores} total={card.count ?? 72} />;
  return (
    <dl className="q-scores">
      {Object.entries(scores).map(([k, v]) => (
        <div key={k} className="q-scores__row">
          <dt>{card.axes?.[k] ?? k}</dt>
          <dd className="t-score">{Number.isInteger(v) ? v : v.toFixed(2).replace(".", ",")}</dd>
        </div>
      ))}
    </dl>
  );
}

function TestDone({ c, round }: { c: Common; round: QRound }) {
  const card = round.card;
  const me = c.st.players.find((p) => p.is_me)!;
  const partner = c.st.players.find((p) => !p.is_me);
  const result = round.private?.result;
  const declined = Boolean(card.declined?.[me.seat]);
  const shared = Boolean(card.shared?.[me.seat]);
  const theirs = partner ? card.shared?.[partner.seat] : null;
  // Questionnaire sans calcul (test de pureté allégé) : rien à partager, seules les réponses privées existent.
  const noScore = Object.keys(card.axes ?? {}).length === 0;
  if (noScore) {
    return (
      <div className="reading-games stack stack--4 enter" aria-live="polite">
        <section className="card stack stack--3">
          <div className="q-result-head">
            <Art name="result-private" size={96} />
            <h2 className="t-section">{declined ? t("q.test.youDeclined") : t("q.test.noScoreTitle")}</h2>
            <p className="t-meta row"><Icon name="lock-keyhole" size={16} />{t("q.test.noScoreText")}</p>
          </div>
          {(card.reserves ?? []).map((r: string) => <p key={r} className="t-meta row"><Icon name="info" size={16} />{r}</p>)}
        </section>
        <p className="t-meta">{partner && (card.completed?.[partner.seat] || card.declined?.[partner.seat]) ? t("q.test.partnerFinished", { name: nameOf(partner) }) : t("q.test.partnerInProgress")}</p>
      </div>
    );
  }
  return (
    <div className="reading-games stack stack--4 enter" aria-live="polite">
      <section className="card stack stack--3">
        <div className="q-result-head">
          <Art name="result-private" size={96} />
          <h2 className="t-section">{t("q.test.yourResult")}</h2>
          <p className="t-meta row"><Icon name="lock-keyhole" size={16} />{shared ? t("q.test.sharedWith", { name: nameOf(partner) }) : t("q.test.onlyYou")}</p>
        </div>
        {declined ? <p>{t("q.test.youDeclined")}</p>
          : result?.status === "complete" ? <Scores card={card} scores={result.scores} />
          : <p>{t("q.test.incomplete", { n: result?.answered ?? 0, total: result?.total ?? card.count })}</p>}
        {(card.reserves ?? []).map((r: string) => <p key={r} className="t-meta row"><Icon name="info" size={16} />{r}</p>)}
        <p className="t-meta">{t("q.test.noDiagnosis")}</p>
        {result?.status === "complete" && !c.st.session.read_only && (
          <label className="switch-row" style={{ padding: 0 }}>
            <span className="switch-row__text"><span>{t("q.test.shareResult", { name: nameOf(partner) })}</span>
              <span className="t-meta">{(c.st.game.config as unknown as { test?: { share_answers?: boolean } }).test?.share_answers ? t("q.purity.shareHintAfter") : t("q.test.shareHint")}</span></span>
            <input className="switch" type="checkbox" role="switch" checked={shared} disabled={c.busy || !c.online}
              onChange={(e) => c.run("set_answer_shared", { p_round: round.round_no, p_share: e.target.checked })} />
          </label>
        )}
      </section>
      <section className="card stack stack--3">
        <h2 className="t-section">{t("q.test.partnerResult", { name: nameOf(partner) })}</h2>
        {theirs ? <><Scores card={card} scores={theirs} />{theirs.answers && <SharedAnswers card={card} answers={theirs.answers} who={nameOf(partner)} />}</>
          : partner && card.declined?.[partner.seat] ? <p className="muted">{t("q.test.partnerDeclined")}</p>
          : partner && card.completed?.[partner.seat] ? <p className="muted">{t("q.test.partnerPrivate")}</p>
          : <><p className="muted">{t("q.test.partnerInProgress")}</p>{c.st.session.status === "playing" && <NudgeButton st={c.st} partner={partner} />}</>}
      </section>
    </div>
  );
}

function TestPlaying({ c, round }: { c: Common; round: QRound }) {
  const card = round.card;
  const me = c.st.players.find((p) => p.is_me)!;
  const items: J[] = card.items ?? [];
  const size: number = card.page_size ?? 5;
  const pages = Math.max(1, Math.ceil(items.length / size));
  const [answers, setAnswers] = useState<Answers>(() => ({ ...(round.private?.answers ?? {}) }));
  const [page, setPage] = useState<number>(() => Math.min(pages - 1, Number(round.private?.page ?? 0)));
  const testCfg = (c.st.game.config as unknown as { test?: { share_default?: boolean; share_answers?: boolean } }).test ?? {};
  const [share, setShare] = useState(Boolean(testCfg.share_default));
  const [err, setErr] = useState<string | null>(null);
  const done = Boolean(card.completed?.[me.seat] || card.declined?.[me.seat]);
  const slice = useMemo(() => items.slice(page * size, page * size + size), [items, page, size]);
  const checkbox = card.input === "checkbox";

  // Case non cochée = expérience non déclarée (faux) ; seule l'action « Passer » laisse un item sans réponse.
  const pageAnswers = () => Object.fromEntries(slice.map((it) => {
    const v = answers[it.id];
    return [it.id, v === undefined ? (checkbox ? false : null) : v];
  }));

  async function play(type: string, payload: Record<string, unknown>) {
    setErr(null);
    const res = await c.run("play_move", { p_round: round.round_no, p_action: crypto.randomUUID(), p_type: type, p_payload: payload });
    if (!res.ok && res.error !== "busy" && res.error !== "stale_round") setErr(moveError(res.error));
    return res.ok;
  }

  if (done) return <TestDone c={c} round={round} />;
  const answeredCount = items.filter((it) => answers[it.id] !== undefined && answers[it.id] !== null).length;
  const last = page === pages - 1;
  const set = (id: string, v: number | boolean | null) => setAnswers((a) => ({ ...a, [id]: v }));
  const busy = c.busy || !c.online;

  return (
    <section className="questionnaire-playing questionnaire-sheet reading-games stack stack--5">
      <div className="q-progress">
        <span className="t-meta">{t("q.test.page", { n: page + 1, total: pages })}</span>
        <span className="t-meta">{t("q.test.answered", { n: answeredCount, total: items.length })}</span>
      </div>
      <div className="nd-progress" role="progressbar" aria-label={t("q.test.progress")} aria-valuemin={0} aria-valuemax={pages} aria-valuenow={page + 1}>
        <div className="nd-progress__fill" style={{ width: `${(100 * (page + 1)) / pages}%` }} />
      </div>
      {page === 0 && c.st.game.rules.details?.[0] && <p className="questionnaire-intro card card--soft">{c.st.game.rules.details[0]}</p>}
      <div className="questionnaire-items stack stack--4">
        {slice.map((it) => checkbox
          ? <CheckItem key={it.id} item={it} value={answers[it.id] as boolean | null | undefined} onChange={(v) => set(it.id, v)} disabled={busy} />
          : <ScaleItem key={it.id} item={it} scale={card.scales?.[it.scale] ?? []} value={answers[it.id] as number | null | undefined} onChange={(v) => set(it.id, v)} disabled={busy} />)}
      </div>
      {err && <Alert>{err}</Alert>}
      {last && Object.keys(card.axes ?? {}).length > 0 && (
        <label className="switch-row card" style={{ paddingInline: 12 }}>
          <span className="switch-row__text">
            <span>{testCfg.share_answers ? t("q.purity.showOnFinish") : t("q.test.shareOnFinish")}</span>
            <span className="t-meta">{testCfg.share_answers ? t("q.purity.showHint", { name: nameOf(c.st.players.find((p) => !p.is_me)) }) : t("q.test.shareHint")}</span>
          </span>
          <input className="switch" type="checkbox" role="switch" checked={share} onChange={(e) => setShare(e.target.checked)} />
        </label>
      )}
      <div className="questionnaire-actions action-bar stack stack--2">
        {last ? (
          <button className="btn" disabled={busy} onClick={() => void play("complete", { answers: pageAnswers(), page, share })}>
            {Object.keys(card.axes ?? {}).length === 0 ? t("q.test.finish") : share ? t("q.test.finishShare") : t("q.test.finishPrivate")}
          </button>
        ) : (
          <button className="btn" disabled={busy} onClick={async () => {
            const a = pageAnswers();
            if (await play("save", { answers: a, page: page + 1 })) { setAnswers((x) => ({ ...x, ...a })); setPage(page + 1); window.scrollTo(0, 0); }
          }}>{t("q.test.nextPage")}<Icon name="arrow-right" /></button>
        )}
        {page > 0 && <button className="btn btn--secondary" disabled={busy} onClick={() => { setPage(page - 1); window.scrollTo(0, 0); }}>{t("q.test.prevPage")}</button>}
        <button className="btn btn--quiet" disabled={busy} onClick={() => void play("decline", {})}>{t("q.test.decline")}</button>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Points d'entrée
// ---------------------------------------------------------------------------
export function QuestionnairePlaying({ c }: { c: Common }) {
  const round = roundsOf(c.st).find((r) => r.round_no === c.st.session.current_round);
  if (!round) return <Loading />;
  return round.card.mech === "pack_conversation" ? <PackPlaying c={c} round={round} /> : <TestPlaying key={round.round_no} c={c} round={round} />;
}

export function QuestionnaireResults({ c, navigate }: { c: Common; navigate: (to: string) => void }) {
  const round = roundsOf(c.st)[0];
  const ended = c.st.session.status === "ended" && !c.st.session.read_only;
  const pack = round?.card?.mech === "pack_conversation";
  return (
    <section className="reading-games stack stack--5">
      <div className="page-header">
        <h1 className="t-page">{pack ? t("q.pack.endTitle") : t("q.test.endTitle")}</h1>
        <p className="t-small muted">{c.st.game.title}</p>
      </div>
      {round && (pack ? <PackResults c={c} /> : <TestDone c={c} round={round} />)}
      {ended && (
        <div className="stack stack--2">
          <button className="btn" disabled={c.busy || !c.online} onClick={async () => { if ((await c.run("close_session")).ok) navigate(`/bibliotheques/${c.st.session.game_id}`); }}>
            {pack ? t("q.pack.continueLater") : t("game.replay")}
          </button>
          <button className="btn btn--secondary" disabled={c.busy || !c.online} onClick={async () => { if ((await c.run("close_session")).ok) navigate("/bibliotheques"); }}>{t("game.otherGame")}</button>
        </div>
      )}
      <Link className="btn btn--quiet" to="/accueil">{t("game.home")}</Link>
    </section>
  );
}
