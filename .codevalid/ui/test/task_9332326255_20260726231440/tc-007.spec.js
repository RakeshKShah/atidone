import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupOptimisticTodosPage } from "../../helpers/mock-api.js";

test("tc-007 Optimistic create updates list immediately", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "tc-007",
    testTitle: "Optimistic create updates list immediately",
  });

  await recorder.step("Set up authenticated optimistic todos mocks with create support");
  await setupOptimisticTodosPage(page, {
    user: { id: 101, login: "alice" },
    todos: [
      {
        id: 1,
        title: "Existing todo",
        completed: 0,
        userId: 101,
        createdAt: "2026-07-26T09:00:00.000Z",
      },
    ],
    createResponse: {
      id: 99,
      title: "Ship release",
      completed: 0,
      userId: 101,
      createdAt: "2026-07-26T12:00:00.000Z",
    },
    createDelayMs: 1200,
  });

  await recorder.step("Open optimistic todos page");
  await page.goto("/optimistic-todos");
  await expect(page).toHaveURL(/\/optimistic-todos$/);

  await recorder.step("Submit a new todo title");
  await page.locator('[name="todo"]').fill("Ship release");
  await page.getByRole("button").click();

  await recorder.step("Assert the item appears optimistically before server confirmation");
  const optimisticItem = page.getByText("Ship release");
  await expect(optimisticItem).toBeVisible();
  await expect(page.locator('[name="todo"]')).toHaveValue("");
  await expect(page.getByText("Existing todo")).toBeVisible();

  console.log("CODEVALID_TEST_ASSERTION_OK:tc-007");
  await recorder.save(testInfo);
});
