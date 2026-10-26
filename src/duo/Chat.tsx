import { Fragment, useEffect, useRef, useState, type FormEvent } from "react";
import { Link } from "react-router";
import { t } from "../i18n";
import { errorMessage } from "../lib/errors";
import { useOnline } from "../lib/useOnline";
import { useAuth } from "../auth/AuthProvider";
import { Avatar } from "../components/Avatar";
import { Alert, Icon, Sheet } from "../components/ui";
import type { ChatMessage } from "../lib/types";
import { useDuo } from "./DuoProvider";

function draftKey(coupleId: string) {
  return `noodeu.chat.draft.${coupleId}`;
}

/** Accès à la discussion : bouton fixe, non déplaçable, dans une zone réservée (V7).
 *  Au-dessus de la navigation principale ; en bas à droite sur les sous-pages. Il ne bouge jamais pour éviter
 *  le contenu : c'est la mise en page qui lui réserve sa place (voir styles/v7.css). */
export { draftKey };

export function ChatLauncher({ onOpen, withNav = true }: { onOpen: () => void; withNav?: boolean }) {
  const { chatUnread } = useDuo();
  return (
    <button type="button" className={`chat-launcher chat-launcher--fixed${withNav ? "" : " chat-launcher--nonav"}`} onClick={onOpen}
      aria-label={chatUnread ? t("chat.openUnread", { n: chatUnread }) : t("chat.open")}>
      <Icon name="chat" size={24} />
      {chatUnread > 0 && <span className="badge-count" aria-hidden="true">{chatUnread > 99 ? "99+" : chatUnread}</span>}
    </button>
  );
}

/** Messages groupés par auteur (moins de 5 min d'écart) : 4 px dans un groupe, 14 px entre groupes, heure en fin
 *  de groupe. À l'arrivée d'un message, on ne descend que si le lecteur était déjà en bas (ou si c'est le sien). */
export function MessageList({ messages, myId, myName, partnerName }: { messages: ChatMessage[]; myId: string | null; myName: string; partnerName: string }) {
  const endRef = useRef<HTMLDivElement>(null);
  const stick = useRef(true);
  const first = useRef(true);
  useEffect(() => {
    const scroller = endRef.current?.closest(".sheet__body, .chat-scroll") as HTMLElement | null;
    if (!scroller) return;
    const onScroll = () => { stick.current = scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight < 96; };
    scroller.addEventListener("scroll", onScroll, { passive: true });
    return () => scroller.removeEventListener("scroll", onScroll);
  }, []);
  const last = messages[messages.length - 1];
  useEffect(() => {
    if (first.current || stick.current || last?.user_id === myId) endRef.current?.scrollIntoView({ block: "end" });
    first.current = false;
  }, [messages.length, last?.user_id, myId]);
  const dayOf = (iso: string) => new Date(iso).toDateString();
  return (
    <div role="log" aria-live="polite" className="chat-log">
      {messages.map((m, i) => {
        const mine = m.user_id === myId;
        const prev = messages[i - 1];
        const next = messages[i + 1];
        const newDay = !prev || dayOf(prev.created_at) !== dayOf(m.created_at);
        const endOfGroup = !next || next.user_id !== m.user_id || dayOf(next.created_at) !== dayOf(m.created_at)
          || new Date(next.created_at).getTime() - new Date(m.created_at).getTime() > 5 * 60_000;
        return (
          <Fragment key={m.client_id}>
            {newDay && <p className="chat-day">{chatDay(m.created_at)}</p>}
            <div className={`chat-msg${mine ? " chat-msg--me" : ""}${endOfGroup ? " chat-msg--end" : ""}`}>
              <div className={`bubble ${mine ? "bubble--me" : ""}`}>
                <span className="sr-only">{mine ? myName : partnerName} : </span>
                <span className="bubble__text">{m.body}</span>
              </div>
              {(endOfGroup || m.pending || m.failed) && (
                <div className="chat-msg__meta">
                  <time dateTime={m.created_at}>{new Date(m.created_at).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}</time>
                  {m.pending && <> · {t("common.sending")}</>}
                </div>
              )}
            </div>
          </Fragment>
        );
      })}
      <div ref={endRef} />
    </div>
  );
}

/** Séparateur de jour : « Aujourd'hui », « Hier » ou la date. */
function chatDay(iso: string) {
  const d = new Date(iso), now = new Date();
  const days = Math.round((new Date(now.toDateString()).getTime() - new Date(d.toDateString()).getTime()) / 86_400_000);
  return days === 0 ? "Aujourd’hui" : days === 1 ? "Hier" : d.toLocaleDateString("fr-FR", { weekday: "long", day: "numeric", month: "long" });
}

export function ChatPanel({ onClose, inGame = false }: { onClose: () => void; inGame?: boolean }) {
  const { active, messages, sendMessage, markChatRead } = useDuo();
  const { userId, profile } = useAuth();
  const online = useOnline();
  const coupleId = active?.id ?? null;
  const [draft, setDraft] = useState("");
  const [error, setError] = useState<string | null>(null);
  const partnerName = active?.partner?.name || "?";

  // Brouillon propre à chaque duo : jamais envoyé à une autre personne.
  useEffect(() => {
    if (!coupleId) return;
    try {
      setDraft(sessionStorage.getItem(draftKey(coupleId)) ?? "");
    } catch {
      setDraft("");
    }
  }, [coupleId]);
  useEffect(() => {
    if (!coupleId) return;
    try {
      sessionStorage.setItem(draftKey(coupleId), draft);
    } catch {
      /* stockage indisponible */
    }
  }, [draft, coupleId]);
  useEffect(() => {
    if (coupleId) void markChatRead();
  }, [coupleId, messages.length, markChatRead]);

  async function submit(e?: FormEvent) {
    e?.preventDefault();
    const body = draft.trim();
    if (!body || !coupleId) return;
    setDraft("");
    const res = await sendMessage(body);
    setError(res.ok ? null : errorMessage(res.error));
  }

  if (!active) {
    return (
      <Sheet title={<h2 className="t-section">{t("chat.noDuoTitle")}</h2>} onClose={onClose}>
        <p>{t("chat.noDuoText")}</p>
        <Link className="btn" to="/inviter" onClick={onClose}>{t("duo.invite")}</Link>
      </Sheet>
    );
  }

  const failed = messages.filter((m) => m.failed);
  return (
    <Sheet
      className={inGame ? "sheet--game-chat" : "sheet--chat-page"}
      onClose={onClose}
      closeLabel={inGame ? "Fermer la conversation et revenir au jeu" : t("chat.minimize")}
      closeIcon={inGame ? "close" : "minus"}
      headerExtra={inGame ? <button type="button" className="btn btn--quiet btn--sm btn--auto" onClick={onClose}>Retour au jeu</button> : undefined}
      title={
        <div className="row chat-head">
          {!inGame && <button type="button" className="icon-btn chat-head__back" onClick={onClose} aria-label={t("common.back")}><Icon name="back" size={22} /></button>}
          <Avatar name={partnerName} path={active.partner?.avatar_path} size={40} />
          <div className="stack" style={{ gap: 0 }}>
            <h2 className="t-card">{partnerName}</h2>
            <span className="t-meta">{inGame ? t("chat.gameContinues") : "Votre conversation"}</span>
          </div>
        </div>
      }
      footer={
        <>
          {(error || failed.length > 0) && (
            <div style={{ padding: "8px var(--gutter) 0" }}>
              <Alert>
                {error ?? t("chat.failed")}{" "}
                {failed.length > 0 && (
                  <button className="btn btn--quiet btn--auto btn--sm" onClick={() => failed.forEach((m) => void sendMessage(m.body, m.client_id))}>
                    {t("common.retry")}
                  </button>
                )}
              </Alert>
            </div>
          )}
          <form className="composer" onSubmit={submit}>
            <label htmlFor="chat-input" className="sr-only">{t("chat.placeholder", { name: partnerName })}</label>
            <textarea
              id="chat-input"
              className="input"
              rows={1}
              maxLength={1000}
              placeholder={t("chat.placeholder", { name: partnerName })}
              value={draft}
              data-autofocus={inGame || undefined}
              onChange={(e) => {
                setDraft(e.target.value);
                e.target.style.height = "auto";
                e.target.style.height = `${Math.min(e.target.scrollHeight, 128)}px`;
              }}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  void submit();
                }
              }}
            />
            <button className="icon-btn" type="submit" disabled={!online || !draft.trim()} aria-label={t("chat.send")}>
              <Icon name="send" />
            </button>
          </form>
        </>
      }
    >
      {messages.length === 0 ? <p className="muted center">{t("chat.empty")}</p> : (
        <MessageList messages={messages} myId={userId} myName={profile?.display_name ?? ""} partnerName={partnerName} />
      )}
    </Sheet>
  );
}
