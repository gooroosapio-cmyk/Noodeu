import { useState } from "react";
import { t } from "../../i18n";
import { Icon } from "../../components/ui";
import { DrawingView, type Stroke } from "../../components/Drawing";
import type { Player } from "../../lib/types";
import { ItemTile } from "./inputs";
import { answerOf, fixed, fixedObjects, itemLabel, list, type RAnswer, type RRound, type StepDef } from "./logic";

type P = Record<string, unknown>;
const EXTRA: Record<string, string> = { depends: "Ça dépend", neither: "Aucun des deux" };

/** Affichage d'une réponse révélée (ou de la sienne). Aucune interprétation : on montre ce qui a été écrit. */
export function AnswerView({ step, answer, round, owner }: { step: StepDef; answer?: RAnswer; round: RRound; owner: Player }) {
  if (!answer) return <p className="muted t-small">{t("rounds.noAnswerYet")}</p>;
  if (answer.skipped) return <p className="muted t-small">{step.kind === "yes_no" ? t("rounds.iPass") : t("rounds.passed")}</p>;
  const p = (answer.payload ?? {}) as P;
  const card = round.card;
  switch (step.kind) {
    case "text": return <p className="answer-text">{String(p.text ?? "")}</p>;
    case "choice": {
      const c = p.choice;
      const label = typeof c === "number" ? (card.choices ?? [])[c] : c === "other" ? `${t("rounds.otherShort")} : ${String(p.other ?? "")}` : EXTRA[String(c)] ?? String(c);
      return <div className="stack stack--2"><p className="t-card">{label}</p>{typeof p.comment === "string" && <p className="answer-text">{p.comment}</p>}</div>;
    }
    case "yes_no": return <p className="t-card">{p.answer === "yes" ? t("rounds.yes") : t("rounds.no")}</p>;
    case "pick": {
      const items = list(card, String(step.params?.list));
      const ids = (p.items as number[]) ?? [];
      const ordered = Boolean(step.params?.ordered);
      const Tag = ordered ? "ol" : "ul";
      return (
        <div className="stack stack--2">
          <Tag className={ordered ? "rank-list" : "chips"} style={ordered ? undefined : { listStyle: "none", padding: 0, margin: 0 }}>
            {ids.map((i, k) => (
              <li key={i} className={ordered ? "rank-list__item" : "word word--static"}>
                {ordered && <span className="rank-list__n" aria-hidden="true">{k + 1}</span>}{itemLabel(items[i]?.v, owner.word_form)}
              </li>
            ))}
            {((p.custom as string[]) ?? []).map((c) => <li key={c} className="word word--static word--own">{c}</li>)}
          </Tag>
          {typeof p.note === "string" && <p className="answer-text">{p.note}</p>}
        </div>
      );
    }
    case "objects": {
      const objects = list<string>(card, "objects");
      const bgs = fixedObjects<{ name: string; hex: string }>(card, "backgrounds");
      return (
        <ul className="object-board" style={{ background: bgs[Number(p.bg)]?.hex }}>
          {((p.items as { i: number; caption?: string }[]) ?? []).map((o) => (
            <li key={o.i}><ItemTile label={objects[o.i]?.v ?? ""} size={48} />{o.caption && <p className="t-small">{o.caption}</p>}</li>
          ))}
        </ul>
      );
    }
    case "sky": {
      const symbols = fixed(card, "symbols"), energies = fixed(card, "energies");
      return (
        <div className="stack stack--2">
          <div className="row row--wrap">{((p.symbols as number[]) ?? []).map((i) => <ItemTile key={i} label={symbols[i]} size={40} />)}</div>
          <p className="t-card">{energies[Number(p.energy)]}</p>
          {typeof p.note === "string" && <p className="answer-text">{p.note}</p>}
        </div>
      );
    }
    case "frise": {
      const prompts = list<string>(card, "prompts");
      return (
        <div className="stack stack--2">
          <p className="t-meta">{p.order === "emotion" ? t("rounds.emotion") : t("rounds.chrono")}</p>
          <ol className="timeline">
            {((p.entries as { p: number; title: string; text?: string; date?: string }[]) ?? []).map((e) => (
              <li key={e.p}><span className="t-meta">{prompts[e.p]?.v}{e.date ? ` · ${e.date}` : ""}</span><span className="t-card">{e.title}</span>{e.text && <span className="answer-text">{e.text}</span>}</li>
            ))}
          </ol>
        </div>
      );
    }
    case "gesture": {
      const actions = list<string>(card, "actions");
      return (
        <div className="stack stack--2">
          <p className="t-meta">{actions[Number(p.action)]?.v}</p>
          {typeof p.text === "string" && <p className="answer-text">{p.text}</p>}
          {Array.isArray(p.drawing) && <DrawingView strokes={p.drawing as Stroke[]} label={t("rounds.drawingOf", { name: owner.display_name })} />}
        </div>
      );
    }
    case "buy": case "common": {
      const acts = list<{ label: string; cost: number }>(card, "activities");
      return (
        <div className="stack stack--2">
          <ul className="chips" style={{ listStyle: "none", padding: 0, margin: 0 }}>{((p.items as number[]) ?? []).map((i) => <li key={i} className="tag">{acts[i]?.v.label} · {acts[i]?.v.cost}</li>)}</ul>
          <p className="t-meta">{t("rounds.spent", { n: Number(p.spent ?? 0) })}</p>
        </div>
      );
    }
    case "light": return <p className="t-card">{fixed(card, "lights")[Number(p.light)]} · {fixed(card, "ambiances")[Number(p.ambiance)]}</p>;
    case "agree": return <p className="t-card">{t("rounds.agreedOn", { n: Number(p.pick) })}</p>;
    case "cover_pick": case "line": {
      const stickers = list<string>(card, "stickers");
      return typeof p.sticker === "number" ? <ItemTile label={stickers[p.sticker]?.v ?? ""} size={36} /> : <p className="answer-text">{String(p.text ?? "")}</p>;
    }
    case "fields": {
      const labels = fixed(card, "fields");
      return (
        <dl className="fields-view">
          {((p.fields as { text?: string; shared: boolean }[]) ?? []).map((f, i) => (
            <div key={i}><dt className="t-meta">{labels[i]}</dt><dd>{f.text ? f.text : f.shared ? "—" : t("rounds.notShared")}</dd></div>
          ))}
        </dl>
      );
    }
    case "share": {
      const listKey = String(step.params?.list ?? "topics");
      return (
        <div className="stack stack--2">
          <p className="t-meta">{list<string>(card, listKey)[Number(p.topic)]?.v}</p>
          <p className="answer-text">{String(p.text ?? "")}</p>
        </div>
      );
    }
    case "confirm": return p.ok ? <p className="t-card row"><Icon name="check" size={18} />{t("rounds.thatsIt")}</p> : <p className="answer-text">{t("rounds.nuanceShort")} : {String(p.nuance ?? "")}</p>;
    case "reaction": {
      const options = step.params?.options as string[] | undefined;
      return <p className="answer-text">{options && typeof p.option === "number" ? options[p.option] : ""}{options && p.text ? " · " : ""}{String(p.text ?? "")}</p>;
    }
    case "surprise": {
      const words = list(card, "words");
      const other = answerOf(round, String(step.params?.from ?? "pick"), 3 - owner.seat)?.payload as { custom?: string[] } | null;
      const label = typeof p.i === "number" ? itemLabel(words[p.i]?.v, "n") : other?.custom?.[Number(p.c)] ?? "";
      return <p className="t-card">{t("rounds.circled", { label })}</p>;
    }
    case "zones": {
      const labels = list<string>(card, "labels"), zones = fixed(card, "zones");
      const places = (p.places as { i: number; z: number }[]) ?? [];
      const detail = p.detail as { i: number; text: string } | undefined;
      return (
        <div className="zones zones--view">
          {zones.map((z, zi) => (
            <div key={z} className="zones__col"><span className="t-meta">{z}</span>
              <ul className="stack stack--2" style={{ listStyle: "none", padding: 0, margin: 0 }}>
                {places.filter((x) => x.z === zi).map((x) => <li key={x.i} className="tag">{labels[x.i]?.v}{detail?.i === x.i ? ` — ${detail.text}` : ""}</li>)}
              </ul>
            </div>
          ))}
        </div>
      );
    }
    case "ask": {
      const labels = list<string>(card, "labels");
      return <p className="answer-text">{t("rounds.askedAbout", { label: labels[Number(p.label)]?.v ?? "" })}{p.text ? ` « ${String(p.text)} »` : ""}</p>;
    }
    case "page": return <PageView round={round} payload={p} label={t("rounds.pageOf", { name: owner.display_name })} />;
    case "gift": return <GiftView round={round} payload={p} owner={owner} />;
    case "place": return null; // rendu commun : SceneView
    default: return null;
  }
}

export function PageView({ round, payload, label }: { round: RRound; payload: P; label: string }) {
  const stickers = list<string>(round.card, "stickers");
  return (
    <div className="stack stack--2">
      {typeof payload.text === "string" && <p className="answer-text">{payload.text}</p>}
      <div className="zine-page zine-page--view" role="img" aria-label={label}>
        {Array.isArray(payload.drawing) && <DrawingView strokes={payload.drawing as Stroke[]} label="" className="zine-page__drawing" />}
        {((payload.stickers as { s: number; x: number; y: number }[]) ?? []).map((o, k) => (
          <span key={k} className="zine-sticker" style={{ left: `${o.x * 100}%`, top: `${o.y * 100}%` }}><ItemTile label={stickers[o.s]?.v ?? ""} size={28} /></span>
        ))}
      </div>
    </div>
  );
}

/** Boîte à surprises : celui qui reçoit ouvre les compartiments un par un (choix local, sans effet réseau). */
function GiftView({ round, payload, owner }: { round: RRound; payload: P; owner: Player }) {
  const [opened, setOpened] = useState(owner.is_me ? 3 : 0);
  const papers = fixedObjects<{ name: string; hex: string }>(round.card, "papers");
  const ribbons = fixedObjects<{ name: string; hex: string }>(round.card, "ribbons");
  const objects = list<string>(round.card, "objects");
  const parts = [
    { key: "o", node: typeof payload.object === "number" ? <ItemTile label={objects[payload.object]?.v ?? ""} size={48} /> : <p className="muted t-small">{t("rounds.emptyCompartment")}</p> },
    { key: "w", node: typeof payload.word === "string" ? <p className="answer-text">{payload.word}</p> : <p className="muted t-small">{t("rounds.emptyCompartment")}</p> },
    { key: "d", node: Array.isArray(payload.drawing) ? <DrawingView strokes={payload.drawing as Stroke[]} label={t("rounds.drawingOf", { name: owner.display_name })} /> : <p className="muted t-small">{t("rounds.emptyCompartment")}</p> },
  ];
  return (
    <div className="gift" style={{ borderColor: ribbons[Number(payload.ribbon)]?.hex, background: papers[Number(payload.paper)]?.hex }}>
      <p className="t-meta">{papers[Number(payload.paper)]?.name} · {ribbons[Number(payload.ribbon)]?.name}</p>
      {parts.slice(0, opened).map((x) => <div key={x.key} className="gift__part enter">{x.node}</div>)}
      {opened < 3 && <button className="btn btn--secondary btn--auto" onClick={() => setOpened(opened + 1)}>{t("rounds.openNext", { n: opened + 1 })}</button>}
    </div>
  );
}

/** Scène commune (« Votre coin tranquille ») : les deux moitiés réunies après la révélation. */
export function SceneView({ round }: { round: RRound }) {
  const objects = list<string>(round.card, "objects");
  const all = round.answers.filter((a) => a.step === "place" && a.payload).flatMap((a) => ((a.payload!.objects as { i: number; x: number; y: number }[]) ?? []));
  return (
    <div className="scene-grid scene-grid--view" role="img" aria-label={t("rounds.sceneView", { list: all.map((o) => objects[o.i]?.v).join(", ") })}>
      {[0, 1, 2, 3].map((y) => (
        <div key={y} className="scene-grid__row">
          {[0, 1, 2, 3, 4, 5].map((x) => {
            const o = all.find((q) => q.x === x && q.y === y);
            return <span key={x} className="scene-cell">{o && <ItemTile label={objects[o.i]?.v ?? ""} size={28} />}</span>;
          })}
        </div>
      ))}
    </div>
  );
}
