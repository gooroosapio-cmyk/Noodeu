import { useCallback, useEffect, useState } from "react";
import { supabase } from "../lib/supabase";
import type { Category, Game } from "../lib/types";
import type { IllustrationName } from "../components/ui";

/** Illustration de vignette par mécanique (illustration de jeu, jamais une photo de participant). */
export const mechanicIllustration: Record<string, IllustrationName> = {
  portrait_words: "04-portrait-en-mots",
};

export function useCatalog(userId: string | null) {
  const [categories, setCategories] = useState<Category[]>([]);
  const [games, setGames] = useState<Game[]>([]);
  const [favorites, setFavorites] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  const load = useCallback(async () => {
    setError(false);
    const [c, g, f] = await Promise.all([
      supabase.from("game_categories").select("id, title, promise, sort, is_demo").eq("status", "published").order("sort"),
      supabase.from("games").select("id, category_id, mechanic, title, promise, style, duration_min, duration_max, content_level, current_version, sort, is_demo").eq("status", "published").order("sort"),
      userId ? supabase.from("game_favorites").select("game_id").eq("user_id", userId) : Promise.resolve({ data: [], error: null }),
    ]);
    if (c.error || g.error) setError(true);
    setCategories((c.data as Category[]) ?? []);
    setGames((g.data as Game[]) ?? []);
    setFavorites(new Set(((f.data as { game_id: string }[]) ?? []).map((x) => x.game_id)));
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

  return { categories, games, favorites, loading, error, reload: load, toggleFavorite };
}

// ---------- Filtres ----------

export type DurationBucket = "short" | "mid" | "long";
export interface Filters {
  family: string[];
  duration: DurationBucket[];
  level: ("standard" | "intime")[];
}
export const emptyFilters: Filters = { family: [], duration: [], level: [] };

/** Règle explicite : un jeu correspond si son intervalle de durée recoupe celui du filtre. */
export function matchesDuration(g: Pick<Game, "duration_min" | "duration_max">, b: DurationBucket) {
  if (b === "short") return g.duration_min < 5;
  if (b === "mid") return g.duration_min <= 15 && g.duration_max >= 5;
  return g.duration_max > 15;
}

/** OU entre les options d'un même groupe, ET entre les groupes ; groupe vide = aucune restriction. */
export function applyFilters(games: Game[], f: Filters) {
  return games.filter(
    (g) =>
      (!f.family.length || f.family.includes(g.category_id)) &&
      (!f.duration.length || f.duration.some((b) => matchesDuration(g, b))) &&
      (!f.level.length || f.level.includes(g.content_level)),
  );
}

export function countFilters(f: Filters) {
  return f.family.length + f.duration.length + f.level.length;
}

export function normalizeText(s: string) {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}
