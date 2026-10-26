// Éléments partagés des écrans V7 (accueil, espace, coffre, historique) : données réelles uniquement.
import { useEffect, useState, type ReactNode } from "react";
import { Link } from "react-router";
import { supabase } from "../lib/supabase";
import { Avatar } from "../components/Avatar";
import { Art, Icon } from "../components/ui";
import type { DuoSummary } from "../duo/DuoProvider";
import { artOf } from "./Libraries";
import type { Game } from "../lib/types";

export interface SessionRow {
  id: string;
  game_id: string;
  status: string;
  created_at: string;
  started_at: string | null;
  ended_at: string | null;
  current_round: number;
  total_rounds: number;
  games: { title: string } | null;
  session_players: { keep_memory: boolean }[];
}

export const SESSION_COLUMNS = "id, game_id, status, created_at, started_at, ended_at, current_round, total_rounds, games(title), session_players(keep_memory)";
export const DONE = ["ended", "closed", "abandoned"];
export const OPEN = ["lobby", "playing", "paused"];

/** Parties d'un duo, du plus récent au plus ancien, avec pagination serveur et total exact si demandé. */
export function useSessions(coupleId: string | undefined, statuses: string[], from: number, to: number, withCount = false) {
  const [rows, setRows] = useState<SessionRow[] | null>(null);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState(false);
  const key = statuses.join(",");
  useEffect(() => {
    if (!coupleId) { setRows([]); return; }
    let cancelled = false;
    setRows(null); setError(false);
    void supabase.from("game_sessions").select(SESSION_COLUMNS, withCount ? { count: "exact" } : undefined)
      .eq("couple_id", coupleId).in("status", key.split(","))
      .order("created_at", { ascending: false }).range(from, to)
      .then(({ data, error: e, count }) => {
        if (cancelled) return;
        setError(Boolean(e));
        setRows((data as unknown as SessionRow[]) ?? []);
        setTotal(count ?? 0);
      });
    return () => { cancelled = true; };
  }, [coupleId, key, from, to, withCount]);
  return { rows, total, error };
}

export const kept = (s: SessionRow) => s.session_players.length === 2 && s.session_players.every((p) => p.keep_memory);

/** « Aujourd'hui », « Hier » ou « 22 oct. ». */
export function dayLabel(iso: string, long = false) {
  const d = new Date(iso), now = new Date();
  const days = Math.round((new Date(now.toDateString()).getTime() - new Date(d.toDateString()).getTime()) / 86_400_000);
  if (days === 0) return "Aujourd’hui";
  if (days === 1) return "Hier";
  return d.toLocaleDateString("fr-FR", long ? { day: "numeric", month: "long" } : { day: "numeric", month: "short" });
}

/** Durée réelle d'une partie terminée (début → fin), jamais estimée. */
export function minutesOf(s: SessionRow) {
  if (!s.started_at || !s.ended_at) return null;
  return Math.max(1, Math.round((new Date(s.ended_at).getTime() - new Date(s.started_at).getTime()) / 60_000));
}

export function GameArt({ game, size = 40 }: { game?: Game; size?: number }) {
  return game ? <Art name={artOf(game)} size={size} /> : <span className="v7-row__icon"><Icon name="cards" size={20} /></span>;
}

/** Ligne de partie : illustration, titre, méta, chevron. */
export function SessionLine({ row, game, meta }: { row: SessionRow; game?: Game; meta: ReactNode }) {
  const body = <>
    <GameArt game={game} />
    <span className="v7-row__text"><strong>{game?.title ?? row.games?.title ?? "Partie"}</strong><small>{meta}</small></span>
    {row.status !== "abandoned" && <Icon name="chevron-right" size={20} />}
  </>;
  return row.status === "abandoned" ? <div className="v7-row">{body}</div> : <Link className="v7-row" to={`/partie/${row.id}`}>{body}</Link>;
}

/** Deux avatars qui se chevauchent, sans symbole entre eux. */
export function DuoAvatars({ me, partner, size = 40 }: { me: { name: string; path?: string | null }; partner?: DuoSummary["partner"] | null; size?: number }) {
  return (
    <span className="v7-avatars" aria-hidden="true">
      <Avatar name={me.name} path={me.path} size={size} me />
      <Avatar name={partner?.name ?? "?"} path={partner?.avatar_path} size={size} />
    </span>
  );
}
