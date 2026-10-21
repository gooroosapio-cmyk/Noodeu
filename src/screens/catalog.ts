import { useCallback, useEffect, useState } from "react";
import { supabase } from "../lib/supabase";
import type { Category, Game, GameStyle } from "../lib/types";
import type { IllustrationName } from "../components/ui";

/** Illustration de vignette par mécanique (illustration de jeu, jamais une photo de participant). */
export const mechanicIllustration: Record<string, IllustrationName> = {
  portrait_words: "04-portrait-en-mots",
};

export function useCatalog(userId: string | null) {
  const [categories, setCategories] = useState<Category[]>([]);
  const [games, setGames] = useState<Game[]>([]);
  const [favorites, setFavorites] = useState<Set<string>>(new Set());
  const [recent, setRecent] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  const load = useCallback(async () => {
    setError(false);
    const [c, g, f, r] = await Promise.all([
      supabase.from("game_categories").select("id, title, promise, sort, is_demo, family_no").eq("status", "published").order("sort"),
      supabase.from("games").select("id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max, content_level, current_version, sort, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail").eq("status", "published").order("sort"),
      userId ? supabase.from("game_favorites").select("game_id").eq("user_id", userId) : Promise.resolve({ data: [], error: null }),
      // Parties du duo (lisibles par ses seuls membres) : activités récemment jouées.
      supabase.from("game_sessions").select("game_id, created_at").order("created_at", { ascending: false }).limit(40),
    ]);
    if (c.error || g.error) setError(true);
    setCategories((c.data as Category[]) ?? []);
    setGames((g.data as Game[]) ?? []);
    setFavorites(new Set(((f.data as { game_id: string }[]) ?? []).map((x) => x.game_id)));
    setRecent([...new Set(((r.data as { game_id: string }[]) ?? []).map((x) => x.game_id))]);
    setLoading(false);
  }, [userId]);

  useEffect(() => {
    void load();
  }, [load]);

  /** Favoris personnels : jamais visibles par l'autre membre du duo. Renvoie false en cas d'échec. */
  const toggleFavorite = useCallback(
    async (gameId: string) => {
      if (!userId) return false;
      const isFav = favorites.has(gameId);
      setFavorites((prev) => {
        const next = new Set(prev);
        if (isFav) next.delete(gameId);
        else next.add(gameId);
        return next;
      });
      const { error: e } = isFav
        ? await supabase.from("game_favorites").delete().eq("user_id", userId).eq("game_id", gameId)
        : await supabase.from("game_favorites").upsert({ user_id: userId, game_id: gameId }, { onConflict: "user_id,game_id", ignoreDuplicates: true });
      if (e) {
        void load(); // retour à l'état réel
        return false;
      }
      return true;
    },
    [favorites, userId, load],
  );

  return { categories, games, favorites, recent, loading, error, reload: load, toggleFavorite };
}

// ---------- Filtres ----------

/** Puces visibles : « Ensemble » réunit échange, création et coopération. */
export type Quick = "all" | "together" | "duel";
export type Show = "all" | "favorites" | "recent";
export interface Filters {
  family: string[];
  mode: GameStyle[];
  difficulty: string[];
  mute: boolean;
  adult: boolean;
}
export const emptyFilters: Filters = { family: [], mode: [], difficulty: [], mute: false, adult: false };

export function matchesQuick(g: Game, q: Quick) {
  return q === "all" || (q === "duel" ? g.style === "duel" : g.style !== "duel");
}

/** OU entre les options d'un même groupe, ET entre les groupes ; groupe vide = aucune restriction. */
export function applyFilters(games: Game[], f: Filters) {
  return games.filter(
    (g) =>
      (!f.family.length || f.family.includes(g.category_id)) &&
      (!f.mode.length || f.mode.includes(g.style)) &&
      (!f.difficulty.length || g.difficulties.some((d) => f.difficulty.includes(d))) &&
      (!f.mute || g.mute_ok) &&
      (!f.adult || g.adult_available),
  );
}

export function countFilters(f: Filters) {
  return f.family.length + f.mode.length + f.difficulty.length + (f.mute ? 1 : 0) + (f.adult ? 1 : 0);
}

/** Une option n'est proposée que si elle change effectivement les résultats. */
export function changesResults(games: Game[], test: (g: Game) => boolean) {
  const n = games.filter(test).length;
  return n > 0 && n < games.length;
}

export function normalizeText(s: string) {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}
