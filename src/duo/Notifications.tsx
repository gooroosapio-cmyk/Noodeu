import { useEffect, useRef, useState } from "react";
import { useLocation, useNavigate } from "react-router";
import { t } from "../i18n";
import { Icon, Sheet, relativeDate, useToast, type IconName } from "../components/ui";
import { useDuo, type AppNotification } from "./DuoProvider";

/** Apparence par type : icône, teinte et action. Jamais la couleur seule : icône, titre et libellé d'action. */
type Look = { icon: IconName; tone: "lavender" | "peach" | "mint" | "butter" | "neutral"; action?: string };
const LOOKS: Record<AppNotification["type"], Look> = {
  nudge: { icon: "bell", tone: "lavender", action: "notif.action.resume" },
  game_proposed: { icon: "play", tone: "peach", action: "notif.action.join" },
  invitation_claimed: { icon: "users", tone: "peach", action: "notif.action.see" },
  invitation_accepted: { icon: "heart", tone: "mint", action: "notif.action.see" },
  invitation_declined: { icon: "info", tone: "neutral" },
  duo_ended: { icon: "info", tone: "neutral" },
  gentle_reminder: { icon: "sun", tone: "butter", action: "notif.action.open" },
  message: { icon: "chat", tone: "neutral" },
};

export function notificationText(n: AppNotification) {
  const d = n.data as Record<string, string | number | undefined>;
  const name = String(d.name ?? d.from ?? "");
  return t(`notif.${n.type}`, { name, title: String(d.title ?? "") });
}

function subText(n: AppNotification) {
  const d = n.data as Record<string, string | number | undefined>;
  if (n.type === "nudge" || n.type === "game_proposed") return String(d.title ?? "");
  return "";
}

/** Les messages restent dans la discussion : ils n'apparaissent jamais dans les notifications. */
const visible = (list: AppNotification[]) => list.filter((n) => n.type !== "message");

/** Centre de notifications personnelles (ouvert depuis la cloche de l'en-tête). */
export function NotificationCenter({ onClose }: { onClose: () => void; onOpenChat?: () => void }) {
  const { notifications, markNotificationsRead, active, activeDuos, switchDuo, invitations } = useDuo();
  const navigate = useNavigate();
  const toast = useToast();
  const [filter, setFilter] = useState<"all" | "unread">("all");
  const list = visible(notifications);
  const unread = list.filter((n) => !n.read_at).length;
  const shown = filter === "unread" ? list.filter((n) => !n.read_at) : list;

  // Notification d'un autre de mes duos actifs : on bascule d'abord sur ce duo (jamais sur un duo dont je ne suis pas membre).
  async function openInDuo(n: AppNotification, sessionId?: string) {
    const target = n.couple_id && activeDuos.find((x) => x.id === n.couple_id);
    if (target && active?.id !== target.id) await switchDuo(target.id);
    onClose();
    if (target && sessionId) navigate(`/partie/${sessionId}`);
    else toast(t("notif.stale"));
  }

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
      case "nudge":
        void openInDuo(n, d.session_id);
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
    <Sheet side title={<h2 className="t-section">{t("notif.title")}</h2>} onClose={onClose}>
      <div className="notif-tools">
        <div className="chips" role="tablist" aria-label={t("notif.filter")}>
          <button className="chip" role="tab" aria-selected={filter === "all"} onClick={() => setFilter("all")}>{t("notif.all")}</button>
          <button className="chip" role="tab" aria-selected={filter === "unread"} onClick={() => setFilter("unread")}>{t("notif.unread", { n: unread })}</button>
        </div>
        {unread > 0 && <button className="btn btn--quiet btn--auto btn--sm" onClick={() => void markNotificationsRead()}><Icon name="check" size={18} />{t("notif.markAll")}</button>}
      </div>
      {shown.length === 0 ? (
        <div className="notif-empty">
          <img src="/assets/premium/shared/waiting.svg" alt="" aria-hidden="true" width={96} height={96} />
          <p className="muted center">{filter === "unread" ? t("notif.emptyUnread") : t("notif.empty")}</p>
        </div>
      ) : (
        <ul className="notif-list">
          {shown.map((n) => {
            const look = LOOKS[n.type] ?? LOOKS.duo_ended;
            const sub = subText(n);
            return (
              <li key={n.id} className={`notif notif--${look.tone}${n.read_at ? "" : " is-unread"}`}>
                <span className="notif__icon" aria-hidden="true"><Icon name={look.icon} size={20} /></span>
                <div className="notif__body">
                  <p className="notif__title">{notificationText(n)}</p>
                  {sub && <p className="notif__sub">{sub}</p>}
                  <p className="notif__time">
                    {!n.read_at && <span className="sr-only">{t("notif.new")} · </span>}
                    <time dateTime={n.created_at}>{relativeDate(n.created_at)}</time>
                  </p>
                  {look.action
                    ? <button className="notif__action" onClick={() => open(n)}>{t(look.action as never)}</button>
                    : !n.read_at && <button className="notif__action notif__action--quiet" onClick={() => open(n)}>{t("notif.action.ok")}</button>}
                </div>
                {!n.read_at && <span className="notif__dot" aria-hidden="true" />}
              </li>
            );
          })}
        </ul>
      )}
    </Sheet>
  );
}

/**
 * Relance reçue pendant que l'app est ouverte : bandeau discret en haut (6 s), action « Reprendre ».
 * Il ne prend jamais le focus ; la notification reste dans le centre tant qu'elle n'est pas lue.
 */
export function NudgeBanner() {
  const { notifications, markNotificationsRead, activeDuos, active, switchDuo } = useDuo();
  const navigate = useNavigate();
  const { pathname } = useLocation();
  const seen = useRef<Set<string>>(new Set());
  const [openedAt] = useState(() => Date.now());
  const [current, setCurrent] = useState<AppNotification | null>(null);

  // Seules les relances reçues pendant que l'app est ouverte s'affichent ; les plus anciennes restent dans le centre.
  useEffect(() => {
    const fresh = notifications.find((n) => n.type === "nudge" && !n.read_at && !seen.current.has(n.id)
      && new Date(n.created_at).getTime() > openedAt - 5000);
    notifications.forEach((n) => seen.current.add(n.id));
    if (fresh) setCurrent(fresh);
  }, [notifications, openedAt]);

  useEffect(() => {
    if (!current) return;
    const id = setTimeout(() => setCurrent(null), 6000);
    return () => clearTimeout(id);
  }, [current]);

  if (!current) return null;
  const d = current.data as Record<string, string | undefined>;
  const here = d.session_id && pathname === `/partie/${d.session_id}`;
  return (
    <div className="nudge-banner" role="status">
      <span className="notif__icon" aria-hidden="true"><Icon name="bell" size={20} /></span>
      <div className="grow">
        <p className="notif__title">{t("notif.nudge", { name: d.name ?? "" })}</p>
        {d.title && <p className="notif__sub">{d.title}</p>}
      </div>
      {!here && d.session_id && (
        <button className="notif__action" onClick={async () => {
          void markNotificationsRead([current.id]);
          const target = current.couple_id && activeDuos.find((x) => x.id === current.couple_id);
          if (target && active?.id !== target.id) await switchDuo(target.id);
          setCurrent(null);
          navigate(`/partie/${d.session_id}`);
        }}>{t("notif.action.resume")}</button>
      )}
      <button className="icon-btn" onClick={() => setCurrent(null)} aria-label={t("common.close")}><Icon name="close" size={18} /></button>
    </div>
  );
}
