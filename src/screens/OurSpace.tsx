import { useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router";
import { t } from "../i18n";
import { rpc } from "../lib/supabase";
import { errorMessage } from "../lib/errors";
import { useAuth } from "../auth/AuthProvider";
import { useDuo, type DuoSummary } from "../duo/DuoProvider";
import { DuoIdentity } from "../duo/DuoIdentity";
import { MessageList } from "../duo/Chat";
import { Avatar } from "../components/Avatar";
import { Alert, ConfirmDialog, Icon, Loading, PageLoading, Sheet, formatDate, useToast } from "../components/ui";
import type { ChatMessage } from "../lib/types";
import { DuoSpaceCard, useDuoSpace } from "../duo/DuoDashboard";
import { useCatalog } from "./catalog";
import { MyItems, ProgressSection } from "../parcours/Progress";
import { DONE, DuoAvatars, SessionLine, dayLabel, minutesOf, useSessions } from "./v7parts";


function DuoSelector({ duos, selected, onSelect }: { duos: DuoSummary[]; selected: string; onSelect: (id: string) => void }) {
  return (
    <fieldset>
      <legend className="sr-only">{t("space.selector")}</legend>
      <div className="stack stack--2">
        {duos.map((d) => (
          <label key={d.id} className="choice">
            <input type="radio" name="duo" checked={selected === d.id} onChange={() => onSelect(d.id)} />
            <Avatar name={d.partner?.name ?? "?"} path={d.partner?.avatar_path} size={36} />
            <span className="grow t-body">{d.partner?.deleted ? t("duo.deleted") : d.partner?.name}</span>
            <span className={`tag ${d.active ? "tag--active" : "tag--archived"}`}>{d.active ? t("duo.active") : t("duo.archived")}</span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}

function ArchivedMessages({ coupleId, partnerName }: { coupleId: string; partnerName: string }) {
  const { loadArchive } = useDuo();
  const { userId, profile } = useAuth();
  const [messages, setMessages] = useState<ChatMessage[] | null>(null);
  return (
    <details className="disclosure" onToggle={(e) => (e.currentTarget.open && !messages) && void loadArchive(coupleId).then(setMessages)}>
      <summary>{t("space.messages")}<Icon name="chevron-down" /></summary>
      <div>
        {!messages ? <Loading /> : messages.length === 0 ? <p className="t-small muted">{t("space.messagesEmpty")}</p> : (
          <MessageList messages={messages} myId={userId} myName={profile?.display_name ?? ""} partnerName={partnerName} />
        )}
      </div>
    </details>
  );
}

/** Corps du témoin 04 : carte de couverture, confidentialité, accès Coffre / Notes, trois parties récentes. */
function SpaceBody({ selected, partnerName }: { selected: DuoSummary; partnerName: string }) {
  const { profile, userId } = useAuth();
  const { games } = useCatalog(userId);
  const space = useDuoSpace(selected.id, selected.active);
  const recent = useSessions(selected.id, DONE, 0, 2);
  const notes = space.unavailable || !space.space ? null : space.space.notes.length;
  return (
    <>
      <DuoSpaceCard space={space} active={selected.active} title={`${profile?.display_name || "Toi"} & ${partnerName}`} subtitle="Votre espace à deux"
        avatars={<DuoAvatars me={{ name: profile?.display_name ?? "", path: profile?.avatar_path }} partner={selected.partner} />} />
      <p className="v7-private"><Icon name="lock" size={16} />Seulement toi et {partnerName}</p>
      <div className="v7-access">
        <Link className="v7-access__card" to={`/espace/coffre?duo=${selected.id}`}>
          <img src="/assets/noodeu/v7/souvenirs-chest.webp" alt="" width={56} height={56} />
          <span><strong>Coffre à souvenirs</strong><small>souvenirs</small></span>
        </Link>
        <Link className="v7-access__card" to={`/espace/coffre?duo=${selected.id}&tab=notes`}>
          <img src="/assets/noodeu/v7/notes-notebook.webp" alt="" width={56} height={56} />
          <span><strong>Nos notes</strong><small>{notes === null ? "Notes partagées" : `${notes} note${notes > 1 ? "s" : ""}`}</small></span>
        </Link>
      </div>
      <section aria-labelledby="space-recent">
        <div className="v7-section-head"><h2 id="space-recent">Parties récentes</h2><Link to={`/espace/historique?duo=${selected.id}`}>Tout voir</Link></div>
        {recent.error ? <Alert>{t("net.loadError")}</Alert> : !recent.rows ? <Loading /> : recent.rows.length === 0 ? <p className="t-small muted">Aucune partie terminée pour le moment.</p> : (
          <div className="v7-list">
            {recent.rows.map((r) => <SessionLine key={r.id} row={r} game={games.find((g) => g.id === r.game_id)}
              meta={<>{dayLabel(r.ended_at ?? r.created_at)}{minutesOf(r) ? ` · ${minutesOf(r)} min` : ""}</>} />)}
          </div>
        )}
      </section>
    </>
  );
}

export function OurSpace() {
  const duo = useDuo();
  const toast = useToast();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const [manage, setManage] = useState(false);
  const [menu, setMenu] = useState(false);
  const [confirmEnd, setConfirmEnd] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (duo.loading) return <PageLoading />;
  const selectedId = params.get("duo") && duo.duos.some((d) => d.id === params.get("duo")) ? params.get("duo")! : (duo.active?.id ?? duo.duos[0]?.id);
  const selected = duo.duos.find((d) => d.id === selectedId) ?? null;
  const partnerName = selected?.partner?.deleted ? t("duo.deleted") : selected?.partner?.name || "?";

  async function endDuo() {
    setBusy(true);
    if (!selected) return;
    let res = await rpc("leave_duo", { p_couple: selected.id });
    // Base pas encore mise à jour (un seul duo actif) : l'ancienne fonction termine ce même duo.
    if (!res.ok && res.error === "unexpected" && duo.activeDuos.length <= 1) res = await rpc("leave_couple");
    setBusy(false);
    setConfirmEnd(false);
    setManage(false);
    if (!res.ok) setError(errorMessage(res.error));
    else toast(t("space.ended"));
    await duo.refresh();
  }

  return (
    <main className="page v7-space">
      <div className="v7-space-head">
        <h1>{selected ? `Espace avec ${partnerName}` : t("space.title")}</h1>
        <button type="button" className="icon-btn" aria-haspopup="dialog" aria-expanded={menu} aria-label="Choisir le duo et gérer l’espace" onClick={() => setMenu(true)}>
          <Icon name="chevron-down" size={22} />
        </button>
      </div>
      {error && <Alert>{error}</Alert>}

      {!selected ? (
        <section className="card stack stack--4">
          <DuoIdentity duo={null} showStatus={false} />
          <div className="stack stack--2">
            <h2 className="t-card">{t("space.noDuoTitle")}</h2>
            <p className="t-small muted">{t("space.noDuoText")}</p>
          </div>
          <Link className="btn" to="/inviter">{t("duo.invite")}</Link>
        </section>
      ) : (
        <SpaceBody key={selected.id} selected={selected} partnerName={partnerName} />
      )}

      {selected && selected.active && selected.id !== duo.active?.id && (
        <div className="stack">
          <p className="t-small muted">{t("duo.switchHint")}</p>
          <button className="btn" onClick={async () => { if (await duo.switchDuo(selected.id)) toast(t("duo.switched", { name: partnerName })); }}>
            <Icon name="users" />{t("duo.showThis")}
          </button>
        </div>
      )}
      {selected && !selected.active && (
        <div className="stack">
          <Alert kind="info">{t("space.archiveBanner")}</Alert>
          {!selected.partner?.deleted && (duo.activeDuos.some((d) => d.partner?.id && d.partner.id === selected.partner?.id)
            ? <p className="t-small muted">{t("invite.alreadyDuo")}</p>
            : <><button className="btn btn--secondary" onClick={() => navigate("/inviter")}>{t("space.replayWith", { name: partnerName })}</button><p className="t-meta">{t("space.replayHint", { name: partnerName })}</p></>)}
        </div>
      )}

      {selected?.active && selected.id === duo.active?.id && (
        <section className="section" aria-labelledby="space-progress">
          <h2 className="t-section" id="space-progress">{t("progress.title")}</h2>
          <ProgressSection />
        </section>
      )}
      <section className="section" aria-labelledby="space-items">
        <div className="section__head">
          <h2 className="t-section" id="space-items">{t("items.title")}</h2>
          <span className="t-meta row"><Icon name="lock" size={16} />{t("items.private")}</span>
        </div>
        <MyItems />
      </section>
      {selected && !selected.active && <ArchivedMessages coupleId={selected.id} partnerName={partnerName} />}

      {menu && (
        <Sheet title={<h2 className="t-section">{t("space.title")}</h2>} onClose={() => setMenu(false)}>
          {duo.duos.length > 0 && selectedId && <DuoSelector duos={duo.duos} selected={selectedId} onSelect={(id) => { setParams({ duo: id }, { replace: true }); setMenu(false); }} />}
          {selected && (
            <ul className="t-meta plain-list">
              {selected.episodes.map((e, i) => (
                <li key={e.started_at}>
                  {i === 0 ? t("duo.since", { date: formatDate(e.started_at) }) : t("duo.resumedOn", { date: formatDate(e.started_at) })}
                  {e.ended_at && ` · ${t("duo.endedOn", { date: formatDate(e.ended_at) })}`}
                </li>
              ))}
            </ul>
          )}
          {selected?.active && <button className="btn btn--secondary" onClick={() => { setMenu(false); setManage(true); }}><Icon name="settings" size={20} />{t("duo.manage")}</button>}
          <Link className="btn btn--quiet" to="/inviter" onClick={() => setMenu(false)}><Icon name="plus" />{duo.active ? t("duo.addOther") : t("duo.invite")}</Link>
          <p className="t-small muted">{t("space.privateText")}</p>
        </Sheet>
      )}
      {manage && selected?.active && (
        <Sheet title={<h2 className="t-section">{t("duo.manage")}</h2>} onClose={() => setManage(false)}>
          <h3 className="t-card">{t("space.members")}</h3>
          <DuoIdentity duo={selected} showStatus={false} />
          <button className="btn btn--danger" onClick={() => { setManage(false); setConfirmEnd(true); }}>{t("space.end")}</button>
        </Sheet>
      )}
      {confirmEnd && (
        <ConfirmDialog title={t("space.endTitle")} text={t("space.endText", { name: partnerName })} confirmLabel={t("space.end")} danger busy={busy}
          onCancel={() => setConfirmEnd(false)} onConfirm={() => void endDuo()} />
      )}
    </main>
  );
}
