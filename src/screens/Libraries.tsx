import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router";
import { t } from "../i18n";
import { errorMessage } from "../lib/errors";
import { rpc, supabase } from "../lib/supabase";
import { useOnline } from "../lib/useOnline";
import { useAuth } from "../auth/AuthProvider";
import { useDuo } from "../duo/DuoProvider";
import { SubPage } from "../components/AppShell";
import { Alert, Art, DemoTag, Icon, Loading, PageLoading } from "../components/ui";
import type { Category, Game } from "../lib/types";
import { CATEGORY_BY_SHELF, SHELF_PATH, SHELVES, normalizeText, shelfOf, useCatalog, type Shelf } from "./catalog";

const ART_BY_PACK: Record<string, string> = {
  P01: "c01-aron36", P03: "c01-approfondies", P15: "c01-retrouver55", P11: "c01-rituels",
  P12: "c01-place", P13: "c01-projets", P14: "c01-valeurs",
};

/** Illustration d'une activité (kit interface v2) : par pack, instrument ou code de référence du catalogue. */
export function artOf(g: Pick<Game, "meta" | "mechanic">) {
  const m = g.meta ?? {};
  if (g.mechanic === "pack_conversation") return ART_BY_PACK[m.code ?? ""] ?? "c01-generic";
  if (g.mechanic === "test_form") return m.instrument ?? "C02";
  return m.reference_code ?? "C03";
}

/** Vignette d'activité (illustration du kit, décorative). */
export function GameThumb({ game, size = "md" }: { game: Pick<Game, "meta" | "mechanic">; size?: "md" | "lg" }) {
  return (
    <div className={`game-thumb${size === "lg" ? " game-thumb--lg" : ""}`} aria-hidden="true">
      <Art name={artOf(game)} size={size === "lg" ? 112 : 56} />
    </div>
  );
}

const PASTELS = ["peach", "sage", "lavender", "butter"] as const;

/** Libellé de type affiché sous un titre. */
export function typeLabel(g: Game) {
  const n = g.meta?.items;
  if (g.mechanic === "test_form") return n ? t("lib.type.test", { n }) : t("lib.shelf.tests");
  if (g.mechanic === "pack_conversation") return n ? t("lib.type.pack", { n }) : t("lib.shelf.questions");
  return shelfOf(g) === "minijeux" ? t("lib.type.minijeu") : t("lib.type.conversation");
}

export function durationLabel(g: Pick<Game, "duration_min" | "duration_max">) {
  return g.duration_min === g.duration_max ? t("lib.duration", { min: g.duration_min }) : t("lib.durationRange", { min: g.duration_min, max: g.duration_max });
}

/** Tuile de la grille à deux colonnes : titre à gauche, illustration à droite. Toute la tuile ouvre la fiche. */
export function GameTile({ game, index }: { game: Game; index: number }) {
  const soon = game.implementation !== "playable";
  return (
    <Link className={`gtile gtile--${PASTELS[index % 4]}${soon ? " gtile--soon" : ""}`} to={`/bibliotheques/${game.id}`}
      aria-label={soon ? `${game.title} (${t("lib.soon")})` : undefined}>
      <span className="gtile__title">{game.title}</span>
      {soon && <span className="gtile__soon" aria-hidden="true">{t("lib.soon")}</span>}
      <Art name={artOf(game)} />
    </Link>
  );
}

export function TileGrid({ games }: { games: Game[] }) {
  return (
    <ul className="gtile-grid">
      {games.map((g, i) => <li key={g.id}><GameTile game={g} index={i} /></li>)}
    </ul>
  );
}

/** Ligne de pack (pages Se découvrir, Mieux se comprendre, À huis clos). */
function PackList({ games }: { games: Game[] }) {
  return (
    <ul className="pack-list">
      {games.map((g) => (
        <li key={g.id}>
          <Link className="pack-row" to={`/bibliotheques/${g.id}`}>
            <Art name={artOf(g)} size={64} />
            <span className="pack-row__body">
              <span className="pack-row__title">{g.title}</span>
              <span className="t-meta">{typeLabel(g)} · {durationLabel(g)}</span>
            </span>
            <Icon name="chevron-right" size={20} />
          </Link>
        </li>
      ))}
    </ul>
  );
}

const BANNER: Record<"questions" | "tests" | "huisclos", { art: string; tone: string }> = {
  questions: { art: "C01", tone: "" },
  tests: { art: "C02", tone: " cat-banner--lavender" },
  huisclos: { art: "result-private", tone: " cat-banner--butter" },
};

/** Catégorie horizontale (environ 74 px) : titre, sous-titre, illustration et chevron ; ouvre la liste des packs. */
export function ShelfBanner({ shelf, title, text }: { shelf: "questions" | "tests" | "huisclos"; title: string; text: string }) {
  return (
    <Link className={`cat-banner${BANNER[shelf].tone}`} to={SHELF_PATH[shelf]}>
      <span className="cat-banner__copy">
        <span className="cat-banner__title">{title}</span>
        <span className="cat-banner__text">{text}</span>
      </span>
      <Art name={BANNER[shelf].art} size={92} />
      <Icon name="chevron-right" size={20} />
    </Link>
  );
}

/** Bloc « À huis clos » : rien n'est listé tant que la personne ne l'a pas activé elle-même. */
function HuisClosNotice({ enabled }: { enabled: boolean }) {
  return enabled
    ? <p className="t-meta row"><Icon name="lock-keyhole" size={18} />{t("lib.huisclosOn")}</p>
    : (
      <div className="card card--lavender stack">
        <p className="row"><Icon name="lock-keyhole" size={20} /><span>{t("lib.huisclosOff")}</span></p>
        <Link className="btn btn--secondary" to="/reglages">{t("lib.huisclosActivate")}</Link>
      </div>
    );
}

const STORE = "noodeu.lib.state.v4";
interface LibState { query: string; scroll: number }

function loadState(): LibState {
  try {
    const s = JSON.parse(sessionStorage.getItem(STORE) ?? "null") as LibState | null;
    if (s && typeof s.query === "string") return s;
  } catch {
    /* rien */
  }
  return { query: "", scroll: 0 };
}

function categoryOf(categories: Category[], shelf: Shelf) {
  return categories.find((c) => c.id === CATEGORY_BY_SHELF[shelf]);
}

function shelfTitle(categories: Category[], shelf: Shelf) {
  return shelf === "huisclos" ? t("lib.shelf.huisclos") : categoryOf(categories, shelf)?.title ?? t(`lib.shelf.${shelf}`);
}

export function Libraries() {
  const { userId, profile } = useAuth();
  const cat = useCatalog(userId);
  const [state, setState] = useState<LibState>(loadState);
  const intimate = !!profile?.intimate_opt_in;

  // Recherche et position conservées en mémoire de session (jamais dans l'URL).
  useEffect(() => {
    try {
      sessionStorage.setItem(STORE, JSON.stringify(state));
    } catch {
      /* rien */
    }
  }, [state]);
  const stateRef = useRef(state);
  stateRef.current = state;
  useEffect(() => () => {
    try {
      sessionStorage.setItem(STORE, JSON.stringify({ ...stateRef.current, scroll: window.scrollY }));
    } catch {
      /* rien */
    }
  }, []);
  useLayoutEffect(() => {
    if (!cat.loading && state.scroll) window.scrollTo(0, state.scroll);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cat.loading]);

  const byShelf = useMemo(() => {
    const m = new Map<Shelf, Game[]>(SHELVES.map((s) => [s, []]));
    for (const g of cat.games) {
      const s = shelfOf(g);
      if (s) m.get(s)!.push(g);
    }
    return m;
  }, [cat.games]);

  const q = normalizeText(state.query.trim());
  // Les activités « À huis clos » restent hors des résultats tant que la personne ne les a pas activées.
  const results = useMemo(() => q
    ? cat.games.filter((g) => (shelfOf(g) !== "huisclos" || intimate) && normalizeText(`${g.title} ${g.hook} ${g.promise}`).includes(q))
    : [], [cat.games, q, intimate]);

  if (cat.loading) return <PageLoading />;
  const count = (s: Shelf) => byShelf.get(s)?.length ?? 0;

  return (
    <main className="page page--tight">
      <div className="page-header">
        <h1 className="t-page">{t("lib.title")}</h1>
        <p className="t-small muted">{t("lib.subtitle")}</p>
      </div>
      {cat.error && (
        <Alert>{t("lib.error")} <button className="btn btn--quiet btn--auto btn--sm" onClick={() => void cat.reload()}>{t("common.retry")}</button></Alert>
      )}
      <div className="search">
        <Icon name="search" size={20} />
        <label htmlFor="search" className="sr-only">{t("lib.search")}</label>
        <input id="search" className="input" type="search" placeholder={t("lib.searchShort")} value={state.query}
          onChange={(e) => setState((s) => ({ ...s, query: e.target.value }))} enterKeyHint="search" />
      </div>
      <p className="sr-only" aria-live="polite">{q ? t("lib.results", { n: results.length }) : ""}</p>

      {cat.games.length === 0 ? (
        <div className="card stack center"><p className="t-card">{t("lib.emptyCatalog")}</p></div>
      ) : q ? (
        results.length ? <TileGrid games={results} /> : (
          <div className="card stack center">
            <p className="t-card">{t("lib.noResults")}</p>
            <button className="btn btn--secondary btn--auto" onClick={() => setState((s) => ({ ...s, query: "" }))}>{t("lib.clearFilters")}</button>
          </div>
        )
      ) : (
        <>
          <div className="stack" style={{ gap: "var(--grid-gap)" }}>
            {(["questions", "tests"] as const).map((s) => count(s) > 0 && (
              <ShelfBanner key={s} shelf={s} title={shelfTitle(cat.categories, s)} text={t(`lib.bannerText.${s}`)} />
            ))}
          </div>
          {(["conversation", "minijeux"] as const).map((s) => count(s) > 0 && (
            <section key={s} className="section" aria-labelledby={`shelf-${s}`}>
              <div className="section__head">
                <h2 className="t-section" id={`shelf-${s}`}>{t(`lib.shelf.${s}`)}</h2>
                <span className="t-meta">{t(s === "minijeux" ? "lib.countMini" : "lib.countGames", { n: count(s) })}</span>
              </div>
              <TileGrid games={byShelf.get(s)!} />
            </section>
          ))}
          {count("huisclos") > 0 && (
            <section className="section" aria-labelledby="shelf-huisclos">
              <h2 className="t-section" id="shelf-huisclos">{t("lib.shelf.huisclos")}</h2>
              {intimate ? <ShelfBanner shelf="huisclos" title={t("lib.shelf.huisclos")} text={t("lib.huisclosText")} /> : <HuisClosNotice enabled={false} />}
            </section>
          )}
        </>
      )}
    </main>
  );
}

/** Page d'une catégorie horizontale (Se découvrir, Mieux se comprendre, À huis clos) : liste de ses packs. */
export function ShelfPage({ shelf }: { shelf: "questions" | "tests" | "huisclos" }) {
  const { userId, profile } = useAuth();
  const cat = useCatalog(userId);
  if (cat.loading) return <PageLoading />;
  const games = cat.games.filter((g) => shelfOf(g) === shelf);
  const intimate = !!profile?.intimate_opt_in;
  return (
    <SubPage backTo="/bibliotheques" title={shelfTitle(cat.categories, shelf)}>
      <main className="page page--bare page--tight">
        <div className="page-header">
          <h1 className="t-page">{t(shelf === "questions" ? "lib.choosePack" : "lib.chooseTest")}</h1>
          <p className="t-small muted">{shelf === "huisclos" ? t("lib.huisclosText") : categoryOf(cat.categories, shelf)?.promise}</p>
        </div>
        {cat.error && <Alert>{t("lib.error")}</Alert>}
        {shelf === "huisclos" && <HuisClosNotice enabled={intimate} />}
        {(shelf !== "huisclos" || intimate) && (games.length ? <PackList games={games} /> : <div className="card stack center"><p className="t-card">{t("lib.emptyCatalog")}</p></div>)}
      </main>
    </SubPage>
  );
}

/** Fiche d'un jeu : promesse, règles et lancement (sélection → règles → salon). */
export function GameSheet() {
  const { gameId = "" } = useParams();
  const { userId } = useAuth();
  const { active, openSession } = useDuo();
  const cat = useCatalog(userId);
  const online = useOnline();
  const navigate = useNavigate();
  const [rules, setRules] = useState<{ objective: string; how_to: string[]; details: string[]; privacy: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const game = cat.games.find((g) => g.id === gameId);

  useEffect(() => {
    if (!game || game.implementation !== "playable" || !game.current_version) return;
    void supabase.from("game_versions").select("rules").eq("game_id", game.id).eq("version", game.current_version).maybeSingle()
      .then(({ data }) => data && setRules(data.rules as typeof rules));
  }, [game]);

  if (cat.loading) return <PageLoading />;
  if (!game) {
    return (
      <SubPage backTo="/bibliotheques">
        <main className="page page--bare"><p className="t-card">{t("game.notFound")}</p></main>
      </SubPage>
    );
  }

  const other = openSession && openSession.game_id !== game.id && openSession.status !== "ended" ? openSession : null;
  const favorite = cat.favorites.has(game.id);
  const soon = game.implementation !== "playable";
  const catTitle = cat.categories.find((c) => c.id === game.category_id)?.title;
  const shelf = shelfOf(game);
  const backTo = shelf === "questions" || shelf === "tests" || shelf === "huisclos" ? SHELF_PATH[shelf] : "/bibliotheques";
  const intime = game.content_level === "intime";

  async function prepare() {
    if (busy) return;
    setBusy(true);
    setError(null);
    const res = await rpc<{ session_id: string }>("create_session", { p_game: game!.id });
    setBusy(false);
    if (res.ok) navigate(`/partie/${res.session_id}`);
    else setError(errorMessage(res.error));
  }

  return (
    <SubPage backTo={backTo} actions={
      <button className="icon-btn icon-btn--soft" aria-pressed={favorite} onClick={() => void cat.toggleFavorite(game.id)}
        aria-label={favorite ? t("lib.removeFavorite", { title: game.title }) : t("lib.addFavorite", { title: game.title })}>
        <Icon name={favorite ? "star" : "bookmark"} />
      </button>
    }>
      <main className="page page--bare page--read">
        <div className={`sheet-hero sheet-hero--${intime ? "lavender" : shelf === "tests" ? "butter" : shelf === "minijeux" ? "sage" : "peach"}`}>
          <GameThumb game={game} size="lg" />
        </div>
        <div className="stack stack--2">
          <h1 className="t-page">{game.title}</h1>
          <p className="t-meta">
            {typeLabel(game)} · {durationLabel(game)}{catTitle ? ` · ${intime ? t("lib.shelf.huisclos") : catTitle}` : ""}
          </p>
          {game.is_demo && <div><DemoTag /></div>}
        </div>
        <p>{game.hook || game.promise}</p>
        {soon ? (
          <Alert kind="info">{t("sheet.soon")}</Alert>
        ) : !rules ? <Loading /> : (
          <>
            <section className="card card--soft stack stack--4">
              <h2 className="t-section">{t("sheet.howTo")}</h2>
              <ol className="how">{rules.how_to.map((x) => <li key={x}>{x}</li>)}</ol>
              <p className="row t-small"><Icon name="lock" size={18} />{rules.privacy}</p>
              {intime && <p className="row t-small"><Icon name="lock" size={18} />{t("sheet.huisclosRule")}</p>}
            </section>
            <details className="disclosure">
              <summary>{t("sheet.details")}<Icon name="chevron-down" /></summary>
              <div><p>{rules.objective}</p><ul style={{ margin: 0, paddingLeft: 20 }}>{rules.details.map((x) => <li key={x}>{x}</li>)}</ul></div>
            </details>
          </>
        )}
        {error && <Alert>{error}</Alert>}
        <div className="action-bar">
          {soon ? (
            <Link className="btn btn--secondary" to="/bibliotheques">{t("sheet.backToGames")}</Link>
          ) : !active ? (
            <>
              <Alert kind="info">{t("sheet.needDuo")}</Alert>
              <Link className="btn" to="/inviter">{t("duo.invite")}</Link>
            </>
          ) : other ? (
            <>
              <Alert kind="info">{t("sheet.otherInProgress", { title: other.title })}</Alert>
              <Link className="btn" to={`/partie/${other.id}`}>{t("sheet.goToOther")}</Link>
            </>
          ) : (
            <button className="btn" disabled={busy || !online} onClick={prepare}>{busy ? t("common.sending") : t("sheet.prepare")}<Icon name="arrow-right" /></button>
          )}
        </div>
      </main>
    </SubPage>
  );
}
