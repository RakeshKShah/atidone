/**
 * Seed test — proves the Nuxt/Atidone app starts, is reachable,
 * and renders expected page content.
 *
 * Helper imports:
 *   ExecutionRecorder  → .codevalid/ui/helpers/execution-recorder.js
 *   mock setup         → .codevalid/ui/mock/mock-server.js
 */
import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../helpers/execution-recorder.js";

test.describe("Atidone – App Reachability (seed test)", () => {
  test("home page loads and displays expected content", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "seed-001",
      testTitle: "home page loads and displays expected content",
    });

    // ── Navigate to the app root ───────────────────────────────────────────────
    recorder.record("navigate", { url: "/" });
    await page.goto("/");

    // ── Page title contains 'Atidone' ─────────────────────────────────────────
    recorder.record("assert page title");
    await expect(page).toHaveTitle(/Atidone/i);

    // ── Main welcome text is visible ──────────────────────────────────────────
    recorder.record("assert welcome text visible");
    const welcomeText = page.getByText("Welcome to Atidone");
    await expect(welcomeText).toBeVisible();

    // ── 'Login with GitHub' button is rendered (unauthenticated state) ────────
    recorder.record("assert login button visible");
    const loginButton = page.getByRole("link", { name: /login with github/i });
    await expect(loginButton).toBeVisible();

    // ── App container / card is present ──────────────────────────────────────
    recorder.record("assert app card present");
    const appCard = page.locator(".min-h-screen");
    await expect(appCard).toBeVisible();

    // ── Save execution record ─────────────────────────────────────────────────
    recorder.record("save execution record");
    await recorder.save(testInfo);
  });

  test("root route responds with HTTP 200", async ({ page }) => {
    const response = await page.goto("/");
    expect(response?.status()).toBe(200);
  });
});
