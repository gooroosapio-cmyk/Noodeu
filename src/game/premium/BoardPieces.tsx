import { createContext, useContext, useEffect, useLayoutEffect, useRef, useState, type CSSProperties, type ImgHTMLAttributes } from "react";
import "../../styles/astra-boards.css";
import { RED_PIECES } from "../red/kit";

const PIECES = "/assets/original/boards3d";
export const SessionRecoveryContext = createContext(0);
const liveFrames = new Map<string, { revision: number; recoveryEpoch: number }>();

/** Passage du plateau au résultat dans le même rendu ; un écran remonté reçoit directement l'état final. */
export function useLiveBoardFrame(key: string, revision: number) {
  const recoveryEpoch = useContext(SessionRecoveryContext);
  useLayoutEffect(() => {
    const frame = { revision, recoveryEpoch };
    liveFrames.set(key, frame);
    const forget = () => liveFrames.delete(key);
    window.addEventListener("offline", forget);
    document.addEventListener("visibilitychange", forget);
    return () => {
      window.removeEventListener("offline", forget);
      document.removeEventListener("visibilitychange", forget);
      // La vue résultat peut consommer la transition lors de ce commit, avant cette microtâche.
      queueMicrotask(() => { if (liveFrames.get(key) === frame) liveFrames.delete(key); });
    };
  }, [key, revision, recoveryEpoch]);
}

export function useBoardReveal(key: string, revision: number, eligible: boolean) {
  const recoveryEpoch = useContext(SessionRecoveryContext);
  const [animate, setAnimate] = useState(false);
  useLayoutEffect(() => {
    const before = liveFrames.get(key);
    liveFrames.delete(key);
    if (!eligible || !before || before.recoveryEpoch !== recoveryEpoch || revision !== before.revision + 1 || !navigator.onLine || document.visibilityState !== "visible") return;
    setAnimate(true);
    const timer = window.setTimeout(() => setAnimate(false), 720);
    return () => window.clearTimeout(timer);
  }, [key, revision, eligible, recoveryEpoch]);
  return animate;
}

/** L'échéance reste serveur. Une panne ne consomme pas définitivement la demande d'expiration. */
export function useServerExpiry(deadline: string | undefined, expired: boolean, send: () => Promise<{ ok: boolean; error?: string }>) {
  const sendRef = useRef(send);
  const lastAttempt = useRef(0);
  const retryRef = useRef<() => void>(() => {});
  const [exhausted, setExhausted] = useState(false);
  sendRef.current = send;
  useEffect(() => {
    setExhausted(false);
    if (!deadline || !expired) return;
    let active = true, inFlight = false, settled = false, retries = 0;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const delays = [1500, 3000, 6000, 12000, 20000];
    async function attempt() {
      if (!active || settled || inFlight || !navigator.onLine || document.visibilityState !== "visible") return;
      clearTimeout(timer);
      const wait = Math.max(0, 1000 - (Date.now() - lastAttempt.current));
      if (wait) { timer = setTimeout(() => void attempt(), wait); return; }
      inFlight = true;
      lastAttempt.current = Date.now();
      let result: { ok: boolean; error?: string };
      try { result = await sendRef.current(); }
      catch { result = { ok: false, error: "network" }; }
      inFlight = false;
      if (!active) return;
      if (result.ok) { settled = true; return; }
      if (["network", "busy", "too_early"].includes(result.error ?? "") && retries < delays.length) {
        timer = setTimeout(() => void attempt(), delays[retries++]);
      } else setExhausted(true);
    }
    const resume = () => { if (!settled) { retries = 0; setExhausted(false); void attempt(); } };
    retryRef.current = resume;
    window.addEventListener("online", resume);
    window.addEventListener("focus", resume);
    document.addEventListener("visibilitychange", resume);
    // Le premier départ reste annulable, y compris lors du cycle de vérification StrictMode.
    timer = setTimeout(() => void attempt(), 0);
    return () => {
      active = false;
      retryRef.current = () => {};
      clearTimeout(timer);
      window.removeEventListener("online", resume);
      window.removeEventListener("focus", resume);
      document.removeEventListener("visibilitychange", resume);
    };
  }, [deadline, expired]);
  return { exhausted, retry: () => retryRef.current() };
}

export function ExpiryRetry({ expiry }: { expiry: ReturnType<typeof useServerExpiry> }) {
  if (!expiry.exhausted) return null;
  return <div className="astra-expiry-retry stack stack--2" role="status">
    <p className="t-small">La fin de la manche n’a pas encore été confirmée. Tu peux réessayer.</p>
    <button type="button" className="btn btn--secondary" onClick={expiry.retry}>Réessayer la confirmation</button>
  </div>;
}

/** Les bitmaps sont décoratifs ; la valeur accessible vient toujours de l'état reçu.
 *  Pièce du kit rouge d'abord (faces exactes du dé, pions), puis l'ancienne image, puis le SVG de secours. */
export function BoardPiece({ piece, fallback, ...props }: ImgHTMLAttributes<HTMLImageElement> & { piece: string; fallback: string }) {
  const chain = [RED_PIECES[piece], `${PIECES}/${piece}.webp`, fallback].filter(Boolean) as string[];
  return <img {...props} src={chain[0]} onError={event => {
    const img = event.currentTarget;
    const next = chain.findIndex(src => img.src.endsWith(src)) + 1;
    if (next > 0 && next < chain.length) img.src = chain[next];
  }} />;
}

/** Une animation pour un nouvel événement, jamais pour le snapshot initial ou un rattrapage. */
export function useConfirmedEvent(revision: number, eligible: boolean, online = true) {
  const recoveryEpoch = useContext(SessionRecoveryContext);
  const previous = useRef({ revision, online, recoveryEpoch });
  const networkGap = useRef(false);
  const [pulse, setPulse] = useState<number | null>(null);
  useEffect(() => {
    const gap = () => { networkGap.current = true; };
    window.addEventListener("offline", gap);
    document.addEventListener("visibilitychange", gap);
    return () => {
      window.removeEventListener("offline", gap);
      document.removeEventListener("visibilitychange", gap);
    };
  }, []);
  useEffect(() => {
    const before = previous.current;
    previous.current = { revision, online, recoveryEpoch };
    if (before.revision === revision && before.online === online && before.recoveryEpoch === recoveryEpoch) return;
    const fresh = eligible && online && before.online && navigator.onLine && !networkGap.current
      && before.recoveryEpoch === recoveryEpoch && document.visibilityState === "visible" && revision === before.revision + 1;
    networkGap.current = false;
    setPulse(fresh ? revision : null);
    if (!fresh) return;
    const timer = window.setTimeout(() => setPulse(null), 720);
    return () => window.clearTimeout(timer);
    // L'éligibilité décrit cette révision ; elle ne constitue pas un nouvel événement.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [revision, online, recoveryEpoch]);
  return pulse;
}

export function HangmanFlower({ errors, revision, online, label }: { errors: number; revision: number; online: boolean; label: string }) {
  const count = Math.max(0, Math.min(6, errors));
  const previousErrors = useRef(count);
  const falling = useConfirmedEvent(revision, count === previousErrors.current + 1, online);
  useEffect(() => { previousErrors.current = count; }, [count]);
  return <div className="astra-flower" role="img" aria-label={label}>
    <BoardPiece className="astra-flower__base" piece="flower-base" fallback="/assets/premium/M09/flower-6.svg" alt="" />
    {Array.from({ length: 6 }, (_, index) => {
      const dropping = falling !== null && index === count - 1;
      if (index < count && !dropping) return null;
      return <span key={`${index}:${dropping ? falling : "rest"}`}
        className={`astra-flower__petal-position${dropping ? " is-falling" : ""}`}
        style={{ "--petal-angle": `${index * 60}deg` } as CSSProperties}>
        <BoardPiece className="astra-flower__petal" piece="flower-petal" fallback="/assets/premium/M09/petal.svg" alt="" />
      </span>;
    })}
  </div>;
}
