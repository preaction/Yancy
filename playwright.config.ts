// playwright.config.ts
import type { PlaywrightTestConfig } from "@playwright/test";

const baseURL = process.env.YANCY_EDITOR_URL || "http://localhost:3333";
const config: PlaywrightTestConfig = {
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
};

export default config;
