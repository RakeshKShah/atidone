/**
 * Mock server for Atidone UI tests.
 *
 * Usage in a test file:
 *   import { setupMocks } from "../mock/mock-server.js";
 *
 *   test.beforeEach(async ({ page }) => {
 *     await setupMocks(page);
 *   });
 *
 * All mock route payloads live here. Test files must not embed payloads —
 * only call setupMocks() (or individual route helpers exported below).
 */

/**
 * Install all standard mock routes on the given Playwright Page via
 * route interception. Call this in a beforeEach hook.
 *
 * @param {import("@playwright/test").Page} page
 */
export async function setupMocks(page) {
  // Mock: GitHub OAuth redirect — return immediately so tests never leave the app
  await page.route("**/api/auth/github", (route) => {
    route.fulfill({
      status: 302,
      headers: { Location: "/" },
      body: "",
    });
  });

  // Mock: Todo list API (empty list for unauthenticated seed state)
  await page.route("**/api/todos*", (route) => {
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify([]),
    });
  });

  // Mock: User session — unauthenticated by default
  await page.route("**/api/_auth/session", (route) => {
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ loggedIn: false, user: null }),
    });
  });
}

/**
 * Set up an authenticated user session mock.
 * Call after setupMocks() to override the session endpoint.
 *
 * @param {import("@playwright/test").Page} page
 * @param {{ login: string }} user
 */
export async function mockAuthenticatedUser(page, user = { login: "testuser" }) {
  await page.route("**/api/_auth/session", (route) => {
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ loggedIn: true, user }),
    });
  });
}

/**
 * Set up a mocked todo list response.
 *
 * @param {import("@playwright/test").Page} page
 * @param {Array<{id: number, title: string, completed: boolean}>} todos
 */
export async function mockTodos(page, todos = []) {
  await page.route("**/api/todos*", (route) => {
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(todos),
    });
  });
}
