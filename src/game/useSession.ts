import { useCallback, useEffect, useRef, useState } from "react";
import { rpc } from "../lib/supabase";
import { subscribePrivate, type ChannelStatus } from "../lib/realtime";
import { onResume } from "../lib/useOnline";
import type { SessionState } from "../lib/types";

const POLL_LIVE_MS = 20000; // filet de sécurité même quand le temps réel fonctionne
const POLL_DOWN_MS = 4000; // temps réel indisponible : relecture fréquente

/**
 * État d'une partie, toujours relu depuis la base (seule source de vérité).
 * Le temps réel ne fait que signaler qu'une relecture est utile.
 */
export function useSession(sessionId: string, userId: string | null) {
  const [state, setState] = useState<SessionState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [channel, setChannel] = useState<ChannelStatus>("connecting");
  const [present, setPresent] = useState<string[]>([]);
  const versionRef = useRef(0);
  const contextKey = `${sessionId}:${userId ?? ""}`;
  const contextRef = useRef(contextKey);
  contextRef.current = contextKey;

  const load = useCallback(async () => {
    const requestedContext = `${sessionId}:${userId ?? ""}`;
    const res = await rpc<SessionState>("get_session_state", { p_session: sessionId });
    if (contextRef.current !== requestedContext) return;
    setLoading(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    const next = res as unknown as SessionState;
    // On n'applique jamais un état plus ancien que celui déjà affiché.
    if (next.session.state_version >= versionRef.current) {
      versionRef.current = next.session.state_version;
      setState(next);
      setError(null);
    }
  }, [sessionId, userId]);

  useEffect(() => {
    versionRef.current = 0;
    setLoading(true);
    setState(null); setError(null); setPresent([]);
    void load();
    return onResume(() => void load());
  }, [load]);

  useEffect(() => {
    if (!userId) return;
    return subscribePrivate(`session:${sessionId}`, {
      presenceKey: userId,
      onPresence: setPresent,
      onStatus: (s) => {
        setChannel(s);
        if (s === "live") void load(); // rattrape ce qui a pu se passer pendant la coupure
      },
      broadcast: {
        state: (p) => {
          if (typeof p.v !== "number" || p.v > versionRef.current) void load();
        },
      },
    });
  }, [sessionId, userId, load]);

  useEffect(() => {
    const id = setInterval(() => {
      if (document.visibilityState === "visible") void load();
    }, channel === "live" ? POLL_LIVE_MS : POLL_DOWN_MS);
    return () => clearInterval(id);
  }, [channel, load]);

  /** Action serveur : relit l'état ensuite, quel que soit le résultat. */
  const act = useCallback(
    async (fn: string, args: Record<string, unknown>) => {
      const res = await rpc(fn, { p_session: sessionId, ...args });
      await load();
      return res;
    },
    [sessionId, load],
  );

  const currentState = state?.session.id === sessionId ? state : null;
  return { state: currentState, error, loading: loading || (state !== null && currentState === null), channel, present, load, act };
}

/** Brouillon local d'une étape (survit au rafraîchissement, effacé à la fermeture de l'onglet). */
export function useDraft(key: string) {
  const storageKey = `noodeu.draft.${key}`;
  const read = () => {
    try {
      return JSON.parse(sessionStorage.getItem(storageKey) ?? "[]") as string[];
    } catch {
      return [];
    }
  };
  const [value, setValue] = useState<string[]>(read);
  useEffect(() => {
    setValue(read());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [storageKey]);
  const update = useCallback(
    (next: string[]) => {
      setValue(next);
      try {
        sessionStorage.setItem(storageKey, JSON.stringify(next));
      } catch {
        /* stockage indisponible : le brouillon reste en mémoire */
      }
    },
    [storageKey],
  );
  const clear = useCallback(() => {
    try {
      sessionStorage.removeItem(storageKey);
    } catch {
      /* rien */
    }
  }, [storageKey]);
  return [value, update, clear] as const;
}
