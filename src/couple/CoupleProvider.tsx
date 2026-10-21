import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import { useAuth } from "../auth/AuthProvider";
import { supabase } from "../lib/supabase";
import { subscribePrivate } from "../lib/realtime";
import { onResume } from "../lib/useOnline";

export interface Partner {
  id: string | null;
  name: string;
}

export interface OpenSession {
  id: string;
  game_id: string;
  status: "lobby" | "playing" | "paused" | "ended";
  title: string;
}

export interface InvitationStatus {
  outgoing: { id: string; code: string; status: "open" | "claimed"; expires_at: string; expired: boolean; claimer_name: string | null } | null;
  incoming: { id: string; status: "claimed"; expires_at: string; inviter_name: string } | null;
}

interface CoupleValue {
  loading: boolean;
  error: boolean;
  coupleId: string | null;
  since: string | null;
  partner: Partner | null;
  partnerOnline: boolean;
  invitations: InvitationStatus;
  openSession: OpenSession | null;
  refresh: () => Promise<void>;
}

const CoupleContext = createContext<CoupleValue | null>(null);
const noInvitations: InvitationStatus = { outgoing: null, incoming: null };

export function CoupleProvider({ children }: { children: ReactNode }) {
  const { userId } = useAuth();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [coupleId, setCoupleId] = useState<string | null>(null);
  const [since, setSince] = useState<string | null>(null);
  const [partner, setPartner] = useState<Partner | null>(null);
  const [online, setOnline] = useState<string[]>([]);
  const [invitations, setInvitations] = useState<InvitationStatus>(noInvitations);
  const [openSession, setOpenSession] = useState<OpenSession | null>(null);

  const refresh = useCallback(async () => {
    if (!userId) return;
    const { data: mine, error: e1 } = await supabase
      .from("couple_members")
      .select("couple_id, joined_at, couples!inner(status)")
      .eq("user_id", userId)
      .is("left_at", null)
      .eq("couples.status", "active")
      .maybeSingle();
    if (e1) {
      setError(true);
      setLoading(false);
      return;
    }
    setError(false);
    const cid = (mine?.couple_id as string | undefined) ?? null;
    setCoupleId(cid);
    setSince((mine?.joined_at as string | undefined) ?? null);

    if (cid) {
      const { data: other } = await supabase
        .from("couple_members")
        .select("user_id, display_name_snapshot")
        .eq("couple_id", cid)
        .neq("user_id", userId)
        .maybeSingle();
      let name = (other?.display_name_snapshot as string) ?? "";
      if (other?.user_id) {
        const { data: prof } = await supabase.from("profiles").select("display_name").eq("id", other.user_id).maybeSingle();
        if (prof?.display_name) name = prof.display_name;
      }
      setPartner({ id: (other?.user_id as string) ?? null, name });
      const { data: open } = await supabase.rpc("get_open_session");
      setOpenSession((open as OpenSession | null) ?? null);
      setInvitations(noInvitations);
    } else {
      setPartner(null);
      setOpenSession(null);
      const { data } = await supabase.rpc("get_invitation_status");
      setInvitations((data as InvitationStatus) ?? noInvitations);
    }
    setLoading(false);
  }, [userId]);

  useEffect(() => {
    setLoading(true);
    void refresh();
    return onResume(() => void refresh());
  }, [refresh]);

  // Notifications personnelles (invitation acceptée, demande reçue, séparation).
  useEffect(() => {
    if (!userId) return;
    return subscribePrivate(`user:${userId}`, {
      broadcast: { invitation: () => void refresh(), couple: () => void refresh() },
    });
  }, [userId, refresh]);

  // Canal du couple : statut de la partie ouverte + présence (indicative).
  useEffect(() => {
    if (!coupleId || !userId) return;
    return subscribePrivate(`couple:${coupleId}`, {
      presenceKey: userId,
      onPresence: setOnline,
      broadcast: { session: () => void refresh() },
    });
  }, [coupleId, userId, refresh]);

  // Filet de sécurité : relecture périodique quand une invitation est en attente.
  useEffect(() => {
    if (coupleId || !(invitations.outgoing || invitations.incoming)) return;
    const id = setInterval(() => void refresh(), 15000);
    return () => clearInterval(id);
  }, [coupleId, invitations, refresh]);

  const partnerOnline = Boolean(partner?.id && online.includes(partner.id));

  return (
    <CoupleContext.Provider value={{ loading, error, coupleId, since, partner, partnerOnline, invitations, openSession, refresh }}>
      {children}
    </CoupleContext.Provider>
  );
}

export function useCouple() {
  const ctx = useContext(CoupleContext);
  if (!ctx) throw new Error("useCouple hors de CoupleProvider");
  return ctx;
}
