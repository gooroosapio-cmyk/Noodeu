import { useState } from "react";
import { Link } from "react-router";
import { t } from "../i18n";
import { useAuth } from "../auth/AuthProvider";
import { useDuo } from "../duo/DuoProvider";
import { DuoIdentity } from "../duo/DuoIdentity";
import { PendingRequest, useInviteActions } from "../duo/InviteScreens";
import { Alert, ConfirmDialog, Icon, Illustration, PageLoading, Sheet, formatDate } from "../components/ui";
import { GameCard } from "./Libraries";
import { mechanicIllustration, useCatalog } from "./catalog";

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
  const { profile, userId } = useAuth();
  const duo = useDuo();
  const cat = useCatalog(userId);

  if (duo.loading) return <PageLoading />;
  const { active, invitations, openSession } = duo;
  const name = profile?.display_name ?? "";

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
  const favorites = cat.games.filter((g) => cat.favorites.has(g.id)).slice(0, 3);
  const discover = cat.games.filter((g) => !cat.favorites.has(g.id)).slice(0, 3);
  const card = (g: (typeof cat.games)[number]) => (
    <GameCard key={g.id} game={g} favorite={cat.favorites.has(g.id)} onToggleFavorite={() => cat.toggleFavorite(g.id)} />
  );

  return (
    <main className="page page--tight">
      <div className="page-header">
        <h1 className="t-page">{t("home.hello", { name })}</h1>
        <p>{active ? t("home.subtitleDuo") : t("home.subtitleSolo")}</p>
      </div>

      {duo.error && <Alert>{t("net.loadError")}</Alert>}

      {/* Carte principale : le duo (ou l'invitation), centrée. */}
      {active ? (
        <section className="card hero center" aria-label={t("home.duoCard")}>
          <DuoIdentity duo={active} online={duo.partnerOnline} center size={60} />
          {!openSession && <Link className="btn hero__cta" to="/bibliotheques">{t("home.choose")}<Icon name="arrow-right" /></Link>}
          <Link className="btn btn--quiet btn--sm btn--auto" to="/espace">{t("home.openSpace")}</Link>
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
            <p className="t-small muted">{t("home.soloText")}</p>
          </div>
          <Link className="btn hero__cta" to="/inviter">{t("home.invite")}</Link>
          <Link className="btn btn--quiet btn--sm btn--auto" to="/rejoindre">{t("home.haveCode")}</Link>
        </section>
      )}

      {active && openSession && (
        <section className="section" aria-labelledby="home-now">
          <h2 className="t-section" id="home-now">{t("home.now")}</h2>
          <div className="card now-card">
            <div className="game-card__thumb" aria-hidden="true">
              <Illustration name={(sessionGame && mechanicIllustration[sessionGame.mechanic]) ?? "01-connexion-a-deux"} />
            </div>
            <div className="stack" style={{ gap: 2 }}>
              <span className="t-meta">{sessionLabel}</span>
              <span className="t-card">{openSession.title}</span>
            </div>
            <Link className="btn now-card__cta" to={`/partie/${openSession.id}`}>{sessionAction}<Icon name="arrow-right" /></Link>
          </div>
        </section>
      )}

      {favorites.length > 0 && (
        <section className="section" aria-labelledby="home-fav">
          <div className="section__head">
            <h2 className="t-section" id="home-fav">{t("home.favorites")}</h2>
          </div>
          <div className="stack grid-2">{favorites.map(card)}</div>
        </section>
      )}

      {discover.length > 0 && (
        <section className="section" aria-labelledby="home-ideas">
          <div className="section__head">
            <h2 className="t-section" id="home-ideas">{active ? t("home.ideasDuo") : t("home.ideas")}</h2>
            <Link className="btn btn--quiet btn--auto btn--sm" to="/bibliotheques">{t("home.seeGames")}</Link>
          </div>
          <div className="stack grid-2">{discover.map(card)}</div>
        </section>
      )}
    </main>
  );
}
