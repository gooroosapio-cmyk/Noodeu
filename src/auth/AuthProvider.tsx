import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session } from "@supabase/supabase-js";
import { rpc, supabase } from "../lib/supabase";
import type { Profile } from "../lib/types";

/** Valeurs par défaut des réglages personnels (identiques à celles de la base). */
const DEFAULT_PREFS: Pick<Profile, "max_intensity" | "adult_confirmed_at" | "daily_adult" | "timezone" | "country" | "reminders"> = {
  max_intensity: "moyen", adult_confirmed_at: null, daily_adult: false, timezone: null, country: null,
  reminders: { enabled: false, per_week: 2, quiet_start: 21, quiet_end: 9 },
};

interface AuthValue {
  loading: boolean;
  session: Session | null;
  userId: string | null;
  profile: Profile | null;
  profileError: boolean;
  refreshProfile: () => Promise<void>;
  updateProfile: (patch: Partial<Omit<Profile, "id">>) => Promise<string | null>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [profileError, setProfileError] = useState(false);
  const userId = session?.user.id ?? null;

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setLoading(false);
    });
    const { data } = supabase.auth.onAuthStateChange((_event, s) => {
      setSession(s);
      // Les canaux temps réel privés utilisent le jeton de la session courante.
      void supabase.realtime.setAuth(s?.access_token ?? null);
    });
    return () => data.subscription.unsubscribe();
  }, []);

  const refreshProfile = useCallback(async () => {
    if (!userId) {
      setProfile(null);
      return;
    }
    // Colonnes publiques (visibles du duo) puis réglages personnels, lisibles par la seule personne concernée.
    const [{ data, error }, prefs] = await Promise.all([
      supabase.from("profiles").select("id, display_name, word_form, intimate_opt_in, reduced_motion, avatar_path").eq("id", userId).maybeSingle(),
      rpc<Partial<Profile>>("get_my_prefs", {}),
    ]);
    // Erreur réseau ou profil absent : l'interface propose de réessayer au lieu d'attendre indéfiniment.
    setProfileError(Boolean(error) || !data);
    if (data) {
      const { ok: _ok, ...own } = prefs.ok ? prefs : { ok: false };
      setProfile({ ...DEFAULT_PREFS, ...(data as Profile), ...own });
    }
  }, [userId]);

  useEffect(() => {
    void refreshProfile();
  }, [refreshProfile]);

  // Fuseau de l'appareil, enregistré une fois (question du jour et heures calmes des rappels).
  useEffect(() => {
    if (!userId || !profile || profile.timezone) return;
    let tz = "";
    try {
      tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    } catch {
      return;
    }
    if (tz) void supabase.from("profiles").update({ timezone: tz }).eq("id", userId).then(({ error }) => {
      if (!error) setProfile((p) => (p ? { ...p, timezone: tz } : p));
    });
  }, [userId, profile]);

  useEffect(() => {
    document.documentElement.classList.toggle("reduced-motion", Boolean(profile?.reduced_motion));
  }, [profile?.reduced_motion]);

  const updateProfile = useCallback(
    async (patch: Partial<Omit<Profile, "id">>) => {
      if (!userId) return "not_authenticated";
      const { error } = await supabase.from("profiles").update(patch).eq("id", userId);
      if (error) return error.message;
      setProfile((p) => (p ? { ...p, ...patch } : p));
      return null;
    },
    [userId],
  );

  const signOut = useCallback(async () => {
    // Nettoyage des données privées locales (brouillons, liens de photo) à la déconnexion.
    try {
      for (const k of Object.keys(sessionStorage)) if (k.startsWith("noodeu.")) sessionStorage.removeItem(k);
    } catch {
      /* stockage indisponible */
    }
    await supabase.removeAllChannels();
    await supabase.auth.signOut();
    setProfile(null);
  }, []);

  return (
    <AuthContext.Provider value={{ loading, session, userId, profile, profileError, refreshProfile, updateProfile, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth hors de AuthProvider");
  return ctx;
}
