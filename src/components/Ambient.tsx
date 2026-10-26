import { useEffect, useRef, useState } from "react";

const ART = "/assets/noodeu/v7/app-background.svg";
const STATIC = "/assets/noodeu/v7/app-background-static.png";

/** Fond décoratif V7 : derrière toutes les surfaces, sans pointeur, focus ni rôle dans l'arbre accessible.
 *  Mouvement lent (±3/±4 px, 24 s) suspendu quand le document est masqué ou la couche hors champ, sans
 *  rattrapage au retour. Fixe si l'appareil demande moins de mouvement ou si « Réduire les animations » est
 *  activé dans Réglages (classe html.reduced-motion). Il ne pilote aucun état de jeu. */
export function Ambient() {
  const ref = useRef<HTMLDivElement>(null);
  const [hidden, setHidden] = useState(() => typeof document !== "undefined" && document.hidden);
  const [offscreen, setOffscreen] = useState(false);
  const [still, setStill] = useState(false);

  useEffect(() => {
    const onVisibility = () => setHidden(document.hidden);
    document.addEventListener("visibilitychange", onVisibility);
    const media = matchMedia("(prefers-reduced-motion: reduce)");
    const root = document.documentElement;
    const syncStill = () => setStill(media.matches || root.classList.contains("reduced-motion"));
    syncStill();
    media.addEventListener("change", syncStill);
    const classes = new MutationObserver(syncStill);
    classes.observe(root, { attributes: true, attributeFilter: ["class"] });
    let io: IntersectionObserver | undefined;
    if (ref.current && "IntersectionObserver" in window) {
      io = new IntersectionObserver(([entry]) => setOffscreen(!entry.isIntersecting));
      io.observe(ref.current);
    }
    return () => {
      document.removeEventListener("visibilitychange", onVisibility);
      media.removeEventListener("change", syncStill);
      classes.disconnect();
      io?.disconnect();
    };
  }, []);

  return (
    <div ref={ref} className={`noodeu-ambient${still ? " noodeu-ambient--still" : ""}`} aria-hidden="true"
      data-motion-paused={hidden || offscreen || still ? "true" : "false"}>
      <img className="noodeu-ambient__art" src={still ? STATIC : ART} alt="" decoding="async" draggable={false} />
    </div>
  );
}
