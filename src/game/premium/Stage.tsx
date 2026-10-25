import type { CSSProperties, ReactNode } from "react";
import type { Universe } from "./universe";
import { asset } from "./universe";

/**
 * Scène d'un jeu premium : décor discret en arrière-plan (jamais interactif, jamais porteur de texte),
 * accents de l'univers en variables CSS ; le plateau et les commandes restent au premier plan.
 */
export function Stage({ u, children, compact = false }: { u: Universe | null; children: ReactNode; compact?: boolean }) {
  if (!u) return <>{children}</>;
  const style = { "--u-tint": u.tint, "--u-accent": u.accent } as CSSProperties;
  return (
    <div className={`stage stage--${u.code}${compact ? " stage--compact" : ""}`} style={style}>
      <img className="stage__decor" src={asset(u.code, "scene")} alt="" aria-hidden="true" decoding="async" />
      <div className="stage__body">
        <p className="stage__eyebrow">{u.name}</p>
        {children}
      </div>
    </div>
  );
}

/** Illustration d'entrée de l'univers (salon, résultat) : décorative. */
export function Hero({ u, size = 120 }: { u: Universe; size?: number }) {
  return <img className="stage__hero" src={asset(u.code, "hero")} alt="" aria-hidden="true" width={size} height={Math.round(size * 0.85)} decoding="async" />;
}
