import { LIBRARY_ART } from "./libraryArt";
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { Link, useParams } from "react-router";
import { t, type MessageKey } from "../i18n";
import { supabase } from "../lib/supabase";
import { useOnline } from "../lib/useOnline";
import { useAuth } from "../auth/AuthProvider";
import { useDuo } from "../duo/DuoProvider";
import { SubPage } from "../components/AppShell";
import { Alert, Art, DemoTag, Icon, Loading, PageLoading } from "../components/ui";
import type { Category, Game, GameRules } from "../lib/types";
import { RulesSheet } from "../components/RulesSheet";
import { ProgressBadge, useProgress } from "../parcours/Progress";
import { HealthResources } from "../parcours/HealthResources";
import { useLaunch } from "../game/launch";
import {
  CATEGORY_BY_SHELF, DURATIONS, FORMATS, INTENSITIES, NO_FILTERS, SHELF_PATH, SHELVES, hasFilters, intensityRank, matchesFilters,
  normalizeText, shelfOf, useCatalog, useMyFilters, type Filters, type Shelf,
} from "./catalog";

export const ART_BY_PACK: Record<string, string> = {
  P01: "custom-P01", P03: "custom-P03", P15: "custom-P15", P11: "custom-P11",
  P12: "custom-P12", P13: "custom-P13", P14: "custom-P14", P20:"custom-P20", P21:"custom-P21", P22:"custom-P22", P23:"custom-P23", P24:"custom-P24",
  H01:"custom-H01", H02:"custom-H02", H03:"custom-H03", H04:"custom-H04", H05:"custom-H05", H06:"custom-H06", H07:"custom-H07", H08:"custom-H08", RND1:"custom-RND1", RND2:"custom-RND2",
};

/** Illustration d'une activité (kit interface v2) : par pack, instrument ou code de référence du catalogue. */
export function artOf(g: Pick<Game, "id" | "meta" | "mechanic">) {
  const m = g.meta ?? {};
  const instruments: Record<string,string> = { RICE100:"011", IPIP50:"012", ECRRS9:"021", CSI4:"022", AAIRS8:"024", QSI12:"025", SPN16:"027" };
  const code = m.reference_code ?? m.code ?? instruments[m.instrument ?? ""] ?? LIBRARY_ART[g.id];
  return `custom-${code ?? "G06"}`;
}

/** Vignette d'activité (illustration du kit, décorative). */
export function GameThumb({ game, size = "md" }: { game: Pick<Game, "id" | "meta" | "mechanic">; size?: "md" | "lg" }) {
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
  const progress = useProgress();
  return (
    <ul className="pack-list">
      {games.map((g) => (
        <li key={g.id}>
          <Link className="pack-row" to={`/bibliotheques/${g.id}`}>
            <Art name={artOf(g)} size={64} />
            <span className="pack-row__body">
              <span className="pack-row__title">{g.title}</span>
              <span className="t-meta">{typeLabel(g)} · {durationLabel(g)}</span>
              <ProgressBadge p={progress?.[g.id]} />
            </span>
            <Icon name="chevron-right" size={20} />
          </Link>
        </li>
      ))}
    </ul>
  );
}

const BANNER: Record<"questions" | "tests" | "huisclos", { art: string; tone: string }> = {
  questions: { art: "custom-questions", tone: "" },
  tests: { art: "custom-tests", tone: " cat-banner--lavender" },
  huisclos: { art: "custom-huisclos", tone: " cat-banner--butter" },
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

const STORE = "noodeu.lib.state.v5";
interface LibState { query: string; scroll: number; filters: Filters; open: boolean }

function loadState(): LibState {
  try {
    const s = JSON.parse(sessionStorage.getItem(STORE) ?? "null") as LibState | null;
    if (s && typeof s.query === "string" && s.filters) return { ...s, filters: { ...NO_FILTERS, ...s.filters } };
  } catch {
    /* rien */
  }
  return { query: "", scroll: 0, filters: NO_FILTERS, open: false };
}

/** Plafond d'intensité du duo : le réglage le plus doux des deux (serveur), à défaut le mien. */
export function useCap() {
  const { profile } = useAuth();
  const { active } = useDuo();
  const my = useMyFilters(`${profile?.max_intensity}|${profile?.intimate_opt_in}|${active?.id ?? ""}`);
  return { cap: my?.duo_cap ?? intensityRank(profile?.max_intensity), duoAdult: my?.duo_adult ?? false };
}

type Group = "intensity" | "duration" | "format";
const GROUP_VALUES: Record<Group, readonly string[]> = { intensity: INTENSITIES, duration: DURATIONS, format: FORMATS };

/** Filtres combinables : intensité, durée, format et +18 (ce dernier seulement si la personne l'a activé). */
function FilterPanel({ filters, cap, adultOk, onChange }: { filters: Filters; cap: number; adultOk: boolean; onChange: (f: Filters) => void }) {
  function flip(group: Group, v: string) {
    const cur = filters[group] as string[];
    onChange({ ...filters, [group]: cur.includes(v) ? cur.filter((x) => x !== v) : [...cur, v] });
  }
  return (
    <div className="filter-panel stack" id="lib-filters">
      {(Object.keys(GROUP_VALUES) as Group[]).map((group) => (
        <fieldset key={group} className="filter-group">
          <legend className="t-meta">{t(`filter.${group}` as MessageKey)}</legend>
          <div className="chips chips--scroll">
            {GROUP_VALUES[group].map((v) => {
              const blocked = group === "intensity" && intensityRank(v as Filters["intensity"][number]) > cap;
              return (
                <button key={v} type="button" className="chip" aria-pressed={(filters[group] as string[]).includes(v)} disabled={blocked}
                  title={blocked ? t("filter.aboveCap") : undefined} onClick={() => flip(group, v)}>
                  {t(`filter.${group}.${v}` as MessageKey)}
                </button>
              );
            })}
          </div>
        </fieldset>
      ))}
      {adultOk && (
        <label className="switch-row">
          <span className="switch-row__text"><span>{t("filter.adult")}</span><span className="t-meta">{t("filter.adultHint")}</span></span>
          <input className="switch" type="checkbox" role="switch" checked={filters.adult} onChange={(e) => onChange({ ...filters, adult: e.target.checked })} />
        </label>
      )}
      {hasFilters(filters) && <button type="button" className="btn btn--quiet btn--auto btn--sm" onClick={() => onChange(NO_FILTERS)}>{t("lib.clearFilters")}</button>}
    </div>
  );
}

function categoryOf(categories: Category[], shelf: Shelf) {
  return categories.find((c) => c.id === CATEGORY_BY_SHELF[shelf]);
}

function shelfTitle(categories: Category[], shelf: Shelf) {
  return shelf === "huisclos" ? t("lib.shelf.huisclos") : categoryOf(categories, shelf)?.title ?? t(`lib.shelf.${shelf}`);
}

export function Libraries() {
  const { userId } = useAuth();
  const cat = useCatalog(userId);
  const [state, setState] = useState<LibState>(loadState);
  const { cap } = useCap();

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

  // En duo, seules les activités compatibles avec les préférences des deux sont proposées.
  const allowed = useMemo(() => cat.games.filter((g) => intensityRank(g.intensity) <= cap), [cat.games, cap]);
  const hidden = cat.games.length - allowed.length;

  const byShelf = useMemo(() => {
    const m = new Map<Shelf, Game[]>(SHELVES.map((s) => [s, []]));
    for (const g of allowed) {
      if (g.meta?.random) continue;
      const s = shelfOf(g);
      if (s) m.get(s)!.push(g);
    }
    return m;
  }, [allowed]);

  const q = normalizeText(state.query.trim());
  const filtering = !!q || hasFilters(state.filters);
  const results = useMemo(() => filtering
    ? allowed.filter((g) => matchesFilters(g, state.filters)
      && (!q || normalizeText(`${g.title} ${g.hook} ${g.promise}`).includes(q)))
    : [], [allowed, q, filtering, state.filters]);
  const nFilters = state.filters.intensity.length + state.filters.duration.length + state.filters.format.length + (state.filters.adult ? 1 : 0);

  if (cat.loading) return <PageLoading />;
  const count = (s: Shelf) => byShelf.get(s)?.length ?? 0;

  return (
    <main className="page page--tight">
      <div className="page-header">
        <h1 className="t-page">{t("lib.title")}</h1>
      </div>
      {cat.error && (
        <Alert>{t("lib.error")} <button className="btn btn--quiet btn--auto btn--sm" onClick={() => void cat.reload()}>{t("common.retry")}</button></Alert>
      )}
      <div className="search-row">
      <div className="search">
        <Icon name="search" size={20} />
        <label htmlFor="search" className="sr-only">{t("lib.search")}</label>
        <input id="search" className="input" type="search" placeholder={t("lib.searchShort")} value={state.query}
          onChange={(e) => setState((s) => ({ ...s, query: e.target.value }))} enterKeyHint="search" />
      </div>
        <button type="button" className="icon-btn icon-btn--soft filter-btn" aria-expanded={state.open} aria-controls="lib-filters"
          aria-label={nFilters ? t("filter.openN", { n: nFilters }) : t("filter.open")} onClick={() => setState((s) => ({ ...s, open: !s.open }))}>
          <Icon name="filter" size={20} />{nFilters > 0 && <span className="filter-badge" aria-hidden="true">{nFilters}</span>}
        </button>
      </div>
      {state.open && <FilterPanel filters={state.filters} cap={cap} adultOk onChange={(f) => setState((s) => ({ ...s, filters: f }))} />}
      {hidden > 0 && <p className="t-meta row"><Icon name="shield-check" size={18} />{t("filter.hidden", { n: hidden })}</p>}
      <p className="sr-only" aria-live="polite">{filtering ? t("lib.results", { n: results.length }) : ""}</p>

      {cat.games.length === 0 ? (
        <div className="card stack center"><p className="t-card">{t("lib.emptyCatalog")}</p></div>
      ) : filtering ? (
        results.length ? <TileGrid games={results} /> : (
          <div className="card stack center">
            <p className="t-card">{t("lib.noResults")}</p>
            <button className="btn btn--secondary btn--auto" onClick={() => setState((s) => ({ ...s, query: "", filters: NO_FILTERS }))}>{t("lib.clearFilters")}</button>
          </div>
        )
      ) : (
        <>
          <div className="stack" style={{ gap: "var(--grid-gap)" }}>
            {count("questions") > 0 && <ShelfBanner shelf="questions" title={shelfTitle(cat.categories, "questions")} text={t("lib.bannerText.questions")} />}
            {count("huisclos") > 0 && <ShelfBanner shelf="huisclos" title={t("lib.shelf.huisclos")} text={t("lib.huisclosText")} />}
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
        </>
      )}
    </main>
  );
}

const COUNTS = [5, 10, 20] as const;

/** Questionnaire aléatoire : questions libres de la rubrique tirées au hasard, en 5, 10 ou 20 questions. */
function RandomLauncher({ game }: { game: Game }) {
  const { active } = useDuo();
  const online = useOnline();
  const { launch, busy, error, dialog } = useLaunch();
  const [n, setN] = useState<number>(10);
  const [mixedReady, setMixedReady] = useState(false);
  useEffect(() => {
    let cancelled = false;
    setMixedReady(false);
    void supabase.from("game_versions").select("config").eq("game_id", game.id).eq("version", game.current_version).maybeSingle().then(({data}) => {
      if (!cancelled) setMixedReady(data?.config?.pack?.mixed_queue === true);
    });
    return () => { cancelled = true; };
  }, [game.id, game.current_version]);
  return (
    <section className="card card--lavender stack stack--3" aria-labelledby="rnd-title">
      <div className="row" style={{ gap: "var(--s-3)" }}>
        <Art name={artOf(game)} size={56} />
        <div className="stack" style={{ gap: 2 }}>
          <h2 className="t-card" id="rnd-title">{t("lib.random.title")}</h2>
        </div>
      </div>
      <div className="random-counts" role="radiogroup" aria-label={t("lib.random.count")}>
        {COUNTS.map((c) => (
          <button key={c} type="button" className="chip" role="radio" aria-checked={n === c} onClick={() => setN(c)}>{t("lib.random.n", { n: c })}</button>
        ))}
      </div>
      {!mixedReady && game.id === "ND-Q-RND1" && <p className="t-meta">Tirage classique disponible. L’ajout d’À huis clos attend la mise à jour du serveur.</p>}
      {game.adult_available && <p className="t-meta row"><Icon name="info" size={16} />{t("game.sexualContent")}</p>}
      {error && <Alert>{error}</Alert>}
      {active
        ? <button className="btn" disabled={busy || !online} onClick={() => void launch(game.id, game.title, { questions: n })}>{busy ? t("common.sending") : t("lib.random.go", { n })}<Icon name="arrow-right" /></button>
        : <Link className="btn btn--secondary" to="/inviter">{t("duo.invite")}</Link>}
      {dialog}
    </section>
  );
}

/** Page d'une rubrique (Se découvrir, À huis clos) : questionnaire aléatoire, packs de questions et questionnaires. */
export function ShelfPage({ shelf: asked }: { shelf: "questions" | "tests" | "huisclos" }) {
  // « Mieux se comprendre » a rejoint « Se découvrir » : l'ancienne adresse mène à la même page.
  const shelf = asked === "tests" ? "questions" : asked;
  const { userId } = useAuth();
  const cat = useCatalog(userId);
  const { cap } = useCap();
  if (cat.loading) return <PageLoading />;
  const games = cat.games.filter((g) => shelfOf(g) === shelf && intensityRank(g.intensity) <= cap);
  const random = games.find((g) => g.meta?.random && g.implementation === "playable");
  const packs = games.filter((g) => !g.meta?.random && g.mechanic !== "test_form");
  const tests = games.filter((g) => g.mechanic === "test_form");
  return (
    <SubPage backTo="/bibliotheques" title={shelfTitle(cat.categories, shelf)}>
      <main className="page page--bare page--tight">
        <div className="page-header">
          <h1 className="t-page">{shelfTitle(cat.categories, shelf)}</h1>
          <p className="t-small muted">{shelf === "huisclos" ? t("lib.huisclosText") : categoryOf(cat.categories, shelf)?.promise}</p>
        </div>
        {cat.error && <Alert>{t("lib.error")}</Alert>}
        {(
          <>
            {random && <RandomLauncher game={random} />}
            {packs.length > 0 && (
              <section className="section" aria-labelledby="shelf-packs">
                <h2 className="t-section" id="shelf-packs">{t("lib.choosePack")}</h2>
                <PackList games={packs} />
              </section>
            )}
            {tests.length > 0 && (
              <section className="section" aria-labelledby="shelf-tests">
                <h2 className="t-section" id="shelf-tests">{t("lib.chooseTest")}</h2>
                <PackList games={tests} />
              </section>
            )}
            {!packs.length && !tests.length && <div className="card stack center"><p className="t-card">{t("lib.emptyCatalog")}</p></div>}
          </>
        )}
        {shelf === "huisclos" && <HealthResources />}
      </main>
    </SubPage>
  );
}

/** Fiche d'un jeu : promesse, règles et lancement (sélection → règles → salon). */
export function GameSheet() {
  const { gameId = "" } = useParams();
  const { userId } = useAuth();
  const { active } = useDuo();
  const cat = useCatalog(userId);
  const online = useOnline();
  const { launch, busy, error, dialog, otherFor } = useLaunch();
  const [rules, setRules] = useState<GameRules | null>(null);
  const [showRules, setShowRules] = useState(false);
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

  const other = otherFor(game.id);
  const favorite = cat.favorites.has(game.id);
  const soon = game.implementation !== "playable";
  const catTitle = cat.categories.find((c) => c.id === game.category_id)?.title;
  const shelf = shelfOf(game);
  const backTo = shelf === "questions" || shelf === "tests" || shelf === "huisclos" ? SHELF_PATH[shelf] : "/bibliotheques";
  const intime = game.content_level === "intime";

  const prepare = () => void launch(game.id, game.title);

  return (
    <SubPage backTo={backTo} title={game.title} actions={
      <button className="icon-btn icon-btn--soft" aria-pressed={favorite} onClick={() => void cat.toggleFavorite(game.id)}
        aria-label={favorite ? t("lib.removeFavorite", { title: game.title }) : t("lib.addFavorite", { title: game.title })}>
        <Icon name={favorite ? "star" : "bookmark"} />
      </button>
    }>
      <main className="page page--bare page--read">
        <div className="game-intro">
          <Art name={artOf(game)} size={112} className="game-intro__art" />
          <h1 className="t-page">{game.title}</h1>
          <p className="t-small muted">{game.hook || game.promise}</p>
          <div className="row row--wrap" style={{ gap: 6 }}>
            <span className="nd-chip">{typeLabel(game)}</span>
            <span className="nd-chip nd-chip--mint">{durationLabel(game)}</span>
            {game.intensity && <span className="nd-chip">{t(`filter.intensity.${game.intensity}`)}</span>}
            {catTitle && <span className="nd-chip nd-chip--peach">{intime ? t("lib.shelf.huisclos") : catTitle}</span>}
            {game.is_demo && <DemoTag />}
          </div>
        </div>
        {soon ? (
          <Alert kind="info">{t("sheet.soon")}</Alert>
        ) : !rules ? <Loading /> : (
          <ul className="info-rows">
            <li className="info-row"><Icon name="users" size={20} /><span className="grow">{t("sheet.twoPlayers")}</span></li>
            <li className="info-row"><Icon name="lock-keyhole" size={20} /><span className="grow">{rules.privacy}</span></li>
            {intime && <li className="info-row"><Icon name="shield-check" size={20} /><span className="grow">{t("sheet.huisclosRule")}</span></li>}
          </ul>
        )}
        {!soon && rules && <button className="btn btn--secondary" onClick={() => setShowRules(true)}><Icon name="book-open" size={20} />{t("sheet.seeRules")}</button>}
        {dialog}
        {showRules && rules && <RulesSheet title={game.title} rules={rules} onClose={() => setShowRules(false)} />}
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
              <button className="btn" disabled={busy || !online} onClick={prepare}>{t("launch.closeAndStart")}<Icon name="arrow-right" /></button>
              <Link className="btn btn--secondary" to={`/partie/${other.id}`}>{t("sheet.goToOther")}</Link>
            </>
          ) : (
            <button className="btn" disabled={busy || !online} onClick={prepare}>{busy ? t("common.sending") : t("sheet.prepare")}<Icon name="arrow-right" /></button>
          )}
        </div>
      </main>
    </SubPage>
  );
}
