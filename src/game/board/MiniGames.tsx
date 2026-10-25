/* eslint-disable @typescript-eslint/no-explicit-any */
// Mini-jeux du lot 2 : Morpion, Points et carrés, Pierre-feuille-ciseaux, Dé chanceux, Bataille navale.
// Les pièces viennent du kit interface v2 ; tirages, tours, scores et secrets viennent du serveur.
import { useEffect, useMemo, useRef, useState, type ComponentType, type ReactNode } from "react";
import { t } from "../../i18n";
import { Icon } from "../../components/ui";
import type { Player } from "../../lib/types";

type J = any;
type Play = (type: string, payload?: Record<string, unknown>) => Promise<{ ok: boolean; error?: string; info?: J }>;
interface V { c: J; priv: J; me: Player; partner?: Player; play: Play; busy: boolean; mine: boolean }

const PIECES = "/assets/v2/jeux";
const nameOf = (p?: Player) => (p ? (p.is_me ? t("game.you") : p.display_name || "?") : "?");
const seatName = (me: Player, partner: Player | undefined, seat: number) => nameOf(seat === me.seat ? me : partner);

export const MINI_MECHS = ["tic_tac_toe", "dots_boxes", "rps", "nd_pig", "battleship"];
export const isMiniMech = (m?: string) => Boolean(m && MINI_MECHS.includes(m));

/** Score de série (Morpion, Pierre-feuille-ciseaux) : victoires des manches précédentes et objectif. */
function Series({ c, me, partner }: { c: J; me: Player; partner?: Player }) {
  const s = c.series ?? {};
  return (
    <p className="mini-series t-meta" aria-label={t("mini.seriesLabel")}>
      <span><strong>{nameOf(me)}</strong> {s[me.seat] ?? 0}</span>
      <span>·</span>
      <span><strong>{nameOf(partner)}</strong> {partner ? s[partner.seat] ?? 0 : 0}</span>
      <span className="grow" />
      <span>{t("mini.target", { n: c.target })}</span>
    </p>
  );
}

// ---------------------------------------------------------------------------
// Morpion
// ---------------------------------------------------------------------------
function symbolOf(c: J, seat: number) {
  return seat === c.x_seat ? "x" : "o";
}

function TicTacToeBoard({ c, me, partner, play, busy, mine }: V & { readOnly?: boolean }) {
  const win: number[] = c.line ?? [];
  return (
    <div className="ttt" role="group" aria-label={t("mini.ttt.board")}>
      {(c.board as number[]).map((v, i) => {
        const label = v ? t("mini.ttt.cellTaken", { n: i + 1, who: seatName(me, partner, v), s: symbolOf(c, v).toUpperCase() }) : t("mini.ttt.cellFree", { n: i + 1 });
        return (
          <button key={i} type="button" className={`ttt__cell${win.includes(i) ? " ttt__cell--win" : ""}`}
            disabled={busy || !mine || Boolean(v) || c.done} aria-label={label}
            onClick={() => void play("place", { cell: i })}>
            {v ? <img src={`${PIECES}/pion-${symbolOf(c, v)}.svg`} alt="" width={56} height={56} /> : null}
          </button>
        );
      })}
    </div>
  );
}

function TicTacToe(v: V) {
  const { c, me } = v;
  return (
    <div className="stack stack--4">
      <Series c={c} me={me} partner={v.partner} />
      <p className="t-small">{t("mini.ttt.youAre", { s: symbolOf(c, me.seat).toUpperCase() })}</p>
      <TicTacToeBoard {...v} />
    </div>
  );
}

// ---------------------------------------------------------------------------
// Points et carrés : grille 9 × 9 (points, arêtes, cases) ; arêtes h:r:c et v:r:c.
// ---------------------------------------------------------------------------
function DotsBoard({ c, me, partner, play, busy, mine }: V) {
  const cells = [];
  const colorOf = (seat?: number) => (seat ? (seat === me.seat ? "me" : "them") : "");
  for (let gr = 0; gr < 9; gr++) {
    for (let gc = 0; gc < 9; gc++) {
      const key = `${gr}-${gc}`;
      if (gr % 2 === 0 && gc % 2 === 0) {
        cells.push(<span key={key} className="dots__dot" aria-hidden="true" />);
      } else if (gr % 2 === 0 || gc % 2 === 0) {
        const id = gr % 2 === 0 ? `h:${gr / 2}:${(gc - 1) / 2}` : `v:${(gr - 1) / 2}:${gc / 2}`;
        const owner = c.edges?.[id];
        const label = gr % 2 === 0
          ? t("mini.dots.hEdge", { r: gr / 2 + 1, c: (gc - 1) / 2 + 1 })
          : t("mini.dots.vEdge", { r: (gr - 1) / 2 + 1, c: gc / 2 + 1 });
        cells.push(
          <button key={key} type="button" className={`dots__edge dots__edge--${gr % 2 === 0 ? "h" : "v"} ${owner ? `dots__edge--on dots__edge--${colorOf(owner)}` : ""}`}
            disabled={busy || !mine || Boolean(owner) || c.done} aria-pressed={Boolean(owner)}
            aria-label={owner ? `${label}, ${seatName(me, partner, owner)}` : label}
            onClick={() => void play("draw_edge", { edge_id: id })} />,
        );
      } else {
        const box = ((gr - 1) / 2) * 4 + (gc - 1) / 2;
        const owner = c.owner?.[box];
        cells.push(
          <span key={key} className={`dots__box ${owner ? `dots__box--${colorOf(owner)}` : ""}`}
            aria-label={owner ? t("mini.dots.boxOf", { name: seatName(me, partner, owner) }) : undefined}>
            {owner ? (owner === me.seat ? nameOf(me) : nameOf(partner)).slice(0, 1).toUpperCase() : ""}
          </span>,
        );
      }
    }
  }
  return <Zoomable zoomClass="board-zoom--dots"><div className="dots" role="group" aria-label={t("mini.dots.board")}>{cells}</div></Zoomable>;
}

function Scoreline({ me, partner, values, label }: { me: Player; partner?: Player; values: J; label: string }) {
  return (
    <div className="mini-scores" aria-label={label}>
      <div className="mini-scores__item mini-scores__item--me"><span className="t-meta">{nameOf(me)}</span><span className="t-score">{values?.[me.seat] ?? 0}</span></div>
      <div className="mini-scores__item"><span className="t-meta">{nameOf(partner)}</span><span className="t-score">{partner ? values?.[partner.seat] ?? 0 : 0}</span></div>
    </div>
  );
}

function DotsBoxes(v: V) {
  return (
    <div className="stack stack--4">
      <Scoreline me={v.me} partner={v.partner} values={v.c.tally} label={t("mini.dots.scores")} />
      <p className="t-meta">{t("mini.dots.hint")}</p>
      <DotsBoard {...v} />
    </div>
  );
}

// ---------------------------------------------------------------------------
// Pierre, feuille, ciseaux : choix privé, verrouillage, échéance serveur de 30 s.
// ---------------------------------------------------------------------------
const GESTURES = [
  { id: "rock", img: "pfc-pierre" },
  { id: "paper", img: "pfc-feuille" },
  { id: "scissors", img: "pfc-ciseaux" },
] as const;

function useCountdown(deadline?: string) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 250);
    return () => clearInterval(id);
  }, []);
  return deadline ? Math.max(0, Math.ceil((new Date(deadline).getTime() - now) / 1000)) : 0;
}

function Rps({ c, priv, me, partner, play, busy }: V) {
  const [pick, setPick] = useState<string | null>(null);
  const left = useCountdown(c.deadline_at);
  const locked = Boolean(c.locked?.[me.seat]);
  const theirs = Boolean(partner && c.locked?.[partner.seat]);
  const asked = useRef(false);
  // À l'échéance, on demande au serveur d'annuler la manche ; il vérifie lui-même l'heure.
  useEffect(() => {
    if (left > 0 || c.done || asked.current) return;
    asked.current = true;
    const tryExpire = async () => {
      const r = await play("expire");
      if (!r.ok && r.error === "too_early") setTimeout(() => void tryExpire(), 1500);
    };
    void tryExpire();
  }, [left, c.done, play]);
  const mineGesture = priv?.gesture as string | undefined;
  return (
    <div className="stack stack--4">
      <Series c={c} me={me} partner={partner} />
      <div className="rps-timer" role="timer" aria-live="off">
        <Icon name="timer" size={20} /><span className="t-score">{left}</span><span className="t-meta">{t("mini.rps.seconds")}</span>
      </div>
      <div className="rps" role="radiogroup" aria-label={t("mini.rps.choose")}>
        {GESTURES.map((g) => {
          const selected = locked ? mineGesture === g.id : pick === g.id;
          return (
            <button key={g.id} type="button" role="radio" aria-checked={selected} className="rps__choice"
              disabled={busy || locked || left === 0} onClick={() => setPick(g.id)}>
              <img src={`${PIECES}/${g.img}.svg`} alt="" width={72} height={72} />
              <span>{t(`mini.rps.${g.id}` as never)}</span>
            </button>
          );
        })}
      </div>
      {locked ? (
        <p className="nd-chip"><Icon name="lock-keyhole" size={16} />{t("mini.rps.locked")}</p>
      ) : (
        <button className="btn" disabled={busy || !pick || left === 0} onClick={() => pick && void play("lock_gesture", { gesture: pick })}>
          <Icon name="lock-keyhole" size={18} />{t("mini.rps.lock")}
        </button>
      )}
      <p className="t-meta row"><Icon name={theirs ? "check" : "clock"} size={16} />{theirs ? t("mini.rps.partnerLocked", { name: nameOf(partner) }) : t("mini.rps.partnerChoosing", { name: nameOf(partner) })}</p>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Le Dé chanceux : le serveur donne la face ; l'écran ne tire rien.
// ---------------------------------------------------------------------------
function PigCounter({ who, value, target, active }: { who: string; value: number; target: number; active: boolean }) {
  const pct = Math.min(100, (100 * value) / Math.max(1, target));
  return (
    <div className={`pig-counter${active ? " is-active" : ""}`}>
      <span className="pig-counter__who">{who}</span>
      <span className="pig-counter__val"><strong>{value}</strong>/{target}</span>
      <span className="pig-counter__bar" aria-hidden="true"><span style={{ width: `${pct}%` }} /></span>
    </div>
  );
}

function Pig({ c, me, partner, play, busy, mine }: V) {
  const last = c.log?.[0];
  const target = Number(c.target ?? 30);
  const rolls = (c.rolls as number[] | undefined) ?? [];
  // Le dé rejoue son animation à chaque nouveau lancer reçu du serveur (jamais avant la réponse).
  const rollKey = (c.log ?? []).length + ":" + (last?.die ?? last?.hold ?? "");
  const bust = Boolean(c.bust && last?.die === 1);
  return (
    <div className="stack stack--4 pig">
      <div className="pig-counters">
        <PigCounter who={nameOf(me)} value={Number(c.banked?.[me.seat] ?? 0)} target={target} active={c.turn === me.seat} />
        {partner && <PigCounter who={nameOf(partner)} value={Number(c.banked?.[partner.seat] ?? 0)} target={target} active={c.turn === partner.seat} />}
      </div>
      <div className="pig-tray" aria-live="polite">
        <img className="pig-tray__felt" src="/assets/premium/M12/tray.svg" alt="" aria-hidden="true" />
        <div className="pig-tray__die" key={rollKey}>
          {c.die ? <img className="pig-die-img" src={`/assets/premium/M12/die-${c.die}.svg`} alt={t("mini.pig.dieValue", { n: c.die })} width={88} height={88} />
            : <img className="pig-die-img is-idle" src="/assets/premium/M12/die-5.svg" alt="" aria-hidden="true" width={88} height={88} />}
        </div>
      </div>
      <div className={`pig-pot${bust ? " is-bust" : ""}`}>
        <img src={`/assets/premium/M12/${bust ? "bust" : "turn-pot"}.svg`} alt="" aria-hidden="true" width={44} height={44} />
        <div className="grow">
          <span className="t-meta">{t("mini.pig.turnTotal")}</span>
          <p className="pig-pot__val">{c.turn_total}</p>
        </div>
        {rolls.length > 0 && <span className="t-meta">{rolls.join(" + ")}</span>}
        {bust && <span className="t-small strong">{t("mini.pig.bust", { name: seatName(me, partner, last.seat) })}</span>}
      </div>
      {mine ? (
        <div className="pig-actions">
          <button className="btn" disabled={busy} aria-busy={busy} onClick={() => void play("roll")}><Icon name="dices" size={18} />{t("mini.pig.roll")}</button>
          <button className="btn btn--secondary" disabled={busy || c.turn_total <= 0} onClick={() => void play("hold")}>
            <img src="/assets/premium/M12/bank.svg" alt="" aria-hidden="true" width={22} height={22} />{t("mini.pig.holdPlus", { n: c.turn_total })}
          </button>
        </div>
      ) : (
        <p className="t-small muted center">{t("mini.pig.waiting", { name: nameOf(partner) })}</p>
      )}
      <p className="t-meta center">{t("mini.pig.goalHold", { n: target })}</p>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Bataille navale : flotte propre (part privée), tirs publics ; aucune position adverse reçue.
// ---------------------------------------------------------------------------
type Ship = { id: string; len: number; r: number; c: number; o: "H" | "V" };
const ROWS = "ABCDEFGHIJ";
const cellsOf = (s: Ship) => Array.from({ length: s.len }, (_, i) => (s.o === "H" ? `${s.r}:${s.c + i}` : `${s.r + i}:${s.c}`));
const inBounds = (s: Ship) => (s.o === "H" ? s.c + s.len <= 10 : s.r + s.len <= 10);

/** Plateau dense : affichage complet par défaut, mode agrandi (cibles de 44 px) avec défilement. */
function Zoomable({ children, zoomClass }: { children: ReactNode; zoomClass: string }) {
  const [zoom, setZoom] = useState(false);
  return (
    <div className="stack stack--2">
      <button type="button" className="btn btn--quiet btn--sm btn--auto" aria-pressed={zoom} onClick={() => setZoom(!zoom)}>
        <Icon name={zoom ? "minus" : "plus"} size={18} />{zoom ? t("mini.zoomOut") : t("mini.zoomIn")}
      </button>
      <div className={zoom ? `board-zoom ${zoomClass}` : undefined}>{children}</div>
    </div>
  );
}

function NavalGrid({ label, cell, onCell, disabled }: {
  label: string; cell: (r: number, c: number) => { cls: string; text: string; img?: string }; onCell?: (r: number, c: number) => void; disabled?: (r: number, c: number) => boolean;
}) {
  return (
    <Zoomable zoomClass="board-zoom--naval">
    <div className="naval" role="grid" aria-label={label}>
      <span aria-hidden="true" />
      {Array.from({ length: 10 }, (_, c) => <span key={`h${c}`} className="naval__head" aria-hidden="true">{c + 1}</span>)}
      {Array.from({ length: 10 }, (_, r) => [
        <span key={`r${r}`} className="naval__head" aria-hidden="true">{ROWS[r]}</span>,
        ...Array.from({ length: 10 }, (_, c) => {
          const x = cell(r, c);
          return (
            <button key={`${r}-${c}`} type="button" role="gridcell" className={`naval__cell ${x.cls}`} aria-label={`${ROWS[r]}${c + 1} : ${x.text}`}
              disabled={!onCell || disabled?.(r, c)} onClick={() => onCell?.(r, c)}>
              {x.img && <img src={`${PIECES}/${x.img}.svg`} alt="" />}
            </button>
          );
        }),
      ])}
    </div>
    </Zoomable>
  );
}

function Placement({ c, priv, me, partner, play, busy }: V) {
  const ships: { id: string; len: number }[] = c.ships;
  const server: Ship[] | undefined = priv?.fleet;
  const [draft, setDraft] = useState<Ship[]>(server ?? []);
  const [sel, setSel] = useState<string>(ships[0].id);
  const [o, setO] = useState<"H" | "V">("H");
  const locked = Boolean(c.locked?.[me.seat]);
  useEffect(() => { if (server) setDraft(server); }, [JSON.stringify(server)]); // eslint-disable-line react-hooks/exhaustive-deps
  const taken = useMemo(() => {
    const m = new Map<string, string>();
    draft.forEach((s) => cellsOf(s).forEach((k) => m.set(k, s.id)));
    return m;
  }, [draft]);
  const complete = draft.length === ships.length;
  const synced = server && JSON.stringify(server) === JSON.stringify(draft);
  const nameShip = (id: string) => t(`mini.naval.ship.${id}` as never);

  function place(r: number, col: number) {
    const len = ships.find((s) => s.id === sel)!.len;
    const next: Ship = { id: sel, len, r, c: col, o };
    if (!inBounds(next)) return;
    const others = draft.filter((s) => s.id !== sel);
    if (cellsOf(next).some((k) => others.some((s) => cellsOf(s).includes(k)))) return;
    setDraft([...others, next]);
    const free = ships.find((s) => s.id !== sel && !others.some((x) => x.id === s.id));
    if (free) setSel(free.id);
  }

  if (locked) {
    return (
      <div className="stack stack--4">
        <p className="nd-chip"><Icon name="lock-keyhole" size={16} />{t("mini.naval.fleetLocked")}</p>
        <p className="t-small muted">{c.locked?.[partner?.seat ?? 0] ? t("mini.naval.starting") : t("mini.naval.waitingFleet", { name: nameOf(partner) })}</p>
        <NavalGrid label={t("mini.naval.myFleet")} cell={(r, col) => taken.has(`${r}:${col}`) ? { cls: "naval__cell--ship", text: nameShip(taken.get(`${r}:${col}`)!) } : { cls: "", text: t("mini.naval.water") }} />
      </div>
    );
  }
  return (
    <div className="stack stack--4">
      <p className="t-small">{t("mini.naval.placeHint")}</p>
      <div className="chips" role="radiogroup" aria-label={t("mini.naval.ships")}>
        {ships.map((s) => (
          <button key={s.id} type="button" role="radio" className="chip" aria-checked={sel === s.id} onClick={() => setSel(s.id)}>
            {draft.some((d) => d.id === s.id) && <Icon name="check" size={14} />}{nameShip(s.id)} · {s.len}
          </button>
        ))}
      </div>
      <button type="button" className="btn btn--secondary btn--sm" onClick={() => setO(o === "H" ? "V" : "H")}>
        <Icon name="refresh" size={18} />{t("mini.naval.rotate", { o: o === "H" ? t("mini.naval.horizontal") : t("mini.naval.vertical") })}
      </button>
      <NavalGrid label={t("mini.naval.myFleet")} onCell={place}
        cell={(r, col) => taken.has(`${r}:${col}`) ? { cls: `naval__cell--ship${taken.get(`${r}:${col}`) === sel ? " naval__cell--sel" : ""}`, text: nameShip(taken.get(`${r}:${col}`)!) } : { cls: "", text: t("mini.naval.water") }} />
      <div className="stack stack--2">
        <button className="btn btn--secondary" disabled={busy} onClick={() => void play("random_fleet")}><Icon name="dices" size={18} />{t("mini.naval.random")}</button>
        {!synced ? (
          <button className="btn" disabled={busy || !complete} onClick={() => void play("set_fleet", {
            ships: draft.map((s) => ({ id: s.id, start_row: s.r, start_col: s.c, orientation: s.o })),
          })}>{t("mini.naval.saveFleet")}</button>
        ) : (
          <button className="btn" disabled={busy} onClick={() => void play("lock_fleet")}><Icon name="lock-keyhole" size={18} />{t("mini.naval.lock")}</button>
        )}
        {!complete && <p className="t-meta">{t("mini.naval.remaining", { n: ships.length - draft.length })}</p>}
      </div>
    </div>
  );
}

function shotCell(x: J | undefined, unknownText: string) {
  if (!x) return { cls: "", text: unknownText };
  if (x.res === "miss") return { cls: "naval__cell--miss", text: t("mini.naval.miss"), img: "naval-eau" };
  if (x.res === "sunk") return { cls: "naval__cell--sunk", text: t("mini.naval.sunkShip", { s: t(`mini.naval.ship.${x.ship}` as never) }), img: "naval-coule" };
  return { cls: "naval__cell--hit", text: t("mini.naval.hitShip", { s: t(`mini.naval.ship.${x.ship}` as never) }), img: "naval-touche" };
}

function Battleship(v: V) {
  const { c, priv, me, partner, play, busy, mine } = v;
  const [view, setView] = useState<"them" | "me">("them");
  if (c.phase === "placement") return <Placement {...v} />;
  const myShots: J[] = c.shots?.[me.seat] ?? [];
  const theirShots: J[] = partner ? c.shots?.[partner.seat] ?? [] : [];
  const shotAt = (list: J[], r: number, col: number) => list.find((x) => x.r === r && x.c === col);
  const fleet: Ship[] = priv?.fleet ?? [];
  const shipAt = (r: number, col: number) => fleet.find((s) => cellsOf(s).includes(`${r}:${col}`));
  const last = myShots[myShots.length - 1];
  return (
    <div className="stack stack--4">
      <Scoreline me={me} partner={partner} values={{ [me.seat]: c.sunk?.[me.seat]?.length ?? 0, [partner?.seat ?? 0]: c.sunk?.[partner?.seat ?? 0]?.length ?? 0 }} label={t("mini.naval.sunkCount")} />
      <div className="seg" role="tablist" aria-label={t("mini.naval.grids")}>
        <button type="button" role="tab" aria-selected={view === "them"} onClick={() => setView("them")}>{t("mini.naval.theirGrid")}</button>
        <button type="button" role="tab" aria-selected={view === "me"} onClick={() => setView("me")}>{t("mini.naval.myGrid")}</button>
      </div>
      {view === "them" ? (
        <>
          {last && <p className="t-small" aria-live="polite">{t("mini.naval.lastShot", { cell: `${ROWS[last.r]}${last.c + 1}`, res: shotCell(last, "").text })}</p>}
          <NavalGrid label={t("mini.naval.theirGrid")} cell={(r, col) => shotCell(shotAt(myShots, r, col), t("mini.naval.unknown"))}
            onCell={mine && !busy ? (r, col) => void play("fire", { row: r, col }) : undefined}
            disabled={(r, col) => Boolean(shotAt(myShots, r, col))} />
          {!mine && <p className="t-small muted center">{t("mini.naval.waitingShot", { name: nameOf(partner) })}</p>}
        </>
      ) : (
        <NavalGrid label={t("mini.naval.myGrid")} cell={(r, col) => {
          const s = shipAt(r, col);
          const x = shotAt(theirShots, r, col);
          if (x) return shotCell(x, "");
          return s ? { cls: "naval__cell--ship", text: t(`mini.naval.ship.${s.id}` as never) } : { cls: "", text: t("mini.naval.water") };
        }} />
      )}
      {c.sunk?.[me.seat]?.length > 0 && (
        <p className="t-meta">{t("mini.naval.youSank", { list: (c.sunk[me.seat] as string[]).map((id) => t(`mini.naval.ship.${id}` as never)).join(", ") })}</p>
      )}
    </div>
  );
}

export const MINI_VIEWS: Record<string, ComponentType<V>> = {
  tic_tac_toe: TicTacToe, dots_boxes: DotsBoxes, rps: Rps, nd_pig: Pig, battleship: Battleship,
};

/** Fin de manche : résultat et état final du plateau. */
export function MiniSolution({ c, players }: { c: J; players: Player[] }) {
  const me = players.find((p) => p.is_me)!;
  const partner = players.find((p) => !p.is_me);
  const noop: Play = async () => ({ ok: false });
  const winnerText = c.void ? t("mini.void")
    : c.winner === 0 ? t("mini.draw")
    : c.winner === me.seat ? t("mini.youWin")
    : c.winner ? t("mini.winner", { name: seatName(me, partner, c.winner) }) : "";
  return (
    <div className="stack stack--3">
      {winnerText && <p className="strong">{winnerText}</p>}
      {c.shortened && <p className="t-meta">{t("mini.shortened")}</p>}
      {c.mech === "tic_tac_toe" && <TicTacToeBoard c={c} priv={null} me={me} partner={partner} play={noop} busy mine={false} />}
      {c.mech === "dots_boxes" && <Scoreline me={me} partner={partner} values={c.tally} label={t("mini.dots.scores")} />}
      {c.mech === "rps" && c.gestures && (
        <div className="rps rps--reveal">
          {[me, partner].filter(Boolean).map((p) => {
            const g = GESTURES.find((x) => x.id === c.gestures[p!.seat]);
            return (
              <div key={p!.seat} className="rps__choice" aria-label={`${nameOf(p)} : ${t(`mini.rps.${g?.id}` as never)}`}>
                <img src={`${PIECES}/${g?.img}.svg`} alt="" width={72} height={72} />
                <span>{nameOf(p)}</span>
              </div>
            );
          })}
        </div>
      )}
      {c.mech === "nd_pig" && <Scoreline me={me} partner={partner} values={c.banked} label={t("mini.pig.banked")} />}
      {c.mech === "battleship" && <p className="t-meta">{t("mini.naval.secretKept")}</p>}
    </div>
  );
}
