import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";
import pkg from "./package.json" with { type: "json" };

export default defineConfig({
  define: { __APP_VERSION__: JSON.stringify(pkg.version) },
  plugins: [
    react(),
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
        background_color: "#FFF8F0",
        theme_color: "#FFF8F0",
        icons: [
          { src: "/assets/noodeu/01_Logos/noodeu-app-icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
          { src: "/assets/noodeu/01_Logos/noodeu-app-icon-512.png", sizes: "512x512", type: "image/png", purpose: "any maskable" },
        ],
      },
      workbox: {
        // Seule l'interface est mise en cache. Aucune réponse de l'API Supabase (données de couple,
        // réponses de jeu, messages) n'est stockée hors connexion.
        globPatterns: ["**/*.{js,css,html,woff2,svg}", "assets/noodeu/02_Illustrations_WEBP/noodeu-16-reconnexion.webp"],
        navigateFallback: "/index.html",
        navigateFallbackDenylist: [/^\/auth\//],
        runtimeCaching: [
          {
            urlPattern: ({ url }) => url.pathname.startsWith("/assets/noodeu/"),
            handler: "CacheFirst",
            options: { cacheName: "noodeu-visuels", expiration: { maxEntries: 120 } },
          },
        ],
      },
    }),
  ],
  server: { host: true, port: 5173 },
});
