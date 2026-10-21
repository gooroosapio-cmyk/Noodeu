import { useEffect, useState } from "react";
import { useNavigate } from "react-router";
import { t } from "../i18n";
import { errorMessage } from "../lib/errors";
import { useOnline } from "../lib/useOnline";
import { useAuth } from "../auth/AuthProvider";
import { Avatar } from "../components/Avatar";
import { Alert, ConfirmDialog, Icon, Loading } from "../components/ui";
import { useSession } from "./useSession";

/**
 * Salon d'attente d'une partie, intégré à l'onglet Salon : qui est là, réglages, « Je suis disponible ».
 * La base démarre la partie quand les deux sont disponibles ; l'écran de jeu s'ouvre alors chez chacun.
 */
export function SessionLobby({ sessionId }: { sessionId: string }) {
  const { userId } = useAuth();
  const online = useOnline();
  const navigate = useNavigate();
  const s = useSession(sessionId, userId);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirmQuit, setConfirmQuit] = useState(false);
  const status = s.state?.session.status;

  useEffect(() => {
    if (status && status !== "lobby") navigate(`/partie/${sessionId}`);
  }, [status, sessionId, navigate]);

  async function run(fn: string, args: Record<string, unknown> = {}) {
    if (busy) return { ok: false };
    setBusy(true);
    setError(null);
    const res = await s.act(fn, args);
    if (!res.ok) setError(errorMessage(res.error));
    setBusy(false);
    return res;
  }

  if (!s.state) return <div className="card"><Loading /></div>;
  const st = s.state;
  const me = st.players.find((p) => p.is_me);
  const partner = st.players.find((p) => !p.is_me);
  const partnerHere = Boolean(partner?.user_id && s.present.includes(partner.user_id));
  const settings = st.game.config.settings ?? {};

  return (
    <section className="card stack stack--4" aria-labelledby="lobby-title">
      <div className="stack stack--2">
        <h2 className="t-section" id="lobby-title">{st.game.title}</h2>
        <p className="t-small muted">{t("game.lobbyText")}</p>
      </div>
      {s.channel === "down" && online && <Alert kind="info"><Loading label={t("net.reconnecting")} /></Alert>}
      {error && <Alert>{error}</Alert>}

      <div>
        {[me, partner].filter(Boolean).map((p) => (
          <div className="player" key={p!.seat}>
            <Avatar name={p!.display_name} path={p!.avatar_path} size={44} me={p!.is_me} />
            <div className="grow stack" style={{ gap: 2 }}>
              <span className="t-card">{p!.is_me ? `${p!.display_name} (${t("game.you")})` : p!.display_name}</span>
              <span className="status">
                <Icon name={p!.ready ? "check" : "clock"} size={16} />
                {p!.ready ? t("game.isReady") : t("game.isNotReady")}
                {!p!.is_me && partnerHere && <> · {t("game.here")}</>}
              </span>
            </div>
          </div>
        ))}
      </div>

      <details className="disclosure">
        <summary>{t("sheet.howTo")}<Icon name="chevron-down" /></summary>
        <div>
          <ol className="how">{st.game.rules.how_to.map((x) => <li key={x}>{x}</li>)}</ol>
          <p className="row t-small"><Icon name="lock" size={18} />{st.game.rules.privacy}</p>
        </div>
      </details>

      {Object.entries(settings).map(([key, def]) => (
        <fieldset key={key}>
          <legend>{def.label}</legend>
          <div className="chips">
            {def.options.map((opt) => (
              <button key={String(opt)} className="chip" aria-pressed={st.session.settings[key] === opt} disabled={busy || !online}
                onClick={() => run("update_session_settings", { p_settings: { [key]: opt } })}>{String(opt)}</button>
            ))}
          </div>
          <p className="t-meta">{t("game.settingsReset")}</p>
        </fieldset>
      ))}

      <button className="btn" disabled={busy || !online} onClick={() => run("set_ready", { p_ready: !me?.ready })}>
        {busy ? t("common.sending") : me?.ready ? t("game.notReady") : t("game.ready")}
      </button>
      <button className="btn btn--quiet btn--sm" disabled={busy} onClick={() => setConfirmQuit(true)}>{t("game.quit")}</button>

      {confirmQuit && (
        <ConfirmDialog title={t("game.quitTitle")} text={t("game.quitText", { name: partner?.display_name || "?" })} confirmLabel={t("game.quit")} danger busy={busy}
          onCancel={() => setConfirmQuit(false)}
          onConfirm={async () => { await run("abandon_session"); setConfirmQuit(false); }} />
      )}
    </section>
  );
}
