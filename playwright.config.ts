import { defineConfig } from "@playwright/test";

const baseURL = process.env.YANCY_EDITOR_URL || "http://127.0.0.1:3333";
export default defineConfig({
  webServer: {
    name: "mojo",
    command: `perl -Ilib myapp.pl daemon -l ${baseURL}`,
    reuseExistingServer: true,
    url: baseURL,
    stdout: "pipe",
    stderr: "pipe",
  },
  use: {
    baseURL,
  },
});
