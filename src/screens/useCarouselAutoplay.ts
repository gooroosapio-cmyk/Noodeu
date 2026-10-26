import { useEffect, useState, type RefObject } from "react";
/** One timer only; user interaction suspends rotation until an explicit restart. */
export function useCarouselAutoplay(ref: RefObject<HTMLDivElement | null>, count: number) {
  const [paused, setPaused] = useState(false);
  const [hover, setHover] = useState(false);
  const [focus, setFocus] = useState(false);
  const [hidden, setHidden] = useState(() => document.hidden);
  const [reduced, setReduced] = useState(() => matchMedia("(prefers-reduced-motion: reduce)").matches);
  useEffect(() => {
    const media = matchMedia("(prefers-reduced-motion: reduce)");
    const motion = () => setReduced(media.matches);
    const visibility = () => setHidden(document.hidden);
    media.addEventListener("change", motion);
    document.addEventListener("visibilitychange", visibility);
    return () => { media.removeEventListener("change", motion); document.removeEventListener("visibilitychange", visibility); };
  }, []);
  useEffect(() => {
    if (paused || hover || focus || hidden || reduced || count < 2) return;
    const timer = setInterval(() => {
      const el = ref.current;
      if (!el || document.hidden || matchMedia("(prefers-reduced-motion: reduce)").matches || el.contains(document.activeElement)) return;
      const nodes = Array.from(el.children) as HTMLElement[];
      if (nodes.length < 2) return;
      const origin = nodes[0].offsetLeft;
      const current = nodes.reduce((best, node, i) => Math.abs(node.offsetLeft - origin - el.scrollLeft) < Math.abs(nodes[best].offsetLeft - origin - el.scrollLeft) ? i : best, 0);
      el.scrollTo({ left: nodes[(current + 1) % nodes.length].offsetLeft - origin, behavior: "smooth" });
    }, 3000);
    return () => clearInterval(timer);
  }, [ref, count, paused, hover, focus, hidden, reduced]);
  return { paused, reduced, setPaused, setHover, setFocus };
}
