import { Link } from "react-router";
import { t } from "../i18n";
import { useAuth } from "../auth/AuthProvider";
import { useCouple } from "../couple/CoupleProvider";
import { PendingRequest } from "../couple/InviteScreens";
import { Alert, Avatar, Icon, Illustration, Logo, PageLoading } from "../components/ui";
import { GameCard } from "./Libraries";
import { useCatalog } from "./catalog";

export function Home() {
  const { profile, userId } = useAuth();
  const couple = useCouple();
  const cat = useCatalog(userId);
  const name = profile?.display_name ?? "";

  if (couple.loading) return <PageLoading />;

  const open = couple.openSession;
  const openLabel = !open ? "" : open.status === "lobby" ? t("home.resumeLobby") : open.status === "ended" ? t("home.resumeEnded") : t("home.resume");
  const openStatus = !open ? "" : open.status === "paused" ? t("home.paused") : open.status === "lobby" ? t("home.waitingLobby") : t("home.inProgress");

  return (
    <main className="page">
      <div className="topbar">
        <Logo width={140} />
        <Link to="/parametres" aria-label={t("nav.settings")}><Avatar name={name} me /></Link>
      </div>
      <div className="page-head">
        <h1>{t("home.hello", { name })}</h1>
        <p>{t("home.subtitle")}</p>
      </div>

      {couple.error && <Alert>{t("net.offline")}</Alert>}

      {couple.coupleId && couple.partner && (
        <div className="duo">
          <div className="avatars"><Avatar name={name} me /><Avatar name={couple.partner.name} /></div>
          <div>
            <strong>{name} & {couple.partner.name}</strong>
            <div className="status">
              <span className={`status-dot ${couple.partnerOnline ? "status-dot--on" : ""}`} />
              {couple.partnerOnline ? t("presence.online") : t("presence.offline")}
            </div>
          </div>
        </div>
      )}

      {open && (
        <section className="card card--warm enter">
          <span className="badge">{openStatus}</span>
          <h2>{open.title}</h2>
          <Link className="btn" to={`/partie/${open.id}`}>{openLabel} <Icon name="arrow-right" /></Link>
        </section>
      )}

      {!couple.coupleId && couple.invitations.outgoing?.status === "claimed" && <PendingRequest />}

      {!couple.coupleId && couple.invitations.outgoing?.status !== "claimed" && (
        <section className="card card--warm">
          <Illustration name="14-duo-a-creer" className="illustration--card" eager />
          <h2>{t("home.inviteTitle")}</h2>
          <p>{t("home.inviteText")}</p>
          <Link className="btn" to="/inviter"><Icon name="plus" />{t("home.invite")}</Link>
        </section>
      )}

      {couple.coupleId && !open && (
        <section className="card card--warm">
          <Illustration name="01-connexion-a-deux" className="illustration--card" eager />
          <h2>{t("home.playTitle")}</h2>
          <Link className="btn" to="/bibliotheques">{t("home.choose")} <Icon name="arrow-right" /></Link>
        </section>
      )}

      {cat.games.length > 0 && (
        <section className="stack">
          <h2>{t("home.ideas")}</h2>
          {cat.games.slice(0, 3).map((g) => (
            <GameCard key={g.id} game={g} favorite={cat.favorites.has(g.id)} onToggleFavorite={() => void cat.toggleFavorite(g.id)} />
          ))}
        </section>
      )}
    </main>
  );
}
