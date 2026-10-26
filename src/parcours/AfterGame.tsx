import { useState } from "react";
import { t } from "../i18n";
import { rpc } from "../lib/supabase";
import { useOnline } from "../lib/useOnline";
import { useDuo } from "../duo/DuoProvider";
import { Icon, useToast } from "../components/ui";

const CALM = ["calm.thanks", "calm.feeling", "calm.space"] as const;

/** Après la partie, tout est facultatif : un mot de retour au calme (envoyé dans la discussion du duo) ou un défi léger. */
export function AfterGame({ onOpenChat }: { onOpenChat: () => void }) {
  const { sendMessage } = useDuo();
  const online = useOnline();
  const toast = useToast();
  const [sent, setSent] = useState<string | null>(null);
  const [challenge, setChallenge] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function send(key: (typeof CALM)[number]) {
    setBusy(true);
    const res = await sendMessage(t(`${key}.message`));
    setBusy(false);
    if (res.ok) {
      setSent(key);
      toast(t("calm.sent"));
    } else toast(t("calm.error"));
  }

  return (
    <section className="card card--soft stack stack--4 after-game" aria-labelledby="after-title">
      <div className="stack stack--2">
        <h2 className="t-card" id="after-title">{t("calm.title")}</h2>
        <p className="t-small">{t("calm.text")}</p>
      </div>
      <div className="stack stack--2">
        {CALM.map((k) => (
          <button key={k} className="btn btn--secondary btn--sm" disabled={busy || !online || sent === k} onClick={() => void send(k)}>
            {sent === k && <Icon name="check" size={16} />}{t(`${k}.label`)}
          </button>
        ))}
        <button className="btn btn--quiet btn--sm" onClick={onOpenChat}><Icon name="chat" size={18} />{t("calm.write")}</button>
      </div>
      <div className="stack stack--2">
        {challenge ? (
          <p className="t-body"><Icon name="sparkles" size={16} /> {challenge}</p>
        ) : (
          <button className="btn btn--quiet btn--sm" disabled={!online} onClick={async () => {
            const res = await rpc<{ text: string }>("get_light_challenge", {});
            setChallenge(res.ok ? (res as unknown as { text: string }).text : t("calm.noChallenge"));
          }}><Icon name="dices" size={18} />{t("calm.challenge")}</button>
        )}
        <p className="t-meta">{t("calm.optional")}</p>
      </div>
    </section>
  );
}
