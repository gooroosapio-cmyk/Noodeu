import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "../lib/supabase";
import type { Profile } from "../lib/types";

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
    const { data, error } = await supabase
      .from("profiles")
      .select("id, display_name, word_form, intimate_opt_in, reduced_motion")
      .eq("id", userId)
      .maybeSingle();
    // Erreur réseau ou profil absent : l'interface propose de réessayer au lieu d'attendre indéfiniment.
    setProfileError(Boolean(error) || !data);
    if (data) setProfile(data as Profile);
  }, [userId]);

  useEffect(() => {
    void refreshProfile();
  }, [refreshProfile]);

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
