import { useEffect, useState } from "react";
import { supabase } from "../lib/supabase";

// Liens signés temporaires (stockage privé) gardés en mémoire pour éviter de les redemander à chaque écran.
const cache = new Map<string, { url: string; expires: number }>();
const TTL = 3600;

export function clearAvatarCache() {
  cache.clear();
}

export function useAvatarUrl(path: string | null | undefined) {
  const [url, setUrl] = useState<string | null>(() => (path ? cache.get(path)?.url ?? null : null));
  useEffect(() => {
    if (!path) {
      setUrl(null);
      return;
    }
    const hit = cache.get(path);
    if (hit && hit.expires > Date.now() + 60_000) {
      setUrl(hit.url);
      return;
    }
    let cancelled = false;
    void supabase.storage.from("avatars").createSignedUrl(path, TTL).then(({ data }) => {
      if (cancelled || !data?.signedUrl) return;
      cache.set(path, { url: data.signedUrl, expires: Date.now() + TTL * 1000 });
      setUrl(data.signedUrl);
    });
    return () => {
      cancelled = true;
    };
  }, [path]);
  return url;
}

/** Photo réelle ou initiale. Toujours décorative : le nom est donné par le texte ou le contrôle voisin. */
export function Avatar({ name, path, size = 40, me = false }: { name: string; path?: string | null; size?: number; me?: boolean }) {
  const url = useAvatarUrl(path);
  const [failed, setFailed] = useState(false);
  const initial = (name.trim()[0] ?? "?").toUpperCase();
  return (
    <span className={`avatar ${me ? "avatar--me" : ""}`} style={{ "--av": `${size}px` } as React.CSSProperties} aria-hidden="true">
      {url && !failed ? <img src={url} alt="" width={size} height={size} onError={() => setFailed(true)} /> : initial}
    </span>
  );
}
