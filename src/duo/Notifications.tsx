import { useNavigate } from "react-router";
import { t } from "../i18n";
import { Icon, Sheet, relativeDate, useToast, type IconName } from "../components/ui";
import { useDuo, type AppNotification } from "./DuoProvider";

const icons: Record<AppNotification["type"], IconName> = {
  invitation_claimed: "users",
  invitation_accepted: "heart",
  invitation_declined: "info",
  duo_ended: "info",
  game_proposed: "play",
  message: "chat",
  gentle_reminder: "sun",
};

export function notificationText(n: AppNotification) {
  const d = n.data as Record<string, string | number | undefined>;
  const name = String(d.name ?? d.from ?? "");
  if (n.type === "message" && Number(d.count ?? 1) > 1) return t("notif.messages", { count: Number(d.count), name });
  return t(`notif.${n.type}`, { name, title: String(d.title ?? "") });
}

/** Centre de notifications personnelles (ouvert depuis la cloche de l'en-tête). */
export function NotificationCenter({ onClose, onOpenChat }: { onClose: () => void; onOpenChat: () => void }) {
  const { notifications, notificationsUnread, markNotificationsRead, active, invitations, openSession } = useDuo();
  const navigate = useNavigate();
  const toast = useToast();

  // Chaque notification revérifie l'état actuel : un ancien événement n'autorise jamais une action devenue invalide.
  function open(n: AppNotification) {
    void markNotificationsRead([n.id]);
    const d = n.data as Record<string, string | undefined>;
    switch (n.type) {
      case "invitation_claimed":
        if (invitations.outgoing?.status === "claimed") { onClose(); navigate("/accueil"); }
        else toast(t("notif.stale"));
        return;
      case "invitation_accepted":
      case "duo_ended":
        onClose();
        navigate(n.couple_id ? `/espace?duo=${n.couple_id}` : "/espace");
        return;
      case "game_proposed":
        if (d.session_id && openSession?.id === d.session_id) { onClose(); navigate(`/partie/${d.session_id}`); }
        else toast(t("notif.stale"));
        return;
      case "message":
        onClose();
        if (n.couple_id && active?.id === n.couple_id) onOpenChat();
        else navigate(n.couple_id ? `/espace?duo=${n.couple_id}` : "/espace");
        return;
      case "gentle_reminder":
        onClose();
        navigate("/accueil");
        return;
      default:
        onClose();
    }
  }

  return (
    <Sheet
      side
      title={<h2 className="t-section">{t("notif.title")}</h2>}
      onClose={onClose}
    >
      {notificationsUnread > 0 && (
        <div className="row" style={{ justifyContent: "flex-end", marginTop: -8 }}>
          <button className="btn btn--quiet btn--auto btn--sm" onClick={() => void markNotificationsRead()}><Icon name="check" size={18} />{t("notif.markAll")}</button>
        </div>
      )}
      {notifications.length === 0 ? (
        <p className="muted center" style={{ padding: "24px 0" }}>{t("notif.empty")}</p>
      ) : (
        <ul className="list">
          {notifications.map((n) => (
            <li key={n.id}>
              <button className="list-row" onClick={() => open(n)} style={n.read_at ? undefined : { borderColor: "var(--c-border-control)" }}>
                <Icon name={icons[n.type]} />
                <span className="list-row__body">
                  <span className={n.read_at ? "t-small" : "t-small strong"}>{notificationText(n)}</span>
                  <span className="t-meta">
                    {!n.read_at && <><span className="tag" style={{ minHeight: 20, padding: "0 8px", marginRight: 6 }}>{t("notif.new")}</span></>}
                    <time dateTime={n.created_at}>{relativeDate(n.created_at)}</time>
                  </span>
                </span>
                <Icon name="arrow-right" size={18} />
              </button>
            </li>
          ))}
        </ul>
      )}
    </Sheet>
  );
}
