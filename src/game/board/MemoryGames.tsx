/* eslint-disable @typescript-eslint/no-explicit-any */
// Famille 4 « Mémoire et observation » : écrans de jeu et récapitulatifs.
// Ce qu'il faut mémoriser n'arrive que dans la part privée (priv.view) ; à la fin de l'observation, l'écran envoie
// « seen » et le serveur le retire. Les réponses sont notées sur le serveur ; l'écran ne fait qu'afficher.
import { useEffect, useRef, useState, type ComponentType, type ReactNode } from "react";
import { t } from "../../i18n";
import { Icon } from "../../components/ui";
import type { Player } from "../../lib/types";
import { elementSrc } from "./creation";

type J = any;
type Play = (type: string, payload?: Record<string, unknown>) => Promise<{ ok: boolean; info?: J }>;
export interface MV { c: J; priv: J; me: Player; partner?: Player; play: Play; busy: boolean; mine: boolean }

const nameOf = (p?: Player) => (p ? (p.is_me ? t("game.you") : p.display_name || "?") : "?");
const reduceMotion = () => typeof window !== "undefined" && Boolean(window.matchMedia?.("(prefers-reduced-motion: reduce)").matches);
const Waiting = ({ partner }: { partner?: Player }) => <p className="center muted">{t("board.waitingOther", { name: nameOf(partner) })}</p>;
const kitSrc = (slug: string) => `/assets/jeux/elements/${slug}.svg`;

export const Obj = ({ label, src, className = "" }: { label: string; src?: string; className?: string }) =>
  <img className={`obj ${className}`} src={src ?? elementSrc(label)} alt={label} draggable={false} />;

/** Observation chronométrée : à la fin (ou sur « J'ai mémorisé »), le coup « seen » retire ce qu'il fallait retenir. */
function Observe({ seconds, play, busy, children, label = t("mem.memorize") }: { seconds: number; play: Play; busy: boolean; children: ReactNode; label?: string }) {
  const [left, setLeft] = useState(seconds);
  const sent = useRef(false);
  const done = () => { if (!sent.current) { sent.current = true; void play("seen"); } };
  useEffect(() => {
    const t0 = Date.now();
    const id = window.setInterval(() => {
      const l = Math.max(0, seconds - Math.floor((Date.now() - t0) / 1000));
      setLeft(l);
      if (l <= 0) { window.clearInterval(id); done(); }
    }, 250);
    return () => window.clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [seconds]);
  return (
    <div className="stack stack--3">
      <p className="board-turn board-turn--me" aria-live="polite"><Icon name="eye" size={18} />{label} · {t("mem.secondsLeft", { n: left })}</p>
      {children}
      <button type="button" className="btn btn--secondary" disabled={busy} onClick={done}>{t("mem.memorized")}</button>
    </div>
  );
}

/** Grille de cases (n × n ou lignes × colonnes) ; render(i) donne le contenu de la case i. */
function Cells({ cols, count, render, onTap, label, disabled, selected }: {
  cols: number; count: number; render: (i: number) => ReactNode; onTap?: (i: number) => void; label: string; disabled?: boolean; selected?: (i: number) => boolean;
}) {
  return (
    <div className="cell-grid" style={{ gridTemplateColumns: `repeat(${cols}, 1fr)` }} role="group" aria-label={label}>
      {[...Array(count)].map((_, i) => onTap ? (
        <button key={i} type="button" className={`cell ${selected?.(i) ? "cell--sel" : ""}`} disabled={disabled} onClick={() => onTap(i)}
          aria-label={t("mem.cell", { n: i + 1 })}>{render(i)}</button>
      ) : <span key={i} className="cell">{render(i)}</span>)}
    </div>
  );
}

/** Placement d'objets sur une grille : choisir un objet, puis sa case. Les positions sont gardées localement. */
function Placer({ objects, labels, cols, count, value, onChange, disabled }: {
  objects: string[]; labels?: string[]; cols: number; count: number; value: (number | null)[]; onChange: (v: (number | null)[]) => void; disabled?: boolean;
}) {
  const [sel, setSel] = useState<number | null>(null);
  const name = (k: number) => labels?.[k] ?? objects[k];
  const src = (k: number) => (labels ? kitSrc(objects[k]) : undefined);
  return (
    <div className="stack stack--3">
      <div className="chips" role="radiogroup" aria-label={t("mem.pickObject")}>
        {objects.map((_, k) => (
          <button key={k} type="button" role="radio" aria-checked={sel === k} className={`obj-chip ${value[k] != null ? "obj-chip--placed" : ""}`}
            disabled={disabled} onClick={() => setSel(sel === k ? null : k)} aria-label={name(k)}>
            <Obj label={name(k)} src={src(k)} />
          </button>
        ))}
      </div>
      <Cells cols={cols} count={count} label={t("mem.grid")} disabled={disabled}
        selected={(i) => sel != null && value[sel] === i}
        render={(i) => { const k = value.findIndex((v) => v === i); return k >= 0 ? <Obj label={name(k)} src={src(k)} /> : null; }}
        onTap={(i) => {
          const k = value.findIndex((v) => v === i);
          if (sel == null) { if (k >= 0) setSel(k); return; }
          const next = value.map((v, j) => (j === sel ? i : v === i ? null : v));
          onChange(next); setSel(null);
        }} />
      <p className="t-meta">{t("mem.placeHint")}</p>
    </div>
  );
}

function Confirm({ busy, disabled, onClick, children = t("mem.confirm") }: { busy: boolean; disabled?: boolean; onClick: () => void; children?: ReactNode }) {
  return <button type="button" className="btn" disabled={busy || disabled} onClick={onClick}><Icon name="check" size={18} />{children}</button>;
}

// ---------------------------------------------------------------------------
// Les 18 activités
// ---------------------------------------------------------------------------
function Pairs({ c, me, partner, play, busy, mine }: MV) {
  // Paire ratée : affichée 1,2 s sur cet écran, même si le serveur l'a déjà retournée.
  const [shown, setShown] = useState<Record<number, string>>({});
  const seenMiss = useRef<string>(JSON.stringify(c.miss ?? {}));
  useEffect(() => {
    const key = JSON.stringify(c.miss ?? {});
    if (key === seenMiss.current) return;
    const before = JSON.parse(seenMiss.current);
    seenMiss.current = key;
    const add: Record<number, string> = {};
    for (const [seat, m] of Object.entries<J>(c.miss ?? {})) {
      if (before[seat]?.at === m.at) continue;
      m.cards.forEach((k: number, j: number) => { add[k] = m.faces[j]; });
    }
    setShown(add);
    const id = window.setTimeout(() => setShown({}), 1200);
    return () => window.clearTimeout(id);
  }, [c.miss]);
  const waiting = Object.keys(shown).length > 0;
  return (
    <div className="stack stack--3">
      <p className="t-small">{nameOf(me)} : {c.scores?.[me.seat] ?? 0} · {nameOf(partner)} : {c.scores?.[partner?.seat ?? 0] ?? 0}</p>
      <div className="mem-grid" style={{ gridTemplateColumns: `repeat(${c.cols ?? 4}, 1fr)` }} role="group" aria-label={t("mem.pairs.grid")}>
        {[...Array(c.n)].map((_, i) => {
          const face = c.faces?.[i] ?? shown[i];
          const matched = c.matched?.[i] != null;
          return (
            <button key={i} type="button" className={`mem-card ${face ? "mem-card--face" : ""} ${matched ? "mem-card--matched" : ""} ${shown[i] ? "mem-card--miss" : ""}`}
              disabled={busy || !mine || waiting || matched || Boolean(c.faces?.[i])} onClick={() => void play("flip", { i })}
              aria-label={face ? `${face}${matched ? ` · ${t("mem.pairs.found")}` : ""}` : t("mem.pairs.hidden", { n: i + 1 })}>
              {face ? <Obj label={face} /> : <span aria-hidden="true">?</span>}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function Change({ c, priv, me, partner, play, busy }: MV) {
  const [mask, setMask] = useState(true);
  const seen = c.seen?.[me.seat];
  useEffect(() => { if (!seen) return; const id = window.setTimeout(() => setMask(false), 2000); return () => window.clearTimeout(id); }, [seen]);
  const n = c.rows * c.cols;
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  if (!seen) return (
    <Observe seconds={c.exposure ?? 12} play={play} busy={busy}>
      <Cells cols={c.cols} count={n} label={t("mem.grid")} render={(i) => priv?.view?.objects?.[i] ? <Obj label={priv.view.objects[i]} /> : null} />
    </Observe>
  );
  if (mask) return <div className="cell-mask" role="img" aria-label={t("mem.change.mask")}><p>{t("mem.change.mask")}</p></div>;
  return (
    <div className="stack stack--3">
      <p className="strong">{t("mem.change.ask")}</p>
      <Cells cols={c.cols} count={n} label={t("mem.grid")} disabled={busy} onTap={(cell) => void play("answer", { cell })}
        render={(i) => priv?.after?.[i] ? <Obj label={priv.after[i]} /> : null} />
    </div>
  );
}

const DIFF_STYLE: Record<string, React.CSSProperties> = {
  rotation: { transform: "rotate(45deg)" }, couleur: { filter: "hue-rotate(150deg) saturate(1.6)" },
  taille: { transform: "scale(0.62)" }, absence: { visibility: "hidden" }, reflet: { transform: "scaleX(-1)" },
};

function Differences({ c, me, partner, play, busy }: MV) {
  const change = (i: number) => c.changes.find((x: J) => x.index === i);
  const found = (i: number) => c.found.find((f: J) => f.i === i);
  return (
    <div className="stack stack--3">
      <p className="t-small">{t("mem.diff.count", { n: c.found.length, total: c.changes.length })} · {nameOf(me)} : {c.scores?.[me.seat] ?? 0} · {nameOf(partner)} : {c.scores?.[partner?.seat ?? 0] ?? 0}</p>
      <div className="diff-views">
        <section className="stack stack--2">
          <h3 className="t-meta">{t("mem.diff.original")}</h3>
          <Cells cols={4} count={c.objects.length} label={t("mem.diff.original")} render={(i) => <Obj label={c.objects[i]} />} />
        </section>
        <section className="stack stack--2">
          <h3 className="t-meta">{t("mem.diff.changed")}</h3>
          <Cells cols={4} count={c.objects.length} label={t("mem.diff.changed")} disabled={busy}
            selected={(i) => Boolean(found(i))}
            onTap={(i) => { if (!found(i)) void play("tap", { i }); }}
            render={(i) => (
              <span className="diff-cell">
                <span style={DIFF_STYLE[change(i)?.property] ?? undefined}><Obj label={c.objects[i]} /></span>
                {found(i) && <span className="diff-pin" aria-label={t("mem.diff.foundBy", { name: found(i).seat === me.seat ? nameOf(me) : nameOf(partner) })}>✓</span>}
              </span>
            )} />
        </section>
      </div>
      <p className="t-meta">{t("mem.diff.errors", { n: c.errors?.[me.seat] ?? 0 })}</p>
    </div>
  );
}

function Zoom({ c, me, partner, play, busy }: MV) {
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  const lv = c.levels?.[me.seat] ?? 1;
  const w = lv === 1 ? 25 : lv === 2 ? 50 : 100;
  const clamp = (v: number) => Math.min(100 - w, Math.max(0, v * 100 - w / 2));
  return (
    <div className="stack stack--4">
      <svg className="zoom" viewBox={`${clamp(c.focus[0])} ${clamp(c.focus[1])} ${w} ${w}`} role="img" aria-label={t("mem.zoom.detail", { n: lv })}>
        <rect x="0" y="0" width="100" height="100" fill="#fff" />
        <image href={c.image} x="0" y="0" width="100" height="100" preserveAspectRatio="xMidYMid meet" />
      </svg>
      <p className="t-meta">{t("mem.zoom.level", { n: lv, p: 4 - lv })}</p>
      <div className="stack stack--2">
        {c.choices.map((w: string, i: number) => <button key={w} className="btn btn--secondary" disabled={busy} onClick={() => void play("answer", { i })}>{w}</button>)}
      </div>
      {lv < 3 && <button type="button" className="btn btn--quiet btn--auto btn--sm" disabled={busy} onClick={() => void play("zoom")}><Icon name="search" size={18} />{t("mem.zoom.wider")}</button>}
    </div>
  );
}

const TILE = (item: string) => { const k = item.lastIndexOf("-"); return { label: item.slice(0, k), color: item.slice(k + 1) }; };

function Search({ c, me, partner, play, busy }: MV) {
  const target = TILE(c.target);
  if (c.found?.[me.seat]) return <div className="stack stack--2"><p className="center strong">{t("mem.search.found")}</p><Waiting partner={partner} /></div>;
  return (
    <div className="stack stack--3">
      <div className="row row--center">
        <span className="t-meta">{t("mem.search.target")}</span>
        <span className={`search-tile search-tile--${target.color}`} role="img" aria-label={`${target.label} ${target.color}`}><Obj label={target.label} /></span>
      </div>
      <div className="search-grid" role="group" aria-label={t("mem.grid")}>
        {c.items.map((it: string, i: number) => {
          const x = TILE(it);
          return (
            <button key={i} type="button" className={`search-tile search-tile--${x.color}`} disabled={busy} onClick={() => void play("tap", { i })} aria-label={`${x.label} ${x.color}`}>
              <Obj label={x.label} />
            </button>
          );
        })}
      </div>
      <p className="t-meta">{t("mem.diff.errors", { n: c.errors?.[me.seat] ?? 0 })}</p>
    </div>
  );
}

function Recall({ c, priv, me, partner, play, busy }: MV) {
  const [pick, setPick] = useState<number[]>([]);
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  if (!c.seen?.[me.seat]) return (
    <Observe seconds={c.exposure ?? 15} play={play} busy={busy}>
      <div className="obj-row">{(priv?.view?.targets ?? []).map((x: string) => <Obj key={x} label={x} />)}</div>
    </Observe>
  );
  return (
    <div className="stack stack--3">
      <p className="strong">{t("mem.recall.ask", { n: c.count })}</p>
      <div className="search-grid search-grid--4" role="group" aria-label={t("mem.recall.choices")}>
        {c.choices.map((x: string, i: number) => (
          <button key={x} type="button" className={`search-tile ${pick.includes(i) ? "search-tile--on" : ""}`} aria-pressed={pick.includes(i)} disabled={busy}
            onClick={() => setPick(pick.includes(i) ? pick.filter((k) => k !== i) : pick.length < c.count ? [...pick, i] : pick)} aria-label={x}>
            <Obj label={x} />
          </button>
        ))}
      </div>
      <p className="t-meta">{t("mem.recall.picked", { n: pick.length, total: c.count })}</p>
      <Confirm busy={busy} disabled={pick.length !== c.count} onClick={() => void play("answer", { items: pick })} />
    </div>
  );
}

const SIMON = [
  { shape: "circle", color: "#F17868", name: "cercle corail" }, { shape: "square", color: "#91BDD4", name: "carré bleu" },
  { shape: "triangle", color: "#A9D9C2", name: "triangle menthe" }, { shape: "diamond", color: "#F4D57A", name: "losange jaune" },
];
function Shape({ shape, color, size = 44 }: { shape: string; color: string; size?: number }) {
  const p: Record<string, ReactNode> = {
    circle: <circle cx="12" cy="12" r="9" />, square: <rect x="3.5" y="3.5" width="17" height="17" rx="2" />,
    triangle: <path d="M12 3 L21 20 L3 20 Z" />, diamond: <path d="M12 2 L22 12 L12 22 L2 12 Z" />,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true"><g fill={color} stroke="#3B2433" strokeWidth="1.2">{p[shape]}</g></svg>;
}

function tone(freq: number, ms = 300) {
  const Ctx = (window.AudioContext || (window as J).webkitAudioContext) as typeof AudioContext | undefined;
  if (!Ctx) return;
  const ctx = new Ctx(), o = ctx.createOscillator(), g = ctx.createGain();
  o.frequency.value = freq; g.gain.setValueAtTime(0.0001, ctx.currentTime);
  g.gain.exponentialRampToValueAtTime(0.2, ctx.currentTime + 0.02); g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + ms / 1000);
  o.connect(g).connect(ctx.destination); o.start(); o.stop(ctx.currentTime + ms / 1000);
  window.setTimeout(() => void ctx.close(), ms + 200);
}
const SIMON_FREQ = [330, 392, 494, 587];

function Simon({ c, priv, me, partner, play, busy }: MV) {
  const [lit, setLit] = useState<number | null>(null);
  const [entry, setEntry] = useState<number[]>([]);
  const [sound, setSound] = useState(false);
  const len = useRef<number | null>(null);
  const seq: number[] | undefined = priv?.view?.sequence;
  const observing = !c.seen?.[me.seat] && Boolean(seq);
  const showSeq = () => {
    if (!seq || reduceMotion()) return;
    seq.forEach((b, i) => {
      window.setTimeout(() => { setLit(b); if (sound) tone(SIMON_FREQ[b]); }, i * 650);
      window.setTimeout(() => setLit(null), i * 650 + 450);
    });
  };
  useEffect(() => { if (observing) { len.current = seq!.length; setEntry([]); showSeq(); } }, [observing, seq?.length]); // eslint-disable-line react-hooks/exhaustive-deps
  if (c.finished?.[me.seat]) return <div className="stack stack--2"><p className="center">{t("mem.simon.finished", { n: c.scores?.[me.seat] ?? 0 })}</p><Waiting partner={partner} /></div>;
  const press = (b: number) => {
    if (sound) tone(SIMON_FREQ[b], 200);
    const next = [...entry, b];
    setEntry(next);
    if (len.current && next.length >= len.current) { setEntry([]); void play("answer", { seq: next }); }
  };
  return (
    <div className="stack stack--3">
      <p className="t-small">{t("mem.simon.status", { l: (c.levels?.[me.seat] ?? 0) + 1, max: c.max_level, e: c.errors?.[me.seat] ?? 0 })}</p>
      <div className="simon" role="group" aria-label={t("mem.simon.buttons")}>
        {SIMON.map((b, i) => (
          <button key={i} type="button" className={`simon-btn ${lit === i ? "simon-btn--lit" : ""}`} disabled={busy || observing} onClick={() => press(i)} aria-label={b.name}>
            <Shape shape={b.shape} color={b.color} size={56} />
          </button>
        ))}
      </div>
      {observing ? (
        <div className="stack stack--2">
          {reduceMotion() && <ol className="t-small">{seq!.map((b, i) => <li key={i}>{SIMON[b].name}</li>)}</ol>}
          <div className="row">
            <button type="button" className="btn btn--quiet btn--auto btn--sm" onClick={showSeq}><Icon name="refresh" size={18} />{t("mem.simon.again")}</button>
            <label className="row t-small"><input type="checkbox" checked={sound} onChange={(e) => setSound(e.target.checked)} />{t("mem.sound")}</label>
          </div>
          <button type="button" className="btn" disabled={busy} onClick={() => void play("seen")}>{t("mem.simon.go")}</button>
        </div>
      ) : (
        <div className="stack stack--2">
          <p className="t-meta">{t("mem.simon.entered", { n: entry.length, total: len.current ?? "?" })}</p>
          {!len.current && entry.length > 0 && <Confirm busy={busy} onClick={() => { void play("answer", { seq: entry }); setEntry([]); }} />}
          {entry.length > 0 && <button type="button" className="btn btn--quiet btn--auto btn--sm" onClick={() => setEntry(entry.slice(0, -1))}><Icon name="undo" size={18} />{t("mem.undo")}</button>}
        </div>
      )}
    </div>
  );
}

function Rhythm({ c, priv, me, partner, play, busy }: MV) {
  const [beat, setBeat] = useState<number | null>(null);
  const [mask, setMask] = useState<boolean[]>(Array(c.beats).fill(false));
  const active: number[] | undefined = priv?.view?.active;
  const step = 60000 / (c.bpm || 80);
  const run = (audio: boolean) => {
    if (!active) return;
    for (let k = 0; k < c.beats * 2; k++) {
      const b = k % c.beats;
      window.setTimeout(() => { setBeat(b); if (audio && active.includes(b)) tone(b === 0 ? 660 : 520, 120); }, k * step);
    }
    window.setTimeout(() => setBeat(null), c.beats * 2 * step);
  };
  useEffect(() => { if (active && !reduceMotion()) run(false); }, [active?.join()]); // eslint-disable-line react-hooks/exhaustive-deps
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  if (!c.seen?.[me.seat]) return (
    <div className="stack stack--3">
      <p className="strong">{t("mem.rhythm.watch")}</p>
      <div className="beats" role="img" aria-label={t("mem.rhythm.pattern", { b: (active ?? []).map((b) => b + 1).join(", ") })}>
        {[...Array(c.beats)].map((_, b) => <span key={b} className={`beat ${active?.includes(b) ? "beat--on" : ""} ${beat === b ? "beat--now" : ""}`}>{b + 1}</span>)}
      </div>
      <button type="button" className="btn btn--quiet btn--auto btn--sm" onClick={() => run(true)}><Icon name="volume" size={18} />{t("mem.listen")}</button>
      <button type="button" className="btn" disabled={busy} onClick={() => void play("seen")}>{t("mem.memorized")}</button>
    </div>
  );
  return (
    <div className="stack stack--3">
      <p className="strong">{t("mem.rhythm.ask")}</p>
      <div className="beats" role="group" aria-label={t("mem.rhythm.grid")}>
        {mask.map((on, b) => (
          <button key={b} type="button" className={`beat ${on ? "beat--on" : ""}`} aria-pressed={on} disabled={busy}
            onClick={() => setMask(mask.map((x, k) => (k === b ? !x : x)))} aria-label={t("mem.rhythm.beat", { n: b + 1 })}>{b + 1}</button>
        ))}
      </div>
      <Confirm busy={busy} onClick={() => void play("answer", { mask })} />
    </div>
  );
}

function Ordered({ c, priv, me, partner, play, busy }: MV) {
  const [k, setK] = useState(0);
  const [order, setOrder] = useState<number[]>([]);
  const seq: string[] | undefined = priv?.view?.sequence;
  const observing = !c.seen?.[me.seat] && Boolean(seq);
  useEffect(() => {
    if (!observing) return;
    const id = window.setInterval(() => setK((x) => x + 1), c.exposure_ms ?? 1500);
    return () => window.clearInterval(id);
  }, [observing, c.exposure_ms]);
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  if (observing) return (
    <div className="stack stack--3 center">
      <p className="t-meta">{t("mem.order.watch", { n: Math.min(k + 1, seq!.length), total: seq!.length })}</p>
      {k < seq!.length ? <Obj key={k} label={seq![k]} className="obj--big enter" /> : <p className="strong">{t("mem.order.done")}</p>}
      <button type="button" className="btn" disabled={busy || k < seq!.length} onClick={() => void play("seen")}>{t("mem.order.rebuild")}</button>
    </div>
  );
  return (
    <div className="stack stack--3">
      <p className="strong">{t("mem.order.ask")}</p>
      <ol className="order-row" aria-label={t("mem.order.yours")}>
        {order.map((i, n) => <li key={n}><button type="button" className="obj-chip" onClick={() => setOrder(order.filter((_, m) => m !== n))} aria-label={t("mem.order.remove", { w: c.pool[i] })}><span className="t-meta">{n + 1}</span><Obj label={c.pool[i]} /></button></li>)}
      </ol>
      <div className="chips">
        {c.pool.map((x: string, i: number) => !order.includes(i) && (
          <button key={i} type="button" className="obj-chip" disabled={busy} onClick={() => setOrder([...order, i])} aria-label={x}><Obj label={x} /></button>
        ))}
      </div>
      <Confirm busy={busy} disabled={order.length !== c.pool.length} onClick={() => void play("answer", { order })} />
    </div>
  );
}

function Spatial({ c, priv, me, partner, play, busy }: MV) {
  const [cells, setCells] = useState<(number | null)[]>(c.objects.map(() => null));
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  if (!c.seen?.[me.seat]) return (
    <Observe seconds={c.exposure ?? 15} play={play} busy={busy}>
      <Cells cols={c.size} count={c.size * c.size} label={t("mem.grid")} render={(i) => priv?.view?.positions?.[i] ? <Obj label={priv.view.positions[i]} /> : null} />
    </Observe>
  );
  return (
    <div className="stack stack--3">
      <p className="strong">{t("mem.spatial.ask")}</p>
      <Placer objects={c.objects} cols={c.size} count={c.size * c.size} value={cells} onChange={setCells} disabled={busy} />
      <Confirm busy={busy} disabled={cells.some((x) => x == null)} onClick={() => void play("answer", { cells })} />
    </div>
  );
}

export function PixelGrid({ cells, onTap, label, compare }: { cells: boolean[]; onTap?: (i: number) => void; label: string; compare?: boolean[] }) {
  return (
    <div className="pix5" role="group" aria-label={label}>
      {cells.map((on, i) => {
        const cls = `pix5__cell ${on ? "pix5__cell--on" : ""} ${compare && compare[i] !== on ? "pix5__cell--diff" : ""}`;
        return onTap ? <button key={i} type="button" className={cls} aria-pressed={on} onClick={() => onTap(i)} aria-label={t("mem.cell", { n: i + 1 })} />
          : <span key={i} className={cls} />;
      })}
    </div>
  );
}
const rowsToCells = (rows: string[]) => rows.join("").split("").map((x) => x === "1");

function PixelRecall({ c, priv, me, partner, play, busy }: MV) {
  const [cells, setCells] = useState<boolean[]>(Array(25).fill(false));
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  if (!c.seen?.[me.seat]) return (
    <Observe seconds={c.exposure ?? 12} play={play} busy={busy}>
      <PixelGrid cells={rowsToCells(priv?.view?.rows ?? [])} label={t("mem.pixel.model")} />
    </Observe>
  );
  return (
    <div className="stack stack--3">
      <p className="strong">{t("mem.pixel.ask")}</p>
      <PixelGrid cells={cells} label={t("mem.pixel.yours")} onTap={(i) => setCells(cells.map((x, k) => (k === i ? !x : x)))} />
      <Confirm busy={busy} onClick={() => void play("answer", { cells })} />
    </div>
  );
}

function SortItem({ rule, item }: { rule: string; item: J }) {
  if (rule === "forme") return <span className="sort-item"><Shape shape={item === "cercle" ? "circle" : "square"} color="#C7B5E5" size={64} /><span>{item}</span></span>;
  if (rule === "couleur") return <span className="sort-item"><Shape shape="circle" color={item === "bleu" ? "#91BDD4" : "#F17868"} size={64} /><span>{item}</span></span>;
  return <span className="sort-item"><span className="sort-item__n">{item}</span></span>;
}

function Sorting({ c, me, partner, play, busy }: MV) {
  // Même cartes pour les deux, dans un ordre propre à chaque écran.
  const [order] = useState<number[]>(() => c.items.map((_: J, i: number) => i).sort(() => Math.random() - 0.5));
  const [bins, setBins] = useState<(number | null)[]>(c.items.map(() => null));
  const k = order.findIndex((i) => bins[i] == null);
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  return (
    <div className="stack stack--3">
      <p className="strong">{t("mem.sort.rule", { r: c.rule })}</p>
      <p className="t-meta">{t("mem.sort.progress", { n: bins.filter((b) => b != null).length, total: c.items.length })}</p>
      {k >= 0 ? (
        <>
          <div className="center" aria-live="polite"><SortItem rule={c.rule} item={c.items[order[k]]} /></div>
          <div className="bins">
            {c.bins.map((b: string, j: number) => <button key={b} type="button" className="btn btn--secondary" disabled={busy} onClick={() => setBins(bins.map((x, i) => (i === order[k] ? j : x)))}>{b}</button>)}
          </div>
        </>
      ) : <p className="center">{t("mem.sort.done")}</p>}
      {k !== 0 && <button type="button" className="btn btn--quiet btn--auto btn--sm" disabled={busy}
        onClick={() => { const last = [...order].reverse().find((i) => bins[i] != null); if (last != null) setBins(bins.map((x, i) => (i === last ? null : x))); }}>
        <Icon name="undo" size={18} />{t("mem.undo")}</button>}
      <Confirm busy={busy} disabled={k >= 0} onClick={() => void play("answer", { bins })} />
    </div>
  );
}

const GN_COLORS: Record<string, string> = { blue: "#91BDD4", coral: "#F17868" };
const GN_NAMES: Record<string, string> = { blue: "bleu", coral: "corail", circle: "cercle", square: "carré" };
function GoNoGo({ c, me, partner, play, busy }: MV) {
  const [k, setK] = useState(-1);
  const [slow, setSlow] = useState(false);
  const [taps, setTaps] = useState<number[]>([]);
  const sent = useRef(false);
  const n = c.stimuli.length;
  useEffect(() => {
    if (k < 0 || k >= n) return;
    const id = window.setTimeout(() => setK(k + 1), (c.interval ?? 1400) * (slow ? 1.5 : 1));
    return () => window.clearTimeout(id);
  }, [k, n, slow, c.interval]);
  useEffect(() => { if (k >= n && !sent.current) { sent.current = true; void play("answer", { taps }); } }, [k, n, taps, play]);
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  const tg = c.target;
  const s = k >= 0 && k < n ? c.stimuli[k] : null;
  return (
    <div className="stack stack--3">
      <div className="row row--center">
        <span className="strong">{t("mem.gonogo.only")}</span>
        <Shape shape={tg.shape} color={GN_COLORS[tg.color]} size={32} /><span>{GN_NAMES[tg.shape]} {GN_NAMES[tg.color]}</span>
      </div>
      {k < 0 ? (
        <div className="stack stack--2">
          <label className="row t-small"><input type="checkbox" checked={slow} onChange={(e) => setSlow(e.target.checked)} />{t("mem.gonogo.slow")}</label>
          <button type="button" className="btn" disabled={busy} onClick={() => setK(0)}><Icon name="play" size={18} />{t("mem.gonogo.start")}</button>
        </div>
      ) : s ? (
        <div className="stack stack--2 center">
          <p className="t-meta">{t("mem.gonogo.progress", { n: k + 1, total: n })}</p>
          <button type="button" className="gonogo" disabled={taps.includes(k)} onClick={() => setTaps([...taps, k])}
            aria-label={t("mem.gonogo.tap", { s: `${GN_NAMES[s.shape]} ${GN_NAMES[s.color]}` })}>
            <Shape shape={s.shape} color={GN_COLORS[s.color]} size={120} />
          </button>
        </div>
      ) : <p className="center">{t("mem.sending")}</p>}
    </div>
  );
}

function Line({ marks }: { marks: { v: number; label: string; cls?: string }[] }) {
  return (
    <div className="line-track" role="img" aria-label={marks.map((m) => `${m.label} ${m.v}`).join(" · ")}>
      {marks.map((m, i) => <span key={i} className={`line-mark ${m.cls ?? ""}`} style={{ left: `${m.v}%` }} title={m.label} />)}
    </div>
  );
}

function Precision({ c, priv, me, partner, play, busy }: MV) {
  const [v, setV] = useState(50);
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  if (!c.seen?.[me.seat]) return (
    <Observe seconds={Math.round((c.exposure_ms ?? 3000) / 1000)} play={play} busy={busy}>
      {priv?.view && <Line marks={[{ v: priv.view.target, label: t("mem.precision.mark") }]} />}
    </Observe>
  );
  return (
    <div className="stack stack--3">
      <p className="strong">{t("mem.precision.ask")}</p>
      <div className="field">
        <label className="field__label" htmlFor="prec">{t("mem.precision.cursor", { v })}</label>
        <input id="prec" className="range" type="range" min={0} max={100} step={1} value={v} onChange={(e) => setV(Number(e.target.value))} />
      </div>
      <Confirm busy={busy} onClick={() => void play("answer", { value: v })} />
    </div>
  );
}

function Split({ c, priv, me, partner, play, busy }: MV) {
  const [sel, setSel] = useState<number | null>(null);
  if (!c.seen?.[me.seat] && priv?.view) return (
    <Observe seconds={c.exposure ?? 12} play={play} busy={busy}>
      <Cells cols={c.size} count={c.size * c.size} label={t("mem.grid")}
        render={(i) => { const x = priv.view.find((p: J) => p.cell === i); return x ? <Obj label={x.o} /> : null; }} />
    </Observe>
  );
  const at = (cell: number) => Object.entries<J>(c.placed ?? {}).find(([, v]) => v === cell)?.[0];
  const all = Object.keys(c.placed ?? {}).length === c.objects.length;
  return (
    <div className="stack stack--3">
      <p className="strong">{t("mem.split.ask")}</p>
      <div className="chips" role="radiogroup" aria-label={t("mem.pickObject")}>
        {c.objects.map((x: string, k: number) => (
          <button key={k} type="button" role="radio" aria-checked={sel === k} className={`obj-chip ${c.placed?.[k] != null ? "obj-chip--placed" : ""}`}
            disabled={busy} onClick={() => setSel(sel === k ? null : k)} aria-label={x}><Obj label={x} /></button>
        ))}
      </div>
      <Cells cols={c.size} count={c.size * c.size} label={t("mem.split.board")} disabled={busy}
        selected={(i) => sel != null && c.placed?.[sel] === i}
        render={(i) => {
          const k = at(i);
          return k != null ? <Obj label={c.objects[Number(k)]} /> : c.hinted?.cell === i ? <span className="cell-ghost"><Obj label={c.hinted.o} /></span> : null;
        }}
        onTap={(cell) => {
          const k = at(cell);
          if (sel == null) { if (k != null) setSel(Number(k)); return; }
          void play("place", { o: sel, cell }); setSel(null);
        }} />
      <div className="row">
        {sel != null && c.placed?.[sel] != null && <button type="button" className="btn btn--quiet btn--auto btn--sm" disabled={busy} onClick={() => { void play("clear", { o: sel }); setSel(null); }}><Icon name="close" size={18} />{t("mem.split.clear")}</button>}
        {c.hinted == null && <button type="button" className="btn btn--quiet btn--auto btn--sm" disabled={busy} onClick={() => void play("hint")}><Icon name="bulb" size={18} />{t("mem.split.hint")}</button>}
      </div>
      {c.hinted && <p className="t-meta">{t("mem.split.hinted", { o: c.hinted.o })}</p>}
      <p className="t-small">{c.validated?.[partner?.seat ?? 0] ? t("mem.split.partnerOk", { name: nameOf(partner) }) : ""}</p>
      {c.validated?.[me.seat] ? <Waiting partner={partner} /> : <Confirm busy={busy} disabled={!all} onClick={() => void play("validate")}>{t("cr.validateBoth")}</Confirm>}
    </div>
  );
}

function Silhouette({ c, me, partner, play, busy }: MV) {
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  return (
    <div className="stack stack--3">
      <div className="shadow-box" role="img" aria-label={t("mem.shadow.label")}>
        <img className="shadow-img" src={c.shadow} alt="" draggable={false} />
        {c.hints?.[me.seat] && <img className="shadow-hint" src={c.shadow} alt="" draggable={false} />}
      </div>
      <div className="search-grid search-grid--2">
        {c.choices.map((x: string, i: number) => (
          <button key={x} type="button" className="search-tile search-tile--big" disabled={busy} onClick={() => void play("answer", { i })} aria-label={c.labels?.[i] ?? x}>
            <Obj label={c.labels?.[i] ?? x} src={kitSrc(x)} /><span className="t-small">{c.labels?.[i] ?? x}</span>
          </button>
        ))}
      </div>
      {!c.hints?.[me.seat] && <button type="button" className="btn btn--quiet btn--auto btn--sm" disabled={busy} onClick={() => void play("hint")}><Icon name="bulb" size={18} />{t("mem.shadow.hint")}</button>}
    </div>
  );
}

const PATTERNS = [
  { id: "dots", color: "#F17868" }, { id: "stripes", color: "#91BDD4" }, { id: "crosses", color: "#A9D9C2" },
];
export function LayersArt({ c, order }: { c: J; order?: number[] }) {
  const draw: number[] = order ?? c.draw;
  const pat = (name: string) => PATTERNS.findIndex((p) => p.id === name);
  return (
    <svg className="layers" viewBox="40 50 220 160" role="img" aria-label={t("mem.layers.scene")}>
      <defs>
        <pattern id="p-dots" width="12" height="12" patternUnits="userSpaceOnUse"><rect width="12" height="12" fill="#F17868" /><circle cx="6" cy="6" r="2.4" fill="#fff" /></pattern>
        <pattern id="p-stripes" width="10" height="10" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="10" height="10" fill="#91BDD4" /><rect width="4" height="10" fill="#fff" /></pattern>
        <pattern id="p-crosses" width="12" height="12" patternUnits="userSpaceOnUse"><rect width="12" height="12" fill="#A9D9C2" /><path d="M3 6h6M6 3v6" stroke="#3B2433" strokeWidth="1.4" /></pattern>
      </defs>
      {draw.map((k) => {
        const [x, y] = c.centers[k];
        return <circle key={k} cx={x} cy={y} r={c.radius} fill={`url(#p-${PATTERNS[pat(c.patterns[k])]?.id ?? "dots"})`} stroke="#3B2433" strokeWidth="2" />;
      })}
      {/* Numéros au-dessus de tout, du côté visible de chaque disque : ils ne disent rien de l'ordre. */}
      {[0, 1, 2].map((k) => {
        const [x, y] = c.centers[k];
        const cx = c.centers.reduce((a: number, p: number[]) => a + p[0], 0) / 3, cy = c.centers.reduce((a: number, p: number[]) => a + p[1], 0) / 3;
        let dx = x - cx, dy = y - cy;
        const n = Math.hypot(dx, dy);
        if (n < 5) { dx = 0; dy = 1; } else { dx /= n; dy /= n; }
        const bx = x + dx * c.radius * 0.62, by = y + dy * c.radius * 0.62;
        return (
          <g key={`n${k}`}>
            <circle cx={bx} cy={by} r="11" fill="#fff" stroke="#3B2433" strokeWidth="1.5" />
            <text x={bx} y={by + 5} textAnchor="middle" fontSize="14" fontWeight="700" fill="#3B2433">{k + 1}</text>
          </g>
        );
      })}
    </svg>
  );
}

function Layers({ c, me, partner, play, busy }: MV) {
  const [order, setOrder] = useState<number[]>([]);
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  const hint = c.hints?.[me.seat];
  return (
    <div className="stack stack--3">
      <LayersArt c={c} />
      <p className="strong">{t("mem.layers.ask")}</p>
      <ol className="order-row" aria-label={t("mem.order.yours")}>
        {order.map((k, n) => <li key={n}><button type="button" className="chip" onClick={() => setOrder(order.filter((_, m) => m !== n))}>{n === 0 ? t("mem.layers.back") : n === 2 ? t("mem.layers.front") : t("mem.layers.middle")} : {k + 1}</button></li>)}
      </ol>
      <div className="chips">
        {[0, 1, 2].map((k) => !order.includes(k) && <button key={k} type="button" className="btn btn--secondary btn--auto" disabled={busy} onClick={() => setOrder([...order, k])}>{t("mem.layers.disk", { n: k + 1 })}</button>)}
      </div>
      {hint ? <p className="t-meta">{t("mem.layers.hinted", { n: hint.id + 1 })}</p>
        : <button type="button" className="btn btn--quiet btn--auto btn--sm" disabled={busy} onClick={() => void play("hint")}><Icon name="bulb" size={18} />{t("mem.shadow.hint")}</button>}
      <Confirm busy={busy} disabled={order.length !== 3} onClick={() => void play("answer", { order })} />
    </div>
  );
}

const TURN_LABEL = (n: number) => t(n === 1 ? "mem.rot.q1" : n === 2 ? "mem.rot.q2" : "mem.rot.q3");
function Rotation({ c, me, partner, play, busy }: MV) {
  const [cells, setCells] = useState<(number | null)[]>(c.objects.map(() => null));
  if (c.submitted?.[me.seat]) return <Waiting partner={partner} />;
  return (
    <div className="stack stack--3">
      <p className="strong">{t("mem.rot.model")}</p>
      <Cells cols={3} count={9} label={t("mem.rot.model")} render={(i) => { const k = c.positions.indexOf(i); return k >= 0 ? <Obj label={c.labels?.[k] ?? c.objects[k]} src={kitSrc(c.objects[k])} /> : null; }} />
      <p className="rot-arrow" aria-label={TURN_LABEL(c.turns)}><span aria-hidden="true">↻</span> {TURN_LABEL(c.turns)}</p>
      <Placer objects={c.objects} labels={c.labels} cols={3} count={9} value={cells} onChange={setCells} disabled={busy} />
      <Confirm busy={busy} disabled={cells.some((x) => x == null)} onClick={() => void play("answer", { cells })} />
    </div>
  );
}

export const MEMORY_VIEWS: Record<string, ComponentType<MV>> = {
  memory_pairs: Pairs, change_detection: Change, differences: Differences, zoom_recognition: Zoom, visual_search: Search,
  recall_set: Recall, simon: Simon, rhythm: Rhythm, ordered_recall: Ordered, spatial_recall: Spatial, pixel_recall: PixelRecall,
  sorting: Sorting, go_nogo: GoNoGo, precision: Precision, split_memory: Split, silhouette: Silhouette, layers: Layers, rotation: Rotation,
};
export const isMemoryMech = (m: string) => m in MEMORY_VIEWS;

// ---------------------------------------------------------------------------
// Fin de manche : la bonne réponse et celles de chacun
// ---------------------------------------------------------------------------
export function MemorySolution({ c, s, players }: { c: J; s: J; players: Player[] }) {
  const ans = (p: Player) => c.answers?.[p.seat];
  const each = (f: (a: J, p: Player) => ReactNode) => players.map((p) => <p key={p.seat} className="t-small">{nameOf(p)} : {ans(p) == null ? "—" : f(ans(p), p)}</p>);
  const grid = (cols: number, count: number, at: (i: number) => ReactNode, label: string) => <Cells cols={cols} count={count} label={label} render={at} />;
  switch (c.mech) {
    case "memory_pairs": return <p>{t("mem.sol.pairs")}</p>;
    case "change_detection": return (
      <div className="stack stack--2">
        <p>{t("mem.sol.change", { o: s.before?.[s.from] ?? "", a: s.from + 1, b: s.to + 1 })}</p>
        {each((a) => (a === s.to ? "✓" : t("mem.cell", { n: a + 1 })))}
      </div>
    );
    case "differences": return <p>{t("mem.sol.diff", { w: (s.changes ?? []).map((x: J) => `${c.objects[x.index]} (${t(`mem.prop.${x.property}` as never)})`).join(", ") })}</p>;
    case "zoom_recognition": return <div className="stack stack--2"><p>{t("board.sol.word", { w: s.target ?? "" })}</p>{each((a) => c.choices[a])}</div>;
    case "visual_search": return <p>{players.map((p) => `${nameOf(p)} : ${t("mem.diff.errors", { n: c.errors?.[p.seat] ?? 0 })}`).join(" · ")}</p>;
    case "recall_set": return <div className="stack stack--2"><p>{t("mem.sol.list", { w: (s.targets ?? []).join(", ") })}</p>{each((a) => a.map((i: number) => c.choices[i]).join(", "))}</div>;
    case "simon": return <p>{players.map((p) => t("mem.sol.simon", { name: nameOf(p), n: c.scores?.[p.seat] ?? 0 })).join(" · ")}</p>;
    case "rhythm": return (
      <div className="stack stack--2">
        <div className="beats">{[...Array(c.beats)].map((_, b) => <span key={b} className={`beat ${s.active?.includes(b) ? "beat--on" : ""}`}>{b + 1}</span>)}</div>
        {each((a) => a.map((on: boolean, b: number) => (on ? b + 1 : null)).filter(Boolean).join(", ") || "—")}
      </div>
    );
    case "ordered_recall": return <div className="stack stack--2"><p>{t("mem.sol.list", { w: (s.sequence ?? []).join(" → ") })}</p>{each((a) => a.join(" → "))}</div>;
    case "spatial_recall": return grid(c.size, c.size * c.size, (i) => (s.positions?.[i] ? <Obj label={s.positions[i]} /> : null), t("mem.sol.grid"));
    case "pixel_recall": {
      const model = rowsToCells(s.rows ?? []);
      return (
        <div className="stack stack--2">
          <p>{t("mem.sol.pixel", { w: s.name ?? "" })}</p>
          <div className="pix5-compare">
            <div className="stack stack--1"><span className="t-meta">{t("mem.pixel.model")}</span><PixelGrid cells={model} label={t("mem.pixel.model")} /></div>
            {players.map((p) => ans(p) && <div key={p.seat} className="stack stack--1"><span className="t-meta">{nameOf(p)}</span><PixelGrid cells={ans(p)} compare={model} label={nameOf(p)} /></div>)}
          </div>
        </div>
      );
    }
    case "sorting": return <p>{players.map((p) => `${nameOf(p)} : ${c.scores?.[p.seat] ?? 0} / ${c.items.length}`).join(" · ")}</p>;
    case "go_nogo": return <div className="stack stack--2">{each((a) => t("mem.sol.gonogo", { h: a.hits, f: a.false_alarms }))}</div>;
    case "precision": return (
      <div className="stack stack--2">
        <Line marks={[{ v: s.target, label: t("mem.precision.mark"), cls: "line-mark--target" }, ...players.filter((p) => ans(p) != null).map((p) => ({ v: ans(p), label: nameOf(p), cls: p.is_me ? "line-mark--me" : "" }))]} />
        <p>{t("mem.sol.precision", { v: s.target })}</p>{each((a) => a)}
      </div>
    );
    case "split_memory": return (
      <div className="stack stack--2">
        <p>{t("mem.sol.split", { n: c.correct ?? 0, total: c.objects.length })}</p>
        {grid(c.size, c.size * c.size, (i) => { const x = (s.positions ?? []).find((p: J) => p.cell === i); return x ? <Obj label={x.o} /> : null; }, t("mem.sol.grid"))}
      </div>
    );
    case "silhouette": return <div className="stack stack--2"><p>{t("board.sol.word", { w: c.labels?.[s.index] ?? s.target })}</p>{each((a, p) => `${c.labels?.[a] ?? c.choices[a]}${c.hints?.[p.seat] ? ` · ${t("mem.sol.withHint")}` : ""}`)}</div>;
    case "layers": return <div className="stack stack--2"><p>{t("mem.sol.layers", { w: (s.order ?? []).map((k: number) => k + 1).join(" → ") })}</p>{each((a) => a.map((k: number) => k + 1).join(" → "))}</div>;
    case "rotation": return grid(3, 9, (i) => { const k = (s.cells ?? []).indexOf(i); return k >= 0 ? <Obj label={c.labels?.[k] ?? c.objects[k]} src={kitSrc(c.objects[k])} /> : null; }, t("mem.sol.grid"));
    default: return null;
  }
}
