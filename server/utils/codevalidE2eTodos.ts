/**
 * Cookie-backed todo fixtures for CODEVALID / CI Playwright runs.
 *
 * Playwright `page.route` cannot intercept Nuxt SSR `$fetch` during middleware
 * navigation, so authenticated pages would render an empty list from the real
 * DB. When this cookie is present, API handlers return the fixture instead.
 */
export const CODEVALID_MOCK_TODOS_COOKIE = "codevalid_mock_todos";

export function isCodevalidE2E(): boolean {
  return (
    process.env.CODEVALID_E2E === "1" ||
    process.env.CI === "true" ||
    process.env.CI === "1"
  );
}

export function readCodevalidMockTodos(event: any): any[] | null {
  if (!isCodevalidE2E()) {
    return null;
  }
  const raw = getCookie(event, CODEVALID_MOCK_TODOS_COOKIE);
  if (raw == null || raw === "") {
    return null;
  }
  try {
    const parsed = JSON.parse(decodeURIComponent(raw));
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export function writeCodevalidMockTodos(event: any, todos: any[]): void {
  if (!isCodevalidE2E()) {
    return;
  }
  setCookie(event, CODEVALID_MOCK_TODOS_COOKIE, encodeURIComponent(JSON.stringify(todos)), {
    path: "/",
    sameSite: "lax",
    httpOnly: false,
  });
}
