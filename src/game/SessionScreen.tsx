import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router";
import { fill, t } from "../i18n";
import { errorMessage } from "../lib/errors";
import { rpc } from "../lib/supabase";
import { useOnline } from "../lib/useOnline";
import { useAuth } from "../auth/AuthProvider";
import { useCouple } from "../couple/CoupleProvider";
import { Alert, Avatar, Icon, Illustration, Loading, PageLoading } from "../components/ui";
import type { Player, Round, SessionState } from "../lib/types";
import { answerOf, nextStep, portraitReveal, toggleWord, wordLabel } from "./portrait";
import { useDraft, useSession } from "./useSession";
import { Salon } from "./Salon";

export function SessionScreen() {
  const { sessionId = "" } = useParams();
  const { userId } = useAuth();
  const { refresh: refreshCouple } = useCouple();
  const online = useOnline();
  const s = useSession(sessionId, userId);
  const [salonOpen, setSalonOpen] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const navigate = useNavigate();

  const status = s.state?.session.status;
  useEffect(() => {
    void refreshCouple();
  }, [status, refreshCouple]);

  async function run(fn: string, args: Record<string, unknown> = {}) {
    if (busy) return { ok: false as const, error: "busy" };
    setBusy(true);
    setActionError(null);
    const res = await s.act(fn, args);
    if (!res.ok && res.error !== "stale_round") setActionError(errorMessage(res.error));
    setBusy(false);
    return res;
  }

  function openSalon(open: boolean) {
    setSalonOpen(open);
    s.setSalonOpen(open);
  }

  if (s.loading && !s.state) return <PageLoading />;
  if (!s.state) {
    return (
      <main className="page page--bare">
        <div className="empty">
          <Illustration name="16-reconnexion" />
          <h2>{s.error ? t("game.notFound") : t("net.reconnecting")}</h2>
          {s.error ? <Link className="btn" to="/accueil">{t("game.home")}</Link> : <button className="btn" onClick={() => void s.load()}>{t("common.retry")}</button>}
        </div>
      </main>
    );
  }

  const st = s.state;
  const me = st.players.find((p) => p.is_me);
  const partner = st.players.find((p) => !p.is_me);
  const partnerName = partner?.display_name || "?";
  const partnerHere = Boolean(partner?.user_id && s.present.includes(partner.user_id));
  const active = ["lobby", "playing", "paused", "ended"].includes(st.session.status) && !st.session.read_only;

  return (
    <main className="page page--bare">
      <header className="topbar">
        <Link className="icon-btn" to="/accueil"><Icon name="arrow-left" label={t("game.home")} /></Link>
        <strong style={{ textAlign: "center", flex: 1 }}>{st.game.title}</strong>
        <div className="topbar__actions">
          {active && (
            <button className="icon-btn" onClick={() => openSalon(true)} aria-label={`${t("game.salon")}${s.unread ? ` (${s.unread})` : ""}`}>
              <Icon name="chat" />
              <span aria-hidden="true">{s.unread ? s.unread : ""}</span>
            </button>
          )}
          {(st.session.status === "playing" || st.session.status === "paused") && (
            <button className="icon-btn" disabled={busy || !online} onClick={() => run("set_paused", { p_paused: st.session.status === "playing" })}>
              <Icon name={st.session.status === "paused" ? "play" : "pause"} />
              <span>{st.session.status === "paused" ? t("game.resume") : t("game.pause")}</span>
            </button>
          )}
        </div>
      </header>

      {s.channel === "down" && online && <Alert kind="info"><Loading label={t("net.reconnecting")} /></Alert>}
      {actionError && <Alert>{actionError}</Alert>}

      {st.session.status === "lobby" && (
        <Lobby st={st} me={me} partner={partner} partnerHere={partnerHere} busy={busy} online={online} run={run} onOpenSalon={() => openSalon(true)} />
      )}
      {st.session.status === "playing" && <Playing st={st} partnerName={partnerName} partner={partner} busy={busy} online={online} run={run} />}
      {st.session.status === "paused" && (
        <section className="empty enter">
          <Illustration name="17-pause" />
          <h2>{t("game.pausedTitle")}</h2>
          <p>{st.session.paused_by === userId ? t("game.pausedByYou") : t("game.pausedBy", { name: partnerName })}</p>
          <button className="btn" disabled={busy || !online} onClick={() => run("set_paused", { p_paused: false })}>{t("game.resume")}</button>
        </section>
      )}
      {(st.session.status === "ended" || st.session.status === "closed") && (
        <Results st={st} me={me} partner={partner} busy={busy} online={online} run={run} navigate={navigate} />
      )}
      {st.session.status === "abandoned" && (
        <section className="empty">
          <Illustration name="17-pause" />
          <h2>{t("game.abandoned")}</h2>
          <Link className="btn" to="/accueil">{t("game.home")}</Link>
        </section>
      )}

      {["lobby", "playing", "paused"].includes(st.session.status) && !st.session.read_only && (
        <button
          className="btn btn--ghost"
          disabled={busy}
          onClick={async () => {
            if (!window.confirm(t("game.quitConfirm"))) return;
            const res = await run("abandon_session");
            if (res.ok) navigate("/accueil");
          }}
        >
          {t("game.quit")}
        </button>
      )}

      {salonOpen && (
        <Salon
          myId={userId}
          partnerName={partnerName}
          myName={me?.display_name ?? ""}
          messages={s.messages}
          onSend={s.sendMessage}
          onClose={() => openSalon(false)}
          online={online}
        />
      )}
    </main>
  );
}

type Run = (fn: string, args?: Record<string, unknown>) => Promise<{ ok: boolean }>;

function Lobby({ st, me, partner, partnerHere, busy, online, run, onOpenSalon }: {
  st: SessionState; me?: Player; partner?: Player; partnerHere: boolean; busy: boolean; online: boolean; run: Run; onOpenSalon: () => void;
}) {
  const settings = st.game.config.settings ?? {};
  return (
    <section className="stack stack--lg enter">
      <div className="page-head">
        <h1>{t("game.lobbyTitle")}</h1>
        <p>{t("game.lobbyText")}</p>
      </div>
      <div className="card card--flat" style={{ gap: 0 }}>
        {[me, partner].filter(Boolean).map((p) => (
          <div className="player-row" key={p!.seat}>
            <Avatar name={p!.display_name} me={p!.is_me} />
            <div style={{ flex: 1 }}>
              <div className="player-row__name">{p!.is_me ? `${p!.display_name} (${t("game.you")})` : p!.display_name}</div>
              <div className="status">
                <span className={`status-dot ${p!.ready ? "status-dot--on" : ""}`} />
                {p!.ready ? t("game.isReady") : t("game.isNotReady")}
                {!p!.is_me && partnerHere && <> · {t("presence.inGame")}</>}
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="card card--warm">
        <h3>{t("sheet.howTo")}</h3>
        <ol className="how">{st.game.rules.how_to.map((x) => <li key={x}>{x}</li>)}</ol>
        <p className="row small"><Icon name="lock" size={18} /> {st.game.rules.privacy}</p>
      </div>

      {Object.entries(settings).map(([key, def]) => (
        <fieldset key={key} className="stack">
          <legend style={{ fontWeight: 700, marginBottom: 8 }}>{def.label}</legend>
          <div className="chips">
            {def.options.map((opt) => (
              <button
                key={String(opt)}
                className="chip"
                aria-pressed={st.session.settings[key] === opt}
                disabled={busy || !online}
                onClick={() => run("update_session_settings", { p_settings: { [key]: opt } })}
              >
                {String(opt)}
              </button>
            ))}
          </div>
          <p className="muted small">{t("game.settingsReset")}</p>
        </fieldset>
      ))}

      <button className="btn btn--soft" onClick={onOpenSalon}><Icon name="chat" />{t("salon.title")}</button>
      <div className="sticky-actions">
        <button className="btn" disabled={busy || !online} onClick={() => run("set_ready", { p_ready: !me?.ready })}>
          {busy ? t("common.sending") : me?.ready ? t("game.notReady") : t("game.ready")}
        </button>
      </div>
    </section>
  );
}

function Playing({ st, partnerName, partner, busy, online, run }: {
  st: SessionState; partnerName: string; partner?: Player; busy: boolean; online: boolean; run: Run;
}) {
  const round = st.rounds.find((r) => r.round_no === st.session.current_round);
  const steps = st.game.config.steps.map((x) => x.key);
  const mySeat = st.my_seat ?? 0;
  if (!round) return <Loading />;
  const step = nextStep(round, steps, mySeat);
  if (step) {
    return <PortraitStep key={`${round.round_no}-${step}`} st={st} round={round} stepKey={step} partnerName={partnerName} partner={partner} busy={busy} online={online} run={run} />;
  }
  const partnerSeat = mySeat === 1 ? 2 : 1;
  return (
    <section className="stack stack--lg enter" aria-live="polite">
      <Illustration name="09-attente-douce" className="illustration--hero" />
      <div className="page-head center">
        <h1>{t("game.sentTitle")}</h1>
        <p>{t("game.waitingPartner", { name: partnerName })}</p>
      </div>
      <div className="card card--flat" style={{ gap: 0 }}>
        {st.players.map((p) => {
          const done = steps.every((k) => answerOf(round, k, p.seat));
          return (
            <div className="player-row" key={p.seat}>
              <Avatar name={p.display_name} me={p.is_me} />
              <div style={{ flex: 1 }}>
                <div className="player-row__name">{p.display_name}</div>
                <div className="status">
                  {done ? <><Icon name="check" size={16} /> {t("game.sent")}</> : <Loading label={t("game.preparing")} />}
                </div>
              </div>
            </div>
          );
        })}
      </div>
      <Alert kind="info"><Icon name="lock" size={18} /> {st.game.rules.privacy}</Alert>
      <p className="center muted small">{t("game.noRush")}</p>
      {steps.every((k) => answerOf(round, k, partnerSeat)) && <Loading />}
    </section>
  );
}

function PortraitStep({ st, round, stepKey, partnerName, partner, busy, online, run }: {
  st: SessionState; round: Round; stepKey: string; partnerName: string; partner?: Player; busy: boolean; online: boolean; run: Run;
}) {
  const cfg = st.game.config;
  const texts = st.game.rules.step_texts[stepKey];
  const stepCfg = cfg.steps.find((x) => x.key === stepKey)!;
  const me = st.players.find((p) => p.is_me);
  const form = stepCfg.about === "self" ? me?.word_form ?? "n" : partner?.word_form ?? "n";
  const [selection, setSelection, clearDraft] = useDraft(`${st.session.id}.${round.round_no}.${stepKey}`);
  const index = cfg.steps.findIndex((x) => x.key === stepKey);
  const valid = useMemo(() => selection.filter((id) => round.card.words.some((w) => w.id === id)), [selection, round]);
  const vars = { partner: partnerName };

  async function submit(skip: boolean) {
    if (skip && !window.confirm(t("game.skipConfirm"))) return;
    const res = await run("submit_answer", { p_round: round.round_no, p_step: stepKey, p_payload: skip ? null : { words: valid }, p_skip: skip });
    if (res.ok) clearDraft();
  }

  return (
    <section className="stack stack--lg enter">
      <div className="stack">
        <div className="row" style={{ justifyContent: "space-between" }}>
          <strong>{index + 1} · {texts.title}</strong>
          <span className="muted small">{t("game.step", { n: index + 1, total: cfg.steps.length + 1 })}</span>
        </div>
        <div className="progress" aria-hidden="true"><span style={{ width: `${((index + 1) / (cfg.steps.length + 1)) * 100}%` }} /></div>
      </div>
      <div className="page-head">
        <h1>{fill(texts.prompt, vars)}</h1>
        <p>{fill(texts.hint, vars)}</p>
      </div>
      <div className="word-grid" role="group" aria-label={fill(texts.hint, vars)}>
        {round.card.words.map((w) => {
          const on = valid.includes(w.id);
          return (
            <button
              key={w.id}
              className="word"
              aria-pressed={on}
              disabled={!on && valid.length >= cfg.pick}
              onClick={() => setSelection(toggleWord(valid, w.id, cfg.pick))}
            >
              <span>{wordLabel(w, form)}</span>
              <span className="word__check" aria-hidden="true"><Icon name="check" size={14} /></span>
            </button>
          );
        })}
      </div>
      <p className="center" aria-live="polite"><strong>{t("game.selected", { n: valid.length, max: cfg.pick })}</strong></p>
      <p className="center muted small row" style={{ justifyContent: "center" }}><Icon name="lock" size={16} /> {t("game.privateHint")}</p>
      <div className="sticky-actions">
        <button className="btn" disabled={busy || !online || valid.length !== cfg.pick} onClick={() => submit(false)}>
          {busy ? t("common.sending") : texts.confirm} <Icon name="arrow-right" />
        </button>
        <button className="btn btn--secondary" disabled={busy || !online} onClick={() => submit(true)}>{t("game.skip")}</button>
      </div>
    </section>
  );
}

function Results({ st, me, partner, busy, online, run, navigate }: {
  st: SessionState; me?: Player; partner?: Player; busy: boolean; online: boolean; run: Run; navigate: (to: string) => void;
}) {
  const [view, setView] = useState<"partner" | "mine" | "end">("partner");
  const round = st.rounds.find((r) => r.revealed);
  const words = new Map((round?.card.words ?? []).map((w) => [w.id, w]));
  const closedWithoutAnswers = st.session.status === "closed" && !round?.answers.length;
  const partnerName = partner?.display_name || "?";

  if (!round || closedWithoutAnswers) {
    return (
      <section className="empty">
        <Illustration name="11-fin-de-partie" />
        <h2>{t("game.closed")}</h2>
        <p>{t("space.notKept")}</p>
        <Link className="btn" to="/accueil">{t("game.home")}</Link>
      </section>
    );
  }

  function PortraitCard({ about, guesser }: { about?: Player; guesser?: Player }) {
    if (!about) return null;
    const r = portraitReveal(round!, about.seat);
    const name = about.display_name || "?";
    return (
      <div className="stack stack--lg enter">
        <div className="page-head">
          <span className="muted small" style={{ letterSpacing: ".12em", textTransform: "uppercase" }}>3 · {t("game.revealTitle")}</span>
          <h1>{about.is_me ? t("portrait.revealMine") : t("portrait.revealPartner", { name })}</h1>
          {r.chosen && r.guessed && <p>{t("portrait.found", { n: r.found.length })}</p>}
        </div>
        <div className="card stack">
          <h3 className="row"><Avatar name={name} me={about.is_me} /> {about.is_me ? t("portrait.chosenByMe") : t("portrait.chosenBy", { name })}</h3>
          {r.chosen ? (
            <ul className="word-grid list" aria-label={t("portrait.chosenBy", { name })}>
              {r.chosen.map((id) => (
                <li key={id} className={`word word--static ${r.found.includes(id) ? "word--match" : ""}`}>
                  {r.found.includes(id) && <Icon name="check" size={16} label={t("portrait.matchLabel")} />}
                  {words.get(id) ? wordLabel(words.get(id)!, about.word_form) : id}
                </li>
              ))}
            </ul>
          ) : <p className="muted">{t("portrait.noAnswer", { name })}</p>}
        </div>
        {guesser && (
          <div className="card stack">
            <h3 className="row"><Avatar name={guesser.display_name} me={guesser.is_me} /> {guesser.is_me ? t("portrait.guessedByMe") : t("portrait.guessedBy", { name: guesser.display_name })}</h3>
            {r.guessed ? (
              <ul className="word-grid list">
                {r.guessed.map((id) => (
                  <li key={id} className={`word word--static ${r.found.includes(id) ? "word--match" : ""}`}>
                    {r.found.includes(id) && <Icon name="check" size={16} label={t("portrait.matchLabel")} />}
                    {words.get(id) ? wordLabel(words.get(id)!, about.word_form) : id}
                  </li>
                ))}
              </ul>
            ) : <p className="muted">{t("portrait.noAnswer", { name: guesser.display_name })}</p>}
          </div>
        )}
        <div className="card card--warm"><h3>{t("portrait.discuss")}</h3></div>
      </div>
    );
  }

  if (view === "partner") {
    return (
      <>
        <PortraitCard about={partner} guesser={me} />
        <button className="btn" onClick={() => setView("mine")}>{t("portrait.revealMine")} <Icon name="arrow-right" /></button>
      </>
    );
  }
  if (view === "mine") {
    return (
      <>
        <PortraitCard about={me} guesser={partner} />
        <button className="btn" onClick={() => setView("end")}>{t("common.continue")} <Icon name="arrow-right" /></button>
        <button className="btn btn--ghost" onClick={() => setView("partner")}>{t("portrait.revealPartner", { name: partnerName })}</button>
      </>
    );
  }

  const ended = st.session.status === "ended" && !st.session.read_only;
  const bothKeep = st.players.every((p) => p.keep_memory);
  return (
    <section className="stack stack--lg enter">
      <Illustration name="11-fin-de-partie" className="illustration--hero" />
      <div className="page-head center">
        <h1>{t("game.endTitle")}</h1>
        <p>{t("game.endText", { title: st.game.title })}</p>
      </div>
      {ended && (
        <div className="card stack">
          <label className="switch">
            <span>{t("game.keepMemory")}</span>
            <input
              type="checkbox"
              role="switch"
              checked={Boolean(me?.keep_memory)}
              disabled={busy || !online}
              onChange={(e) => run("set_keep_memory", { p_keep: e.target.checked })}
            />
          </label>
          <p className="muted small">{bothKeep ? t("game.keepBoth") : me?.keep_memory ? t("game.keepWaiting", { name: partnerName }) : t("game.keepMemoryHint")}</p>
        </div>
      )}
      {ended && (
        <>
          <button
            className="btn"
            disabled={busy || !online}
            onClick={async () => {
              const res = await rpc<{ session_id: string }>("create_session", { p_game: st.session.game_id });
              if (res.ok) navigate(`/partie/${res.session_id}`);
            }}
          >
            {t("game.replay")}
          </button>
          <button
            className="btn btn--secondary"
            disabled={busy || !online}
            onClick={async () => {
              await run("close_session");
              navigate("/bibliotheques");
            }}
          >
            {t("game.otherGame")}
          </button>
        </>
      )}
      <Link className="btn btn--ghost" to="/accueil">{t("game.home")}</Link>
      <button className="btn btn--ghost" onClick={() => setView("partner")}>{t("portrait.revealPartner", { name: partnerName })}</button>
    </section>
  );
}
