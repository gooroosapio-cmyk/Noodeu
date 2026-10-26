// Vérification VISUELLE du rendu (320 → 1440 px, faible hauteur, texte agrandi).
// ⚠️ Les réponses Supabase sont simulées ici UNIQUEMENT pour afficher les écrans connectés :
// ce script ne teste ni la synchronisation ni la sécurité (voir supabase/tests pour cela).
// Usage : npm run build && npx vite preview --port 4173 &  puis  node tests/visual/render-check.mjs [dossier]
// Variables : ONLY=<motif d'écran>, WIDTHS=320,390, ZOOM=2 (texte à 200 %), PW_CHROMIUM=<chemin du navigateur> FULL=1 (page entière)
import { chromium } from "@playwright/test";
import { mkdirSync, readFileSync } from "node:fs";

// États réels produits par la base locale (tests/visual/make_fixtures.py) : catalogue 2.1.0 et parties de la famille 1.
const FIX = new URL("./fixtures/", import.meta.url);
const fixture = (name) => JSON.parse(readFileSync(new URL(name, FIX), "utf8"));
const catalogue = fixture("catalogue.json");
// Catalogue final : questionnaire aléatoire de « Se découvrir » (bouton dédié, jamais listé comme un pack).
if (!catalogue.games.some((g) => g.id === "ND-Q-RND1")) {
  catalogue.games.push({ ...catalogue.games.find((g) => g.mechanic === "pack_conversation"), id: "ND-Q-RND1", title: "Questionnaire aléatoire",
    sort: 0, adult_available: true, content_level: "standard", meta: { random: true, code: "RND1" }, implementation: "playable" });
}
const playable = Object.keys(fixture("index.json"));

const BASE = process.env.BASE ?? "http://localhost:4173";
const OUT = process.argv[2] ?? "test-results/visual";
mkdirSync(OUT, { recursive: true });
const REF = "uqyrjdaonqqkkpzyjfcg";
const ME = "11111111-1111-4111-8111-111111111111";
const PARTNER = "22222222-2222-4222-8222-222222222222";
const SESSION = "33333333-3333-4333-8333-333333333333";
const DUO = "44444444-4444-4444-8444-444444444444";
const OLD_DUO = "55555555-5555-4555-8555-555555555555";

const words = ["curieux:Curieuse:Curieux", "calme:Calme:Calme", "fiable:Fiable:Fiable", "gourmand:Gourmande:Gourmand", "spontane:Spontanée:Spontané", "reveur:Rêveuse:Rêveur", "creatif:Créative:Créatif", "patient:Patiente:Patient", "sportif:Sportive:Sportif", "sociable:Sociable:Sociable", "drole:Drôle:Drôle", "perfectionniste:Perfectionniste:Perfectionniste"]
  .map((w) => { const [id, f, m] = w.split(":"); return { id: `portrait.${id}`, f, m }; });
const rules = {
  objective: "Te décrire en cinq mots…", how_to: ["Choisis cinq mots pour te décrire.", "Imagine les cinq mots que l'autre a choisis.", "Découvrez vos portraits ensemble."],
  details: ["Vous voyez tous les deux la même grille de mots."], privacy: "Vos réponses restent privées avant la révélation.",
  step_texts: { self: { title: "Mon portrait", prompt: "Quels mots te ressemblent ?", hint: "Choisis 5 mots pour te décrire.", confirm: "Confirmer mes mots" },
    guess: { title: "Son portrait", prompt: "Et {partner}, en cinq mots ?", hint: "Imagine les mots que {partner} a choisis.", confirm: "Confirmer mon portrait" } },
};
const config = { mechanic: "portrait_words", rounds: 1, pick: 5, steps: [{ key: "self", kind: "pick_words", about: "self" }, { key: "guess", kind: "pick_words", about: "partner" }], settings: { deck_size: { label: "Mots proposés", options: [12, 16], default: 12 } } };
const game = { id: "portrait-en-cinq-mots", category_id: "se-decouvrir", mechanic: "portrait_words", title: "Portrait en cinq mots", promise: "Se découvrir autrement, en quelques mots.", style: "echange", duration_min: 4, duration_max: 6, content_level: "standard", current_version: 1, sort: 1, is_demo: true };
const players = [
  { seat: 1, user_id: ME, is_me: true, display_name: "Maya", word_form: "f", avatar_path: null, ready: true, keep_memory: false },
  { seat: 2, user_id: PARTNER, is_me: false, display_name: "Alex", word_form: "m", avatar_path: null, ready: false, keep_memory: false },
];
const activeDuo = { id: DUO, active: true, created_at: "2026-10-01T10:00:00Z", separated_at: null, partner: { id: PARTNER, name: "Alex", avatar_path: null, deleted: false }, episodes: [{ started_at: "2026-10-01T10:00:00Z", ended_at: null }] };
const secondDuo = { id: "00000000-0000-4000-a000-00000000d002", active: true, current: false, unread: 3, created_at: "2026-10-20T10:00:00Z", separated_at: null, partner: { id: "y", name: "Camille", avatar_path: null, deleted: false }, episodes: [{ started_at: "2026-10-20T10:00:00Z", ended_at: null }] };
const archivedDuo = { id: OLD_DUO, active: false, created_at: "2026-08-01T10:00:00Z", separated_at: "2026-09-20T10:00:00Z", partner: { id: "x", name: "Sam", avatar_path: null, deleted: false }, episodes: [{ started_at: "2026-08-01T10:00:00Z", ended_at: "2026-09-20T10:00:00Z" }] };
function sessionState(status, answers = [], revealed = false) {
  return { ok: true, my_seat: 1, players, game: { title: game.title, mechanic: "portrait_words", rules, config },
    session: { id: SESSION, game_id: game.id, status, settings: { deck_size: 12 }, current_round: status === "lobby" ? 0 : 1, total_rounds: 1, paused_by: null, state_version: 5, read_only: false, created_at: new Date().toISOString(), ended_at: null },
    rounds: status === "lobby" ? [] : [{ round_no: 1, card: { words }, revealed, answers }] };
}
const pick = (ids) => ({ words: ids.map((i) => `portrait.${i}`) });
const notifications = [
  { id: "n0", type: "nudge", couple_id: DUO, data: { name: "Alex", title: "Deux vérités et un mensonge", session_id: SESSION }, created_at: new Date(Date.now() - 30000).toISOString(), read_at: null },
  { id: "n9", type: "message", couple_id: DUO, data: { name: "Alex", count: 3 }, created_at: new Date(Date.now() - 60000).toISOString(), read_at: null },
  { id: "n1", type: "game_proposed", couple_id: DUO, data: { name: "Alex", title: game.title, session_id: SESSION }, created_at: new Date(Date.now() - 600000).toISOString(), read_at: "2026-10-25T19:00:00Z" },
  { id: "n2", type: "invitation_accepted", couple_id: DUO, data: { name: "Alex" }, created_at: "2026-10-01T10:00:00Z", read_at: "2026-10-01T11:00:00Z" },
];
const messages = [
  { id: "m1", user_id: PARTNER, client_id: "c1", body: "Prête pour une partie ce soir ?", created_at: "2026-10-21T18:00:00Z" },
  { id: "m2", user_id: ME, client_id: "c2", body: "Oui ! Je lance Portrait en cinq mots.", created_at: "2026-10-21T18:02:00Z" },
];

async function setup(page, scenario) {
  await page.routeWebSocket("**", socket => socket.close());
  const exp = Math.floor(Date.now() / 1000) + 3600;
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const jwt = `${b64({ alg: "HS256", typ: "JWT" })}.${b64({ sub: ME, role: "authenticated", exp })}.sig`;
  if (scenario.auth !== false) {
    await page.addInitScript(([key, val]) => localStorage.setItem(key, val), [`sb-${REF}-auth-token`, JSON.stringify({ access_token: jwt, refresh_token: "r", token_type: "bearer", expires_in: 3600, expires_at: exp, user: { id: ME, email: "maya@exemple.fr", aud: "authenticated", role: "authenticated" } })]);
  }
  await page.route(`https://${REF}.supabase.co/**`, async (route) => {
    const url = new URL(route.request().url());
    const p = url.pathname;
    const json = (body) => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(body) });
    if (p.endsWith("/auth/v1/settings")) return json({ external: { google: true, email: true } });
    if (p.endsWith("/profiles")) return json([{ id: ME, display_name: "Maya", word_form: "f", intimate_opt_in: Boolean(scenario.intimate), reduced_motion: false, avatar_path: null }]);
    if (p.endsWith("/rpc/get_my_duos")) return json(scenario.duos ?? []);
    if (p.endsWith("/rpc/get_audio_capability")) return json({ok:true,enabled:false});
    if (p.endsWith("/rpc/get_duo_space")) return json({ok:true,cover_path:null,version:0,notes:[{id:"note1",body:"Choisir une idée pour notre prochain week-end",due_on:null,done:false,version:0}]});
    if (p.endsWith("/rpc/get_open_session")) return json(scenario.open ?? null);
    if (p.endsWith("/rpc/get_invitation_status")) return json(scenario.invitations ?? { outgoing: null, incoming: null });
    if (p.endsWith("/rpc/get_session_state")) return json(scenario.state ? {
      ...scenario.state, session: { ...scenario.state.session, id: route.request().postDataJSON().p_session }
    } : {ok:false,error:"not_found"});
    if (p.endsWith("/rpc/get_chat_unread")) return json(scenario.unread ?? 0);
    if (p.endsWith("/notifications")) return json(scenario.notifications ?? []);
    if (p.endsWith("/duo_messages")) return json(scenario.duos?.length ? messages : []);
    if (p.endsWith("/game_categories")) return json(catalogue.categories);
    if (p.endsWith("/games")) return json(catalogue.games);
    if (p.endsWith("/game_versions")) {
      const id = (url.searchParams.get("game_id") ?? "").replace(/^eq\./, "");
      return json(catalogue.rules[id] ? [{ rules: catalogue.rules[id] }] : [{ rules }]);
    }
    if (p.endsWith("/game_favorites")) return json([{ game_id: "ND-Q-P01" }, { game_id: "N2-076" }]);
    if (p.endsWith("/game_sessions")) {
      // Périmètre du duo, filtres, ordre et pagination (offset/limit), comme PostgREST.
      const q = new URL(route.request().url()).searchParams;
      const wanted = /^in\.\((.*)\)$/.exec(q.get("status") ?? "")?.[1]?.split(",");
      const coupleId = q.get("couple_id")?.replace(/^eq\./, "");
      const order = (q.get("order") ?? "").split(",").filter(Boolean).map((part) => part.split("."));
      const all = (scenario.history ?? []).filter((h) => (!coupleId || (h.couple_id ?? DUO) === coupleId) && (!wanted || wanted.includes(h.status)))
        .sort((a, b) => {
          for (const [column, direction] of order) {
            const cmp = String(a[column] ?? "").localeCompare(String(b[column] ?? ""));
            if (cmp) return direction === "desc" ? -cmp : cmp;
          }
          return 0;
        });
      const offset = Number(q.get("offset") ?? 0), limit = Number(q.get("limit") ?? all.length);
      const page = all.slice(offset, offset + limit);
      return route.fulfill({ status: 200, contentType: "application/json", headers: { "content-range": `${offset}-${offset + Math.max(page.length - 1, 0)}/${all.length}`, "access-control-expose-headers": "content-range" }, body: JSON.stringify(page) });
    }
    // Parcours : réglages personnels, plafond du duo, question du jour, progression, questions gardées.
    if (p.endsWith("/rpc/get_my_prefs")) return json({ ok: true, max_intensity: scenario.maxIntensity ?? "moyen", adult_confirmed_at: scenario.intimate ? "2026-10-01T10:00:00Z" : null,
      daily_adult: false, timezone: "Europe/Paris", country: scenario.country ?? "FR", reminders: { enabled: Boolean(scenario.reminders), per_week: 2, quiet_start: 21, quiet_end: 9 } });
    if (p.endsWith("/rpc/get_my_filters")) return json({ ok: true, my_max: "moyen", duo_cap: scenario.cap ?? 2, duo_adult: false, in_duo: Boolean(scenario.duos?.length) });
    if (p.endsWith("/rpc/get_daily")) return json({ ok: true, day: "2026-10-24", mode: "hasard", theme: null, redraws_left: 3, bank: "q_gottman_open", item_id: "GO-01",
      shared: Boolean(scenario.duos?.length), card: { text: "Quel souvenir de notre première année te fait encore sourire ?", theme: "Conversations à prendre le temps d'avoir",
        intensity: "soft", duration_kind: "discussion", minutes_min: 5, minutes_max: 10, long_followup: "Peux-tu donner un exemple précis ?" } });
    if (p.endsWith("/rpc/get_daily_themes")) return json(["Conversations à prendre le temps d'avoir", "Se retrouver"]);
    if (p.endsWith("/rpc/get_home_moment")) return json({ ok: true, question: "Quelle activité toute simple aimerais-tu essayer à deux ?", games_played: 3, server_now: new Date().toISOString(), expires_at: new Date(Date.now() + 3600000).toISOString() });
    if (p.endsWith("/rpc/get_progress")) return json({ ok: true, games: { "ND-Q-P01": { kind: "pack", count: 36, cards_done: 12, completed: false, viewed: 14, answered: 11, passed: 2 },
      "ND-Q-012": { kind: "test", me: "completed", partner: "pending" } } });
    if (p.endsWith("/rpc/get_my_items")) return json({ ok: true, later: [], favorites: [{ kind: "question", bank: "q_usu_roadtrip", item_id: "R-03",
      view: { text: "Quel voyage aimerais-tu que l'on fasse ensemble ?", intensity: "soft", duration_kind: "discussion", minutes_min: 5, minutes_max: 10 } }] });
    if (p.endsWith("/rpc/get_session_meta")) return json({ ok: true, items: {} });
    if (p.endsWith("/rpc/is_app_admin")) return json(Boolean(scenario.admin));
    if (p.endsWith("/rpc/admin_list_questions")) return json(scenario.admin ? fixture("admin-questions.json") : { ok: false, error: "forbidden" });
    if (/\/(item_favorites|later_items|item_feedback)$/.test(p)) return json(route.request().method() === "GET" ? null : []);
    return json({});
  });
}

const solo = { duos: [] };
// Historique fictif (données de démonstration) : titres et identifiants du catalogue, dates relatives.
const ago = (days, minutes = 0) => new Date(Date.now() - days * 86_400_000 - minutes * 60_000).toISOString();
const histo = (id, game_id, title, status, days, minutes, keep = false, extra = {}) => ({ id, game_id, status, created_at: ago(days, minutes + 5), started_at: ago(days, minutes + 5), ended_at: status === "abandoned" || ["lobby", "playing", "paused"].includes(status) ? null : ago(days, 5),
  current_round: 10, total_rounds: 10, games: { title }, session_players: [{ keep_memory: keep }, { keep_memory: keep }], ...extra });
const duo = { duos: [activeDuo, archivedDuo], unread: 2, notifications, history: [
  histo("00000000-0000-4000-a000-0000000000h1", "nd-action-verite", "Action ou Vérité", "ended", 0, 0, true),
  histo("00000000-0000-4000-a000-0000000000h2", "N2-003", "Je n’ai jamais", "ended", 1, 5),
  histo("00000000-0000-4000-a000-0000000000h3", "N2-002", "Tu préfères", "closed", 4, -2, true),
  histo(SESSION, game.id, game.title, "closed", 6, 5, true),
  histo("00000000-0000-4000-a000-0000000000h5", "nd-de-chanceux", "Le Dé chanceux", "ended", 7, 8),
  histo("00000000-0000-4000-a000-0000000000h6", "N2-018", "Petit bac", "ended", 8, 10),
] };
const allScreens = [
  { name: "01-bienvenue", path: "/", scenario: { auth: false } },
  { name: "02a-connexion", path: "/connexion", scenario: { auth: false } },
  { name: "02-inscription", path: "/inscription", scenario: { auth: false } },
  { name: "70-admin-questions", path: "/admin/questions", scenario: { ...solo, admin: true } },
  { name: "70b-admin-sous-categorie", path: "/admin/questions", scenario: { ...solo, admin: true },
    action: async (page) => { await page.getByLabel("Sous-catégorie").selectOption("Tu préfères"); await page.getByRole("button", { name: "Ajouter une question" }).click(); } },
  { name: "70c-admin-modifier", path: "/admin/questions", scenario: { ...solo, admin: true },
    action: async (page) => { await page.getByRole("button", { name: "Modifier" }).first().click(); } },
  { name: "70d-reglages-admin", path: "/reglages", scenario: { ...solo, admin: true } },
  { name: "06a-accueil-sans-duo", path: "/accueil", scenario: solo },
  { name: "06b-accueil-invitation", path: "/accueil", scenario: { ...solo, invitations: { outgoing: { id: "i", code: "K7PM-Q2RX", status: "open", expires_at: "2026-10-22T10:00:00Z", expired: false, claimer_name: null }, incoming: null } } },
  { name: "06c-accueil-demande", path: "/accueil", scenario: { ...solo, invitations: { outgoing: { id: "i", code: "K7PM-Q2RX", status: "claimed", expires_at: "2026-10-22T10:00:00Z", expired: false, claimer_name: "Alex" }, incoming: null } } },
  { name: "06d-accueil-duo", path: "/accueil", scenario: { ...duo, open: { id: SESSION, game_id: game.id, status: "playing", title: game.title } } },
  { name: "06e-accueil-duo-libre", path: "/accueil", scenario: duo },
  { name: "04-inviter", path: "/inviter", scenario: { ...solo, invitations: { outgoing: { id: "i", code: "K7PM-Q2RX", status: "open", expires_at: "2026-10-22T10:00:00Z", expired: false, claimer_name: null }, incoming: null } } },
  { name: "04b-rejoindre", path: "/rejoindre", scenario: solo },
  { name: "07-bibliotheques", path: "/bibliotheques", scenario: duo },
  { name: "07b-recherche", path: "/bibliotheques", scenario: duo, action: async (page) => page.getByLabel("Rechercher un jeu").fill("questions") },
  { name: "08a-packs-c01", path: "/bibliotheques/questions", scenario: duo },
  { name: "08b-tests-c02", path: "/bibliotheques/tests", scenario: duo },
  { name: "08c-huis-clos-desactive", path: "/bibliotheques/a-huis-clos", scenario: duo },
  { name: "08d-huis-clos-active", path: "/bibliotheques/a-huis-clos", scenario: { ...duo, intimate: true } },
  { name: "09-fiche", path: "/bibliotheques/ND-Q-P01", scenario: duo },
  { name: "09c-fiche-test", path: "/bibliotheques/ND-Q-012", scenario: duo },
  { name: "09b-fiche-bientot", path: "/bibliotheques/N2-076", scenario: duo },
  { name: "11-salon", path: `/partie/${SESSION}`, scenario: { ...duo, state: sessionState("lobby") } },
  { name: "12-mon-portrait", path: `/partie/${SESSION}`, scenario: { ...duo, state: sessionState("playing") } },
  { name: "18-attente", path: `/partie/${SESSION}`, scenario: { ...duo, state: sessionState("playing", [
    { step: "self", seat: 1, skipped: false, payload: pick(["curieux", "calme", "fiable", "gourmand", "creatif"]) },
    { step: "guess", seat: 1, skipped: false, payload: pick(["calme", "drole", "fiable", "sportif", "patient"]) }]) } },
  { name: "19-revelation", path: `/partie/${SESSION}`, scenario: { ...duo, state: sessionState("ended", [
    { step: "self", seat: 1, skipped: false, payload: pick(["curieux", "calme", "fiable", "gourmand", "creatif"]) },
    { step: "guess", seat: 1, skipped: false, payload: pick(["calme", "drole", "fiable", "sportif", "patient"]) },
    { step: "self", seat: 2, skipped: false, payload: pick(["calme", "fiable", "drole", "patient", "gourmand"]) },
    { step: "guess", seat: 2, skipped: false, payload: pick(["curieux", "calme", "reveur", "creatif", "sociable"]) }], true) } },
  { name: "20-pause-reprise", path: `/partie/${SESSION}`, scenario: { ...duo, state: (() => { const st = sessionState("playing");
    return { ...st, session: { ...st.session, status: "paused", paused_by: ME, pause_state: { paused_at: "2026-10-24T10:00:00Z", by: ME, resume: [st.my_seat ?? 1] } } }; })() } },
  { name: "21a-espace-duo", path: "/espace", scenario: duo },
  { name: "21e-coffre", path: "/espace/coffre", scenario: duo },
  { name: "21f-coffre-notes", path: "/espace/coffre?tab=notes", scenario: duo },
  { name: "21g-historique", path: "/espace/historique", scenario: duo },
  { name: "21b-espace-archive", path: `/espace?duo=${OLD_DUO}`, scenario: { ...duo, duos: [archivedDuo] } },
  { name: "21c-espace-sans-duo", path: "/espace", scenario: solo },
  { name: "22-parametres", path: "/reglages", scenario: duo },
  { name: "22d-rappels", path: "/reglages", scenario: { ...duo, reminders: true } },
  { name: "07c-filtres", path: "/bibliotheques", scenario: duo, action: async (page) => {
    await page.getByRole("button", { name: /Afficher les filtres/ }).click();
    await page.getByRole("button", { name: "Discussion · plus long" }).click();
  } },
  { name: "32-fermer-partie-ouverte", path: "/bibliotheques/ND-Q-P01", scenario: { ...duo, open: { id: SESSION, game_id: "N2-076", status: "lobby", title: "Morpion" } },
    action: async (page) => page.getByRole("button", { name: "Fermer l'autre partie et lancer" }).click() },
  { name: "06f-accueil-deux-duos", path: "/accueil", scenario: { ...duo, duos: [{ ...activeDuo, current: true }, secondDuo, archivedDuo] } },
  { name: "06g-changer-de-duo", path: "/accueil", scenario: { ...duo, duos: [{ ...activeDuo, current: true }, secondDuo, archivedDuo] },
    action: async (page) => page.getByRole("button", { name: /Changer de duo/ }).click() },
  { name: "21d-espace-autre-duo", path: `/espace?duo=${"00000000-0000-4000-a000-00000000d002"}`, scenario: { ...duo, duos: [{ ...activeDuo, current: true }, secondDuo, archivedDuo] } },
  { name: "22b-profil", path: "/reglages/profil", scenario: duo },
  { name: "25-conseils", path: "/conseils", scenario: duo },
  { name: "30-chat", path: "/accueil", scenario: duo, action: async (page) => page.getByRole("button", { name: /Ouvrir la discussion/ }).last().click() },
  { name: "31-notifications", path: "/accueil", scenario: duo, action: async (page) => page.getByRole("button", { name: /Notifications/ }).click() },
];
// Famille 1 : salon (avec options), écran de jeu et révélation, à partir d'états réels.
for (const gid of playable) {
  const st = (kind) => ({ ...duo, state: fixture(`${gid}-${kind}.json`) });
  allScreens.push({ name: `50-${gid}-jeu`, path: `/partie/${SESSION}`, scenario: st("play") });
  allScreens.push({ name: `51-${gid}-revelation`, path: `/partie/${SESSION}`, scenario: st("reveal") });
}
// Familles 2 à 4 (plateau) : début de manche, après un coup, manche finie, partie finie.
for (const gid of [...Object.keys(fixture("index_board.json")), ...Object.keys(fixture("index_board3.json")), ...Object.keys(fixture("index_board4.json"))]) {
  for (const [k, label] of [["b0", "debut"], ["b1", "coup"], ["b2", "manche-finie"], ["b3", "fin"]]) {
    allScreens.push({ name: `53-${gid}-${label}`, path: `/partie/${SESSION}`, scenario: { ...duo, state: fixture(`${gid}-${k}.json`) } });
  }
}
// Export d'une création en image : un vrai fichier PNG doit être proposé au téléchargement.
allScreens.push({ name: "54-N2-128-export-png", path: `/partie/${SESSION}`, scenario: { ...duo, state: fixture("N2-128-b3.json") },
  action: async (page) => {
    const [dl] = await Promise.all([page.waitForEvent("download", { timeout: 8000 }), page.getByRole("button", { name: "Enregistrer en image" }).first().click()]);
    const name = dl.suggestedFilename();
    if (!name.endsWith(".png")) throw new Error(`export inattendu : ${name}`);
    console.log(`export PNG : ${name}`);
  } });
allScreens.push({ name: "52-N2-001-salon-options", path: `/partie/${SESSION}`, scenario: { ...duo, state: fixture("N2-001-lobby.json") },
  action: async (page) => page.getByRole("button", { name: /options/i }).first().click() });
// Catégories 1 et 2 : packs de questions et questionnaires (tests/visual/make_fixtures_c14.py).
// Échéances relatives ({ __rel: secondes }) recalées sur l'heure du rendu.
const rebase = (o) => (Array.isArray(o) ? o.map(rebase) : o && typeof o === "object"
  ? ("__rel" in o ? new Date(Date.now() + o.__rel * 1000).toISOString() : Object.fromEntries(Object.entries(o).map(([k, v]) => [k, rebase(v)]))) : o);
for (const key of Object.keys(fixture("index_c14.json"))) {
  allScreens.push({ name: `60-${key}`, path: `/partie/${SESSION}`, scenario: { ...duo, intimate: key === "salon-huis-clos" || key === "conv-salon", state: fixture(`c14-${key}.json`) } });
}
// Refonte rouge : salon à révision, G01 oral, G08 tour par tour (tests/visual/make_fixtures_rouge.py).
for (const key of Object.keys(fixture("index_rouge.json"))) {
  allScreens.push({ name: `80-rouge-${key}`, path: `/partie/${SESSION}`, scenario: { ...duo, state: fixture(`rouge-${key}.json`) } });
}
export { setup, duo, sessionState, SESSION, ME, PARTNER, activeDuo };
if (!process.env.NOODEU_FIXTURES_ONLY) {
const ONLY = process.env.ONLY;
const screens = process.env.SCREENS ? allScreens.filter(s => new RegExp(process.env.SCREENS).test(s.name)) : ONLY ? allScreens.filter((s) => s.name.includes(ONLY)) : allScreens;
const sizes = (process.env.WIDTHS ?? "320,360,390,430,768,1440").split(",").map((w) => ({ width: Number(w), height: Number(process.env.HEIGHT ?? (Number(w) >= 768 ? 900 : 780)) }));
if (!process.env.WIDTHS) sizes.push({ width: 390, height: 560, label: "basse" });
const zoom = Number(process.env.ZOOM ?? 1);

const browser = await chromium.launch(process.env.PW_CHROMIUM ? { executablePath: process.env.PW_CHROMIUM } : {});
let problems = 0;
for (const size of sizes) {
  for (const s of screens) {
    const ctx = await browser.newContext({ viewport: { width: size.width, height: size.height }, deviceScaleFactor: 1, locale: "fr-FR", serviceWorkers: "block" });
    const page = await ctx.newPage();
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    // Chaque capture commence avec la même durée restante, même après une longue matrice.
    await setup(page, rebase(s.scenario));
    await page.goto(BASE + s.path, { waitUntil: "networkidle" });
    await page.locator("#root > *").first().waitFor();
    if (zoom !== 1) await page.addStyleTag({ content: `html { font-size: ${zoom * 100}%; }` });
    if (s.action) { await s.action(page); }
    await page.waitForTimeout(Number(process.env.WAIT ?? 350));
    await page.screenshot({ path: `${OUT}/${size.width}x${size.height}${zoom !== 1 ? `-z${zoom}` : ""}-${s.name}.png`, fullPage: process.env.FULL === "1" });
    const report = await page.evaluate(() => {
      const overflow = document.documentElement.scrollWidth - window.innerWidth;
      const culprits = overflow > 0 ? [...document.querySelectorAll("body *")].filter((el) => el.getBoundingClientRect().right > window.innerWidth + 0.5).slice(0, 4).map((el) => `${el.tagName}.${el.className}`) : [];
      const small = [...document.querySelectorAll("button, a, [role=switch], select")].filter((el) => {
        const r = el.getBoundingClientRect();
        // Un contrôle placé dans une étiquette entièrement cliquable hérite de sa zone tactile.
        const zone = el.closest("label") ?? el;
        const z = zone.getBoundingClientRect();
        return r.width > 0 && r.height > 0 && (z.height < 44 || z.width < 44) && !el.closest(".game-card__main, [inert]");
      }).map((el) => (el.getAttribute("aria-label") || el.textContent || el.tagName).trim().slice(0, 24));
      // Contenu caché sous la navigation : le dernier élément de la page doit rester atteignable.
      const nav = document.querySelector(".nav");
      const page = document.querySelector("main");
      let hidden = false;
      if (nav && page && !document.querySelector(".sheet")) {
        if (page.scrollHeight > page.clientHeight && getComputedStyle(page).overflowY === "auto") page.scrollTop = page.scrollHeight;
        else window.scrollTo(0, document.documentElement.scrollHeight);
        const last = page.lastElementChild?.getBoundingClientRect();
        hidden = Boolean(last && last.bottom > nav.getBoundingClientRect().top + 1);
      }
      const navLabels = [...document.querySelectorAll(".nav a")].map((a) => a.innerText.replace(/\s+/g, " ").trim());
      return { overflow, culprits, small, hidden, navLabels };
    });
    if (await page.locator(".skeleton, .page-loading").count()) errors.push("écran encore en chargement : fixture ou chargement invalide");
    // L'écran d'erreur du routeur intercepte les exceptions : on le détecte explicitement.
    if (await page.getByText("Unexpected Application Error").count()) errors.push(await page.locator("h3, pre").first().innerText().catch(() => "erreur de rendu"));
    const bad = report.overflow > 0 || errors.length || report.hidden || (process.env.STRICT_TARGETS === "1" && report.small.length > 0);
    if (bad) problems++;
    console.log(`${size.width}x${size.height}${zoom !== 1 ? ` texte×${zoom}` : ""} ${s.name}: débordement=${report.overflow}px masqué-sous-nav=${report.hidden} erreurs=${errors.length}`
      + (errors.length ? ` [${errors.join(" | ")}]` : "") + (report.culprits.length ? ` dépassent=${report.culprits.join(",")}` : "")
      + (report.small.length ? ` petites-cibles=${JSON.stringify(report.small)}` : "") + (s.name === "07-bibliotheques" && report.navLabels.length ? ` nav=${JSON.stringify(report.navLabels)}` : ""));
    await ctx.close();
  }
}
await browser.close();
console.log(problems ? `${problems} écran(s) à corriger` : "Aucun débordement, contenu masqué ni erreur JavaScript.");
if (problems) process.exitCode = 1;

}
