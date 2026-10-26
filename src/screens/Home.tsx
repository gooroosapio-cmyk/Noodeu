import { useRef, useState } from "react";
import { Link } from "react-router";
import { t } from "../i18n";
import { useAuth } from "../auth/AuthProvider";
import { useDuo } from "../duo/DuoProvider";
import { DuoIdentity } from "../duo/DuoIdentity";
import { DuoSwitcher } from "../duo/DuoSwitcher";
import { useCarouselAutoplay } from "./useCarouselAutoplay";
import { useHomeMoment } from "./useHomeMoment";
import { PendingRequest, useInviteActions } from "../duo/InviteScreens";
import { Alert, ConfirmDialog, Icon, PageLoading, Sheet, formatDate } from "../components/ui";
import { artOf, GameThumb } from "./Libraries";
import { useCatalog } from "./catalog";
import { DONE, DuoAvatars, OPEN, SessionLine, dayLabel, minutesOf, useSessions } from "./v7parts";

const CONVERSATION = /^(nd_|pack_conversation|test_form)/;
const roundWord = (mechanic?: string) => (mechanic && CONVERSATION.test(mechanic) ? "Question" : "Manche");

function PendingInvitationCard() {
  const { out, share, copy, revoke } = useInviteActions();
  const [menu, setMenu] = useState(false);
  const [confirm, setConfirm] = useState(false);
  if (!out) return null;
  return (
    <section className="card hero center">
      <DuoIdentity duo={null} showStatus={false} center size={60} />
      <div className="stack stack--2">
        <h2 className="t-card">{t("home.pendingTitle")}</h2>
        <p className="t-meta">{t("home.pendingUntil", { date: formatDate(out.expires_at, true) })}</p>
      </div>
      <div className="row hero__cta">
        <button className="btn grow" onClick={() => void share()}><Icon name="share" />{t("home.share")}</button>
        <button className="icon-btn icon-btn--soft" aria-haspopup="dialog" aria-label={t("home.moreActions")} onClick={() => setMenu(true)} style={{ minWidth: 52, minHeight: 52 }}>
          <Icon name="chevron-down" />
        </button>
      </div>
      {menu && (
        <Sheet title={<h2 className="t-section">{t("home.pendingTitle")}</h2>} onClose={() => setMenu(false)}>
          <p className="code-box">{out.code}</p>
          <button className="btn btn--secondary" onClick={() => { void copy(); setMenu(false); }}><Icon name="copy" />{t("home.copy")}</button>
          <button className="btn btn--danger" onClick={() => { setMenu(false); setConfirm(true); }}>{t("home.cancelInvite")}</button>
        </Sheet>
      )}
      {confirm && (
        <ConfirmDialog title={t("home.cancelInvite")} text={t("invite.revokeText")} confirmLabel={t("home.cancelInvite")} danger
          onCancel={() => setConfirm(false)} onConfirm={() => { setConfirm(false); void revoke(); }} />
      )}
    </section>
  );
}

export function Home() {
  const { userId, profile } = useAuth();
  const duo = useDuo();
  const cat = useCatalog(userId);
  const moment = useHomeMoment(duo.active?.id);
  const carousel = useRef<HTMLDivElement>(null);
  const [slide, setSlide] = useState(0);
  const [quick, setQuick] = useState(false);
  function go(index: number) {
    rotation.setPaused(true);
    const node = carousel.current?.children[index] as HTMLElement | undefined;
    if (node) carousel.current?.scrollTo({ left: node.offsetLeft - (carousel.current.firstElementChild as HTMLElement).offsetLeft, behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth" });
  }

  const { active, invitations, openSession } = duo;
  const openRows = useSessions(active && openSession ? active.id : undefined, OPEN, 0, 0);
  const openRow = openRows.rows?.find((r) => r.id === openSession?.id);
  const recent = useSessions(active?.id, DONE, 0, 0);

  let sessionLabel = "", sessionAction = "";
  if (openSession) {
    const map = {
      lobby: [t("home.statusLobby"), t("home.joinLobby")],
      playing: [t("home.statusPlaying"), t("home.resume")],
      paused: [t("home.statusPaused"), t("home.resume")],
      ended: [t("home.statusEnded"), t("home.seeResults")],
    } as const;
    [sessionLabel, sessionAction] = map[openSession.status];
  }
  const sessionGame = openSession ? cat.games.find((g) => g.id === openSession.game_id) : undefined;
  const discover = cat.games.filter((g) => g.implementation === "playable" && g.content_level !== "intime" && !g.meta?.random);
  const featured = discover.filter((g) => /^custom-(G|M)/.test(artOf(g))).sort((a, b) => Number(artOf(b) === "custom-G03") - Number(artOf(a) === "custom-G03"));
  const cards = (quick ? featured.filter((g) => (g.duration_min ?? 99) <= 5) : featured).slice(0, 4);
  const rotation = useCarouselAutoplay(carousel, cards.length);
  if (duo.loading) return <PageLoading />;

  return (
    <main className="page page--tight arcade-home v7-home">

      {duo.error && <Alert>{t("net.loadError")}</Alert>}

      {/* Carte principale : la pause à deux (ou l'invitation). */}
      {active ? (
        <section className="v7-duo-card" aria-label="Votre duo">
          <DuoAvatars me={{ name: profile?.display_name ?? "", path: profile?.avatar_path }} partner={active.partner} />
          <span className="v7-duo-card__text"><strong>{profile?.display_name || "Toi"} &amp; {active.partner?.name || "?"}</strong><small>Votre duo</small></span>
          <DuoSwitcher icon />
        </section>
      ) : invitations.outgoing?.status === "claimed" ? (
        <PendingRequest />
      ) : invitations.outgoing && !invitations.outgoing.expired ? (
        <PendingInvitationCard />
      ) : invitations.incoming ? (
        <section className="card hero center">
          <DuoIdentity duo={null} showStatus={false} center size={60} />
          <p className="t-card">{t("home.waitingAnswer", { name: invitations.incoming.inviter_name })}</p>
          <Link className="btn btn--secondary hero__cta" to="/rejoindre">{t("common.continue")}</Link>
        </section>
      ) : (
        <section className="card hero center">
          <DuoIdentity duo={null} showStatus={false} center size={60} />
          <div className="stack stack--2">
            <h2 className="t-card">{t("home.soloTitle")}</h2>
          </div>
          <Link className="btn hero__cta" to="/inviter">{t("home.invite")}</Link>
          <Link className="btn btn--quiet btn--sm btn--auto" to="/rejoindre">{t("home.haveCode")}</Link>
        </section>
      )}

      <section className="arcade-play" aria-labelledby="arcade-title"
        onMouseEnter={() => rotation.setHover(true)} onMouseLeave={() => rotation.setHover(false)}
        onFocusCapture={() => rotation.setFocus(true)} onBlurCapture={(event) => { if (!event.currentTarget.contains(event.relatedTarget)) rotation.setFocus(false); }}
      >
        <h1 id="arcade-title">À quoi on joue ?</h1>
        <div className="arcade-filters">
          <button className="btn btn--secondary v7-filter--primary" onClick={() => { setQuick(false); requestAnimationFrame(() => go(Math.floor(Math.random() * Math.max(1, featured.slice(0, 4).length)))); }}>Surprise</button>
          <button className="btn btn--secondary" aria-pressed={quick} onClick={() => { setQuick(!quick); go(0); }}>5 minutes</button>
          <a className="btn btn--secondary" href="#arcade-resume">À reprendre</a>
        </div>
        {cat.error ? <Alert>Catalogue indisponible. <button className="btn btn--quiet" onClick={() => void cat.reload()}>Réessayer</button></Alert> : cat.loading ? <p>Chargement des jeux…</p> : !cards.length ? <p>Aucun jeu disponible.</p> : <>
          <div className="arcade-carousel" onPointerDown={() => rotation.setPaused(true)} onKeyDown={() => rotation.setPaused(true)} ref={carousel} aria-label="Jeux à découvrir" onScroll={() => {
            const el = carousel.current; if (!el) return;
            const children = Array.from(el.children) as HTMLElement[];
            const origin = children[0]?.offsetLeft ?? 0;
            setSlide(children.reduce((best, child, i) => Math.abs(child.offsetLeft - origin - el.scrollLeft) < Math.abs(children[best].offsetLeft - origin - el.scrollLeft) ? i : best, 0));
          }}>
            {cards.map((g, i) => <article className="arcade-feature" key={g.id} aria-label={`${i + 1} sur ${cards.length}`}>
              <div><h2>{g.title}</h2>{(g.hook || g.promise) && <p className="arcade-feature__desc">{g.hook || g.promise}</p>}<p className="arcade-feature__time">{g.duration_min ? `${g.duration_min}–${g.duration_max ?? g.duration_min} min` : "À votre rythme"}</p><Link className="btn" to={`/bibliotheques/${g.id}`}>Jouer <Icon name="play" size={18} /></Link></div>
              <GameThumb game={g} size="lg" />
            </article>)}
          </div>
          <div className="arcade-pagination">
            {cards.map((g, i) => <button key={g.id} aria-label={`Afficher ${g.title}`} aria-current={slide === i ? "true" : undefined} onClick={() => go(i)}><span /></button>)}
            {!rotation.reduced && <button className="arcade-autoplay" aria-label={rotation.paused ? "Reprendre le défilement automatique" : "Mettre en pause le défilement automatique"} aria-pressed={rotation.paused} onClick={() => rotation.setPaused(!rotation.paused)}><Icon name={rotation.paused ? "play" : "pause"} size={16} /></button>}
            <button aria-label="Jeu suivant" onClick={() => go((slide + 1) % cards.length)}><Icon name="arrow-right" size={18} /></button>
          </div>
        </>}
      </section>
      <section className="v7-home-pair" aria-label="Votre rendez-vous à deux">
        <article className="v7-question-moment v7-home-tile">
          <h2>Question du moment</h2>
          <p aria-live="polite">{!active ? "Créez votre duo pour découvrir votre question." : moment.loading ? "Votre question arrive…" : moment.data?.question ?? "Question indisponible pour le moment."}</p>
          {moment.error && <button className="btn btn--quiet btn--sm" onClick={moment.refresh}>Réessayer</button>}
        </article>
        {active && openSession ? (
          <Link className="v7-home-tile v7-resume" id="arcade-resume" to={`/partie/${openSession.id}`} aria-label={`${sessionAction} : ${sessionGame?.title ?? openSession.title}`}>
            <h2>À reprendre</h2>
            <p className="v7-resume__game">{sessionGame?.title ?? openSession.title}</p>
            {openRow && openRow.status !== "lobby" && openRow.total_rounds > 0 ? <>
              <small>{roundWord(sessionGame?.mechanic)} {openRow.current_round} sur {openRow.total_rounds}</small>
              <span className="v7-resume__bar" aria-hidden="true"><span style={{ width: `${Math.min(100, (100 * openRow.current_round) / openRow.total_rounds)}%` }} /></span>
            </> : <small>{sessionLabel}</small>}
          </Link>
        ) : (
          <article className="v7-home-tile v7-resume" id="arcade-resume" tabIndex={-1}>
            <h2>À reprendre</h2>
            <small>Aucune partie en cours.</small>
          </article>
        )}
      </section>
      {active && recent.rows && recent.rows.length > 0 && (
        <section className="v7-recent" aria-labelledby="v7-recent-title">
          <div className="v7-section-head"><h2 id="v7-recent-title">Récemment joués</h2><Link to="/espace/historique">Tout voir</Link></div>
          <div className="v7-list">
            <SessionLine row={recent.rows[0]} game={cat.games.find((g) => g.id === recent.rows![0].game_id)}
              meta={<>{dayLabel(recent.rows[0].ended_at ?? recent.rows[0].created_at)}{minutesOf(recent.rows[0]) ? ` · ${minutesOf(recent.rows[0])} min` : ""}</>} />
          </div>
        </section>
      )}
    </main>
  );
}
