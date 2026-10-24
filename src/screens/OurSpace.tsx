import { useEffect, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router";
import { t } from "../i18n";
import { rpc, supabase } from "../lib/supabase";
import { errorMessage } from "../lib/errors";
import { useAuth } from "../auth/AuthProvider";
import { useDuo, type DuoSummary } from "../duo/DuoProvider";
import { DuoIdentity } from "../duo/DuoIdentity";
import { MessageList } from "../duo/Chat";
import { useShell } from "../components/AppShell";
import { Avatar } from "../components/Avatar";
import { Alert, ConfirmDialog, Icon, Loading, PageLoading, Sheet, formatDate, useToast } from "../components/ui";
import type { ChatMessage } from "../lib/types";
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
  const [items, setItems] = useState<HistoryItem[] | null>(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    setItems(null);
    void supabase.from("game_sessions")
      .select("id, status, created_at, ended_at, games(title), session_players(keep_memory)")
      .eq("couple_id", coupleId).in("status", ["ended", "closed", "abandoned"])
      .order("created_at", { ascending: false }).limit(30)
      .then(({ data, error: e }) => { setError(Boolean(e)); setItems((data as unknown as HistoryItem[]) ?? []); });
  }, [coupleId]);
  if (error) return <Alert>{t("net.loadError")}</Alert>;
  if (!items) return <Loading />;
  if (!items.length) return <p className="t-small muted">{t("space.historyEmpty")}</p>;
  return (
    <ul className="list">
      {items.map((h) => {
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
  const { openChat } = useShell();
  const toast = useToast();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const [manage, setManage] = useState(false);
  const [confirmEnd, setConfirmEnd] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (duo.loading) return <PageLoading />;
  const selectedId = params.get("duo") && duo.duos.some((d) => d.id === params.get("duo")) ? params.get("duo")! : duo.duos[0]?.id;
  const selected = duo.duos.find((d) => d.id === selectedId) ?? null;
  const partnerName = selected?.partner?.deleted ? t("duo.deleted") : selected?.partner?.name || "?";

  async function endDuo() {
    setBusy(true);
    const res = await rpc("leave_couple");
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
        <DuoSelector duos={duo.duos} selected={selectedId} onSelect={(id) => setParams({ duo: id }, { replace: true })} />
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
        <section className="card stack stack--4">
          <DuoIdentity duo={selected} online={selected.active && duo.partnerOnline} />
          <ul className="t-meta plain-list">
            {selected.episodes.map((e, i) => (
              <li key={e.started_at}>
                {i === 0 ? t("duo.since", { date: formatDate(e.started_at) }) : t("duo.resumedOn", { date: formatDate(e.started_at) })}
                {e.ended_at && ` · ${t("duo.endedOn", { date: formatDate(e.ended_at) })}`}
              </li>
            ))}
          </ul>
          {selected.active ? (
            <div className="stack">
              {duo.openSession ? (
                <Link className="btn" to={`/partie/${duo.openSession.id}`}>{duo.openSession.status === "ended" ? t("home.seeResults") : t("home.resume")}</Link>
              ) : (
                <Link className="btn" to="/bibliotheques">{t("home.choose")}</Link>
              )}
              <button className="btn btn--secondary" onClick={openChat}><Icon name="chat" />{t("space.openChat")}</button>
              <button className="btn btn--quiet btn--sm" aria-haspopup="dialog" onClick={() => setManage(true)}>
                <Icon name="settings" size={20} />{t("duo.manage")}
              </button>
            </div>
          ) : (
            <div className="stack">
              <Alert kind="info">{t("space.archiveBanner")}</Alert>
              {!selected.partner?.deleted && (
                duo.active ? (
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
      )}

      {selected && (
        <section className="section">
          <h2 className="t-section">{t("space.history")}</h2>
          <History coupleId={selected.id} />
        </section>
      )}

      {selected?.active && (
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

      {!duo.active && duo.duos.length > 0 && (
        <Link className="btn btn--secondary" to="/inviter">{t("duo.invite")}</Link>
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
