import { useEffect, useMemo, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router";
import { fill, t } from "../i18n";
import { errorMessage } from "../lib/errors";
import { rpc } from "../lib/supabase";
import { useOnline } from "../lib/useOnline";
import { useAuth } from "../auth/AuthProvider";
import { useDuo } from "../duo/DuoProvider";
import { ChatPanel, ChatLauncher } from "../duo/Chat";
import { SubPage } from "../components/AppShell";
import { Avatar } from "../components/Avatar";
import { Alert, Art, ConfirmDialog, Icon, Illustration, Loading, PageLoading, Sheet } from "../components/ui";
import { RulesSheet } from "../components/RulesSheet";
import { ART_BY_PACK, artOf } from "../screens/Libraries";
import type { Player, Round, SessionState } from "../lib/types";
import { answerOf, nextStep, portraitReveal, toggleWord, wordLabel } from "./portrait";
import { useDraft, useSession } from "./useSession";
import { OptionsSheet, RoundsPlaying, RoundsResults, hasOptions, isRounds } from "./rounds/RoundsGame";
import { BoardPlaying, BoardResults, isBoard } from "./board/BoardGame";
import { Hero, Stage } from "./premium/Stage";
import { NudgeButton } from "./premium/Nudge";
import { universeOf } from "./premium/universe";
import { SessionRecoveryContext } from "./premium/BoardPieces";
import { QuestionnairePlaying, QuestionnaireResults, isQuestionnaireMech } from "./board/QuestionnaireGames";
import { ConversationPlaying, ConversationResults, isConversationMech } from "./board/ConversationGames";
import { WordPlaying, isWordMech } from "./board/WordGames";
import { LaunchFilm } from "./media/LaunchFilm";
import { ConnectionNotice } from "./ConnectionNotice";
import { AfterGame } from "../parcours/AfterGame";
import { ReadingRegion } from "./ReadingRegion";
import "../styles/astra-console.css";
import "../styles/salon-proposal.css";
import "../styles/board-session-refinement.css";

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

  return (
    <SessionRecoveryContext.Provider value={s.recoveryEpoch}>
    <div className={`subpage session-shell${playing ? " session-console" : ""}`} data-session-status={st.session.status}>
      <header className="session-toolbar">
        <div className="session-toolbar__identity">
          <span className="session-toolbar__state">{st.session.status === "lobby" ? "Votre salon" : st.session.status === "paused" ? "En pause" : playing ? "À vous de jouer" : "Votre partie"}</span>
          <h1>{st.session.status === "lobby" ? "Votre salon" : st.game.title}</h1>
        </div>
        <Link className="session-toolbar__reduce" to="/accueil" aria-label="Réduire la partie et revenir à l’accueil" title="La partie continue ; retrouve-la sur l’accueil."
          onClick={event => { if (!event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey && event.button === 0) leavingSession.current = true; }}>
          <Icon name="minus" size={19} /><span>Réduire</span>
        </Link>
        <nav className="session-toolbar__commands" aria-label="Commandes de la partie">
          {st.session.status !== "lobby" && <button onClick={() => setRules(true)}><Icon name="book-open" size={17} />Règles</button>}
          {showOptions && st.session.status !== "lobby" && <button onClick={() => setOptions(true)}><Icon name="settings" size={17} />{t("rounds.options")}</button>}
          {playing && <button disabled={busy || !online} onClick={() => run("set_paused", { p_paused: true })}><Icon name="pause" size={17} />Pause</button>}
          {activeSession
            ? <button className="session-toolbar__quit" disabled={busy} onClick={() => setConfirmQuit(true)}><Icon name="logout" size={17} />Quitter</button>
            : <Link className="session-toolbar__quit" to="/accueil"><Icon name="logout" size={17} />Quitter</Link>}
        </nav>
      </header>
      <main className="page page--bare page--read session-with-chat" aria-label={playing ? "Console de jeu" : "Partie"}>
        <div className="session-notices">
          <ConnectionNotice online={online} channel={s.channel} networkError={s.error === "network"} onRetry={() => void s.load()} />
          {actionError && <Alert>{actionError}</Alert>}
        </div>

        {st.session.status === "lobby" && <Lobby st={st} me={me} partner={partner} partnerHere={partnerHere} busy={busy} online={online} run={run}
          onRules={() => setRules(true)} onOptions={showOptions ? () => setOptions(true) : undefined} />}
        {playing && <SessionPlayers st={st} partnerHere={partnerHere} />}
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
      {duo.active && <ChatLauncher withNav={false} onOpen={() => setChat(true)} />}
      {chat && <ChatPanel inGame onClose={() => setChat(false)} />}
      {options && <OptionsSheet c={common} onClose={() => setOptions(false)} />}
      {rules && <RulesSheet title={st.game.title} rules={st.game.rules} onClose={() => setRules(false)} />}
    </div>
    </SessionRecoveryContext.Provider>
  );
}

/** Les identités et verrous proviennent du snapshot ; aucune réponse privée n'est déduite. */
function SessionPlayers({ st, partnerHere }: { st: SessionState; partnerHere: boolean }) {
  const round = st.rounds.find(r => r.round_no === st.session.current_round);
  const card = round?.card as unknown as { mech?: string; phase?: string; turn?: number; done?: boolean; locked?: Record<number, boolean> } | undefined;
  const lockLabel = card?.mech === "battleship" ? card.phase === "placement" ? "Flotte prête" : null
    : card?.mech === "rps" ? "Choix validé"
    : isConversationMech(card?.mech) ? "Réponse validée" : null;
  return <div className="session-player-strip" aria-label="Les joueurs">
    {st.players.map(p => <div className="session-player-strip__person" key={p.seat}>
      <Avatar name={p.display_name} path={p.avatar_path} size={28} me={p.is_me} />
      <div><span className="session-player-strip__name">{p.display_name || (p.is_me ? "Toi" : "Partenaire")}</span>
        <span className="session-player-strip__status">{!card?.done && card?.turn === p.seat ? (p.is_me ? "À toi de jouer" : "À son tour") : !card?.done && card?.locked?.[p.seat] && lockLabel ? lockLabel : p.is_me ? "Toi" : partnerHere ? "En ligne" : "Partenaire"}</span></div>
    </div>)}
  </div>;
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
      <Illustration name="17-pause" />
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

function lobbyArt(st: SessionState) {
  const cfg = st.game.config as unknown as { mechanic?: string; pack?: { code?: string }; test?: { instrument?: string } };
  if (cfg.mechanic === "pack_conversation" && ART_BY_PACK[cfg.pack?.code ?? ""]) return ART_BY_PACK[cfg.pack!.code!];
  return artOf({id:st.session.game_id,mechanic:cfg.mechanic ?? "",meta:{}});
}

function LobbyFacts({st}:{st:SessionState}) {
 const cfg=st.game.config as unknown as {mechanic:string;parameters?:{target?:number;wins_target?:number;choice_timeout_seconds?:number;boxes?:number;rows?:number;columns?:number;fleet?:number[];shots_per_turn?:number};test?:{count:number};pack?:{set_size?:number}};
 const p=cfg.parameters ?? {};const facts:string[]=[];
 if(cfg.mechanic === "nd_pig")facts.push(`${p.target ?? 30} points à conserver pour gagner`);
 else if(p.wins_target)facts.push(`${p.wins_target} victoires pour gagner`,`${p.choice_timeout_seconds ?? 30} s pour choisir`);
 else if(cfg.mechanic === "battleship")facts.push(`${p.rows ?? 10} × ${p.columns ?? 10} cases`,`${p.fleet?.length ?? 5} navires · ${p.shots_per_turn ?? 1} tir par tour`);
 else if(cfg.mechanic === "dots_boxes")facts.push(`${p.boxes ?? 16} carrés`,"Un carré fermé te fait rejouer");
 else if(cfg.mechanic === "test_form" && cfg.test?.count)facts.push(`${cfg.test.count} questions · ordre préservé`);
 else if(cfg.mechanic === "pack_conversation")facts.push(cfg.pack?.set_size ? `Séries de ${cfg.pack.set_size} questions` : "À votre rythme, carte après carte");
 else if(!Object.keys(st.game.config.settings ?? {}).length)facts.push(`${st.session.total_rounds} manches prévues`);
 if(!facts.length)return null;
 return <div className="lobby-facts" aria-label="Règles de cette activité">{facts.map(f=><span className="t-meta" key={f}>{f}</span>)}</div>;
}

function Lobby({ st, me, partner, partnerHere, busy, online, run, onOptions, onRules }: {
  st: SessionState; me?: Player; partner?: Player; partnerHere: boolean; busy: boolean; online: boolean; run: Run; onOptions?: () => void; onRules: () => void;
}) {
  const [showDescription, setShowDescription] = useState(false);
  const [launching,setLaunching]=useState(false);
  // Moteur 2.1.0 : les réglages passent par la fenêtre d'options (avec les préférences privées).
  const settings = onOptions ? {} : st.game.config.settings ?? {};
  // Questions +18 : aucune permission, elles font partie du jeu. Le salon le signale simplement.
  const sexual = st.game.content_level === "intime" || Boolean(st.game.adult_available);
  const disabled = busy || !online || launching || st.session.read_only || !me;
  const readyCount = st.players.filter(p => p.ready).length;
  const cfg = st.game.config as unknown as {mechanic:string;parameters?:{target?:number};turn?:string};
  const kind = cfg.mechanic === "test_form" ? "Se découvrir" : cfg.mechanic === "pack_conversation" ? "Questions à deux" : (cfg.turn === "simultaneous" || cfg.mechanic === "nd_two_truths") ? "À vous deux" : "À tour de rôle";
  return (
    <section className="lobby lobby-proposal enter">
      <h1 className="sr-only">{t("game.lobbyTitle")}</h1>
      <div className="salon-crew">
        <div className="salon-section-head"><h3>Les joueurs</h3><span className="salon-ready-count" aria-live="polite">{readyCount}/2 prêts</span></div>
        <div className="salon-players">
        {[me, partner].filter(Boolean).map((p) => (
          <div className={`salon-player${p!.ready ? " is-ready" : ""}`} key={p!.seat}>
            <div className="salon-player__avatar"><Avatar name={p!.display_name} path={p!.avatar_path} size={44} me={p!.is_me} /></div>
            <div className="salon-player__info">
              <span className="salon-player__name">{p!.display_name || (p!.is_me ? t("game.youCap") : "Partenaire")}</span>
              <span className="salon-player__status"><Icon name={p!.ready ? "check" : "clock"} size={13} />{p!.ready ? "Disponible" : "À confirmer"}</span>
              {!p!.is_me && partnerHere && <span className="salon-player__presence">{t("game.here")}</span>}
            </div>
          </div>
        ))}
        {!partner && <div className="salon-player salon-player--empty"><span className="salon-player__name">Deuxième joueur</span><span className="salon-player__status">En attente</span></div>}
        </div>
      </div>

      <div className="salon-activity">
        <div className="salon-activity__intro">
          <div className="salon-activity__identity">
            <span className="salon-kicker">{kind}</span>
            <h2>{st.game.title}</h2>
            <span className="salon-private"><Icon name="lock-keyhole" size={14} />{t("game.roomBadge")}</span>
          </div>
          <div className="salon-activity__art" aria-hidden="true">
            {universeOf(st) ? <Hero u={universeOf(st)!} size={96} /> : <Art name={lobbyArt(st)} size={96} />}
          </div>
        </div>
        {st.game.rules.objective && <p className="lobby-description">{st.game.rules.objective}</p>}
        {sexual && <p className="session-adult-note"><Icon name="shield-check" size={16} />+18 · Tu peux passer à tout moment.</p>}
        <div className="lobby-guide" aria-label="Découvrir cette activité">
          <button className="lobby-guide__button" onClick={() => setShowDescription(true)}><Icon name="info" size={18} /><span>Description</span></button>
          <button className="lobby-guide__button" onClick={onRules}><Icon name="book-open" size={18} /><span>Règles</span></button>
        </div>
      </div>


      <div className="salon-config">
        <div className="salon-section-head"><h3>{Object.keys(settings).length || onOptions ? "Réglages" : "Le format"}</h3><Icon name="settings" size={17} /></div>
        {onOptions && <button className="btn btn--secondary" disabled={disabled} onClick={onOptions}><Icon name="settings" size={18} />{t("rounds.options")}</button>}
        <div className="lobby-settings">
        {Object.entries(settings).map(([key, def]) => def.options.length <= 4 ? (
          <fieldset className="salon-setting" key={key} disabled={disabled}>
            <legend>{def.label}</legend>
            <div className="salon-setting__choices" style={{gridTemplateColumns:`repeat(${def.options.length}, minmax(0, 1fr))`}}>
              {def.options.map(opt => <label className="salon-setting__choice" key={String(opt)}>
                <input className="sr-only" type="radio" name={`salon-${key}`} checked={String(st.session.settings[key] ?? def.default) === String(opt)}
                  onChange={() => void run("update_session_settings",{p_settings:{[key]:opt}})} />
                <span>{String(opt)}</span>
              </label>)}
            </div>
          </fieldset>
        ) : (
          <label className="field" key={key}><span className="field__label">{def.label}</span>
            <select className="input" value={String(st.session.settings[key] ?? def.default)} disabled={disabled}
              onChange={e => { const value=def.options.find(opt => String(opt) === e.target.value); if(value !== undefined) void run("update_session_settings",{p_settings:{[key]:value}}); }}>
              {def.options.map(opt => <option key={String(opt)} value={String(opt)}>{String(opt)}</option>)}
            </select>
          </label>
        ))}
        </div>
        {!Object.keys(settings).length && !onOptions && <LobbyFacts st={st} />}
        {Object.keys(settings).length>0 && <p className="salon-config__hint">Les deux joueurs reconfirment après un changement.</p>}
      </div>
      <div className="salon-launch">
        <button className={`btn${me?.ready ? " btn--secondary" : ""}`} disabled={disabled} onClick={() => { if(me?.ready) void run("set_ready",{p_ready:false}); else setLaunching(true); }}>
          <Icon name={me?.ready ? "check" : partner?.ready ? "play" : "check"} size={19} />
          {launching ? "Préparation…" : busy ? t("common.sending") : me?.ready ? "Annuler ma disponibilité" : partner?.ready ? "Lancer la partie" : t("game.ready")}
        </button>
        {me?.ready && partner && !partner.ready && <p className="salon-launch__status">En attente de {partner.display_name || "l’autre joueur"}</p>}
        {me?.ready && partner && !partner.ready && <NudgeButton st={st} partner={partner} />}
      </div>
      {launching && me && <LaunchFilm sessionId={st.session.id} userId={me.user_id ?? `seat-${me.seat}`} title={st.game.title} onComplete={() => { setLaunching(false); if(online && !st.session.read_only) void run("set_ready",{p_ready:true}); }} />}
      {showDescription && <Sheet title={<h2 className="t-section">Description · {st.game.title}</h2>} onClose={() => setShowDescription(false)}><p>{st.game.rules.objective || st.game.title}</p><LobbyFacts st={st} /><p className="t-small">{st.game.rules.privacy}</p></Sheet>}
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
