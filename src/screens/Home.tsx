import { useRef, useState } from "react";
import { Link } from "react-router";
import { t } from "../i18n";
import { useAuth } from "../auth/AuthProvider";
import { useDuo } from "../duo/DuoProvider";
import { DuoIdentity } from "../duo/DuoIdentity";
import { useHomeMoment } from "./useHomeMoment";
import { PendingRequest, useInviteActions } from "../duo/InviteScreens";
import { Alert, Art, ConfirmDialog, Icon, PageLoading, Sheet, formatDate } from "../components/ui";
import { artOf, GameThumb } from "./Libraries";
import { useCatalog } from "./catalog";

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
  const { userId } = useAuth();
  const duo = useDuo();
  const cat = useCatalog(userId);
  const moment = useHomeMoment(duo.active?.id);
  const carousel = useRef<HTMLDivElement>(null);
  const [slide, setSlide] = useState(0);
  const [quick, setQuick] = useState(false);
  function go(index: number) {
    const node = carousel.current?.children[index] as HTMLElement | undefined;
    if (node) carousel.current?.scrollTo({ left: node.offsetLeft - (carousel.current.firstElementChild as HTMLElement).offsetLeft, behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth" });
  }

  if (duo.loading) return <PageLoading />;
  const { active, invitations, openSession } = duo;

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
  const cards = (quick ? featured.filter((g) => (g.duration_min ?? 99) <= 5) : featured).slice(0, 5);
  const next = discover.filter((g) => ["custom-M01", "custom-P01"].includes(artOf(g))).slice(0, 2);
  const recommendations = next.length === 2 ? next : discover.slice(0, 2);

  return (
    <main className="page page--tight arcade-home">

      {duo.error && <Alert>{t("net.loadError")}</Alert>}

      {/* Carte principale : la pause à deux (ou l'invitation). */}
      {active ? (
        <section className="arcade-duo" aria-label="Votre duo">
          <DuoIdentity duo={active} online={duo.partnerOnline} size={42} />
          <Link className="arcade-space" to="/espace"><Icon name="home" size={17} /><span>Notre espace</span><Icon name="chevron-right" size={14} /></Link>
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

      <section className="arcade-play" aria-labelledby="arcade-title">
        <h1 id="arcade-title">À quoi on joue ?</h1>
        <div className="arcade-filters">
          <button className="btn btn--secondary" onClick={() => { setQuick(false); requestAnimationFrame(() => go(Math.floor(Math.random() * Math.max(1, featured.slice(0, 5).length)))); }}>Surprise</button>
          <button className="btn btn--secondary" aria-pressed={quick} onClick={() => { setQuick(!quick); go(0); }}>5 minutes</button>
          <a className="btn btn--secondary" href="#arcade-resume">À reprendre</a>
        </div>
        {cat.error ? <Alert>Catalogue indisponible. <button className="btn btn--quiet" onClick={() => void cat.reload()}>Réessayer</button></Alert> : cat.loading ? <p>Chargement des jeux…</p> : !cards.length ? <p>Aucun jeu disponible.</p> : <>
          <div className="arcade-carousel" ref={carousel} aria-label="Jeux à découvrir" onScroll={() => {
            const el = carousel.current; if (!el) return;
            const children = Array.from(el.children) as HTMLElement[];
            const origin = children[0]?.offsetLeft ?? 0;
            setSlide(children.reduce((best, child, i) => Math.abs(child.offsetLeft - origin - el.scrollLeft) < Math.abs(children[best].offsetLeft - origin - el.scrollLeft) ? i : best, 0));
          }}>
            {cards.map((g, i) => <article className="arcade-feature" key={g.id} aria-label={`${i + 1} sur ${cards.length}`}>
              <div><h2>{g.title}</h2><p>{g.duration_min ? `${g.duration_min}–${g.duration_max ?? g.duration_min} min · À deux` : "À votre rythme"}</p><Link className="btn" to={`/bibliotheques/${g.id}`}>Jouer <Icon name="play" size={18} /></Link></div>
              <GameThumb game={g} size="lg" />
            </article>)}
          </div>
          <div className="arcade-pagination">
            {cards.map((g, i) => <button key={g.id} aria-label={`Afficher ${g.title}`} aria-current={slide === i ? "true" : undefined} onClick={() => go(i)}><span /></button>)}
            <button aria-label="Jeu suivant" onClick={() => go((slide + 1) % cards.length)}><Icon name="arrow-right" size={18} /></button>
          </div>
        </>}
      </section>
      <section className="arcade-dashboard" aria-label="Votre rendez-vous à deux">
        <article className="arcade-question">
          <h2>Question du moment</h2>
          <p aria-live="polite">{!active ? "Créez votre duo pour découvrir votre question." : moment.loading ? "Votre question arrive…" : moment.data?.question ?? "Question indisponible pour le moment."}</p>
          {moment.error && <button className="btn btn--quiet" onClick={moment.refresh}>Réessayer</button>}
          <div className="arcade-question__foot"><Art name="custom-025" size={95} /><Link to="/bibliotheques/questions" className="icon-btn" aria-label="Découvrir les questions"><Icon name="arrow-right" /></Link></div>
        </article>
        <article className="arcade-resume" id="arcade-resume" tabIndex={-1}>
          <h2>Reprendre la partie</h2>
          <Art name="custom-M12" size={56} />
          {active && openSession ? <><p>{sessionGame?.title ?? openSession.title}</p><span className="t-meta">{sessionLabel}</span><Link className="btn btn--secondary" to={`/partie/${openSession.id}`}>{sessionAction}</Link></> : <p>Aucune partie en cours.</p>}
        </article>
        <article className="arcade-progress">
          <h2>Votre parcours</h2>
          <p>{active && moment.data ? <><strong>{moment.data.games_played}</strong> jeux terminés</> : active ? "Progression indisponible" : "Votre aventure commence à deux"}</p>
          <div className="arcade-progress__dots" aria-hidden="true">{Array.from({ length: 5 }, (_, i) => <span key={i} className={moment.data && i < moment.data.games_played ? "is-done" : ""} />)}</div>
        </article>
      </section>
      <section className="section arcade-next" aria-labelledby="arcade-next">
        <div className="section__head"><h2 id="arcade-next">Vos prochains jeux</h2><Link to="/bibliotheques" className="btn btn--quiet btn--auto">Voir tout</Link></div>
        <div>{recommendations.map((g) => <Link key={g.id} to={`/bibliotheques/${g.id}`}><GameThumb game={g} /><span><strong>{g.title}</strong><small>{g.duration_min ? `${g.duration_min} min` : "À votre rythme"}</small></span><Icon name="chevron-right" size={16} /></Link>)}</div>
      </section>
    </main>
  );
}
