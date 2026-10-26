import { useEffect, useMemo, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router";
import { fill, t } from "../i18n";
import { errorMessage } from "../lib/errors";
import { rpc } from "../lib/supabase";
import { useOnline } from "../lib/useOnline";
import { useAuth } from "../auth/AuthProvider";
import { useDuo } from "../duo/DuoProvider";
import { ChatPanel } from "../duo/Chat";
import { SubPage } from "../components/AppShell";
import { Avatar } from "../components/Avatar";
import { Alert, ConfirmDialog, Icon, Illustration, Loading, PageLoading, Sheet } from "../components/ui";
import { RulesSheet } from "../components/RulesSheet";
import type { Player, Round, SessionState } from "../lib/types";
import { answerOf, nextStep, portraitReveal, toggleWord, wordLabel } from "./portrait";
import { useDraft, useSession } from "./useSession";
import { OptionsSheet, RoundsPlaying, RoundsResults, hasOptions, isRounds } from "./rounds/RoundsGame";
import { BoardPlaying, BoardResults, isBoard } from "./board/BoardGame";
import { Stage } from "./premium/Stage";
import { universeOf } from "./premium/universe";
import { SessionRecoveryContext } from "./premium/BoardPieces";
import { QuestionnairePlaying, QuestionnaireResults, isQuestionnaireMech } from "./board/QuestionnaireGames";
import { ConversationPlaying, ConversationResults, isConversationMech } from "./board/ConversationGames";
import { WordPlaying, isWordMech } from "./board/WordGames";
import { ConnectionNotice } from "./ConnectionNotice";
import { AfterGame } from "../parcours/AfterGame";
import { ReadingRegion } from "./ReadingRegion";
import "../styles/astra-console.css";
import "../styles/salon-proposal.css";
import "../styles/board-session-refinement.css";
import "../styles/red-kit.css";
import { redKitOf, RED_SCREENS } from "./red/kit";
import { DuoStrip, GameHeader, GameHero, GameShell, ReconnectBanner, RoundProgress } from "./red/ui";
import { RedLobby } from "./red/Lobby";
import { scoreboard } from "./premium/GameFrame";

type Run = (fn: string, args?: Record<string, unknown>) => Promise<{ ok: boolean }>;

export function SessionScreen() {
  const { sessionId = "" } = useParams();
  const { userId } = useAuth();
  const duo = useDuo();
  const online = useOnline();
  const s = useSession(sessionId, userId);
  const [chat, setChat] = useState(false);
  const [options, setOptions] = useState(false);
  const [confirmQuit, setConfirmQuit] = useState(false);
  const [rules, setRules] = useState(false);
  const [commands, setCommands] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const actionLock = useRef(false);
  const leavingSession = useRef(false);
  const navigate = useNavigate();

  const status = s.state?.session.status;
  useEffect(() => {
    void duo.refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status]);

  async function run(fn: string, args: Record<string, unknown> = {}) {
    // Une préparation différée ne doit pas déclarer le joueur prêt après Réduire
    // ou un retour navigateur, même si la route suivante est encore en chargement.
    if (leavingSession.current || window.location.pathname !== `/partie/${sessionId}`) return { ok: false as const, error: "stale_session" };
    if (!online || s.state?.session.read_only) return { ok: false as const, error: "unavailable" };
    if (fn === "update_session_settings" && s.state?.session.status === "lobby" && s.state.players.some(p => p.is_me && p.ready)) return { ok: false as const, error: "settings_locked" };
    if (actionLock.current) return { ok: false as const, error: "busy" };
    actionLock.current = true; setBusy(true);
    setActionError(null);
    const res = await s.act(fn, args);
    if (!res.ok && res.error !== "stale_round" && fn !== "play_move") setActionError(errorMessage(res.error));
    actionLock.current = false; setBusy(false);
    return res;
  }

  if (s.loading && !s.state) return <PageLoading />;
  if (!s.state) {
    return (
      <SubPage backTo="/accueil">
        <main className="page page--bare">
          <div className="empty">
            <Illustration name="16-reconnexion" />
            <h2 className="t-section">{s.error && s.error !== "network" ? t("game.notFound") : "Connexion en cours"}</h2>
            {s.error && s.error !== "network" ? <Link className="btn btn--auto" to="/accueil">{t("game.home")}</Link> : <button className="btn btn--auto" onClick={() => void s.load()}>{t("common.retry")}</button>}
          </div>
        </main>
      </SubPage>
    );
  }

  const st = s.state;
  const me = st.players.find((p) => p.is_me);
  const partner = st.players.find((p) => !p.is_me);
  const partnerName = partner?.display_name || "?";
  const partnerHere = Boolean(partner?.user_id && s.present.includes(partner.user_id));
  const rounds = isRounds(st);
  const board = isBoard(st);
  const questionnaire = board && isQuestionnaireMech((st.game.config as unknown as { mechanic?: string }).mechanic);
  const mech = (st.game.config as unknown as { mechanic?: string }).mechanic;
  const word = board && isWordMech(mech);
  const conversation = board && (isConversationMech(mech) || word);
  const common = { st, run, busy, online, act: s.act };
  const universe = universeOf(st);
  // Bandeau des packs et parties +18, au début : on peut passer, faire une pause ou arrêter à tout moment.
  const adultStart = (st.game.content_level === "intime" || Boolean(st.game.adult_active)) && st.session.current_round <= 1;
  const showOptions = rounds && hasOptions(st) && ["lobby", "playing", "paused"].includes(st.session.status) && !st.session.read_only;
  const playing = st.session.status === "playing";
  const activeSession = ["lobby", "playing", "paused"].includes(st.session.status) && !st.session.read_only;

  const kit = redKitOf(st);
  const background = st.session.status === "paused" ? RED_SCREENS.pause.background : st.session.status === "lobby" ? RED_SCREENS.salon.background : kit.background;
  return (
    <SessionRecoveryContext.Provider value={s.recoveryEpoch}>
    <div className={`subpage session-shell red-scope${playing ? " session-console" : ""}`} data-session-status={st.session.status} data-red-layout={kit.layout}>
      <GameShell background={background}>
      <GameHeader title={st.session.status === "lobby" ? "Préparer la partie" : st.game.title} reduceTo="/accueil"
        onReduce={() => { leavingSession.current = true; }} onMenu={() => setCommands(true)} menuOpen={commands}
        onChat={duo.active ? () => setChat(true) : undefined} chatUnread={duo.chatUnread ?? 0} />
      <main className="page page--bare page--read session-with-chat red-main" aria-label={playing ? "Console de jeu" : "Partie"}>
        <div className="session-notices">
          <ReconnectBanner online={online} networkError={s.error === "network"} onRetry={() => void s.load()} />
          {online && s.error !== "network" && <ConnectionNotice online={online} channel={s.channel} networkError={false} onRetry={() => void s.load()} />}
          {actionError && <Alert>{actionError}</Alert>}
        </div>

        {st.session.status === "lobby" && <RedLobby st={st} kit={kit} me={me} partner={partner} partnerHere={partnerHere} busy={busy} online={online} run={run}
          onRules={() => setRules(true)} onOptions={showOptions ? () => setOptions(true) : undefined} />}
        {playing && <SessionPlayers st={st} partnerHere={partnerHere} />}
        {playing && showRoundProgress(st) && <RoundProgress current={st.session.current_round} total={st.session.total_rounds}
          label={(st.game.config as unknown as { code?: string }).code === "G08" ? "Tour" : "Manche"} />}
        {playing && adultStart && <p className="session-adult-note"><Icon name="shield-check" size={16} />+18 · Tu peux passer à tout moment.</p>}
        {playing && <div className="session-play-area"><Stage u={universe} compact>{word ? <WordPlaying c={common} /> : conversation ? <ConversationPlaying c={common} /> : questionnaire ? <QuestionnairePlaying c={common} /> : board ? <BoardPlaying {...common} /> : rounds ? <RoundsPlaying {...common} /> : <Playing st={st} partnerName={partnerName} partner={partner} busy={busy} online={online} run={run} />}</Stage></div>}
        {st.session.status === "paused" && <PausedPanel st={st} userId={userId} partnerName={partnerName} busy={busy} online={online} run={run} />}
        {(st.session.status === "ended" || st.session.status === "closed") && <Stage u={universe}>{(conversation
          ? <ConversationResults c={common} navigate={navigate} />
          : questionnaire
          ? <QuestionnaireResults c={common} navigate={navigate} />
          : board
          ? <BoardResults c={common} navigate={navigate} />
          : rounds
          ? <RoundsResults c={common} navigate={navigate} />
          : <Results st={st} me={me} partner={partner} busy={busy} online={online} run={run} navigate={navigate} />)}</Stage>}
        {st.session.status === "ended" && !st.session.read_only && <AfterGame onOpenChat={() => setChat(true)} />}
        {st.session.status === "abandoned" && (
          <section className="empty">
            <Illustration name="17-pause" />
            <h2 className="t-section">{t("game.abandoned")}</h2>
            <Link className="btn btn--auto" to="/accueil">{t("game.home")}</Link>
          </section>
        )}


      </main>
      </GameShell>

      {commands && <Sheet title="Commandes de la partie" onClose={() => setCommands(false)}>
        <div className="session-command-menu stack stack--2">
          <button className="btn btn--secondary" onClick={() => setRules(true)}><Icon name="book-open" />Règles</button>
          {showOptions && <button className="btn btn--secondary" onClick={() => setOptions(true)}><Icon name="settings" />{t("rounds.options")}</button>}
          {playing && <button className="btn btn--secondary" disabled={busy || !online} onClick={async () => { const result = await run("set_paused", { p_paused: true }); if (result.ok) setCommands(false); }}><Icon name="pause" />Pause</button>}
          {activeSession ? <button className="btn btn--secondary" disabled={busy} onClick={() => setConfirmQuit(true)}><Icon name="logout" />Quitter</button>
            : <Link className="btn btn--secondary" to="/accueil"><Icon name="logout" />Quitter</Link>}
        </div>
      </Sheet>}
      {confirmQuit && (
        <ConfirmDialog title={t("game.quitTitle")} text={st.session.status === "lobby" ? "Quitter annule ce salon pour vous deux. Aucune partie ne commencera." : t("game.quitText", { name: partnerName })} confirmLabel={t("game.quit")} danger busy={busy} disabled={!online}
          onCancel={() => setConfirmQuit(false)}
          onConfirm={async () => {
            const res = await run("abandon_session");
            if (res.ok) { setConfirmQuit(false); navigate("/accueil"); }
          }}>
          {!online && <Alert kind="info">Reconnecte-toi pour confirmer l’arrêt de la partie.</Alert>}
          {actionError && <Alert>{actionError}</Alert>}
        </ConfirmDialog>
      )}
      {chat && <ChatPanel inGame onClose={() => setChat(false)} />}
      {options && <OptionsSheet c={{ ...common, busy: busy || Boolean(st.session.read_only) || (st.session.status === "lobby" && Boolean(me?.ready)) }} onClose={() => setOptions(false)} />}
      {rules && <RulesSheet title={st.game.title} rules={st.game.rules} onClose={() => setRules(false)} />}
    </div>
    </SessionRecoveryContext.Provider>
  );
}

/** Manche i/N seulement quand N est le vrai nombre de manches ; les jeux à objectif (points, victoires) affichent leur objectif. */
const TARGET_MECHS = new Set(["nd_pig", "nd_name_three_call", "battleship", "dots_boxes", "tic_tac_toe", "rps"]);
function showRoundProgress(st: SessionState) {
  const cfg = st.game.config as unknown as { mechanic?: string; parameters?: { target?: number; wins_target?: number } };
  return st.session.total_rounds > 1 && !TARGET_MECHS.has(cfg.mechanic ?? "") && !cfg.parameters?.target && !cfg.parameters?.wins_target;
}

/** Les identités, scores et verrous proviennent du snapshot ; aucune réponse privée n'est déduite. */
function SessionPlayers({ st, partnerHere }: { st: SessionState; partnerHere: boolean }) {
  const round = st.rounds.find(r => r.round_no === st.session.current_round);
  const card = round?.card as unknown as { mech?: string; phase?: string; turn?: number; active?: number; author?: number; done?: boolean; locked?: Record<number, boolean> } | undefined;
  const lockLabel = card?.mech === "battleship" ? card.phase === "placement" ? "Flotte prête" : null
    : card?.mech === "rps" ? "Choix validé"
    : isConversationMech(card?.mech) ? "Réponse validée" : null;
  const actor = card?.turn ?? card?.active ?? (card?.phase === "write" ? card?.author : undefined);
  // Dé, morpion et PFC affichent déjà leurs compteurs vers l'objectif : pas de second score dans le bandeau.
  const mech = (st.game.config as unknown as { mechanic?: string }).mechanic ?? "";
  const board = ["nd_pig", "rps", "tic_tac_toe"].includes(mech) ? null : scoreboard(st);
  const scoreLabel = undefined;
  return <DuoStrip people={st.players.map(p => {
    const active = !card?.done && actor === p.seat;
    const status = active ? (p.is_me ? "À toi de jouer" : "À son tour") : !card?.done && card?.locked?.[p.seat] && lockLabel ? lockLabel
      : p.is_me ? undefined : partnerHere ? "Connecté·e" : "Déconnecté·e";
    return { player: p, active, status, presence: p.is_me ? undefined : partnerHere ? "here" as const : "away" as const,
      score: board ? board.scores[p.seat as 1 | 2] : undefined, scoreLabel };
  })} />;
}

/** Pause partagée : chronos suspendus ; la partie ne reprend qu'avec l'accord de vous deux. */
function PausedPanel({ st, userId, partnerName, busy, online, run }: {
  st: SessionState; userId: string | null; partnerName: string; busy: boolean; online: boolean; run: Run;
}) {
  const resume = st.session.pause_state?.resume ?? [];
  const mine = st.my_seat != null && resume.includes(st.my_seat);
  const theirs = st.players.some((p) => !p.is_me && resume.includes(p.seat));
  return (
    <section className="empty enter" aria-live="polite">
      <GameHero hero={RED_SCREENS.pause.hero} size="sm" eager />
      <h2 className="t-section">{t("game.pausedTitle")}</h2>
      <p>{st.session.paused_by === userId ? t("game.pausedByYou") : t("game.pausedBy", { name: partnerName })}</p>
      <p className="t-meta">{t("rhythm.pauseTimers")}</p>
      {mine ? (
        <p className="t-small strong row" style={{ justifyContent: "center" }}><Icon name="clock" size={18} />{t("rhythm.resumeWaiting", { name: partnerName })}</p>
      ) : (
        <>
          {theirs && <p className="t-small strong">{t("rhythm.partnerReady", { name: partnerName })}</p>}
          <button className="btn btn--auto" disabled={busy || !online} onClick={() => run("set_paused", { p_paused: false })}>
            {theirs ? t("game.resume") : t("rhythm.askResume")}
          </button>
        </>
      )}
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
  if (step) return <PortraitStep key={`${round.round_no}-${step}`} st={st} round={round} stepKey={step} partnerName={partnerName} partner={partner} busy={busy} online={online} run={run} />;
  return (
    <section className="stack stack--6 enter" aria-live="polite">
      <Illustration name="09-attente-douce" className="public__art" />
      <div className="page-header center">
        <h1 className="t-page">{t("game.sentTitle")}</h1>
        <p>{t("game.waitingPartner", { name: partnerName })}</p>
      </div>
      <div className="card" style={{ gap: 0, paddingBlock: 4 }}>
        {st.players.map((p) => {
          const done = steps.every((k) => answerOf(round, k, p.seat));
          return (
            <div className="player" key={p.seat}>
              <Avatar name={p.display_name} path={p.avatar_path} size={44} me={p.is_me} />
              <div className="grow stack" style={{ gap: 2 }}>
                <span className="t-card">{p.display_name}</span>
                <span className="status">{done ? <><Icon name="check" size={16} />{t("game.sent")}</> : <Loading label={t("game.preparing")} />}</span>
              </div>
            </div>
          );
        })}
      </div>
      <Alert kind="info"><Icon name="lock" size={18} />{st.game.rules.privacy}</Alert>
      <p className="center t-meta">{t("game.noRush")}</p>
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
  const [confirmSkip, setConfirmSkip] = useState(false);
  const index = cfg.steps.findIndex((x) => x.key === stepKey);
  const total = cfg.steps.length + 1;
  const valid = useMemo(() => selection.filter((id) => round.card.words.some((w) => w.id === id)), [selection, round]);
  const vars = { partner: partnerName };

  async function submit(skip: boolean) {
    const res = await run("submit_answer", { p_round: round.round_no, p_step: stepKey, p_payload: skip ? null : { words: valid }, p_skip: skip });
    if (res.ok) clearDraft();
  }

  return (
    <section className="console-round portrait-console reading-games enter">
      <div className="console-progress stack stack--2">
        <div className="row row--between">
          <span className="t-small strong">{texts.title}</span>
          <span className="t-meta">{t("game.step", { n: index + 1, total })}</span>
        </div>
        <div className="progress" role="progressbar" aria-valuemin={1} aria-valuemax={total} aria-valuenow={index + 1} aria-label={t("game.step", { n: index + 1, total })}>
          <span style={{ width: `${((index + 1) / total) * 100}%` }} />
        </div>
      </div>
      <ReadingRegion className="console-question portrait-question" label="Question et consigne" resetKey={`${round.round_no}-${stepKey}`}>
        <h1 className="t-page">{fill(texts.prompt, vars)}</h1>
        <p>{fill(texts.hint, vars)}</p>
      </ReadingRegion>
      <ul className="word-grid console-answer-zone" aria-label={fill(texts.hint, vars)}>
        {round.card.words.map((w) => {
          const on = valid.includes(w.id);
          return (
            <li key={w.id}>
              <button className="word" aria-pressed={on} disabled={!on && valid.length >= cfg.pick} onClick={() => setSelection(toggleWord(valid, w.id, cfg.pick))}>
                <span>{wordLabel(w, form)}</span>
                <span className="word__check" aria-hidden="true"><Icon name="check" size={14} /></span>
              </button>
            </li>
          );
        })}
      </ul>
      <div className="action-bar console-round-controls">
        <p className="t-meta row" style={{ justifyContent: "center" }}><Icon name="lock" size={16} />{t("game.privateHint")}</p>
        <p className="center t-small strong" aria-live="polite">{t("game.selected", { n: valid.length, max: cfg.pick })}</p>
        <button className="btn" disabled={busy || !online || valid.length !== cfg.pick} onClick={() => void submit(false)}>
          {busy ? t("common.sending") : texts.confirm}<Icon name="arrow-right" />
        </button>
        <button className="btn btn--quiet" disabled={busy || !online} onClick={() => setConfirmSkip(true)}>{t("game.skip")}</button>
      </div>
      {confirmSkip && (
        <ConfirmDialog title={t("game.skipTitle")} text={t("game.skipText")} confirmLabel={t("game.skip")}
          onCancel={() => setConfirmSkip(false)} onConfirm={() => { setConfirmSkip(false); void submit(true); }} />
      )}
    </section>
  );
}

function WordList({ ids, found, words, form, label }: { ids: string[]; found: string[]; words: Map<string, Round["card"]["words"][number]>; form: Player["word_form"]; label: string }) {
  return (
    <ul className="word-grid" aria-label={label}>
      {ids.map((id) => (
        <li key={id} className={`word word--static ${found.includes(id) ? "word--match" : ""}`}>
          {found.includes(id) && <Icon name="check" size={16} label={t("portrait.matchLabel")} />}
          {words.get(id) ? wordLabel(words.get(id)!, form) : id}
        </li>
      ))}
    </ul>
  );
}

function Results({ st, me, partner, busy, online, run, navigate }: {
  st: SessionState; me?: Player; partner?: Player; busy: boolean; online: boolean; run: Run; navigate: (to: string) => void;
}) {
  const [view, setView] = useState<"partner" | "mine" | "end">("partner");
  const round = st.rounds.find((r) => r.revealed);
  const words = new Map((round?.card.words ?? []).map((w) => [w.id, w]));
  const partnerName = partner?.display_name || "?";

  if (!round || (st.session.status === "closed" && !round.answers.length)) {
    return (
      <section className="empty">
        <Illustration name="11-fin-de-partie" />
        <h2 className="t-section">{t("game.closed")}</h2>
        <p>{t("game.notKept")}</p>
        <Link className="btn btn--auto" to="/accueil">{t("game.home")}</Link>
      </section>
    );
  }

  function Portrait({ about, guesser }: { about?: Player; guesser?: Player }) {
    if (!about) return null;
    const r = portraitReveal(round!, about.seat);
    const name = about.display_name || "?";
    return (
      <div className="stack stack--4 enter">
        <div className="page-header">
          <span className="t-meta" style={{ letterSpacing: ".08em", textTransform: "uppercase" }}>{t("game.revealTitle")}</span>
          <h1 className="t-page">{about.is_me ? t("portrait.revealMine") : t("portrait.revealPartner", { name })}</h1>
          {r.chosen && r.guessed && <p>{t("portrait.found", { n: r.found.length })}</p>}
        </div>
        <div className="card stack">
          <h2 className="t-card row"><Avatar name={name} path={about.avatar_path} size={36} me={about.is_me} />{about.is_me ? t("portrait.chosenByMe") : t("portrait.chosenBy", { name })}</h2>
          {r.chosen ? <WordList ids={r.chosen} found={r.found} words={words} form={about.word_form} label={t("portrait.chosenBy", { name })} /> : <p className="muted">{t("portrait.noAnswer", { name })}</p>}
        </div>
        {guesser && (
          <div className="card stack">
            <h2 className="t-card row"><Avatar name={guesser.display_name} path={guesser.avatar_path} size={36} me={guesser.is_me} />{guesser.is_me ? t("portrait.guessedByMe") : t("portrait.guessedBy", { name: guesser.display_name })}</h2>
            {r.guessed ? <WordList ids={r.guessed} found={r.found} words={words} form={about.word_form} label={t("portrait.guessedBy", { name: guesser.display_name })} /> : <p className="muted">{t("portrait.noAnswer", { name: guesser.display_name })}</p>}
          </div>
        )}
        <div className="card card--soft"><p className="t-card">{t("portrait.discuss")}</p></div>
      </div>
    );
  }

  if (view !== "end") {
    return (
      <>
        {view === "partner" ? <Portrait about={partner} guesser={me} /> : <Portrait about={me} guesser={partner} />}
        <div className="action-bar">
          <button className="btn" onClick={() => setView(view === "partner" ? "mine" : "end")}>
            {view === "partner" ? t("portrait.revealMine") : t("common.continue")}<Icon name="arrow-right" />
          </button>
          {view === "mine" && <button className="btn btn--quiet" onClick={() => setView("partner")}>{t("portrait.revealPartner", { name: partnerName })}</button>}
        </div>
      </>
    );
  }

  const ended = st.session.status === "ended" && !st.session.read_only;
  const bothKeep = st.players.every((p) => p.keep_memory);
  return (
    <section className="stack stack--6 enter">
      <Illustration name="11-fin-de-partie" className="public__art" />
      <div className="page-header center">
        <h1 className="t-page">{t("game.endTitle")}</h1>
        <p>{t("game.endText", { title: st.game.title })}</p>
      </div>
      {ended && (
        <div className="group">
          <label className="switch-row">
            <span className="switch-row__text">
              <span>{t("game.keepMemory")}</span>
              <span className="t-meta">{bothKeep ? t("game.keepBoth") : me?.keep_memory ? t("game.keepWaiting", { name: partnerName }) : t("game.keepMemoryHint")}</span>
            </span>
            <input className="switch" type="checkbox" role="switch" checked={Boolean(me?.keep_memory)} disabled={busy || !online}
              onChange={(e) => run("set_keep_memory", { p_keep: e.target.checked })} />
          </label>
        </div>
      )}
      {ended && (
        <div className="stack">
          <button className="btn" disabled={busy || !online} onClick={async () => {
            const res = await rpc<{ session_id: string }>("create_session", { p_game: st.session.game_id });
            if (res.ok) navigate(`/partie/${res.session_id}`);
          }}>{t("game.replay")}</button>
          <button className="btn btn--secondary" disabled={busy || !online} onClick={async () => { await run("close_session"); navigate("/bibliotheques"); }}>{t("game.otherGame")}</button>
        </div>
      )}
      <Link className="btn btn--quiet" to="/accueil">{t("game.home")}</Link>
      <button className="btn btn--quiet" onClick={() => setView("partner")}>{t("portrait.revealPartner", { name: partnerName })}</button>
    </section>
  );
}
