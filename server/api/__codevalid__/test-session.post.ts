/**
 * Test-only helper for Playwright UI runs.
 *
 * Establishes a real nuxt-auth-utils sealed session cookie so SSR `auth`
 * middleware and `useUserSession()` see the user. Browser `page.route`
 * mocks alone cannot satisfy server-side middleware.
 *
 * Enabled only when CODEVALID_E2E=1 or CI=true.
 */
export default eventHandler(async (event) => {
  const enabled =
    process.env.CODEVALID_E2E === "1" ||
    process.env.CI === "true" ||
    process.env.CI === "1";
  if (!enabled) {
    throw createError({ statusCode: 404, statusMessage: "Not Found" });
  }

  const body = await readBody<{
    user?: { id?: number; login?: string } | null;
    clear?: boolean;
  }>(event);

  if (body?.clear || body?.user == null) {
    await clearUserSession(event);
    return { ok: true, loggedIn: false };
  }

  const user = {
    id: Number(body.user.id ?? 10),
    login: String(body.user.login ?? "testuser"),
  };
  await setUserSession(event, { user });
  return { ok: true, loggedIn: true, user };
});
