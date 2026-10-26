/* eslint-disable @typescript-eslint/no-explicit-any */
// Kit rouge : Action ou vérité (sans saisie) et Deux vérités et un mensonge (tour par tour).
// Le serveur reste autoritaire : l'auteur, l'acteur, la phase et le mensonge ne sont jamais déduits ici ;
// le devineur ne reçoit les trois textes qu'après verrouillage, et le mensonge qu'à la révélation.
import { useState } from "react";
import { t } from "../../i18n";
import { rpc } from "../../lib/supabase";
import { Alert, Icon } from "../../components/ui";
import type { Player, SessionState } from "../../lib/types";
import { NudgeButton } from "../premium/Nudge";
import { LaterButton } from "../Later";
import { redIllustration } from "./kit";
import { ChoiceCard, GameActions, GameHero, QuestionCard, ReadyStatus } from "./ui";

type J = any;
type Play = (type: string, payload?: Record<string, unknown>) => Promise<boolean>;
type After = (type: string, payload?: Record<string, unknown>) => Promise<boolean>;
const nameOf = (p?: Player) => (p ? (p.is_me ? t("game.you") : p.display_name || "?") : "?");

/** Fin de manche : chacun confirme ; la manche suivante commence quand les deux ont continué. */
export function ContinueBar({ st, card, me, partner, busy, after, last }: { st: SessionState; card: J; me: Player; partner?: Player; busy: boolean; after: After; last: boolean }) {
  const continued = Boolean(card.continue?.[me.seat]);
  const theyContinued = Boolean(partner && card.continue?.[partner.seat]);
  return (
    <GameActions note={theyContinued && !continued ? t("conv.partnerContinued", { name: nameOf(partner) }) : undefined}>
      <button type="button" className="red-btn" disabled={busy || continued} onClick={() => void after("continue")}>
        {continued ? t("conv.waitingContinue", { name: nameOf(partner) }) : last ? t("conv.finish") : t("conv.continue")}
        {!continued && <Icon name="arrow-right" size={20} />}
      </button>
      {continued && !theyContinued && <NudgeButton st={st} partner={partner} />}
    </GameActions>
  );
}

// ---------------------------------------------------------------------------------------------------------------
// G01 Action ou vérité : réponse orale, « C'est répondu » / « C'est fait ». Aucun champ, aucun envoi de texte.
// ---------------------------------------------------------------------------------------------------------------
export function TruthDareRed({ st, round, card, me, partner, busy, play, after, err }: {
  st: SessionState; round: { round_no: number }; card: J; me: Player; partner?: Player; busy: boolean; play: Play; after: After; err: string | null;
}) {
  const active = card.active === me.seat;
  const actor = st.players.find((p) => p.seat === card.active);
  const kind: "truth" | "dare" | undefined = card.kind;
  const last = round.round_no >= st.session.total_rounds;

  if (card.done) {
    const legacyText = card.response?.text;
    return (
      <section className="red-play red-td red-reveal" data-phase="reveal">
        {card.skipped ? <ReadyStatus icon="skip" tone="info">{t("conv.skipped")}</ReadyStatus> : card.redacted ? <Alert kind="info">{t("conv.interrupted")}</Alert> : (
          <QuestionCard tone="paper" kicker={kind === "dare" ? "Action" : "Vérité"}
            chips={<span className="red-chip red-chip--ok"><Icon name="circle-check" size={16} />{kind === "dare" ? "C’est fait" : "C’est répondu"}</span>}>
            {card.text && <p className="red-question red-question--center">{card.text}</p>}
            <p className="red-td__by">{actor?.is_me ? "Ta carte" : `Carte de ${nameOf(actor)}`}</p>
            {legacyText && <p className="red-td__legacy">{legacyText}</p>}
          </QuestionCard>
        )}
        {err && <Alert>{err}</Alert>}
        <ContinueBar st={st} card={card} me={me} partner={partner} busy={busy} after={after} last={last} />
      </section>
    );
  }

  if (card.phase === "choice") {
    return (
      <section className="red-play red-td" data-phase="choice">
        {active ? (
          <>
            <GameHero hero="cartes_action_verite" size="sm" eager />
            <div className="red-td__intro">
              <h2 className="red-question red-question--center">Choisis ta carte</h2>
              <p className="red-td__sub">Elle est tirée après ton choix.</p>
            </div>
            <div className="red-grid2 red-td__choices" aria-label="Choisir Action ou Vérité">
              <ChoiceCard role="button" tone="red" disabled={busy} onSelect={() => void play("choose_kind", { kind: "dare" })}
                label={<><Icon name="lightning" size={44} /><span className="red-td__kind">Action</span></>} hint="Un défi à vivre" />
              <ChoiceCard role="button" tone="cream" disabled={busy} onSelect={() => void play("choose_kind", { kind: "truth" })}
                label={<><Icon name="heart" size={44} /><span className="red-td__kind">Vérité</span></>} hint="Une réponse à voix haute" />
            </div>
          </>
        ) : (
          <>
            <GameHero hero="cartes_action_verite" />
            <ReadyStatus>{t("conv.td.waitChoice", { name: nameOf(partner) })}</ReadyStatus>
            <NudgeButton st={st} partner={partner} />
          </>
        )}
        {err && <Alert>{err}</Alert>}
        <GameActions note="Tu peux refuser ou passer, sans pénalité.">
          <button type="button" className="red-btn red-btn--quiet" disabled={busy} onClick={() => void play("skip_round")}>
            {active ? "Passer mon tour" : "Passer cette manche"}
          </button>
        </GameActions>
      </section>
    );
  }

  // Carte tirée : l'acteur répond ou réalise l'action dans l'appel ; l'autre observe.
  return (
    <section className="red-play red-td" data-phase="respond">
      <div className="red-td__tabs" role="group" aria-label="Type de carte">
        <span className={`red-td__tab${kind === "truth" ? " is-on" : ""}`}><Icon name="heart" size={18} />Vérité</span>
        <span className={`red-td__tab${kind === "dare" ? " is-on" : ""}`}><Icon name="lightning" size={18} />Action</span>
      </div>
      <QuestionCard tone="paper" kicker={card.theme} chips={card.adult ? <span className="red-chip">{t("conv.adultChip")}</span> : undefined}>
        {card.redacted ? <p className="muted">{t("conv.redacted")}</p> : <p className="red-question red-question--center">{card.text}</p>}
      </QuestionCard>
      {active
        ? <p className="red-td__how">{kind === "dare" ? "Réalise l’action dans votre appel. Aucune preuve n’est demandée." : "Réponds à voix haute, dans votre appel ou votre conversation."}</p>
        : <ReadyStatus icon="users">{kind === "dare" ? `${nameOf(partner)} réalise son action…` : `${nameOf(partner)} te répond à voix haute…`}</ReadyStatus>}
      {err && <Alert>{err}</Alert>}
      <GameActions note="Tu peux refuser ou passer, sans pénalité.">
        {active && (
          <>
            <div className="red-row2">
              <button type="button" className="red-btn red-btn--secondary" disabled={busy} onClick={() => void play("replace_card")}><Icon name="refresh" size={18} />{t("conv.td.replace")}</button>
              <button type="button" className="red-btn red-btn--secondary" disabled={busy} onClick={() => void play("skip_round")}><Icon name="skip" size={18} />Passer</button>
            </div>
            <button type="button" className="red-btn" disabled={busy} onClick={() => void play("mark_done")}>
              <Icon name="circle-check" size={20} />{kind === "dare" ? "C’est fait !" : "C’est répondu !"}
            </button>
          </>
        )}
        {!active && <>
          <NudgeButton st={st} partner={partner} />
          <button type="button" className="red-btn red-btn--quiet" disabled={busy} onClick={() => void play("skip_round")}>Passer cette manche</button>
        </>}
        {card.card_id && !card.redacted && <LaterButton key={card.card_id} sessionId={st.session.id} round={round.round_no} disabled={busy} />}
      </GameActions>
    </section>
  );
}

// ---------------------------------------------------------------------------------------------------------------
// G08 Deux vérités et un mensonge, tour par tour : un écrit, l'autre devine, puis les rôles s'échangent.
// ---------------------------------------------------------------------------------------------------------------
export function TwoTruthsRed({ st, round, card, priv, me, partner, busy, play, after, err }: {
  st: SessionState; round: { round_no: number }; card: J; priv: J; me: Player; partner?: Player; busy: boolean; play: Play; after: After; err: string | null;
}) {
  const [texts, setTexts] = useState(["", "", ""]);
  const [lie, setLie] = useState<string | null>(null);
  const [truthOk, setTruthOk] = useState(false);
  const [guess, setGuess] = useState<string | null>(null);
  const [idea, setIdea] = useState<string | null>(null);
  const author = card.author === me.seat;
  const authorP = st.players.find((p) => p.seat === card.author);
  const guesserP = st.players.find((p) => p.seat === card.guesser);
  const last = round.round_no >= st.session.total_rounds;
  const roles = <p className="red-tt__roles">{author ? `Tu écris · ${nameOf(guesserP)} devine` : `${nameOf(authorP)} écrit · Tu devines`}</p>;
  const head = (
    <div className="red-tt__head">
      <GameHero hero="masque_trois_cartes" size="sm" />
      {roles}
    </div>
  );
  const skip = !card.done && (
    <button type="button" className="red-btn red-btn--quiet" disabled={busy} onClick={() => void play("skip_round")}>{t("conv.skip")}</button>
  );

  if (card.done) {
    return (
      <section className="red-play red-tt red-reveal" data-phase="reveal">
        {head}
        {card.skipped ? <ReadyStatus icon="skip" tone="info">{t("conv.skipped")}</ReadyStatus> : (
          <>
            <ol className="red-tt__list" aria-label="Révélation">
              {(card.statements ?? []).map((s: J, i: number) => (
                <li key={s.id} className={`red-tt__item${s.id === card.lie ? " is-lie" : ""}`}>
                  <span className="red-tt__n" aria-hidden="true">{i + 1}</span>
                  <span className="grow">{s.text}</span>
                  {s.id === card.lie && <span className="red-chip red-chip--lie"><Icon name="close" size={14} />{t("conv.tt.theLie")}</span>}
                  {s.id === card.guess && <span className="red-chip"><Icon name="eye" size={14} />{t("conv.tt.guessed")}</span>}
                </li>
              ))}
            </ol>
            <ReadyStatus icon={card.found ? "circle-check" : "info"} tone={card.found ? "ok" : "info"}>
              {card.found ? (guesserP?.is_me ? t("conv.tt.foundMe") : t("conv.tt.found", { name: nameOf(guesserP) }))
                : (authorP?.is_me ? t("conv.tt.notFoundMe") : t("conv.tt.notFound", { name: nameOf(authorP) }))}
            </ReadyStatus>
          </>
        )}
        {err && <Alert>{err}</Alert>}
        <ContinueBar st={st} card={card} me={me} partner={partner} busy={busy} after={after} last={last} />
      </section>
    );
  }

  if (card.phase === "write" && !author) {
    return (
      <section className="red-play red-tt" data-phase="wait-write">
        {head}
        <ReadyStatus>{t("conv.tt.waitWrite", { name: nameOf(authorP) })}</ReadyStatus>
        <p className="red-tt__hint">Tu verras les trois propositions dès qu’elles seront verrouillées. Vous pouvez discuter en attendant.</p>
        {err && <Alert>{err}</Alert>}
        <GameActions><NudgeButton st={st} partner={partner} />{skip}</GameActions>
      </section>
    );
  }

  if (card.phase === "write") {
    const distinct = new Set(texts.map((x) => x.trim().toLowerCase())).size === 3;
    const ready = texts.every((x) => x.trim()) && lie !== null && truthOk && distinct;
    return (
      <form className="red-play red-tt" data-phase="write" onSubmit={(e) => {
        e.preventDefault();
        if (ready && !busy) void play("publish_three", { confirmed_truths: true, lie_statement_id: lie, statements: texts.map((x, i) => ({ id: `s${i + 1}`, text: x.trim() })) });
      }}>
        {head}
        <p className="red-tt__hint">Écris trois propositions sur toi. Une seule est un mensonge : désigne-la en secret.</p>
        <fieldset className="red-tt__fields">
          <legend className="sr-only">Tes trois propositions et ton mensonge</legend>
          {texts.map((x, i) => {
            const id = `s${i + 1}`;
            return (
              <div key={id} className={`red-tt__row${lie === id ? " is-lie" : ""}`}>
                <span className="red-tt__n" aria-hidden="true">{i + 1}</span>
                <div className="red-tt__inputs">
                  <label className="sr-only" htmlFor={`red-tt-${id}`}>{t("conv.tt.statement", { n: i + 1 })}</label>
                  <input id={`red-tt-${id}`} className="red-input" maxLength={240} value={x} disabled={busy} placeholder={t("conv.tt.statement", { n: i + 1 })}
                    onChange={(e) => setTexts(texts.map((y, k) => (k === i ? e.target.value : y)))} />
                  <label className="red-tt__lie">
                    <input type="radio" name="red-tt-lie" checked={lie === id} disabled={busy} onChange={() => setLie(id)} />
                    <span>Mon mensonge</span>
                  </label>
                </div>
              </div>
            );
          })}
        </fieldset>
        {!distinct && texts.every((x) => x.trim()) && <p className="red-tt__warn" role="status">Les trois propositions doivent être différentes.</p>}
        <label className="red-check"><input type="checkbox" checked={truthOk} disabled={busy} onChange={(e) => setTruthOk(e.target.checked)} />{t("conv.tt.confirmTruths")}</label>
        <button type="button" className="red-link-btn" disabled={busy} onClick={async () => {
          const r = await rpc<{ text: string }>("get_two_truths_idea", { p_session: st.session.id });
          setIdea(r.ok ? (r as unknown as { text: string }).text : t("conv.tt.noIdea"));
        }}><Icon name="sparkles" size={16} />{t("conv.tt.idea")}</button>
        {idea && <p className="red-status red-status--info" aria-live="polite">{idea}</p>}
        {err && <Alert>{err}</Alert>}
        <GameActions note="Rien n’est envoyé à l’autre avant le verrouillage.">
          <button type="submit" className="red-btn" disabled={busy || !ready}><Icon name="lock-keyhole" size={20} />Verrouiller mes propositions</button>
          {skip}
        </GameActions>
      </form>
    );
  }

  // Devinette.
  return (
    <section className="red-play red-tt" data-phase="guess">
      {head}
      {author ? (
        <>
          <ol className="red-tt__list" aria-label="Tes propositions">
            {(card.statements ?? []).map((s: J, i: number) => (
              <li key={s.id} className="red-tt__item">
                <span className="red-tt__n" aria-hidden="true">{i + 1}</span><span className="grow">{s.text}</span>
                {priv?.lie === s.id && <span className="red-chip red-chip--lie">{t("conv.tt.yourLie")}</span>}
              </li>
            ))}
          </ol>
          <ReadyStatus>{t("conv.tt.waitGuess", { name: nameOf(guesserP) })}</ReadyStatus>
          {err && <Alert>{err}</Alert>}
          <GameActions><NudgeButton st={st} partner={partner} />{skip}</GameActions>
        </>
      ) : (
        <>
          <p className="red-tt__hint">{t("conv.tt.whichLie")}</p>
          <div className="red-stack" role="radiogroup" aria-label={t("conv.tt.whichLie")}>
            {(card.statements ?? []).map((s: J, i: number) => (
              <ChoiceCard key={s.id} layout="row" label={<><span className="red-tt__n" aria-hidden="true">{i + 1}</span><span>{s.text}</span></>} selected={guess === s.id}
                disabled={busy} onSelect={() => setGuess(s.id)} tone="cream" />
            ))}
          </div>
          {err && <Alert>{err}</Alert>}
          <GameActions>
            <button type="button" className="red-btn" disabled={busy || !guess} onClick={() => guess && void play("lock_guess", { statement_id: guess })}>
              <Icon name="check" size={20} />{t("conv.tt.lockGuess")}
            </button>
            {skip}
          </GameActions>
        </>
      )}
    </section>
  );
}

/** Jetons du kit pour « Je n'ai jamais », choisis d'après le libellé réel de l'option (jamais d'après sa position). */
export const neverToken = (text: string) =>
  /jamais/i.test(text) ? redIllustration("jeton_jamais") : /déjà|deja/i.test(text) ? redIllustration("jeton_deja") : undefined;
