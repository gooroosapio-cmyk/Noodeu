import { useCallback, useEffect, useState } from "react";
import { rpc } from "../lib/supabase";
interface Moment { question: string | null; games_played: number; server_now: string; expires_at: string }
/** No local draw: the two members use the same server-owned hourly slot. */
export function useHomeMoment(couple?: string) {
  const [revision, setRevision] = useState(0);
  const [state, setState] = useState<{ couple?: string; data: Moment | null; error: boolean; loading: boolean }>({ data: null, error: false, loading: true });
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
      setState({ couple, data: result.ok ? result : null, error: !result.ok, loading: false });
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
  return { ...(state.couple === couple ? state : { data: null, loading: Boolean(couple), error: false }), refresh };
}
