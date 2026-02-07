import { defineConfig } from "@playwright/test";

const baseURL = process.env.YANCY_EDITOR_URL || "http://127.0.0.1:3336";
export default defineConfig({
  testDir: "./tests",
  webServer: {
    name: "mojo",
    command: `perl -I../../lib myapp.pl daemon -l ${baseURL}`,
    reuseExistingServer: true,
    url: baseURL,
    stdout: "pipe",
    stderr: "pipe",
  },
  use: {
    baseURL,
  },
});
