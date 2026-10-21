import type { RealtimeChannel } from "@supabase/supabase-js";
import { supabase } from "./supabase";

export type ChannelStatus = "connecting" | "live" | "down";

interface Options {
  /** Événements diffusés par la base (jamais par les navigateurs). */
  broadcast?: Record<string, (payload: Record<string, unknown>) => void>;
  /** Présence : identité publiée par ce navigateur (informative seulement). */
  presenceKey?: string;
  onPresence?: (keys: string[]) => void;
  onStatus?: (status: ChannelStatus) => void;
}

/**
 * Abonnement à un canal privé (autorisé par les politiques de la base).
 * La présence sert uniquement à l'affichage ; l'état réel est toujours relu depuis la base.
 */
export function subscribePrivate(topic: string, opts: Options): () => void {
  let channel: RealtimeChannel | null = null;
  let cancelled = false;

  void (async () => {
    const { data } = await supabase.auth.getSession();
    await supabase.realtime.setAuth(data.session?.access_token ?? null);
    if (cancelled) return;
    channel = supabase.channel(topic, {
      config: { private: true, presence: opts.presenceKey ? { key: opts.presenceKey } : undefined },
    });
    for (const [event, handler] of Object.entries(opts.broadcast ?? {})) {
      channel.on("broadcast", { event }, (msg) => handler((msg.payload ?? {}) as Record<string, unknown>));
    }
    if (opts.onPresence) {
      channel.on("presence", { event: "sync" }, () => {
        opts.onPresence?.(Object.keys(channel?.presenceState() ?? {}));
      });
    }
    opts.onStatus?.("connecting");
    channel.subscribe((status) => {
      if (status === "SUBSCRIBED") {
        opts.onStatus?.("live");
        if (opts.presenceKey) void channel?.track({ at: new Date().toISOString() });
      } else if (status === "CHANNEL_ERROR" || status === "TIMED_OUT" || status === "CLOSED") {
        opts.onStatus?.("down");
      }
    });
  })();

  return () => {
    cancelled = true;
    if (channel) void supabase.removeChannel(channel);
  };
}
