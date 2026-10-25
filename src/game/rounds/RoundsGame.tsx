import { Link } from "react-router";
import { fill, t } from "../../i18n";
import { Avatar } from "../../components/Avatar";
import { Alert, Icon, Illustration, Loading, Sheet, formatDate } from "../../components/ui";
import type { Player, SessionState } from "../../lib/types";
import { StepInput, type StepTexts } from "./inputs";
import { AnswerView, SceneView } from "./views";
import { afterTurns, answerOf, nextTurn, stepSeats, type RRound, type RoundsConfig, type StepDef } from "./logic";

type Run = (fn: string, args?: Record<string, unknown>) => Promise<{ ok: boolean; error?: string }>;
interface Common { st: SessionState; run: Run; busy: boolean; online: boolean }

export const isRounds = (st: SessionState) => (st.game.config as unknown as { engine?: string }).engine === "rounds";
const cfgOf = (st: SessionState) => st.game.config as unknown as RoundsConfig;
const roundsOf = (st: SessionState) => st.rounds as unknown as RRound[];

function textsFor(st: SessionState, step: StepDef): StepTexts {
  const all = st.game.rules.step_texts as unknown as Record<string, StepTexts>;
  return all[step.key] ?? all[step.key.replace(/\d+$/, "")] ?? { title: "", prompt: "", hint: "", confirm: t("common.continue") };
}

function people(st: SessionState) {
  const me = st.players.find((p) => p.is_me)!;
  const partner = st.players.find((p) => !p.is_me);
  return { me, partner, vars: { name: partner?.display_name || "?", theme: "" } };
}

/** Carte du tour (question tirée) ; mention +18 explicite, jamais seulement par la couleur. */
function CardFace({ round, total }: { round: RRound; total: number }) {
  if (!round.card.text) return total > 1 ? <p className="t-meta">{t("rounds.cardOf", { n: round.round_no, total })}</p> : null;
  return (
    <div className="play-card">
      <div className="row row--between">
        <span className="t-meta">{total > 1 ? t("rounds.cardOf", { n: round.round_no, total }) : ""}</span>
        {round.card.adult && <span className="tag tag--adult">{t("rounds.adultTag")}</span>}
      </div>
      <p className="play-card__text">{round.card.text}</p>
    </div>
  );
}

function submitter(c: Common, round: RRound, step: StepDef) {
  return async (payload: Record<string, unknown> | null, skip = false) => {
    const res = await c.run("submit_answer", { p_round: round.round_no, p_step: step.key, p_payload: payload, p_skip: skip });
    return res.ok;
  };
}

/** Réponses visibles d'une étape, par joueur (sa propre réponse, ou celle de l'autre une fois révélée). */
function StepAnswers({ st, round, step }: { st: SessionState; round: RRound; step: StepDef }) {
  if (step.kind === "place") return <SceneView round={round} />;
  const seats = stepSeats(step, round.card);
  const players = st.players.filter((p) => seats.includes(p.seat));
  const answered = players.filter((p) => answerOf(round, step.key, p.seat));
  if (!answered.length && step.kind !== "light") return null;
  return (
    <div className="stack stack--3">
      {answered.map((p) => (
        <div key={p.seat} className="answer-block">
          <div className="row"><Avatar name={p.display_name} path={p.avatar_path} size={32} me={p.is_me} /><span className="t-small strong">{p.is_me ? t("game.you") : p.display_name}</span></div>
          <AnswerView step={step} answer={answerOf(round, step.key, p.seat)} round={round} owner={p} />
        </div>
      ))}
    </div>
  );
}

/** Une manche révélée : la carte, les réponses, puis les étapes d'après (réaction, accord, page commune…). */
function RoundReveal({ c, round, interactive }: { c: Common; round: RRound; interactive: boolean }) {
  const cfg = cfgOf(c.st);
  const { me, partner, vars } = people(c.st);
  const pending = interactive ? afterTurns(cfg, round, me.seat) : [];
  const total = c.st.session.total_rounds;
  return (
    <section className="stack stack--4 enter" aria-labelledby={`reveal-${round.round_no}`}>
      <h2 className="sr-only" id={`reveal-${round.round_no}`}>{t("rounds.revealOf", { n: round.round_no })}</h2>
      <CardFace round={round} total={total} />
      {cfg.steps.map((s) => (
        <div key={s.key} className="stack stack--2">
          {cfg.steps.length > 1 && <h3 className="t-card">{fill(textsFor(c.st, s).title, vars)}</h3>}
          <StepAnswers st={c.st} round={round} step={s} />
        </div>
      ))}
      {cfg.after.some((s) => round.answers.some((a) => a.step === s.key)) && (
        <div className="card card--soft stack stack--3">
          {cfg.after.filter((s) => round.answers.some((a) => a.step === s.key)).map((s) => (
            <div key={s.key} className="stack stack--2">
              <span className="t-meta">{fill(textsFor(c.st, s).title, vars)}</span>
              <StepAnswers st={c.st} round={round} step={s} />
            </div>
          ))}
        </div>
      )}
      {pending.slice(0, 1).map((s) => (
        <div key={s.key} className="card stack stack--3">
          <h3 className="t-card">{fill(textsFor(c.st, s).prompt, vars)}</h3>
          <p className="t-small muted">{fill(textsFor(c.st, s).hint, vars)}</p>
          <StepInput step={s} round={round} texts={textsFor(c.st, s)} vars={vars} me={me} partner={partner}
            busy={c.busy} online={c.online} submit={submitter(c, round, s)} />
        </div>
      ))}
    </section>
  );
}

export function RoundsPlaying(c: Common) {
  const cfg = cfgOf(c.st);
  const { me, partner, vars } = people(c.st);
  const round = roundsOf(c.st).find((r) => r.round_no === c.st.session.current_round);
  if (!round) return <Loading />;
  const total = c.st.session.total_rounds;

  if (round.revealed) {
    const last = round.round_no >= total;
    return (
      <>
        <RoundReveal c={c} round={round} interactive />
        {!last && (
          <div className="action-bar">
            <button className="btn" disabled={c.busy || !c.online} onClick={() => c.run("next_round", { p_from_round: round.round_no })}>
              {t("rounds.nextCard")}<Icon name="arrow-right" />
            </button>
            <button className="btn btn--quiet" disabled={c.busy || !c.online} onClick={() => c.run("finish_session")}>{t("rounds.stopHere")}</button>
          </div>
        )}
      </>
    );
  }

  const turn = nextTurn(cfg, round, me.seat);
  if (turn.kind === "answer") {
    const texts = textsFor(c.st, turn.step);
    const themeVars = { ...vars, theme: String((round.card.themes as { v: string }[] | undefined)?.[0]?.v ?? "") };
    const canReroll = (cfg.rerolls ?? 0) > (round.card.rerolled ?? 0) && round.answers.length === 0;
    // Étapes de l'autre déjà visibles (écoute : le récit à reformuler).
    const shown = cfg.steps.filter((s) => s.visible === "immediate" && partner && answerOf(round, s.key, partner.seat));
    return (
      <section className="stack stack--5 enter" key={`${round.round_no}-${turn.step.key}`}>
        {turn.total > 1 && (
          <div className="stack stack--2">
            <div className="row row--between"><span className="t-small strong">{fill(texts.title, themeVars)}</span>
              <span className="t-meta">{t("game.step", { n: turn.index + 1, total: turn.total })}</span></div>
            <div className="progress" role="progressbar" aria-valuemin={1} aria-valuemax={turn.total} aria-valuenow={turn.index + 1}
              aria-label={t("game.step", { n: turn.index + 1, total: turn.total })}><span style={{ width: `${((turn.index + 1) / turn.total) * 100}%` }} /></div>
          </div>
        )}
        <CardFace round={round} total={total} />
        {shown.map((s) => <div key={s.key} className="card card--soft"><StepAnswers st={c.st} round={round} step={s} /></div>)}
        <div className="page-header">
          <h1 className="t-section">{fill(texts.prompt, themeVars)}</h1>
          {texts.hint && <p>{fill(texts.hint, themeVars)}</p>}
        </div>
        {canReroll && (
          <button className="btn btn--quiet btn--auto btn--sm" disabled={c.busy || !c.online} onClick={() => c.run("reroll_round", { p_round: round.round_no })}>
            <Icon name="refresh" size={18} />{t("rounds.reroll")}
          </button>
        )}
        <StepInput step={turn.step} round={round} texts={texts} vars={themeVars} me={me} partner={partner}
          busy={c.busy} online={c.online} submit={submitter(c, round, turn.step)} />
      </section>
    );
  }

  // Envoyé, ou en attente d'une étape de l'autre.
  const shown = cfg.steps.filter((s) => s.visible === "immediate" && round.answers.some((a) => a.step === s.key));
  return (
    <section className="stack stack--5 enter" aria-live="polite">
      <CardFace round={round} total={total} />
      {shown.map((s) => <div key={s.key} className="card card--soft"><StepAnswers st={c.st} round={round} step={s} /></div>)}
      <Illustration name="09-attente-douce" className="public__art" />
      <div className="page-header center">
        <h1 className="t-page">{turn.kind === "wait" ? t("rounds.yourTurnSoon") : t("game.sentTitle")}</h1>
        <p>{turn.kind === "wait" ? t("rounds.waitingStep", { name: vars.name }) : t("game.waitingPartner", { name: vars.name })}</p>
      </div>
      <Alert kind="info"><Icon name="lock" size={18} />{c.st.game.rules.privacy}</Alert>
      <p className="center t-meta">{t("game.noRush")}</p>
    </section>
  );
}

export function RoundsResults({ c, navigate }: { c: Common; navigate: (to: string) => void }) {
  const { me, partner } = people(c.st);
  const rounds = roundsOf(c.st);
  const capsule = rounds.find((r) => r.reveal_at);
  const revealed = rounds.filter((r) => r.revealed);
  const ended = c.st.session.status === "ended" && !c.st.session.read_only;
  const result = c.st.session.result as { points?: Record<string, number> } | undefined;
  const bothKeep = c.st.players.every((p) => p.keep_memory);

  if (!revealed.length && !capsule) {
    return (
      <section className="empty">
        <Illustration name="11-fin-de-partie" />
        <h2 className="t-section">{t("game.closed")}</h2>
        <p>{t("game.notKept")}</p>
        <Link className="btn btn--auto" to="/accueil">{t("game.home")}</Link>
      </section>
    );
  }

  return (
    <section className="stack stack--6">
      {capsule && (
        <div className="card stack stack--3">
          <h1 className="t-section">{t("rounds.capsuleClosed")}</h1>
          <p>{t("rounds.capsuleOpens", { date: formatDate(capsule.reveal_at!, false) })}</p>
          <AnswerView step={cfgOf(c.st).steps[0]} answer={answerOf(capsule, cfgOf(c.st).steps[0].key, me.seat)} round={capsule} owner={me} />
        </div>
      )}
      {revealed.map((r) => <RoundReveal key={r.round_no} c={c} round={r} interactive={ended && r === revealed[revealed.length - 1]} />)}
      {result?.points && (
        <div className="card stack stack--2">
          <h2 className="t-card">{t("rounds.points")}</h2>
          {c.st.players.map((p) => <p key={p.seat}>{p.is_me ? t("game.you") : p.display_name} : {result.points![String(p.seat)] ?? 0}</p>)}
          <p className="t-meta">{t("rounds.pointsRule")}</p>
        </div>
      )}
      <div className="page-header center">
        <h2 className="t-page">{t("game.endTitle")}</h2>
        <p>{t("game.endText", { title: c.st.game.title })}</p>
      </div>
      {ended && !capsule && (
        <div className="group">
          <label className="switch-row">
            <span className="switch-row__text">
              <span>{t("game.keepMemory")}</span>
              <span className="t-meta">{bothKeep ? t("game.keepBoth") : me.keep_memory ? t("game.keepWaiting", { name: partner?.display_name || "?" }) : t("rounds.keepHint24")}</span>
            </span>
            <input className="switch" type="checkbox" role="switch" checked={me.keep_memory} disabled={c.busy || !c.online}
              onChange={(e) => c.run("set_keep_memory", { p_keep: e.target.checked })} />
          </label>
        </div>
      )}
      {ended && (
        <div className="stack">
          <button className="btn" disabled={c.busy || !c.online} onClick={async () => {
            await c.run("close_session");
            navigate(`/bibliotheques/${c.st.session.game_id}`);
          }}>{t("game.replay")}</button>
          <button className="btn btn--secondary" disabled={c.busy || !c.online} onClick={async () => { await c.run("close_session"); navigate("/bibliotheques"); }}>{t("game.otherGame")}</button>
        </div>
      )}
      <Link className="btn btn--quiet" to="/accueil">{t("game.home")}</Link>
    </section>
  );
}

const TOPICS = ["passe", "sante_sexuelle", "numerique", "desir"] as const;

/** Petite fenêtre d'options : réglages de partie (salon) et thèmes à éviter (préférence privée). */
export function OptionsSheet({ c, onClose }: { c: Common; onClose: () => void }) {
  const cfg = cfgOf(c.st);
  const lobby = c.st.session.status === "lobby";
  const prefs = (c.st as unknown as { my_prefs?: { adult: boolean; excluded_topics: string[] } }).my_prefs ?? { adult: false, excluded_topics: [] };
  const adultAvailable = Boolean((c.st.game as unknown as { adult_available?: boolean }).adult_available);
  const settings = Object.entries(cfg.settings ?? {});
  const setPrefs = (adult: boolean, topics: string[]) => c.run("set_session_prefs", { p_adult: adult, p_excluded: topics });
  return (
    <Sheet title={<h2 className="t-section">{t("rounds.options")}</h2>} onClose={onClose}
      footer={<div className="sheet__foot"><button className="btn" onClick={onClose}>{t("rounds.optionsReady")}</button></div>}>
      {lobby && settings.map(([key, def]) => (
        <fieldset key={key}>
          <legend>{def.label}</legend>
          <div className="chips" role="radiogroup">
            {def.options.map((opt) => (
              <button key={String(opt)} type="button" className="chip" role="radio" aria-checked={c.st.session.settings[key] === opt} disabled={c.busy || !c.online}
                onClick={() => c.run("update_session_settings", { p_settings: { [key]: opt } })}>{String(opt)}</button>
            ))}
          </div>
        </fieldset>
      ))}
      {adultAvailable && (
        <>
          <fieldset>
            <legend>{t("rounds.avoidTopics")}</legend>
            <div className="chips">
              {TOPICS.map((k) => {
                const on = prefs.excluded_topics.includes(k);
                return (
                  <button key={k} type="button" className="chip" role="checkbox" aria-checked={on} disabled={c.busy || !c.online}
                    onClick={() => setPrefs(prefs.adult, on ? prefs.excluded_topics.filter((x) => x !== k) : [...prefs.excluded_topics, k])}>
                    {on && <Icon name="check" size={16} />}{t(`rounds.topic.${k}`)}
                  </button>
                );
              })}
            </div>
            <p className="t-meta">{t("rounds.avoidHint")}</p>
          </fieldset>
        </>
      )}
      {!settings.length && !adultAvailable && <p className="muted">{t("rounds.noOptions")}</p>}
      {lobby && <p className="t-meta">{t("game.settingsReset")}</p>}
    </Sheet>
  );
}

export function hasOptions(st: SessionState) {
  return Object.keys(cfgOf(st).settings ?? {}).length > 0 || Boolean((st.game as unknown as { adult_available?: boolean }).adult_available);
}

export type { Player };
