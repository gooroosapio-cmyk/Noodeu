import { useCallback, useEffect, useState } from "react";
import { supabase } from "../lib/supabase";
import type { Category, Game } from "../lib/types";

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
      supabase.from("games").select("id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max, content_level, current_version, sort, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, meta").eq("status", "published").order("sort"),
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

// ---------- Rayons de la bibliothèque ----------

/** Rayons affichés : deux grandes entrées (questions, tests), deux sections en grille, et l'espace « À huis clos ». */
export type Shelf = "questions" | "tests" | "conversation" | "minijeux" | "huisclos";
export const SHELVES: Shelf[] = ["questions", "tests", "conversation", "minijeux", "huisclos"];

const SHELF_BY_CATEGORY: Record<string, Shelf> = {
  "nd-se-decouvrir": "questions",
  "nd-mieux-se-comprendre": "tests",
  "nd-conversation-decouverte": "conversation",
  "nd-mini-jeux-interactifs": "minijeux",
};
export const CATEGORY_BY_SHELF: Partial<Record<Shelf, string>> = Object.fromEntries(
  Object.entries(SHELF_BY_CATEGORY).map(([c, s]) => [s, c]),
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
