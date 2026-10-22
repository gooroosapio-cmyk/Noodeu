// Vérification VISUELLE du rendu (320 → 1440 px, faible hauteur, texte agrandi).
// ⚠️ Les réponses Supabase sont simulées ici UNIQUEMENT pour afficher les écrans connectés :
// ce script ne teste ni la synchronisation ni la sécurité (voir supabase/tests pour cela).
// Usage : npm run build && npx vite preview --port 4173 &  puis  node tests/visual/render-check.mjs [dossier]
// Variables : ONLY=<motif d'écran>, WIDTHS=320,390, ZOOM=2 (texte à 200 %), PW_CHROMIUM=<chemin du navigateur>
import { chromium } from "@playwright/test";
import { mkdirSync, readFileSync } from "node:fs";

// États réels produits par la base locale (tests/visual/make_fixtures.py) : catalogue 2.1.0 et parties de la famille 1.
const FIX = new URL("./fixtures/", import.meta.url);
const fixture = (name) => JSON.parse(readFileSync(new URL(name, FIX), "utf8"));
const catalogue = fixture("catalogue.json");
const playable = Object.keys(fixture("index.json"));

const BASE = "http://localhost:4173";
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
const archivedDuo = { id: OLD_DUO, active: false, created_at: "2026-08-01T10:00:00Z", separated_at: "2026-09-20T10:00:00Z", partner: { id: "x", name: "Sam", avatar_path: null, deleted: false }, episodes: [{ started_at: "2026-08-01T10:00:00Z", ended_at: "2026-09-20T10:00:00Z" }] };
function sessionState(status, answers = [], revealed = false) {
  return { ok: true, my_seat: 1, players, game: { title: game.title, mechanic: "portrait_words", rules, config },
    session: { id: SESSION, game_id: game.id, status, settings: { deck_size: 12 }, current_round: status === "lobby" ? 0 : 1, total_rounds: 1, paused_by: null, state_version: 5, read_only: false, created_at: new Date().toISOString(), ended_at: null },
    rounds: status === "lobby" ? [] : [{ round_no: 1, card: { words }, revealed, answers }] };
}
const pick = (ids) => ({ words: ids.map((i) => `portrait.${i}`) });
const notifications = [
  { id: "n1", type: "game_proposed", couple_id: DUO, data: { name: "Alex", title: game.title, session_id: SESSION }, created_at: new Date(Date.now() - 600000).toISOString(), read_at: null },
  { id: "n2", type: "invitation_accepted", couple_id: DUO, data: { name: "Alex" }, created_at: "2026-10-01T10:00:00Z", read_at: "2026-10-01T11:00:00Z" },
];
const messages = [
  { id: "m1", user_id: PARTNER, client_id: "c1", body: "Prête pour une partie ce soir ?", created_at: "2026-10-21T18:00:00Z" },
  { id: "m2", user_id: ME, client_id: "c2", body: "Oui ! Je lance Portrait en cinq mots.", created_at: "2026-10-21T18:02:00Z" },
];

async function setup(page, scenario) {
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
    if (p.endsWith("/profiles")) return json([{ id: ME, display_name: "Maya", word_form: "f", intimate_opt_in: false, reduced_motion: false, avatar_path: null }]);
    if (p.endsWith("/rpc/get_my_duos")) return json(scenario.duos ?? []);
    if (p.endsWith("/rpc/get_open_session")) return json(scenario.open ?? null);
    if (p.endsWith("/rpc/get_invitation_status")) return json(scenario.invitations ?? { outgoing: null, incoming: null });
    if (p.endsWith("/rpc/get_session_state")) return json(scenario.state);
    if (p.endsWith("/rpc/get_chat_unread")) return json(scenario.unread ?? 0);
    if (p.endsWith("/notifications")) return json(scenario.notifications ?? []);
    if (p.endsWith("/duo_messages")) return json(scenario.duos?.length ? messages : []);
    if (p.endsWith("/game_categories")) return json(catalogue.categories);
    if (p.endsWith("/games")) return json(catalogue.games);
    if (p.endsWith("/game_versions")) {
      const id = (url.searchParams.get("game_id") ?? "").replace(/^eq\./, "");
      return json(catalogue.rules[id] ? [{ rules: catalogue.rules[id] }] : [{ rules }]);
    }
    if (p.endsWith("/game_favorites")) return json([{ game_id: "N2-005" }, { game_id: "N2-061" }]);
    if (p.endsWith("/game_sessions")) return json(scenario.history ?? []);
    return json({});
  });
}

const solo = { duos: [] };
const duo = { duos: [activeDuo, archivedDuo], unread: 2, notifications, history: [{ id: SESSION, status: "closed", created_at: "2026-10-20T20:00:00Z", ended_at: "2026-10-20T20:10:00Z", games: { title: game.title }, session_players: [{ keep_memory: true }, { keep_memory: true }] }] };
const allScreens = [
  { name: "01-bienvenue", path: "/", scenario: { auth: false } },
  { name: "02-inscription", path: "/inscription", scenario: { auth: false } },
  { name: "06a-accueil-sans-duo", path: "/accueil", scenario: solo },
  { name: "06b-accueil-invitation", path: "/accueil", scenario: { ...solo, invitations: { outgoing: { id: "i", code: "K7PM-Q2RX", status: "open", expires_at: "2026-10-22T10:00:00Z", expired: false, claimer_name: null }, incoming: null } } },
  { name: "06c-accueil-demande", path: "/accueil", scenario: { ...solo, invitations: { outgoing: { id: "i", code: "K7PM-Q2RX", status: "claimed", expires_at: "2026-10-22T10:00:00Z", expired: false, claimer_name: "Alex" }, incoming: null } } },
  { name: "06d-accueil-duo", path: "/accueil", scenario: { ...duo, open: { id: SESSION, game_id: game.id, status: "playing", title: game.title } } },
  { name: "06e-accueil-duo-libre", path: "/accueil", scenario: duo },
  { name: "04-inviter", path: "/inviter", scenario: { ...solo, invitations: { outgoing: { id: "i", code: "K7PM-Q2RX", status: "open", expires_at: "2026-10-22T10:00:00Z", expired: false, claimer_name: null }, incoming: null } } },
  { name: "04b-rejoindre", path: "/rejoindre", scenario: solo },
  { name: "07-bibliotheques", path: "/bibliotheques", scenario: duo },
  { name: "07b-filtres", path: "/bibliotheques", scenario: duo, action: async (page) => page.getByRole("button", { name: /^Filtres/ }).click() },
  { name: "09-fiche", path: "/bibliotheques/N2-001", scenario: duo },
  { name: "09b-fiche-bientot", path: "/bibliotheques/N2-061", scenario: duo },
  { name: "07c-biblio-duel", path: "/bibliotheques", scenario: duo, action: async (page) => page.getByRole("button", { name: "Duel", exact: true }).click() },
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
  { name: "21a-espace-duo", path: "/espace", scenario: duo },
  { name: "21b-espace-archive", path: `/espace?duo=${OLD_DUO}`, scenario: { ...duo, duos: [archivedDuo] } },
  { name: "21c-espace-sans-duo", path: "/espace", scenario: solo },
  { name: "22-parametres", path: "/reglages", scenario: duo },
  { name: "22b-profil", path: "/reglages/profil", scenario: duo },
  { name: "25-astuces", path: "/astuces", scenario: duo },
  { name: "30-chat", path: "/accueil", scenario: duo, action: async (page) => page.getByRole("button", { name: /Ouvrir la discussion/ }).last().click() },
  { name: "31-notifications", path: "/accueil", scenario: duo, action: async (page) => page.getByRole("button", { name: /Notifications/ }).click() },
];
// Famille 1 : salon (avec options), écran de jeu et révélation, à partir d'états réels.
for (const gid of playable) {
  const st = (kind) => ({ ...duo, state: fixture(`${gid}-${kind}.json`) });
  allScreens.push({ name: `50-${gid}-jeu`, path: `/partie/${SESSION}`, scenario: st("play") });
  allScreens.push({ name: `51-${gid}-revelation`, path: `/partie/${SESSION}`, scenario: st("reveal") });
}
// Famille 2 (plateau) : début de manche, après un coup, manche finie, partie finie.
for (const gid of Object.keys(fixture("index_board.json"))) {
  for (const [k, label] of [["b0", "debut"], ["b1", "coup"], ["b2", "manche-finie"], ["b3", "fin"]]) {
    allScreens.push({ name: `53-${gid}-${label}`, path: `/partie/${SESSION}`, scenario: { ...duo, state: fixture(`${gid}-${k}.json`) } });
  }
}
allScreens.push({ name: "52-N2-001-salon-options", path: `/partie/${SESSION}`, scenario: { ...duo, state: fixture("N2-001-lobby.json") },
  action: async (page) => page.getByRole("button", { name: "Options" }).first().click() });
const ONLY = process.env.ONLY;
const screens = ONLY ? allScreens.filter((s) => s.name.includes(ONLY)) : allScreens;
const sizes = (process.env.WIDTHS ?? "320,360,390,430,768,1440").split(",").map((w) => ({ width: Number(w), height: Number(w) >= 768 ? 900 : 780 }));
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
    await setup(page, s.scenario);
    await page.goto(BASE + s.path, { waitUntil: "networkidle" });
    if (zoom !== 1) await page.addStyleTag({ content: `html { font-size: ${zoom * 100}%; }` });
    if (s.action) { await s.action(page); }
    await page.waitForTimeout(350);
    await page.screenshot({ path: `${OUT}/${size.width}x${size.height}${zoom !== 1 ? `-z${zoom}` : ""}-${s.name}.png`, fullPage: false });
    const report = await page.evaluate(() => {
      const overflow = document.documentElement.scrollWidth - window.innerWidth;
      const culprits = overflow > 0 ? [...document.querySelectorAll("body *")].filter((el) => el.getBoundingClientRect().right > window.innerWidth + 0.5).slice(0, 4).map((el) => `${el.tagName}.${el.className}`) : [];
      const small = [...document.querySelectorAll("button, a, [role=switch], select")].filter((el) => {
        const r = el.getBoundingClientRect();
        // Un contrôle placé dans une étiquette entièrement cliquable hérite de sa zone tactile.
        const zone = el.closest("label") ?? el;
        const z = zone.getBoundingClientRect();
        return r.width > 0 && r.height > 0 && (z.height < 44 || z.width < 44) && !el.closest(".game-card__main");
      }).map((el) => (el.getAttribute("aria-label") || el.textContent || el.tagName).trim().slice(0, 24));
      // Contenu caché sous la navigation : le dernier élément de la page doit rester atteignable.
      const nav = document.querySelector(".nav");
      const page = document.querySelector("main");
      let hidden = false;
      if (nav && page && !document.querySelector(".sheet")) {
        window.scrollTo(0, document.documentElement.scrollHeight);
        const last = page.lastElementChild?.getBoundingClientRect();
        hidden = Boolean(last && last.bottom > nav.getBoundingClientRect().top + 1);
      }
      const navLabels = [...document.querySelectorAll(".nav a")].map((a) => a.innerText.replace(/\s+/g, " ").trim());
      return { overflow, culprits, small, hidden, navLabels };
    });
    // L'écran d'erreur du routeur intercepte les exceptions : on le détecte explicitement.
    if (await page.getByText("Unexpected Application Error").count()) errors.push(await page.locator("h3, pre").first().innerText().catch(() => "erreur de rendu"));
    const bad = report.overflow > 0 || errors.length || report.hidden;
    if (bad) problems++;
    console.log(`${size.width}x${size.height}${zoom !== 1 ? ` texte×${zoom}` : ""} ${s.name}: débordement=${report.overflow}px masqué-sous-nav=${report.hidden} erreurs=${errors.length}`
      + (errors.length ? ` [${errors.join(" | ")}]` : "") + (report.culprits.length ? ` dépassent=${report.culprits.join(",")}` : "")
      + (report.small.length ? ` petites-cibles=${JSON.stringify(report.small)}` : "") + (s.name === "07-bibliotheques" && report.navLabels.length ? ` nav=${JSON.stringify(report.navLabels)}` : ""));
    await ctx.close();
  }
}
await browser.close();
console.log(problems ? `${problems} écran(s) à corriger` : "Aucun débordement, contenu masqué ni erreur JavaScript.");
