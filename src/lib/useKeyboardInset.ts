import { useEffect } from "react";

/** Clavier virtuel : quand le navigateur ne réduit pas la page (Safari iOS ignore interactive-widget),
 *  publie la hauteur masquée dans --kb-inset. Si la page est déjà réduite (Chrome Android), l'écart vaut 0 :
 *  aucune double compensation. Utilisé par les panneaux et le pied de saisie (styles/v7.css). */
export function useKeyboardInset() {
  useEffect(() => {
    const vv = window.visualViewport;
    if (!vv) return;
    const root = document.documentElement;
    let frame = 0;
    const update = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const hidden = Math.max(0, Math.round(window.innerHeight - (vv.height + vv.offsetTop)));
        root.style.setProperty("--kb-inset", `${hidden > 40 ? hidden : 0}px`);
      });
    };
    update();
    vv.addEventListener("resize", update);
    vv.addEventListener("scroll", update);
    return () => {
      cancelAnimationFrame(frame);
      vv.removeEventListener("resize", update);
      vv.removeEventListener("scroll", update);
      root.style.removeProperty("--kb-inset");
    };
  }, []);
}
