import { useEffect, useState, useSyncExternalStore } from "react";
import { rpc, supabase } from "../lib/supabase";
import type { Category, Format, Game, Intensity } from "../lib/types";

interface CatalogSnapshot { categories: Category[]; games: Game[]; favorites: Set<string>; recent: string[]; loading: boolean; error: boolean }

// En mémoire seulement, avec un abonnement par compte : les écrans ouverts après une
// écriture optimiste reçoivent aussi sa confirmation ou son annulation.
const FRESH_MS = 30_000;
const catalogs = new Map<string | null, ReturnType<typeof createCatalog>>();

function createCatalog(userId: string | null) {
  let snapshot: CatalogSnapshot = { categories: [], games: [], favorites: new Set(), recent: [], loading: true, error: false };
  let confirmedFavorites = new Set<string>();
  const pendingFavorites = new Map<string, boolean>();
  const writes = new Map<string, Promise<boolean>>();
  const listeners = new Set<() => void>();
  let favoriteRevision = 0;
  let needsReconciliation = false;
  let at = 0;
  let inflight: Promise<void> | null = null;

  function publish(patch: Partial<CatalogSnapshot> = {}) {
    const favorites = new Set(confirmedFavorites);
    for (const [gameId, favorite] of pendingFavorites) {
      if (favorite) favorites.add(gameId);
      else favorites.delete(gameId);
    }
    snapshot = { ...snapshot, ...patch, favorites };
    for (const listener of listeners) listener();
  }

  function load(): Promise<void> {
    if (inflight) return inflight;
    const readRevision = favoriteRevision;
    const hadPendingFavorites = pendingFavorites.size > 0;
    publish({ error: false });
    const promise = Promise.resolve().then(async () => {
      if (!listeners.size) { at = 0; return; }
      const [c, g, f, r] = await Promise.all([
        supabase.from("game_categories").select("id, title, promise, sort, is_demo, family_no").eq("status", "published").order("sort"),
        supabase.from("games").select("id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max, content_level, current_version, sort, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, meta, intensity, formats, duration_kind").eq("status", "published").order("sort"),
        userId ? supabase.from("game_favorites").select("game_id").eq("user_id", userId) : Promise.resolve({ data: [], error: null }),
        // Parties du duo, lisibles par ses seuls membres.
        supabase.from("game_sessions").select("game_id, created_at").order("created_at", { ascending: false }).limit(40),
      ]);
      // Une lecture commencée avant une écriture (même déjà confirmée) ne doit
      // jamais la défaire. Les écritures encore en vol restent superposées.
      if (!f.error && !hadPendingFavorites && readRevision === favoriteRevision) {
        confirmedFavorites = new Set(((f.data as { game_id: string }[]) ?? []).map((x) => x.game_id));
        needsReconciliation = false;
      }
      const error = Boolean(c.error || g.error || f.error || r.error);
      if (!error && !needsReconciliation) at = Date.now();
      publish({
        categories: c.error ? snapshot.categories : (c.data as Category[]) ?? [],
        games: g.error ? snapshot.games : (g.data as Game[]) ?? [],
        recent: r.error ? snapshot.recent : [...new Set(((r.data as { game_id: string }[]) ?? []).map((x) => x.game_id))],
        loading: false,
        error,
      });
    }).catch(() => publish({ loading: false, error: true }))
      .finally(() => { if (inflight === promise) inflight = null; });
    inflight = promise;
    return promise;
  }

  async function reconcileFavorites() {
    // Ne pas rejoindre une lecture qui a précédé l'échec de l'écriture.
    if (inflight) await inflight;
    at = 0;
    // Après un changement de compte, ne pas lancer une requête de l'ancien
    // compte avec la nouvelle authentification. Son retour déclenchera la lecture.
    if (listeners.size && !pendingFavorites.size && needsReconciliation) await load();
  }

  function toggleFavorite(gameId: string): Promise<boolean> {
    if (!userId || !listeners.size) return Promise.resolve(false);
    const pending = writes.get(gameId);
    if (pending) return pending;
    const favorite = !snapshot.favorites.has(gameId);
    pendingFavorites.set(gameId, favorite);
    favoriteRevision += 1;
    const promise = Promise.resolve().then(async () => {
      const { error } = favorite
        ? await supabase.from("game_favorites").upsert({ user_id: userId, game_id: gameId }, { onConflict: "user_id,game_id", ignoreDuplicates: true })
        : await supabase.from("game_favorites").delete().eq("user_id", userId).eq("game_id", gameId);
      return !error;
    }).catch(() => false).then((ok) => {
      if (ok) {
        if (favorite) confirmedFavorites.add(gameId);
        else confirmedFavorites.delete(gameId);
      } else {
        needsReconciliation = true;
        at = 0;
      }
      pendingFavorites.delete(gameId);
      writes.delete(gameId);
      favoriteRevision += 1;
      publish();
      // Si un autre favori est encore en écriture, sa fin déclenchera la relecture.
      if (needsReconciliation && !pendingFavorites.size) void reconcileFavorites();
      return ok;
    });
    writes.set(gameId, promise);
    publish();
    return promise;
  }

  return {
    getSnapshot: () => snapshot,
    subscribe(listener: () => void) { listeners.add(listener); return () => { listeners.delete(listener); }; },
    ensureFresh() { if (!at || Date.now() - at > FRESH_MS) void load(); },
    reload: load,
    toggleFavorite,
  };
}

export function useCatalog(userId: string | null) {
  let catalog = catalogs.get(userId);
  if (!catalog) {
    catalog = createCatalog(userId);
    catalogs.set(userId, catalog);
  }
  const snapshot = useSyncExternalStore(catalog.subscribe, catalog.getSnapshot, catalog.getSnapshot);
  useEffect(() => { catalog.ensureFresh(); }, [catalog]);
  return { ...snapshot, reload: catalog.reload, toggleFavorite: catalog.toggleFavorite };
}

// ---------- Rayons de la bibliothèque ----------

/** Rayons affichés : deux grandes entrées (questions, tests), deux sections en grille, et l'espace « À huis clos ». */
export type Shelf = "questions" | "tests" | "conversation" | "minijeux" | "huisclos";
export const SHELVES: Shelf[] = ["questions", "tests", "conversation", "minijeux", "huisclos"];

const SHELF_BY_CATEGORY: Record<string, Shelf> = {
  "nd-se-decouvrir": "questions",
  "nd-mieux-se-comprendre": "questions", // rubrique fusionnée dans « Se découvrir »
  "nd-conversation-decouverte": "conversation",
  "nd-mini-jeux-interactifs": "minijeux",
};
// Première catégorie de chaque rayon (« Se découvrir » pour les questions, même avec l'ancienne catégorie fusionnée).
export const CATEGORY_BY_SHELF: Partial<Record<Shelf, string>> = Object.fromEntries(
  Object.entries(SHELF_BY_CATEGORY).reverse().map(([c, s]) => [s, c]),
);

/** Une activité intime rejoint « À huis clos », quelle que soit sa catégorie. */
export function shelfOf(g: Pick<Game, "category_id" | "content_level">): Shelf | null {
  if (g.content_level === "intime") return "huisclos";
  return SHELF_BY_CATEGORY[g.category_id] ?? null;
}

/** Adresse des pages d'entrée (les identifiants d'activité ne prennent jamais ces valeurs). */
export const SHELF_PATH: Record<"questions" | "tests" | "huisclos", string> = {
  questions: "/bibliotheques/questions",
  tests: "/bibliotheques/tests",
  huisclos: "/bibliotheques/a-huis-clos",
};

export function normalizeText(s: string) {
  return s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

// ---------- Filtres (intensité, durée, format) ----------

export const INTENSITIES: Intensity[] = ["soft", "moyen", "hot"];
export const FORMATS: Format[] = ["solo", "duo", "jeu", "rituel", "defi"];
export const DURATIONS = ["rapide", "discussion"] as const;
export const intensityRank = (i: Intensity | null | undefined) => (i === "hot" ? 3 : i === "moyen" ? 2 : 1);

export interface Filters { intensity: Intensity[]; duration: (typeof DURATIONS)[number][]; format: Format[]; adult: boolean }
export const NO_FILTERS: Filters = { intensity: [], duration: [], format: [], adult: false };
export const hasFilters = (f: Filters) => f.intensity.length + f.duration.length + f.format.length > 0 || f.adult;

/** Filtres combinés : chaque groupe restreint (ET entre groupes, OU à l'intérieur d'un groupe). */
export function matchesFilters(g: Game, f: Filters) {
  if (f.intensity.length && !f.intensity.includes(g.intensity ?? "soft")) return false;
  if (f.duration.length && !(g.duration_kind && f.duration.includes(g.duration_kind))) return false;
  if (f.format.length && !f.format.some((x) => (g.formats ?? []).includes(x))) return false;
  if (f.adult && !(g.adult_available || g.content_level === "intime")) return false;
  return true;
}

export interface MyFilters { my_max: Intensity; duo_cap: number; duo_adult: boolean; in_duo: boolean }

/** Plafond commun (le réglage le plus doux des deux membres), calculé côté serveur. */
export function useMyFilters(key: unknown) {
  const [data, setData] = useState<MyFilters | null>(null);
  useEffect(() => {
    let alive = true;
    void rpc<MyFilters>("get_my_filters", {}).then((res) => {
      if (alive && res.ok) setData(res as unknown as MyFilters);
    });
    return () => { alive = false; };
  }, [key]);
  return data;
}
