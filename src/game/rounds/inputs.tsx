import { useMemo, useState } from "react";
import { fill, t } from "../../i18n";
import { Icon } from "../../components/ui";
import { DrawingPad, type Stroke } from "../../components/Drawing";
import type { Player, WordForm } from "../../lib/types";
import elements from "../elements.json";
import {
  answerOf, basketCost, fixed, fixedObjects, itemLabel, list, move, toggleIn,
  type RRound, type StepDef,
} from "./logic";

type Payload = Record<string, unknown>;
export interface StepTexts { title: string; prompt: string; hint: string; confirm: string }

export interface InputProps {
  step: StepDef;
  round: RRound;
  texts: StepTexts;
  vars: Record<string, string>;
  me: Player;
  partner?: Player;
  busy: boolean;
  online: boolean;
  /** Envoie la réponse ; renvoie true si la base l'a acceptée. */
  submit: (payload: Payload | null, skip?: boolean) => Promise<boolean>;
}

const ELEMENTS = elements as Record<string, string>;

/** Image d'élément du kit (décorative) + libellé texte réel. */
export function ItemTile({ label, size = 40 }: { label: string; size?: number }) {
  const src = ELEMENTS[label];
  return (
    <span className="item-tile">
      {src && <img src={src} alt="" width={size} height={size} loading="lazy" />}
      <span>{label}</span>
    </span>
  );
}

function Counter({ value, max }: { value: string; max: number }) {
  return <span className="t-meta" aria-live="polite">{t("rounds.chars", { n: value.length, max })}</span>;
}

function TextArea({ id, label, value, onChange, max, rows = 4, hint }: {
  id: string; label: string; value: string; onChange: (v: string) => void; max: number; rows?: number; hint?: string;
}) {
  return (
    <div className="field">
      <label className="field__label" htmlFor={id}>{label}</label>
      {hint && <span className="field__hint">{hint}</span>}
      <textarea id={id} className="input" rows={rows} maxLength={max} value={value} onChange={(e) => onChange(e.target.value)} />
      <Counter value={value} max={max} />
    </div>
  );
}

/** Barre d'envoi commune : bouton principal, « passer » si autorisé, rappel de confidentialité. */
function SendBar({ p, ready, payload, privateHint = true }: { p: InputProps; ready: boolean; payload: () => Payload; privateHint?: boolean }) {
  const [sending, setSending] = useState(false);
  async function go(skip: boolean) {
    if (sending) return;
    setSending(true);
    await p.submit(skip ? null : payload(), skip);
    setSending(false);
  }
  return (
    <div className="action-bar">
      {privateHint && <p className="t-meta row" style={{ justifyContent: "center" }}><Icon name="lock" size={16} />{t("game.privateHint")}</p>}
      <button className="btn" disabled={!ready || p.busy || sending || !p.online} onClick={() => void go(false)}>
        {sending ? t("common.sending") : p.texts.confirm}<Icon name="arrow-right" />
      </button>
      {p.step.skippable && (
        <button className="btn btn--quiet" disabled={p.busy || sending || !p.online} onClick={() => void go(true)}>{t("rounds.pass")}</button>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------

function TextInput(p: InputProps) {
  const max = Number(p.step.params?.max ?? 300);
  const [text, setText] = useState("");
  return (
    <>
      <TextArea id={`t-${p.step.key}`} label={p.texts.title} value={text} onChange={setText} max={max} rows={max > 300 ? 6 : 4} />
      <SendBar p={p} ready={text.trim().length > 0} payload={() => ({ text })} />
    </>
  );
}

const EXTRA_LABELS: Record<string, string> = { depends: "rounds.depends", neither: "rounds.neither", other: "rounds.other" };

function ChoiceInput(p: InputProps) {
  const choices = p.round.card.choices ?? [];
  const extras = (p.step.params?.extras as string[] | undefined) ?? [];
  const commentMax = Number(p.step.params?.comment_max ?? 0);
  const [choice, setChoice] = useState<number | string | null>(null);
  const [other, setOther] = useState("");
  const [comment, setComment] = useState("");
  const ready = choice !== null && (choice !== "other" || other.trim().length > 0);
  return (
    <>
      <fieldset>
        <legend className="sr-only">{p.texts.title}</legend>
        <div className="choice-list">
          {choices.map((c, i) => (
            <button key={c} type="button" className="choice-card" role="radio" aria-checked={choice === i} onClick={() => setChoice(i)}>{c}</button>
          ))}
          {extras.map((x) => (
            <button key={x} type="button" className="choice-card choice-card--quiet" role="radio" aria-checked={choice === x} onClick={() => setChoice(x)}>
              {t(EXTRA_LABELS[x] as "rounds.depends")}
            </button>
          ))}
        </div>
      </fieldset>
      {choice === "other" && (
        <div className="field">
          <label className="field__label" htmlFor="c-other">{t("rounds.otherLabel")}</label>
          <input id="c-other" className="input" maxLength={80} value={other} onChange={(e) => setOther(e.target.value)} />
        </div>
      )}
      {commentMax > 0 && <TextArea id="c-comment" label={t("rounds.commentLabel")} value={comment} onChange={setComment} max={commentMax} rows={2} />}
      <SendBar p={p} ready={ready} payload={() => ({ choice, ...(choice === "other" ? { other } : {}), ...(comment.trim() ? { comment } : {}) })} />
    </>
  );
}

function YesNoInput(p: InputProps) {
  const [sending, setSending] = useState(false);
  async function go(answer: "yes" | "no" | null) {
    if (sending) return;
    setSending(true);
    await p.submit(answer ? { answer } : null, answer === null);
    setSending(false);
  }
  const disabled = p.busy || sending || !p.online;
  return (
    <div className="action-bar">
      <p className="t-meta row" style={{ justifyContent: "center" }}><Icon name="lock" size={16} />{t("game.privateHint")}</p>
      <div className="row">
        <button className="btn grow" disabled={disabled} onClick={() => void go("yes")}>{t("rounds.yes")}</button>
        <button className="btn grow" disabled={disabled} onClick={() => void go("no")}>{t("rounds.no")}</button>
      </div>
      <button className="btn btn--secondary" disabled={disabled} onClick={() => void go(null)}>{t("rounds.iPass")}</button>
    </div>
  );
}

function PickInput(p: InputProps) {
  const prm = p.step.params ?? {};
  const items = list(p.round.card, String(prm.list));
  const max = Number(prm.max), min = Number(prm.min);
  const customMax = Number(prm.custom_max ?? 0), customLen = Number(prm.custom_len ?? 24), noteMax = Number(prm.note_max ?? 0);
  const ordered = Boolean(prm.ordered);
  const [sel, setSel] = useState<number[]>([]);
  const [custom, setCustom] = useState<string[]>([]);
  const [draft, setDraft] = useState("");
  const [note, setNote] = useState("");
  const total = sel.length + custom.length;
  const label = (i: number) => itemLabel(items[i]?.v, p.me.word_form);
  return (
    <>
      <ul className="word-grid" aria-label={fill(p.texts.hint, p.vars)}>
        {items.map((it, i) => {
          const on = sel.includes(i);
          return (
            <li key={it.i}>
              <button className="word" aria-pressed={on} disabled={!on && total >= max} onClick={() => setSel(toggleIn(sel, i, max - custom.length))}>
                <span>{itemLabel(it.v, p.me.word_form)}</span>
                {ordered && on ? <span className="word__rank" aria-label={t("rounds.rank", { n: sel.indexOf(i) + 1 })}>{sel.indexOf(i) + 1}</span>
                  : <span className="word__check" aria-hidden="true"><Icon name="check" size={14} /></span>}
              </button>
            </li>
          );
        })}
      </ul>
      {customMax > 0 && (
        <div className="field">
          <label className="field__label" htmlFor="pick-custom">{t("rounds.ownWord")}</label>
          <div className="row">
            <input id="pick-custom" className="input grow" maxLength={customLen} value={draft} onChange={(e) => setDraft(e.target.value)} disabled={custom.length >= customMax || total >= max} />
            <button className="btn btn--secondary btn--auto" disabled={!draft.trim() || custom.length >= customMax || total >= max}
              onClick={() => { setCustom([...custom, draft.trim()]); setDraft(""); }}>{t("rounds.add")}</button>
          </div>
          {custom.map((c, i) => (
            <button key={c} className="chip chip--remove" onClick={() => setCustom(custom.filter((_, j) => j !== i))} aria-label={t("lib.removeFilter", { label: c })}>
              {c}<Icon name="close" size={16} />
            </button>
          ))}
        </div>
      )}
      {ordered && sel.length > 0 && (
        <ol className="rank-list" aria-label={t("rounds.order")}>
          {sel.map((i, k) => (
            <li key={i} className="rank-list__item">
              <span className="rank-list__n" aria-hidden="true">{k + 1}</span>
              <span className="grow">{label(i)}</span>
              <button className="icon-btn" aria-label={t("rounds.up", { label: label(i) })} disabled={k === 0} onClick={() => setSel(move(sel, k, k - 1))}><Icon name="chevron-up" size={18} /></button>
              <button className="icon-btn" aria-label={t("rounds.down", { label: label(i) })} disabled={k === sel.length - 1} onClick={() => setSel(move(sel, k, k + 1))}><Icon name="chevron-down" size={18} /></button>
            </li>
          ))}
        </ol>
      )}
      {noteMax > 0 && sel.length > 0 && (
        <TextArea id="pick-note" label={t("rounds.noteFirst", { label: label(sel[0]) })} value={note} onChange={setNote} max={noteMax} rows={2} />
      )}
      <p className="center t-small strong" aria-live="polite">{t("game.selected", { n: total, max })}</p>
      <SendBar p={p} ready={total >= min && total <= max} payload={() => ({ items: sel.map((i) => items[i].i === undefined ? i : i), custom, ...(note.trim() ? { note } : {}) })} />
    </>
  );
}

function ObjectsInput(p: InputProps) {
  const prm = p.step.params ?? {};
  const objects = list<string>(p.round.card, "objects");
  const backgrounds = fixedObjects<{ name: string; hex: string }>(p.round.card, "backgrounds");
  const count = Number(prm.count), capMax = Number(prm.caption_max);
  const [sel, setSel] = useState<number[]>([]);
  const [caps, setCaps] = useState<Record<number, string>>({});
  const [bg, setBg] = useState(0);
  return (
    <>
      <ul className="tile-grid" aria-label={t("rounds.pickObjects", { n: count })}>
        {objects.map((o, i) => (
          <li key={o.i}>
            <button className="tile-btn" aria-pressed={sel.includes(i)} disabled={!sel.includes(i) && sel.length >= count}
              onClick={() => setSel(toggleIn(sel, i, count))}><ItemTile label={o.v} /></button>
          </li>
        ))}
      </ul>
      {sel.map((i) => (
        <TextArea key={i} id={`cap-${i}`} label={t("rounds.caption", { label: objects[i].v })} value={caps[i] ?? ""} max={capMax} rows={2}
          onChange={(v) => setCaps({ ...caps, [i]: v })} />
      ))}
      <fieldset>
        <legend>{t("rounds.background")}</legend>
        <div className="chips" role="radiogroup">
          {backgrounds.map((b, i) => (
            <button key={b.name} type="button" role="radio" aria-checked={bg === i} className="swatch swatch--labelled" style={{ background: b.hex }} onClick={() => setBg(i)}>
              <span className="sr-only">{b.name}</span>
            </button>
          ))}
        </div>
      </fieldset>
      <SendBar p={p} ready={sel.length === count} payload={() => ({ items: sel.map((i) => ({ i, ...(caps[i]?.trim() ? { caption: caps[i] } : {}) })), bg })} />
    </>
  );
}

function SkyInput(p: InputProps) {
  const symbols = fixed(p.round.card, "symbols");
  const energies = fixed(p.round.card, "energies");
  const [sym, setSym] = useState<number[]>([]);
  const [energy, setEnergy] = useState<number | null>(null);
  const [note, setNote] = useState("");
  return (
    <>
      <fieldset>
        <legend>{t("rounds.skySymbols")}</legend>
        <ul className="tile-grid">
          {symbols.map((s, i) => (
            <li key={s}><button className="tile-btn" aria-pressed={sym.includes(i)} disabled={!sym.includes(i) && sym.length >= 3} onClick={() => setSym(toggleIn(sym, i, 3))}><ItemTile label={s} /></button></li>
          ))}
        </ul>
      </fieldset>
      <fieldset>
        <legend>{t("rounds.energy")}</legend>
        <div className="chips" role="radiogroup">
          {energies.map((e, i) => <button key={e} type="button" className="chip" role="radio" aria-checked={energy === i} onClick={() => setEnergy(i)}>{e}</button>)}
        </div>
      </fieldset>
      <TextArea id="sky-note" label={t("rounds.noteOptional")} value={note} onChange={setNote} max={200} rows={2} />
      <SendBar p={p} ready={sym.length >= 1 && energy !== null} payload={() => ({ symbols: sym, energy, ...(note.trim() ? { note } : {}) })} />
    </>
  );
}

function FriseInput(p: InputProps) {
  const prompts = list<string>(p.round.card, "prompts");
  const [order, setOrder] = useState<number[]>(prompts.map((_, i) => i));
  const [entries, setEntries] = useState<Record<number, { title: string; text: string; date: string }>>({});
  const [mode, setMode] = useState<"chrono" | "emotion">("chrono");
  const get = (i: number) => entries[i] ?? { title: "", text: "", date: "" };
  const set = (i: number, patch: Partial<{ title: string; text: string; date: string }>) => setEntries({ ...entries, [i]: { ...get(i), ...patch } });
  return (
    <>
      <fieldset>
        <legend>{t("rounds.friseOrder")}</legend>
        <div className="chips" role="radiogroup">
          <button type="button" className="chip" role="radio" aria-checked={mode === "chrono"} onClick={() => setMode("chrono")}>{t("rounds.chrono")}</button>
          <button type="button" className="chip" role="radio" aria-checked={mode === "emotion"} onClick={() => setMode("emotion")}>{t("rounds.emotion")}</button>
        </div>
      </fieldset>
      <ol className="stack" style={{ listStyle: "none", padding: 0, margin: 0 }}>
        {order.map((i, k) => (
          <li key={i} className="card stack stack--2">
            <div className="row row--between">
              <span className="t-card">{k + 1}. {prompts[i].v}</span>
              <span className="row" style={{ gap: 0 }}>
                <button className="icon-btn" aria-label={t("rounds.up", { label: prompts[i].v })} disabled={k === 0} onClick={() => setOrder(move(order, k, k - 1))}><Icon name="chevron-up" size={18} /></button>
                <button className="icon-btn" aria-label={t("rounds.down", { label: prompts[i].v })} disabled={k === order.length - 1} onClick={() => setOrder(move(order, k, k + 1))}><Icon name="chevron-down" size={18} /></button>
              </span>
            </div>
            <div className="field">
              <label className="field__label" htmlFor={`fr-t-${i}`}>{t("rounds.title")}</label>
              <input id={`fr-t-${i}`} className="input" maxLength={40} value={get(i).title} onChange={(e) => set(i, { title: e.target.value })} />
            </div>
            <TextArea id={`fr-x-${i}`} label={t("rounds.sentence")} value={get(i).text} onChange={(v) => set(i, { text: v })} max={160} rows={2} />
            <div className="field">
              <label className="field__label" htmlFor={`fr-d-${i}`}>{t("rounds.dateOptional")}</label>
              <input id={`fr-d-${i}`} className="input" maxLength={20} value={get(i).date} onChange={(e) => set(i, { date: e.target.value })} />
            </div>
          </li>
        ))}
      </ol>
      <SendBar p={p} ready={order.every((i) => get(i).title.trim())}
        payload={() => ({ order: mode, entries: order.map((i) => ({ p: i, title: get(i).title, ...(get(i).text.trim() ? { text: get(i).text } : {}), ...(get(i).date.trim() ? { date: get(i).date } : {}) })) })} />
    </>
  );
}

function GestureInput(p: InputProps) {
  const actions = list<string>(p.round.card, "actions");
  const [action, setAction] = useState(() => Math.floor(Math.random() * Math.max(actions.length, 1)));
  const [text, setText] = useState("");
  const [drawing, setDrawing] = useState<Stroke[]>([]);
  const [draw, setDraw] = useState(false);
  return (
    <>
      <div className="card card--soft stack stack--2" aria-live="polite">
        <span className="t-meta">{t("rounds.wheel")}</span>
        <p className="t-card">{actions[action]?.v}</p>
        <button className="btn btn--secondary btn--auto btn--sm" onClick={() => setAction((a) => (a + 1 + Math.floor(Math.random() * (actions.length - 1))) % actions.length)}>
          <Icon name="refresh" size={18} />{t("rounds.change")}
        </button>
      </div>
      <TextArea id="g-text" label={t("rounds.yourText")} value={text} onChange={setText} max={280} rows={3} />
      <button className="btn btn--quiet btn--auto" aria-expanded={draw} onClick={() => setDraw(!draw)}><Icon name="pencil" size={18} />{draw ? t("rounds.hideDrawing") : t("rounds.addDrawing")}</button>
      {draw && <DrawingPad value={drawing} onChange={setDrawing} label={t("rounds.drawingLabel")} />}
      <SendBar p={p} ready={text.trim().length > 0 || drawing.length > 0}
        payload={() => ({ action, ...(text.trim() ? { text } : {}), ...(drawing.length ? { drawing } : {}) })} />
    </>
  );
}

function BuyInput(p: InputProps) {
  const prm = p.step.params ?? {};
  const acts = list<{ label: string; cost: number }>(p.round.card, "activities");
  const budget = Number(prm.budget ?? 12), maxItems = Number(prm.max_items ?? 4);
  const [sel, setSel] = useState<number[]>([]);
  const spent = basketCost(p.round.card, sel);
  return (
    <>
      <p className="t-card" aria-live="polite">{t("rounds.tokens", { n: budget - spent, max: budget })}</p>
      <ul className="stack" style={{ listStyle: "none", padding: 0, margin: 0 }}>
        {acts.map((a, i) => {
          const on = sel.includes(i);
          const blocked = !on && (sel.length >= maxItems || spent + a.v.cost > budget);
          return (
            <li key={a.i}>
              <button className="choice-card row row--between" aria-pressed={on} disabled={blocked} onClick={() => setSel(toggleIn(sel, i, maxItems))}>
                <span>{a.v.label}</span><span className="tag">{t("rounds.cost", { n: a.v.cost })}</span>
              </button>
            </li>
          );
        })}
      </ul>
      <SendBar p={p} ready={sel.length >= 1} payload={() => ({ items: sel })} />
    </>
  );
}

function PlaceInput(p: InputProps) {
  const objects = list<string>(p.round.card, "objects");
  const count = Number(p.step.params?.count ?? 3);
  const seat = p.me.seat;
  const [placed, setPlaced] = useState<{ i: number; x: number; y: number }[]>([]);
  const [picked, setPicked] = useState<number | null>(null);
  const mine = (x: number) => (seat === 1 ? x <= 2 : x >= 3);
  function tapCell(x: number, y: number) {
    const here = placed.find((o) => o.x === x && o.y === y);
    if (here) { setPlaced(placed.filter((o) => o !== here)); return; }
    if (picked === null || !mine(x) || placed.length >= count) return;
    setPlaced([...placed.filter((o) => o.i !== picked), { i: picked, x, y }]);
    setPicked(null);
  }
  return (
    <>
      {picked !== null && <p className="t-small strong" aria-live="polite">{t("rounds.placeCell", { label: objects[picked].v })}</p>}
      <ul className="tile-grid tile-grid--small">
        {objects.map((o, i) => (
          <li key={o.i}>
            <button className="tile-btn" aria-pressed={picked === i || placed.some((x) => x.i === i)} onClick={() => setPicked(picked === i ? null : i)}
              disabled={!placed.some((x) => x.i === i) && placed.length >= count && picked !== i}><ItemTile label={o.v} size={32} /></button>
          </li>
        ))}
      </ul>
      <div className="scene-grid" role="grid" aria-label={t("rounds.scene")}>
        {[0, 1, 2, 3].map((y) => (
          <div role="row" key={y} className="scene-grid__row">
            {[0, 1, 2, 3, 4, 5].map((x) => {
              const o = placed.find((q) => q.x === x && q.y === y);
              const name = o ? objects[o.i].v : "";
              return (
                <button key={x} role="gridcell" className={`scene-cell${mine(x) ? " scene-cell--mine" : ""}`} disabled={!mine(x)}
                  aria-label={mine(x) ? (o ? t("rounds.cellRemove", { label: name, x: x + 1, y: y + 1 }) : t("rounds.cellEmpty", { x: x + 1, y: y + 1 })) : t("rounds.cellOther", { x: x + 1, y: y + 1 })}
                  onClick={() => tapCell(x, y)}>
                  {o && <ItemTile label={name} size={28} />}
                </button>
              );
            })}
          </div>
        ))}
      </div>
      <p className="t-meta">{t("rounds.yourHalf")}</p>
      <SendBar p={p} ready={placed.length === count} payload={() => ({ objects: placed })} />
    </>
  );
}

function LightInput(p: InputProps) {
  const lights = fixed(p.round.card, "lights");
  const ambiances = fixed(p.round.card, "ambiances");
  const [light, setLight] = useState<number | null>(null);
  const [amb, setAmb] = useState<number | null>(null);
  return (
    <>
      <fieldset><legend>{t("rounds.light")}</legend>
        <div className="chips" role="radiogroup">{lights.map((l, i) => <button key={l} type="button" className="chip" role="radio" aria-checked={light === i} onClick={() => setLight(i)}>{l}</button>)}</div>
      </fieldset>
      <fieldset><legend>{t("rounds.ambiance")}</legend>
        <div className="chips" role="radiogroup">{ambiances.map((l, i) => <button key={l} type="button" className="chip" role="radio" aria-checked={amb === i} onClick={() => setAmb(i)}>{l}</button>)}</div>
      </fieldset>
      <SendBar p={p} ready={light !== null && amb !== null} payload={() => ({ light, ambiance: amb })} />
    </>
  );
}

function GiftInput(p: InputProps) {
  const papers = fixedObjects<{ name: string; hex: string }>(p.round.card, "papers");
  const ribbons = fixedObjects<{ name: string; hex: string }>(p.round.card, "ribbons");
  const objects = list<string>(p.round.card, "objects");
  const prompts = list<string>(p.round.card, "prompts");
  const [paper, setPaper] = useState(0);
  const [ribbon, setRibbon] = useState(0);
  const [object, setObject] = useState<number | null>(null);
  const [word, setWord] = useState("");
  const [drawing, setDrawing] = useState<Stroke[]>([]);
  return (
    <>
      {prompts.length > 0 && <p className="t-small muted">{t("rounds.ideas")} {prompts.map((x) => x.v).join(" · ")}</p>}
      <fieldset><legend>{t("rounds.paper")}</legend>
        <div className="chips" role="radiogroup">{papers.map((x, i) => (
          <button key={x.name} type="button" role="radio" aria-checked={paper === i} className="swatch swatch--labelled" style={{ background: x.hex }} onClick={() => setPaper(i)}><span className="sr-only">{x.name}</span></button>
        ))}</div>
      </fieldset>
      <fieldset><legend>{t("rounds.ribbon")}</legend>
        <div className="chips" role="radiogroup">{ribbons.map((x, i) => (
          <button key={x.name} type="button" role="radio" aria-checked={ribbon === i} className="chip" onClick={() => setRibbon(i)}>{x.name}</button>
        ))}</div>
      </fieldset>
      <fieldset><legend>{t("rounds.compartment1")}</legend>
        <ul className="tile-grid tile-grid--small">{objects.map((o, i) => (
          <li key={o.i}><button className="tile-btn" aria-pressed={object === i} onClick={() => setObject(object === i ? null : i)}><ItemTile label={o.v} size={32} /></button></li>
        ))}</ul>
      </fieldset>
      <TextArea id="gift-word" label={t("rounds.compartment2")} value={word} onChange={setWord} max={160} rows={2} />
      <fieldset><legend>{t("rounds.compartment3")}</legend>
        <DrawingPad value={drawing} onChange={setDrawing} label={t("rounds.drawingLabel")} />
      </fieldset>
      <SendBar p={p} ready payload={() => ({ paper, ribbon, object, ...(word.trim() ? { word } : {}), ...(drawing.length ? { drawing } : {}) })} />
    </>
  );
}

function PageInput(p: InputProps) {
  const stickers = list<string>(p.round.card, "stickers");
  const theme = list<string>(p.round.card, "themes")[0]?.v ?? "";
  const [text, setText] = useState("");
  const [placed, setPlaced] = useState<{ s: number; x: number; y: number }[]>([]);
  const [picked, setPicked] = useState<number | null>(null);
  const [drawing, setDrawing] = useState<Stroke[]>([]);
  const [mode, setMode] = useState<"stickers" | "draw">("stickers");
  return (
    <>
      <p className="t-small strong">{t("rounds.theme", { theme })}</p>
      <TextArea id="page-text" label={t("rounds.pageText")} value={text} onChange={setText} max={200} rows={3} />
      <div className="chips" role="radiogroup" aria-label={t("rounds.tool")}>
        <button type="button" className="chip" role="radio" aria-checked={mode === "stickers"} onClick={() => setMode("stickers")}>{t("rounds.stickers")}</button>
        <button type="button" className="chip" role="radio" aria-checked={mode === "draw"} onClick={() => setMode("draw")}><Icon name="pencil" size={16} />{t("rounds.pencil")}</button>
      </div>
      {mode === "stickers" ? (
        <>
          <ul className="tile-grid tile-grid--small">{stickers.map((s, i) => (
            <li key={s.i}><button className="tile-btn" aria-pressed={picked === i} disabled={placed.length >= 8 && picked !== i} onClick={() => setPicked(picked === i ? null : i)}><ItemTile label={s.v} size={28} /></button></li>
          ))}</ul>
          <p className="t-meta">{picked === null ? t("rounds.stickerPick") : t("rounds.stickerPlace", { label: stickers[picked].v })}</p>
          <div className="zine-page" role="application" aria-label={t("rounds.pageArea")}
            onClick={(e) => {
              if (picked === null || placed.length >= 8) return;
              const r = e.currentTarget.getBoundingClientRect();
              const x = Math.round(((e.clientX - r.left) / r.width) * 1000) / 1000;
              const y = Math.round(((e.clientY - r.top) / r.height) * 1000) / 1000;
              setPlaced([...placed, { s: picked, x, y }]);
            }}>
            {placed.map((o, k) => (
              <button key={k} className="zine-sticker" style={{ left: `${o.x * 100}%`, top: `${o.y * 100}%` }}
                aria-label={t("rounds.stickerRemove", { label: stickers[o.s].v })}
                onClick={(e) => { e.stopPropagation(); setPlaced(placed.filter((_, j) => j !== k)); }}>
                <ItemTile label={stickers[o.s].v} size={28} />
              </button>
            ))}
          </div>
        </>
      ) : <DrawingPad value={drawing} onChange={setDrawing} label={t("rounds.drawingLabel")} />}
      <SendBar p={p} ready={text.trim().length > 0 || placed.length > 0 || drawing.length > 0}
        payload={() => ({ ...(text.trim() ? { text } : {}), stickers: placed, ...(drawing.length ? { drawing } : {}) })} />
    </>
  );
}

function CoverPickInput(p: InputProps) {
  const stickers = list<string>(p.round.card, "stickers");
  const page = answerOf(p.round, String(p.step.params?.from ?? "page"), p.me.seat)?.payload as { stickers?: { s: number }[] } | null;
  const mine = [...new Set((page?.stickers ?? []).map((x) => x.s))];
  const [sticker, setSticker] = useState<number | null>(null);
  const [text, setText] = useState("");
  return (
    <>
      {mine.length > 0 && (
        <ul className="tile-grid tile-grid--small">{mine.map((s) => (
          <li key={s}><button className="tile-btn" aria-pressed={sticker === s} onClick={() => { setSticker(sticker === s ? null : s); setText(""); }}><ItemTile label={stickers[s]?.v ?? ""} size={28} /></button></li>
        ))}</ul>
      )}
      <div className="field">
        <label className="field__label" htmlFor="cover-text">{t("rounds.coverText")}</label>
        <input id="cover-text" className="input" maxLength={40} value={text} onChange={(e) => { setText(e.target.value); setSticker(null); }} />
      </div>
      <SendBar p={p} ready={sticker !== null || text.trim().length > 0} payload={() => (sticker !== null ? { sticker } : { text })} />
    </>
  );
}

function LineInput(p: InputProps) {
  const stickers = list<string>(p.round.card, "stickers");
  const [text, setText] = useState("");
  const [sticker, setSticker] = useState<number | null>(null);
  return (
    <>
      <div className="field">
        <label className="field__label" htmlFor={`line-${p.step.key}`}>{t("rounds.lineText")}</label>
        <input id={`line-${p.step.key}`} className="input" maxLength={80} value={text} onChange={(e) => { setText(e.target.value); setSticker(null); }} />
      </div>
      <ul className="tile-grid tile-grid--small">{stickers.map((s, i) => (
        <li key={s.i}><button className="tile-btn" aria-pressed={sticker === i} onClick={() => { setSticker(sticker === i ? null : i); setText(""); }}><ItemTile label={s.v} size={28} /></button></li>
      ))}</ul>
      <SendBar p={p} privateHint={false} ready={sticker !== null || text.trim().length > 0} payload={() => (sticker !== null ? { sticker } : { text })} />
    </>
  );
}

function FieldsInput(p: InputProps) {
  const labels = fixed(p.round.card, "fields");
  const ideas = list<string>(p.round.card, "ideas");
  const max = Number(p.step.params?.max ?? 180);
  const [fields, setFields] = useState(labels.map(() => ({ text: "", shared: true })));
  const set = (i: number, patch: Partial<{ text: string; shared: boolean }>) => setFields(fields.map((f, j) => (j === i ? { ...f, ...patch } : f)));
  return (
    <>
      {ideas.length > 0 && <p className="t-small muted">{t("rounds.ideas")} {ideas.map((x) => x.v).join(" · ")}</p>}
      {labels.map((l, i) => (
        <div key={l} className="card stack stack--2">
          <TextArea id={`cap-f-${i}`} label={l} value={fields[i].text} onChange={(v) => set(i, { text: v })} max={max} rows={2} />
          <label className="switch-row" style={{ padding: 0, minHeight: 44 }}>
            <span className="switch-row__text"><span>{t("rounds.share")}</span>
              <span className="t-meta">{fields[i].shared ? t("rounds.sharedHint") : t("rounds.keptHint")}</span></span>
            <input className="switch" type="checkbox" role="switch" checked={fields[i].shared} onChange={(e) => set(i, { shared: e.target.checked })} />
          </label>
        </div>
      ))}
      <SendBar p={p} ready={fields.some((f) => f.text.trim())} payload={() => ({ fields: fields.map((f) => ({ ...(f.text.trim() ? { text: f.text } : {}), shared: f.shared })) })} />
    </>
  );
}

function ShareInput(p: InputProps) {
  const listKey = String(p.step.params?.list ?? "topics");
  const topics = list<string>(p.round.card, listKey);
  const max = Number(p.step.params?.max ?? 500);
  const [topic, setTopic] = useState<number | null>(null);
  const [text, setText] = useState("");
  return (
    <>
      <fieldset>
        <legend>{listKey === "prompts" ? t("rounds.pickPrompt") : t("rounds.pickTopic")}</legend>
        <div className="choice-list">
          {topics.map((x, i) => <button key={x.i} type="button" className="choice-card" role="radio" aria-checked={topic === i} onClick={() => setTopic(i)}>{x.v}</button>)}
        </div>
      </fieldset>
      <TextArea id="share-text" label={topic !== null && listKey === "prompts" ? topics[topic].v : t("rounds.yourText")} value={text} onChange={setText} max={max} rows={5} />
      <SendBar p={p} privateHint={p.step.visible !== "immediate"} ready={topic !== null && text.trim().length > 0} payload={() => ({ topic, text })} />
    </>
  );
}

function ConfirmInput(p: InputProps) {
  const [nuance, setNuance] = useState("");
  const [sending, setSending] = useState(false);
  async function go(ok: boolean) {
    setSending(true);
    await p.submit(ok ? { ok: true } : { ok: false, nuance });
    setSending(false);
  }
  const disabled = p.busy || sending || !p.online;
  return (
    <>
      <TextArea id="nuance" label={t("rounds.nuance")} value={nuance} onChange={setNuance} max={250} rows={2} />
      <div className="action-bar">
        <button className="btn" disabled={disabled} onClick={() => void go(true)}>{t("rounds.thatsIt")}</button>
        <button className="btn btn--secondary" disabled={disabled || !nuance.trim()} onClick={() => void go(false)}>{t("rounds.sendNuance")}</button>
      </div>
    </>
  );
}

function ZonesInput(p: InputProps) {
  const labels = list<string>(p.round.card, "labels");
  const zones = fixed(p.round.card, "zones");
  const max = Number(p.step.params?.max ?? 6);
  const [places, setPlaces] = useState<{ i: number; z: number }[]>([]);
  const [picked, setPicked] = useState<number | null>(null);
  const [detailI, setDetailI] = useState<number | null>(null);
  const [detail, setDetail] = useState("");
  const placedSet = new Set(places.map((x) => x.i));
  return (
    <>
      <p className="t-small">{picked === null ? t("rounds.zonePick", { n: max }) : t("rounds.zonePlace", { label: labels[picked].v })}</p>
      <div className="chips">
        {labels.map((l, i) => !placedSet.has(i) && (
          <button key={l.i} type="button" className="chip" aria-pressed={picked === i} disabled={places.length >= max && picked !== i} onClick={() => setPicked(picked === i ? null : i)}>{l.v}</button>
        ))}
      </div>
      <div className="zones">
        {zones.map((z, zi) => (
          <div key={z} className="zones__col">
            <button className="btn btn--secondary btn--sm" disabled={picked === null} onClick={() => { setPlaces([...places, { i: picked!, z: zi }]); setPicked(null); }}>
              {t("rounds.putIn", { zone: z })}
            </button>
            <ul className="stack stack--2" style={{ listStyle: "none", padding: 0, margin: 0 }}>
              {places.filter((x) => x.z === zi).map((x) => (
                <li key={x.i}><button className="chip chip--remove" onClick={() => setPlaces(places.filter((y) => y.i !== x.i))} aria-label={t("rounds.removeLabel", { label: labels[x.i].v })}>{labels[x.i].v}<Icon name="close" size={14} /></button></li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      {places.length > 0 && (
        <fieldset>
          <legend>{t("rounds.detailOptional")}</legend>
          <div className="chips" role="radiogroup">{places.map((x) => (
            <button key={x.i} type="button" className="chip" role="radio" aria-checked={detailI === x.i} onClick={() => setDetailI(detailI === x.i ? null : x.i)}>{labels[x.i].v}</button>
          ))}</div>
          {detailI !== null && <TextArea id="zone-detail" label={t("rounds.detail", { label: labels[detailI].v })} value={detail} onChange={setDetail} max={80} rows={2} />}
        </fieldset>
      )}
      <SendBar p={p} ready={places.length >= 1}
        payload={() => ({ places, ...(detailI !== null && placedSet.has(detailI) && detail.trim() ? { detail: { i: detailI, text: detail } } : {}) })} />
    </>
  );
}

// ----- Étapes après révélation ------------------------------------------------

function ReactionInput(p: InputProps) {
  const options = (p.step.params?.options as string[] | undefined) ?? null;
  const max = Number(p.step.params?.max ?? 200);
  const [option, setOption] = useState<number | null>(null);
  const [text, setText] = useState("");
  return (
    <>
      {options && (
        <div className="chips" role="radiogroup" aria-label={p.texts.title}>
          {options.map((o, i) => <button key={o} type="button" className="chip" role="radio" aria-checked={option === i} onClick={() => setOption(i)}>{o}</button>)}
        </div>
      )}
      <TextArea id={`re-${p.step.key}`} label={options ? t("rounds.addWordOptional") : p.texts.title} value={text} onChange={setText} max={max} rows={2} />
      <SendBar p={p} privateHint={false} ready={options ? option !== null : text.trim().length > 0}
        payload={() => (options ? { option, ...(text.trim() ? { text } : {}) } : { text })} />
    </>
  );
}

function SurpriseInput(p: InputProps) {
  const from = String(p.step.params?.from ?? "pick");
  const other = p.partner ? answerOf(p.round, from, p.partner.seat)?.payload as { items?: number[]; custom?: string[] } | null : null;
  const words = list(p.round.card, "words");
  const [ref, setRef] = useState<{ i?: number; c?: number } | null>(null);
  if (!other) return <p className="muted">{t("rounds.nothingToCircle")}</p>;
  return (
    <>
      <div className="chips">
        {(other.items ?? []).map((i) => (
          <button key={`i${i}`} type="button" className="chip" aria-pressed={ref?.i === i} onClick={() => setRef({ i })}>{itemLabel(words[i]?.v, p.partner?.word_form ?? "n")}</button>
        ))}
        {(other.custom ?? []).map((c, k) => (
          <button key={`c${k}`} type="button" className="chip" aria-pressed={ref?.c === k} onClick={() => setRef({ c: k })}>{c}</button>
        ))}
      </div>
      <SendBar p={p} privateHint={false} ready={ref !== null} payload={() => ref ?? {}} />
    </>
  );
}

function CommonInput(p: InputProps) {
  const from = String(p.step.params?.from ?? "buy");
  const budget = Number(p.step.params?.budget ?? 12);
  const acts = list<{ label: string; cost: number }>(p.round.card, "activities");
  const union = useMemo(() => [...new Set(p.round.answers.filter((a) => a.step === from).flatMap((a) => ((a.payload?.items as number[]) ?? [])))].sort((a, b) => a - b), [p.round, from]);
  const mine = answerOf(p.round, p.step.key, p.me.seat)?.payload?.items as number[] | undefined;
  const [sel, setSel] = useState<number[]>(mine ?? []);
  const spent = basketCost(p.round.card, sel);
  return (
    <>
      <p className="t-card" aria-live="polite">{t("rounds.tokens", { n: budget - spent, max: budget })}</p>
      <ul className="stack" style={{ listStyle: "none", padding: 0, margin: 0 }}>
        {union.map((i) => {
          const on = sel.includes(i);
          return (
            <li key={i}>
              <button className="choice-card row row--between" aria-pressed={on} disabled={!on && spent + acts[i].v.cost > budget} onClick={() => setSel(toggleIn(sel, i, 12))}>
                <span>{acts[i].v.label}</span><span className="tag">{t("rounds.cost", { n: acts[i].v.cost })}</span>
              </button>
            </li>
          );
        })}
      </ul>
      <SendBar p={p} privateHint={false} ready={sel.length >= 1} payload={() => ({ items: sel })} />
    </>
  );
}

function AgreeInput(p: InputProps) {
  const lights = fixed(p.round.card, "lights");
  const ambiances = fixed(p.round.card, "ambiances");
  const [pick, setPick] = useState<number | null>(null);
  return (
    <>
      <div className="choice-list">
        {[1, 2].map((seat) => {
          const a = answerOf(p.round, "light", seat)?.payload as { light?: number; ambiance?: number } | null;
          const who = seat === p.me.seat ? t("rounds.myProposal") : t("rounds.proposalOf", { name: p.partner?.display_name ?? "?" });
          return (
            <button key={seat} type="button" className="choice-card" role="radio" aria-checked={pick === seat} disabled={!a} onClick={() => setPick(seat)}>
              <span className="strong">{who}</span><br />
              {a ? `${lights[a.light ?? 0]} · ${ambiances[a.ambiance ?? 0]}` : t("rounds.noProposal")}
            </button>
          );
        })}
      </div>
      <SendBar p={p} privateHint={false} ready={pick !== null} payload={() => ({ pick })} />
    </>
  );
}

function AskInput(p: InputProps) {
  const labels = list<string>(p.round.card, "labels");
  const from = String(p.step.params?.from ?? "map");
  const other = p.partner ? answerOf(p.round, from, p.partner.seat)?.payload as { places?: { i: number }[] } | null : null;
  const [label, setLabel] = useState<number | null>(null);
  const [text, setText] = useState("");
  if (!other?.places?.length) return <p className="muted">{t("rounds.nothingToAsk")}</p>;
  return (
    <>
      <div className="chips" role="radiogroup">
        {other.places.map((x) => <button key={x.i} type="button" className="chip" role="radio" aria-checked={label === x.i} onClick={() => setLabel(x.i)}>{labels[x.i]?.v}</button>)}
      </div>
      <TextArea id="ask-text" label={t("rounds.questionOptional")} value={text} onChange={setText} max={120} rows={2} />
      <SendBar p={p} privateHint={false} ready={label !== null} payload={() => ({ label, ...(text.trim() ? { text } : {}) })} />
    </>
  );
}

const INPUTS: Record<string, (p: InputProps) => React.JSX.Element> = {
  text: TextInput, choice: ChoiceInput, yes_no: YesNoInput, pick: PickInput, objects: ObjectsInput, sky: SkyInput,
  frise: FriseInput, gesture: GestureInput, buy: BuyInput, place: PlaceInput, light: LightInput, gift: GiftInput,
  page: PageInput, cover_pick: CoverPickInput, line: LineInput, fields: FieldsInput, share: ShareInput,
  confirm: ConfirmInput, zones: ZonesInput, reaction: ReactionInput, surprise: SurpriseInput, common: CommonInput,
  agree: AgreeInput, ask: AskInput,
};

export function StepInput(p: InputProps) {
  const C = INPUTS[p.step.kind];
  if (!C) return <p className="muted">{t("rounds.unsupported")}</p>;
  return <C {...p} />;
}

export type { Payload };
export type FormOf = WordForm;
