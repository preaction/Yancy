import { defineConfig } from "vitest/config";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { svelteTesting } from "@testing-library/svelte/vite";
import tailwindcss from "@tailwindcss/vite";

// https://vite.dev/config/
export default defineConfig({
  plugins: [tailwindcss(), svelte(), svelteTesting()],
  clearScreen: false,
  appType: "custom",
  define: {
    process: {
      env: {
        NODE_ENV: process.env.NODE_ENV,
      },
    },
  },
  build: {
    sourcemap: true,
    lib: {
      name: "Yancy",
      entry: {
        editor: "lib/Yancy/Editor/src/index.ts",
        iframe: "lib/Yancy/Editor/src/iframe.ts",
      },
      fileName: (format, entryName) => `${entryName}.${format}.js`,
    },
    // Put the library with the rest of the editor
    // XXX: I don't like this, but I can't think of any other modular way of doing it...
    outDir: "lib/Yancy/Editor/dist/editor",
    emptyOutDir: true,
    copyPublicDir: false,
    cssCodeSplit: true,
  },
  test: {
    include: ["t/**/*.spec.ts"],
    environment: "jsdom",
    setupFiles: ["./vitest-setup.ts"],
  },
});
