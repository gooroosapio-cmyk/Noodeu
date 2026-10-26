/* eslint-disable @typescript-eslint/no-explicit-any */
// Moteur « plateau » (familles 2 à 4) : l'état public vient de la base, la part privée de l'appelant aussi.
// L'écran ne décide de rien : chaque coup part au serveur, qui l'accepte ou le refuse avec une raison.
import { useEffect, useState, type ComponentType, type ReactNode } from "react";
import { Link } from "react-router";
import { t, type MessageKey } from "../../i18n";
import { Alert, Art, Icon, Illustration, Loading } from "../../components/ui";
import type { Player, SessionState } from "../../lib/types";
import { CREATION_VIEWS, CreationSolution, isCreationMech } from "./CreationGames";
import { MEMORY_VIEWS, MemorySolution, isMemoryMech } from "./MemoryGames";
import { MINI_VIEWS, MiniSolution, isMiniMech } from "./MiniGames";

type Run = (fn: string, args?: Record<string, unknown>) => Promise<{ ok: boolean; error?: string; info?: any }>;
interface Common { st: SessionState; run: Run; busy: boolean; online: boolean }
type J = any;
type Play = (type: string, payload?: Record<string, unknown>) => Promise<{ ok: boolean; info?: J }>;

interface BRound { round_no: number; card: J; revealed: boolean; private: J; solution: J }
interface V { c: J; priv: J; me: Player; partner?: Player; play: Play; busy: boolean; mine: boolean }

export const isBoard = (st: SessionState) => (st.game.config as unknown as { engine?: string }).engine === "board";
const roundsOf = (st: SessionState) => st.rounds as unknown as BRound[];
const nameOf = (p?: Player) => (p ? (p.is_me ? t("game.you") : p.display_name || "?") : "?");
const bySeat = (me: Player, partner: Player | undefined, seat: number) => nameOf(seat === me.seat ? me : partner);
const errKey = (code?: string) => `board.err.${code}` as MessageKey;

function moveError(code?: string) {
  const msg = t(errKey(code));
  return msg === errKey(code) ? t("board.err.invalid_move") : msg;
}

// ---------------------------------------------------------------------------
// Petits éléments communs
// ---------------------------------------------------------------------------
function TextMove({ id, label, hint, max, onSend, busy, button, initial = "" }: {
  id: string; label: string; hint?: string; max: number; busy: boolean; button: string;
  onSend: (v: string) => Promise<boolean>; initial?: string;
}) {
  const [v, setV] = useState(initial);
  return (
    <form className="stack stack--2" onSubmit={async (e) => { e.preventDefault(); if (v.trim() && await onSend(v.trim())) setV(""); }}>
      <div className="field">
        <label className="field__label" htmlFor={id}>{label}</label>
        {hint && <span className="field__hint">{hint}</span>}
        <input id={id} className="input" maxLength={max} value={v} autoComplete="off" autoCapitalize="none" spellCheck={false}
          onChange={(e) => setV(e.target.value)} />
      </div>
      <button className="btn" type="submit" disabled={busy || !v.trim()}>{button}</button>
    </form>
  );
}

function Turn({ mine, other }: { mine: boolean; other: string }) {
  return (
    <p className={`board-turn ${mine ? "board-turn--me" : ""}`} aria-live="polite">
      <Icon name={mine ? "play" : "clock"} size={18} />{mine ? t("board.yourTurn") : t("board.theirTurn", { name: other })}
    </p>
  );
}

function Letters({ letters, label }: { letters: (string | null)[]; label?: string }) {
  return (
    <div className="letter-row" role="img" aria-label={label ?? letters.map((l) => l ?? "?").join(" ")}>
      {letters.map((l, i) => <span key={i} className={`letter ${l ? "" : "letter--empty"}`} aria-hidden="true">{l ?? ""}</span>)}
    </div>
  );
}

function Quiet({ children, onClick, busy }: { children: ReactNode; onClick: () => void; busy: boolean }) {
  return <button type="button" className="btn btn--quiet btn--auto btn--sm" disabled={busy} onClick={onClick}>{children}</button>;
}

const List = ({ items }: { items: ReactNode[] }) =>
  <ul className="chips" style={{ listStyle: "none", padding: 0, margin: 0 }}>{items.map((x, i) => <li key={i} className="tag">{x}</li>)}</ul>;

// ---------------------------------------------------------------------------
// Les 18 activités
// ---------------------------------------------------------------------------
function Taboo({ c, priv, me, partner, play, busy }: V) {
  const giver = c.giver === me.seat;
  return (
    <div className="stack stack--4">
      <p className="t-meta">{giver ? t("board.taboo.youGive") : t("board.taboo.youGuess", { name: nameOf(partner) })}</p>
      {giver && priv && (
        <div className="play-card">
          <span className="t-meta">{t("board.taboo.target")}</span>
          <p className="play-card__text">{priv.target}</p>
          <span className="t-meta">{t("board.taboo.forbidden")}</span>
          <List items={priv.forbidden.map((w: string) => <s key={w}>{w}</s>)} />
        </div>
      )}
      <ol className="stack stack--2 board-log">
        {c.clues.map((x: J, i: number) => (
          <li key={i} className="answer-block">
            <span className="t-meta">{t("board.taboo.clueN", { n: i + 1 })}{x.flagged ? ` · ${t("board.taboo.flagged")}` : ""}</span>
            <span className="answer-text">{x.text}</span>
            {c.guesses[i] && <span className={c.guesses[i].ok ? "strong" : "muted"}>→ {c.guesses[i].text} {c.guesses[i].ok ? "✓" : "✗"}</span>}
            {!giver && !x.flagged && !c.done && <Quiet busy={busy} onClick={() => void play("flag", { i })}>{t("board.taboo.flag")}</Quiet>}
          </li>
        ))}
        {c.guesses.slice(c.clues.length).map((g: J, i: number) => <li key={`g${i}`} className="muted">→ {g.text} ✗</li>)}
      </ol>
      {giver && c.phase === "clue" && <TextMove id="clue" label={t("board.taboo.clueLabel")} hint={t("board.taboo.clueHint")} max={80} busy={busy}
        button={t("board.send")} onSend={async (v) => (await play("clue", { text: v })).ok} />}
      {!giver && c.phase === "guess" && <TextMove id="guess" label={t("board.taboo.guessLabel", { n: c.guesses.length + 1, max: c.max })} max={40} busy={busy}
        button={t("board.propose")} onSend={async (v) => (await play("guess", { text: v })).ok} />}
    </div>
  );
}

function Anagram({ c, play, busy }: V) {
  const [order, setOrder] = useState<number[]>(() => c.letters.map((_: string, i: number) => i));
  useEffect(() => setOrder(c.letters.map((_: string, i: number) => i)), [c.letters]);
  const [pick, setPick] = useState<number | null>(null);
  const tap = (k: number) => {
    if (pick === null) return setPick(k);
    const next = [...order];
    [next[pick], next[k]] = [next[k], next[pick]];
    setOrder(next); setPick(null);
  };
  const word = order.map((i) => c.letters[i]).join("");
  return (
    <div className="stack stack--4">
      <p className="t-small muted">{t("board.anagram.hint")}</p>
      <div className="letter-row">
        {order.map((i, k) => (
          <button key={k} type="button" className="letter letter--btn" aria-pressed={pick === k} onClick={() => tap(k)}
            aria-label={t("board.anagram.letterAt", { l: c.letters[i], n: k + 1 })}>{c.letters[i]}</button>
        ))}
      </div>
      <button className="btn" disabled={busy} onClick={() => void play("propose", { word })}>{t("board.anagram.propose", { w: word })}</button>
      <TextMove id="ana" label={t("board.anagram.type")} max={20} busy={busy} button={t("board.propose")}
        onSend={async (v) => (await play("propose", { word: v })).ok} />
      {c.attempts.length > 0 && <List items={c.attempts.map((a: J) => `${a.word} ${a.ok ? "✓" : t("board.anagram.notInLexicon")}`)} />}
      <Quiet busy={busy} onClick={() => void play("giveup")}>{t("board.giveup")}</Quiet>
    </div>
  );
}

function Categories({ c, me, partner, play, busy }: V) {
  const [words, setWords] = useState<string[]>(() => c.categories.map(() => ""));
  const [verdicts, setVerdicts] = useState<Record<number, boolean>>({});
  if (c.phase === "write") {
    if (c.submitted?.[me.seat]) return <p className="center">{t("board.waitingOther", { name: nameOf(partner) })}</p>;
    return (
      <form className="stack stack--3" onSubmit={async (e) => { e.preventDefault(); await play("submit", { words }); }}>
        <p className="play-card__text">{t("board.categories.letter", { l: c.letter })}</p>
        {c.categories.map((cat: string, i: number) => (
          <div key={cat} className="field">
            <label className="field__label" htmlFor={`cat-${i}`}>{cat}</label>
            <input id={`cat-${i}`} className="input" maxLength={30} value={words[i]} autoComplete="off"
              onChange={(e) => setWords(words.map((w, k) => (k === i ? e.target.value : w)))} />
          </div>
        ))}
        <button className="btn" type="submit" disabled={busy}>{t("board.categories.submit")}</button>
      </form>
    );
  }
  const theirs = (c.words?.[partner?.seat ?? 0] ?? []) as J[];
  const toJudge = c.phase === "judge" && !c.judged?.[me.seat] && theirs.some((w) => w.status === "pending");
  return (
    <div className="stack stack--4">
      <p className="t-meta">{t("board.categories.letter", { l: c.letter })}</p>
      <div className="cat-table" role="table">
        <div role="row" className="cat-table__row cat-table__head">
          <span role="columnheader" />
          {[me, partner].map((p) => <span key={p?.seat} role="columnheader" className="t-meta">{nameOf(p)}</span>)}
        </div>
        {c.categories.map((cat: string, i: number) => (
          <div role="row" key={cat} className="cat-table__row">
            <span role="rowheader" className="t-small strong">{cat}</span>
            {[me, partner].map((p) => {
              const w = c.words?.[p?.seat ?? 0]?.[i];
              return <span role="cell" key={p?.seat}>{w?.text || "—"} <span className="t-meta">{w ? t(`board.categories.st.${w.status}` as MessageKey) : ""}</span></span>;
            })}
          </div>
        ))}
      </div>
      {toJudge && (
        <div className="card stack stack--3">
          <h3 className="t-card">{t("board.categories.judge", { name: nameOf(partner) })}</h3>
          {theirs.map((w, i) => w.status === "pending" && (
            <div key={i} className="row row--between row--wrap">
              <span>{c.categories[i]} : <strong>{w.text}</strong></span>
              <div className="chips" role="radiogroup" aria-label={w.text}>
                <button type="button" className="chip" role="radio" aria-checked={verdicts[i] === true} onClick={() => setVerdicts({ ...verdicts, [i]: true })}>{t("board.accept")}</button>
                <button type="button" className="chip" role="radio" aria-checked={verdicts[i] === false} onClick={() => setVerdicts({ ...verdicts, [i]: false })}>{t("board.refuse")}</button>
              </div>
            </div>
          ))}
          <button className="btn" disabled={busy || theirs.some((w, i) => w.status === "pending" && verdicts[i] === undefined)}
            onClick={() => void play("judge", { verdicts: theirs.map((_, i) => verdicts[i] ?? false) })}>{t("board.categories.confirmJudge")}</button>
        </div>
      )}
      {c.phase === "judge" && !toJudge && <p className="center muted">{t("board.waitingOther", { name: nameOf(partner) })}</p>}
    </div>
  );
}

const fold = (w: string) => w.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();

function WordChain({ c, play, busy, mine }: V) {
  const used = new Set(c.chain.map((x: J) => x.w));
  const last: string = c.chain[c.chain.length - 1].w;
  return (
    <div className="stack stack--4">
      <ol className="chain" aria-label={t("board.chain.chain")}>
        {c.chain.map((x: J, i: number) => <li key={i} className={x.restart ? "chain__restart" : ""}>{x.w}</li>)}
      </ol>
      <p className="t-small">{t("board.chain.progress", { n: c.added, max: c.target })} · {t("board.chain.startsWith", { l: last.slice(-1).toUpperCase() })}</p>
      <fieldset disabled={!mine || busy}>
        <legend className="t-small strong">{t("board.chain.reserve")}</legend>
        <div className="chips">
          {c.reserve.filter((w: string) => !used.has(w))
            .sort((a: string, b: string) => Number(fold(b)[0] === fold(last).slice(-1)) - Number(fold(a)[0] === fold(last).slice(-1)))
            .map((w: string) => (
            <button key={w} type="button" className="chip" onClick={() => void play("word", { text: w })}>{w}</button>
          ))}
        </div>
      </fieldset>
      {mine && (
        <div className="row row--wrap">
          <Quiet busy={busy} onClick={() => void play("pass")}>{t("board.pass")}</Quiet>
          <Quiet busy={busy} onClick={() => void play("restart")}>{t("board.chain.restart")}</Quiet>
        </div>
      )}
    </div>
  );
}

function Convergence({ c, me, partner, play, busy }: V) {
  return (
    <div className="stack stack--4">
      <div className="pair"><span className="play-card__text">{c.pair[0]}</span><span aria-hidden="true">+</span><span className="play-card__text">{c.pair[1]}</span></div>
      <p className="t-meta">{t("board.convergence.tour", { n: c.tour, max: c.max })}</p>
      {c.submitted?.[me.seat]
        ? <p className="center">{t("board.waitingOther", { name: nameOf(partner) })}</p>
        : <TextMove id="conv" label={t("board.convergence.label")} max={30} busy={busy} button={t("board.send")}
            onSend={async (v) => (await play("submit", { word: v })).ok} />}
      {c.history.length > 0 && (
        <ol className="stack stack--2 board-log">
          {c.history.map((h: J) => <li key={h.tour} className="answer-block">{t("board.convergence.tourN", { n: h.tour })} : {h.words["1"]} · {h.words["2"]} {h.match ? "✓" : ""}</li>)}
        </ol>
      )}
    </div>
  );
}

function Ladder({ c, play, busy, mine }: V) {
  return (
    <div className="stack stack--4">
      <div className="row row--between"><span className="tag">{t("board.ladder.from", { w: c.start })}</span><span className="tag">{t("board.ladder.to", { w: c.end })}</span></div>
      <ol className="chain" aria-label={t("board.chain.chain")}>{c.chain.map((w: string, i: number) => <li key={i}>{w}</li>)}</ol>
      {c.hint && <Alert kind="info">{t("board.ladder.hint", { w: c.hint })}</Alert>}
      {mine && <TextMove id="ladder" label={t("board.ladder.label", { w: c.current })} max={12} busy={busy} button={t("board.send")}
        onSend={async (v) => (await play("step", { word: v })).ok} />}
      <div className="row row--wrap">
        {mine && c.chain.length > 1 && <Quiet busy={busy} onClick={() => void play("back")}><Icon name="undo" size={18} />{t("board.ladder.back")}</Quiet>}
        <Quiet busy={busy} onClick={() => void play("hint")}><Icon name="bulb" size={18} />{t("board.ladder.askHint")}</Quiet>
        <Quiet busy={busy} onClick={() => void play("giveup")}>{t("board.giveup")}</Quiet>
      </div>
    </div>
  );
}

function inLine(f: J, r: number, col: number) {
  return r >= Math.min(f.r1, f.r2) && r <= Math.max(f.r1, f.r2) && col >= Math.min(f.c1, f.c2) && col <= Math.max(f.c1, f.c2);
}

function WordSearch({ c, play, busy }: V) {
  const [first, setFirst] = useState<[number, number] | null>(null);
  const [miss, setMiss] = useState(false);
  const found = new Set(c.found.map((f: J) => f.w));
  const tap = async (r: number, col: number) => {
    if (!first) { setFirst([r, col]); setMiss(false); return; }
    const [r1, c1] = first; setFirst(null);
    if (r1 === r && c1 === col) return;
    const res = await play("select", { r1, c1, r2: r, c2: col });
    setMiss(res.ok && res.info?.hit === false);
  };
  return (
    <div className="stack stack--4">
      <p className="t-small muted">{first ? t("board.search.second") : t("board.search.first")}</p>
      <div className="letter-grid" role="grid" aria-label={t("board.search.grid")}>
        {c.grid.map((row: string, r: number) => (
          <div key={r} role="row" className="letter-grid__row">
            {row.split("").map((l, col) => {
              const on = c.found.some((f: J) => inLine(f, r, col));
              const sel = first && first[0] === r && first[1] === col;
              return (
                <button key={col} role="gridcell" type="button" disabled={busy}
                  className={`letter letter--btn ${on ? "letter--found" : ""}`} aria-pressed={Boolean(sel)}
                  aria-label={t("board.search.cell", { l, r: r + 1, c: col + 1 })} onClick={() => void tap(r, col)}>{l}</button>
              );
            })}
          </div>
        ))}
      </div>
      {miss && <p className="t-small" role="status">{t("board.search.miss")}</p>}
      <List items={c.words.map((w: string) => (found.has(w) ? <s key={w}>{w}</s> : w))} />
      <Quiet busy={busy} onClick={() => void play("giveup")}>{t("board.giveup")}</Quiet>
    </div>
  );
}

const ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

function Masked({ c, play, busy, mine }: V) {
  return (
    <div className="stack stack--4">
      <Letters letters={c.mask} label={t("board.masked.mask", { n: c.len })} />
      <p className="t-small">{t("board.masked.errors", { n: c.errors, max: c.max })}</p>
      <fieldset disabled={!mine || busy}>
        <legend className="sr-only">{t("board.masked.pickLetter")}</legend>
        <div className="keyboard">
          {ALPHA.map((l) => (
            <button key={l} type="button" className="key" disabled={c.tried.includes(l)} onClick={() => void play("letter", { letter: l })}>{l}</button>
          ))}
        </div>
      </fieldset>
      {mine && <TextMove id="masked" label={t("board.masked.word")} max={20} busy={busy} button={t("board.propose")}
        onSend={async (v) => (await play("word", { word: v })).ok} />}
      {c.wrong_words.length > 0 && <List items={c.wrong_words.map((w: string) => `${w} ✗`)} />}
      {!c.hint_used && <Quiet busy={busy} onClick={() => void play("hint")}><Icon name="bulb" size={18} />{t("board.masked.hint")}</Quiet>}
    </div>
  );
}

function Syllables({ c, play, busy }: V) {
  const [word, setWord] = useState<number[]>([]);
  useEffect(() => setWord([]), [c.tiles]);
  const tile = (id: number) => c.tiles.find((x: J) => x.id === id)?.t ?? "";
  return (
    <div className="stack stack--4">
      <div className="letter-row letter-row--word" aria-live="polite" aria-label={t("board.syllables.word")}>
        {word.length ? word.map((id) => (
          <button key={id} type="button" className="frag frag--on" onClick={() => setWord(word.filter((x) => x !== id))}>{tile(id)}</button>
        )) : <span className="muted">{t("board.syllables.empty")}</span>}
      </div>
      <div className="chips">
        {c.tiles.filter((x: J) => !word.includes(x.id)).map((x: J) => (
          <button key={x.id} type="button" className="frag" onClick={() => setWord([...word, x.id])}>{x.t}</button>
        ))}
      </div>
      {c.attempts > 0 && <p className="t-meta">{t("board.syllables.attempts", { n: c.attempts })}</p>}
      <button className="btn" disabled={busy || !word.length} onClick={() => void play("submit", { order: word })}>{t("board.syllables.submit")}</button>
      <Quiet busy={busy} onClick={() => void play("giveup")}>{t("board.giveup")}</Quiet>
    </div>
  );
}

function Market({ c, me, partner, play, busy, mine }: V) {
  const mineL = c.market.filter((x: J) => x.owner === me.seat).map((x: J) => x.l);
  if (c.phase === "buy") {
    return (
      <div className="stack stack--4">
        <p className="t-small">{t("board.market.wallet", { n: c.tokens[me.seat], b: c.buys[me.seat] })}</p>
        <div><span className="t-meta">{t("board.market.base")}</span><Letters letters={[...c.base, ...mineL]} /></div>
        <fieldset disabled={!mine || busy}>
          <legend className="t-small strong">{t("board.market.market")}</legend>
          <div className="chips">
            {c.market.map((x: J) => (
              <button key={x.id} type="button" className="chip" disabled={x.owner !== null || x.cost > c.tokens[me.seat]}
                onClick={() => void play("buy", { id: x.id })}
                aria-label={x.owner ? t("board.market.taken", { l: x.l, name: bySeat(me, partner, x.owner) }) : t("board.market.buyL", { l: x.l, n: x.cost })}>
                <strong>{x.l}</strong> · {x.owner ? (x.owner === me.seat ? t("game.you") : nameOf(partner)) : x.cost}
              </button>
            ))}
          </div>
        </fieldset>
        {mine && !c.stopped[me.seat] && <Quiet busy={busy} onClick={() => void play("stop")}>{t("board.market.stop")}</Quiet>}
      </div>
    );
  }
  if (c.submitted?.[me.seat]) return <p className="center">{t("board.waitingOther", { name: nameOf(partner) })}</p>;
  return (
    <div className="stack stack--4">
      <div><span className="t-meta">{t("board.market.yourLetters")}</span><Letters letters={[...c.base, ...mineL]} /></div>
      <TextMove id="market" label={t("board.market.compose")} hint={t("board.market.composeHint")} max={20} busy={busy}
        button={t("board.send")} onSend={async (v) => (await play("submit", { word: v })).ok} />
      <Quiet busy={busy} onClick={() => void play("submit", { word: "" })}>{t("board.market.noWord")}</Quiet>
    </div>
  );
}

function Intruder({ c, me, partner, play, busy }: V) {
  if (c.submitted?.[me.seat]) return <p className="center">{t("board.waitingOther", { name: nameOf(partner) })}</p>;
  return (
    <div className="stack stack--4">
      <p className="play-card__text">{t("board.intruder.family", { f: c.category })}</p>
      <div className="stack stack--2">
        {c.items.map((w: string, i: number) => <button key={w} className="btn btn--secondary" disabled={busy} onClick={() => void play("pick", { i })}>{w}</button>)}
      </div>
    </div>
  );
}

function Telegram({ c, priv, me, partner, play, busy, mine }: V) {
  const sender = c.sender === me.seat;
  return (
    <div className="stack stack--4">
      {sender && priv?.scene && <div className="play-card"><span className="t-meta">{t("board.telegram.scene")}</span><p className="play-card__text">{priv.scene}</p></div>}
      {c.telegram && <div className="card card--soft"><span className="t-meta">{t("board.telegram.telegram")}</span><p className="play-card__text">{c.telegram.join(" · ")}</p></div>}
      {c.guess && <div className="answer-block"><span className="t-meta">{t("board.telegram.guessOf", { name: bySeat(me, partner, c.receiver) })}</span><p className="answer-text">{c.guess}</p></div>}
      {c.scene && <p className="t-small">{t("board.telegram.wasScene", { s: c.scene })}</p>}
      {mine && c.phase === "write" && <TextMove id="tel" label={t("board.telegram.write")} hint={t("board.telegram.writeHint")} max={120} busy={busy}
        button={t("board.send")} onSend={async (v) => (await play("telegram", { text: v })).ok} />}
      {mine && c.phase === "guess" && <TextMove id="telg" label={t("board.telegram.rebuild")} max={60} busy={busy}
        button={t("board.send")} onSend={async (v) => (await play("guess", { text: v })).ok} />}
      {mine && c.phase === "judge" && (
        <div className="stack stack--2">
          <p className="strong">{t("board.telegram.judge")}</p>
          <button className="btn" disabled={busy} onClick={() => void play("judge", { ok: true })}>{t("board.telegram.passed")}</button>
          <button className="btn btn--secondary" disabled={busy} onClick={() => void play("judge", { ok: false })}>{t("board.telegram.notPassed")}</button>
        </div>
      )}
    </div>
  );
}

function Rhymes({ c, play, busy, mine }: V) {
  const [phrase, setPhrase] = useState("");
  return (
    <div className="stack stack--4">
      <p className="play-card__text">{t("board.rhymes.sound", { s: c.sound })}</p>
      <p className="t-small">{t("board.rhymes.progress", { n: c.found.length, max: c.count })}</p>
      {c.found.length > 0 && <ol className="stack stack--2 board-log">{c.found.map((f: J) => <li key={f.w}><strong>{f.w}</strong>{f.phrase ? ` — ${f.phrase}` : ""}</li>)}</ol>}
      {c.hint && <Alert kind="info">{t("board.rhymes.hint", { s: c.hint.start, n: c.hint.len })}</Alert>}
      {mine && (
        <>
          <div className="field">
            <label className="field__label" htmlFor="rh-phrase">{t("board.rhymes.phrase")}</label>
            <input id="rh-phrase" className="input" maxLength={80} value={phrase} onChange={(e) => setPhrase(e.target.value)} />
          </div>
          <TextMove id="rh" label={t("board.rhymes.word")} max={30} busy={busy} button={t("board.send")}
            onSend={async (v) => { const ok = (await play("word", { text: v, phrase })).ok; if (ok) setPhrase(""); return ok; }} />
          <Quiet busy={busy} onClick={() => void play("pass")}>{t("board.pass")}</Quiet>
        </>
      )}
      <Quiet busy={busy} onClick={() => void play("hint")}><Icon name="bulb" size={18} />{t("board.rhymes.askHint")}</Quiet>
    </div>
  );
}

function ClueGrid({ c, priv, me, partner, play, busy, mine }: V) {
  const giver = c.giver === me.seat;
  const roles: string[] | undefined = priv?.roles;
  const clue = c.clues[c.clues.length - 1];
  return (
    <div className="stack stack--4">
      <p className="t-meta">{giver ? t("board.clue.youGive") : t("board.clue.youGuess", { name: nameOf(partner) })} · {t("board.clue.tour", { n: c.tour, max: c.max_tours })} · {t("board.clue.found", { n: c.found })}</p>
      {clue && c.phase === "guess" && <p className="play-card__text">{t("board.clue.clue", { w: clue.word })}</p>}
      <div className="clue-grid">
        {c.words.map((w: string, i: number) => {
          const shown = c.revealed[String(i)] ?? (giver ? roles?.[i] : undefined);
          return (
            <button key={i} type="button" className={`clue-card ${shown ? `clue-card--${shown}` : ""} ${c.revealed[String(i)] ? "clue-card--open" : ""}`}
              disabled={busy || giver || !mine || c.phase !== "guess" || Boolean(c.revealed[String(i)])}
              onClick={() => void play("pick", { i })}>
              <span>{w}</span>{shown && <span className="t-meta">{t(`board.clue.role.${shown}` as MessageKey)}</span>}
            </button>
          );
        })}
      </div>
      {giver && mine && c.phase === "clue" && <TextMove id="cg" label={t("board.clue.give")} hint={t("board.clue.giveHint")} max={24} busy={busy}
        button={t("board.send")} onSend={async (v) => (await play("clue", { word: v })).ok} />}
      {!giver && mine && c.phase === "guess" && (
        <>
          <p className="t-small">{t("board.clue.picksLeft", { n: c.picks_left })}</p>
          <Quiet busy={busy} onClick={() => void play("stop")}>{t("board.clue.stop")}</Quiet>
        </>
      )}
    </div>
  );
}

function Sentence({ c, me, partner, play, busy, mine }: V) {
  const [from, setFrom] = useState<number | null>(null);
  const text = (id: number) => c.tiles.find((x: J) => x.id === id)?.t ?? "";
  return (
    <div className="stack stack--4">
      <p className="t-small">{t("board.sentence.moves", { n: c.moves, max: c.max })}</p>
      <ol className="frag-list">
        {c.order.map((id: number, k: number) => (
          <li key={id}>
            <button type="button" className="frag" aria-pressed={from === k} disabled={!mine || busy}
              onClick={() => { if (from === null) setFrom(k); else { const f = from; setFrom(null); if (f !== k) void play("move", { from: f, to: k }); } }}>
              {text(id)}
            </button>
          </li>
        ))}
      </ol>
      {mine && <p className="t-meta">{from === null ? t("board.sentence.pick") : t("board.sentence.place")}</p>}
      <p className="answer-text">{c.order.map(text).join(" ")}</p>
      {c.agree?.[me.seat] === undefined
        ? <Quiet busy={busy} onClick={() => void play("agree")}>{t("board.sentence.agree")}</Quiet>
        : <p className="t-meta">{t("board.sentence.agreeWait", { name: nameOf(partner) })}</p>}
    </div>
  );
}

function Growth({ c, play, busy, mine }: V) {
  return (
    <div className="stack stack--4">
      <ol className="chain">{c.chain.map((w: string) => <li key={w}>{w}</li>)}</ol>
      {c.hint && <Alert kind="info">{t("board.growth.hint", { l: c.hint })}</Alert>}
      {mine && <TextMove id="grow" label={t("board.growth.label", { w: c.current })} max={20} busy={busy} button={t("board.send")}
        onSend={async (v) => (await play("grow", { word: v })).ok} />}
      <div className="row row--wrap">
        <Quiet busy={busy} onClick={() => void play("hint")}><Icon name="bulb" size={18} />{t("board.growth.askHint")}</Quiet>
        <Quiet busy={busy} onClick={() => void play("giveup")}>{t("board.giveup")}</Quiet>
      </div>
    </div>
  );
}

function Cross({ c, me, partner, play, busy }: V) {
  const horizontal = c.a === me.seat;
  const [ids, setIds] = useState<number[]>(() => c.props?.[me.seat] ?? []);
  const letter = (id: number) => c.tiles.find((x: J) => x.id === id)?.l ?? "";
  const theirs: number[] = c.props?.[partner?.seat ?? 0] ?? [];
  return (
    <div className="stack stack--4">
      <p className="t-meta">{horizontal ? t("board.cross.youH") : t("board.cross.youV")}</p>
      <div className="letter-row" aria-label={t("board.cross.yourWord")}>
        {[0, 1, 2, 3, 4].map((k) => (
          <button key={k} type="button" className={`letter letter--btn ${k === 2 ? "letter--center" : ""}`}
            aria-label={t("board.cross.slot", { n: k + 1, l: ids[k] !== undefined ? letter(ids[k]) : "—" })}
            onClick={() => setIds(ids.slice(0, k))}>{ids[k] !== undefined ? letter(ids[k]) : ""}</button>
        ))}
      </div>
      <p className="t-meta">{t("board.cross.centerHint")}</p>
      <div className="chips">
        {c.tiles.filter((x: J) => !ids.includes(x.id)).map((x: J) => (
          <button key={x.id} type="button" className={`frag ${theirs.includes(x.id) ? "frag--theirs" : ""}`} disabled={ids.length >= 5}
            onClick={() => setIds([...ids, x.id])}>{x.l}</button>
        ))}
      </div>
      {theirs.length > 0 && <p className="t-small">{t("board.cross.theirs", { name: nameOf(partner), w: theirs.map(letter).join(""), ok: c.ok?.[partner?.seat ?? 0] ? "✓" : "…" })}</p>}
      {c.props?.[me.seat] && <p className="t-small">{c.ok?.[me.seat] ? t("board.cross.okMine") : t("board.cross.notYet")}</p>}
      <button className="btn" disabled={busy || ids.length !== 5} onClick={() => void play("propose", { ids })}>{t("board.propose")}</button>
    </div>
  );
}

function Rebus({ c, play, busy }: V) {
  return (
    <div className="stack stack--4">
      <div className="rebus" role="img" aria-label={c.readings ? c.readings.join(" + ") : t("board.rebus.images")}>
        {c.icons.map((x: J, i: number) => (
          <figure key={i} className="rebus__item">
            <img src={x.src} alt="" width={88} height={88} />
            {c.readings && <figcaption className="t-small">{c.readings[i]}</figcaption>}
          </figure>
        ))}
      </div>
      <p className="t-small">{t("board.rebus.tries", { n: c.tries.length, max: c.max })}</p>
      {c.tries.length > 0 && <List items={c.tries.map((x: J) => `${x.text} ${x.ok ? "✓" : "✗"}`)} />}
      <TextMove id="rebus" label={t("board.rebus.label")} max={30} busy={busy} button={t("board.propose")}
        onSend={async (v) => (await play("propose", { text: v })).ok} />
      {!c.readings && <Quiet busy={busy} onClick={() => void play("hint")}><Icon name="bulb" size={18} />{t("board.rebus.hint")}</Quiet>}
    </div>
  );
}

const VIEWS: Record<string, ComponentType<V>> = {
  taboo: Taboo, anagram: Anagram, categories: Categories, word_chain: WordChain, convergence: Convergence,
  word_ladder: Ladder, word_search: WordSearch, masked_word: Masked, syllables: Syllables, letter_market: Market,
  semantic_intruder: Intruder, telegram: Telegram, rhymes: Rhymes, clue_grid: ClueGrid, sentence_order: Sentence,
  word_growth: Growth, cross_letters: Cross, rebus: Rebus,
  ...CREATION_VIEWS,
  ...MEMORY_VIEWS,
  ...MINI_VIEWS,
};

// ---------------------------------------------------------------------------
// Fin de manche : ce qui s'est passé et la solution
// ---------------------------------------------------------------------------
function Solution({ round, st }: { round: BRound; st: SessionState }) {
  const c = round.card, s = round.solution ?? {};
  if (isCreationMech(c.mech)) return <CreationSolution c={c} s={s} players={st.players} title={st.game.title} />;
  if (isMemoryMech(c.mech)) return <MemorySolution c={c} s={s} players={st.players} />;
  if (isMiniMech(c.mech)) return <MiniSolution c={c} players={st.players} />;
  const line = (k: MessageKey, vars: Record<string, string | number>) => <p>{t(k, vars)}</p>;
  switch (c.mech) {
    case "taboo": return line("board.sol.word", { w: s.target ?? "" });
    case "anagram": return line("board.sol.accepted", { w: (s.accepted ?? []).join(", ") });
    case "categories": return (
      <div className="stack stack--2">
        {st.players.map((p) => (
          <p key={p.seat}>{nameOf(p)} : {(c.words?.[p.seat] ?? []).map((w: J) => w.text || "—").join(", ")} ({c.scores?.[p.seat] ?? 0})</p>
        ))}
        <p className="t-meta">{t("board.sol.examples", { w: (s.examples ?? []).join(", ") })}</p>
      </div>
    );
    case "word_ladder": return line("board.sol.path", { w: (s.path ?? []).join(" → ") });
    case "word_search": return line("board.sol.words", { w: (c.words ?? []).join(", ") });
    case "masked_word": return line("board.sol.word", { w: s.word ?? "" });
    case "syllables": return line("board.sol.word", { w: `${s.word} (${(s.parts ?? []).join(" / ")})` });
    case "letter_market": return (
      <div className="stack stack--2">
        {st.players.map((p) => <p key={p.seat}>{nameOf(p)} : <strong>{c.words?.[p.seat] || "—"}</strong> ({c.scores?.[p.seat] ?? 0})</p>)}
        <p className="t-meta">{t("board.sol.examples", { w: (s.examples ?? []).join(", ") })}</p>
      </div>
    );
    case "semantic_intruder": return (
      <div className="stack stack--2">
        <p>{t("board.sol.intruder", { w: s.answer ?? "", r: s.reason ?? "" })}</p>
        {st.players.map((p) => <p key={p.seat} className="t-small">{nameOf(p)} : {c.items?.[c.picks?.[p.seat]]} {c.scores?.[p.seat] ? "✓" : ""}</p>)}
      </div>
    );
    case "telegram": return line("board.sol.scene", { w: s.scene ?? "" });
    case "rhymes": return line("board.sol.words", { w: (s.words ?? []).join(", ") });
    case "clue_grid": return line("board.sol.targets", { w: (c.words ?? []).filter((_: string, i: number) => s.roles?.[i] === "target").join(", ") });
    case "sentence_order": return line("board.sol.sentence", { w: s.text ?? "" });
    case "word_growth": return line("board.sol.path", { w: (s.accepted ?? []).join(" → ") });
    case "cross_letters": return line("board.sol.cross", { h: s.horizontal ?? "", v: s.vertical ?? "" });
    case "rebus": return <p>{t("board.sol.word", { w: s.answer ?? "" })} — {s.explanation}</p>;
    default: return null;
  }
}

function RoundEnd({ c, round }: { c: Common; round: BRound }) {
  const card = round.card;
  const duel = Boolean(card.scores);
  return (
    <section className="card stack stack--3 enter" aria-live="polite">
      <h2 className="t-section">{duel ? t("board.roundDone") : card.success ? t("board.success") : t("board.notThisTime")}</h2>
      <Solution round={round} st={c.st} />
      {duel && <p className="t-small">{c.st.players.map((p) => `${nameOf(p)} : ${card.scores[p.seat] ?? 0}`).join(" · ")}</p>}
      {!duel && card.points > 0 && <p className="t-small">{t("board.points", { n: card.points })}</p>}
    </section>
  );
}

// ---------------------------------------------------------------------------
// Écran de jeu
// ---------------------------------------------------------------------------
export function BoardPlaying(c: Common) {
  const [err, setErr] = useState<string | null>(null);
  const round = roundsOf(c.st).find((r) => r.round_no === c.st.session.current_round);
  const me = c.st.players.find((p) => p.is_me)!;
  const partner = c.st.players.find((p) => !p.is_me);
  const total = c.st.session.total_rounds;
  useEffect(() => setErr(null), [round?.round_no]);
  if (!round) return <Loading />;
  const card = round.card;
  const play: Play = async (type, payload = {}) => {
    setErr(null);
    const res = await c.run("play_move", { p_round: round.round_no, p_action: crypto.randomUUID(), p_type: type, p_payload: payload });
    if (!res.ok && res.error !== "busy" && res.error !== "stale_round") setErr(moveError(res.error));
    return res;
  };
  const View = VIEWS[card.mech];
  const mine = card.turn === me.seat;
  const turnBased = typeof card.turn === "number";
  return (
    <section className="stack stack--5" key={round.round_no}>
      <div className="row row--between">
        <span className="t-meta">{t("board.roundOf", { n: round.round_no, total })}</span>
        {turnBased && !card.done && <Turn mine={mine} other={nameOf(partner)} />}
      </div>
      {card.done ? <RoundEnd c={c} round={round} /> : View ? <View c={card} priv={round.private} me={me} partner={partner} play={play} busy={c.busy || !c.online} mine={mine} /> : null}
      {err && <Alert>{err}</Alert>}
      {card.done && round.round_no < total && (
        <div className="action-bar">
          <button className="btn" disabled={c.busy || !c.online} onClick={() => c.run("next_round", { p_from_round: round.round_no })}>
            {t("board.nextRound")}<Icon name="arrow-right" />
          </button>
        </div>
      )}
    </section>
  );
}

export function BoardResults({ c, navigate }: { c: Common; navigate: (to: string) => void }) {
  const result = c.st.session.result as { points?: Record<string, number>; common?: number; rounds?: number; success?: number } | undefined;
  const ended = c.st.session.status === "ended" && !c.st.session.read_only;
  const rounds = roundsOf(c.st).filter((r) => r.revealed);
  const creation = Boolean((c.st.game.config as unknown as { creation?: boolean }).creation);
  const me = c.st.players.find((p) => p.is_me);
  const partner = c.st.players.find((p) => !p.is_me);
  const bothKeep = c.st.players.every((p) => p.keep_memory);
  return (
    <section className="stack stack--6">
      {isMiniMech(c.st.game.mechanic) ? <div className="result-emblem"><Art name={`custom-${(c.st.game.config as unknown as {code:string}).code}`} size={72} /></div> : <Illustration name="11-fin-de-partie" className="public__art" />}
      <div className="page-header center">
        <h1 className="t-page">{t("game.endTitle")}</h1>
        <p>{t("game.endText", { title: c.st.game.title })}</p>
      </div>
      {result?.points && (
        <div className="card stack stack--2">
          <h2 className="t-card">{isMiniMech(c.st.game.mechanic) ? t("mini.finalScore") : t("rounds.points")}</h2>
          <div className="result-scores">{c.st.players.map((p) => <div key={p.seat}><span>{nameOf(p)}</span><strong>{result.points![String(p.seat)] ?? 0}</strong></div>)}</div>
        </div>
      )}
      {result?.common !== undefined && !creation && (
        <div className="card stack stack--2">
          <h2 className="t-card">{t("board.together")}</h2>
          <p>{t("board.resultCommon", { n: result.common, s: result.success ?? 0, r: result.rounds ?? rounds.length })}</p>
        </div>
      )}
      {creation && rounds.map((r) => (
        <section key={r.round_no} className="card stack stack--3">
          <h2 className="t-card">{rounds.length > 1 ? t("cr.creationN", { n: r.round_no }) : t("cr.creation")}</h2>
          <Solution round={r} st={c.st} />
        </section>
      ))}
      {!creation && rounds.map((r) => (
        <details key={r.round_no} className="card">
          <summary className="strong">{t("board.roundOf", { n: r.round_no, total: c.st.session.total_rounds })} · {r.card.scores
            ? c.st.players.map((p) => `${nameOf(p)} ${r.card.scores[p.seat] ?? 0}`).join(" · ") : r.card.success ? "✓" : "—"}</summary>
          <Solution round={r} st={c.st} />
        </details>
      ))}
      {ended && creation && (
        <div className="group">
          <label className="switch-row">
            <span className="switch-row__text">
              <span>{t("game.keepMemory")}</span>
              <span className="t-meta">{bothKeep ? t("game.keepBoth") : me?.keep_memory ? t("game.keepWaiting", { name: nameOf(partner) }) : t("cr.keepHint")}</span>
            </span>
            <input className="switch" type="checkbox" role="switch" checked={Boolean(me?.keep_memory)} disabled={c.busy || !c.online}
              onChange={(e) => c.run("set_keep_memory", { p_keep: e.target.checked })} />
          </label>
        </div>
      )}
      {ended && (
        <div className="stack">
          <button className="btn" disabled={c.busy || !c.online} onClick={async () => { if ((await c.run("close_session")).ok) navigate(`/bibliotheques/${c.st.session.game_id}`); }}>{t("game.replay")}</button>
          <button className="btn btn--secondary" disabled={c.busy || !c.online} onClick={async () => { if ((await c.run("close_session")).ok) navigate("/bibliotheques"); }}>{t("game.otherGame")}</button>
        </div>
      )}
      <Link className="btn btn--quiet" to="/accueil">{t("game.home")}</Link>
    </section>
  );
}
