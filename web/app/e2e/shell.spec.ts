import { expect, test } from "@playwright/test";

test("the shell loads the demo bundle through Core", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "mathmath" })).toBeVisible();
  await expect(page.getByTestId("bundle-status")).toHaveText(/^Demo bundle: \d+ nodes$/);
});

test("the page links a web app manifest (installable)", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator('link[rel="manifest"]')).toHaveCount(1);
});
