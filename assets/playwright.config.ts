import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  expect: {
    timeout: 5_000,
  },
  fullyParallel: false,
  reporter: "line",
  testDir: "./test/browser",
  use: {
    ...devices["Desktop Chrome"],
    baseURL: "http://localhost:4002",
    launchOptions: {
      executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
    },
    trace: "retain-on-failure",
  },
  webServer: {
    command: "cd .. && mix assets.build && mix phx.server",
    env: {
      MIX_ENV: "test",
      PHX_SERVER: "true",
      PORT: "4002",
    },
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    url: "http://localhost:4002/__test__/lexical-editor",
  },
});
