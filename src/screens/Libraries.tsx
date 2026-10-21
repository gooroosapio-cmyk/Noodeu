import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router";
import { t } from "../i18n";
import { errorMessage } from "../lib/errors";
import { rpc, supabase } from "../lib/supabase";
import { useOnline } from "../lib/useOnline";
import { useAuth } from "../auth/AuthProvider";
import { useCouple } from "../couple/CoupleProvider";
import { Alert, DemoBadge, EmptyState, Icon, Illustration, Loading, PageLoading } from "../components/ui";
import type { Game } from "../lib/types";
import { mechanicIllustration, useCatalog } from "./catalog";

const normalize = (s: string) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();

export function GameCard({ game, favorite, onToggleFavorite }: { game: Game; favorite: boolean; onToggleFavorite: () => void }) {
  return (
    <article className="game-card">
      <div className="game-card__thumb" aria-hidden="true">
        <Illustration name={mechanicIllustration[game.mechanic] ?? "01-connexion-a-deux"} />
      </div>
      <div className="game-card__body">
        <Link className="game-card__title" to={`/bibliotheques/${game.id}`}>{game.title}</Link>
        <span className="game-card__meta">
          {t(`lib.style.${game.style}`)} · {t("common.minutes", { min: game.duration_min, max: game.duration_max })} · {t("common.twoPlayers")}
        </span>
        <span className="small">{game.promise}</span>
      </div>
      <button
        className="icon-btn icon-btn--plain"
        aria-pressed={favorite}
        onClick={onToggleFavorite}
        aria-label={favorite ? t("lib.removeFavorite", { title: game.title }) : t("lib.addFavorite", { title: game.title })}
      >
        <Icon name={favorite ? "star" : "bookmark"} />
      </button>
    </article>
  );
}

export function Libraries() {
  const { userId } = useAuth();
  const cat = useCatalog(userId);
  const [filter, setFilter] = useState<string>("all");
  const [query, setQuery] = useState("");

  const shown = useMemo(() => {
    const q = normalize(query.trim());
    return cat.games.filter((g) => {
      if (filter === "favorites" && !cat.favorites.has(g.id)) return false;
      if (filter !== "all" && filter !== "favorites" && g.category_id !== filter) return false;
      return !q || normalize(`${g.title} ${g.promise}`).includes(q);
    });
  }, [cat.games, cat.favorites, filter, query]);

  if (cat.loading) return <PageLoading />;

  return (
    <main className="page">
      <div className="page-head">
        <h1>{t("lib.title")}</h1>
        <p>{t("lib.subtitle")}</p>
      </div>
      {cat.error && (
        <Alert>
          {t("lib.error")} <button className="btn btn--ghost btn--inline" onClick={() => void cat.reload()}>{t("common.retry")}</button>
        </Alert>
      )}
      <div className="field">
        <label htmlFor="search" className="sr-only">{t("lib.search")}</label>
        <input id="search" className="input" type="search" placeholder={t("lib.search")} value={query} onChange={(e) => setQuery(e.target.value)} enterKeyHint="search" />
      </div>
      <div className="chips" role="group" aria-label={t("lib.title")}>
        <button className="chip" aria-pressed={filter === "all"} onClick={() => setFilter("all")}>{t("lib.all")}</button>
        {cat.categories.map((c) => (
          <button key={c.id} className="chip" aria-pressed={filter === c.id} onClick={() => setFilter(c.id)}>{c.title}</button>
        ))}
        <button className="chip" aria-pressed={filter === "favorites"} onClick={() => setFilter("favorites")}>
          <Icon name="star" size={18} />{t("lib.favorites")}
        </button>
      </div>
      {cat.categories.filter((c) => filter === c.id).map((c) => (
        <div key={c.id} className="card card--warm">
          <h2>{c.title}</h2>
          <p>{c.promise}</p>
          {c.is_demo && <div><DemoBadge /></div>}
        </div>
      ))}
      {shown.length === 0 ? (
        <EmptyState
          illustration="13-favoris"
          title={filter === "favorites" ? t("lib.favorites") : t("lib.empty")}
          text={filter === "favorites" ? t("lib.emptyFavorites") : undefined}
        />
      ) : (
        <div className="stack">
          {shown.map((g) => (
            <GameCard key={g.id} game={g} favorite={cat.favorites.has(g.id)} onToggleFavorite={() => void cat.toggleFavorite(g.id)} />
          ))}
        </div>
      )}
    </main>
  );
}

/** Fiche d'un jeu : promesse, règles, lancement (sélection → règles → salon). */
export function GameSheet() {
  const { gameId = "" } = useParams();
  const { userId } = useAuth();
  const { coupleId, openSession } = useCouple();
  const cat = useCatalog(userId);
  const online = useOnline();
  const navigate = useNavigate();
  const [rules, setRules] = useState<{ objective: string; how_to: string[]; details: string[]; privacy: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const game = cat.games.find((g) => g.id === gameId);

  useEffect(() => {
    if (!game) return;
    void supabase.from("game_versions").select("rules").eq("game_id", game.id).eq("version", game.current_version).maybeSingle()
      .then(({ data }) => {
        if (data) setRules(data.rules as typeof rules);
      });
  }, [game]);

  if (cat.loading) return <PageLoading />;
  if (!game) {
    return (
      <main className="page">
        <EmptyState illustration="13-favoris" title={t("game.notFound")}>
          <Link className="btn" to="/bibliotheques">{t("sheet.backToGames")}</Link>
        </EmptyState>
      </main>
    );
  }

  const other = openSession && openSession.game_id !== game.id && openSession.status !== "ended" ? openSession : null;

  async function prepare() {
    if (busy) return;
    setBusy(true);
    setError(null);
    const res = await rpc<{ session_id: string }>("create_session", { p_game: game!.id });
    setBusy(false);
    if (res.ok) navigate(`/partie/${res.session_id}`);
    else setError(errorMessage(res.error));
  }

  const favorite = cat.favorites.has(game.id);
  return (
    <main className="page">
      <div className="topbar">
        <Link className="icon-btn" to="/bibliotheques"><Icon name="arrow-left" label={t("sheet.backToGames")} /></Link>
        <button className="icon-btn" aria-pressed={favorite} onClick={() => void cat.toggleFavorite(game.id)}
          aria-label={favorite ? t("lib.removeFavorite", { title: game.title }) : t("lib.addFavorite", { title: game.title })}>
          <Icon name={favorite ? "star" : "bookmark"} />
        </button>
      </div>
      <div className="page-head">
        <h1>{game.title}</h1>
        <div className="badges">
          <span className="badge"><Icon name="chat" size={16} />{t(`lib.style.${game.style}`)}</span>
          <span className="badge"><Icon name="users" size={16} />{t("common.twoPlayers")}</span>
          <span className="badge"><Icon name="clock" size={16} />{t("common.minutes", { min: game.duration_min, max: game.duration_max })}</span>
          {game.is_demo && <DemoBadge />}
        </div>
      </div>
      <div className="card card--warm">
        <Illustration name={mechanicIllustration[game.mechanic] ?? "01-connexion-a-deux"} className="illustration--card" eager />
        <p>{game.promise}</p>
      </div>
      {!rules ? <Loading /> : (
        <>
          <section className="stack">
            <h2>{t("sheet.howTo")}</h2>
            <ol className="how">{rules.how_to.map((x) => <li key={x}>{x}</li>)}</ol>
          </section>
          <p className="row"><Icon name="lock" /> {rules.privacy}</p>
          <details className="rules">
            <summary>{t("sheet.details")}</summary>
            <p>{rules.objective}</p>
            <ul>{rules.details.map((x) => <li key={x}>{x}</li>)}</ul>
          </details>
        </>
      )}
      {error && <Alert>{error}</Alert>}
      {!coupleId ? (
        <>
          <Alert kind="info">{t("sheet.needPartner")}</Alert>
          <Link className="btn" to="/inviter">{t("home.invite")}</Link>
        </>
      ) : other ? (
        <>
          <Alert kind="info">{t("sheet.otherInProgress", { title: other.title })}</Alert>
          <Link className="btn" to={`/partie/${other.id}`}>{t("sheet.goToOther")}</Link>
        </>
      ) : (
        <button className="btn" disabled={busy || !online} onClick={prepare}>
          {busy ? t("common.sending") : t("sheet.prepare")} <Icon name="arrow-right" />
        </button>
      )}
      <Link className="btn btn--ghost" to="/bibliotheques">{t("sheet.backToGames")}</Link>
    </main>
  );
}
