import { createClient } from "@supabase/supabase-js";

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined;

export const supabaseConfigured = Boolean(url && key);

export const supabase = createClient(url ?? "https://invalid.local", key ?? "missing", {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: "pkce" },
});

export type RpcResult<T = Record<string, unknown>> = ({ ok: true } & T) | { ok: false; error: string };

/**
 * Appelle une fonction de la base. Les erreurs réseau ou SQL sont converties en { ok: false, error }
 * pour que l'interface affiche toujours un message compréhensible.
 */
export async function rpc<T = Record<string, unknown>>(fn: string, args?: Record<string, unknown>): Promise<RpcResult<T>> {
  try {
    const { data, error } = await supabase.rpc(fn, args);
    if (error) {
      const known = /^[a-z_]+$/.test(error.message) ? error.message : null;
      return { ok: false, error: known ?? (isNetworkError(error.message) ? "network" : "unexpected") };
    }
    if (data && typeof data === "object" && "ok" in data) return data as RpcResult<T>;
    return { ok: true, ...(data as T) };
  } catch (e) {
    return { ok: false, error: isNetworkError(String(e)) ? "network" : "unexpected" };
  }
}

function isNetworkError(message: string) {
  return /fetch|network|Failed to fetch|Load failed|NetworkError/i.test(message);
}
