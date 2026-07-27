import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupUnauthenticatedSession } from "../../helpers/mock-api.js";

test("tc-008 Optimistic todos auth gate", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "tc-008",
    testTitle: "Optimistic todos auth gate",
  });

  await recorder.step("Set up unauthenticated session mocks");
  await setupUnauthenticatedSession(page);

  await recorder.step("Navigate to optimistic todos page while unauthenticated");
  await page.goto("/optimistic-todos");

  await recorder.step("Assert redirect to landing page and sign-in requirement copy");
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByText("Welcome to Atidone.")).toBeVisible();
  await expect(page.locator('[name="todo"]')).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:tc-008");
  await recorder.save(testInfo);
});
