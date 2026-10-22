import { useRef, useState } from "react";
import { t } from "../i18n";
import { Icon } from "./ui";

/** Trait vectoriel normalisé (0..1) : couleur et épaisseur par index, points arrondis au millième. */
export interface Stroke { c: number; w: number; p: [number, number][] }

export const DRAW_COLORS = ["#43263E", "#F17868", "#663C59", "#516B80", "#A9D9C2", "#F4D57A", "#C7B5E5", "#765647"];
const COLOR_NAMES = ["prune foncé", "corail", "prune", "bleu ardoise", "menthe", "jaune", "lilas", "brun"];
const WIDTHS = [0.008, 0.016, 0.03];
const MAX_POINTS = 6000;
const round3 = (x: number) => Math.round(Math.min(1, Math.max(0, x)) * 1000) / 1000;

function pathOf(s: Stroke) {
  if (s.p.length === 1) return `M${s.p[0][0]} ${s.p[0][1]}l0.0001 0`;
  return s.p.map(([x, y], i) => `${i ? "L" : "M"}${x} ${y}`).join("");
}

/** Affichage d'un dessin (lecture seule). Le texte alternatif est fourni par le contexte. */
export function DrawingView({ strokes, label, className = "" }: { strokes: Stroke[]; label: string; className?: string }) {
  return (
    <svg className={`drawing ${className}`} viewBox="0 0 1 1" role="img" aria-label={label} preserveAspectRatio="xMidYMid meet">
      {strokes.map((s, i) => (
        <path key={i} d={pathOf(s)} fill="none" stroke={DRAW_COLORS[s.c] ?? DRAW_COLORS[0]} strokeWidth={WIDTHS[s.w] ?? WIDTHS[1]}
          strokeLinecap="round" strokeLinejoin="round" />
      ))}
    </svg>
  );
}

/**
 * Carnet de dessin : un trait est confirmé au lever du doigt (pas d'événement par point).
 * Annuler et Tout effacer restent accessibles au clavier ; le dessin est facultatif partout où il est proposé.
 */
export function DrawingPad({ value, onChange, label }: { value: Stroke[]; onChange: (s: Stroke[]) => void; label: string }) {
  const [color, setColor] = useState(1);
  const [width, setWidth] = useState(1);
  const svg = useRef<SVGSVGElement>(null);
  const current = useRef<Stroke | null>(null);
  const [, force] = useState(0);
  const total = value.reduce((n, s) => n + s.p.length, 0);

  function point(e: React.PointerEvent): [number, number] {
    const r = svg.current!.getBoundingClientRect();
    return [round3((e.clientX - r.left) / r.width), round3((e.clientY - r.top) / r.height)];
  }

  return (
    <div className="drawpad">
      <svg ref={svg} className="drawing drawing--pad" viewBox="0 0 1 1" role="img" aria-label={label}
        onPointerDown={(e) => {
          if (total >= MAX_POINTS || value.length >= 80) return;
          (e.target as Element).setPointerCapture?.(e.pointerId);
          current.current = { c: color, w: width, p: [point(e)] };
          force((n) => n + 1);
        }}
        onPointerMove={(e) => {
          const s = current.current;
          if (!s || s.p.length >= 500) return;
          const [x, y] = point(e);
          const [lx, ly] = s.p[s.p.length - 1];
          if (Math.abs(x - lx) + Math.abs(y - ly) < 0.006) return;
          s.p.push([x, y]);
          force((n) => n + 1);
        }}
        onPointerUp={() => {
          if (current.current) onChange([...value, current.current]);
          current.current = null;
        }}
        onPointerCancel={() => { current.current = null; force((n) => n + 1); }}
      >
        <rect x="0" y="0" width="1" height="1" fill="#fff" />
        {[...value, ...(current.current ? [current.current] : [])].map((s, i) => (
          <path key={i} d={pathOf(s)} fill="none" stroke={DRAW_COLORS[s.c]} strokeWidth={WIDTHS[s.w]} strokeLinecap="round" strokeLinejoin="round" />
        ))}
      </svg>
      <div className="drawpad__tools">
        <div className="chips" role="radiogroup" aria-label={t("draw.color")}>
          {DRAW_COLORS.map((c, i) => (
            <button key={c} type="button" role="radio" aria-checked={color === i} className="swatch" style={{ background: c }}
              aria-label={COLOR_NAMES[i]} onClick={() => setColor(i)} />
          ))}
        </div>
        <div className="row row--wrap">
          <div className="chips" role="radiogroup" aria-label={t("draw.width")}>
            {[t("draw.thin"), t("draw.medium"), t("draw.thick")].map((w, i) => (
              <button key={w} type="button" role="radio" aria-checked={width === i} className="chip" onClick={() => setWidth(i)}>{w}</button>
            ))}
          </div>
          <button type="button" className="btn btn--quiet btn--auto btn--sm" disabled={!value.length} onClick={() => onChange(value.slice(0, -1))}>
            <Icon name="undo" size={18} />{t("draw.undo")}
          </button>
          <button type="button" className="btn btn--quiet btn--auto btn--sm" disabled={!value.length} onClick={() => onChange([])}>{t("draw.clear")}</button>
        </div>
        <p className="t-meta" aria-live="polite">{t("draw.count", { n: value.length })}</p>
      </div>
    </div>
  );
}
