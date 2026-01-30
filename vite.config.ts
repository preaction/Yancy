import { defineConfig } from "vitest/config";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { svelteTesting } from "@testing-library/svelte/vite";
import Icons from "unplugin-icons/vite";

// https://vite.dev/config/
export default defineConfig({
  plugins: [svelte(), Icons({ compiler: "svelte" }), svelteTesting()],
  clearScreen: false,
  appType: "custom",
  build: {
    sourcemap: true,
    lib: {
      name: "Yancy",
      entry: ["lib/Yancy/Editor/src/index.ts"],
    },
    // Put the library with the rest of the editor
    // XXX: I don't like this, but I can't think of any other modular way of doing it...
    outDir: "lib/Yancy/Editor/dist/editor",
    emptyOutDir: false,
    copyPublicDir: false,
  },
  test: {
    include: ["t/**/*.spec.ts"],
    environment: "jsdom",
    setupFiles: ["./vitest-setup.ts"],
  },
});
