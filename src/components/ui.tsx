import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { t } from "../i18n";
import { useOnline } from "../lib/useOnline";

const BASE = "/assets/noodeu";

export type IconName =
  | "home" | "library" | "bulb" | "heart" | "settings" | "arrow-left" | "arrow-right" | "chevron-down" | "chevron-up"
  | "close" | "check" | "plus" | "minus" | "search" | "filter" | "bookmark" | "star" | "share" | "send" | "copy"
  | "link" | "users" | "user" | "chat" | "pause" | "play" | "stop" | "skip" | "mic" | "image" | "volume" | "clock"
  | "lock" | "eye" | "eye-off" | "bell" | "wifi" | "refresh" | "logout" | "info" | "help" | "pencil" | "undo"
  | "eraser" | "smile" | "puzzle" | "cards" | "lightning" | "leaf" | "sparkles" | "delete" | "quote";

/** Icône du kit (masque CSS : hérite de la couleur du texte). Décorative sauf si `label` est fourni. */
export function Icon({ name, size = 22, label }: { name: IconName; size?: number; label?: string }) {
  const style = { width: size, height: size, "--icon": `url("${BASE}/03_Icones_SVG/icon-${name}.svg")` } as CSSProperties;
  return <span className="icon" style={style} role={label ? "img" : undefined} aria-label={label} aria-hidden={label ? undefined : true} />;
}

export function Logo({ variant = "couleur", width = 140 }: { variant?: "couleur" | "prune" | "blanc"; width?: number }) {
  return (
    <img className="logo" src={`${BASE}/01_Logos/noodeu-logo-${variant}.svg`} width={width} height={Math.round((width * 190) / 830)} alt="Noodeu" />
  );
}

export type IllustrationName =
  | "01-connexion-a-deux" | "02-invitation" | "03-duo-confirme" | "04-portrait-en-mots" | "05-conversation"
  | "06-quiz-devinette" | "07-dessin-creatif" | "08-cooperation" | "09-attente-douce" | "10-revelation"
  | "11-fin-de-partie" | "12-astuce" | "13-favoris" | "14-duo-a-creer" | "15-invitation-expiree" | "16-reconnexion"
  | "17-pause" | "18-rire-ensemble";

/** Illustration du kit : WebP léger (alpha conservé) avec repli sur le PNG source. */
export function Illustration({ name, alt = "", className = "", eager = false }: { name: IllustrationName; alt?: string; className?: string; eager?: boolean }) {
  return (
    <picture>
      <source srcSet={`${BASE}/02_Illustrations_WEBP/noodeu-${name}.webp`} type="image/webp" />
      <img
        className={`illustration ${className}`}
        src={`${BASE}/02_Illustrations_PNG/noodeu-${name}.png`}
        width={1448}
        height={1086}
        alt={alt}
        loading={eager ? "eager" : "lazy"}
        decoding="async"
      />
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
  return <div className="page center" style={{ paddingTop: 80 }}><Loading /></div>;
}

export function EmptyState({ illustration, title, text, children }: { illustration?: IllustrationName; title: string; text?: string; children?: ReactNode }) {
  return (
    <section className="empty">
      {illustration && <Illustration name={illustration} />}
      <h2>{title}</h2>
      {text && <p>{text}</p>}
      {children}
    </section>
  );
}

export function Alert({ kind = "error", children }: { kind?: "error" | "info" | "success"; children: ReactNode }) {
  return <div className={`alert alert--${kind}`} role={kind === "error" ? "alert" : "status"}>{children}</div>;
}

export function DemoBadge() {
  return <span className="badge badge--demo" title={t("common.demoHint")}>{t("common.demo")}</span>;
}

export function Avatar({ name, me = false }: { name: string; me?: boolean }) {
  const initial = (name.trim()[0] ?? "?").toUpperCase();
  return <span className={`avatar ${me ? "avatar--me" : ""}`} aria-hidden="true">{initial}</span>;
}

/** Bandeau de connexion : honnête sur l'état du réseau. */
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

/** Feuille modale accessible (salon, confirmations). Ferme avec Échap. */
export function Sheet({ title, onClose, children, footer, labelledBy }: { title?: ReactNode; onClose: () => void; children: ReactNode; footer?: ReactNode; labelledBy?: string }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const prev = document.activeElement as HTMLElement | null;
    ref.current?.focus();
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
      prev?.focus();
    };
  }, [onClose]);
  return (
    <div className="sheet-backdrop" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="sheet" role="dialog" aria-modal="true" aria-labelledby={labelledBy} tabIndex={-1} ref={ref}>
        <div className="sheet__head">
          <div>{title}</div>
          <button className="icon-btn" onClick={onClose}><Icon name="close" label={t("common.close")} /></button>
        </div>
        <div className="sheet__body">{children}</div>
        {footer && <div className="sheet__foot">{footer}</div>}
      </div>
    </div>
  );
}

export function formatDate(iso: string, withTime = false) {
  const d = new Date(iso);
  return d.toLocaleDateString("fr-FR", withTime ? { day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" } : { day: "numeric", month: "long", year: "numeric" });
}
