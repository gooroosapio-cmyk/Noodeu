import { useCallback, useEffect, useRef, useState } from "react";
import { rpc } from "../lib/supabase";
import { subscribePrivate, type ChannelStatus } from "../lib/realtime";
import { onResume } from "../lib/useOnline";
import type { SessionState } from "../lib/types";

const POLL_LIVE_MS = 20000; // filet de sécurité même quand le temps réel fonctionne
const POLL_DOWN_MIN_MS = 4000; // temps réel indisponible : relecture, puis espacement progressif
const POLL_DOWN_MAX_MS = 30000;
/** Délai borné avec jitter (±20 %) : pas de relecture rapide permanente pendant une coupure. */
const downDelay = (attempt: number) => {
  const base = Math.min(POLL_DOWN_MAX_MS, POLL_DOWN_MIN_MS * 2 ** attempt);
  return Math.round(base * (0.8 + Math.random() * 0.4));
};

interface ReadBatch {
  promise: Promise<void>;
  resolve: () => void;
  reject: (reason: unknown) => void;
}

function createReadBatch(): ReadBatch {
  let resolve!: () => void;
  let reject!: (reason: unknown) => void;
  const promise = new Promise<void>((done, fail) => { resolve = done; reject = fail; });
  return { promise, resolve, reject };
}

interface SessionContext {
  key: string;
  sessionId: string;
  version: number;
  recoveryPending: boolean;
  recoveryGeneration: number;
  channel: ChannelStatus;
  inFlight: ReadBatch | null;
  queued: ReadBatch | null;
}

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
  // Une rupture de transport ne doit pas transformer le prochain snapshot en événement animé.
  // L'époque est publiée avec ce snapshot, pas au début de la panne : après ce rattrapage,
  // les relectures régulières restent des mises à jour normales, même sans WebSocket.
  const [recoveryEpoch, setRecoveryEpoch] = useState(0);
  const contextKey = `${sessionId}:${userId ?? ""}`;
  const latestKey = useRef(contextKey);
  latestKey.current = contextKey;
  const activeContext = useRef<SessionContext | null>(null);
  const isCurrent = useCallback((context: SessionContext) => (
    activeContext.current === context && latestKey.current === context.key
  ), []);

  const loadOnce = useCallback(async (context: SessionContext) => {
    const requestedGeneration = context.recoveryGeneration;
    const res = await rpc<SessionState>("get_session_state", { p_session: context.sessionId });
    if (!isCurrent(context)) return;
    setLoading(false);
    if (!res.ok) {
      context.recoveryPending = true;
      context.recoveryGeneration += 1;
      setError(res.error);
      return;
    }
    // Une réponse lancée avant la rupture ne prouve pas que le transport a repris.
    if (context.recoveryPending && requestedGeneration !== context.recoveryGeneration) return;
    const next = res as unknown as SessionState;
    // On n'applique jamais un état plus ancien que celui déjà affiché.
    if (next.session.state_version >= context.version) {
      context.version = next.session.state_version;
      if (context.recoveryPending) {
        context.recoveryPending = false;
        setRecoveryEpoch((epoch) => epoch + 1);
      }
      setState(next);
      setError(null);
    }
  }, [isCurrent]);
  const load = useCallback((): Promise<void> => {
    const context = activeContext.current;
    if (!context || context.key !== contextKey || !isCurrent(context)) return Promise.resolve();
    // Chaque contexte possède sa file. Une ancienne partie ne peut pas absorber les demandes de la suivante.
    if (context.inFlight) {
      // Les appels pendant une lecture attendent une seule lecture suivante, pas toutes les futures.
      context.queued ??= createReadBatch();
      return context.queued.promise;
    }
    const start = (batch: ReadBatch) => {
      context.inFlight = batch;
      const complete = () => {
        const next = context.queued;
        context.queued = null;
        context.inFlight = null;
        // Transférer la file avant de réveiller les appelants : leurs nouveaux appels ne peuvent
        // ni doubler cette lecture, ni prolonger la promesse du lot qui vient de terminer.
        if (next) {
          if (isCurrent(context)) start(next);
          else next.resolve();
        }
      };
      void loadOnce(context).then(() => {
        complete();
        batch.resolve();
      }, (reason: unknown) => {
        complete();
        batch.reject(reason);
      });
    };
    const batch = createReadBatch();
    start(batch);
    return batch.promise;
  }, [contextKey, isCurrent, loadOnce]);

  useEffect(() => {
    const context: SessionContext = {
      key: contextKey, sessionId, version: 0, recoveryPending: false,
      recoveryGeneration: 0, channel: "connecting", inFlight: null, queued: null,
    };
    activeContext.current = context;
    setRecoveryEpoch(0);
    setLoading(true);
    setChannel("connecting");
    setState(null); setError(null); setPresent([]);
    void load();
    const stopResume = onResume(() => { if (isCurrent(context)) void load(); });
    return () => {
      if (activeContext.current === context) activeContext.current = null;
      // Les appelants quittant ce contexte n'attendent pas une ancienne requête réseau bloquée.
      context.queued?.resolve();
      context.inFlight?.resolve();
      context.queued = null;
      context.inFlight = null;
      stopResume();
    };
  }, [contextKey, sessionId, isCurrent, load]);

  useEffect(() => {
    const context = activeContext.current;
    if (!userId || !context) return;
    return subscribePrivate(`session:${sessionId}`, {
      presenceKey: userId,
      onPresence: (keys) => { if (isCurrent(context)) setPresent(keys); },
      onStatus: (s) => {
        if (!isCurrent(context)) return;
        if ((context.channel === "live" && s === "down") || (context.channel === "down" && s === "live")) {
          context.recoveryPending = true;
          context.recoveryGeneration += 1;
        }
        context.channel = s;
        setChannel(s);
        if (s === "live") void load(); // rattrape ce qui a pu se passer pendant la coupure
      },
      broadcast: {
        state: (p) => {
          if (isCurrent(context) && (typeof p.v !== "number" || p.v > context.version)) void load();
        },
      },
    });
  }, [sessionId, userId, isCurrent, load]);

  useEffect(() => {
    const context = activeContext.current;
    if (!context) return;
    let timer: ReturnType<typeof setTimeout>;
    let stopped = false;
    let attempt = 0;
    const tick = () => {
      timer = setTimeout(() => {
        if (stopped || !isCurrent(context)) return;
        if (document.visibilityState === "visible") void load();
        attempt += 1;
        tick();
      }, channel === "live" ? POLL_LIVE_MS : downDelay(attempt));
    };
    tick();
    return () => { stopped = true; clearTimeout(timer); };
  }, [channel, isCurrent, load]);

  /** Action serveur : relit l'état ensuite, quel que soit le résultat. */
  const act = useCallback(
    async (fn: string, args: Record<string, unknown>) => {
      const context = activeContext.current;
      if (!context || context.key !== contextKey || !isCurrent(context)) return { ok: false as const, error: "stale_session" };
      const res = await rpc(fn, { p_session: sessionId, ...args });
      if (!isCurrent(context)) return res;
      if (!res.ok && res.error === "network") {
        context.recoveryPending = true;
        context.recoveryGeneration += 1;
      }
      await load();
      return res;
    },
    [sessionId, contextKey, isCurrent, load],
  );

  const current = activeContext.current?.key === contextKey;
  const currentState = current && state?.session.id === sessionId ? state : null;
  return { state: currentState, error: current ? error : null, loading: !current || loading, channel: current ? channel : "connecting", present: current ? present : [], recoveryEpoch: current ? recoveryEpoch : 0, load, act };
}

/** Brouillon local d'une étape (survit au rafraîchissement, effacé à la fermeture de l'onglet). */
/** Oublie un brouillon d'onglet sans le monter (manche terminée, passée ou interrompue). */
export function forgetDraft(key: string) {
  try {
    sessionStorage.removeItem(`noodeu.draft.${key}`);
  } catch {
    /* rien */
  }
}

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
