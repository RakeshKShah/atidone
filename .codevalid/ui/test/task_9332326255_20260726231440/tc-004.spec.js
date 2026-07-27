import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupOptimisticTodosPage } from "../../helpers/mock-api.js";

test("tc-004 Authenticated user sees todo list", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "tc-004",
    testTitle: "Authenticated user sees todo list",
  });

  await recorder.step("Setup authenticated todo page mocks", async () => {
    await setupOptimisticTodosPage(page);
  });

  await recorder.step("Navigate to /todos", async () => {
    await page.goto("/todos");
  });

  await recorder.step("Assert todo list UI is visible for authenticated user", async () => {
    await expect(page).toHaveURL(/\/todos$/);
    await expect(page.locator('[name="todo"]')).toBeVisible();
    await expect(page.locator('[name="todo"]')).toHaveValue("");
    await expect(page.getByText("Pay rent")).toBeVisible();
    await expect(page.getByText("Buy groceries")).toBeVisible();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:tc-004");
  await recorder.save(testInfo);
});
