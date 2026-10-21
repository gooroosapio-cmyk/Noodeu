import { Navigate, Outlet, createBrowserRouter, useLocation } from "react-router";
import { useRegisterSW } from "virtual:pwa-register/react";
import { t } from "./i18n";
import { supabaseConfigured } from "./lib/supabase";
import { AuthProvider, useAuth } from "./auth/AuthProvider";
import { AuthForm, Onboarding, Welcome, needsOnboarding } from "./auth/AuthScreens";
import { DuoProvider } from "./duo/DuoProvider";
import { InvitePage } from "./duo/InviteScreens";
import { Alert, EmptyState, NetworkBanner, PageLoading, ToastProvider } from "./components/ui";
import { AppShell } from "./components/AppShell";
import { Home } from "./screens/Home";
import { GameSheet, Libraries } from "./screens/Libraries";
import { OurSpace } from "./screens/OurSpace";
import { ProfileEdit, Settings } from "./screens/Settings";
import { Tips } from "./screens/Tips";
import { SessionScreen } from "./game/SessionScreen";

function UpdatePrompt() {
  const { needRefresh: [needRefresh], updateServiceWorker } = useRegisterSW();
  if (!needRefresh) return null;
  return (
    <div className="toast-region" style={{ pointerEvents: "auto" }}>
      <div className="toast row" role="status">
        <span className="grow">{t("update.available")}</span>
        <button className="btn btn--sm btn--auto" onClick={() => void updateServiceWorker(true)}>{t("update.reload")}</button>
      </div>
    </div>
  );
}

function Root() {
  return (
    <AuthProvider>
      <ToastProvider>
        <NetworkBanner />
        {!supabaseConfigured && <div className="page page--bare"><Alert>{t("net.notConfigured")}</Alert></div>}
        <Outlet />
        <UpdatePrompt />
      </ToastProvider>
    </AuthProvider>
  );
}

/** Espace connecté : redirige vers l'accueil public si besoin, en gardant la destination. */
function RequireAuth() {
  const { loading, session, profile, profileError, refreshProfile, signOut } = useAuth();
  const location = useLocation();
  if (loading) return <PageLoading />;
  if (!session) return <Navigate to={`/?next=${encodeURIComponent(location.pathname + location.search)}`} replace />;
  if (!profile && profileError) {
    return (
      <main className="page page--bare">
        <EmptyState illustration="16-reconnexion" title={t("net.reconnecting")} text={t("net.offline")}>
          <button className="btn" onClick={() => void refreshProfile()}>{t("common.retry")}</button>
          <button className="btn btn--quiet" onClick={() => void signOut()}>{t("settings.logout")}</button>
        </EmptyState>
      </main>
    );
  }
  if (!profile) return <PageLoading />;
  if (needsOnboarding(profile)) return <Onboarding />;
  return (
    <DuoProvider>
      <Outlet />
    </DuoProvider>
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
        element: <RequireAuth />,
        children: [
          {
            element: <AppShell />,
            children: [
              { path: "/accueil", element: <Home /> },
              { path: "/bibliotheques", element: <Libraries /> },
              { path: "/astuces", element: <Tips /> },
              { path: "/notre-espace", element: <OurSpace /> },
              { path: "/parametres", element: <Settings /> },
            ],
          },
          { path: "/bibliotheques/:gameId", element: <GameSheet /> },
          { path: "/parametres/profil", element: <ProfileEdit /> },
          { path: "/inviter", element: <InvitePage /> },
          { path: "/rejoindre", element: <InvitePage /> },
          { path: "/partie/:sessionId", element: <SessionScreen /> },
        ],
      },
      { path: "*", element: <Navigate to="/" replace /> },
    ],
  },
]);
