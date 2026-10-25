// Relance « X t'attend » : un toucher envoie une notification de partie à l'autre (jamais un message de discussion).
// Les limites (20 s d'attente, 60 s entre deux envois, 3 par manche) sont décidées par le serveur.
import { useEffect, useState } from "react";
import { t } from "../../i18n";
import { rpc } from "../../lib/supabase";
import { Icon } from "../../components/ui";
import type { Player, SessionState } from "../../lib/types";

type State = { kind: "idle" } | { kind: "sending" } | { kind: "sent"; until: number } | { kind: "wait"; until: number } | { kind: "limit" } | { kind: "error" };

export function NudgeButton({ st, partner }: { st: SessionState; partner?: Player }) {
  const [state, setState] = useState<State>({ kind: "idle" });
  const [, tick] = useState(0);
  const until = state.kind === "sent" || state.kind === "wait" ? state.until : 0;
  useEffect(() => {
    if (!until) return;
    const id = setInterval(() => {
      tick((n) => n + 1);
      if (Date.now() >= until) setState({ kind: "idle" });
    }, 1000);
    return () => clearInterval(id);
  }, [until]);
  // Nouvelle manche : la relance redevient possible (le serveur garde ses propres limites).
  useEffect(() => setState({ kind: "idle" }), [st.session.current_round]);
  if (!partner || st.session.read_only) return null;
  const name = partner.display_name || "?";
  const left = Math.max(0, Math.ceil((until - Date.now()) / 1000));

  async function send() {
    setState({ kind: "sending" });
    const r = await rpc<{ retry_in?: number }>("send_nudge", { p_session: st.session.id });
    const retry = Number((r as unknown as { retry_in?: number }).retry_in ?? 60);
    if (r.ok) setState({ kind: "sent", until: Date.now() + retry * 1000 });
    else if (r.error === "too_soon" || r.error === "cooldown") setState({ kind: "wait", until: Date.now() + retry * 1000 });
    else if (r.error === "limit") setState({ kind: "limit" });
    else setState({ kind: "error" });
  }

  const label = state.kind === "sending" ? t("nudge.sending")
    : state.kind === "sent" ? t("nudge.sent", { s: left })
    : state.kind === "wait" ? t("nudge.wait", { s: left })
    : state.kind === "limit" ? t("nudge.limit")
    : t("nudge.send", { name });
  const disabled = state.kind !== "idle" && state.kind !== "error";
  return (
    <div className="stack stack--1">
      <button type="button" className={`nudge-btn${state.kind === "sent" ? " is-sent" : ""}`} disabled={disabled} aria-busy={state.kind === "sending"}
        onClick={() => void send()}>
        <Icon name={state.kind === "sent" ? "check" : "bell"} size={18} />{label}
      </button>
      {state.kind === "error" && <p className="t-meta center" role="status">{t("nudge.error")}</p>}
    </div>
  );
}
