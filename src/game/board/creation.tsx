/* eslint-disable @typescript-eslint/no-explicit-any */
// Briques communes aux activités de création (famille 3) : carnet de dessin trait par trait, rendus SVG
// des créations, export en image PNG (fait dans le navigateur, rien n'est envoyé ailleurs).
import { useRef, useState, type ReactNode } from "react";
import { t } from "../../i18n";
import { Icon } from "../../components/ui";
import { DRAW_COLORS, type Stroke } from "../../components/Drawing";

type J = any;
const WIDTHS = [0.008, 0.016, 0.03];
const COLOR_NAMES = ["prune foncé", "corail", "prune", "bleu ardoise", "menthe", "jaune", "lilas", "brun"];
const r3 = (x: number) => Math.round(Math.min(1, Math.max(0, x)) * 1000) / 1000;

export function slug(label: string) {
  return label.replace(/œ/g, "oe").replace(/[’']/g, "").normalize("NFD").replace(/[̀-ͯ]/g, "")
    .toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}
export const elementSrc = (label: string) => `/assets/jeux/elements/${slug(label)}.svg`;

export function pathOf(s: Stroke, mirror = false) {
  const pts = mirror ? s.p.map(([x, y]) => [1 - x, y]) : s.p;
  if (pts.length === 1) return `M${pts[0][0]} ${pts[0][1]}l0.0001 0`;
  return pts.map(([x, y], i) => `${i ? "L" : "M"}${x} ${y}`).join("");
}

/** Traits dans un repère 0..1 (à placer dans un <svg viewBox="0 0 1 1"> ou un <g> mis à l'échelle). */
export function Strokes({ strokes, mirror = false, opacity = 1, gray = false }: { strokes: Stroke[]; mirror?: boolean; opacity?: number; gray?: boolean }) {
  return (
    <g opacity={opacity}>
      {strokes.map((s, i) => (
        <g key={i}>
          <path d={pathOf(s)} fill="none" stroke={gray ? "#A1A6AA" : DRAW_COLORS[s.c] ?? DRAW_COLORS[0]} strokeWidth={WIDTHS[s.w] ?? WIDTHS[1]} strokeLinecap="round" strokeLinejoin="round" />
          {mirror && <path d={pathOf(s, true)} fill="none" stroke={DRAW_COLORS[s.c] ?? DRAW_COLORS[0]} strokeWidth={WIDTHS[s.w] ?? WIDTHS[1]} strokeLinecap="round" strokeLinejoin="round" />}
        </g>
      ))}
    </g>
  );
}

/** Gommette ou objet posé (image du kit) dans un repère 0..1. */
export function Placed({ label, x, y, r = 0, size = 0.18 }: { label: string; x: number; y: number; r?: number; size?: number }) {
  // Image dessinée dans un repère de 100 unités puis mise à l'échelle : Chrome n'affiche pas une image SVG
  // dont la taille locale est inférieure à une unité.
  return (
    <g transform={`translate(${x} ${y}) rotate(${r}) scale(${size / 100})`}>
      <image href={elementSrc(label)} x={-50} y={-50} width={100} height={100} preserveAspectRatio="xMidYMid meet" />
    </g>
  );
}

/**
 * Carnet de dessin trait par trait : chaque trait est envoyé au lever du doigt (onStroke).
 * `underlay` est dessiné dessous (amorce, image fantôme, repères), `limitX` borne les points (miroir).
 */
export function StrokePad({ strokes, onStroke, label, underlay, disabled = false, mirror = false, limitX = 1, colors, ratio = 1 }: {
  strokes: Stroke[]; onStroke: (s: Stroke) => void | Promise<unknown>; label: string; underlay?: ReactNode; disabled?: boolean;
  mirror?: boolean; limitX?: number; colors?: number[]; ratio?: number;
}) {
  const palette = colors ?? [0, 1, 2, 3, 4, 5, 6, 7];
  const [color, setColor] = useState(palette.includes(1) ? 1 : palette[0]);
  const [width, setWidth] = useState(1);
  const svg = useRef<SVGSVGElement>(null);
  const cur = useRef<Stroke | null>(null);
  const [, force] = useState(0);
  const point = (e: React.PointerEvent): [number, number] => {
    const r = svg.current!.getBoundingClientRect();
    return [r3(Math.min(limitX, (e.clientX - r.left) / r.width)), r3((e.clientY - r.top) / r.height)];
  };
  return (
    <div className="drawpad">
      <svg ref={svg} className={`drawing drawing--pad ${disabled ? "drawing--off" : ""}`} viewBox={`0 0 1 ${ratio}`} role="img" aria-label={label}
        style={{ aspectRatio: `1 / ${ratio}` }}
        onPointerDown={(e) => {
          if (disabled) return;
          (e.target as Element).setPointerCapture?.(e.pointerId);
          cur.current = { c: color, w: width, p: [point(e)] };
          force((n) => n + 1);
        }}
        onPointerMove={(e) => {
          const s = cur.current;
          if (!s || s.p.length >= 400) return;
          const [x, y] = point(e);
          const [lx, ly] = s.p[s.p.length - 1];
          if (Math.abs(x - lx) + Math.abs(y - ly) < 0.008) return;
          s.p.push([x, y]);
          force((n) => n + 1);
        }}
        onPointerUp={() => { const s = cur.current; cur.current = null; force((n) => n + 1); if (s) void onStroke(s); }}
        onPointerCancel={() => { cur.current = null; force((n) => n + 1); }}>
        <rect x="0" y="0" width="1" height={ratio} fill="#fff" />
        {underlay}
        <Strokes strokes={[...strokes, ...(cur.current ? [cur.current] : [])]} mirror={mirror} />
      </svg>
      {!disabled && (
        <div className="drawpad__tools">
          <div className="chips" role="radiogroup" aria-label={t("draw.color")}>
            {palette.map((i) => (
              <button key={i} type="button" role="radio" aria-checked={color === i} className="swatch" style={{ background: DRAW_COLORS[i] }}
                aria-label={COLOR_NAMES[i]} onClick={() => setColor(i)} />
            ))}
          </div>
          <div className="chips" role="radiogroup" aria-label={t("draw.width")}>
            {[t("draw.thin"), t("draw.medium"), t("draw.thick")].map((w, i) => (
              <button key={w} type="button" role="radio" aria-checked={width === i} className="chip" onClick={() => setWidth(i)}>{w}</button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Export en image : SVG → PNG (les images du kit sont intégrées avant le dessin sur le canevas).
// ---------------------------------------------------------------------------
async function inlineImages(svg: SVGSVGElement) {
  const clone = svg.cloneNode(true) as SVGSVGElement;
  const imgs = Array.from(clone.querySelectorAll("image"));
  await Promise.all(imgs.map(async (img) => {
    const href = img.getAttribute("href");
    if (!href || href.startsWith("data:")) return;
    try {
      const res = await fetch(href);
      const blob = await res.blob();
      const data = await new Promise<string>((ok) => { const fr = new FileReader(); fr.onload = () => ok(String(fr.result)); fr.readAsDataURL(blob); });
      img.setAttribute("href", data);
    } catch { /* image absente : on garde la place vide */ }
  }));
  clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
  return clone;
}

export async function exportPng(svg: SVGSVGElement, name: string) {
  const clone = await inlineImages(svg);
  const vb = svg.viewBox.baseVal;
  const w = 1200, h = Math.round((1200 * (vb.height || 1)) / (vb.width || 1));
  clone.setAttribute("width", String(w)); clone.setAttribute("height", String(h));
  const url = URL.createObjectURL(new Blob([new XMLSerializer().serializeToString(clone)], { type: "image/svg+xml" }));
  const img = new Image();
  await new Promise<void>((ok, ko) => { img.onload = () => ok(); img.onerror = () => ko(); img.src = url; });
  const canvas = document.createElement("canvas");
  canvas.width = w; canvas.height = h;
  const ctx = canvas.getContext("2d")!;
  ctx.fillStyle = "#FFF9F2"; ctx.fillRect(0, 0, w, h);
  ctx.drawImage(img, 0, 0, w, h);
  URL.revokeObjectURL(url);
  const a = document.createElement("a");
  a.href = canvas.toDataURL("image/png");
  a.download = `${slug(name) || "creation"}.png`;
  a.click();
}

/** Création affichée avec un bouton « Enregistrer en image ». */
export function Exportable({ name, children, viewBox, label }: { name: string; children: ReactNode; viewBox: string; label: string }) {
  const ref = useRef<SVGSVGElement>(null);
  const [busy, setBusy] = useState(false);
  return (
    <div className="stack stack--2">
      <svg ref={ref} className="creation" viewBox={viewBox} role="img" aria-label={label} xmlns="http://www.w3.org/2000/svg">{children}</svg>
      <button type="button" className="btn btn--secondary btn--auto btn--sm" disabled={busy}
        onClick={async () => { setBusy(true); try { await exportPng(ref.current!, name); } finally { setBusy(false); } }}>
        <Icon name="image" size={18} />{t("cr.export")}
      </button>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Tangram : mêmes calculs que le serveur (sommets entiers, quart de tour, retournement).
// ---------------------------------------------------------------------------
export function tgPoly(base: [number, number][], px: number, py: number, rot: number, flip: boolean): [number, number][] {
  let pts = base.map(([x, y]) => {
    let a = flip ? -x : x, b = y;
    for (let k = 0; k < ((rot % 4) + 4) % 4; k++) { const tmp = a; a = -b; b = tmp; }
    return [a, b] as [number, number];
  });
  const mx = Math.min(...pts.map((p) => p[0])), my = Math.min(...pts.map((p) => p[1]));
  pts = pts.map(([x, y]) => [x - mx + px, y - my + py]);
  return pts;
}

export const WEAVE_MARK = { over: "│", under: "─" };
export type { J };
