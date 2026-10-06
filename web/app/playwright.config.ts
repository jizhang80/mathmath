import { defineConfig, devices } from "@playwright/test";

// D29: the agent gate runs end-to-end under both the WebKit and Chromium engines. WebKit with the
// iPad/iPhone profiles is the closest an agent gets to Safari; physical devices are the owner's.
export default defineConfig({
  testDir: "./e2e",
  forbidOnly: !!process.env["CI"],
  retries: 0,
  reporter: process.env["CI"] ? "github" : "list",
  use: { baseURL: "http://localhost:4173" },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "webkit-ipad", use: { ...devices["iPad (gen 7)"] } },
    { name: "webkit-iphone", use: { ...devices["iPhone 15"] } },
  ],
  webServer: {
    command: "pnpm build && pnpm preview",
    url: "http://localhost:4173",
    reuseExistingServer: !process.env["CI"],
  },
});
