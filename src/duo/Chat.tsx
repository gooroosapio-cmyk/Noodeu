import { useEffect, useRef, useState, type FormEvent } from "react";
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

/** Bulle flottante : ouvre la discussion avec la personne du duo actif. */
export function ChatLauncher({ onOpen, withNav = true }: { onOpen: () => void; withNav?: boolean }) {
  const { chatUnread } = useDuo();
  const launcher = useRef<HTMLButtonElement>(null);
  const [position, setPosition] = useState<{ left: number; top: number }>();
  useEffect(() => {
    let frame = 0;
    function place() {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const button = launcher.current;
        if (!button || document.querySelector('[role="dialog"]')) return;
        const box = button.getBoundingClientRect();
        const edge = Math.max(16, (innerWidth - 632) / 2 + 16);
        const floor = withNav ? document.querySelector('.nav')?.getBoundingClientRect().top ?? innerHeight : (visualViewport?.height ?? innerHeight);
        const controls = Array.from(document.querySelectorAll('main a, main button, main input, main select, main textarea')).filter((el) => el !== button).map((el) => el.getBoundingClientRect()).filter((r) => r.width && r.height);
        const candidates = [16, 84, 152, 220].flatMap((gap) => [
          { left: innerWidth - edge - box.width, top: floor - box.height - gap },
          { left: edge, top: floor - box.height - gap },
        ]).filter((p) => p.top >= 72);
        if (!candidates.length) candidates.push({ left: edge, top: Math.max(0, floor - box.height - 16) });
        const overlap = (p: { left: number; top: number }) => controls.reduce((area, r) => area + Math.max(0, Math.min(p.left + box.width + 4, r.right) - Math.max(p.left - 4, r.left)) * Math.max(0, Math.min(p.top + box.height + 4, r.bottom) - Math.max(p.top - 4, r.top)), 0);
        const best = candidates.reduce((a, b) => overlap(b) < overlap(a) ? b : a);
        setPosition((old) => old?.left === best.left && old?.top === best.top ? old : best);
      });
    }
    place();
    window.addEventListener('scroll', place, true);
    window.addEventListener('resize', place);
    visualViewport?.addEventListener('resize', place);
    const observer = new MutationObserver(place);
    observer.observe(document.body, { childList: true, subtree: true });
    return () => { cancelAnimationFrame(frame); observer.disconnect(); window.removeEventListener('scroll', place, true); window.removeEventListener('resize', place); visualViewport?.removeEventListener('resize', place); };
  }, [withNav]);
  return (
    <button ref={launcher} style={position ? { ...position, right: "auto", bottom: "auto" } : undefined} className={`chat-launcher ${withNav ? "" : "chat-launcher--nonav"}`} onClick={onOpen}
      aria-label={chatUnread ? t("chat.openUnread", { n: chatUnread }) : t("chat.open")}>
      <Icon name="chat" size={26} />
      {chatUnread > 0 && <span className="badge-count" aria-hidden="true">{chatUnread > 99 ? "99+" : chatUnread}</span>}
    </button>
  );
}

export function MessageList({ messages, myId, myName, partnerName }: { messages: ChatMessage[]; myId: string | null; myName: string; partnerName: string }) {
  const endRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    endRef.current?.scrollIntoView({ block: "end" });
  }, [messages.length]);
  return (
    <div role="log" aria-live="polite" className="stack stack--2">
      {messages.map((m) => {
        const mine = m.user_id === myId;
        return (
          <div key={m.client_id} className={`bubble ${mine ? "bubble--me" : ""}`}>
            <div>{m.body}</div>
            <div className="bubble__meta">
              <span className="sr-only">{mine ? myName : partnerName}, </span>
              <time dateTime={m.created_at}>{new Date(m.created_at).toLocaleString("fr-FR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}</time>
              {m.pending && <> · {t("common.sending")}</>}
            </div>
          </div>
        );
      })}
      <div ref={endRef} />
    </div>
  );
}

/** Discussion du duo actif. Réduire conserve le brouillon (indexé par duo) et ne quitte pas la partie. */
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
      tall
      side
      onClose={onClose}
      closeLabel={t("chat.minimize")}
      closeIcon="minus"
      title={
        <div className="row">
          <Avatar name={partnerName} path={active.partner?.avatar_path} size={40} />
          <div className="stack" style={{ gap: 0 }}>
            <h2 className="t-card">{partnerName}</h2>
            <span className="t-meta">{inGame ? t("chat.gameContinues") : t("chat.with", { name: partnerName })}</span>
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
              data-autofocus
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
