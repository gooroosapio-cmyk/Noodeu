import { useEffect, useState } from "react";
import { t } from "../i18n";
import { rpc } from "../lib/supabase";
import { useToast, Icon } from "../components/ui";

/** « Plus tard » : la question rejoint l'espace personnel, sans prévenir l'autre ni modifier la partie. */
export function LaterButton({ sessionId, round, disabled }: { sessionId: string; round: number; disabled?: boolean }) {
  const toast = useToast();
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);
  useEffect(() => setSaved(false), [round]);
  return (
    <button type="button" className="btn btn--quiet btn--sm btn--auto" disabled={disabled || busy || saved} title={t("rhythm.laterHint")}
      onClick={async () => {
        setBusy(true);
        const res = await rpc("save_for_later", { p_session: sessionId, p_round: round });
        setBusy(false);
        if (res.ok) {
          setSaved(true);
          toast(t("rhythm.laterSaved"));
        }
      }}>
      <Icon name={saved ? "bookmark-filled" : "bookmark"} size={18} />{saved ? t("rhythm.laterDone") : t("rhythm.later")}
    </button>
  );
}
