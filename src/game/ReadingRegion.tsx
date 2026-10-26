import { useEffect, useId, useRef, useState, type ReactNode } from "react";
import "../styles/question-reading.css";

/** Texte complet dans une surface fixe ; l'indice reste hors du texte et ne le recouvre jamais. */
export function ReadingRegion({ children, label, className = "", resetKey }: {
  children: ReactNode; label: string; className?: string; resetKey?: string | number;
}) {
  const region = useRef<HTMLDivElement>(null);
  const content = useRef<HTMLDivElement>(null);
  const hintId = useId();
  const [scroll, setScroll] = useState({ overflowing: false, below: false });

  useEffect(() => {
    const element = region.current;
    const body = content.current;
    if (!element || !body) return;
    let frame = 0;
    const measure = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const overflowing = element.scrollHeight > element.clientHeight + 1;
        const below = element.scrollTop + element.clientHeight < element.scrollHeight - 2;
        setScroll(previous => previous.overflowing === overflowing && previous.below === below ? previous : { overflowing, below });
      });
    };
    element.scrollTop = 0;
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    observer.observe(body);
    element.addEventListener("scroll", measure, { passive: true });
    measure();
    return () => {
      cancelAnimationFrame(frame);
      observer.disconnect();
      element.removeEventListener("scroll", measure);
    };
  }, [resetKey]);

  return (
    <article className={`q-card question-reading ${className}`}>
      <div className="question-reading__scroll" ref={region} role="region" aria-label={label}
        aria-describedby={scroll.overflowing ? hintId : undefined} tabIndex={0}>
        <div className="question-reading__content" ref={content}>{children}</div>
      </div>
      <span className="question-reading__hint" id={hintId} data-overflow={scroll.overflowing}>
        {scroll.overflowing ? scroll.below ? "Faire défiler ↓" : "Début du texte ↑" : ""}
      </span>
    </article>
  );
}
