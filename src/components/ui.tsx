import { createContext, useCallback, useContext, useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { t } from "../i18n";
import { useOnline } from "../lib/useOnline";

const BASE = "/assets/noodeu";

export type IconName =
  | "home" | "library" | "bulb" | "heart" | "settings" | "arrow-left" | "arrow-right" | "chevron-down" | "chevron-up"
  | "close" | "check" | "plus" | "minus" | "search" | "filter" | "bookmark" | "star" | "share" | "send" | "copy"
  | "link" | "users" | "user" | "chat" | "pause" | "play" | "stop" | "skip" | "mic" | "image" | "volume" | "clock"
  | "lock" | "eye" | "eye-off" | "bell" | "wifi" | "refresh" | "logout" | "info" | "help" | "pencil" | "undo"
  | "eraser" | "smile" | "puzzle" | "cards" | "lightning" | "leaf" | "sparkles" | "delete" | "quote"
  | "gamepad" | "chevron-right" | "bookmark-filled" | "trophy" | "timer" | "source" | "gift" | "moon" | "sun" | "text"
  | "lock-keyhole" | "unlock-keyhole" | "thumbs-up" | "thumbs-down" | "dices" | "ship" | "scissors" | "hand" | "calendar-days"
  | "ellipsis" | "swap" | "back" | "shield-check" | "triangle-alert" | "wifi-off" | "circle-check" | "book-open";

/** Illustrations de l'interface v2 (cellules découpées des atlas du kit, PNG transparents convertis en WebP). */
export type ArtName = string;
export function Art({ name, size = 72, className = "", alt = "" }: { name: ArtName; size?: number; className?: string; alt?: string }) {
  return <img className={`art ${className}`} src={name.startsWith("custom-") ? (name === "custom-G06" ? "/assets/original/library/G06.svg" : `/assets/original/library3d/${name.slice(7)}.webp`) : `/assets/v2/art/${name}.webp`} width={size} height={size} alt={alt} loading="lazy" decoding="async" />;
}

/** Icône du kit (masque CSS : hérite de la couleur du texte). Décorative sauf si `label` est fourni. */
export function Icon({ name, size = 22, label }: { name: IconName; size?: number; label?: string }) {
  const style = { width: size, height: size, "--icon": `url("/assets/v2/icones/icon-${name}.svg")` } as CSSProperties;
  return <span className="icon" style={style} role={label ? "img" : undefined} aria-label={label} aria-hidden={label ? undefined : true} />;
}

export function Logo({ width = 104, variant = "couleur" }: { width?: number; variant?: "couleur" | "prune" | "blanc" }) {
  return <img className="logo" src={`${BASE}/01_Logos/noodeu-logo-${variant}.svg`} width={width} height={Math.round((width * 190) / 830)} alt="Noodeu" />;
}

export type IllustrationName =
  | "01-connexion-a-deux" | "02-invitation" | "03-duo-confirme" | "04-portrait-en-mots" | "05-conversation"
  | "06-quiz-devinette" | "07-dessin-creatif" | "08-cooperation" | "09-attente-douce" | "10-revelation"
  | "11-fin-de-partie" | "12-astuce" | "13-favoris" | "14-duo-a-creer" | "15-invitation-expiree" | "16-reconnexion"
  | "17-pause" | "18-rire-ensemble";

/** Illustration du kit (décorative par défaut). WebP léger avec repli sur le PNG source. */
export function Illustration({ name, alt = "", className = "", eager = false }: { name: IllustrationName; alt?: string; className?: string; eager?: boolean }) {
  return (
    <picture>
      <source srcSet={`${BASE}/02_Illustrations_WEBP/noodeu-${name}.webp`} type="image/webp" />
      <img className={`illustration ${className}`} src={`${BASE}/02_Illustrations_PNG/noodeu-${name}.png`} width={1448} height={1086}
        alt={alt} loading={eager ? "eager" : "lazy"} decoding="async" />
    </picture>
  );
}

export function Loading({ label = t("common.loading") }: { label?: string }) {
  return (
    <span className="loading" role="status">
      <span className="loading__dots" aria-hidden="true"><i /><i /><i /></span>
      <span>{label}</span>
    </span>
  );
}

export function PageLoading() {
  const [delayed,setDelayed]=useState(false);
  useEffect(()=>{const timer=setTimeout(()=>setDelayed(true),1200);return()=>clearTimeout(timer);},[]);
  return <div className="page-loading" aria-busy="true" aria-label="Chargement">
    <div className="page-loading__logo"><Logo width={160} /></div>
    <p className="t-small" role="status">{delayed ? "Un instant…" : ""}</p>
  </div>;
}

export function EmptyState({ illustration, title, text, children }: { illustration?: IllustrationName; title: string; text?: string; children?: ReactNode }) {
  return (
    <section className="empty">
      {illustration && <Illustration name={illustration} />}
      <h2 className="t-section">{title}</h2>
      {text && <p>{text}</p>}
      {children}
    </section>
  );
}

export function Alert({ kind = "error", children }: { kind?: "error" | "info" | "success"; children: ReactNode }) {
  return <div className={`alert alert--${kind}`} role={kind === "error" ? "alert" : "status"}>{children}</div>;
}

export function DemoTag() {
  return <span className="tag tag--demo" title={t("common.demoHint")}>{t("common.demo")}</span>;
}

export function NetworkBanner() {
  const online = useOnline();
  const [showBack, setShowBack] = useState(false);
  const wasOffline = useRef(false);
  useEffect(() => {
    if (!online) wasOffline.current = true;
    else if (wasOffline.current) {
      wasOffline.current = false;
      setShowBack(true);
      const id = setTimeout(() => setShowBack(false), 2500);
      return () => clearTimeout(id);
    }
  }, [online]);
  if (online && !showBack) return null;
  return <div className="net-banner" role="status">{online ? t("net.back") : t("net.offline")}</div>;
}

// Registre des fenêtres ouvertes : une seule entrée d'historique pour toute la pile,
// afin que le bouton « retour » du téléphone ferme d'abord la fenêtre du dessus.
const sheetStack: (() => void)[] = [];
let historyPushed = false;
let historyBackPending = false;
function ensureSheetHistory() {
  if (historyPushed || historyBackPending || !sheetStack.length) return;
  history.pushState({ noodeuSheet: true }, "");
  historyPushed = true;
}
if (typeof window !== "undefined") {
  window.addEventListener("popstate", () => {
    // Le retour demandé à la fermeture peut arriver après l'ouverture d'une autre feuille.
    // Il retire l'ancienne entrée ; il ne doit pas fermer la nouvelle fenêtre.
    if (historyBackPending) {
      historyBackPending = false;
      ensureSheetHistory();
      return;
    }
    if (!historyPushed || !sheetStack.length) return;
    historyPushed = false;
    sheetStack[sheetStack.length - 1]();
  });
}
function registerSheet(close: () => void) {
  sheetStack.push(close);
  ensureSheetHistory();
  return () => {
    const i = sheetStack.indexOf(close);
    if (i >= 0) sheetStack.splice(i, 1);
    // Différé : si une autre fenêtre s'ouvre aussitôt (remplacement), elle réutilise l'entrée.
    setTimeout(() => {
      if (historyBackPending) return;
      if (sheetStack.length) { ensureSheetHistory(); return; }
      if (!historyPushed) return;
      historyPushed = false;
      if (history.state?.noodeuSheet) { historyBackPending = true; history.back(); }
    }, 0);
  };
}

/**
 * Fenêtre (feuille basse sur mobile, panneau latéral possible sur grand écran).
 * Garde le focus à l'intérieur, se ferme avec Échap ou le bouton retour, rend le focus au déclencheur.
 */
export function Sheet({ title, onClose, children, footer, side = false, tall = false, centered = false, headerExtra, closeLabel = t("common.close"), closeIcon = "close", className = "" }: {
  title: ReactNode; onClose: () => void; children: ReactNode; footer?: ReactNode; side?: boolean; tall?: boolean; centered?: boolean;
  headerExtra?: ReactNode; closeLabel?: string; closeIcon?: IconName; className?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const titleId = useRef(`sheet-${Math.random().toString(36).slice(2)}`).current;
  const closeRef = useRef(onClose);
  closeRef.current = onClose;
  const topClose = useRef<(() => void) | null>(null);

  useEffect(() => {
    const opener = document.activeElement as HTMLElement | null;
    const first = ref.current?.querySelector<HTMLElement>("[data-autofocus]") ?? ref.current;
    first?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape" && sheetStack[sheetStack.length - 1] === topClose.current) closeRef.current();
      if (e.key !== "Tab" || !ref.current || sheetStack[sheetStack.length - 1] !== topClose.current) return;
      const items = [...ref.current.querySelectorAll<HTMLElement>("a[href], button:not([disabled]), input:not([disabled]), textarea:not([disabled]), select, [tabindex]:not([tabindex='-1'])")];
      if (!items.length) return;
      const [a, z] = [items[0], items[items.length - 1]];
      if (!ref.current.contains(document.activeElement) || document.activeElement === ref.current) { e.preventDefault(); (e.shiftKey ? z : a).focus(); }
      else if (e.shiftKey && document.activeElement === a) { e.preventDefault(); z.focus(); }
      else if (!e.shiftKey && document.activeElement === z) { e.preventDefault(); a.focus(); }
    };
    const close = () => closeRef.current();
    topClose.current = close;
    const unregister = registerSheet(close);
    document.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    document.body.classList.add("has-sheet");
    return () => {
      unregister();
      document.removeEventListener("keydown", onKey);
      if (!sheetStack.length) {
        document.body.style.overflow = "";
        document.body.classList.remove("has-sheet");
      }
      opener?.focus?.();
    };
  }, []);

  return (
    <div className={`sheet-backdrop ${side ? "sheet-backdrop--side" : ""} ${centered ? "sheet-backdrop--centered" : ""}`} onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className={`sheet ${tall ? "sheet--tall" : ""} ${className}`} role="dialog" aria-modal="true" aria-labelledby={titleId} tabIndex={-1} ref={ref}>
        <div className="sheet__head">
          <div className="sheet__title" id={titleId}>{title}</div>
          {headerExtra}
          <button className="icon-btn icon-btn--soft" onClick={onClose} aria-label={closeLabel}><Icon name={closeIcon} /></button>
        </div>
        <div className="sheet__body">{children}</div>
        {footer}
      </div>
    </div>
  );
}

/** Confirmation explicite d'une action importante. */
export function ConfirmDialog({ title, text, confirmLabel, danger = false, busy = false, disabled = false, onConfirm, onCancel, children }: {
  title: string; text: ReactNode; confirmLabel: string; danger?: boolean; busy?: boolean; disabled?: boolean; onConfirm: () => void; onCancel: () => void; children?: ReactNode;
}) {
  return (
    <Sheet
      title={<h2 className="t-section">{title}</h2>}
      onClose={() => { if (!busy) onCancel(); }}
      footer={
        <div className="sheet__foot">
          <button className="btn btn--secondary btn--auto" disabled={busy} onClick={onCancel} data-autofocus>{t("common.cancel")}</button>
          <button className={`btn ${danger ? "btn--danger-solid" : ""}`} disabled={busy || disabled} onClick={onConfirm}>{busy ? t("common.sending") : confirmLabel}</button>
        </div>
      }
    >
      <div className="t-body">{text}</div>
      {children}
    </Sheet>
  );
}

const ToastContext = createContext<(message: string) => void>(() => undefined);

/** Messages brefs confirmant une action réellement aboutie. */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<{ id: number; message: string }[]>([]);
  const show = useCallback((message: string) => {
    const id = Date.now() + Math.random();
    setItems((prev) => [...prev, { id, message }]);
    setTimeout(() => setItems((prev) => prev.filter((i) => i.id !== id)), 3200);
  }, []);
  return (
    <ToastContext.Provider value={show}>
      {children}
      <div className="toast-region" role="status" aria-live="polite">
        {items.map((i) => <div key={i.id} className="toast">{i.message}</div>)}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  return useContext(ToastContext);
}

export function formatDate(iso: string, withTime = false) {
  const d = new Date(iso);
  return d.toLocaleDateString("fr-FR", withTime ? { day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" } : { day: "numeric", month: "long", year: "numeric" });
}

export function relativeDate(iso: string) {
  const diff = (Date.now() - new Date(iso).getTime()) / 1000;
  if (diff < 60) return "à l'instant";
  if (diff < 3600) return `il y a ${Math.floor(diff / 60)} min`;
  if (diff < 86400) return `il y a ${Math.floor(diff / 3600)} h`;
  if (diff < 7 * 86400) return `il y a ${Math.floor(diff / 86400)} j`;
  return new Date(iso).toLocaleDateString("fr-FR", { day: "numeric", month: "short" });
}
