/* eslint-disable @typescript-eslint/no-explicit-any */
// Deux vérités et un mensonge, version 2 (« Le petit théâtre ») : écriture simultanée en coulisses,
// « OK, je suis prêt », puis devinette simultanée sur scène. Le serveur ne transmet les textes de l'autre
// qu'une fois les deux prêts, et les mensonges qu'après les deux choix.
import { useEffect, useRef, useState } from "react";
import { t } from "../../i18n";
import { rpc } from "../../lib/supabase";
import { Icon } from "../../components/ui";
import type { Player, SessionState } from "../../lib/types";
import { useDraft } from "../useSession";
import { NudgeButton } from "./Nudge";

type J = any;
type Play = (type: string, p?: Record<string, unknown>) => Promise<boolean>;
const IDS = ["s1", "s2", "s3"] as const;
const nameOf = (p?: Player) => (p ? (p.is_me ? t("game.you") : p.display_name || "?") : "?");

/** Points de chacun sur les manches terminées (1 par mensonge trouvé). */
export function theatreScore(st: SessionState, seat: number) {
  return (st.rounds as unknown as { card: J }[]).reduce((n, r) => n + (r.card?.done && !r.card.skipped ? Number(r.card.scores?.[seat] ?? 0) : 0), 0);
}

function Backstage({ busy, play, sessionId, partner, draft, updateDraft }: { busy: boolean; play: Play; sessionId: string; partner?: Player; draft: string[]; updateDraft: (value: string[]) => void }) {
  const texts = IDS.map((_, i) => draft[i] ?? "");
  const lie = draft[3] || null;
  const setTexts = (next: string[]) => updateDraft([...next, lie ?? ""]);
  const setLie = (next: string | null) => updateDraft([...texts, next ?? ""]);
  const submitting = useRef(false);
  const [idea, setIdea] = useState<string | null>(null);
  const filled = texts.every((x) => x.trim());
  const distinct = new Set(texts.map((x) => x.trim().toLowerCase())).size === 3;
  const ready = filled && distinct && lie !== null;
  const why = !filled ? t("tt2.needThree") : !distinct ? t("tt2.needDistinct") : !lie ? t("tt2.needLie") : null;
  return (
    <form className="stack stack--4" onSubmit={(e) => {
      e.preventDefault();
      if (ready && !busy && !submitting.current) {
        submitting.current = true;
        void play("publish_three", { confirmed_truths: true, lie_statement_id: lie, statements: texts.map((x, i) => ({ id: IDS[i], text: x.trim() })) })
          .finally(() => { submitting.current = false; });
      }
    }}>
      <div className="stack stack--1">
        <h2 className="q-title">{t("tt2.writeTitle")}</h2>
        <p className="t-small muted">{t("tt2.writeHint")}</p>
      </div>
      <ol className="theatre-notes">
        {texts.map((x, i) => {
          const isLie = lie === IDS[i];
          return (
            <li key={i} className={`theatre-note${isLie ? " theatre-note--lie" : ""}`}>
              <div className="theatre-note__head">
                <label className="theatre-note__label" htmlFor={`tt2-${i}`}>{t("tt2.statement", { n: i + 1 })}</label>
                <button type="button" className={`theatre-tag${isLie ? " theatre-tag--lie" : ""}`} aria-pressed={isLie} disabled={busy}
                  onClick={() => setLie(isLie ? null : IDS[i])}>
                  <Icon name={isLie ? "eye-off" : "check"} size={14} />{isLie ? t("tt2.myLie") : t("tt2.truth")}
                </button>
              </div>
              <textarea id={`tt2-${i}`} className="input theatre-note__input" maxLength={240} rows={2} value={x} disabled={busy}
                onChange={(e) => setTexts(texts.map((y, k) => (k === i ? e.target.value : y)))} />
            </li>
          );
        })}
      </ol>
      <div className="stack stack--2">
        <button type="button" className="btn btn--quiet btn--sm btn--auto" disabled={busy} onClick={async () => {
          const r = await rpc<{ text: string }>("get_two_truths_idea", { p_session: sessionId });
          setIdea(r.ok ? (r as unknown as { text: string }).text : t("conv.tt.noIdea"));
        }}><Icon name="sparkles" size={16} />{t("conv.tt.idea")}</button>
        {idea && <p className="t-small card card--soft" aria-live="polite">{idea}</p>}
      </div>
      <p className="theatre-info"><Icon name="lock-keyhole" size={16} />{t("tt2.privacy", { name: nameOf(partner) })}</p>
      <button className="btn" type="submit" disabled={busy || !ready} aria-describedby={why ? "tt2-why" : undefined}>
        {t("tt2.ready")}<Icon name="check" size={18} />
      </button>
      {why && <p id="tt2-why" className="t-meta center">{why}</p>}
    </form>
  );
}

function Pair({ me, partner, done, labelDone, labelWait }: { me: Player; partner?: Player; done: (seat: number) => boolean; labelDone: string; labelWait: string }) {
  return (
    <ul className="ready-pair" aria-live="polite">
      {[me, partner].filter(Boolean).map((p) => (
        <li key={p!.seat} className={`ready-pair__item${done(p!.seat) ? " is-done" : ""}`}>
          <Icon name={done(p!.seat) ? "check" : "pencil"} size={16} />
          <span><strong>{nameOf(p)}</strong> · {done(p!.seat) ? labelDone : labelWait}</span>
        </li>
      ))}
    </ul>
  );
}

export function TwoTruthsTheatre({ st, card, priv, me, partner, busy, play }: {
  st: SessionState; card: J; priv: J; me: Player; partner?: Player; busy: boolean; play: Play;
}) {
  const [guess, setGuess] = useState<string | null>(null);
  const [draft, updateDraft, clearDraft] = useDraft(`two-truths:${me.user_id}:${st.session.id}:${st.session.current_round}`);
  useEffect(() => { if (card.phase !== "write") clearDraft(); }, [card.phase, clearDraft]);
  const meReady = Boolean(card.ready?.[me.seat]);
  const meGuessed = Boolean(card.guessed?.[me.seat]);
  const theirs: { id: string; text: string }[] = partner ? card.statements?.[partner.seat] ?? [] : [];

  if (card.phase === "write" && !meReady) return <Backstage busy={busy} play={play} sessionId={st.session.id} partner={partner} draft={draft} updateDraft={updateDraft} />;

  if (card.phase === "write") {
    return (
      <div className="stack stack--4">
        <h2 className="q-title">{t("tt2.waitTitle")}</h2>
        <Pair me={me} partner={partner} done={(s) => Boolean(card.ready?.[s])} labelDone={t("tt2.isReady")} labelWait={t("tt2.isWriting")} />
        <ol className="theatre-cards theatre-cards--mine">
          {(priv?.statements ?? []).map((s: J) => (
            <li key={s.id} className="theatre-card">
              <span className="grow">{s.text}</span>
              <span className={`theatre-tag${priv?.lie === s.id ? " theatre-tag--lie" : ""}`}>{priv?.lie === s.id ? t("tt2.myLie") : t("tt2.truth")}</span>
            </li>
          ))}
        </ol>
        <NudgeButton st={st} partner={partner} />
        <button className="btn btn--quiet" disabled={busy} onClick={() => void play("unready")}>{t("tt2.edit")}</button>
      </div>
    );
  }

  // Devinette : trois cartes de l'autre, sur scène.
  return (
    <div className="stack stack--4">
      <div className="stack stack--1">
        <h2 className="q-title">{t("tt2.guessTitle", { name: nameOf(partner) })}</h2>
        <p className="t-small muted">{t("tt2.guessHint")}</p>
      </div>
      <div className="theatre-scene" role="radiogroup" aria-label={t("conv.tt.whichLie")}>
        {theirs.map((s, i) => (
          <button key={s.id} type="button" role="radio" aria-checked={guess === s.id} className={`theatre-card theatre-card--pick${guess === s.id ? " is-picked" : ""}`}
            disabled={busy || meGuessed} onClick={() => setGuess(s.id)} style={{ animationDelay: `${i * 60}ms` }}>
            <span className="theatre-card__n" aria-hidden="true">{i + 1}</span>
            <span className="grow">{s.text}</span>
          </button>
        ))}
      </div>
      {meGuessed ? (
        <>
          <Pair me={me} partner={partner} done={(s) => Boolean(card.guessed?.[s])} labelDone={t("tt2.hasChosen")} labelWait={t("tt2.isChoosing")} />
          <NudgeButton st={st} partner={partner} />
        </>
      ) : (
        <button className="btn" disabled={busy || !guess} onClick={() => guess && void play("lock_guess", { statement_id: guess })}>
          {t("tt2.lockGuess")}<Icon name="check" size={18} />
        </button>
      )}
    </div>
  );
}

/** Révélation : les deux jeux de cartes, tampon Vrai / Mensonge, et le choix de l'autre. */
export function TwoTruthsReveal({ st, card, me, partner }: { st: SessionState; card: J; me: Player; partner?: Player }) {
  const total = st.session.total_rounds;
  const side = (author?: Player, guesser?: Player) => {
    if (!author) return null;
    const list: { id: string; text: string }[] = card.statements?.[author.seat] ?? [];
    const lie = card.lies?.[author.seat];
    const g = guesser ? card.guesses?.[guesser.seat] : undefined;
    const found = guesser ? Boolean(card.found?.[guesser.seat]) : false;
    return (
      <section className="stack stack--2" aria-label={t("tt2.cardsOf", { name: nameOf(author) })}>
        <h3 className="t-meta strong">{author.is_me ? t("tt2.yourCards") : t("tt2.cardsOf", { name: nameOf(author) })}</h3>
        <ol className="theatre-cards">
          {list.map((s) => (
            <li key={s.id} className={`theatre-card theatre-card--reveal${s.id === lie ? " is-lie" : ""}`}>
              <span className="grow">{s.text}</span>
              <span className={`theatre-stamp${s.id === lie ? " theatre-stamp--lie" : ""}`}>{s.id === lie ? t("tt2.stampLie") : t("tt2.stampTrue")}</span>
              {s.id === g && <span className="theatre-guess"><Icon name="eye" size={14} />{guesser?.is_me ? t("tt2.yourGuess") : t("tt2.guessedBy", { name: nameOf(guesser) })}</span>}
            </li>
          ))}
        </ol>
        <p className={`t-small strong ${found ? "is-success" : ""}`}>
          {guesser?.is_me ? (found ? t("tt2.foundMe") : t("tt2.missedMe")) : found ? t("tt2.found", { name: nameOf(guesser) }) : t("tt2.missed", { name: nameOf(guesser) })}
        </p>
      </section>
    );
  };
  return (
    <div className="stack stack--4">
      {side(partner, me)}
      {side(me, partner)}
      <p className="theatre-score">
        <span>{t("game.you")} <strong>{theatreScore(st, me.seat)}/{total}</strong></span>
        {partner && <span>{nameOf(partner)} <strong>{theatreScore(st, partner.seat)}/{total}</strong></span>}
      </p>
    </div>
  );
}
