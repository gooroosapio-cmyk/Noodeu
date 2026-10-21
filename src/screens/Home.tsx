import { useState } from "react";
import { Link } from "react-router";
import { t } from "../i18n";
import { useAuth } from "../auth/AuthProvider";
import { useDuo } from "../duo/DuoProvider";
import { DuoIdentity } from "../duo/DuoIdentity";
import { PendingRequest, useInviteActions } from "../duo/InviteScreens";
import { Alert, ConfirmDialog, Icon, PageLoading, Sheet, formatDate } from "../components/ui";
import { GameCard } from "./Libraries";
import { useCatalog } from "./catalog";

function PendingInvitationCard() {
  const { out, share, copy, revoke } = useInviteActions();
  const [menu, setMenu] = useState(false);
  const [confirm, setConfirm] = useState(false);
  if (!out) return null;
  return (
    <section className="card stack stack--4">
      <DuoIdentity duo={null} showStatus={false} />
      <div className="stack stack--2">
        <h2 className="t-card">{t("home.pendingTitle")}</h2>
        <p className="t-meta">{t("home.pendingUntil", { date: formatDate(out.expires_at, true) })}</p>
      </div>
      <div className="row">
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
      lobby: [t("home.lobby", { title: openSession.title }), t("home.joinLobby")],
      playing: [t("home.inProgress", { title: openSession.title }), t("home.resume")],
      paused: [t("home.paused", { title: openSession.title }), t("home.resume")],
      ended: [t("home.ended", { title: openSession.title }), t("home.seeResults")],
    } as const;
    [sessionLabel, sessionAction] = map[openSession.status];
  }

  return (
    <main className="page">
      <div className="page-header">
        <h1 className="t-page">{t("home.hello", { name })}</h1>
        <p>{active ? t("home.subtitleDuo") : t("home.subtitleSolo")}</p>
      </div>

      {duo.error && <Alert>{t("net.loadError")}</Alert>}

      {active ? (
        <section className="card stack stack--4">
          <DuoIdentity duo={active} online={duo.partnerOnline} />
          {openSession && <p className="t-small">{sessionLabel}</p>}
          {openSession ? (
            <Link className="btn" to={`/partie/${openSession.id}`}>{sessionAction}<Icon name="arrow-right" /></Link>
          ) : (
            <Link className="btn" to="/bibliotheques">{t("home.choose")}<Icon name="arrow-right" /></Link>
          )}
          <Link className="btn btn--quiet btn--sm" to="/notre-espace">{t("home.space")}</Link>
        </section>
      ) : invitations.outgoing?.status === "claimed" ? (
        <PendingRequest />
      ) : invitations.outgoing && !invitations.outgoing.expired ? (
        <PendingInvitationCard />
      ) : invitations.incoming ? (
        <section className="card stack stack--3">
          <DuoIdentity duo={null} showStatus={false} />
          <p className="t-card">{t("home.waitingAnswer", { name: invitations.incoming.inviter_name })}</p>
          <Link className="btn btn--secondary" to="/rejoindre">{t("common.continue")}</Link>
        </section>
      ) : (
        <section className="card stack stack--4">
          <DuoIdentity duo={null} showStatus={false} />
          <div className="stack stack--2">
            <h2 className="t-card">{t("home.soloTitle")}</h2>
            <p className="t-small muted">{t("home.soloText")}</p>
          </div>
          <Link className="btn" to="/inviter">{t("home.invite")}</Link>
          <Link className="btn btn--quiet btn--sm" to="/rejoindre">{t("home.haveCode")}</Link>
        </section>
      )}

      {cat.games.length > 0 && (
        <section className="section">
          <div className="section__head">
            <h2 className="t-section">{active ? t("home.ideasDuo") : t("home.ideas")}</h2>
            <Link className="btn btn--quiet btn--auto btn--sm" to="/bibliotheques">{t("home.seeGames")}</Link>
          </div>
          <div className="stack grid-2">
            {cat.games.slice(0, 3).map((g) => (
              <GameCard key={g.id} game={g} favorite={cat.favorites.has(g.id)} onToggleFavorite={() => cat.toggleFavorite(g.id)} />
            ))}
          </div>
        </section>
      )}
    </main>
  );
}
