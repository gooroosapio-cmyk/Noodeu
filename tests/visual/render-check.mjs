// Vérification VISUELLE du rendu sur petits écrans (320/390/430 px).
// ⚠️ Les réponses Supabase sont simulées ici UNIQUEMENT pour afficher les écrans connectés :
// ce script ne teste ni la synchronisation ni la sécurité (voir supabase/tests pour cela).
// Usage : npx vite preview --port 4173 & node tests/visual/render-check.mjs [dossier-sortie]
import { chromium } from "@playwright/test";
import { mkdirSync } from "node:fs";

const BASE = "http://localhost:4173";
const OUT = process.argv[2] ?? "test-results/visual";
mkdirSync(OUT, { recursive: true });
const REF = "uqyrjdaonqqkkpzyjfcg";
const ME = "11111111-1111-4111-8111-111111111111";
const PARTNER = "22222222-2222-4222-8222-222222222222";
const SESSION = "33333333-3333-4333-8333-333333333333";

const words = ["curieux:Curieuse:Curieux", "calme:Calme:Calme", "fiable:Fiable:Fiable", "gourmand:Gourmande:Gourmand", "spontane:Spontanée:Spontané", "reveur:Rêveuse:Rêveur", "creatif:Créative:Créatif", "patient:Patiente:Patient", "sportif:Sportive:Sportif", "sociable:Sociable:Sociable", "drole:Drôle:Drôle", "perfectionniste:Perfectionniste:Perfectionniste"]
  .map((w) => { const [id, f, m] = w.split(":"); return { id: `portrait.${id}`, f, m }; });
const rules = {
  objective: "Te décrire en cinq mots…", how_to: ["Choisis cinq mots pour te décrire.", "Imagine les cinq mots que ton ou ta partenaire a choisis.", "Découvrez vos portraits ensemble."],
  details: ["Vous voyez tous les deux la même grille de mots."], privacy: "Vos réponses restent privées avant la révélation.",
  step_texts: { self: { title: "Mon portrait", prompt: "Quels mots te ressemblent ?", hint: "Choisis 5 mots pour te décrire.", confirm: "Confirmer mes mots" },
    guess: { title: "Son portrait", prompt: "Et {partner}, en cinq mots ?", hint: "Imagine les mots que {partner} a choisis.", confirm: "Confirmer mon portrait" } },
};
const config = { mechanic: "portrait_words", rounds: 1, pick: 5, steps: [{ key: "self", kind: "pick_words", about: "self" }, { key: "guess", kind: "pick_words", about: "partner" }], settings: { deck_size: { label: "Mots proposés", options: [12, 16], default: 12 } } };
const game = { id: "portrait-en-cinq-mots", category_id: "se-decouvrir", mechanic: "portrait_words", title: "Portrait en cinq mots", promise: "Se découvrir autrement, en quelques mots.", style: "echange", duration_min: 4, duration_max: 6, content_level: "standard", current_version: 1, sort: 1, is_demo: true };
const players = [
  { seat: 1, user_id: ME, is_me: true, display_name: "Maya", word_form: "f", ready: true, keep_memory: false },
  { seat: 2, user_id: PARTNER, is_me: false, display_name: "Alex", word_form: "m", ready: false, keep_memory: false },
];
function sessionState(status, answers = [], revealed = false) {
  return { ok: true, my_seat: 1, players, game: { title: game.title, mechanic: "portrait_words", rules, config },
    session: { id: SESSION, game_id: game.id, status, settings: { deck_size: 12 }, current_round: status === "lobby" ? 0 : 1, total_rounds: 1, paused_by: null, state_version: 5, read_only: false, created_at: new Date().toISOString(), ended_at: null },
    rounds: status === "lobby" ? [] : [{ round_no: 1, card: { words }, revealed, answers }] };
}
const pick = (ids) => ({ words: ids.map((i) => `portrait.${i}`) });

async function setup(page, scenario) {
  const exp = Math.floor(Date.now() / 1000) + 3600;
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const jwt = `${b64({ alg: "HS256", typ: "JWT" })}.${b64({ sub: ME, role: "authenticated", exp })}.sig`;
  await page.addInitScript(([key, val]) => localStorage.setItem(key, val), [`sb-${REF}-auth-token`, JSON.stringify({ access_token: jwt, refresh_token: "r", token_type: "bearer", expires_in: 3600, expires_at: exp, user: { id: ME, email: "maya@exemple.fr", aud: "authenticated", role: "authenticated" } })]);
  await page.route(`https://${REF}.supabase.co/**`, async (route) => {
    const url = new URL(route.request().url());
    const p = url.pathname;
    const json = (body) => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(body) });
    // supabase-js (maybeSingle) attend un tableau de lignes.
    if (p.endsWith("/profiles")) return json([{ id: ME, display_name: url.searchParams.get("id")?.includes(PARTNER) ? "Alex" : "Maya", word_form: "f", intimate_opt_in: false, reduced_motion: false }]);
    if (p.endsWith("/couple_members")) {
      if (!scenario.couple) return json([]);
      return json(url.searchParams.get("user_id")?.startsWith("neq") ? [{ user_id: PARTNER, display_name_snapshot: "Alex" }] : [{ couple_id: "c1", joined_at: "2026-10-01T10:00:00Z", couples: { status: "active" } }]);
    }
    if (p.endsWith("/rpc/get_open_session")) return json(scenario.open ?? null);
    if (p.endsWith("/rpc/get_invitation_status")) return json(scenario.invitations ?? { outgoing: null, incoming: null });
    if (p.endsWith("/rpc/get_session_state")) return json(scenario.state);
    if (p.endsWith("/game_categories")) return json([{ id: "se-decouvrir", title: "Se découvrir", promise: "Même après des années, il reste des surprises.", sort: 1, is_demo: true }]);
    if (p.endsWith("/games")) return json([game]);
    if (p.endsWith("/game_versions")) return json([{ rules }]);
    if (p.endsWith("/game_favorites")) return json([]);
    if (p.endsWith("/game_sessions")) return json([]);
    if (p.endsWith("/session_messages")) return json([]);
    return json({});
  });
}

const ONLY = process.env.ONLY;
const allScreens = [
  { name: "01-bienvenue", path: "/", auth: false },
  { name: "02-inscription", path: "/inscription", auth: false },
  { name: "06-accueil-sans-duo", path: "/accueil", scenario: { couple: false } },
  { name: "06b-accueil-demande", path: "/accueil", scenario: { couple: false, invitations: { outgoing: { id: "i", code: "K7PM-Q2RX", status: "claimed", expires_at: "2026-10-22T10:00:00Z", expired: false, claimer_name: "Alex" }, incoming: null } } },
  { name: "04-inviter", path: "/inviter", scenario: { couple: false, invitations: { outgoing: { id: "i", code: "K7PM-Q2RX", status: "open", expires_at: "2026-10-22T10:00:00Z", expired: false, claimer_name: null }, incoming: null } } },
  { name: "06c-accueil-duo", path: "/accueil", scenario: { couple: true, open: { id: SESSION, game_id: game.id, status: "playing", title: game.title } } },
  { name: "07-bibliotheques", path: "/bibliotheques", scenario: { couple: true } },
  { name: "09-fiche", path: "/bibliotheques/portrait-en-cinq-mots", scenario: { couple: true } },
  { name: "11-salon-attente", path: `/partie/${SESSION}`, scenario: { couple: true, state: sessionState("lobby") } },
  { name: "12-mon-portrait", path: `/partie/${SESSION}`, scenario: { couple: true, state: sessionState("playing") } },
  { name: "18-attente", path: `/partie/${SESSION}`, scenario: { couple: true, state: sessionState("playing", [
    { step: "self", seat: 1, skipped: false, payload: pick(["curieux", "calme", "fiable", "gourmand", "creatif"]) },
    { step: "guess", seat: 1, skipped: false, payload: pick(["calme", "drole", "fiable", "sportif", "patient"]) },
    { step: "self", seat: 2, skipped: false, payload: null }]) } },
  { name: "19-revelation", path: `/partie/${SESSION}`, scenario: { couple: true, state: sessionState("ended", [
    { step: "self", seat: 1, skipped: false, payload: pick(["curieux", "calme", "fiable", "gourmand", "creatif"]) },
    { step: "guess", seat: 1, skipped: false, payload: pick(["calme", "drole", "fiable", "sportif", "patient"]) },
    { step: "self", seat: 2, skipped: false, payload: pick(["calme", "fiable", "drole", "patient", "gourmand"]) },
    { step: "guess", seat: 2, skipped: false, payload: pick(["curieux", "calme", "reveur", "creatif", "sociable"]) }], true) } },
  { name: "21-notre-espace", path: "/notre-espace", scenario: { couple: true } },
  { name: "22-parametres", path: "/parametres", scenario: { couple: true } },
  { name: "25-astuces", path: "/astuces", scenario: { couple: true } },
];
const screens = ONLY ? allScreens.filter((s) => s.name.includes(ONLY)) : allScreens;

const browser = await chromium.launch(process.env.PW_CHROMIUM ? { executablePath: process.env.PW_CHROMIUM } : {});
let problems = 0;
for (const width of (process.env.WIDTHS ?? "320,390,430").split(",").map(Number)) {
  for (const s of screens) {
    const ctx = await browser.newContext({ viewport: { width, height: 800 }, deviceScaleFactor: 1, locale: "fr-FR", serviceWorkers: "block" });
    const page = await ctx.newPage();
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    if (process.env.DEBUG) {
      page.on("request", (r) => r.url().includes("supabase") && console.log("  →", r.method(), r.url().slice(0, 120), r.headers()["accept"]));
      page.on("console", (m) => console.log("  console:", m.text()));
    }
    if (s.auth !== false) await setup(page, s.scenario ?? {});
    await page.goto(BASE + s.path, { waitUntil: "networkidle" });
    await page.waitForTimeout(400);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    const tooSmall = await page.evaluate(() => [...document.querySelectorAll("button, a, input, [role=switch]")]
      .filter((el) => { const r = el.getBoundingClientRect(); return r.width > 0 && r.height > 0 && (r.height < 40 || r.width < 40) && getComputedStyle(el).position !== "absolute"; })
      .map((el) => (el.textContent || el.getAttribute("aria-label") || el.tagName).trim().slice(0, 30)));
    const navItems = await page.locator("nav.nav a").count();
    if (overflow > 0) {
      const culprits = await page.evaluate(() => [...document.querySelectorAll("body *")]
        .filter((el) => el.getBoundingClientRect().right > window.innerWidth + 0.5)
        .slice(0, 5).map((el) => `${el.tagName}.${el.className}`));
      console.log("  éléments qui dépassent :", culprits.join(", "));
    }
    if (overflow > 0 || errors.length) problems++;
    console.log(`${width}px ${s.name}: débordement=${overflow}px nav=${navItems} erreurs=${errors.length}${errors.length ? " " + errors.join(" | ") : ""}${tooSmall.length ? " petites-cibles=" + JSON.stringify(tooSmall) : ""}`);
    await page.screenshot({ path: `${OUT}/${width}-${s.name}.png`, fullPage: true });
    await ctx.close();
  }
}
await browser.close();
console.log(problems ? `${problems} écran(s) à corriger` : "Aucun débordement horizontal ni erreur JavaScript.");
