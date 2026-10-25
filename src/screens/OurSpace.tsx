import { useEffect, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router";
import { t } from "../i18n";
import { rpc, supabase } from "../lib/supabase";
import { errorMessage } from "../lib/errors";
import { useAuth } from "../auth/AuthProvider";
import { useDuo, type DuoSummary } from "../duo/DuoProvider";
import { DuoIdentity } from "../duo/DuoIdentity";
import { MessageList } from "../duo/Chat";
import { Avatar } from "../components/Avatar";
import { Alert, ConfirmDialog, Icon, Loading, PageLoading, Sheet, formatDate, useToast } from "../components/ui";
import type { ChatMessage } from "../lib/types";
import { DuoDashboard } from "../duo/DuoDashboard";
import { useCatalog } from "./catalog";
import { MyItems, ProgressSection } from "../parcours/Progress";

interface HistoryItem {
  id: string;
  status: string;
  created_at: string;
  ended_at: string | null;
  games: { title: string } | null;
  session_players: { keep_memory: boolean }[];
}

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

function History({ coupleId }: { coupleId: string }) {
  const [onlyKept, setOnlyKept] = useState(true);
  const [items, setItems] = useState<HistoryItem[] | null>(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    let cancelled = false;
    setItems(null); setError(false);
    void supabase.from("game_sessions")
      .select("id, status, created_at, ended_at, games(title), session_players(keep_memory)")
      .eq("couple_id", coupleId).in("status", ["ended", "closed", "abandoned"])
      .order("created_at", { ascending: false }).limit(30)
      .then(({ data, error: e }) => { if (!cancelled) { setError(Boolean(e)); setItems((data as unknown as HistoryItem[]) ?? []); } });
    return () => { cancelled = true; };
  }, [coupleId]);
  if (error) return <Alert>{t("net.loadError")}</Alert>;
  if (!items) return <Loading />;
  return (
    <div className="stack stack--3">
      <div className="action-pair" aria-label="Afficher les parties">
        <button className="chip" aria-pressed={!onlyKept} onClick={() => setOnlyKept(false)}>Parties récentes</button>
        <button className="chip" aria-pressed={onlyKept} onClick={() => setOnlyKept(true)}><Icon name="heart" size={18} />Coffre à souvenirs</button>
      </div>
      <p className="t-meta">{onlyKept ? 'Uniquement les parties que vous avez tous les deux choisi de garder.' : 'Les 30 dernières parties de ce duo.'}</p>
      {onlyKept && !items.some(h => h.session_players.length === 2 && h.session_players.every(p => p.keep_memory)) && <p className="t-small muted">Aucun souvenir partagé.</p>}
      <ul className="list">
      {items.filter(h => !onlyKept || (h.session_players.length === 2 && h.session_players.every(p => p.keep_memory))).map((h) => {
        const kept = h.session_players.length === 2 && h.session_players.every((p) => p.keep_memory);
        const label = h.status === "abandoned" ? t("space.abandoned") : h.status === "ended" ? t("game.endTitle") : kept ? t("space.kept") : t("space.notKept");
        const body = (
          <>
            <Icon name="cards" />
            <span className="list-row__body">
              <span className="t-card">{h.games?.title}</span>
              <span className="t-meta">{formatDate(h.ended_at ?? h.created_at)} · {label}</span>
            </span>
            {h.status !== "abandoned" && <Icon name="arrow-right" size={18} />}
          </>
        );
        return <li key={h.id}>{h.status === "abandoned" ? <div className="list-row">{body}</div> : <Link className="list-row" to={`/partie/${h.id}`}>{body}</Link>}</li>;
      })}
    </ul>
    </div>
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

export function OurSpace() {
  const duo = useDuo();
  const { userId } = useAuth();
  const { games } = useCatalog(userId);
  const toast = useToast();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const [manage, setManage] = useState(false);
  const [confirmEnd, setConfirmEnd] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (duo.loading) return <PageLoading />;
  const selectedId = params.get("duo") && duo.duos.some((d) => d.id === params.get("duo")) ? params.get("duo")! : (duo.active?.id ?? duo.duos[0]?.id);
  const selected = duo.duos.find((d) => d.id === selectedId) ?? null;
  const currentGame = selected?.id === duo.active?.id && duo.openSession ? games.find(g => g.id === duo.openSession?.game_id) : undefined;
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
    <main className="page">
      <div className="page-header">
        <h1 className="t-page">{t("space.title")}</h1>
      </div>
      {error && <Alert>{error}</Alert>}

      {duo.duos.length > 1 && selectedId && (
        <details className="disclosure space-selector">
          <summary><span>Espace avec {partnerName}</span><Icon name="chevron-down" /></summary>
          <DuoSelector duos={duo.duos} selected={selectedId} onSelect={(id) => setParams({ duo: id }, { replace: true })} />
        </details>
      )}

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
        <DuoDashboard key={selected.id} coupleId={selected.id} active={selected.active} partner={partnerName} activity={currentGame ? <><h2 className="t-card">{currentGame.title}</h2><p className="t-small muted">{currentGame.promise}</p></> : <p className="t-small muted">{selected.active ? "Aucune partie en cours." : "Duo archivé."}</p>} identity={<DuoIdentity duo={selected} online={selected.id === duo.active?.id && duo.partnerOnline} center size={64} />}>
        <section className="space-vault stack stack--3" aria-label="Coffre à souvenirs"><h2 className="t-section row"><Icon name="heart" />Coffre à souvenirs</h2><History key={selected.id} coupleId={selected.id} /></section>
        <section className="space-duo-summary stack stack--3">
          <ul className="t-meta plain-list">
            {selected.episodes.map((e, i) => (
              <li key={e.started_at}>
                {i === 0 ? t("duo.since", { date: formatDate(e.started_at) }) : t("duo.resumedOn", { date: formatDate(e.started_at) })}
                {e.ended_at && ` · ${t("duo.endedOn", { date: formatDate(e.ended_at) })}`}
              </li>
            ))}
          </ul>
          {selected.active && selected.id !== duo.active?.id ? (
            <div className="stack">
              <p className="t-small muted">{t("duo.switchHint")}</p>
              <button className="btn" onClick={async () => { if (await duo.switchDuo(selected.id)) toast(t("duo.switched", { name: partnerName })); }}>
                <Icon name="users" />{t("duo.showThis")}
              </button>
              <button className="btn btn--quiet btn--sm" aria-haspopup="dialog" onClick={() => setManage(true)}>
                <Icon name="settings" size={20} />{t("duo.manage")}
              </button>
            </div>
          ) : selected.active ? (
            <div className="stack">
              <button className="btn btn--quiet btn--sm" aria-haspopup="dialog" onClick={() => setManage(true)}>
                <Icon name="settings" size={20} />{t("duo.manage")}
              </button>
            </div>
          ) : (
            <div className="stack">
              <Alert kind="info">{t("space.archiveBanner")}</Alert>
              {!selected.partner?.deleted && (
                duo.activeDuos.some((d) => d.partner?.id && d.partner.id === selected.partner?.id) ? (
                  <p className="t-small muted">{t("invite.alreadyDuo")}</p>
                ) : (
                  <>
                    <button className="btn btn--secondary" onClick={() => navigate("/inviter")}>{t("space.replayWith", { name: partnerName })}</button>
                    <p className="t-meta">{t("space.replayHint", { name: partnerName })}</p>
                  </>
                )
              )}
            </div>
          )}
        </section>
        </DuoDashboard>
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

      {duo.duos.length > 0 && (
        <Link className="btn btn--secondary" to="/inviter"><Icon name="plus" />{duo.active ? t("duo.addOther") : t("duo.invite")}</Link>
      )}

      <section className="card card--soft stack stack--2">
        <h2 className="t-card row"><Icon name="lock" size={20} />{t("space.private")}</h2>
        <p className="t-small">{t("space.privateText")}</p>
      </section>

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
