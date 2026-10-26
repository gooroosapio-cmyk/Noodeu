import { useCallback, useEffect, useState } from "react";
import { rpc, supabase } from "../lib/supabase";
interface Moment { question: string | null; games_played: number; server_now: string; expires_at: string }
/** No local draw: the two members use the same server-owned hourly slot. */
export function useHomeMoment(couple?: string) {
  const [revision, setRevision] = useState(0);
  const [state, setState] = useState<{ couple?: string; data: Moment | null; error: boolean; loading: boolean; played: number | null }>({ data: null, error: false, loading: true, played: null });
  const refresh = useCallback(() => setRevision((n) => n + 1), []);
  useEffect(() => {
    if (!couple) return;
    let alive = true;
    let request = 0;
    let timer: ReturnType<typeof setTimeout>;
    async function load() {
      const ticket = ++request;
      const result = await rpc<Moment>("get_home_moment", { p_couple: couple });
      if (!alive || ticket !== request) return;
      // Existing table API keeps the counter available before the hourly RPC is installed.
      // Explicit couple filter avoids mixing A–B and A–C despite both being readable by A.
      let played: number | null = result.ok ? result.games_played : null;
      if (!result.ok && !["not_found", "not_authenticated", "not_allowed"].includes(result.error)) {
        const games = new Set<string>();
        for (let offset = 0; ; offset += 1000) {
          const fallback = await supabase.from("game_sessions").select("game_id,id").eq("couple_id", couple)
            .in("status", ["ended", "closed"]).order("id").range(offset, offset + 999);
          if (!alive || ticket !== request) return;
          if (fallback.error) break;
          (fallback.data ?? []).forEach((row) => games.add(row.game_id));
          if ((fallback.data?.length ?? 0) < 1000) { played = games.size; break; }
        }
      }
      setState({ couple, data: result.ok ? result : null, played, error: !result.ok, loading: false });
      clearTimeout(timer);
      if (result.ok) {
        const remaining = Date.parse(result.expires_at) - Date.parse(result.server_now);
        timer = setTimeout(() => void load(), Number.isFinite(remaining) ? Math.max(1000, Math.min(3600000, remaining)) + 100 : 60000);
      }
    }
    function resume() { if (document.visibilityState === "visible") void load(); }
    void load();
    document.addEventListener("visibilitychange", resume);
    window.addEventListener("online", resume);
    return () => { alive = false; clearTimeout(timer); document.removeEventListener("visibilitychange", resume); window.removeEventListener("online", resume); };
  }, [couple, revision]);
  return { ...(state.couple === couple ? state : { data: null, loading: Boolean(couple), error: false, played: null }), refresh };
}
