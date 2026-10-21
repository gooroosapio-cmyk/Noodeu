import { createContext, useContext, useLayoutEffect, useRef, useState, type ReactNode } from "react";
import { Link, NavLink, Outlet } from "react-router";
import { t } from "../i18n";
import { useAuth } from "../auth/AuthProvider";
import { useDuo } from "../duo/DuoProvider";
import { ChatLauncher, ChatPanel } from "../duo/Chat";
import { NotificationCenter } from "../duo/Notifications";
import { Avatar } from "./Avatar";
import { Icon, Logo, type IconName } from "./ui";

interface ShellValue {
  openChat: () => void;
}
const ShellContext = createContext<ShellValue>({ openChat: () => undefined });
export const useShell = () => useContext(ShellContext);

// Navigation imposée : exactement cinq destinations. Le jeu et son salon n'en font pas partie.
const tabs: { to: string; label: string; short?: string; icon: IconName }[] = [
  { to: "/accueil", label: t("nav.home"), icon: "home" },
  { to: "/bibliotheques", label: t("nav.libraries"), short: t("nav.librariesShort"), icon: "library" },
  { to: "/astuces", label: t("nav.tips"), icon: "bulb" },
  { to: "/espace", label: t("nav.space"), icon: "heart" },
  { to: "/reglages", label: t("nav.settings"), icon: "settings" },
];

function BottomNav() {
  const ref = useRef<HTMLElement>(null);
  // La barre peut grandir (texte agrandi) : l'espace réservé suit sa hauteur réelle.
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const root = document.documentElement;
    const ro = new ResizeObserver(() => root.style.setProperty("--nav-measured", `${el.offsetHeight}px`));
    ro.observe(el);
    return () => {
      ro.disconnect();
      root.style.removeProperty("--nav-measured");
    };
  }, []);
  return (
    <nav className="nav" aria-label={t("nav.label")} ref={ref}>
      {tabs.map((tab) => (
        <NavLink key={tab.to} to={tab.to} aria-label={tab.short ? tab.label : undefined}>
          <Icon name={tab.icon} size={24} />
          {tab.short ? (
            <span aria-hidden="true"><span className="nav__full--long">{tab.label}</span><span className="nav__short">{tab.short}</span></span>
          ) : (
            <span>{tab.label}</span>
          )}
        </NavLink>
      ))}
    </nav>
  );
}

/** En-tête compact : photo + cloche à gauche, logo à droite. */
export function TopBar({ onOpenNotifications, showBell = true }: { onOpenNotifications: () => void; showBell?: boolean }) {
  const { profile } = useAuth();
  const { notificationsUnread } = useDuo();
  return (
    <header className="topbar">
      <Link className="topbar__logo" to="/accueil" aria-label={t("top.home")}><Logo width={104} /></Link>
      <div className="topbar__actions">
        {showBell && (
          <button className="icon-btn" onClick={onOpenNotifications}
            aria-label={notificationsUnread ? t("top.notificationsUnread", { n: notificationsUnread }) : t("top.notifications")}>
            <Icon name="bell" size={24} />
            {notificationsUnread > 0 && <span className="badge-count" aria-hidden="true">{notificationsUnread > 9 ? "9+" : notificationsUnread}</span>}
          </button>
        )}
        <Link className="avatar-link" to="/reglages/profil" aria-label={t("top.profile")}>
          <Avatar name={profile?.display_name ?? ""} path={profile?.avatar_path} size={40} me />
        </Link>
      </div>
    </header>
  );
}

/** Pages principales connectées : en-tête, contenu, navigation basse et discussion flottante. */
export function AppShell() {
  const [panel, setPanel] = useState<"chat" | "notifications" | null>(null);
  return (
    <ShellContext.Provider value={{ openChat: () => setPanel("chat") }}>
      <div className="shell">
        <TopBar onOpenNotifications={() => setPanel("notifications")} />
        <Outlet />
        <BottomNav />
        {panel === null && <ChatLauncher onOpen={() => setPanel("chat")} />}
        {panel === "chat" && <ChatPanel onClose={() => setPanel(null)} />}
        {panel === "notifications" && <NotificationCenter onClose={() => setPanel(null)} onOpenChat={() => setPanel("chat")} />}
      </div>
    </ShellContext.Provider>
  );
}

/** Sous-pages et écran de jeu : retour explicite, sans navigation basse. */
export function SubPage({ title, backTo, children, actions }: { title?: string; backTo: string; children: ReactNode; actions?: ReactNode }) {
  return (
    <>
      <header className="topbar">
        <Link className="icon-btn icon-btn--soft" to={backTo} aria-label={t("common.back")}><Icon name="arrow-left" /></Link>
        {title && <span className="topbar__title">{title}</span>}
        <div className="row" style={{ gap: 4 }}>{actions}</div>
      </header>
      {children}
    </>
  );
}
