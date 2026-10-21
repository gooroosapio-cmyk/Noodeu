import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router";
import { t } from "../i18n";
import { errorMessage } from "../lib/errors";
import { rpc, supabase } from "../lib/supabase";
import { useOnline } from "../lib/useOnline";
import { useAuth } from "../auth/AuthProvider";
import { useDuo } from "../duo/DuoProvider";
import { SubPage } from "../components/AppShell";
import { Alert, DemoTag, Icon, Illustration, Loading, PageLoading, Sheet, useToast } from "../components/ui";
import type { Category, Game } from "../lib/types";
import {
  applyFilters, countFilters, emptyFilters, matchesDuration, mechanicIllustration, normalizeText, useCatalog,
  type DurationBucket, type Filters,
} from "./catalog";

/** Carte de jeu : zone principale (fiche) et favori sont deux contrôles frères. */
export function GameCard({ game, favorite, onToggleFavorite, categoryTitle }: {
  game: Game; favorite: boolean; onToggleFavorite: () => Promise<boolean>; categoryTitle?: string;
}) {
  const toast = useToast();
  const [pending, setPending] = useState(false);
  return (
    <article className="game-card">
      <div className="game-card__thumb" aria-hidden="true">
        <Illustration name={mechanicIllustration[game.mechanic] ?? "01-connexion-a-deux"} />
      </div>
      <Link className="game-card__main" to={`/bibliotheques/${game.id}`}>
        <span className="game-card__title">{game.title}</span>
        <span className="t-meta">
          {t("common.minutes", { min: game.duration_min, max: game.duration_max })}
          {categoryTitle ? ` · ${categoryTitle}` : ` · ${t(`lib.style.${game.style}`)}`}
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
      <p className="game-card__desc">{game.promise}</p>
    </article>
  );
}

const STORE = "noodeu.lib.state";
type Sort = "recommended" | "shortest" | "alpha";
interface LibState { quick: "all" | "favorites"; query: string; filters: Filters; sort: Sort; scroll: number }

function loadState(): LibState {
  try {
    const s = JSON.parse(sessionStorage.getItem(STORE) ?? "null") as LibState | null;
    if (s) return s;
  } catch {
    /* rien */
  }
  return { quick: "all", query: "", filters: emptyFilters, sort: "recommended", scroll: 0 };
}

const durationLabels: Record<DurationBucket, string> = {
  short: t("filters.durationShort"), mid: t("filters.durationMid"), long: t("filters.durationLong"),
};
const levelLabels = { standard: t("filters.levelStandard"), intime: t("filters.levelIntime") };

/** Options réellement présentes dans le catalogue (aucun filtre vide ou fictif). */
function availableOptions(games: Game[], categories: Category[]) {
  const family = categories.filter((c) => games.some((g) => g.category_id === c.id)).map((c) => ({ id: c.id, label: c.title }));
  const duration = (["short", "mid", "long"] as DurationBucket[]).filter((b) => games.some((g) => matchesDuration(g, b))).map((b) => ({ id: b, label: durationLabels[b] }));
  const level = (["standard", "intime"] as const).filter((l) => games.some((g) => g.content_level === l)).map((l) => ({ id: l, label: levelLabels[l] }));
  return { family, duration, level };
}

function FilterSheet({ games, categories, applied, onApply, onClose }: {
  games: Game[]; categories: Category[]; applied: Filters; onApply: (f: Filters) => void; onClose: () => void;
}) {
  // Brouillon : rien n'est appliqué tant que « Voir les N jeux » n'est pas touché.
  const [draft, setDraft] = useState<Filters>(applied);
  const opts = availableOptions(games, categories);
  const n = applyFilters(games, draft).length;
  const groups: { key: keyof Filters; title: string; options: { id: string; label: string }[]; hint?: string }[] = [
    { key: "family", title: t("filters.family"), options: opts.family },
    { key: "duration", title: t("filters.duration"), options: opts.duration, hint: t("filters.durationRule") },
    { key: "level", title: t("filters.level"), options: opts.level },
  ].filter((g) => g.options.length >= 2) as never;

  function toggle(key: keyof Filters, id: string) {
    setDraft((d) => {
      const list = d[key] as string[];
      return { ...d, [key]: list.includes(id) ? list.filter((x) => x !== id) : [...list, id] };
    });
  }

  return (
    <Sheet
      side
      title={<h2 className="t-section">{t("filters.title")}</h2>}
      onClose={onClose}
      footer={
        <div className="sheet__foot">
          <button className="btn btn--secondary btn--auto" onClick={() => setDraft(emptyFilters)}>{t("filters.reset")}</button>
          <button className="btn" disabled={n === 0} onClick={() => onApply(draft)}>
            {n === 0 ? t("filters.applyNone") : n === 1 ? t("filters.applyOne") : t("filters.apply", { n })}
          </button>
        </div>
      }
    >
      {groups.map((g) => (
        <fieldset key={g.key}>
          <legend>{g.title}</legend>
          <div className="chips">
            {g.options.map((o) => (
              <button key={o.id} type="button" className="chip" role="checkbox" aria-checked={(draft[g.key] as string[]).includes(o.id)} onClick={() => toggle(g.key, o.id)}>
                {(draft[g.key] as string[]).includes(o.id) && <Icon name="check" size={16} />}
                {o.label}
              </button>
            ))}
          </div>
          {g.hint && <p className="t-meta">{g.hint}</p>}
        </fieldset>
      ))}
    </Sheet>
  );
}

export function Libraries() {
  const { userId } = useAuth();
  const cat = useCatalog(userId);
  const [state, setState] = useState<LibState>(loadState);
  const [sheet, setSheet] = useState(false);
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
    // En quittant la liste (vers une fiche), on mémorise la position de lecture.
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
      (state.quick !== "favorites" || cat.favorites.has(g.id)) && (!q || normalizeText(`${g.title} ${g.promise}`).includes(q)));
    if (state.sort === "shortest") list = [...list].sort((a, b) => a.duration_min - b.duration_min);
    if (state.sort === "alpha") list = [...list].sort((a, b) => a.title.localeCompare(b.title, "fr"));
    return list;
  }, [cat.games, cat.favorites, state]);

  if (cat.loading) return <PageLoading />;

  const active = countFilters(state.filters);
  const summary: { key: keyof Filters; id: string; label: string }[] = [
    ...state.filters.family.map((id) => ({ key: "family" as const, id, label: catTitle.get(id) ?? id })),
    ...state.filters.duration.map((id) => ({ key: "duration" as const, id, label: durationLabels[id] })),
    ...state.filters.level.map((id) => ({ key: "level" as const, id, label: levelLabels[id] })),
  ];
  const remove = (key: keyof Filters, id: string) =>
    update({ filters: { ...state.filters, [key]: (state.filters[key] as string[]).filter((x) => x !== id) } });

  return (
    <main className="page">
      <div className="page-header">
        <h1 className="t-page">{t("lib.title")}</h1>
        <p>{t("lib.subtitle")}</p>
      </div>
      {cat.error && (
        <Alert>{t("lib.error")} <button className="btn btn--quiet btn--auto btn--sm" onClick={() => void cat.reload()}>{t("common.retry")}</button></Alert>
      )}
      <div className="stack">
        <div className="toolbar">
          <div className="search">
            <Icon name="search" size={20} />
            <label htmlFor="search" className="sr-only">{t("lib.search")}</label>
            <input id="search" className="input" type="search" placeholder={t("lib.search")} value={state.query} onChange={(e) => update({ query: e.target.value })} enterKeyHint="search" />
          </div>
          <button ref={filterBtn} className="btn btn--secondary btn--auto" onClick={() => setSheet(true)} aria-label={active ? t("lib.filtersCount", { n: active }) : t("lib.filters")}>
            <Icon name="filter" size={20} />{t("lib.filters")}{active > 0 && <span className="tag" style={{ minHeight: 22 }} aria-hidden="true">{active}</span>}
          </button>
        </div>
        <div className="row row--between row--wrap">
          <div className="chips" role="group" aria-label={t("lib.title")}>
            <button className="chip" aria-pressed={state.quick === "all"} onClick={() => update({ quick: "all" })}>{t("lib.all")}</button>
            <button className="chip" aria-pressed={state.quick === "favorites"} onClick={() => update({ quick: "favorites" })}><Icon name="star" size={18} />{t("lib.favorites")}</button>
          </div>
          <label className="row t-small" style={{ gap: 8 }}>
            <span className="sr-only">Trier</span>
            <select className="input" style={{ minHeight: 44, width: "auto", paddingBlock: 8 }} value={state.sort} onChange={(e) => update({ sort: e.target.value as Sort })}>
              <option value="recommended">Recommandés</option>
              <option value="shortest">Plus courts</option>
              <option value="alpha">A à Z</option>
            </select>
          </label>
        </div>
        {summary.length > 0 && (
          <div className="chips" aria-label={t("lib.filters")}>
            {summary.slice(0, 2).map((s) => (
              <button key={`${s.key}-${s.id}`} className="chip chip--remove" onClick={() => remove(s.key, s.id)} aria-label={t("lib.removeFilter", { label: s.label })}>
                {s.label}<Icon name="close" size={16} />
              </button>
            ))}
            {summary.length > 2 && <button className="chip" onClick={() => setSheet(true)}>+{summary.length - 2}</button>}
            <button className="btn btn--quiet btn--auto btn--sm" onClick={() => update({ filters: emptyFilters })}>{t("lib.clearAll")}</button>
          </div>
        )}
        <p className="t-meta" aria-live="polite">{t("lib.results", { n: shown.length })}</p>
      </div>

      {shown.length === 0 ? (
        <div className="card stack center">
          <p className="t-card">{state.quick === "favorites" && !active && !state.query ? t("lib.emptyFavorites") : t("lib.noResults")}</p>
          {(active > 0 || state.query) && (
            <button className="btn btn--secondary btn--auto" onClick={() => update({ filters: emptyFilters, query: "" })}>{t("lib.clearFilters")}</button>
          )}
        </div>
      ) : (
        <div className="stack grid-2 grid-3">
          {shown.map((g) => (
            <GameCard key={g.id} game={g} favorite={cat.favorites.has(g.id)} categoryTitle={catTitle.get(g.category_id)} onToggleFavorite={() => cat.toggleFavorite(g.id)} />
          ))}
        </div>
      )}

      {sheet && (
        <FilterSheet games={cat.games} categories={cat.categories} applied={state.filters}
          onApply={(f) => { update({ filters: f }); setSheet(false); }} onClose={() => setSheet(false)} />
      )}
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
    if (!game) return;
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
        <div className="row" style={{ alignItems: "flex-start" }}>
          <div className="game-card__thumb" aria-hidden="true" style={{ width: 72, height: 72 }}>
            <Illustration name={mechanicIllustration[game.mechanic] ?? "01-connexion-a-deux"} eager />
          </div>
          <div className="stack stack--2 grow">
            <h1 className="t-page">{game.title}</h1>
            <p className="t-meta">{t("common.minutes", { min: game.duration_min, max: game.duration_max })} · {t(`lib.style.${game.style}`)}</p>
            {game.is_demo && <div><DemoTag /></div>}
          </div>
        </div>
        <p>{game.promise}</p>
        {!rules ? <Loading /> : (
          <>
            <section className="card card--soft stack stack--4">
              <h2 className="t-section">{t("sheet.howTo")}</h2>
              <ol className="how">{rules.how_to.map((x) => <li key={x}>{x}</li>)}</ol>
              <p className="row t-small"><Icon name="lock" size={18} />{rules.privacy}</p>
            </section>
            <details className="disclosure">
              <summary>{t("sheet.details")}<Icon name="chevron-down" /></summary>
              <div><p>{rules.objective}</p><ul style={{ margin: 0, paddingLeft: 20 }}>{rules.details.map((x) => <li key={x}>{x}</li>)}</ul></div>
            </details>
          </>
        )}
        {error && <Alert>{error}</Alert>}
        <div className="action-bar">
          {!active ? (
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
