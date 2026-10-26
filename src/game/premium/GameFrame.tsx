/* eslint-disable @typescript-eslint/no-explicit-any */
// Cadre des écrans de jeu (planches cibles du 26/10/2026) : en-tête « réduire · titre · aide », bandeau des deux
// joueurs avec score ou état, scène illustrée par jeu. Les menus de l'application gardent leur propre thème.
import type { ReactNode } from "react";
import { Link } from "react-router";
import { Icon, Sheet } from "../../components/ui";
import type { Player, SessionState } from "../../lib/types";

type J = any;

/** Décor recadré des planches (sans texte ni interface) ; à défaut, l'illustration 3D de la bibliothèque. */
const SCENE_BY_MECH: Record<string, string> = {
  nd_opinion: "opinion", nd_two_truths: "twotruths", nd_sentence: "sentence",
  nd_never: "never", nd_duo_target: "target", pack_conversation: "questionnaire", test_form: "questionnaire",
};

/** Jeux dont le plateau est déjà la scène : pas de bandeau en plus. */
const BOARD_IS_SCENE = new Set(["nd_pig", "nd_hangman", "battleship", "tic_tac_toe", "dots_boxes", "rps", "nd_categories_stop", "nd_name_three_call"]);

const mechOf = (st: SessionState) => (st.game.config as unknown as { mechanic?: string }).mechanic ?? "";
const codeOf = (st: SessionState) => (st.game.config as unknown as { code?: string }).code;

export function GameHeader({ title, reduceTo, onReduce, onHelp }: { title: string; reduceTo: string; onReduce?: () => void; onHelp: () => void }) {
  return (
    <header className="game-head">
      <Link className="game-head__btn" to={reduceTo} aria-label="Réduire la partie et revenir à l’accueil" title="La partie continue ; retrouve-la sur l’accueil."
        onClick={(e) => { if (!e.metaKey && !e.ctrlKey && !e.shiftKey && !e.altKey && e.button === 0) onReduce?.(); }}>
        <Icon name="chevron-down" size={22} />
      </Link>
      <h1 className="game-head__title">{title}</h1>
      <button type="button" className="game-head__btn" onClick={onHelp} aria-label="Aide, règles et commandes de la partie">
        <Icon name="help" size={22} />
      </button>
    </header>
  );
}

/** Score courant si le jeu en tient un (séries, points conservés, cases, navires coulés, points des manches). */
function scoreboard(st: SessionState): { scores: Record<number, number>; target?: number } | null {
  const rounds = st.rounds as unknown as { round_no: number; card?: J }[];
  const card = rounds.find((r) => r.round_no === st.session.current_round)?.card ?? rounds[rounds.length - 1]?.card;
  if (!card) return null;
  const mech = mechOf(st);
  const pick = (o: J) => ({ 1: Number(o?.[1] ?? 0), 2: Number(o?.[2] ?? 0) });
  if (mech === "nd_pig" && card.banked) return { scores: pick(card.banked), target: Number(card.target ?? 30) };
  if (card.series) return { scores: pick(card.series), target: card.target ? Number(card.target) : undefined };
  if (card.tally) return { scores: pick(card.tally) };
  if (mech === "battleship" && card.sunk) return { scores: { 1: card.sunk[1]?.length ?? 0, 2: card.sunk[2]?.length ?? 0 } };
  let any = false;
  const totals = { 1: 0, 2: 0 };
  for (const r of rounds) {
    if (!r.card?.scores) continue;
    any = true;
    totals[1] += Number(r.card.scores[1] ?? 0);
    totals[2] += Number(r.card.scores[2] ?? 0);
  }
  return any ? { scores: totals } : null;
}

function Person({ p, value, label, here }: { p?: Player; value?: number; label?: string; here: boolean }) {
  const name = p ? (p.display_name || "?") : "Invité·e";
  return (
    <div className={`game-players__who${p?.is_me ? " is-me" : ""}`}>
      <span className="game-players__avatar" aria-hidden="true">{name.trim().slice(0, 1).toUpperCase()}</span>
      <span className="game-players__text">
        <span className="game-players__name">{p?.is_me ? `${name}` : name}</span>
        {value !== undefined
          ? <span className="game-players__score">{value}{label && <small> {label}</small>}</span>
          : <span className={`game-players__state${here ? " is-here" : ""}`}>{here ? "Connecté·e" : "Hors ligne"}</span>}
      </span>
    </div>
  );
}

export function GamePlayers({ st, partnerHere }: { st: SessionState; partnerHere: boolean }) {
  const me = st.players.find((p) => p.is_me);
  const partner = st.players.find((p) => !p.is_me);
  const board = scoreboard(st);
  const label = mechOf(st) === "nd_pig" ? "points" : undefined;
  return (
    <section className="game-players" aria-label="Les joueurs">
      <Person p={me} here value={board ? board.scores[me?.seat ?? 1] : undefined} label={label} />
      {board?.target ? <span className="game-players__goal"><small>Objectif</small><strong>{board.target}</strong></span> : <span className="game-players__sep" aria-hidden="true" />}
      <Person p={partner} here={partnerHere} value={board && partner ? board.scores[partner.seat] : undefined} label={label} />
    </section>
  );
}

/** Scène du jeu : décor de planche quand il existe, sinon l'objet 3D du jeu sur la teinte de son univers. */
export function GameScene({ st }: { st: SessionState }) {
  if (BOARD_IS_SCENE.has(mechOf(st))) return null;
  const scene = SCENE_BY_MECH[mechOf(st)];
  const code = codeOf(st);
  if (scene) return <div className="game-scene game-scene--photo" aria-hidden="true"><img src={`/assets/scenes/${scene}.webp`} alt="" decoding="async" /></div>;
  if (!code) return null;
  return (
    <div className="game-scene game-scene--object" aria-hidden="true">
      <img src={`/assets/original/library3d/${code}.webp`} alt="" decoding="async" onError={(e) => { (e.currentTarget.parentElement as HTMLElement).hidden = true; }} />
    </div>
  );
}

/** « ? » : règles et commandes (options, pause, quitter) regroupées. */
export function GameMenu({ onClose, onRules, onOptions, onPause, onQuit, pauseDisabled, extra }: {
  onClose: () => void; onRules?: () => void; onOptions?: () => void; onPause?: () => void; onQuit: () => void; pauseDisabled?: boolean; extra?: ReactNode;
}) {
  const item = (icon: Parameters<typeof Icon>[0]["name"], label: string, fn: () => void, cls = "", disabled = false) => (
    <li><button type="button" className={`game-menu__item ${cls}`} disabled={disabled} onClick={() => { onClose(); fn(); }}>
      <Icon name={icon} size={20} /><span>{label}</span><Icon name="chevron-right" size={18} />
    </button></li>
  );
  return (
    <Sheet title={<h2 className="t-section">La partie</h2>} onClose={onClose}>
      {extra}
      <ul className="game-menu">
        {onRules && item("book-open", "Règles du jeu", onRules)}
        {onOptions && item("settings", "Options de la partie", onOptions)}
        {onPause && item("pause", "Mettre en pause", onPause, "", pauseDisabled)}
        {item("logout", "Quitter la partie", onQuit, "game-menu__item--quit")}
      </ul>
      <p className="t-meta">« Réduire » (flèche en haut à gauche) garde la partie ouverte : retrouve-la sur l’accueil.</p>
    </Sheet>
  );
}
