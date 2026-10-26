import { useEffect, useState } from "react";
import { Link, useSearchParams } from "react-router";
import { t } from "../i18n";
import { supabase } from "../lib/supabase";
import { useDuo } from "../duo/DuoProvider";
import { SubPage } from "../components/AppShell";
import { Alert, Icon, Loading, formatDate } from "../components/ui";

const PAGE = 5;

interface Row {
  id: string;
  status: string;
  created_at: string;
  ended_at: string | null;
  games: { title: string } | null;
  session_players: { keep_memory: boolean }[];
}

type Filter = "all" | "ended" | "abandoned";
const FILTERS: { id: Filter; label: string; statuses: string[] }[] = [
  { id: "all", label: "Toutes", statuses: ["ended", "closed", "abandoned"] },
  { id: "ended", label: "Terminées", statuses: ["ended", "closed"] },
  { id: "abandoned", label: "Interrompues", statuses: ["abandoned"] },
];

/** Historique dédié (V7) : cinq parties par page, pagination réelle côté serveur et total exact, sans faux total. */
export function HistoryPage() {
  const duo = useDuo();
  const [params, setParams] = useSearchParams();
  const coupleId = params.get("duo") && duo.duos.some((d) => d.id === params.get("duo")) ? params.get("duo")! : duo.active?.id ?? duo.duos[0]?.id;
  const filter = (FILTERS.find((f) => f.id === params.get("f"))?.id ?? "all") as Filter;
  const page = Math.max(0, Number(params.get("p") ?? 0) || 0);
  const [rows, setRows] = useState<Row[] | null>(null);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState(false);

  useEffect(() => {
    if (!coupleId) return;
    let cancelled = false;
    setRows(null); setError(false);
    const statuses = FILTERS.find((f) => f.id === filter)!.statuses;
    void supabase.from("game_sessions")
      .select("id, status, created_at, ended_at, games(title), session_players(keep_memory)", { count: "exact" })
      .eq("couple_id", coupleId).in("status", statuses)
      .order("created_at", { ascending: false }).range(page * PAGE, page * PAGE + PAGE - 1)
      .then(({ data, error: e, count }) => {
        if (cancelled) return;
        setError(Boolean(e));
        setRows((data as unknown as Row[]) ?? []);
        setTotal(count ?? 0);
      });
    return () => { cancelled = true; };
  }, [coupleId, filter, page]);

  const pages = Math.max(1, Math.ceil(total / PAGE));
  const go = (next: Partial<{ f: Filter; p: number }>) => {
    const q = new URLSearchParams(params);
    if (next.f !== undefined) { q.set("f", next.f); q.set("p", "0"); }
    if (next.p !== undefined) q.set("p", String(next.p));
    setParams(q, { replace: true });
  };

  return (
    <SubPage title="Historique" backTo={coupleId ? `/espace?duo=${coupleId}` : "/espace"}>
      <main className="page page--read v7-history">
        <h1 className="t-section">Vos parties</h1>
        <div className="chips" role="group" aria-label="Filtrer les parties">
          {FILTERS.map((f) => <button key={f.id} type="button" className="chip" aria-pressed={filter === f.id} onClick={() => go({ f: f.id })}>{f.label}</button>)}
        </div>
        {!coupleId ? <p className="t-small muted">{t("space.noDuoText")}</p>
          : error ? <Alert>{t("net.loadError")}</Alert>
          : !rows ? <Loading />
          : rows.length === 0 ? <p className="t-small muted">Aucune partie dans cette liste.</p>
          : <HistoryList rows={rows} />}
        {rows && total > PAGE && (
          <nav className="v7-pager" aria-label="Pages de l’historique">
            <button type="button" className="icon-btn" disabled={page === 0} onClick={() => go({ p: page - 1 })} aria-label="Page précédente"><Icon name="arrow-left" size={20} /></button>
            <span className="t-meta" aria-live="polite">Page {page + 1} sur {pages}</span>
            <button type="button" className="icon-btn" disabled={page + 1 >= pages} onClick={() => go({ p: page + 1 })} aria-label="Page suivante"><Icon name="arrow-right" size={20} /></button>
          </nav>
        )}
        {rows && <p className="t-meta center">{PAGE} parties par page</p>}
      </main>
    </SubPage>
  );
}

export function HistoryList({ rows }: { rows: Row[] }) {
  return (
    <ul className="list">
      {rows.map((h) => {
        const kept = h.session_players.length === 2 && h.session_players.every((p) => p.keep_memory);
        const label = h.status === "abandoned" ? t("space.abandoned") : h.status === "ended" ? t("game.endTitle") : kept ? t("space.kept") : t("space.notKept");
        const body = (
          <>
            <Icon name="cards" />
            <span className="list-row__body">
              <span className="t-card">{h.games?.title}</span>
              <span className="t-meta">{formatDate(h.ended_at ?? h.created_at)} · {label}</span>
            </span>
            {h.status !== "abandoned" && <Icon name="chevron-right" size={18} />}
          </>
        );
        return <li key={h.id}>{h.status === "abandoned" ? <div className="list-row">{body}</div> : <Link className="list-row" to={`/partie/${h.id}`}>{body}</Link>}</li>;
      })}
    </ul>
  );
}
