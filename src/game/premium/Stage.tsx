import type { CSSProperties, ReactNode } from "react";
import type { Universe } from "./universe";

/** Surfaces unies pour les commandes. L'art reste dans l'en-tête, jamais étiré derrière le plateau. */
export function Stage({ u, children, compact = false }: { u: Universe | null; children: ReactNode; compact?: boolean }) {
  if (!u) return <>{children}</>;
  const style = { "--u-tint": u.tint, "--u-accent": u.accent } as CSSProperties;
  return (
    <div className={`stage stage--${u.code}${compact ? " stage--compact" : ""}`} style={style}>
      <div className="stage__body">
        <div className="stage__heading"><p className="stage__eyebrow">{u.name}</p></div>
        {children}
      </div>
    </div>
  );
}

/** Pièce tactile déjà présente dans le kit ; geste PFC original du lot courant. */
export function Hero({ u, size = 96 }: { u: Universe; size?: number }) {
  return <img className="stage__hero" src={u.code === "M11" ? "/assets/original/pfc-rock.webp" : `/assets/original/library/${u.code}.svg`}
    alt="" aria-hidden="true" width={size} height={size} decoding="async" />;
}
