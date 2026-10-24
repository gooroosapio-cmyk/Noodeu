import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import { useAuth } from "../auth/AuthProvider";
import { rpc, supabase } from "../lib/supabase";
import { subscribePrivate } from "../lib/realtime";
import { onResume } from "../lib/useOnline";
import type { ChatMessage } from "../lib/types";

export interface DuoSummary {
  id: string;
  active: boolean;
  created_at: string;
  separated_at: string | null;
  partner: { id: string | null; name: string; avatar_path: string | null; deleted: boolean } | null;
  episodes: { started_at: string; ended_at: string | null }[];
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

export interface AppNotification {
  id: string;
  type: "invitation_claimed" | "invitation_accepted" | "invitation_declined" | "duo_ended" | "game_proposed" | "message" | "gentle_reminder";
  couple_id: string | null;
  data: Record<string, unknown>;
  created_at: string;
  read_at: string | null;
}

interface DuoValue {
  loading: boolean;
  error: boolean;
  duos: DuoSummary[];
  active: DuoSummary | null;
  partnerOnline: boolean;
  invitations: InvitationStatus;
  openSession: OpenSession | null;
  refresh: () => Promise<void>;
  // Chat du duo actif
  messages: ChatMessage[];
  chatUnread: number;
  sendMessage: (body: string, clientId?: string) => Promise<{ ok: boolean; error?: string }>;
  markChatRead: () => Promise<void>;
  loadArchive: (coupleId: string) => Promise<ChatMessage[]>;
  // Notifications personnelles
  notifications: AppNotification[];
  notificationsUnread: number;
  markNotificationsRead: (ids?: string[]) => Promise<void>;
}

const DuoContext = createContext<DuoValue | null>(null);
const noInvitations: InvitationStatus = { outgoing: null, incoming: null };

function mergeMessages(prev: ChatMessage[], incoming: ChatMessage[]) {
  const byClient = new Map(prev.map((m) => [m.client_id, m]));
  for (const m of incoming) {
    const existing = byClient.get(m.client_id);
    byClient.set(m.client_id, existing ? { ...existing, ...m, pending: false, failed: false } : m);
  }
  return [...byClient.values()].sort((a, b) => a.created_at.localeCompare(b.created_at));
}

export function DuoProvider({ children }: { children: ReactNode }) {
  const { userId } = useAuth();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [duos, setDuos] = useState<DuoSummary[]>([]);
  const [online, setOnline] = useState<string[]>([]);
  const [invitations, setInvitations] = useState<InvitationStatus>(noInvitations);
  const [openSession, setOpenSession] = useState<OpenSession | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [chatUnread, setChatUnread] = useState(0);
  const [notifications, setNotifications] = useState<AppNotification[]>([]);
  const active = duos.find((d) => d.active) ?? null;
  const activeId = active?.id ?? null;
  const activeRef = useRef<string | null>(null);
  activeRef.current = activeId;

  const loadNotifications = useCallback(async () => {
    const { data } = await supabase
      .from("notifications")
      .select("id, type, couple_id, data, created_at, read_at")
      .order("created_at", { ascending: false })
      .limit(50);
    if (data) setNotifications(data as AppNotification[]);
  }, []);

  const loadChat = useCallback(async (coupleId: string | null) => {
    if (!coupleId) {
      setMessages([]);
      setChatUnread(0);
      return;
    }
    const [{ data }, unread] = await Promise.all([
      supabase.from("duo_messages").select("id, user_id, client_id, body, created_at").eq("couple_id", coupleId)
        .order("created_at", { ascending: false }).limit(200),
      supabase.rpc("get_chat_unread"),
    ]);
    // Ignore une réponse arrivée après un changement de duo.
    if (activeRef.current !== coupleId) return;
    if (data) setMessages((prev) => mergeMessages(prev.filter((m) => m.pending || m.failed), (data as ChatMessage[]).reverse()));
    if (typeof unread.data === "number") setChatUnread(unread.data);
  }, []);

  const refresh = useCallback(async () => {
    if (!userId) return;
    const [d, inv, open] = await Promise.all([
      supabase.rpc("get_my_duos"),
      supabase.rpc("get_invitation_status"),
      supabase.rpc("get_open_session"),
    ]);
    if (d.error) {
      setError(true);
      setLoading(false);
      return;
    }
    setError(false);
    setDuos((d.data as DuoSummary[]) ?? []);
    setInvitations((inv.data as InvitationStatus) ?? noInvitations);
    setOpenSession((open.data as OpenSession | null) ?? null);
    setLoading(false);
    void loadNotifications();
  }, [userId, loadNotifications]);

  useEffect(() => {
    setLoading(true);
    void refresh();
    return onResume(() => {
      void refresh();
      void loadChat(activeRef.current);
    });
  }, [refresh, loadChat]);

  // Changement de duo : on vide la conversation affichée avant de charger la nouvelle.
  useEffect(() => {
    setMessages([]);
    setChatUnread(0);
    void loadChat(activeId);
  }, [activeId, loadChat]);

  useEffect(() => {
    if (!userId) return;
    return subscribePrivate(`user:${userId}`, {
      broadcast: {
        invitation: () => void refresh(),
        couple: () => void refresh(),
        notification: () => void loadNotifications(),
      },
    });
  }, [userId, refresh, loadNotifications]);

  useEffect(() => {
    if (!activeId || !userId) return;
    setOnline([]);
    return subscribePrivate(`couple:${activeId}`, {
      presenceKey: userId,
      onPresence: setOnline,
      onStatus: (s) => s === "live" && void loadChat(activeId),
      broadcast: {
        session: () => void refresh(),
        duo: () => void refresh(),
        chat: (p) => {
          const m = p as unknown as ChatMessage & { couple_id: string };
          if (m.couple_id !== activeRef.current) return;
          setMessages((prev) => mergeMessages(prev, [m]));
          if (m.user_id !== userId) setChatUnread((n) => n + 1);
        },
      },
    });
  }, [activeId, userId, refresh, loadChat]);

  // Filet de sécurité : relecture périodique légère (le temps réel peut être indisponible).
  useEffect(() => {
    const id = setInterval(() => {
      if (document.visibilityState !== "visible") return;
      void refresh();
      void loadChat(activeRef.current);
    }, 30000);
    return () => clearInterval(id);
  }, [refresh, loadChat]);

  const sendMessage = useCallback(
    async (body: string, clientId: string = crypto.randomUUID()) => {
      const optimistic: ChatMessage = { id: `local-${clientId}`, user_id: userId, client_id: clientId, body, created_at: new Date().toISOString(), pending: true };
      setMessages((prev) => mergeMessages(prev.filter((m) => m.client_id !== clientId), [optimistic]));
      const res = await rpc<{ id: string; created_at: string }>("send_duo_message", { p_client_id: clientId, p_body: body });
      setMessages((prev) =>
        prev.map((m) => (m.client_id === clientId ? (res.ok ? { ...m, id: res.id, created_at: res.created_at, pending: false, failed: false } : { ...m, pending: false, failed: true }) : m)),
      );
      return res;
    },
    [userId],
  );

  const markChatRead = useCallback(async () => {
    if (!activeRef.current) return;
    setChatUnread(0);
    await rpc("mark_chat_read", { p_couple: activeRef.current });
    void loadNotifications();
  }, [loadNotifications]);

  const loadArchive = useCallback(async (coupleId: string) => {
    const { data } = await supabase.from("duo_messages").select("id, user_id, client_id, body, created_at")
      .eq("couple_id", coupleId).order("created_at", { ascending: true }).limit(300);
    return (data as ChatMessage[]) ?? [];
  }, []);

  const markNotificationsRead = useCallback(async (ids?: string[]) => {
    const now = new Date().toISOString();
    setNotifications((prev) => prev.map((n) => (!ids || ids.includes(n.id) ? { ...n, read_at: n.read_at ?? now } : n)));
    await rpc("mark_notifications_read", { p_ids: ids ?? null });
  }, []);

  const partnerId = active?.partner?.id;
  const partnerOnline = Boolean(partnerId && online.includes(partnerId));
  const notificationsUnread = notifications.filter((n) => !n.read_at).length;

  return (
    <DuoContext.Provider
      value={{
        loading, error, duos, active, partnerOnline, invitations, openSession, refresh,
        messages, chatUnread, sendMessage, markChatRead, loadArchive,
        notifications, notificationsUnread, markNotificationsRead,
      }}
    >
      {children}
    </DuoContext.Provider>
  );
}

export function useDuo() {
  const ctx = useContext(DuoContext);
  if (!ctx) throw new Error("useDuo hors de DuoProvider");
  return ctx;
}
