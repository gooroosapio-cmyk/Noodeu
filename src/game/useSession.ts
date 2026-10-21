import { useCallback, useEffect, useRef, useState } from "react";
import { rpc, supabase } from "../lib/supabase";
import { subscribePrivate, type ChannelStatus } from "../lib/realtime";
import { onResume } from "../lib/useOnline";
import type { ChatMessage, SessionState } from "../lib/types";

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
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [unread, setUnread] = useState(0);
  const versionRef = useRef(0);
  const salonOpenRef = useRef(false);

  const load = useCallback(async () => {
    const res = await rpc<SessionState>("get_session_state", { p_session: sessionId });
    setLoading(false);
    if (!res.ok) {
      if (res.error !== "network") setError(res.error);
      return;
    }
    const next = res as unknown as SessionState;
    // On n'applique jamais un état plus ancien que celui déjà affiché.
    if (next.session.state_version >= versionRef.current) {
      versionRef.current = next.session.state_version;
      setState(next);
      setError(null);
    }
  }, [sessionId]);

  const loadMessages = useCallback(async () => {
    const { data, error: e } = await supabase
      .from("session_messages")
      .select("id, user_id, client_id, body, created_at")
      .eq("session_id", sessionId)
      .order("created_at", { ascending: true })
      .limit(200);
    if (e || !data) return;
    setMessages((prev) => mergeMessages(prev.filter((m) => m.pending || m.failed), data as ChatMessage[]));
  }, [sessionId]);

  useEffect(() => {
    versionRef.current = 0;
    setLoading(true);
    void load();
    void loadMessages();
    return onResume(() => {
      void load();
      void loadMessages();
    });
  }, [load, loadMessages]);

  useEffect(() => {
    if (!userId) return;
    return subscribePrivate(`session:${sessionId}`, {
      presenceKey: userId,
      onPresence: setPresent,
      onStatus: (s) => {
        setChannel(s);
        if (s === "live") {
          void load(); // rattrape ce qui a pu se passer pendant la coupure
          void loadMessages();
        }
      },
      broadcast: {
        state: (p) => {
          if (typeof p.v !== "number" || p.v > versionRef.current) void load();
        },
        chat: (p) => {
          const m = p as unknown as ChatMessage;
          setMessages((prev) => mergeMessages(prev, [m]));
          if (m.user_id !== userId && !salonOpenRef.current) setUnread((n) => n + 1);
        },
      },
    });
  }, [sessionId, userId, load, loadMessages]);

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

  const sendMessage = useCallback(
    async (body: string, clientId: string = crypto.randomUUID()) => {
      const optimistic: ChatMessage = { id: `local-${clientId}`, user_id: userId, client_id: clientId, body, created_at: new Date().toISOString(), pending: true };
      setMessages((prev) => mergeMessages(prev.filter((m) => m.client_id !== clientId), [optimistic]));
      const res = await rpc<{ id: string }>("send_session_message", { p_session: sessionId, p_client_id: clientId, p_body: body });
      if (res.ok) {
        setMessages((prev) => prev.map((m) => (m.client_id === clientId ? { ...m, id: res.id, pending: false, failed: false } : m)));
      } else {
        setMessages((prev) => prev.map((m) => (m.client_id === clientId ? { ...m, pending: false, failed: true } : m)));
      }
      return res;
    },
    [sessionId, userId],
  );

  const setSalonOpen = useCallback(
    (open: boolean) => {
      salonOpenRef.current = open;
      if (open) {
        setUnread(0);
        void loadMessages();
      }
    },
    [loadMessages],
  );

  return { state, error, loading, channel, present, messages, unread, load, act, sendMessage, setSalonOpen };
}

function mergeMessages(prev: ChatMessage[], incoming: ChatMessage[]): ChatMessage[] {
  const byClient = new Map(prev.map((m) => [m.client_id, m]));
  for (const m of incoming) {
    const existing = byClient.get(m.client_id);
    byClient.set(m.client_id, existing ? { ...existing, ...m, pending: false, failed: false } : m);
  }
  return [...byClient.values()].sort((a, b) => a.created_at.localeCompare(b.created_at));
}

/** Brouillon local d'une étape (survit au rafraîchissement, effacé à la fermeture de l'onglet). */
export function useDraft(key: string) {
  const storageKey = `noodeu.draft.${key}`;
  const [value, setValue] = useState<string[]>(() => {
    try {
      return JSON.parse(sessionStorage.getItem(storageKey) ?? "[]") as string[];
    } catch {
      return [];
    }
  });
  useEffect(() => {
    try {
      setValue(JSON.parse(sessionStorage.getItem(storageKey) ?? "[]") as string[]);
    } catch {
      setValue([]);
    }
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
