import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  // Relative base so the same build serves from any path (a preview URL or a site root).
  base: "./",
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      manifest: {
        name: "mathmath",
        short_name: "mathmath",
        display: "standalone",
        start_url: ".",
        background_color: "#ffffff",
        theme_color: "#ffffff",
        icons: [],
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,json,woff2,svg,png}"],
      },
    }),
  ],
  server: { fs: { allow: ["../.."] } },
});
