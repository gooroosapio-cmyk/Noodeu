import { Navigate, NavLink, Outlet, createBrowserRouter, useLocation } from "react-router";
import { useRegisterSW } from "virtual:pwa-register/react";
import { t } from "./i18n";
import { supabaseConfigured } from "./lib/supabase";
import { AuthProvider, useAuth } from "./auth/AuthProvider";
import { AuthForm, Onboarding, Welcome, needsOnboarding } from "./auth/AuthScreens";
import { CoupleProvider } from "./couple/CoupleProvider";
import { InvitePage } from "./couple/InviteScreens";
import { Alert, EmptyState, Icon, NetworkBanner, PageLoading, type IconName } from "./components/ui";
import { Home } from "./screens/Home";
import { GameSheet, Libraries } from "./screens/Libraries";
import { OurSpace, Settings, Tips } from "./screens/OtherTabs";
import { SessionScreen } from "./game/SessionScreen";

// Navigation imposée : exactement cinq entrées. Le jeu et le salon n'en font pas partie.
const tabs: { to: string; label: string; icon: IconName }[] = [
  { to: "/accueil", label: t("nav.home"), icon: "home" },
  { to: "/bibliotheques", label: t("nav.libraries"), icon: "library" },
  { to: "/astuces", label: t("nav.tips"), icon: "bulb" },
  { to: "/notre-espace", label: t("nav.space"), icon: "heart" },
  { to: "/parametres", label: t("nav.settings"), icon: "settings" },
];

function BottomNav() {
  return (
    <nav className="nav" aria-label={t("nav.label")}>
      {tabs.map((tab) => (
        <NavLink key={tab.to} to={tab.to}>
          <Icon name={tab.icon} />
          {/* Césures douces : coupure propre des libellés longs sur les écrans de 320 px. */}
          <span>{tab.label.replace("Bibliothèques", "Biblio\u00ADthèques").replace("Paramètres", "Para\u00ADmètres")}</span>
        </NavLink>
      ))}
    </nav>
  );
}

function UpdatePrompt() {
  const { needRefresh: [needRefresh], updateServiceWorker } = useRegisterSW();
  if (!needRefresh) return null;
  return (
    <div className="update-banner" role="status">
      <span>{t("update.available")}</span>
      <button className="btn btn--small" onClick={() => void updateServiceWorker(true)}>{t("update.reload")}</button>
    </div>
  );
}

function Root() {
  return (
    <AuthProvider>
      <NetworkBanner />
      {!supabaseConfigured && <div className="page" style={{ paddingBottom: 0 }}><Alert>{t("net.notConfigured")}</Alert></div>}
      <Outlet />
      <UpdatePrompt />
    </AuthProvider>
  );
}

/** Espace connecté : redirige vers l'accueil public si besoin, en gardant la destination. */
function RequireAuth({ withNav }: { withNav: boolean }) {
  const { loading, session, profile, profileError, refreshProfile, signOut } = useAuth();
  const location = useLocation();
  if (loading) return <PageLoading />;
  if (!session) return <Navigate to={`/?next=${encodeURIComponent(location.pathname + location.search)}`} replace />;
  if (!profile && profileError) {
    return (
      <main className="page page--bare">
        <EmptyState illustration="16-reconnexion" title={t("net.reconnecting")} text={t("net.offline")}>
          <button className="btn" onClick={() => void refreshProfile()}>{t("common.retry")}</button>
          <button className="btn btn--ghost" onClick={() => void signOut()}>{t("settings.logout")}</button>
        </EmptyState>
      </main>
    );
  }
  if (!profile) return <PageLoading />;
  if (needsOnboarding(profile)) return <Onboarding />;
  return (
    <CoupleProvider>
      <Outlet />
      {withNav && <BottomNav />}
    </CoupleProvider>
  );
}

export const router = createBrowserRouter([
  {
    element: <Root />,
    children: [
      { path: "/", element: <Welcome /> },
      { path: "/inscription", element: <AuthForm mode="signup" /> },
      { path: "/connexion", element: <AuthForm mode="login" /> },
      {
        element: <RequireAuth withNav />,
        children: [
          { path: "/accueil", element: <Home /> },
          { path: "/bibliotheques", element: <Libraries /> },
          { path: "/bibliotheques/:gameId", element: <GameSheet /> },
          { path: "/astuces", element: <Tips /> },
          { path: "/notre-espace", element: <OurSpace /> },
          { path: "/parametres", element: <Settings /> },
        ],
      },
      {
        element: <RequireAuth withNav={false} />,
        children: [
          { path: "/inviter", element: <InvitePage /> },
          { path: "/rejoindre", element: <InvitePage /> },
          { path: "/partie/:sessionId", element: <SessionScreen /> },
        ],
      },
      { path: "*", element: <Navigate to="/" replace /> },
    ],
  },
]);
