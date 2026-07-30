/**
 * Mock server for Atidone UI tests.
 *
 * Usage in a test file:
 *   import { setupMocks, mockAuthenticatedUser, mockTodos } from "../mock/mock-server.js";
 *
 * Authenticated flows must call `mockAuthenticatedUser` (or helpers in
 * `helpers/mock-api.js`) so a real nuxt-auth-utils session cookie is set.
 * Route-only session mocks are not enough for SSR `middleware: 'auth'`.
 */

const TEST_SESSION_URL = "/api/__codevalid__/test-session";

/**
 * Install baseline mocks (OAuth stub + empty todos). Does not force an
 * unauthenticated session cookie — call {@link clearTestSession} when needed.
 *
 * @param {import("@playwright/test").Page} page
 */
export async function setupMocks(page) {
  await page.route("**/api/auth/github", (route) => {
    route.fulfill({
      status: 302,
      headers: { Location: "/" },
      body: "",
    });
  });

  await page.route("**/api/todos*", (route) => {
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify([]),
    });
  });
}

/**
 * Clear any sealed session cookie via the test-only session endpoint.
 * @param {import("@playwright/test").Page} page
 */
export async function clearTestSession(page) {
  const response = await page.request.post(TEST_SESSION_URL, {
    data: { clear: true },
  });
  if (!response.ok()) {
    throw new Error(
      `clearTestSession failed: HTTP ${response.status()} ${await response.text()}`
    );
  }
}

/**
 * Establish a real authenticated session cookie for SSR middleware, then
 * keep a client-visible session payload in sync for hydration.
 *
 * @param {import("@playwright/test").Page} page
 * @param {{ id?: number, login?: string }} user
 */
export async function mockAuthenticatedUser(page, user = { login: "testuser", id: 10 }) {
  const payload = {
    id: Number(user.id ?? 10),
    login: String(user.login ?? "testuser"),
  };

  // Drop any prior session route mock so the sealed cookie wins for SSR.
  await page.unroute("**/api/_auth/session").catch(() => {});

  const response = await page.request.post(TEST_SESSION_URL, {
    data: { user: payload },
  });
  if (!response.ok()) {
    throw new Error(
      `mockAuthenticatedUser failed: HTTP ${response.status()} ${await response.text()}`
    );
  }

  await page.route("**/api/_auth/session", (route) => {
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ loggedIn: true, user: payload }),
    });
  });
}

/**
 * Set up a mocked todo list response (overrides the empty list from setupMocks).
 *
 * Also writes the `codevalid_mock_todos` cookie so that Nuxt SSR handlers can
 * read the fixture via `readCodevalidMockTodos()` — `page.route` only intercepts
 * browser-side requests and cannot intercept the server-side `$fetch` call that
 * SSR makes when rendering the page.
 *
 * @param {import("@playwright/test").Page} page
 * @param {Array<Record<string, unknown>>} todos
 */
export async function mockTodos(page, todos = []) {
  // Write the cookie so SSR can read the fixture on server-side renders.
  const cookieValue = encodeURIComponent(JSON.stringify(todos));
  await page.context().addCookies([
    {
      name: "codevalid_mock_todos",
      value: cookieValue,
      domain: "localhost",
      path: "/",
      sameSite: "Lax",
      httpOnly: false,
      secure: false,
    },
  ]);

  // Also intercept client-side requests so re-fetches after hydration are mocked.
  await page.unroute("**/api/todos*").catch(() => {});
  await page.route("**/api/todos*", (route) => {
    if (route.request().method().toUpperCase() !== "GET") {
      return route.continue();
    }
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(todos),
    });
  });
}
