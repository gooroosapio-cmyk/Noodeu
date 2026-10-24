import { useEffect, useState } from "react";
import { Link } from "react-router";
import { t } from "../i18n";
import { rpc, supabase } from "../lib/supabase";
import { useAuth } from "../auth/AuthProvider";
import { Icon, Loading } from "../components/ui";
import { useCatalog } from "../screens/catalog";
import { ItemChips, itemText, type ItemView } from "./items";

export type Progress =
  | { kind: "pack"; count: number; cards_done: number; completed: boolean; viewed: number; answered: number; passed: number }
  | { kind: "test"; me: "completed" | "declined" | "started"; partner: "completed" | "pending" }
  | { kind: "game"; played: number; started: number };

/** Progression du duo : compteurs seulement, aucune réponse n'est transmise. */
export function useProgress(key?: unknown) {
  const [data, setData] = useState<Record<string, Progress> | null>(null);
  useEffect(() => {
    let alive = true;
    void rpc<{ games: Record<string, Progress> }>("get_progress", {}).then((r) => {
      if (alive) setData(r.ok ? (r as unknown as { games: Record<string, Progress> }).games ?? {} : {});
    });
    return () => { alive = false; };
  }, [key]);
  return data;
}

/** Libellé court d'une progression : consulté, passé et réalisé restent distincts. */
export function progressLabel(p: Progress) {
  if (p.kind === "pack") return p.completed ? t("progress.packDone") : t("progress.pack", { done: p.cards_done, count: p.count });
  if (p.kind === "test") return p.me === "completed" ? (p.partner === "completed" ? t("progress.testBoth") : t("progress.testMine")) : t("progress.testStarted");
  return p.played > 0 ? t("progress.played", { n: p.played }) : t("progress.started");
}

export function ProgressBadge({ p }: { p?: Progress }) {
  if (!p) return null;
  const done = (p.kind === "pack" && p.completed) || (p.kind === "test" && p.me === "completed" && p.partner === "completed");
  return <span className={`nd-chip${done ? " nd-chip--mint" : ""}`}>{done && <Icon name="check" size={14} />}{progressLabel(p)}</span>;
}

export function ProgressSection() {
  const { userId } = useAuth();
  const cat = useCatalog(userId);
  const progress = useProgress();
  if (!progress || cat.loading) return <Loading />;
  const rows = cat.games.filter((g) => progress[g.id]);
  if (!rows.length) return <p className="t-small muted">{t("progress.empty")}</p>;
  return (
    <ul className="list">
      {rows.map((g) => {
        const p = progress[g.id];
        return (
          <li key={g.id}>
            <Link className="list-row" to={`/bibliotheques/${g.id}`}>
              <Icon name={p.kind === "pack" ? "cards" : p.kind === "test" ? "book-open" : "gamepad"} />
              <span className="list-row__body">
                <span className="t-card">{g.title}</span>
                <span className="t-meta">{progressLabel(p)}</span>
                {p.kind === "pack" && (
                  <span className="t-meta">{t("progress.packDetail", { viewed: p.viewed, answered: p.answered, passed: p.passed })}</span>
                )}
              </span>
              <Icon name="arrow-right" size={18} />
            </Link>
          </li>
        );
      })}
    </ul>
  );
}

interface MyItem { bank: string; item_id: string; kind?: string; view: ItemView | null }

/** Mes questions favorites et mises de côté : visibles par moi seul. */
export function MyItems() {
  const { userId } = useAuth();
  const [data, setData] = useState<{ later: MyItem[]; favorites: MyItem[] } | null>(null);
  const [tab, setTab] = useState<"favorites" | "later">("favorites");
  useEffect(() => {
    void rpc<{ later: MyItem[]; favorites: MyItem[] }>("get_my_items", {}).then((r) => setData(r.ok ? (r as unknown as { later: MyItem[]; favorites: MyItem[] }) : { later: [], favorites: [] }));
  }, []);
  if (!data) return <Loading />;
  const list = data[tab];

  async function remove(it: MyItem) {
    if (!userId) return;
    const table = tab === "later" ? "later_items" : "item_favorites";
    const { error } = await supabase.from(table).delete().eq("user_id", userId).eq("bank", it.bank).eq("item_id", it.item_id);
    if (!error) setData((d) => d && { ...d, [tab]: d[tab].filter((x) => !(x.bank === it.bank && x.item_id === it.item_id)) });
  }

  return (
    <div className="stack">
      <div className="chips" role="tablist" aria-label={t("items.title")}>
        {(["favorites", "later"] as const).map((k) => (
          <button key={k} className="chip" role="tab" aria-selected={tab === k} aria-pressed={tab === k} onClick={() => setTab(k)}>
            {t(k === "favorites" ? "items.tabFav" : "items.tabLater", { n: data[k].length })}
          </button>
        ))}
      </div>
      {list.length === 0 ? <p className="t-small muted">{t(tab === "favorites" ? "items.emptyFav" : "items.emptyLater")}</p> : (
        <ul className="stack stack--2 plain-list">
          {list.map((it) => (
            <li key={`${it.bank}/${it.item_id}`} className="card stack stack--2">
              {!it.view || it.view.hidden ? <p className="muted">{t("items.hidden")}</p> : (
                <>
                  <ItemChips v={it.view} />
                  <p className="t-body">{itemText(it.view)}</p>
                </>
              )}
              <button className="btn btn--quiet btn--sm btn--auto" onClick={() => void remove(it)}><Icon name="close" size={16} />{t("items.remove")}</button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
