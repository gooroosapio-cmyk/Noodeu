import { useEffect, useRef, useState, type FormEvent } from "react";
import { t } from "../i18n";
import { errorMessage } from "../lib/errors";
import type { ChatMessage } from "../lib/types";
import { Alert, Icon, Sheet } from "../components/ui";

/** Salon privé : feuille liée à la partie, le brouillon survit à sa fermeture. */
export function Salon({ myId, myName, partnerName, messages, onSend, onClose, online }: {
  myId: string | null;
  myName: string;
  partnerName: string;
  messages: ChatMessage[];
  onSend: (body: string, clientId?: string) => Promise<{ ok: boolean; error?: string }>;
  onClose: () => void;
  online: boolean;
}) {
  const [draft, setDraft] = useState(() => sessionStorage.getItem("noodeu.salon.draft") ?? "");
  const [error, setError] = useState<string | null>(null);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    try {
      sessionStorage.setItem("noodeu.salon.draft", draft);
    } catch {
      /* rien */
    }
  }, [draft]);

  useEffect(() => {
    endRef.current?.scrollIntoView({ block: "end" });
  }, [messages.length]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    const body = draft.trim();
    if (!body) return;
    setDraft("");
    const res = await onSend(body);
    if (!res.ok) setError(errorMessage(res.error));
    else setError(null);
  }

  return (
    <Sheet
      onClose={onClose}
      labelledBy="salon-title"
      title={
        <div>
          <h2 id="salon-title">{t("salon.title")}</h2>
          <p className="muted small">{t("salon.subtitle", { names: `${myName} & ${partnerName}` })}</p>
        </div>
      }
      footer={
        <>
          {error && <Alert>{error}</Alert>}
          <form className="composer" onSubmit={submit}>
            <label htmlFor="salon-input" className="sr-only">{t("salon.placeholder", { name: partnerName })}</label>
            <textarea
              id="salon-input"
              className="input"
              rows={1}
              maxLength={1000}
              placeholder={t("salon.placeholder", { name: partnerName })}
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  void submit(e as unknown as FormEvent);
                }
              }}
            />
            <button className="icon-btn" type="submit" disabled={!online || !draft.trim()}>
              <Icon name="send" label={t("salon.send")} />
            </button>
          </form>
          <p className="muted small row"><Icon name="lock" size={16} /> {t("salon.ephemeral")}</p>
          <p className="muted small row"><Icon name="mic" size={16} /> {t("salon.voiceSoon")}</p>
          <button className="btn btn--soft" onClick={onClose}>{t("salon.back")}</button>
        </>
      }
    >
      <div role="log" aria-live="polite" className="stack">
        {messages.length === 0 && <p className="muted center">{t("salon.empty")}</p>}
        {messages.map((m) => {
          const mine = m.user_id === myId;
          return (
            <div key={m.client_id} className={`bubble ${mine ? "bubble--me" : ""}`}>
              <div>{m.body}</div>
              <div className="bubble__meta">
                {mine ? myName : partnerName} · {new Date(m.created_at).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}
                {m.pending && <> · {t("common.sending")}</>}
                {m.failed && (
                  <>
                    {" · "}{t("salon.failed")}{" "}
                    <button className="btn btn--ghost btn--inline" style={{ minHeight: 32, padding: 0 }} onClick={() => void onSend(m.body, m.client_id)}>
                      {t("common.retry")}
                    </button>
                  </>
                )}
              </div>
            </div>
          );
        })}
        <div ref={endRef} />
      </div>
    </Sheet>
  );
}
