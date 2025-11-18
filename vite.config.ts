import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import Icons from "unplugin-icons/vite";

// https://vite.dev/config/
export default defineConfig({
  plugins: [svelte(), Icons({ compiler: "svelte" })],
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
});
