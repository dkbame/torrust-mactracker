// https://v3.nuxtjs.org/api/configuration/nuxt.config
import eslintPlugin from "vite-plugin-eslint";

export default defineNuxtConfig({
  ssr: false,

  runtimeConfig: {
    public: {
      apiBase: process.env.API_BASE_URL
    }
  },

  modules: [
    "@nuxtjs/tailwindcss",
    "@nuxtjs/color-mode"
  ],

  build: {
    transpile: ["notiwind-ts"]
  },

  colorMode: {
    preference: "dark", // default value of $colorMode.preference
    fallback: "dark", // fallback value if not system preference found
    hid: "nuxt-color-mode-script",
    globalName: "__NUXT_COLOR_MODE__",
    componentName: "ColorScheme",
    classPrefix: "",
    classSuffix: "",
    storageKey: "nuxt-color-mode",
    dataValue: "theme"
  },

  vite: {
    server: {
      fs: {
        // Allow serving files from one level up to the project root
        allow: [".."]
      }
    },
    plugins: [
      eslintPlugin()
    ]
  },

  devtools: {
    enabled: true
  },

  postcss: {
    plugins: {
      "tailwindcss/nesting": {},
      tailwindcss: {},
      autoprefixer: {}
    }
  }
});
