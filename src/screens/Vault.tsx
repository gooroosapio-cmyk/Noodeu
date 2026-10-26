import { useEffect, useRef, useState } from "react";
import { Link, useSearchParams } from "react-router";
import { useAuth } from "../auth/AuthProvider";
import { t } from "../i18n";
import { useDuo } from "../duo/DuoProvider";
import { DuoNotes } from "../duo/DuoDashboard";
import { Alert, Icon, Loading } from "../components/ui";
import { supabase } from "../lib/supabase";
import { DONE, SESSION_COLUMNS, dayLabel, kept, type SessionRow } from "./v7parts";

const PAGE_SIZE = 30;

/** Une instance par compte et duo : les pages et réponses tardives restent dans ce contexte. */
function VaultMemories({ coupleId }: { coupleId: string }) {
  const [memories, setMemories] = useState<SessionRow[] | null>(null);
  const [more, setMore] = useState(true);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const loadRef = useRef<(() => Promise<void>) | null>(null);

  useEffect(() => {
    let active = true;
    let busy = false;
    let offset = 0;
    let hasMore = true;
    const load = async () => {
      // Verrou synchrone : deux clics ne peuvent pas demander la même page en parallèle.
      if (!active || busy || !hasMore) return;
      busy = true;
      setLoading(true);
      setError(false);
      try {
        const { data, error: failure } = await supabase.from("game_sessions").select(SESSION_COLUMNS)
          .eq("couple_id", coupleId).in("status", DONE)
          .order("created_at", { ascending: false }).order("id", { ascending: false })
          .range(offset, offset + PAGE_SIZE - 1);
        if (!active) return;
        if (failure) throw failure;
        const rows = (data ?? []) as unknown as SessionRow[];
        offset += rows.length;
        hasMore = rows.length === PAGE_SIZE;
        setMemories((previous) => [...new Map([...(previous ?? []), ...rows.filter(kept)].map((row) => [row.id, row])).values()]);
        setMore(hasMore);
      } catch {
        if (active) setError(true);
      } finally {
        busy = false;
        if (active) setLoading(false);
      }
    };
    loadRef.current = load;
    void load();
    return () => { active = false; loadRef.current = null; };
  }, [coupleId]);

  return (
    <section aria-label="Souvenirs gardés" aria-busy={loading}>
      {memories?.length === 0 && <p className="t-small muted">{more
        ? "Aucun souvenir trouvé dans les parties récentes. Vous pouvez consulter les plus anciennes."
        : "Aucun souvenir pour le moment : à la fin d’une partie, gardez-la tous les deux pour la retrouver ici."}</p>}
      {memories !== null && memories.length > 0 && (
        <ul className="v7-memories">
          {memories.map((m, i) => (
            <li key={m.id}>
              <Link className={`v7-memory${i % 2 === 0 ? " v7-memory--warm" : ""}`} to={`/partie/${m.id}`}>
                <span className="v7-memory__head"><span className="v7-memory__kicker">{m.games?.title ?? "Partie"}</span><Icon name="heart" size={22} /></span>
                <span className="v7-memory__meta">Gardé par vous deux · {dayLabel(m.ended_at ?? m.created_at, true)}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
      {error && <Alert>{t("net.loadError")}</Alert>}
      {loading && <Loading />}
      {(error || (memories !== null && more)) && <button type="button" className="btn btn--secondary" disabled={loading} onClick={() => void loadRef.current?.()}>
        {error ? "Réessayer" : "Voir plus ancien"}
      </button>}
    </section>
  );
}

/** Coffre à souvenirs (témoin 05) : parties gardées par vous deux, et notes partagées.
 *  Seules les données existantes sont montrées (titre, date) : aucune réponse privée n'est citée. */
export function VaultPage() {
  const { userId } = useAuth();
  const duo = useDuo();
  const [params, setParams] = useSearchParams();
  const selected = duo.duos.find((d) => d.id === params.get("duo")) ?? duo.active ?? duo.duos[0] ?? null;
  const tab = params.get("tab") === "notes" ? "notes" : "souvenirs";
  const partner = selected?.partner?.deleted ? t("duo.deleted") : selected?.partner?.name || "?";
  const go = (next: "souvenirs" | "notes") => { const q = new URLSearchParams(params); if (next === "notes") q.set("tab", "notes"); else q.delete("tab"); setParams(q, { replace: true }); };

  return (
    <main className="page v7-vault">
      <div className="v7-vault__intro">
        <div>
          <h1>Les moments à garder</h1>
          <p>Choisis ensemble, retrouvés ici.</p>
          <div className="v7-tabs" role="group" aria-label="Contenu du coffre">
            <button type="button" aria-pressed={tab === "souvenirs"} onClick={() => go("souvenirs")}>Souvenirs</button>
            <button type="button" aria-pressed={tab === "notes"} onClick={() => go("notes")}>Nos notes</button>
          </div>
        </div>
        <img src="/assets/noodeu/v7/souvenirs-chest.webp" alt="" width={112} height={112} />
      </div>

      {!selected ? <p className="t-small muted">{t("space.noDuoText")}</p>
        : tab === "notes" ? <DuoNotes key={selected.id} coupleId={selected.id} active={selected.active} partner={partner} />
        : userId ? <VaultMemories key={`${userId}:${selected.id}`} coupleId={selected.id} /> : <Loading />}
      {selected && <p className="v7-private"><Icon name="lock" size={16} />Vos souvenirs restent dans cet espace.</p>}
    </main>
  );
}
