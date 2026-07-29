import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupOptimisticTodosPage } from "../../helpers/mock-api.js";

test("tc-005 Create a todo from the UI", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "tc-005",
    testTitle: "Create a todo from the UI",
  });

  await recorder.step("Setup authenticated todo page mocks", async () => {
    await setupOptimisticTodosPage(page, {
      todos: [
        {
          id: 1,
          title: "Pay rent",
          completed: 0,
          userId: 101,
          createdAt: "2026-07-26T10:00:00.000Z",
        },
      ],
      createDelayMs: 1,
    });
  });

  await recorder.step("Navigate to /todos", async () => {
    await page.goto("/todos");
  });

  await recorder.step("Enter a title in the new todo input", async () => {
    await expect(page.locator('[name="todo"]')).toBeVisible();
    await page.locator('[name="todo"]').fill("Write Playwright coverage");
    await expect(page.locator('[name="todo"]')).toHaveValue("Write Playwright coverage");
  });

  await recorder.step("Submit create", async () => {
    await page.locator('form').getByRole('button').click();
  });

  await recorder.step("Assert the new todo appears in the list", async () => {
    await expect(page.getByText("Write Playwright coverage", { exact: true })).toBeVisible();
    await expect(page.locator('[name="todo"]')).toHaveValue("");
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:tc-005");
  await recorder.save(testInfo);
});
