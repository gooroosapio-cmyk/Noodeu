import { useSearchParams } from "react-router";
import { t } from "../i18n";
import { useDuo } from "../duo/DuoProvider";
import { useAuth } from "../auth/AuthProvider";
import { Alert, Icon, Loading } from "../components/ui";
import { useCatalog } from "./catalog";
import { DONE, OPEN, SessionLine, dayLabel, useSessions, type SessionRow } from "./v7parts";

const PAGE = 5;
type Filter = "all" | "ended" | "open";
const FILTERS: { id: Filter; label: string; statuses: string[] }[] = [
  { id: "all", label: "Toutes", statuses: [...OPEN, ...DONE] },
  { id: "ended", label: "Terminées", statuses: ["ended", "closed"] },
  { id: "open", label: "À reprendre", statuses: OPEN },
];

const stateOf = (r: SessionRow) => OPEN.includes(r.status)
  ? `À reprendre${r.status !== "lobby" && r.total_rounds > 0 ? ` · ${r.current_round}/${r.total_rounds}` : ""}`
  : r.status === "abandoned" ? "Interrompue" : "Terminée";

/** Historique dédié (témoin 06) : cinq parties par page, pagination serveur et total exact, sans faux total. */
export function HistoryPage() {
  const duo = useDuo();
  const { userId } = useAuth();
  const { games } = useCatalog(userId);
  const [params, setParams] = useSearchParams();
  const coupleId = duo.duos.find((d) => d.id === params.get("duo"))?.id ?? duo.active?.id ?? duo.duos[0]?.id;
  const filter = (FILTERS.find((f) => f.id === params.get("f"))?.id ?? "all") as Filter;
  const page = Math.max(0, Number(params.get("p") ?? 0) || 0);
  const { rows, total, error } = useSessions(coupleId, FILTERS.find((f) => f.id === filter)!.statuses, page * PAGE, page * PAGE + PAGE - 1, true);
  const pages = Math.max(1, Math.ceil(total / PAGE));
  const go = (next: Partial<{ f: Filter; p: number }>) => {
    const q = new URLSearchParams(params);
    if (next.f !== undefined) { q.set("f", next.f); q.set("p", "0"); }
    if (next.p !== undefined) q.set("p", String(next.p));
    setParams(q, { replace: true });
  };

  return (
    <main className="page v7-history">
      <h1>Vos parties</h1>
      <div className="v7-tabs v7-tabs--dark" role="group" aria-label="Filtrer les parties">
        {FILTERS.map((f) => <button key={f.id} type="button" aria-pressed={filter === f.id} onClick={() => go({ f: f.id })}>{f.label}</button>)}
      </div>
      {!coupleId ? <p className="t-small muted">{t("space.noDuoText")}</p>
        : error ? <Alert>{t("net.loadError")}</Alert>
        : !rows ? <Loading />
        : rows.length === 0 ? <p className="t-small muted">Aucune partie dans cette liste.</p>
        : <div className="v7-list">{rows.map((r) => <SessionLine key={r.id} row={r} game={games.find((g) => g.id === r.game_id)} meta={<>{dayLabel(r.ended_at ?? r.created_at, true)} · {stateOf(r)}</>} />)}</div>}
      {rows && total > 0 && (
        <nav className="v7-pager" aria-label="Pages de l’historique">
          <button type="button" className="icon-btn" disabled={page === 0} onClick={() => go({ p: page - 1 })} aria-label="Page précédente"><Icon name="arrow-left" size={20} /></button>
          <span className="t-meta" aria-live="polite">Page {page + 1} sur {pages}</span>
          <button type="button" className="icon-btn" disabled={page + 1 >= pages} onClick={() => go({ p: page + 1 })} aria-label="Page suivante"><Icon name="arrow-right" size={20} /></button>
        </nav>
      )}
      {rows && total > 0 && <p className="t-meta center">{PAGE} parties par page</p>}
    </main>
  );
}
