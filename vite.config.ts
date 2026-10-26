import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";
import pkg from "./package.json" with { type: "json" };

const releaseEnv = loadEnv("production", ".", "VERCEL_GIT_");
const supabaseUrl = loadEnv("production", ".", "VITE_SUPABASE_URL").VITE_SUPABASE_URL;

export default defineConfig({
  define: { __APP_VERSION__: JSON.stringify(pkg.version) },
  plugins: [
    react(),
    { name: "noodeu-release",
      // Connexion à Supabase ouverte dès le HTML (DNS + TLS), en parallèle du chargement du code. L'URL est publique.
      transformIndexHtml() {
        return supabaseUrl ? [{ tag: "link", attrs: { rel: "preconnect", href: new URL(supabaseUrl).origin, crossorigin: "" }, injectTo: "head" }] : [];
      },
      generateBundle() {
      this.emitFile({ type: "asset", fileName: "assets/noodeu-release.json", source: JSON.stringify({
        commit: releaseEnv.VERCEL_GIT_COMMIT_SHA ?? "local", branch: releaseEnv.VERCEL_GIT_COMMIT_REF ?? "local", audioEnabled: false, databaseMigrationsAppliedByBuild: false,
      }) });
    } },
    VitePWA({
      registerType: "prompt",
      includeAssets: ["assets/noodeu/01_Logos/noodeu-favicon.svg", "assets/noodeu/01_Logos/noodeu-app-icon-180.png"],
      manifest: {
        name: "Noodeu",
        short_name: "Noodeu",
        description: "Jouer à deux, même à distance.",
        lang: "fr",
        start_url: "/accueil",
        scope: "/",
        display: "standalone",
        orientation: "portrait",
        background_color: "#F7F1F1",
        theme_color: "#F7F1F1",
        icons: [
          { src: "/assets/noodeu/01_Logos/noodeu-app-icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
          { src: "/assets/noodeu/01_Logos/noodeu-app-icon-512.png", sizes: "512x512", type: "image/png", purpose: "any maskable" },
        ],
      },
      workbox: {
        // Seule l'interface est mise en cache. Aucune réponse de l'API Supabase (données de couple,
        // réponses de jeu, messages) n'est stockée hors connexion.
        globPatterns: ["**/*.{js,css,html,woff2,svg}", "assets/noodeu/02_Illustrations_WEBP/noodeu-16-reconnexion.webp"],
        // Polices cyrillique et vietnamienne : jamais utilisées en français, non préchargées (servies si besoin).
        // Les ~400 images des activités ne sont pas préchargées : elles se mettent en cache à l'usage.
        globIgnores: ["assets/jeux/**", "assets/noodeu/red-v1/**", "assets/*-{cyrillic,cyrillic-ext,vietnamese}-*.woff2"],
        navigateFallback: "/index.html",
        navigateFallbackDenylist: [/^\/auth\//],
        runtimeCaching: [
          {
            urlPattern: ({ url }) => url.pathname.startsWith("/assets/noodeu/") || url.pathname.startsWith("/assets/jeux/"),
            handler: "CacheFirst",
            options: { cacheName: "noodeu-visuels", expiration: { maxEntries: 500 } },
          },
        ],
      },
    }),
  ],
  build: {
    rolldownOptions: {
      output: {
        // Bibliothèques stables dans leurs propres fichiers : un déploiement ne fait retélécharger que le code de l'application.
        codeSplitting: {
          groups: [
            { name: "react", test: /node_modules[\\/](react|react-dom|react-router|scheduler)[\\/]/ },
            { name: "supabase", test: /node_modules[\\/]@supabase[\\/]/ },
          ],
        },
      },
    },
  },
  server: { host: true, port: 5173 },
});
