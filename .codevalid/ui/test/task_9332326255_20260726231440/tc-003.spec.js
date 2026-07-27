import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupUnauthenticatedSession } from "../../helpers/mock-api.js";

test("tc-003 Todos page requires auth", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "tc-003",
    testTitle: "Todos page requires auth",
  });

  await recorder.step("Setup unauthenticated session mocks", async () => {
    await setupUnauthenticatedSession(page);
  });

  await recorder.step("Navigate to /todos", async () => {
    await page.goto("/todos");
  });

  await recorder.step("Observe auth gate blocking todo UI", async () => {
    await page.waitForLoadState("networkidle");
    await expect(page).not.toHaveURL(/\/todos$/);
    await expect(page.locator('[name="todo"]')).toHaveCount(0);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:tc-003");
  await recorder.save(testInfo);
});
