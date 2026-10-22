/* eslint-disable @typescript-eslint/no-explicit-any */
// Famille 3 « Dessin et création » : écrans de jeu et rendus finaux (exportables en image).
import { useEffect, useRef, useState, type ComponentType, type ReactNode } from "react";
import { t, type MessageKey } from "../../i18n";
import { Icon } from "../../components/ui";
import { DrawingView, type Stroke } from "../../components/Drawing";
import type { Player } from "../../lib/types";
import { Exportable, Placed, StrokePad, Strokes, elementSrc, tgPoly } from "./creation";

type J = any;
type Play = (type: string, payload?: Record<string, unknown>) => Promise<{ ok: boolean; info?: J }>;
export interface CV { c: J; priv: J; me: Player; partner?: Player; play: Play; busy: boolean; mine: boolean }

const nameOf = (p?: Player) => (p ? (p.is_me ? t("game.you") : p.display_name || "?") : "?");
const PIXEL = ["#F17868", "#F4D57A", "#A9D9C2", "#663C59", "#516B80", "#C7B5E5"];
const PIXEL_NAMES = ["corail", "jaune", "menthe", "prune", "bleu ardoise", "lilas"];
const NOTE_NAMES: Record<number, string> = { 60: "do", 62: "ré", 64: "mi", 67: "sol", 69: "la" };

function Small({ children, onClick, busy, icon }: { children: ReactNode; onClick: () => void; busy: boolean; icon?: "undo" | "bulb" | "check" | "refresh" }) {
  return <button type="button" className="btn btn--quiet btn--auto btn--sm" disabled={busy} onClick={onClick}>{icon && <Icon name={icon} size={18} />}{children}</button>;
}

function TextSend({ id, label, max, busy, onSend, button = t("board.send"), hint }: {
  id: string; label: string; max: number; busy: boolean; onSend: (v: string) => Promise<boolean>; button?: string; hint?: string;
}) {
  const [v, setV] = useState("");
  return (
    <form className="stack stack--2" onSubmit={async (e) => { e.preventDefault(); if (v.trim() && await onSend(v.trim())) setV(""); }}>
      <div className="field">
        <label className="field__label" htmlFor={id}>{label}</label>
        {hint && <span className="field__hint">{hint}</span>}
        <input id={id} className="input" maxLength={max} value={v} autoComplete="off" onChange={(e) => setV(e.target.value)} />
      </div>
      <button className="btn" type="submit" disabled={busy || !v.trim()}>{button}</button>
    </form>
  );
}

const Waiting = ({ partner }: { partner?: Player }) => <p className="center muted">{t("board.waitingOther", { name: nameOf(partner) })}</p>;

// ---------------------------------------------------------------------------
// Rendus des créations (réutilisés en jeu, en fin de manche et à l'export)
// ---------------------------------------------------------------------------
function Frame({ children, ratio = 1 }: { children: ReactNode; ratio?: number }) {
  return <><rect x="0" y="0" width="1" height={ratio} fill="#fff" />{children}</>;
}

export function PixelArt({ cells, size = 8 }: { cells: (number | null)[]; size?: number }) {
  return (
    <g>
      {cells.map((v, i) => (
        <rect key={i} x={(i % size) / size} y={Math.floor(i / size) / size} width={1 / size} height={1 / size}
          fill={v === null || v === undefined ? "#FFF9F2" : PIXEL[v]} stroke="#E8DDD6" strokeWidth={0.002} />
      ))}
    </g>
  );
}

export function EmblemArt({ c }: { c: J }) {
  const color = (k?: number) => c.colors?.[k ?? 0]?.hex ?? "#663C59";
  const shape = c.support ?? 0;
  const s1 = c.slots?.["1"], s2 = c.slots?.["2"];
  return (
    <g>
      <rect x="0" y="0" width="1" height="1" fill="#FFF9F2" />
      {shape === 0 && <circle cx="0.5" cy="0.45" r="0.36" fill="#FFF" stroke="#663C59" strokeWidth="0.02" />}
      {shape === 1 && <rect x="0.14" y="0.09" width="0.72" height="0.72" rx="0.12" fill="#FFF" stroke="#663C59" strokeWidth="0.02" />}
      {shape === 2 && <path d="M0.5 0.06 L0.88 0.45 L0.5 0.84 L0.12 0.45 Z" fill="#FFF" stroke="#663C59" strokeWidth="0.02" />}
      {s1 && <><circle cx="0.38" cy="0.45" r="0.12" fill={color(s1.c)} opacity="0.35" /><Placed label={c.symbols[s1.o]} x={0.38} y={0.45} size={0.2} /></>}
      {s2 && <><circle cx="0.62" cy="0.45" r="0.12" fill={color(s2.c)} opacity="0.35" /><Placed label={c.symbols[s2.o]} x={0.62} y={0.45} size={0.2} /></>}
      {c.name && <text x="0.5" y="0.95" textAnchor="middle" fontSize="0.07" fill="#43263E" fontFamily="sans-serif">{c.name}</text>}
    </g>
  );
}

function PosterArt({ c }: { c: J }) {
  return (
    <g>
      <rect x="0" y="0" width="1" height="1.4" fill="#FFF5E8" stroke="#663C59" strokeWidth="0.01" />
      <text x="0.5" y="0.13" textAnchor="middle" fontSize="0.075" fontWeight="700" fill="#43263E" fontFamily="sans-serif">{c.title ?? "…"}</text>
      {(c.visual ?? []).map((o: J, i: number) => <Placed key={i} label={c.objects[o.s]} x={o.x} y={0.2 + o.y * 0.8} r={o.r} size={0.2} />)}
      <text x="0.5" y="1.12" textAnchor="middle" fontSize="0.045" fill="#43263E" fontFamily="sans-serif">{c.subtitle ?? ""}</text>
      <text x="0.5" y="1.24" textAnchor="middle" fontSize="0.04" fill="#663C59" fontFamily="sans-serif">{c.detail ?? ""}</text>
      <text x="0.5" y="1.34" textAnchor="middle" fontSize="0.03" fill="#765647" fontFamily="sans-serif">{t("cr.poster.fictional")}</text>
    </g>
  );
}

function TileArt({ grid }: { grid: (string | null)[] }) {
  return (
    <g>
      <rect x="0" y="0" width="1" height="1" fill="#ADD8E8" />
      {grid.map((v, i) => v && (
        <g key={i}>
          <rect x={(i % 5) / 5} y={Math.floor(i / 5) / 5} width={0.2} height={0.2} fill="#FFF9F2" stroke="#E8DDD6" strokeWidth={0.003} />
          <Placed label={v} x={(i % 5) / 5 + 0.1} y={Math.floor(i / 5) / 5 + 0.1} size={0.17} />
        </g>
      ))}
    </g>
  );
}

function StarsArt({ c }: { c: J }) {
  const pos = (k: number) => { const cell = c.stars[k].cell; return [(cell % 5) / 5 + 0.1, Math.floor(cell / 5) / 5 + 0.1]; };
  return (
    <g>
      <rect x="0" y="0" width="1" height="1" fill="#253C54" />
      {c.seq.length > 1 && <polyline points={c.seq.map((k: number) => pos(k).join(",")).join(" ")} fill="none" stroke="#F4D57A" strokeWidth="0.008" />}
      {c.stars.map((s: J, k: number) => {
        const [x, y] = pos(k);
        return <g key={k}><circle cx={x} cy={y} r="0.035" fill="#FFF5E8" /><text x={x} y={y + 0.08} textAnchor="middle" fontSize="0.04" fill="#FFF5E8" fontFamily="sans-serif">{NOTE_NAMES[s.note] ?? s.note}</text></g>;
      })}
    </g>
  );
}

function WeaveArt({ c, show = "mask" }: { c: J; show?: "mask" | "model" }) {
  const mask: number[] = show === "model" ? c.model.mask : c.mask;
  const col = (list: (number | string | null)[], i: number) => {
    const v = list[i];
    if (typeof v === "string") return c.palette.find((p: J) => p.name === v)?.hex ?? "#ccc";
    return v === null || v === undefined ? "#E8DDD6" : c.palette[v]?.hex ?? "#ccc";
  };
  const v = show === "model" ? c.model.vertical : c.vcolors, h = show === "model" ? c.model.horizontal : c.hcolors;
  return (
    <g>
      {mask.map((m, i) => {
        const x = (i % 6) / 6, y = Math.floor(i / 6) / 6;
        return (
          <g key={i}>
            <rect x={x} y={y} width={1 / 6} height={1 / 6} fill={m ? col(v, i % 6) : col(h, Math.floor(i / 6))} stroke="#fff" strokeWidth="0.004" />
            {m ? <line x1={x + 1 / 12} y1={y + 0.02} x2={x + 1 / 12} y2={y + 1 / 6 - 0.02} stroke="#30323D" strokeWidth="0.006" opacity="0.5" />
               : <line x1={x + 0.02} y1={y + 1 / 12} x2={x + 1 / 6 - 0.02} y2={y + 1 / 12} stroke="#30323D" strokeWidth="0.006" opacity="0.5" />}
          </g>
        );
      })}
    </g>
  );
}

function FlipFrame({ c, i, opacity = 1 }: { c: J; i: number; opacity?: number }) {
  const f = c.frames[i];
  if (!f) return null;
  return (
    <g opacity={opacity}>
      {f.objs.map((o: J, k: number) => <Placed key={k} label={c.objects[o.s]} x={o.x} y={o.y} r={o.r} size={0.22} />)}
      <Strokes strokes={f.strokes ?? []} />
    </g>
  );
}

// ---------------------------------------------------------------------------
// Écrans de jeu
// ---------------------------------------------------------------------------
function DrawGuess({ c, priv, me, partner, play, busy }: CV) {
  const drawer = c.drawer === me.seat;
  const left = c.budget ? c.budget - c.used : null;
  return (
    <div className="stack stack--4">
      <p className="t-meta">{drawer ? t("cr.draw.youDraw") : t("cr.draw.youGuess", { name: nameOf(partner) })}</p>
      {drawer && priv?.target && <div className="play-card"><span className="t-meta">{t("cr.draw.target")}</span><p className="play-card__text">{priv.target}</p></div>}
      {left !== null && <p className="t-small strong" aria-live="polite">{t("cr.draw.left", { n: left })}</p>}
      {drawer
        ? <StrokePad strokes={c.strokes} label={t("cr.draw.canvas")} disabled={busy || left === 0} colors={c.budget ? [0] : undefined}
            onStroke={(s) => play("stroke", { s })} />
        : <DrawingView strokes={c.strokes} label={t("cr.draw.theirDrawing", { name: nameOf(partner) })} />}
      {drawer && c.strokes.length > 0 && <Small busy={busy || left === 0} icon="undo" onClick={() => void play("undo")}>{c.budget ? t("cr.draw.eraseCost") : t("draw.undo")}</Small>}
      {c.guesses.length > 0 && <ul className="chips" style={{ listStyle: "none", padding: 0, margin: 0 }}>{c.guesses.map((g: J, i: number) => <li key={i} className="tag">{g.text} {g.ok ? "✓" : "✗"}</li>)}</ul>}
      {!drawer && (c.strokes.length === 0
        ? <p className="muted center">{t("cr.draw.waitDrawing", { name: nameOf(partner) })}</p>
        : <TextSend id="dg" label={t("cr.draw.guess", { n: c.guesses.length + 1, max: c.max })} max={40} busy={busy} button={t("board.propose")}
            onSend={async (v) => (await play("guess", { text: v })).ok} />)}
    </div>
  );
}

function Doodle({ c, me, partner, play, busy, mine }: CV) {
  const mirror = c.mech === "mirror_draw";
  const names = mirror ? c.names : c.titles;
  if (c.phase === "name") {
    return (
      <div className="stack stack--4">
        <DrawingView strokes={[...(c.starter ?? []), ...c.strokes]} label={t("cr.doodle.result")} />
        {mirror && <svg className="drawing" viewBox="0 0 1 1" role="img" aria-label={t("cr.mirror.result")}><Frame><Strokes strokes={c.strokes} mirror /></Frame></svg>}
        {names?.[me.seat] ? <Waiting partner={partner} /> : <TextSend id="dn" label={mirror ? t("cr.mirror.name") : t("cr.doodle.title")} max={40} busy={busy} onSend={async (v) => (await play("name", { text: v })).ok} />}
      </div>
    );
  }
  const done = mirror ? c.in_tour : c.in_pass, per = mirror ? c.per_tour : c.per_pass;
  return (
    <div className="stack stack--4">
      <p className="t-small">{mirror ? t("cr.mirror.tour", { n: c.tour, max: c.max }) : t("cr.doodle.pass", { n: c.pass, max: c.max_pass, s: c.shape })} · {t("cr.strokesOf", { n: done, max: per })}</p>
      <StrokePad strokes={c.strokes} label={t("cr.doodle.canvas")} disabled={!mine || busy} mirror={mirror} limitX={mirror ? 0.5 : 1}
        underlay={<>{c.starter && <Strokes strokes={c.starter} gray />}{mirror && <line x1="0.5" y1="0" x2="0.5" y2="1" stroke="#C7B5E5" strokeWidth="0.004" strokeDasharray="0.02 0.02" />}</>}
        onStroke={(s) => play("stroke", { s })} />
      {mine && (
        <div className="row row--wrap">
          <Small busy={busy} onClick={() => void play("pass")}>{t("cr.handOver")}</Small>
          {done > 0 && <Small busy={busy} icon="undo" onClick={() => void play("undo")}>{t("draw.undo")}</Small>}
        </div>
      )}
    </div>
  );
}

const SHAPES = ["circle", "square", "triangle"] as const;
function ShapeIcon({ shape, x, y, rotation, size = 1 / 6, color = "#663C59" }: { shape: string; x: number; y: number; rotation: number; size?: number; color?: string }) {
  const cx = x * size + size / 2, cy = y * size + size / 2, r = size * 0.38;
  if (shape === "circle") return <circle cx={cx} cy={cy} r={r} fill={color} />;
  if (shape === "square") return <rect x={cx - r} y={cy - r} width={2 * r} height={2 * r} fill={color} transform={`rotate(${rotation} ${cx} ${cy})`} />;
  return <path d={`M${cx} ${cy - r} L${cx + r} ${cy + r} L${cx - r} ${cy + r} Z`} fill={color} transform={`rotate(${rotation} ${cx} ${cy})`} />;
}
function GeoGrid({ shapes, onCell, label, color }: { shapes: J[]; onCell?: (x: number, y: number) => void; label: string; color?: string }) {
  return (
    <svg className="drawing" viewBox="0 0 1 1" role="img" aria-label={label}>
      <rect x="0" y="0" width="1" height="1" fill="#fff" />
      {[1, 2, 3, 4, 5].map((k) => <g key={k}><line x1={k / 6} y1="0" x2={k / 6} y2="1" stroke="#E8DDD6" strokeWidth="0.004" /><line x1="0" y1={k / 6} x2="1" y2={k / 6} stroke="#E8DDD6" strokeWidth="0.004" /></g>)}
      {shapes.map((s, i) => <ShapeIcon key={i} {...s} color={color} />)}
      {onCell && [...Array(36)].map((_, i) => (
        <rect key={i} x={(i % 6) / 6} y={Math.floor(i / 6) / 6} width={1 / 6} height={1 / 6} fill="transparent" style={{ cursor: "pointer" }}
          onClick={() => onCell(i % 6, Math.floor(i / 6))} />
      ))}
    </svg>
  );
}

function Dictation({ c, priv, me, partner, play, busy }: CV) {
  const guide = c.guide === me.seat;
  const [shapes, setShapes] = useState<J[]>(c.placed ?? []);
  const [tool, setTool] = useState<string>("circle");
  const [rot, setRot] = useState(0);
  return (
    <div className="stack stack--4">
      <p className="t-meta">{guide ? t("cr.dict.youGuide", { k: c.k }) : t("cr.dict.youDraw", { name: nameOf(partner), k: c.k })}</p>
      {guide && priv?.model && <GeoGrid shapes={priv.model} label={t("cr.dict.model")} />}
      {!guide && (
        <>
          <div className="chips" role="radiogroup" aria-label={t("cr.dict.shape")}>
            {SHAPES.map((s) => <button key={s} type="button" role="radio" aria-checked={tool === s} className="chip" onClick={() => setTool(s)}>{t(`cr.shape.${s}` as MessageKey)}</button>)}
            <button type="button" className="chip" onClick={() => setRot((rot + 90) % 360)}><Icon name="refresh" size={16} />{rot}°</button>
          </div>
          <GeoGrid shapes={shapes} label={t("cr.dict.yourGrid")} onCell={(x, y) => {
            const exists = shapes.findIndex((s) => s.x === x && s.y === y);
            if (exists >= 0) setShapes(shapes.filter((_, i) => i !== exists));
            else if (shapes.length < 8) setShapes([...shapes, { shape: tool, x, y, rotation: rot }]);
          }} />
          <p className="t-meta">{t("cr.dict.tapHint")}</p>
          <div className="row row--wrap">
            <button className="btn btn--secondary btn--auto" disabled={busy} onClick={() => void play("place", { shapes })}>{t("cr.dict.share")}</button>
            <button className="btn btn--auto" disabled={busy || !c.placed.length} onClick={() => void play("validate")}>{t("cr.dict.validate")}</button>
          </div>
        </>
      )}
      {guide && <GeoGrid shapes={c.placed} label={t("cr.dict.theirGrid", { name: nameOf(partner) })} color="#F17868" />}
      <ol className="stack stack--2 board-log">{c.messages.map((m: J, i: number) => <li key={i} className="answer-block"><span className="t-meta">{m.seat === me.seat ? t("game.you") : nameOf(partner)}</span>{m.text}</li>)}</ol>
      <TextSend id="dict" label={guide ? t("cr.dict.say") : t("cr.dict.ask")} max={140} busy={busy} onSend={async (v) => (await play(guide ? "say" : "ask", { text: v })).ok} />
    </div>
  );
}

function Exquisite({ c, me, partner, play, busy }: CV) {
  const [drafts, setDrafts] = useState<Record<number, Stroke[]>>({});
  const bandNames = [t("cr.exq.head"), t("cr.exq.body"), t("cr.exq.legs")];
  if (c.phase === "name") {
    return (
      <div className="stack stack--4">
        <ExquisiteArt c={c} />
        {c.names?.[me.seat] ? <Waiting partner={partner} /> : <TextSend id="exn" label={t("cr.exq.name")} max={40} busy={busy} onSend={async (v) => (await play("name", { text: v })).ok} />}
      </div>
    );
  }
  return (
    <div className="stack stack--4">
      {c.owners.map((owner: number, i: number) => (
        <div key={i} className="card stack stack--2">
          <h3 className="t-card">{bandNames[i]} · <span className="t-meta">{t("cr.exq.idea", { s: c.suggestions[i] })}</span></h3>
          {c.done_bands[String(i)] ? <p className="muted">{owner === me.seat ? t("cr.exq.sent") : t("cr.exq.hidden", { name: nameOf(partner) })}</p>
            : owner !== me.seat ? <p className="muted">{t("cr.exq.theirBand", { name: nameOf(partner) })}</p>
            : (
              <>
                <StrokePad strokes={drafts[i] ?? []} label={bandNames[i]} ratio={0.5} disabled={busy}
                  underlay={<>{i > 0 && c.marks[i - 1].map((x: number) => <line key={x} x1={x} y1="0" x2={x} y2="0.06" stroke="#F17868" strokeWidth="0.012" />)}
                    {i < 2 && c.marks[i].map((x: number) => <line key={x} x1={x} y1="0.44" x2={x} y2="0.5" stroke="#F17868" strokeWidth="0.012" />)}</>}
                  onStroke={(s) => setDrafts({ ...drafts, [i]: [...(drafts[i] ?? []), { ...s, p: s.p.map(([x, y]) => [x, Math.min(0.5, y)] as [number, number]) }] })} />
                <div className="row row--wrap">
                  <Small busy={busy || !(drafts[i] ?? []).length} icon="undo" onClick={() => setDrafts({ ...drafts, [i]: (drafts[i] ?? []).slice(0, -1) })}>{t("draw.undo")}</Small>
                  <button className="btn btn--auto" disabled={busy || !(drafts[i] ?? []).length} onClick={() => void play("band", { band: i, strokes: drafts[i] })}>{t("cr.exq.send")}</button>
                </div>
                <p className="t-meta">{t("cr.exq.marks")}</p>
              </>
            )}
        </div>
      ))}
    </div>
  );
}
function ExquisiteArt({ c }: { c: J }) {
  return (
    <svg className="creation" viewBox="0 0 1 1.5" role="img" aria-label={t("cr.exq.creature")}>
      <rect x="0" y="0" width="1" height="1.5" fill="#fff" />
      {(c.bands ?? []).map((b: Stroke[], i: number) => <g key={i} transform={`translate(0 ${i * 0.5})`}><Strokes strokes={b ?? []} /></g>)}
    </svg>
  );
}

function Pixel({ c, me, partner, play, busy }: CV) {
  const mineColors: number[] = c.colors[me.seat];
  const [color, setColor] = useState<number | null>(mineColors[0]);
  const cells: (number | null)[] = c.cells;
  const toMe = c.pending.map((p: J, k: number) => ({ ...p, k })).filter((p: J) => p.by !== me.seat);
  return (
    <div className="stack stack--4">
      <div className="row row--wrap">
        <svg className="mini" viewBox="0 0 1 1" role="img" aria-label={t("cr.pixel.model", { n: c.model.name })}>
          <PixelArt cells={c.model.rows.join("").split("").map((x: string) => (x === "1" ? 3 : null))} size={5} />
        </svg>
        <p className="t-small">{t("cr.pixel.model", { n: c.model.name })}</p>
      </div>
      <div className="chips" role="radiogroup" aria-label={t("draw.color")}>
        {mineColors.map((k) => <button key={k} type="button" role="radio" aria-checked={color === k} className="swatch" style={{ background: PIXEL[k] }} aria-label={PIXEL_NAMES[k]} onClick={() => setColor(k)} />)}
        <button type="button" role="radio" aria-checked={color === null} className="chip" onClick={() => setColor(null)}>{t("cr.pixel.erase")}</button>
      </div>
      <div className="pixel-grid" role="grid" aria-label={t("cr.pixel.grid")}>
        {cells.map((v, i) => {
          const theirs = v !== null && !mineColors.includes(v);
          return (
            <button key={i} type="button" role="gridcell" className="pixel" disabled={busy} style={{ background: v === null ? undefined : PIXEL[v] }}
              aria-label={t("cr.pixel.cell", { r: Math.floor(i / 8) + 1, c: (i % 8) + 1, v: v === null ? t("cr.pixel.empty") : PIXEL_NAMES[v] })}
              onClick={() => void play(theirs ? "propose" : "paint", { i, c: color })} />
          );
        })}
      </div>
      <p className="t-meta">{t("cr.pixel.hint", { name: nameOf(partner) })}</p>
      {toMe.map((p: J) => (
        <div key={p.k} className="row row--between row--wrap card">
          <span>{t("cr.pixel.proposal", { name: nameOf(partner), r: Math.floor(p.i / 8) + 1, c: (p.i % 8) + 1, v: p.c === null ? t("cr.pixel.empty") : PIXEL_NAMES[p.c] })}</span>
          <div className="row"><Small busy={busy} onClick={() => void play("accept", { k: p.k })}>{t("board.accept")}</Small><Small busy={busy} onClick={() => void play("refuse", { k: p.k })}>{t("board.refuse")}</Small></div>
        </div>
      ))}
      {c.validated?.[me.seat] ? <Waiting partner={partner} /> : <button className="btn" disabled={busy} onClick={() => void play("validate")}>{t("cr.validateBoth")}</button>}
    </div>
  );
}

function Tangram({ c, play, busy }: CV) {
  const [sel, setSel] = useState<number | null>(null);
  const W = c.board.w, H = c.board.h;
  const piece = sel === null ? null : c.pieces[sel];
  const send = (dx: number, dy: number, drot = 0, flip?: boolean) => {
    if (!piece) return;
    const rot = (piece.rot + drot + 4) % 4, f = flip === undefined ? piece.flip : flip;
    const pts = tgPoly(piece.base, 0, 0, rot, f);
    const bw = Math.max(...pts.map((p) => p[0])), bh = Math.max(...pts.map((p) => p[1]));
    void play("place", { id: piece.id, x: Math.max(0, Math.min(W - bw, piece.x + dx)), y: Math.max(0, Math.min(H - bh, piece.y + dy)), rot, flip: f });
  };
  const colors = ["#F17868", "#663C59", "#F4D57A", "#A9D9C2", "#516B80", "#C7B5E5", "#BC7758"];
  return (
    <div className="stack stack--4">
      <svg className="drawing tangram" viewBox={`0 0 ${W} ${H}`} role="img" aria-label={t("cr.tangram.board")}>
        <rect x="0" y="0" width={W} height={H} fill="#fff" />
        <rect x={c.target.x} y={c.target.y} width={c.target.size} height={c.target.size} fill="#FFF5E8" stroke="#663C59" strokeWidth="0.06" strokeDasharray="0.2 0.12" />
        {[...Array(W * H)].map((_, i) => (
          <rect key={i} x={i % W} y={Math.floor(i / W)} width="1" height="1" fill="transparent"
            onClick={() => piece && void play("place", (() => {
              const pts = tgPoly(piece.base, 0, 0, piece.rot, piece.flip);
              const bw = Math.max(...pts.map((p) => p[0])), bh = Math.max(...pts.map((p) => p[1]));
              return { id: piece.id, x: Math.min(W - bw, i % W), y: Math.min(H - bh, Math.floor(i / W)), rot: piece.rot, flip: piece.flip };
            })())} />
        ))}
        {c.pieces.map((p: J) => (
          <polygon key={p.id} points={tgPoly(p.base, p.x, p.y, p.rot, p.flip).map((q) => q.join(",")).join(" ")}
            fill={colors[p.id]} fillOpacity="0.85" stroke={sel === p.id ? "#43263E" : "#fff"} strokeWidth={sel === p.id ? 0.14 : 0.05}
            onClick={() => setSel(p.id)} style={{ cursor: "pointer" }} />
        ))}
      </svg>
      <div className="chips" role="radiogroup" aria-label={t("cr.tangram.pieces")}>
        {c.pieces.map((p: J) => <button key={p.id} type="button" role="radio" aria-checked={sel === p.id} className="chip" onClick={() => setSel(p.id)}>
          <span className="swatch swatch--sm" style={{ background: colors[p.id] }} aria-hidden="true" />{t(`cr.tangram.p${p.id}` as MessageKey)}</button>)}
      </div>
      {piece ? (
        <div className="pad-keys" aria-label={t("cr.tangram.move")}>
          <button type="button" className="key" disabled={busy} onClick={() => send(0, -1)} aria-label={t("cr.up")}>↑</button>
          <button type="button" className="key" disabled={busy} onClick={() => send(-1, 0)} aria-label={t("cr.left")}>←</button>
          <button type="button" className="key" disabled={busy} onClick={() => send(1, 0)} aria-label={t("cr.right")}>→</button>
          <button type="button" className="key" disabled={busy} onClick={() => send(0, 1)} aria-label={t("cr.down")}>↓</button>
          <button type="button" className="key key--wide" disabled={busy} onClick={() => send(0, 0, 1)}>{t("cr.tangram.rotate")}</button>
          {piece.flippable && <button type="button" className="key key--wide" disabled={busy} onClick={() => send(0, 0, 0, !piece.flip)}>{t("cr.tangram.flip")}</button>}
        </div>
      ) : <p className="t-small muted">{t("cr.tangram.pick")}</p>}
      <p className="t-meta">{t("cr.tangram.moves", { n: c.moves })}</p>
    </div>
  );
}

function Jigsaw({ c, play, busy }: CV) {
  const [sel, setSel] = useState<number | null>(null);
  const n = c.rows * c.cols;
  return (
    <div className="stack stack--4">
      <p className="t-small muted">{sel === null ? t("cr.jigsaw.pick") : t("cr.jigsaw.place")}</p>
      <div className="jigsaw" style={{ gridTemplateColumns: `repeat(${c.cols}, 1fr)` }} role="grid" aria-label={t("cr.jigsaw.grid")}>
        {c.order.map((tile: number, pos: number) => (
          <button key={pos} type="button" className="jigsaw__tile" aria-pressed={sel === pos} disabled={busy}
            aria-label={t("cr.jigsaw.tile", { n: pos + 1, ok: tile === pos ? t("cr.jigsaw.inPlace") : "" })}
            style={{ backgroundImage: `url(${c.art})`, backgroundSize: `${c.cols * 100}% ${c.rows * 100}%`,
              backgroundPosition: `${((tile % c.cols) / Math.max(1, c.cols - 1)) * 100}% ${(Math.floor(tile / c.cols) / Math.max(1, c.rows - 1)) * 100}%` }}
            onClick={() => { if (sel === null) setSel(pos); else { const a = sel; setSel(null); if (a !== pos) void play("swap", { a, b: pos }); } }} />
        ))}
      </div>
      <p className="t-meta">{t("cr.jigsaw.moves", { n: c.moves, total: n })}</p>
      <details><summary className="t-small">{t("cr.jigsaw.model")}</summary><img src={c.art} alt="" className="jigsaw__model" /></details>
    </div>
  );
}

function ItemsEditor({ labels, items, setItems, max, label, ratio = 1, base }: {
  labels: string[]; items: J[]; setItems: (v: J[]) => void; max: number; label: string; ratio?: number; base?: ReactNode;
}) {
  const [sel, setSel] = useState<number | null>(null);
  const move = (dx: number, dy: number, dr = 0) => {
    if (sel === null) return;
    setItems(items.map((o, i) => (i === sel ? { ...o, x: Math.max(0, Math.min(1, +(o.x + dx).toFixed(3))), y: Math.max(0, Math.min(1, +(o.y + dy).toFixed(3))), r: (o.r + dr + 360) % 360 } : o)));
  };
  return (
    <div className="stack stack--3">
      <svg className="drawing" viewBox={`0 0 1 ${ratio}`} role="img" aria-label={label}>
        <rect x="0" y="0" width="1" height={ratio} fill="#fff" />
        {base}
        {items.map((o, i) => (
          <g key={i} onClick={() => setSel(i)} style={{ cursor: "pointer" }}>
            <Placed label={labels[o.s]} x={o.x} y={o.y * ratio} r={o.r} size={0.2} />
            {sel === i && <rect x={o.x - 0.11} y={o.y * ratio - 0.11} width="0.22" height="0.22" fill="none" stroke="#F17868" strokeWidth="0.006" />}
          </g>
        ))}
      </svg>
      {sel !== null && items[sel] && (
        <div className="pad-keys" aria-label={labels[items[sel].s]}>
          <button type="button" className="key" onClick={() => move(0, -0.05)} aria-label={t("cr.up")}>↑</button>
          <button type="button" className="key" onClick={() => move(-0.05, 0)} aria-label={t("cr.left")}>←</button>
          <button type="button" className="key" onClick={() => move(0.05, 0)} aria-label={t("cr.right")}>→</button>
          <button type="button" className="key" onClick={() => move(0, 0.05)} aria-label={t("cr.down")}>↓</button>
          <button type="button" className="key key--wide" onClick={() => move(0, 0, 15)}>{t("cr.rotate15")}</button>
          <button type="button" className="key key--wide" onClick={() => { setItems(items.filter((_, i) => i !== sel)); setSel(null); }}>{t("cr.remove")}</button>
        </div>
      )}
      <p className="t-meta">{t("cr.items.count", { n: items.length, max })}</p>
      <div className="sticker-pick">
        {labels.map((l, k) => (
          <button key={k} type="button" className="sticker-btn" disabled={items.length >= max} aria-label={t("cr.items.add", { l })}
            onClick={() => { setItems([...items, { s: k, x: 0.5, y: 0.5, r: 0 }]); setSel(items.length); }}>
            <img src={elementSrc(l)} alt="" width={36} height={36} /><span className="t-meta">{l}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

function Portrait({ c, me, partner, play, busy }: CV) {
  const [items, setItems] = useState<J[]>([]);
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  return (
    <div className="stack stack--4">
      <ItemsEditor labels={c.stickers} items={items} setItems={setItems} max={c.max} label={t("cr.portrait.canvas")}
        base={<ellipse cx="0.5" cy="0.5" rx="0.3" ry="0.38" fill="#FFF5E8" stroke="#E8DDD6" strokeWidth="0.006" />} />
      <button className="btn" disabled={busy || !items.length} onClick={() => void play("submit", { items })}>{t("cr.portrait.submit")}</button>
    </div>
  );
}
function PortraitArt({ items, labels }: { items: J[]; labels: string[] }) {
  return <><Frame><ellipse cx="0.5" cy="0.5" rx="0.3" ry="0.38" fill="#FFF5E8" />{items.map((o, i) => <Placed key={i} label={labels[o.s]} x={o.x} y={o.y} r={o.r} size={0.2} />)}</Frame></>;
}

function Emblem({ c, me, partner, play, busy, mine }: CV) {
  const [o, setO] = useState<number | null>(null);
  const [col, setCol] = useState(0);
  return (
    <div className="stack stack--4">
      <svg className="creation creation--sm" viewBox="0 0 1 1" role="img" aria-label={t("cr.emblem.preview")}><EmblemArt c={c} /></svg>
      {mine && (
        <div className="card stack stack--3">
          <h3 className="t-card">{t("cr.emblem.yourSymbol")}</h3>
          <div className="sticker-pick">
            {c.symbols.map((l: string, k: number) => (
              <button key={k} type="button" className="sticker-btn" aria-pressed={o === k} onClick={() => setO(k)}><img src={elementSrc(l)} alt="" width={36} height={36} /><span className="t-meta">{l}</span></button>
            ))}
          </div>
          <div className="chips" role="radiogroup" aria-label={t("draw.color")}>
            {c.colors.map((p: J, k: number) => <button key={k} type="button" role="radio" aria-checked={col === k} className="swatch" style={{ background: p.hex }} aria-label={p.name} onClick={() => setCol(k)} />)}
          </div>
          <button className="btn" disabled={busy || o === null} onClick={() => void play("symbol", { o, c: col })}>{t("cr.emblem.place")}</button>
        </div>
      )}
      {!mine && !(c.slots["1"] && c.slots["2"]) && <p className="muted center">{t("board.theirTurn", { name: nameOf(partner) })}</p>}
      <fieldset>
        <legend className="t-small strong">{t("cr.emblem.support")}</legend>
        <div className="chips">{c.supports.map((s: string, k: number) => <button key={s} type="button" className="chip" aria-pressed={c.support === k} disabled={busy} onClick={() => void play("support", { k })}>{s}</button>)}</div>
      </fieldset>
      <TextSend id="emn" label={t("cr.emblem.name")} max={24} busy={busy} onSend={async (v) => (await play("name", { text: v })).ok} />
      {c.validated?.[me.seat] ? <Waiting partner={partner} /> : <button className="btn" disabled={busy} onClick={() => void play("validate")}>{t("cr.validateBoth")}</button>}
    </div>
  );
}

function Palette({ c, me, partner, play, busy, mine }: CV) {
  const [picks, setPicks] = useState<number[]>([]);
  const Sw = ({ k, onClick, pressed }: { k: number; onClick?: () => void; pressed?: boolean }) => (
    <button type="button" className="palette-chip" aria-pressed={pressed} disabled={!onClick || busy} onClick={onClick}>
      <span className="swatch swatch--sm" style={{ background: c.colors[k].hex }} aria-hidden="true" />{c.colors[k].name}
    </button>
  );
  return (
    <div className="stack stack--4">
      <p className="play-card__text">{t("cr.palette.scene", { s: c.scene })}</p>
      <PaletteArt colors={(c.phase === "pick" ? picks : c.final).map((k: number) => c.colors[k].hex)} />
      {c.phase === "pick" && (c.submitted?.[me.seat] ? <Waiting partner={partner} /> : (
        <>
          <p className="t-small">{t("cr.palette.pick", { n: picks.length })}</p>
          <div className="chips">{c.colors.map((_: J, k: number) => <Sw key={k} k={k} pressed={picks.includes(k)} onClick={() => setPicks(picks.includes(k) ? picks.filter((x) => x !== k) : picks.length < 3 ? [...picks, k] : picks)} />)}</div>
          <button className="btn" disabled={busy || picks.length !== 3} onClick={() => void play("pick", { ids: picks })}>{t("cr.palette.confirm")}</button>
        </>
      ))}
      {c.phase === "negotiate" && (
        <>
          <p className="t-small">{t("cr.palette.final", { n: c.final.length })}</p>
          <div className="chips">{c.final.map((k: number) => <Sw key={k} k={k} />)}</div>
          {c.proposal && mine && (
            <div className="card stack stack--2">
              <p>{t("cr.palette.proposed", { name: nameOf(partner) })} <strong>{c.colors[c.proposal.id].name}</strong></p>
              <div className="row"><button className="btn btn--auto" disabled={busy} onClick={() => void play("answer", { ok: true })}>{t("board.accept")}</button>
                <button className="btn btn--secondary btn--auto" disabled={busy} onClick={() => void play("answer", { ok: false })}>{t("board.refuse")}</button></div>
            </div>
          )}
          {!c.proposal && mine && (
            <>
              <p className="t-small strong">{t("cr.palette.proposeOne")}</p>
              <div className="chips">{c.colors.map((_: J, k: number) => !c.final.includes(k) && <Sw key={k} k={k} onClick={() => void play("propose", { id: k })} />)}</div>
            </>
          )}
          {!mine && <p className="muted center">{t("board.theirTurn", { name: nameOf(partner) })}</p>}
        </>
      )}
    </div>
  );
}
function PaletteArt({ colors }: { colors: string[] }) {
  const c = (i: number) => colors[i] ?? "#E8DDD6";
  return (
    <svg className="creation creation--sm" viewBox="0 0 1 0.6" role="img" aria-label={t("cr.palette.preview")}>
      <rect x="0" y="0" width="1" height="0.6" fill={c(0)} />
      <circle cx="0.75" cy="0.18" r="0.09" fill={c(1)} />
      <path d="M0 0.45 Q0.3 0.25 0.6 0.42 T1 0.4 V0.6 H0 Z" fill={c(2)} />
      <rect x="0.15" y="0.3" width="0.18" height="0.18" fill={c(3)} /><path d="M0.12 0.31 L0.24 0.2 L0.36 0.31 Z" fill={c(4)} />
    </svg>
  );
}

function Poster({ c, me, partner, play, busy, mine }: CV) {
  const [items, setItems] = useState<J[]>([]);
  const step: string = c.phase;
  return (
    <div className="stack stack--4">
      <p className="t-small"><strong>{c.event}</strong> · {t("cr.poster.constraint", { s: c.constraint })}</p>
      <svg className="creation creation--sm" viewBox="0 0 1 1.4" role="img" aria-label={t("cr.poster.preview")}><PosterArt c={{ ...c, visual: c.visual ?? (step === "visual" ? items : null) }} /></svg>
      {!mine && <p className="muted center">{t("board.theirTurn", { name: nameOf(partner) })}</p>}
      {mine && step === "title" && <TextSend id="pt" label={t("cr.poster.title")} max={40} busy={busy} onSend={async (v) => (await play("title", { text: v })).ok} />}
      {mine && step === "visual" && (
        <>
          <ItemsEditor labels={c.objects} items={items} setItems={setItems} max={5} label={t("cr.poster.visual")} />
          <button className="btn" disabled={busy || !items.length} onClick={() => void play("visual", { items })}>{t("cr.poster.sendVisual")}</button>
        </>
      )}
      {mine && step === "subtitle" && <TextSend id="ps" label={t("cr.poster.subtitle")} max={80} busy={busy} onSend={async (v) => (await play("subtitle", { text: v })).ok} />}
      {mine && step === "detail" && <TextSend id="pd" label={t("cr.poster.detail")} hint={t("cr.poster.detailHint")} max={40} busy={busy} onSend={async (v) => (await play("detail", { text: v })).ok} />}
      <p className="t-meta">{me.seat === c.a ? t("cr.poster.youA") : t("cr.poster.youB")}</p>
    </div>
  );
}

function Comic({ c, me, partner, play, busy, mine }: CV) {
  const [strokes, setStrokes] = useState<Stroke[]>([]);
  const [stickers, setStickers] = useState<J[]>([]);
  const idx = c.frames.findIndex((f: J) => f === null);
  if (c.phase === "titles") {
    return (
      <div className="stack stack--4">
        <ComicArt c={c} />
        {c.submitted?.[me.seat] ? <Waiting partner={partner} /> : <TextSend id="ct" label={t("cr.comic.title")} max={60} busy={busy} onSend={async (v) => (await play("title", { text: v })).ok} />}
      </div>
    );
  }
  return (
    <div className="stack stack--4">
      <p className="t-small"><strong>{c.subject}</strong> · {t("cr.comic.frame", { n: idx + 1 })}</p>
      <ComicArt c={c} />
      {!mine ? <p className="muted center">{t("board.theirTurn", { name: nameOf(partner) })}</p> : (
        <>
          <StrokePad strokes={strokes} label={t("cr.comic.canvas", { n: idx + 1 })} disabled={busy}
            underlay={<>{stickers.map((o, i) => <Placed key={i} label={c.stickers[o.s]} x={o.x} y={o.y} size={0.2} />)}</>}
            onStroke={(s) => setStrokes([...strokes, s])} />
          <div className="row row--wrap"><Small busy={busy || !strokes.length} icon="undo" onClick={() => setStrokes(strokes.slice(0, -1))}>{t("draw.undo")}</Small></div>
          <details>
            <summary className="t-small">{t("cr.comic.stickers", { n: stickers.length })}</summary>
            <div className="sticker-pick">
              {c.stickers.map((l: string, k: number) => (
                <button key={k} type="button" className="sticker-btn" disabled={stickers.length >= 4} onClick={() => setStickers([...stickers, { s: k, x: 0.2 + 0.2 * stickers.length, y: 0.7, r: 0 }])}>
                  <img src={elementSrc(l)} alt="" width={32} height={32} /><span className="t-meta">{l}</span>
                </button>
              ))}
            </div>
          </details>
          <button className="btn" disabled={busy || (!strokes.length && !stickers.length)} onClick={async () => { if ((await play("frame", { strokes, stickers })).ok) { setStrokes([]); setStickers([]); } }}>{t("cr.comic.send")}</button>
        </>
      )}
    </div>
  );
}
function ComicArt({ c }: { c: J }) {
  return (
    <svg className="creation" viewBox="0 0 3.2 1.1" role="img" aria-label={t("cr.comic.strip")}>
      <rect x="0" y="0" width="3.2" height="1.1" fill="#FFF9F2" />
      {c.frames.map((f: J, i: number) => (
        <g key={i} transform={`translate(${0.05 + i * 1.05} 0.05)`}>
          <rect x="0" y="0" width="1" height="1" fill="#fff" stroke="#43263E" strokeWidth="0.012" />
          {f && <>{f.stickers.map((o: J, k: number) => <Placed key={k} label={c.stickers[o.s]} x={o.x} y={o.y} size={0.2} />)}<Strokes strokes={f.strokes} /></>}
        </g>
      ))}
    </svg>
  );
}

function Tiles({ c, me, partner, play, busy, mine }: CV) {
  const [h, setH] = useState<number | null>(null);
  const hand: string[] = c.hands[me.seat];
  return (
    <div className="stack stack--4">
      <p className="t-small">{t("cr.tiles.count", { n: c.placed, max: c.max })} · {c.goal ? t("cr.tiles.goalOk") : t("cr.tiles.goal")}</p>
      <div className="tile-grid" role="grid" aria-label={t("cr.tiles.grid")}>
        {c.grid.map((v: string | null, i: number) => (
          <button key={i} type="button" role="gridcell" className="tile" disabled={busy || !mine || v !== null || h === null}
            aria-label={v ? t("cr.tiles.cellFull", { v, r: Math.floor(i / 5) + 1, c: (i % 5) + 1 }) : t("cr.tiles.cellEmpty", { r: Math.floor(i / 5) + 1, c: (i % 5) + 1 })}
            onClick={async () => { if (h !== null && (await play("place", { h, i })).ok) setH(null); }}>
            {v && <img src={elementSrc(v)} alt="" />}
          </button>
        ))}
      </div>
      {mine ? (
        <>
          <p className="t-small strong">{t("cr.tiles.hand")}</p>
          <div className="row row--wrap">
            {hand.map((v, k) => <button key={k} type="button" className="sticker-btn" aria-pressed={h === k} onClick={() => setH(k)}><img src={elementSrc(v)} alt="" width={40} height={40} /><span className="t-meta">{v}</span></button>)}
          </div>
          <p className="t-meta">{t("cr.tiles.rule")}</p>
          <Small busy={busy} icon="refresh" onClick={() => void play("swap")}>{t("cr.tiles.swap")}</Small>
        </>
      ) : <p className="muted center">{t("board.theirTurn", { name: nameOf(partner) })}</p>}
    </div>
  );
}

function playNotes(notes: number[], bpm: number) {
  const Ctx = (window.AudioContext || (window as J).webkitAudioContext) as typeof AudioContext | undefined;
  if (!Ctx) return;
  const ctx = new Ctx();
  const step = 60 / bpm;
  notes.forEach((n, i) => {
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = "sine"; o.frequency.value = 440 * Math.pow(2, (n - 69) / 12);
    g.gain.setValueAtTime(0.0001, ctx.currentTime + i * step);
    g.gain.exponentialRampToValueAtTime(0.25, ctx.currentTime + i * step + 0.02);
    g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + i * step + step * 0.9);
    o.connect(g).connect(ctx.destination); o.start(ctx.currentTime + i * step); o.stop(ctx.currentTime + (i + 1) * step);
  });
  setTimeout(() => void ctx.close(), (notes.length + 1) * step * 1000);
}

function Constellation({ c, me, partner, play, busy, mine }: CV) {
  const notes = c.seq.map((k: number) => c.stars[k].note);
  return (
    <div className="stack stack--4">
      <div className="star-field" role="group" aria-label={t("cr.stars.field")}>
        {[...Array(25)].map((_, cell) => {
          const k = c.stars.findIndex((s: J) => s.cell === cell);
          return k < 0 ? <span key={cell} className="star-cell" /> : (
            <button key={cell} type="button" className="star-cell star" disabled={busy || !mine || c.phase !== "compose"} onClick={() => void play("note", { k })}
              aria-label={t("cr.stars.star", { n: NOTE_NAMES[c.stars[k].note] ?? "" })}>
              <span aria-hidden="true">★</span><span className="t-meta">{NOTE_NAMES[c.stars[k].note]}</span>
            </button>
          );
        })}
      </div>
      <p className="t-small">{t("cr.stars.seq", { n: c.seq.length, max: c.steps })} {notes.map((n: number) => NOTE_NAMES[n]).join(" · ")}</p>
      <Small busy={!notes.length} onClick={() => playNotes(notes, c.bpm)}>{t("cr.stars.listen")}</Small>
      {c.phase === "compose" && !mine && <p className="muted center">{t("board.theirTurn", { name: nameOf(partner) })}</p>}
      {c.phase === "name" && (c.names?.[me.seat] ? <Waiting partner={partner} /> : <TextSend id="sn" label={t("cr.stars.name")} max={40} busy={busy} onSend={async (v) => (await play("name", { text: v })).ok} />)}
    </div>
  );
}

function usePlayer(count: number) {
  const reduce = typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  const [frame, setFrame] = useState(0);
  const [playing, setPlaying] = useState(false);
  const timer = useRef<number | null>(null);
  useEffect(() => {
    if (!playing) return;
    timer.current = window.setInterval(() => setFrame((f) => (f + 1) % count), 250);
    const stop = window.setTimeout(() => setPlaying(false), 250 * count * 3);
    return () => { if (timer.current) window.clearInterval(timer.current); window.clearTimeout(stop); };
  }, [playing, count]);
  return { frame, setFrame, playing, setPlaying, reduce };
}

function Flipbook({ c, me, partner, play, busy }: CV) {
  const p = usePlayer(8);
  const [edit, setEdit] = useState<number | null>(null);
  const [objs, setObjs] = useState<J[]>([]);
  const [strokes, setStrokes] = useState<Stroke[]>([]);
  const all = c.frames.every((f: J) => f);
  const open = (i: number) => {
    const f = c.frames[i] ?? c.frames[i - 1];
    setObjs(f?.objs ?? [{ s: 0, x: 0.3, y: 0.5, r: 0 }, { s: 1, x: 0.7, y: 0.5, r: 0 }]);
    setStrokes(c.frames[i]?.strokes ?? []);
    setEdit(i);
  };
  if (edit !== null) {
    return (
      <div className="stack stack--4">
        <h3 className="t-card">{t("cr.flip.editing", { n: edit + 1 })}</h3>
        <ItemsEditor labels={c.objects} items={objs} setItems={(v) => setObjs(v.slice(0, 2))} max={2} label={t("cr.flip.frame", { n: edit + 1 })}
          base={<>{edit > 0 && <FlipFrame c={c} i={edit - 1} opacity={0.2} />}<Strokes strokes={strokes} /></>} />
        <StrokePad strokes={strokes} label={t("cr.flip.strokes")} disabled={strokes.length >= 3}
          underlay={<>{objs.map((o, k) => <Placed key={k} label={c.objects[o.s]} x={o.x} y={o.y} r={o.r} size={0.22} />)}</>}
          onStroke={(s) => setStrokes([...strokes, s].slice(0, 3))} />
        <p className="t-meta">{t("cr.strokesOf", { n: strokes.length, max: 3 })}</p>
        <div className="row row--wrap">
          <Small busy={!strokes.length} icon="undo" onClick={() => setStrokes(strokes.slice(0, -1))}>{t("draw.undo")}</Small>
          <button className="btn btn--auto" disabled={busy || objs.length !== 2} onClick={async () => { if ((await play("frame", { i: edit, objs, strokes })).ok) setEdit(null); }}>{t("cr.flip.save")}</button>
          <Small busy={false} onClick={() => setEdit(null)}>{t("common.cancel")}</Small>
        </div>
      </div>
    );
  }
  return (
    <div className="stack stack--4">
      <p className="t-small"><strong>{c.scene}</strong></p>
      <svg className="creation creation--sm" viewBox="0 0 1 1" role="img" aria-label={t("cr.flip.frame", { n: p.frame + 1 })}>
        <Frame>{p.frame > 0 && <FlipFrame c={c} i={p.frame - 1} opacity={0.2} />}<FlipFrame c={c} i={p.frame} /></Frame>
      </svg>
      <div className="row row--wrap">
        <Small busy={false} onClick={() => p.setFrame((p.frame + 7) % 8)}>{t("cr.flip.prev")}</Small>
        {!p.reduce && <Small busy={false} onClick={() => p.setPlaying(!p.playing)}>{p.playing ? t("cr.flip.pause") : t("cr.flip.play")}</Small>}
        <Small busy={false} onClick={() => p.setFrame((p.frame + 1) % 8)}>{t("cr.flip.next")}</Small>
      </div>
      <div className="flip-strip">
        {c.frames.map((f: J, i: number) => (
          <button key={i} type="button" className="flip-thumb" aria-pressed={p.frame === i}
            onClick={() => (c.owners[i] === me.seat ? open(i) : p.setFrame(i))}
            aria-label={t("cr.flip.thumb", { n: i + 1, who: c.owners[i] === me.seat ? t("game.you") : nameOf(partner), state: f ? t("cr.flip.done") : t("cr.flip.todo") })}>
            <svg viewBox="0 0 1 1" aria-hidden="true"><Frame><FlipFrame c={c} i={i} /></Frame></svg>
            <span className="t-meta">{i + 1}{c.owners[i] === me.seat ? " ✎" : ""}</span>
          </button>
        ))}
      </div>
      <p className="t-meta">{t("cr.flip.hint")}</p>
      {all && (c.validated?.[me.seat] ? <Waiting partner={partner} /> : <button className="btn" disabled={busy} onClick={() => void play("validate")}>{t("cr.validateBoth")}</button>)}
    </div>
  );
}

function Weaving({ c, me, partner, play, busy }: CV) {
  const vertical = c.a === me.seat;
  const [k, setK] = useState(0);
  const mineColors: (number | null)[] = vertical ? c.vcolors : c.hcolors;
  const done = c.vcolors.every((x: J) => x !== null) && c.hcolors.every((x: J) => x !== null);
  return (
    <div className="stack stack--4">
      <div className="row row--wrap">
        <svg className="mini" viewBox="0 0 1 1" role="img" aria-label={t("cr.weave.model")}><WeaveArt c={c} show="model" /></svg>
        <p className="t-small">{vertical ? t("cr.weave.youV") : t("cr.weave.youH")}</p>
      </div>
      <fieldset>
        <legend className="t-small strong">{vertical ? t("cr.weave.vThreads") : t("cr.weave.hThreads")}</legend>
        <div className="chips">{mineColors.map((v, i) => <button key={i} type="button" className="chip" aria-pressed={k === i} onClick={() => setK(i)}>
          {i + 1}{v !== null && <span className="swatch swatch--sm" style={{ background: c.palette[v].hex }} aria-hidden="true" />}</button>)}</div>
        <div className="chips">{c.palette.map((p: J, ci: number) => <button key={ci} type="button" className="palette-chip" disabled={busy}
          onClick={() => void play(vertical ? "vcolor" : "hcolor", { k, c: ci })}><span className="swatch swatch--sm" style={{ background: p.hex }} aria-hidden="true" />{p.name}</button>)}</div>
      </fieldset>
      <div className="weave-grid" role="grid" aria-label={t("cr.weave.grid")}>
        {c.mask.map((m: number, i: number) => {
          const minePart = (i % 6 < 3) === vertical;
          return (
            <button key={i} type="button" role="gridcell" className="weave-cell" disabled={busy || !minePart} onClick={() => void play("toggle", { i })}
              aria-label={t("cr.weave.cell", { r: Math.floor(i / 6) + 1, c: (i % 6) + 1, v: m ? t("cr.weave.over") : t("cr.weave.under") })}
              style={{ background: m ? (c.vcolors[i % 6] !== null ? c.palette[c.vcolors[i % 6]].hex : "#E8DDD6") : (c.hcolors[Math.floor(i / 6)] !== null ? c.palette[c.hcolors[Math.floor(i / 6)]].hex : "#E8DDD6") }}>
              <span aria-hidden="true">{m ? "│" : "─"}</span>
            </button>
          );
        })}
      </div>
      <p className="t-meta">{t("cr.weave.hint")}</p>
      <TextSend id="wt" label={t("cr.weave.title")} max={40} busy={busy} onSend={async (v) => (await play("title", { text: v })).ok} />
      {c.title && <p className="t-small">{t("cr.titleIs", { s: c.title })}</p>}
      {done && c.title && (c.validated?.[me.seat] ? <Waiting partner={partner} /> : <button className="btn" disabled={busy} onClick={() => void play("validate")}>{t("cr.validateBoth")}</button>)}
    </div>
  );
}

export const CREATION_VIEWS: Record<string, ComponentType<CV>> = {
  draw_guess: DrawGuess, stroke_budget: DrawGuess, complete_doodle: Doodle, mirror_draw: Doodle, draw_dictation: Dictation,
  exquisite_drawing: Exquisite, pixel_art: Pixel, tangram: Tangram, jigsaw: Jigsaw, sticker_portrait: Portrait, emblem: Emblem,
  palette: Palette, poster: Poster, silent_comic: Comic, tile_scene: Tiles, constellation: Constellation, flipbook: Flipbook, weaving: Weaving,
};

// ---------------------------------------------------------------------------
// Fin de manche : la création (exportable) ou le résultat
// ---------------------------------------------------------------------------
export function CreationSolution({ c, s, players, title }: { c: J; s: J; players: Player[]; title: string }) {
  const names = (o?: Record<string, string>) => players.map((p) => `${nameOf(p)} : « ${o?.[p.seat] ?? "—"} »`).join(" · ");
  const exp = (node: ReactNode, viewBox = "0 0 1 1", label = title) => <Exportable name={title} viewBox={viewBox} label={label}>{node}</Exportable>;
  switch (c.mech) {
    case "draw_guess": case "stroke_budget":
      return <div className="stack stack--2"><p>{t("board.sol.word", { w: s?.target ?? "" })}</p><DrawingView strokes={c.strokes} label={t("cr.draw.canvas")} /></div>;
    case "complete_doodle": return <div className="stack stack--2">{exp(<Frame><Strokes strokes={c.starter ?? []} gray /><Strokes strokes={c.strokes} /></Frame>)}<p>{names(c.titles)}</p></div>;
    case "mirror_draw": return <div className="stack stack--2">{exp(<Frame><Strokes strokes={c.strokes} mirror /></Frame>)}<p>{names(c.names)}</p></div>;
    case "draw_dictation": return (
      <div className="stack stack--2">
        <p>{t("cr.dict.score", { n: c.score ?? 0, k: c.k })}</p>
        <div className="row row--wrap side-by-side">
          <GeoGrid shapes={s?.model ?? []} label={t("cr.dict.model")} />
          <GeoGrid shapes={c.placed} label={t("cr.dict.yourGrid")} color="#F17868" />
        </div>
      </div>
    );
    case "exquisite_drawing": return (
      <div className="stack stack--2">
        {exp(<><rect x="0" y="0" width="1" height="1.5" fill="#fff" />{(c.bands ?? []).map((b: Stroke[], i: number) => <g key={i} transform={`translate(0 ${i * 0.5})`}><Strokes strokes={b ?? []} /></g>)}</>, "0 0 1 1.5")}
        <p>{names(c.names)}</p>
      </div>
    );
    case "pixel_art": return <div className="stack stack--2">{exp(<PixelArt cells={c.cells} />)}<p>{t("cr.pixel.score", { n: c.score ?? 0 })}</p></div>;
    case "tangram": return <p>{t("cr.tangram.solved", { n: c.moves })}</p>;
    case "jigsaw": return <div className="stack stack--2"><img src={c.art} alt={t("cr.jigsaw.model")} className="jigsaw__model" /><p>{t("cr.jigsaw.done", { n: c.moves })}</p></div>;
    case "sticker_portrait": return (
      <div className="row row--wrap side-by-side">
        {players.map((p) => <div key={p.seat} className="stack stack--2"><span className="t-meta">{nameOf(p)}</span>{exp(<PortraitArt items={c.portraits?.[p.seat] ?? []} labels={c.stickers} />, "0 0 1 1", t("cr.portrait.of", { name: nameOf(p) }))}</div>)}
      </div>
    );
    case "emblem": return exp(<EmblemArt c={c} />);
    case "palette": return <div className="stack stack--2"><p>{c.final.map((k: number) => c.colors[k].name).join(", ")}</p>{exp(<g><rect x="0" y="0" width="1" height="1" fill="#fff" />{c.final.map((k: number, i: number) => <rect key={k} x={i / 5} y="0" width={1 / 5} height="1" fill={c.colors[k].hex} />)}</g>, "0 0 1 1", c.final.map((k: number) => c.colors[k].name).join(", "))}</div>;
    case "poster": return exp(<PosterArt c={c} />, "0 0 1 1.4");
    case "silent_comic": return <div className="stack stack--2">{exp(<g>{c.frames.map((f: J, i: number) => <g key={i} transform={`translate(${0.05 + i * 1.05} 0.05)`}><rect x="0" y="0" width="1" height="1" fill="#fff" stroke="#43263E" strokeWidth="0.012" />{f && <>{f.stickers.map((o: J, k: number) => <Placed key={k} label={c.stickers[o.s]} x={o.x} y={o.y} size={0.2} />)}<Strokes strokes={f.strokes} /></>}</g>)}</g>, "0 0 3.2 1.1")}<p>{names(c.titles)}</p></div>;
    case "tile_scene": return <div className="stack stack--2">{exp(<TileArt grid={c.grid} />)}<p>{c.goal ? t("cr.tiles.goalOk") : t("cr.tiles.goalMissed")}</p></div>;
    case "constellation": return <div className="stack stack--2">{exp(<StarsArt c={c} />)}<p>{names(c.names)}</p><Small busy={false} onClick={() => playNotes(c.seq.map((k: number) => c.stars[k].note), c.bpm)}>{t("cr.stars.listen")}</Small></div>;
    case "flipbook": return exp(<g><rect x="0" y="0" width="4" height="2" fill="#FFF9F2" />{c.frames.map((_: J, i: number) => <g key={i} transform={`translate(${(i % 4) + 0.03} ${Math.floor(i / 4) + 0.03}) scale(0.94)`}><Frame><FlipFrame c={c} i={i} /></Frame><text x="0.05" y="0.12" fontSize="0.08" fill="#663C59" fontFamily="sans-serif">{i + 1}</text></g>)}</g>, "0 0 4 2", t("cr.flip.sheet"));
    case "weaving": return <div className="stack stack--2">{exp(<WeaveArt c={c} />)}<p>{t("cr.weave.result", { n: c.matches ?? 0, s: c.title ?? "" })}</p></div>;
    default: return null;
  }
}

export const isCreationMech = (m: string) => m in CREATION_VIEWS;
