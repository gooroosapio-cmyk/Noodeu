// Noodeu · Suppression de compte (fonction serveur Supabase).
// 1. Vérifie l'identité de l'appelant avec son jeton.
// 2. Termine son duo actif (l'autre membre est prévenu et garde l'historique en lecture seule).
// 3. Efface ses photos puis son compte (profil, favoris, notifications suivent par cascade).
// La clé secrète n'existe que côté serveur ; elle n'est jamais envoyée au navigateur.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function key(kind: "publishable" | "secret") {
  const json = Deno.env.get(kind === "publishable" ? "SUPABASE_PUBLISHABLE_KEYS" : "SUPABASE_SECRET_KEYS");
  if (json) {
    try {
      const keys = JSON.parse(json) as Record<string, string>;
      if (keys.default) return keys.default;
    } catch {
      /* format inattendu : on tente les clés historiques */
    }
  }
  return Deno.env.get(kind === "publishable" ? "SUPABASE_ANON_KEY" : "SUPABASE_SERVICE_ROLE_KEY")!;
}

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { ok: false, error: "method_not_allowed" });

  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return reply(401, { ok: false, error: "not_authenticated" });
  const url = Deno.env.get("SUPABASE_URL")!;

  const asUser = createClient(url, key("publishable"), { global: { headers: { Authorization: auth } } });
  const { data: { user }, error: userError } = await asUser.auth.getUser(auth.slice(7));
  if (userError || !user) return reply(401, { ok: false, error: "not_authenticated" });

  let body: { confirm?: string } = {};
  try {
    body = await req.json();
  } catch {
    /* corps absent */
  }
  if (body.confirm !== "SUPPRIMER") return reply(400, { ok: false, error: "confirmation_required" });

  // Fin du duo actif, avec les mêmes règles que dans l'application.
  const { error: leaveError } = await asUser.rpc("leave_couple");
  if (leaveError) return reply(500, { ok: false, error: "leave_failed" });

  const admin = createClient(url, key("secret"), { auth: { persistSession: false } });
  const { data: files } = await admin.storage.from("avatars").list(user.id, { limit: 100 });
  if (files?.length) await admin.storage.from("avatars").remove(files.map((f) => `${user.id}/${f.name}`));

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) return reply(500, { ok: false, error: "delete_failed" });
  return reply(200, { ok: true });
});
