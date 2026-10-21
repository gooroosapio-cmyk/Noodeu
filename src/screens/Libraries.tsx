import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router";
import { t } from "../i18n";
import { errorMessage } from "../lib/errors";
import { rpc, supabase } from "../lib/supabase";
import { useOnline } from "../lib/useOnline";
import { useAuth } from "../auth/AuthProvider";
import { useDuo } from "../duo/DuoProvider";
import { SubPage } from "../components/AppShell";
import { Alert, DemoTag, Icon, Illustration, Loading, PageLoading, useToast } from "../components/ui";
import type { Category, Game, GameStyle } from "../lib/types";
import {
  applyFilters, changesResults, countFilters, emptyFilters, matchesQuick, mechanicIllustration, normalizeText, useCatalog,
  type Filters, type Quick, type Show,
} from "./catalog";

/** Vignette d'activité (image du kit servie par l'application) ; illustration générique à défaut. */
export function GameThumb({ game, size = "md" }: { game: Pick<Game, "thumbnail" | "mechanic">; size?: "md" | "lg" }) {
  return (
    <div className={`game-card__thumb game-card__thumb--wide${size === "lg" ? " game-card__thumb--lg" : ""}`} aria-hidden="true">
      {game.thumbnail
        ? <img src={game.thumbnail} alt="" loading="lazy" decoding="async" width={720} height={420} />
        : <Illustration name={mechanicIllustration[game.mechanic] ?? "01-connexion-a-deux"} />}
    </div>
  );
}

/** Carte d'activité : zone principale (fiche) et favori sont deux contrôles frères. */
export function GameCard({ game, favorite, onToggleFavorite, categoryTitle }: {
  game: Game; favorite: boolean; onToggleFavorite: () => Promise<boolean>; categoryTitle?: string;
}) {
  const toast = useToast();
  const [pending, setPending] = useState(false);
  const soon = game.implementation === "coming_soon";
  return (
    <article className={soon ? "game-card game-card--soon" : "game-card"}>
      <GameThumb game={game} />
      <Link className="game-card__main" to={`/bibliotheques/${game.id}`}>
        <span className="game-card__title">{game.title}</span>
        <span className="t-meta">
          {t(`lib.style.${game.style}`)}
          {categoryTitle ? ` · ${categoryTitle}` : ""}
          {soon && <> · <span className="tag tag--soon">{t("lib.soon")}</span></>}
        </span>
      </Link>
      <button
        className="icon-btn"
        aria-pressed={favorite}
        disabled={pending}
        aria-label={favorite ? t("lib.removeFavorite", { title: game.title }) : t("lib.addFavorite", { title: game.title })}
        onClick={async () => {
          setPending(true);
          const ok = await onToggleFavorite();
          setPending(false);
          if (!ok) toast(t("lib.favoriteError"));
        }}
      >
        <Icon name={favorite ? "star" : "bookmark"} />
      </button>
      <p className="game-card__desc">{game.hook || game.promise}</p>
    </article>
  );
}

const STORE = "noodeu.lib.state.v2";
type Sort = "recommended" | "alpha" | "playable";
interface LibState { quick: Quick; show: Show; query: string; filters: Filters; sort: Sort; scroll: number }

function loadState(): LibState {
  try {
    const s = JSON.parse(sessionStorage.getItem(STORE) ?? "null") as LibState | null;
    if (s) return { ...s, filters: { ...emptyFilters, ...s.filters } };
  } catch {
    /* rien */
  }
  return { quick: "all", show: "all", query: "", filters: emptyFilters, sort: "recommended", scroll: 0 };
}

const MODES: GameStyle[] = ["echange", "creation", "cooperation", "duel"];

/** Options réellement utiles : un groupe n'apparaît que s'il change les résultats. */
function availableOptions(games: Game[], categories: Category[]) {
  const family = categories.filter((c) => changesResults(games, (g) => g.category_id === c.id)).map((c) => ({ id: c.id, label: c.title }));
  const mode = MODES.filter((m) => changesResults(games, (g) => g.style === m)).map((m) => ({ id: m, label: t(`lib.style.${m}`) }));
  const diffs = [...new Set(games.flatMap((g) => g.difficulties))];
  const difficulty = diffs.filter((d) => changesResults(games, (g) => g.difficulties.includes(d))).map((d) => ({ id: d, label: d === "facile" || d === "normal" ? t(`lib.difficulty.${d}`) : d }));
  return {
    family: family.length >= 2 ? family : [],
    mode: mode.length >= 2 ? mode : [],
    difficulty,
    mute: changesResults(games, (g) => g.mute_ok),
    adult: changesResults(games, (g) => g.adult_available),
  };
}

/** Filtre déroulant sous la recherche : chaque choix s'applique immédiatement. */
function FilterPanel({ id, games, categories, state, update, onClose, hasRecent }: {
  id: string; games: Game[]; categories: Category[]; state: LibState; update: (p: Partial<LibState>) => void; onClose: () => void; hasRecent: boolean;
}) {
  const opts = availableOptions(games, categories);
  const groups = ([
    { key: "family", title: t("filters.family"), options: opts.family },
    { key: "mode", title: t("filters.mode"), options: opts.mode },
    { key: "difficulty", title: t("filters.difficulty"), options: opts.difficulty },
  ] as { key: "family" | "mode" | "difficulty"; title: string; options: { id: string; label: string }[] }[]).filter((g) => g.options.length > 0);

  function toggle(key: "family" | "mode" | "difficulty", value: string) {
    const list = state.filters[key] as string[];
    update({ filters: { ...state.filters, [key]: list.includes(value) ? list.filter((x) => x !== value) : [...list, value] } });
  }

  return (
    <div id={id} className="filter-panel" role="region" aria-label={t("lib.filters")}
      onKeyDown={(e) => { if (e.key === "Escape") { e.stopPropagation(); onClose(); } }}>
      <fieldset>
        <legend>{t("lib.show")}</legend>
        <div className="chips">
          <button type="button" className="chip" aria-pressed={state.show === "all"} onClick={() => update({ show: "all" })}>{t("lib.showAll")}</button>
          <button type="button" className="chip" aria-pressed={state.show === "favorites"} onClick={() => update({ show: "favorites" })}><Icon name="star" size={16} />{t("lib.favorites")}</button>
          {hasRecent && <button type="button" className="chip" aria-pressed={state.show === "recent"} onClick={() => update({ show: "recent" })}><Icon name="clock" size={16} />{t("lib.recent")}</button>}
        </div>
      </fieldset>
      {groups.map((g) => (
        <fieldset key={g.key}>
          <legend>{g.title}</legend>
          <div className="chips">
            {g.options.map((o) => {
              const on = (state.filters[g.key] as string[]).includes(o.id);
              return (
                <button key={o.id} type="button" className="chip" role="checkbox" aria-checked={on} onClick={() => toggle(g.key, o.id)}>
                  {on && <Icon name="check" size={16} />}{o.label}
                </button>
              );
            })}
          </div>
        </fieldset>
      ))}
      {(opts.mute || opts.adult) && (
        <fieldset>
          <legend>{t("filters.more")}</legend>
          <div className="chips">
            {opts.mute && <button type="button" className="chip" role="checkbox" aria-checked={state.filters.mute}
              onClick={() => update({ filters: { ...state.filters, mute: !state.filters.mute } })}>{state.filters.mute && <Icon name="check" size={16} />}{t("filters.mute")}</button>}
            {opts.adult && <button type="button" className="chip" role="checkbox" aria-checked={state.filters.adult}
              onClick={() => update({ filters: { ...state.filters, adult: !state.filters.adult } })}>{state.filters.adult && <Icon name="check" size={16} />}{t("filters.adult")}</button>}
          </div>
        </fieldset>
      )}
      <label className="filter-panel__sort">
        <span className="t-small">{t("lib.sort")}</span>
        <select className="input" value={state.sort} onChange={(e) => update({ sort: e.target.value as Sort })}>
          <option value="recommended">{t("lib.sortRecommended")}</option>
          <option value="playable">{t("lib.sortPlayable")}</option>
          <option value="alpha">{t("lib.sortAlpha")}</option>
        </select>
      </label>
      <div className="row row--between">
        <button type="button" className="btn btn--quiet btn--auto btn--sm" onClick={() => update({ show: "all", filters: emptyFilters, sort: "recommended" })}>{t("filters.reset")}</button>
        <button type="button" className="btn btn--secondary btn--auto btn--sm" onClick={onClose}>{t("lib.closeFilters")}</button>
      </div>
    </div>
  );
}

export function Libraries() {
  const { userId } = useAuth();
  const cat = useCatalog(userId);
  const [state, setState] = useState<LibState>(loadState);
  const [open, setOpen] = useState(false);
  const filterBtn = useRef<HTMLButtonElement>(null);
  const update = (patch: Partial<LibState>) => setState((s) => ({ ...s, ...patch }));

  // Filtres et position conservés en mémoire de session (jamais dans l'URL).
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

  const catTitle = useMemo(() => new Map(cat.categories.map((c) => [c.id, c.title])), [cat.categories]);
  const shown = useMemo(() => {
    const q = normalizeText(state.query.trim());
    let list = applyFilters(cat.games, state.filters).filter((g) =>
      matchesQuick(g, state.quick)
      && (state.show !== "favorites" || cat.favorites.has(g.id))
      && (state.show !== "recent" || cat.recent.includes(g.id))
      && (!q || normalizeText(`${g.title} ${g.hook} ${g.promise}`).includes(q)));
    if (state.show === "recent") list = [...list].sort((a, b) => cat.recent.indexOf(a.id) - cat.recent.indexOf(b.id));
    else if (state.sort === "alpha") list = [...list].sort((a, b) => a.title.localeCompare(b.title, "fr"));
    else if (state.sort === "playable") list = [...list].sort((a, b) => Number(a.implementation !== "playable") - Number(b.implementation !== "playable"));
    return list;
  }, [cat.games, cat.favorites, cat.recent, state]);

  if (cat.loading) return <PageLoading />;

  const active = countFilters(state.filters) + (state.show !== "all" ? 1 : 0);
  const closePanel = () => { setOpen(false); filterBtn.current?.focus(); };
  // Regroupement par famille quand l'ordre recommandé est utilisé (sinon : liste continue).
  const grouped = state.sort === "recommended" && state.show !== "recent";
  const sections = grouped
    ? cat.categories.map((c) => ({ id: c.id, title: c.title, games: shown.filter((g) => g.category_id === c.id) })).filter((s) => s.games.length)
    : [{ id: "all", title: "", games: shown }];

  return (
    <main className="page page--tight">
      <h1 className="t-page">{t("lib.title")}</h1>
      {cat.error && (
        <Alert>{t("lib.error")} <button className="btn btn--quiet btn--auto btn--sm" onClick={() => void cat.reload()}>{t("common.retry")}</button></Alert>
      )}
      <div className="lib-tools">
        <div className="toolbar">
          <div className="search">
            <Icon name="search" size={20} />
            <label htmlFor="search" className="sr-only">{t("lib.search")}</label>
            <input id="search" className="input" type="search" placeholder={t("lib.searchShort")} value={state.query} onChange={(e) => update({ query: e.target.value })} enterKeyHint="search" />
          </div>
          <button ref={filterBtn} className="btn btn--secondary btn--auto filter-btn" aria-expanded={open} aria-controls="lib-filters"
            onClick={() => setOpen((o) => !o)} aria-label={active ? t("lib.filtersCount", { n: active }) : t("lib.filters")}>
            <Icon name="filter" size={20} /><span className="filter-btn__label">{t("lib.filters")}</span>
            {active > 0 && <span className="tag" style={{ minHeight: 22 }} aria-hidden="true">{active}</span>}
            <Icon name="chevron-down" size={18} />
          </button>
        </div>
        <div className="chips chips--scroll" role="group" aria-label={t("lib.quick")}>
          {(["all", "together", "duel"] as Quick[]).map((q) => (
            <button key={q} type="button" className="chip" aria-pressed={state.quick === q} onClick={() => update({ quick: q })}>{t(`lib.quick.${q}`)}</button>
          ))}
        </div>
        {open && <FilterPanel id="lib-filters" games={cat.games} categories={cat.categories} state={state} update={update} onClose={closePanel} hasRecent={cat.recent.length > 0} />}
        <p className="sr-only" aria-live="polite">{t("lib.results", { n: shown.length })}</p>
      </div>

      {shown.length === 0 ? (
        <div className="card stack center">
          <p className="t-card">{state.show === "favorites" && !countFilters(state.filters) && !state.query ? t("lib.emptyFavorites") : t("lib.noResults")}</p>
          {(active > 0 || state.query || state.quick !== "all") && (
            <button className="btn btn--secondary btn--auto" onClick={() => update({ filters: emptyFilters, query: "", show: "all", quick: "all" })}>{t("lib.clearFilters")}</button>
          )}
        </div>
      ) : sections.map((sec) => (
        <section key={sec.id} className="section" aria-labelledby={sec.title ? `fam-${sec.id}` : undefined}>
          {sec.title && <h2 className="t-section" id={`fam-${sec.id}`}>{sec.title}</h2>}
          <div className="stack grid-2 grid-3">
            {sec.games.map((g) => (
              <GameCard key={g.id} game={g} favorite={cat.favorites.has(g.id)} categoryTitle={grouped ? undefined : catTitle.get(g.category_id)}
                onToggleFavorite={() => cat.toggleFavorite(g.id)} />
            ))}
          </div>
        </section>
      ))}
    </main>
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
    <SubPage backTo="/bibliotheques" actions={
      <button className="icon-btn icon-btn--soft" aria-pressed={favorite} onClick={() => void cat.toggleFavorite(game.id)}
        aria-label={favorite ? t("lib.removeFavorite", { title: game.title }) : t("lib.addFavorite", { title: game.title })}>
        <Icon name={favorite ? "star" : "bookmark"} />
      </button>
    }>
      <main className="page page--bare page--read">
        <GameThumb game={game} size="lg" />
        <div className="stack stack--2">
          <h1 className="t-page">{game.title}</h1>
          <p className="t-meta">
            {t(`lib.style.${game.style}`)}{catTitle ? ` · ${catTitle}` : ""}
            {game.adult_available && <> · {t("sheet.adultAvailable")}</>}
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
              {game.adult_available && <p className="row t-small"><Icon name="info" size={18} />{t("sheet.adultRule")}</p>}
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
