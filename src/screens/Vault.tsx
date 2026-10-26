import { Link, useSearchParams } from "react-router";
import { t } from "../i18n";
import { useDuo } from "../duo/DuoProvider";
import { DuoNotes } from "../duo/DuoDashboard";
import { Alert, Icon, Loading } from "../components/ui";
import { DONE, dayLabel, kept, useSessions } from "./v7parts";

/** Coffre à souvenirs (témoin 05) : parties gardées par vous deux, et notes partagées.
 *  Seules les données existantes sont montrées (titre, date) : aucune réponse privée n'est citée. */
export function VaultPage() {
  const duo = useDuo();
  const [params, setParams] = useSearchParams();
  const selected = duo.duos.find((d) => d.id === params.get("duo")) ?? duo.active ?? duo.duos[0] ?? null;
  const tab = params.get("tab") === "notes" ? "notes" : "souvenirs";
  const partner = selected?.partner?.deleted ? t("duo.deleted") : selected?.partner?.name || "?";
  const sessions = useSessions(selected?.id, DONE, 0, 29);
  const memories = (sessions.rows ?? []).filter(kept);
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
        : sessions.error ? <Alert>{t("net.loadError")}</Alert>
        : !sessions.rows ? <Loading />
        : memories.length === 0 ? <p className="t-small muted">Aucun souvenir pour le moment : à la fin d’une partie, gardez-la tous les deux pour la retrouver ici.</p>
        : (
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
      {selected && <p className="v7-private"><Icon name="lock" size={16} />Vos souvenirs restent dans cet espace.</p>}
    </main>
  );
}
