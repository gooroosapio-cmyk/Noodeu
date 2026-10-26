import { Suspense, lazy, useEffect, type ComponentType } from "react";
import { Navigate, Outlet, createBrowserRouter, useLocation } from "react-router";
import { Ambient } from "./components/Ambient";
import { useKeyboardInset } from "./lib/useKeyboardInset";
import { useRegisterSW } from "virtual:pwa-register/react";
import { t } from "./i18n";
import { supabaseConfigured } from "./lib/supabase";
import { AuthProvider, useAuth } from "./auth/AuthProvider";
import { AuthForm, Onboarding, Welcome, needsOnboarding } from "./auth/AuthScreens";
import { DuoProvider } from "./duo/DuoProvider";
import { InvitePage } from "./duo/InviteScreens";
import { Alert, EmptyState, NetworkBanner, PageLoading, ToastProvider } from "./components/ui";
import { GameInvitation } from "./duo/GameInvitation";
import { NudgeBanner } from "./duo/Notifications";
import { AppShell } from "./components/AppShell";
import { Home } from "./screens/Home";
import { GameSheet, Libraries, ShelfPage } from "./screens/Libraries";
import { OurSpace } from "./screens/OurSpace";
import { HistoryPage } from "./screens/History";
import { VaultPage } from "./screens/Vault";
import { ProfileEdit, Settings } from "./screens/Settings";
import { Tips } from "./screens/Tips";

/** Écran chargé à la demande. Après un déploiement, un ancien fichier peut avoir disparu :
 *  on recharge alors la page une seule fois (garde en sessionStorage) au lieu d'afficher une erreur. */
function deferred(load: () => Promise<ComponentType>) {
  const Screen = lazy(() => load().then(
    (component) => { try { sessionStorage.removeItem("noodeu.chunk-reload"); } catch { /* stockage indisponible */ } return { default: component }; },
    (error: unknown) => {
      let retried = true;
      try { retried = sessionStorage.getItem("noodeu.chunk-reload") === "1"; sessionStorage.setItem("noodeu.chunk-reload", "1"); } catch { /* stockage indisponible */ }
      if (!retried) { window.location.reload(); return new Promise<never>(() => undefined); }
      throw error;
    },
  ));
  return function DeferredScreen() { return <Suspense fallback={<PageLoading />}><Screen /></Suspense>; };
}
const loadSession = () => import("./game/SessionScreen").then((m) => m.SessionScreen);
const SessionScreen = deferred(loadSession);
const AdminQuestions = deferred(() => import("./admin/AdminQuestions").then((m) => m.AdminQuestions));

/** Une fois connecté, l'écran de jeu est préchargé pendant un temps mort : entrer en partie reste immédiat. */
function usePrefetchGame() {
  useEffect(() => {
    const idle = window.requestIdleCallback ?? ((cb: () => void) => window.setTimeout(cb, 2500));
    const cancel = window.cancelIdleCallback ?? window.clearTimeout;
    const id = idle(() => void loadSession().catch(() => undefined));
    return () => cancel(id);
  }, []);
}

/** Ancienne adresse « Notre espace » : redirigée vers l'Espace (paramètres conservés). */
function LegacySpace() {
  return <Navigate to={`/espace${useLocation().search}`} replace />;
}

function UpdatePrompt() {
  const location = useLocation();
  const { needRefresh: [needRefresh], updateServiceWorker } = useRegisterSW({
    // L'application installée reste souvent ouverte : on vérifie la présence d'une nouvelle version au retour
    // dans l'application et toutes les 15 minutes (sinon l'ancienne version reste servie par le cache).
    onRegisteredSW(_url, registration) {
      if (!registration) return;
      const check = () => {
        if (document.visibilityState === "visible" && navigator.onLine) void registration.update().catch(() => undefined);
      };
      setInterval(check, 15 * 60 * 1000);
      document.addEventListener("visibilitychange", check);
    },
  });
  // Hors d'une partie, la nouvelle version s'installe d'elle-même ; pendant une partie, on propose seulement.
  const inGame = location.pathname.startsWith("/partie/");
  useEffect(() => {
    if (needRefresh && !inGame) void updateServiceWorker(true);
  }, [needRefresh, inGame, updateServiceWorker]);
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
  useKeyboardInset();
  return (
    <AuthProvider>
      <ToastProvider>
        <Ambient />
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
  return <SignedIn />;
}

function SignedIn() {
  usePrefetchGame();
  return (
    <DuoProvider>
      <Outlet />
      <NudgeBanner />
      <GameInvitation />
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
              { path: "/conseils", element: <Tips /> },
              { path: "/astuces", element: <Navigate to="/conseils" replace /> },
              { path: "/espace", element: <OurSpace /> },
              { path: "/espace/coffre", element: <VaultPage /> },
              { path: "/espace/historique", element: <HistoryPage /> },
              { path: "/notre-espace", element: <LegacySpace /> },
              { path: "/parametres", element: <Navigate to="/reglages" replace /> },
              { path: "/reglages", element: <Settings /> },
            ],
          },
          { path: "/bibliotheques/questions", element: <ShelfPage shelf="questions" /> },
          { path: "/bibliotheques/tests", element: <ShelfPage shelf="tests" /> },
          { path: "/bibliotheques/a-huis-clos", element: <ShelfPage shelf="huisclos" /> },
          { path: "/bibliotheques/:gameId", element: <GameSheet /> },
          { path: "/reglages/profil", element: <ProfileEdit /> },
          { path: "/admin/questions", element: <AdminQuestions /> },
          { path: "/parametres/profil", element: <Navigate to="/reglages/profil" replace /> },
          { path: "/inviter", element: <InvitePage /> },
          { path: "/rejoindre", element: <InvitePage /> },
          { path: "/partie/:sessionId", element: <SessionScreen /> },
        ],
      },
      { path: "*", element: <Navigate to="/" replace /> },
    ],
  },
]);
