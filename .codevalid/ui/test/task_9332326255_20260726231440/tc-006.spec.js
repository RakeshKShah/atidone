import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  setupOptimisticTodosPage,
  setupUnauthenticatedSession,
} from "../../helpers/mock-api.js";

test("tc-006 Optimistic todos page loads when authenticated", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "tc-006",
    testTitle: "Optimistic todos page loads when authenticated",
  });

  await recorder.step("Set up authenticated session and todo list mocks");
  await setupOptimisticTodosPage(page, {
    user: { id: 101, login: "alice" },
    todos: [
      {
        id: 1,
        title: "Pay rent",
        completed: 0,
        userId: 101,
        createdAt: "2026-07-26T10:00:00.000Z",
      },
      {
        id: 2,
        title: "Buy groceries",
        completed: 1,
        userId: 101,
        createdAt: "2026-07-26T11:00:00.000Z",
      },
    ],
  });

  await recorder.step("Navigate to optimistic todos page");
  await page.goto("/optimistic-todos");

  await recorder.step("Assert authenticated optimistic todos content is visible");
  await expect(page).toHaveURL(/\/optimistic-todos$/);
  await expect(page.locator('[name="todo"]')).toBeVisible();
  await expect(page.locator('[name="todo"]')).toHaveAttribute("placeholder", "Make a Nuxt demo");
  await expect(page.getByText("Pay rent")).toBeVisible();
  await expect(page.getByText("Buy groceries")).toBeVisible();

  console.log("CODEVALID_TEST_ASSERTION_OK:tc-006");
  await recorder.save(testInfo);
});
