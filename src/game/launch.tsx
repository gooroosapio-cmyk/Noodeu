import { useState } from "react";
import { useNavigate } from "react-router";
import { t } from "../i18n";
import { errorMessage } from "../lib/errors";
import { rpc } from "../lib/supabase";
import { useDuo } from "../duo/DuoProvider";
import { ConfirmDialog } from "../components/ui";

interface Pending { gameId: string; title: string; settings?: Record<string, unknown> }

/**
 * Lancement d'une activité : si une autre partie est déjà ouverte, on demande d'abord s'il faut la fermer
 * (elle s'arrête alors pour les deux, comme « Arrêter la partie »), au lieu de bloquer.
 */
export function useLaunch() {
  const { openSession, refresh } = useDuo();
  const navigate = useNavigate();
  const [pending, setPending] = useState<Pending | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const otherFor = (gameId: string) =>
    openSession && openSession.game_id !== gameId && openSession.status !== "ended" ? openSession : null;

  async function start(p: Pending) {
    const res = await rpc<{ session_id: string }>("create_session", { p_game: p.gameId });
    if (!res.ok) {
      setError(errorMessage(res.error));
      return;
    }
    if (p.settings) {
      const settingsResult = await rpc("update_session_settings", { p_session: res.session_id, p_settings: p.settings });
      if (!settingsResult.ok) { setError(errorMessage(settingsResult.error)); return; }
    }
    navigate(`/partie/${res.session_id}`);
  }

  async function launch(gameId: string, title: string, settings?: Record<string, unknown>) {
    if (busy) return;
    setError(null);
    if (otherFor(gameId)) {
      setPending({ gameId, title, settings });
      return;
    }
    setBusy(true);
    await start({ gameId, title, settings });
    setBusy(false);
  }

  async function closeOtherAndLaunch() {
    const p = pending;
    const other = p && otherFor(p.gameId);
    if (!p || !other) return;
    setBusy(true);
    const res = await rpc("abandon_session", { p_session: other.id });
    if (!res.ok) {
      setError(errorMessage(res.error));
      setBusy(false);
      setPending(null);
      return;
    }
    await refresh();
    setPending(null);
    await start(p);
    setBusy(false);
  }

  const other = pending ? otherFor(pending.gameId) : null;
  const dialog = pending && other ? (
    <ConfirmDialog
      title={t("launch.closeTitle", { title: other.title })}
      text={t("launch.closeText", { title: other.title, next: pending.title })}
      confirmLabel={t("launch.closeConfirm")}
      danger
      busy={busy}
      onCancel={() => setPending(null)}
      onConfirm={() => void closeOtherAndLaunch()}
    />
  ) : null;

  return { launch, busy, error, dialog, otherFor };
}
